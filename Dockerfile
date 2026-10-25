FROM astrocrpublic.azurecr.io/runtime:3.3-9

# dbt in its own venv: dbt-bigquery pins google-cloud-storage<3.2, which conflicts with the
# runtime's apache-airflow-providers-google. dags/dbt_build.py points Cosmos at this executable.
RUN python -m venv dbt_venv && dbt_venv/bin/pip install --no-cache-dir dbt-bigquery==1.12.1
