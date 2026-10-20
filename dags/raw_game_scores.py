import json, os
from datetime import datetime, timedelta, timezone
import pendulum
from airflow.decorators import dag, task
from airflow.providers.google.cloud.hooks.gcs import GCSHook
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from google.cloud import bigquery
from include.ingest.odds_api import SPORT_KEYS, fetch_scores

BUCKET = os.environ["GCS_BUCKET"]
PROJECT = os.environ["GCP_PROJECT"]
SCHEMA = [bigquery.SchemaField("ingested_at", "TIMESTAMP"),
          bigquery.SchemaField("league", "STRING"),
          bigquery.SchemaField("payload", "STRING")]   # raw JSON; parsed in dbt

@dag(schedule="0 6 * * *",   # 6am ET daily
     start_date=pendulum.datetime(2026, 10, 20, tz="America/New_York"), catchup=False, max_active_runs=1,
     default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
     tags=["raw", "scores"])
def raw_game_scores():

    @task
    def scores(league):
        ts = datetime.now(timezone.utc)
        rows = fetch_scores(league, days_from=1)
        if not rows:
            print(f"No games for {league}")
            return 0
        nd = "\n".join(json.dumps({"ingested_at": ts.isoformat(), "league": league,
                                   "payload": json.dumps(r)}) for r in rows)
        path = f"raw/scores/league={league}/dt={ts:%Y-%m-%d}/{ts:%H%M%S}.ndjson"
        GCSHook().upload(BUCKET, path, data=nd, timeout=300, num_max_attempts=3)
        client = BigQueryHook(use_legacy_sql=False).get_client(project_id=PROJECT)
        cfg = bigquery.LoadJobConfig(source_format="NEWLINE_DELIMITED_JSON",
                                     write_disposition="WRITE_APPEND", schema=SCHEMA)
        client.load_table_from_uri(f"gs://{BUCKET}/{path}",
                                   f"{PROJECT}.raw.game_scores", job_config=cfg).result()
        print(f"{league}: {len(rows)} rows -> {path}")
        return len(rows)

    scores.expand(league=list(SPORT_KEYS))

raw_game_scores()
