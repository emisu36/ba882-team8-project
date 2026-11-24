"""
## Team 8 Phase 2: model training DAG (adapted from the Session 9/10 lab)

ml_game_outcome: Option B (does Polymarket add information beyond sportsbooks?)
                 + Option A (calibration of each venue and the model, logged per run)

Flow per DAG: register_model -> create_dataset -> train (parallel .expand over configs)
-> register_run (each) -> pick_production (books-only run) -> promote to mlops.model_version.
Training happens in the ml-train-model Cloud Function (ML_TRAIN_URL env var).
"""
import json
import os
import uuid
from datetime import timedelta

import pendulum
import requests
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from airflow.sdk import dag, task

PROJECT = os.environ.get("GCP_PROJECT", "")
ML_TRAIN_URL = os.environ.get("ML_TRAIN_URL", "")


def bq():
    # same auth path as the team's other DAGs (Airflow connection), not default credentials
    return BigQueryHook(use_legacy_sql=False).get_client(project_id=PROJECT)


def q(s):
    return s.replace("'", "\\'")


SPECS = {
    "ml_game_outcome": {
        "problem": "game_outcome",
        "table": "ai_datasets.ml_training_set",
        "model": {"model_id": "model-game-outcome",
                  "name": "Game outcome: books vs Polymarket",
                  "business_problem": "Does Polymarket add information beyond sportsbook odds in predicting game winners?",
                  "ticket_number": "BA882-T8-P2", "owner": "team8"},
        "configs": [
            {"feature_set": "book_only",    "algorithm": "logistic_regression", "hyperparameters": {"C": "auto"}},
            {"feature_set": "book_poly",    "algorithm": "logistic_regression", "hyperparameters": {"C": "auto"}},
            # kept as evidence that extra features overfit at this sample size (Emily's sandbox)
            {"feature_set": "outcome_full", "algorithm": "logistic_regression", "hyperparameters": {"C": "auto"}},
            # challenger: boosted trees, re-tested every run as data grows (champion = books-only LR)
            {"feature_set": "outcome_full", "algorithm": "gradient_boosting",
             "hyperparameters": {"n_estimators": 150, "max_depth": 2, "learning_rate": 0.03}},
        ],
        # Production = books-only model (simplest; +Polymarket and extra features don't help)
        "production_feature_set": "book_only",
    },
}


def make_dag(dag_id, spec):
    M = spec["model"]

    @dag(dag_id=dag_id, schedule="0 8 * * 1,4",   # Mon + Thu 8am ET (~50 new games per retrain)
         start_date=pendulum.datetime(2026, 11, 1, tz="America/New_York"),
         catchup=False, max_active_runs=1,
         default_args={"retries": 1, "retry_delay": timedelta(minutes=5)},
         tags=["mlops", "model", "phase2"])
    def _dag():

        @task
        def register_model():
            bq().query(f"""
                INSERT INTO `{PROJECT}.mlops.model`
                  (model_id, name, business_problem, ticket_number, owner, created_at)
                SELECT '{M["model_id"]}', '{q(M["name"])}', '{q(M["business_problem"])}',
                       '{M["ticket_number"]}', '{M["owner"]}', CURRENT_TIMESTAMP()
                FROM (SELECT 1)
                WHERE NOT EXISTS (SELECT 1 FROM `{PROJECT}.mlops.model`
                                  WHERE model_id = '{M["model_id"]}')
            """).result()

        @task
        def create_dataset():
            r = list(bq().query(f"""
                SELECT COUNT(*) AS n, CAST(MAX(game_date) AS STRING) AS max_date
                FROM `{PROJECT}.{spec["table"]}`""").result())[0]
            version = pendulum.now("UTC").format("YYYYMMDD-HHmm")
            dataset_id = f"ds-{M['model_id']}-{version}"
            bq().query(f"""
                INSERT INTO `{PROJECT}.mlops.dataset`
                  (dataset_id, model_id, data_version, gcs_path, row_count, feature_count, created_at)
                VALUES ('{dataset_id}', '{M["model_id"]}', '{version} (games to {r.max_date})',
                        'bigquery://{PROJECT}/{spec["table"]}', {r.n}, NULL, CURRENT_TIMESTAMP())
            """).result()
            return {"dataset_id": dataset_id}

        @task
        def train(config: dict, ds: dict, **ctx):
            run_id = f"run-{M['model_id']}-{uuid.uuid4().hex[:8]}"
            resp = requests.post(ML_TRAIN_URL, timeout=300, json={
                "run_id": run_id, "model_id": M["model_id"], "dataset_id": ds["dataset_id"],
                "gcp_project": PROJECT, "problem": spec["problem"], "test_days": 14, **config})
            if resp.status_code != 200:
                raise RuntimeError(f"training failed: {resp.status_code} {resp.text}")
            out = resp.json()
            out.update(config=config, airflow_run_id=ctx["dag_run"].run_id)
            print(run_id, config, out["metrics"])
            return out

        @task
        def register_run(res: dict, ds: dict):
            params = q(json.dumps(res["config"]))
            metrics = q(json.dumps(res["metrics"]))
            bq().query(f"""
                INSERT INTO `{PROJECT}.mlops.training_run`
                  (run_id, model_id, dataset_id, airflow_run_id, params, metrics, artifact, status, created_at)
                VALUES ('{res["run_id"]}', '{M["model_id"]}', '{ds["dataset_id"]}', '{res["airflow_run_id"]}',
                        PARSE_JSON('{params}'), PARSE_JSON('{metrics}'), '{res["artifact"]}',
                        'completed', CURRENT_TIMESTAMP())
            """).result()

        @task
        def pick_production(results: list):
            """Promote the books-only run (team decision from Emily's sandbox), and log
            whether +Polymarket beat it this week so the comparison is tracked over time."""
            prod = next(r for r in results
                        if r["config"]["feature_set"] == spec["production_feature_set"]
                        and r["config"]["algorithm"] == "logistic_regression")
            for r in results:   # how each other model compares with the champion this run
                if r is prod:
                    continue
                diff = r["metrics"]["log_loss"] - prod["metrics"]["log_loss"]
                print(f'{r["config"]["feature_set"]} / {r["config"]["algorithm"]}: '
                      f"log loss {diff:+.4f} vs champion (negative = better than champion)")
            return prod

        @task
        def promote(best: dict):
            mv = f"mv-{M['model_id']}-{uuid.uuid4().hex[:8]}"
            client = bq()
            client.query(f"""UPDATE `{PROJECT}.mlops.model_version` SET status = 'archived'
                             WHERE model_id = '{M["model_id"]}' AND status = 'production'""").result()
            client.query(f"""
                INSERT INTO `{PROJECT}.mlops.model_version`
                  (model_version_id, model_id, training_run_id, artifact_path, metrics, status, created_at)
                VALUES ('{mv}', '{M["model_id"]}', '{best["run_id"]}', '{best["artifact"]}',
                        PARSE_JSON('{q(json.dumps(best["metrics"]))}'), 'production', CURRENT_TIMESTAMP())
            """).result()
            return mv

        m = register_model()
        ds = create_dataset()
        m >> ds
        results = train.partial(ds=ds).expand(config=spec["configs"])
        register_run.partial(ds=ds).expand(res=results)
        promote(pick_production(results))

    return _dag()


for _id, _spec in SPECS.items():
    globals()[_id] = make_dag(_id, _spec)
