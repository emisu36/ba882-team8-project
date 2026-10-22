import os
from datetime import timedelta
from pathlib import Path
import pendulum
from airflow.sdk import Asset
from cosmos import DbtDag, ExecutionConfig, LoadMode, ProfileConfig, ProjectConfig, RenderConfig
from cosmos.constants import InvocationMode

DBT_DIR = Path(__file__).parent.parent / "include" / "dbt"
# dbt-bigquery pins google-cloud-storage<3.2, which clashes with providers-google in the
# runtime image, so dbt lives in its own venv (built in the Dockerfile; .venv-dbt locally / CI).
DBT_EXE = os.environ.get("DBT_EXECUTABLE_PATH",
                         f"{os.environ.get('AIRFLOW_HOME', '/usr/local/airflow')}/dbt_venv/bin/dbt")

# Runs after every raw_market_snapshots run. Set Airflow Variable DBT_FULL_REFRESH=true to
# rebuild incremental models and seeds from scratch (templated, so no DB call at parse time).
dbt_build = DbtDag(
    dag_id="dbt_build",
    project_config=ProjectConfig(DBT_DIR),
    profile_config=ProfileConfig(profile_name="team8_markets", target_name="dev",
                                 profiles_yml_filepath=DBT_DIR / "profiles.yml"),
    execution_config=ExecutionConfig(dbt_executable_path=DBT_EXE,
                                     invocation_mode=InvocationMode.SUBPROCESS),
    render_config=RenderConfig(load_method=LoadMode.DBT_LS, dbt_executable_path=DBT_EXE,
                               invocation_mode=InvocationMode.SUBPROCESS),
    operator_args={"full_refresh": "{{ var.value.get('DBT_FULL_REFRESH', 'false') }}"},
    schedule=[Asset("raw_market_snapshots")],
    start_date=pendulum.datetime(2026, 10, 20, tz="America/New_York"), catchup=False, max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
    tags=["dbt", "transform"],
)
