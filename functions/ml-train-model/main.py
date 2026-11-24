# Train one game-outcome model from ai_datasets.ml_training_set (built by dbt).
#   Option B: does Polymarket add information beyond the sportsbooks? (nested models)
#   Option A: is each venue (and our model) well calibrated? (reliability bins + ECE on the test set)
# No feature engineering here (team rule): only feature selection, fitted preprocessing
# (impute / scale / one-hot, fit on TRAIN only), a time-based split, and evaluation.

import io
import os

import functions_framework
import joblib
import numpy as np
import pandas as pd
from google.cloud import bigquery, storage
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, log_loss, roc_auc_score
from sklearn.model_selection import GridSearchCV, TimeSeriesSplit
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

GCS_BUCKET = os.environ.get("GCS_BUCKET", "ba882-team8-fall26-ml")
EPS = 1e-6
# Candidate regularization strengths for logistic regression when C = "auto".
# Smaller C = stronger pull toward 50/50; picked by time-ordered cross-validation on TRAIN only.
C_GRID = [0.01, 0.03, 0.1, 0.3, 1.0]

PROBLEMS = {
    "game_outcome": {
        "table": "ai_datasets.ml_training_set",
        "label": "team_won",
        "time_col": "game_date",
        # market prices used directly as forecasts; the model must beat these
        "price_baselines": {"book": "book_mid", "poly": "poly_mid"},
    },
}

FEATURE_SETS = {
    # Option B: nested models. If book_poly beats book_only, Polymarket adds information.
    "book_only": {"num": ["book_logit"], "cat": []},
    "book_poly": {"num": ["book_logit", "poly_logit"], "cat": []},
    "outcome_full": {
        "num": ["book_logit", "poly_logit", "abs_gap", "book_range", "poly_spread",
                "n_books", "book_move", "poly_move", "hours_to_start", "outside_spread"],
        "cat": ["league"],
    },
}


def brier(y, p):
    return float(np.mean((np.asarray(p) - np.asarray(y)) ** 2))


def scores(y, p):
    p = np.clip(np.asarray(p, dtype=float), EPS, 1 - EPS)
    out = {"brier": round(brier(y, p), 5), "log_loss": round(float(log_loss(y, p, labels=[0, 1])), 5)}
    out["auc"] = round(float(roc_auc_score(y, p)), 4) if len(set(y)) == 2 else None
    out["accuracy"] = round(float(accuracy_score(y, (p >= 0.5).astype(int))), 4)
    return out


def calibration(y, p, n_bins=10):
    """Option A: reliability bins and expected calibration error (ECE).
    ECE = weighted average gap between predicted probability and actual win rate."""
    y, p = np.asarray(y, dtype=float), np.asarray(p, dtype=float)
    bins = np.minimum((p * n_bins).astype(int), n_bins - 1)
    table, ece = [], 0.0
    for b in range(n_bins):
        m = bins == b
        if m.sum() == 0:
            continue
        gap = float(y[m].mean() - p[m].mean())
        ece += m.mean() * abs(gap)
        table.append({"bin": b, "n": int(m.sum()), "avg_pred": round(float(p[m].mean()), 3),
                      "win_rate": round(float(y[m].mean()), 3)})
    return round(float(ece), 4), table


def paired_t(d):
    """t-statistic for the mean of paired differences d (one value per game)."""
    d = np.asarray(d, dtype=float)
    sd = d.std(ddof=1)
    return round(float(d.mean() / (sd / np.sqrt(len(d)))), 3) if len(d) > 2 and sd > 0 else None


def market_diagnostics(frame, label):
    """Emily's sandbox checks, on every finished game in the table (no model involved):
    - paired Brier: book Brier minus Polymarket Brier per game; > 0 = Polymarket more accurate
    - home bias: actual home win rate minus predicted; < 0 = home teams overpriced"""
    y = frame[label].to_numpy(dtype=float)
    book, poly = frame["book_mid"].to_numpy(dtype=float), frame["poly_mid"].to_numpy(dtype=float)
    d = (book - y) ** 2 - (poly - y) ** 2
    out = {"n_games": int(len(y)),
           "brier_book_minus_poly": round(float(d.mean()), 5), "brier_book_minus_poly_t": paired_t(d)}
    for name, p in [("book", book), ("poly", poly)]:
        e = y - p
        out[f"home_bias_{name}_pts"] = round(float(e.mean() * 100), 2)
        out[f"home_bias_{name}_t"] = paired_t(e)
    return out


def boot_brier_diff(y, p_model, p_base, n=1000, seed=42):
    """95% bootstrap CI for Brier(model) - Brier(baseline) on the test set. Below 0 = model better."""
    y, p_model, p_base = map(np.asarray, (y, p_model, p_base))
    rng, k = np.random.default_rng(seed), len(y)
    diffs = []
    for _ in range(n):
        s = rng.integers(0, k, k)
        diffs.append(brier(y[s], p_model[s]) - brier(y[s], p_base[s]))
    lo, hi = np.percentile(diffs, [2.5, 97.5])
    return round(float(lo), 5), round(float(hi), 5)


def build_model(algorithm, hp, num, cat):
    steps = [("num", Pipeline([("impute", SimpleImputer(strategy="constant", fill_value=0)),
                               ("scale", StandardScaler())]), num)]
    if cat:
        steps.append(("cat", OneHotEncoder(handle_unknown="ignore"), cat))
    pre = ColumnTransformer(steps)
    if algorithm == "logistic_regression":
        c = hp.get("C", "auto")
        clf = LogisticRegression(max_iter=hp.get("max_iter", 1000), C=1.0 if c == "auto" else float(c))
    elif algorithm == "gradient_boosting":
        clf = GradientBoostingClassifier(n_estimators=hp.get("n_estimators", 100),
                                         max_depth=hp.get("max_depth", 2),
                                         learning_rate=hp.get("learning_rate", 0.05),
                                         random_state=42)
    else:
        raise ValueError(f"unknown algorithm: {algorithm}")
    return Pipeline([("pre", pre), ("clf", clf)])


@functions_framework.http
def task(request):
    """
    JSON body: run_id, model_id, dataset_id, gcp_project, problem, feature_set,
               algorithm, hyperparameters, test_days (default 14),
               train_end (optional YYYY-MM-DD: train on games up to this date and test on the
                          following test_days, for walk-forward backtests)
    """
    b = request.get_json(silent=True) or {}
    need = ["run_id", "model_id", "dataset_id", "gcp_project", "problem", "feature_set"]
    if not all(b.get(k) for k in need):
        return {"error": f"missing one of {need}"}, 400

    prob = PROBLEMS[b["problem"]]
    fs = FEATURE_SETS[b["feature_set"]]
    algorithm = b.get("algorithm", "logistic_regression")
    hp = b.get("hyperparameters", {})
    test_days = int(b.get("test_days", 14))
    label, time_col = prob["label"], prob["time_col"]

    # ---- load (no SQL logic, just the dbt table) ----
    bq = bigquery.Client(project=b["gcp_project"])
    df = bq.query(f"SELECT * FROM `{b['gcp_project']}.{prob['table']}`").to_dataframe()
    if df.empty:
        return {"error": f"{prob['table']} is empty"}, 400
    for c in df.columns:                      # type casts only, not features
        if df[c].dtype == bool or str(df[c].dtype) == "boolean":
            df[c] = df[c].astype("float")         # booleans -> 0/1
        elif df[c].dtype == object:               # BigQuery NUMERIC arrives as Decimal objects
            conv = pd.to_numeric(df[c], errors="coerce")
            if conv.notna().sum() == df[c].notna().sum():
                df[c] = conv.astype(float)

    # ---- time-based split: newest test_days are the test set ----
    t = pd.to_datetime(df[time_col])
    if b.get("train_end"):                       # backtest: fixed cutoff in the past
        cutoff = pd.Timestamp(b["train_end"])
        train, test = df[t <= cutoff], df[(t > cutoff) & (t <= cutoff + pd.Timedelta(days=test_days))]
    else:                                         # normal: newest test_days are the test set
        cutoff = t.max() - pd.Timedelta(days=test_days)
        train, test = df[t <= cutoff], df[t > cutoff]
    if len(train) < 50 or len(test) < 20 or train[label].nunique() < 2:
        return {"error": f"not enough data: train={len(train)} test={len(test)}"}, 400

    cols = fs["num"] + fs["cat"]
    train = train.sort_values(time_col)          # time order, so CV folds never look ahead
    model = build_model(algorithm, hp, fs["num"], fs["cat"])
    chosen = {}
    if algorithm == "logistic_regression" and hp.get("C", "auto") == "auto":
        # pick C with time-series CV inside the training data (test set untouched)
        search = GridSearchCV(model, {"clf__C": C_GRID}, scoring="neg_log_loss",
                              cv=TimeSeriesSplit(n_splits=4))
        search.fit(train[cols], train[label])
        model = search.best_estimator_
        chosen = {"chosen_C": float(search.best_params_["clf__C"]),
                  "cv_log_loss_by_C": {str(c): round(float(-v), 5) for c, v in
                                       zip(C_GRID, search.cv_results_["mean_test_score"])}}
    else:
        model.fit(train[cols], train[label])
    p_model = model.predict_proba(test[cols])[:, 1]
    y = test[label].to_numpy()

    # ---- metrics: model vs baselines on the SAME test rows ----
    metrics = {"n_train": int(len(train)), "n_test": int(len(test)),
               "train_end": str(cutoff.date()), "test_end": str(pd.to_datetime(test[time_col]).max().date()),
               "test_positive_rate": round(float(y.mean()), 4)}
    metrics.update(scores(y, p_model))
    metrics.update(chosen)

    base_rate = np.full(len(y), train[label].mean())          # "no skill" baseline
    metrics["baseline_base_rate"] = scores(y, base_rate)
    for name, col in prob["price_baselines"].items():
        metrics[f"baseline_{name}"] = scores(y, test[col])
    ref = test["book_mid"] if "book" in prob["price_baselines"] else base_rate
    metrics["ref_baseline"] = "book" if "book" in prob["price_baselines"] else "base_rate"
    metrics["brier_minus_ref"] = round(metrics["brier"] - brier(y, ref), 5)
    metrics["brier_minus_ref_ci95"] = boot_brier_diff(y, p_model, ref)
    metrics["beats_ref"] = metrics["brier_minus_ref_ci95"][1] < 0   # whole CI below 0

    # Option A: calibration of the model and of each venue on the same test games
    metrics["ece"], metrics["calibration_bins"] = calibration(y, p_model)
    for name, col in prob["price_baselines"].items():
        metrics[f"baseline_{name}"]["ece"] = calibration(y, test[col])[0]

    # Brier by league on the test set (model and both venues)
    metrics["brier_by_league"] = {
        lg: {"n": int(len(g)),
             "model": round(brier(g[label], p_model[test["league"].to_numpy() == lg]), 4),
             "book": round(brier(g[label], g["book_mid"]), 4),
             "poly": round(brier(g[label], g["poly_mid"]), 4)}
        for lg, g in test.groupby("league")}

    # market-level checks (same for every config): all finished games, and the test window
    metrics["market_all_games"] = market_diagnostics(df, label)
    metrics["market_test_window"] = market_diagnostics(test, label)

    # coefficients (logistic regression only) for interpretation
    if algorithm == "logistic_regression":
        names = model.named_steps["pre"].get_feature_names_out()
        coefs = model.named_steps["clf"].coef_[0]
        metrics["coefficients"] = {n: round(float(c), 4) for n, c in zip(names, coefs)}

    # ---- save artifact ----
    buf = io.BytesIO()
    joblib.dump({"model": model, "features": cols, "problem": b["problem"]}, buf)
    buf.seek(0)
    path = (f"models/model_id={b['model_id']}/dataset_id={b['dataset_id']}/"
            f"run_id={b['run_id']}/model.pkl")
    storage.Client().bucket(GCS_BUCKET).blob(path).upload_from_file(buf)

    return {"run_id": b["run_id"], "artifact": f"gs://{GCS_BUCKET}/{path}", "metrics": metrics}, 200
