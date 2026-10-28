"""DAG de EJEMPLO (D005): corrida batch diaria del pipeline dbt.

No forma parte del docker-compose ni se ejecutó: muestra cómo se orquestaría en producción.
Escrito para Airflow 3. Supone una imagen con este repo, dbt y sus paquetes instalados
(la misma del Dockerfile), por ejemplo detrás de un KubernetesPodOperator o un worker
que la tenga.
"""

from datetime import datetime, timedelta

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

DBT_DIR = "/app/dbt"

# Día que procesa la corrida: el día anterior completo. La extracción a raw llega
# ~03:00 (_extracted_at), el DAG corre 04:00. data_interval_end - 1 día da la misma
# fecha con o sin data intervals (Airflow 2 y 3).
RUN_DATE = "{{ (data_interval_end - macros.timedelta(days=1)) | ds }}"
DBT_VARS = f"--vars '{{run_date: {RUN_DATE}}}'"

default_args = {
    "owner": "data-engineering",
    "retries": 2,
    "retry_delay": timedelta(minutes=10),
}

with DAG(
    dag_id="ecommerce_daily",
    description="bronze -> silver -> gold con dbt, una vez por día",
    schedule="0 4 * * *",
    start_date=datetime(2026, 1, 2),
    end_date=datetime(2026, 7, 2),
    catchup=True,          # backfill día por día desde start_date
    max_active_runs=1,     # DuckDB acepta un solo writer: corridas en serie
    default_args=default_args,
    tags=["ecommerce", "dbt"],
) as dag:
    # 1. Validar la fuente antes de transformar: si raw está vacío o roto, no seguir.
    check_bronze = BashOperator(
        task_id="check_bronze",
        bash_command=f"cd {DBT_DIR} && dbt test --select source:raw {DBT_VARS}",
    )

    # 2. Silver: dedup incremental. Reintentar es seguro (idempotente, D027).
    build_silver = BashOperator(
        task_id="build_silver",
        bash_command=f"cd {DBT_DIR} && dbt build --select silver {DBT_VARS}",
    )

    # 3. Gold: modelos de negocio + tests. Si un test de silver falló, no se llega acá
    #    y el dashboard sigue mostrando el último gold bueno.
    build_gold = BashOperator(
        task_id="build_gold",
        bash_command=f"cd {DBT_DIR} && dbt build --select gold {DBT_VARS}",
    )

    check_bronze >> build_silver >> build_gold
