import json, os
from datetime import datetime, timedelta, timezone
import pendulum
from airflow.decorators import dag, task
from airflow.sdk import Asset
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

# noon + 7pm ET (cron runs in start_date tz, DST-safe). Odds API budget: 2 runs x 3 leagues x 1 credit
# = 6/day, plus raw_game_scores 3 x 2 = 6/day -> ~12/day, ~372 per 31-day month of the 500 free tier.
@dag(schedule="0 12,19 * * *",
     start_date=pendulum.datetime(2026, 10, 20, tz="America/New_York"), catchup=False, max_active_runs=1,
     default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
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

    # one asset event per run (not one per mapped snapshot) -> one dbt_build run
    @task(outlets=[Asset("raw_market_snapshots")])
    def signal_done(counts):
        print(f"Snapshot run done: {sum(counts)} rows total")

    signal_done(snapshot.expand(c=combos()))

raw_market_snapshots()