"""Dashboard de métricas de negocio.

No tiene lógica propia (D021): ejecuta los mismos .sql de queries/ contra el warehouse.
El selector de fecha corre dbt hasta ese día para mostrar el incremental en vivo (D022).
"""

import os
import subprocess
import sys
from datetime import date
from pathlib import Path

import duckdb
import streamlit as st

ROOT = Path(__file__).resolve().parent.parent
QUERIES_DIR = ROOT / "queries"
DBT_DIR = ROOT / "dbt"
# dbt del mismo entorno que corre Streamlit (venv local o imagen Docker).
DBT_BIN = str(Path(sys.executable).parent / "dbt")
WAREHOUSE_PATH = Path(os.environ.get("WAREHOUSE_PATH", ROOT / "data" / "warehouse.duckdb"))

FIRST_DAY = date(2026, 1, 1)
LAST_DAY = date(2026, 7, 1)


def run_query(name: str):
    """Abre el warehouse en solo lectura, corre queries/<name>.sql y cierra.

    Conexión corta: mientras dbt escribe, el dashboard no tiene el archivo tomado.
    """
    sql = (QUERIES_DIR / f"{name}.sql").read_text()
    with duckdb.connect(str(WAREHOUSE_PATH), read_only=True) as con:
        return con.execute(sql).df()


def processed_until() -> date | None:
    if not WAREHOUSE_PATH.exists():
        return None
    try:
        return run_query("01a_clientes_resumen")["fecha_corte"].iloc[0].date()
    except duckdb.Error:
        return None


def run_dbt(run_date: date, current: date | None) -> subprocess.CompletedProcess:
    """Corre `dbt build` hasta run_date.

    Avanzar en el tiempo es incremental. Volver atrás no se puede con un incremental
    (ya tiene datos posteriores), así que se reconstruye con --full-refresh.
    """
    cmd = [DBT_BIN, "build", "--vars", f"{{run_date: {run_date.isoformat()}}}"]
    if current is None or run_date < current:
        cmd.append("--full-refresh")
    return subprocess.run(cmd, cwd=DBT_DIR, capture_output=True, text=True)


st.set_page_config(page_title="E-commerce: métricas", layout="wide")
st.title("E-commerce: métricas de negocio")

current = processed_until()

with st.sidebar:
    st.header("Pipeline")
    st.write(f"Datos procesados hasta: **{current or 'sin datos'}**")
    run_date = st.date_input(
        "Procesar hasta esta fecha",
        value=current or LAST_DAY,
        min_value=FIRST_DAY,
        max_value=LAST_DAY,
    )
    # Si llega un segundo clic mientras corre, ese dbt falla por el lock de DuckDB
    # (un solo writer) sin tocar los datos.
    if st.button("Procesar", type="primary"):
        with st.spinner(f"dbt build hasta {run_date}..."):
            result = run_dbt(run_date, current)
        st.session_state["last_log"] = result.stdout[-3000:] + result.stderr[-2000:]
        if result.returncode == 0:
            st.rerun()
        st.error("dbt build falló, ver log.")
    if "last_log" in st.session_state:
        with st.expander("Log de la última corrida"):
            st.code(st.session_state["last_log"])

if current is None:
    st.info("El warehouse está vacío. Elegí una fecha y apretá **Procesar**.")
    st.stop()

# 1. Clientes
st.header("1. Clientes")
resumen = run_query("01a_clientes_resumen").iloc[0]
c1, c2, c3 = st.columns(3)
c1.metric("Clientes registrados", f"{int(resumen.clientes_total or 0):,}")
c2.metric("Clientes con compras", f"{int(resumen.clientes_con_compras or 0):,}")
c3.metric(
    "Clientes activos (90 días)",
    f"{int(resumen.clientes_activos or 0):,}",
    help="Al menos 1 orden no cancelada en los 90 días previos a la fecha de corte.",
)
crecimiento = run_query("01b_clientes_crecimiento_mensual")
st.subheader("Clientes acumulados por mes de registro")
st.bar_chart(crecimiento, x="mes", y="clientes_acumulados", y_label="clientes", x_label="mes")
with st.expander("Tabla"):
    st.dataframe(crecimiento, hide_index=True)

# 2. Ventas
st.header("2. Ventas")
st.caption("Venta = orden creada, aunque después se cancele.")
tab_dia, tab_semana = st.tabs(["Por día", "Por semana"])
with tab_dia:
    por_dia = run_query("02a_ventas_por_dia")
    st.line_chart(por_dia, x="dia", y="ventas", y_label="órdenes", x_label="día")
    with st.expander("Tabla"):
        st.dataframe(por_dia, hide_index=True)
with tab_semana:
    por_semana = run_query("02b_ventas_por_semana")
    st.bar_chart(por_semana, x="semana", y="ventas", y_label="órdenes", x_label="semana (lunes)")
    st.caption("La primera y la última semana pueden estar incompletas (ver dias_con_ventas).")
    with st.expander("Tabla"):
        st.dataframe(por_semana, hide_index=True)

# 3. Ingresos
st.header("3. Ingresos")
st.caption("Ingreso = órdenes entregadas, a precio de lista actual (USD).")
ingresos = run_query("03a_ingresos_total").iloc[0]
c1, c2, c3 = st.columns(3)
c1.metric("Ingresos totales", f"USD {ingresos.ingresos_total or 0:,.2f}")
c2.metric("Órdenes con ingreso", f"{int(ingresos.ordenes_con_ingreso or 0):,}")
c3.metric("Monto en curso (no cuenta)", f"USD {ingresos.monto_en_curso or 0:,.2f}")
por_categoria = run_query("03b_ingresos_por_categoria")
st.bar_chart(por_categoria, x="categoria", y="ingresos", y_label="USD", x_label="categoría", horizontal=True)
with st.expander("Tabla"):
    st.dataframe(por_categoria, hide_index=True)

# 4. Órdenes
st.header("4. Estado de las órdenes")
estados = run_query("04_estado_ordenes").set_index("estado")
c1, c2 = st.columns(2)
c1.metric("Entregadas", f"{estados.pct_ordenes.get('delivered', 0):.2f}%")
c2.metric("Canceladas", f"{estados.pct_ordenes.get('cancelled', 0):.2f}%")
st.bar_chart(estados.reset_index(), x="estado", y="pct_ordenes", y_label="% de órdenes", x_label="estado actual")
with st.expander("Tabla"):
    st.dataframe(estados.reset_index(), hide_index=True)
