import json, os
from datetime import datetime, timezone
from airflow.decorators import dag, task
from airflow.providers.google.cloud.hooks.gcs import GCSHook
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from google.cloud import bigquery
from include.ingest.markets import LEAGUES, fetch_polymarket
from include.ingest.odds_api import fetch_odds

BUCKET = os.environ["GCS_BUCKET"]
PROJECT = os.environ["GCP_PROJECT"]
FETCH = {"oddsapi": fetch_odds, "polymarket": fetch_polymarket}
SCHEMA = [bigquery.SchemaField("ingested_at", "TIMESTAMP"),
          bigquery.SchemaField("venue", "STRING"),
          bigquery.SchemaField("league", "STRING"),
          bigquery.SchemaField("payload", "STRING")]   # raw JSON; parsed in dbt

@dag(schedule="0 16,21,23 * * *",   # noon, 5pm, 7pm ET (UTC cron)
     start_date=datetime(2026, 10, 20), catchup=False, max_active_runs=1,
     tags=["raw", "markets"])
def raw_market_snapshots():

    @task
    def combos():
        return [{"venue": v, "league": l} for v in FETCH for l in LEAGUES]

    @task
    def snapshot(c):
        ts = datetime.now(timezone.utc)
        rows = FETCH[c["venue"]](c["league"])
        if not rows:
            print(f"No open markets for {c}")
            return 0
        nd = "\n".join(json.dumps({"ingested_at": ts.isoformat(), "venue": c["venue"],
                                   "league": c["league"], "payload": json.dumps(r)}) for r in rows)
        path = f"raw/venue={c['venue']}/league={c['league']}/dt={ts:%Y-%m-%d}/{ts:%H%M%S}.ndjson.gz"
        GCSHook().upload(BUCKET, path, data=nd, gzip=True, timeout=300, num_max_attempts=3)
        client = BigQueryHook(use_legacy_sql=False).get_client(project_id=PROJECT)
        cfg = bigquery.LoadJobConfig(source_format="NEWLINE_DELIMITED_JSON",
                                     write_disposition="WRITE_APPEND", schema=SCHEMA)
        client.load_table_from_uri(f"gs://{BUCKET}/{path}",
                                   f"{PROJECT}.raw.market_snapshots", job_config=cfg).result()
        print(f"{c}: {len(rows)} rows -> {path}")
        return len(rows)

    snapshot.expand(c=combos())

raw_market_snapshots()