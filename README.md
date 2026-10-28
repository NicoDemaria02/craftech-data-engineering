# Prueba técnica Data Engineering — Craftech

Modelo de datos de un e-commerce construido sobre DuckDB con **dbt**, en arquitectura
**medallion** (bronze → silver → gold). Incluye las consultas que responden a las preguntas
de negocio y un dashboard en **Streamlit**. Todo se levanta con un comando.

```
data/ecommerce.duckdb (raw)          data/warehouse.duckdb
┌──────────────────────┐   dbt    ┌───────────────────────┐       ┌───────────────┐
│ BRONZE  schema raw   │ ───────► │ SILVER  limpio, dedup │ ────► │ queries/*.sql │
│ customers  products  │ (read-   │ GOLD    dims + facts  │       │ Streamlit     │
│ orders  order_items  │  only)   └───────────────────────┘       └───────────────┘
└──────────────────────┘
```

---

## Cómo ejecutarlo desde cero

### Opción A: Docker (recomendada)

Requiere Docker con Docker Compose.

```bash
git clone https://github.com/NicoDemaria02/craftech-data-engineering.git
cd craftech-data-engineering
docker compose up --build
```

1. El servicio `pipeline` corre `dbt build`: construye silver y gold desde bronze y ejecuta
   los 54 tests. Al terminar, sale.
2. El servicio `dashboard` arranca solo si el pipeline terminó bien. Queda en
   **http://localhost:8501**.

El resultado queda en `data/warehouse.duckdb`. Para reconstruir desde cero, borrá ese archivo
y volvé a correr el comando.

### Opción B: local

Requiere Python 3.13 o 3.14.

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cd dbt
../.venv/bin/dbt deps                 # instala dbt_utils
../.venv/bin/dbt build                # silver + gold + tests
cd ..
.venv/bin/streamlit run app/streamlit_app.py
```

### Simular la corrida diaria

`raw` es una foto estática con 6 meses de datos. Para simular el batch diario, cada corrida
recibe un `run_date` y solo "ve" lo que había llegado al final de ese día:

```bash
cd dbt
../.venv/bin/dbt build --full-refresh --vars '{run_date: 2026-01-31}'   # hasta el 31/1
../.venv/bin/dbt build --vars '{run_date: 2026-02-01}'                  # suma el 1/2 (incremental)
```

En el dashboard, esto mismo se hace desde el panel lateral: **"Procesar hasta esta fecha"**.

### Correr las consultas de negocio

```bash
duckdb -readonly data/warehouse.duckdb < queries/03b_ingresos_por_categoria.sql
```

Para explorar con la UI web de DuckDB: `duckdb -init scripts/explore.sql -ui`. Adjunta
bronze (`ecom`) y el warehouse (`wh`) en solo lectura. Cerrala antes de correr dbt: DuckDB
admite un solo proceso escribiendo a la vez.

---

## Estructura del repositorio

```
craftech-data-engineering/
├── README.md
├── decision-log.txt              registro de decisiones D001…, con roadmap
├── requirements.txt              versiones fijas: dbt-core, dbt-duckdb, duckdb, streamlit
├── Dockerfile                    imagen única: Python + dbt + paquetes dbt + app
├── docker-compose.yml            servicios pipeline (batch) y dashboard
├── .dockerignore / .gitignore
│
├── data/
│   ├── ecommerce.duckdb          FUENTE (bronze), tal como la entregaron; nunca se escribe
│   └── warehouse.duckdb          SALIDA (silver + gold), la genera dbt; no se versiona
│
├── catalog/bronze/               catálogo de datos de raw
│   ├── README.md                 índice, relaciones, hallazgos de calidad
│   └── customers.md, products.md, orders.md, order_items.md
│
├── dbt/                          proyecto dbt (se corre desde esta carpeta)
│   ├── dbt_project.yml           nombre del proyecto y config por carpeta (schema, materialización)
│   ├── profiles.yml              conexión: escribe en warehouse.duckdb y adjunta ecommerce.duckdb como "bronze"
│   ├── packages.yml              dbt_utils
│   ├── models/
│   │   ├── bronze/_sources.yml   declara las tablas raw y sus tests de contrato
│   │   ├── silver/               1 modelo por tabla raw: limpieza, dedup, incremental
│   │   │   ├── silver_customers.sql, silver_products.sql
│   │   │   ├── silver_orders.sql, silver_order_items.sql
│   │   │   └── _silver.yml       tests y descripción de silver
│   │   └── gold/                 modelo de negocio
│   │       ├── gold_fct_orders.sql, gold_fct_order_items.sql
│   │       ├── gold_dim_customers.sql, gold_dim_products.sql
│   │       └── _gold.yml         tests y descripción de gold
│   ├── macros/
│   │   ├── run_date_filter.sql   simula "hoy" con --vars run_date
│   │   └── generate_schema_name.sql  schemas "silver"/"gold" (no "main_silver")
│   └── tests/                    tests singulares (SQL que devuelve las filas que violan algo)
│
├── queries/                      1 archivo = 1 respuesta de negocio (los usa el dashboard)
│   ├── 01a_clientes_resumen.sql, 01b_clientes_crecimiento_mensual.sql
│   ├── 02a_ventas_por_dia.sql, 02b_ventas_por_semana.sql
│   ├── 03a_ingresos_total.sql, 03b_ingresos_por_categoria.sql
│   └── 04_estado_ordenes.sql
│
├── app/streamlit_app.py          dashboard + botón "procesar hasta esta fecha"
├── airflow/dags/ecommerce_daily.py   DAG de ejemplo (no se ejecuta en el compose)
├── scripts/explore.sql           init de DuckDB UI: adjunta bronze y warehouse en solo lectura
└── docs/dbt.md                   guía de estudio de dbt aplicada a este caso
```

### Cómo se conectan las piezas

1. **`data/ecommerce.duckdb`** es bronze. dbt lo adjunta en solo lectura con el alias
   `bronze` (`profiles.yml`), y `models/bronze/_sources.yml` lo declara como `source('raw', …)`.
2. **`dbt/models/silver/`** lee bronze con `source()` y escribe el schema `silver` en
   `data/warehouse.duckdb`.
3. **`dbt/models/gold/`** lee silver con `ref()` y escribe el schema `gold` en el mismo archivo.
4. **`queries/`** consulta solo `gold`. Es la capa que ve el negocio.
5. **`app/streamlit_app.py`** ejecuta esos mismos `.sql`. El botón corre `dbt build` con un
   `run_date`, y vuelve al paso 2.
6. **`docker-compose.yml`**: el servicio `pipeline` hace los pasos 1 a 3. El servicio
   `dashboard` hace el paso 5 y arranca solo cuando el pipeline terminó bien.
7. **`airflow/dags/`** describe cómo se dispararían los pasos 1 a 3 todos los días en producción.

### Por dónde empezar a leer

| Si querés entender… | Leé |
|---|---|
| qué datos llegan y qué problemas tienen | `catalog/bronze/README.md` |
| cómo se limpian | `dbt/models/silver/silver_orders.sql` (dedup + incremental) |
| cómo se calculan las métricas | `dbt/models/gold/gold_fct_orders.sql` y `queries/` |
| por qué se hizo así | `decision-log.txt` |
| dbt desde cero | `docs/dbt.md` |

## Modelo de datos

| Capa | Modelo | Grano | Notas |
|---|---|---|---|
| silver | `silver_customers` | 1 fila por cliente | 1:1 con raw |
| silver | `silver_products` | 1 fila por producto | 1:1 con raw |
| silver | `silver_orders` | 1 fila por **evento** de orden | dedup; incremental |
| silver | `silver_order_items` | 1 fila por línea de orden | dedup; incremental |
| gold | `gold_fct_orders` | 1 fila por orden | estado actual, fechas clave, monto, ingreso |
| gold | `gold_fct_order_items` | 1 fila por línea | precio, monto de línea, categoría |
| gold | `gold_dim_customers` | 1 fila por cliente | cantidad de órdenes, primera y última compra, `is_active` |
| gold | `gold_dim_products` | 1 fila por producto | |

Hay **54 tests** de dbt: contrato con la fuente, unicidad de cada grano, not null, valores
aceptados, integridad referencial, montos positivos, y que gold no pierda líneas contra silver.
Los tests clave se validaron rompiendo el código a propósito y comprobando que fallan (ver
`decision-log.txt`, D020 y D025).

## Respuestas (datos completos, fecha de corte 2026-07-01)

| Pregunta | Consulta | Resultado |
|---|---|---|
| 1. Clientes | `01a_clientes_resumen.sql`, `01b_clientes_crecimiento_mensual.sql` | 600 registrados, 399 con compras, **398 activos** (66,33%). Crecimiento mensual por fecha de registro, desde 2025-07. |
| 2. Ventas | `02a_ventas_por_dia.sql`, `02b_ventas_por_semana.sql` | 3.998 órdenes en 182 días. Semanas ISO; la primera y la última son parciales. |
| 3. Ingresos | `03a_ingresos_total.sql`, `03b_ingresos_por_categoria.sql` | **USD 3.502.509,72** de 3.252 órdenes entregadas. electronics 55,17%, home 18,32%, sports 16,60%, beauty 5,76%, books 4,14%. Hay USD 184.227,73 más en órdenes en curso. |
| 4. Órdenes | `04_estado_ordenes.sql` | **81,34% entregadas**, **10,86% canceladas**, 3,58% devueltas, 4,23% en curso. |

---

## Decisiones y supuestos

El detalle completo, con alternativas descartadas, está en
[`decision-log.txt`](decision-log.txt). Estas son las principales.

### Sobre los datos (ver [`catalog/bronze/`](catalog/bronze/README.md))

1. **`orders` es un log de eventos, no una tabla de órdenes.** Tiene 15.608 filas para 3.998
   órdenes. El estado actual es el **último evento por `event_at`**, no por `_ingested_at`:
   ordenar por llegada cambia el estado de 65 órdenes, porque hay eventos que llegan tarde.
2. **Re-entregas.** El mismo evento llega más de una vez y solo cambia `_ingested_at`: 443
   copias en `orders` y 205 en `order_items`. Silver deduplica por la clave de negocio
   (`order_id, status, event_at` y `order_id, line_number`) y se queda con la **primera
   llegada**. Sin deduplicar, el ingreso se infla un 2,9%.
3. **No hay precio de venta.** El monto se calcula como `quantity × unit_price` usando el
   **precio de lista actual** de `products`. Si un producto cambió de precio después de la
   venta, el ingreso no refleja el precio real. Es el principal supuesto del modelo.
4. **Moneda única (USD) y timestamps sin zona horaria.** Se usan tal cual.
5. **5 órdenes no tienen evento `created`** (ni líneas). Se toma como fecha de orden su
   primer evento conocido y se marcan con `has_created_event = false`.

### Definiciones de negocio

| Concepto | Definición |
|---|---|
| **Venta** | orden creada, contada en su fecha de creación, aunque después se cancele |
| **Ingreso** | monto de las órdenes cuyo estado actual es `delivered`. Se excluyen las canceladas, las devueltas (se asume reembolso) y las que están en curso |
| **Cliente activo** | al menos una orden no cancelada en los **90 días** previos a la fecha de corte |
| **Crecimiento de clientes** | clientes nuevos por mes según la fecha de registro, y acumulado |

Con estos datos, la definición de cliente activo a 90 días casi no discrimina: 398 de 399
clientes con compras quedan activos. Con 30 días serían 371. Se mantuvo 90 días por ser el
estándar en e-commerce, pero conviene revisarla con negocio.

### Diseño

- **Bronze no se toca.** dbt escribe en un archivo propio (`warehouse.duckdb`) y adjunta
  `ecommerce.duckdb` en solo lectura.
- **Silver = 1 modelo por tabla raw, sin joins.** Limpieza liviana en un solo paso. Los joins
  y las reglas de negocio, como el precio, viven en gold.
- **Nombres medallion** (`silver_*`, `gold_*`) en lugar de la convención dbt
  `stg_`/`fct_`/`dim_`. Son equivalentes: staging = silver, marts = gold.
- **Incremental** en `silver_orders` y `silver_order_items`: `delete+insert` por clave de
  negocio, lectura por `_ingested_at` con **2 días de lookback** para cubrir llegadas tardías
  (hasta ~48 h), y un **anti-join** para que una re-entrega posterior no reemplace a la
  primera llegada. Las dimensiones (customers, products) son fotos completas y gold se
  reconstruye entero en cada corrida, porque es barato.
- **Prueba del incremental:** 182 corridas diarias más una repetición del último día dan un
  resultado **idéntico** al de un full-refresh (0 filas de diferencia en silver y gold).
- **Dashboard sin lógica propia:** ejecuta los mismos `.sql` de `queries/`, así que el número
  del dashboard es el de la consulta entregada.

---

## Orquestación en producción

En [`airflow/dags/ecommerce_daily.py`](airflow/dags/ecommerce_daily.py) hay un DAG de
ejemplo para Airflow 3. No forma parte del compose ni se ejecutó.

```
check_bronze  ──►  build_silver  ──►  build_gold
dbt test          dbt build           dbt build
source:raw        --select silver     --select gold
```

- **Schedule:** diario a las 04:00, después de que la extracción llega a raw (~03:00).
  `run_date` = el día anterior completo, pasado a dbt con `--vars`.
- **`max_active_runs=1`:** DuckDB acepta un solo proceso escribiendo, así que las corridas van
  en serie.
- **`catchup=True`:** el backfill se hace día por día. Como el pipeline es idempotente,
  reintentar o re-correr un día es seguro.
- **Fallas:** `retries=2`. Si falla un test de bronze o de silver, gold no se construye y el
  dashboard sigue mostrando la última versión buena. Habría que sumar alertas (Slack o email)
  con `on_failure_callback`.
- **Ejecución:** cada tarea correría en la imagen del `Dockerfile`, por ejemplo con
  `KubernetesPodOperator` o `DockerOperator`, para que Airflow no tenga que instalar dbt.
  Una alternativa es [astronomer-cosmos](https://github.com/astronomer/astronomer-cosmos),
  que expone cada modelo dbt como una tarea propia de Airflow.
- **Con más volumen:** DuckDB local deja de alcanzar cuando varios procesos tienen que
  escribir a la vez. El mismo proyecto dbt se puede llevar a MotherDuck, o a
  Snowflake/BigQuery cambiando el adapter. El `refresh` del dashboard dispararía el DAG
  mediante la API REST de Airflow, en lugar de correr dbt directamente.

---

## Uso de IA

Usé **Claude Code** (extensión de VS Code, modelo principal Claude Opus 5.5) como par de
trabajo durante toda la prueba. No lo usé como generador de una sola vez: trabajamos paso a
paso, discutiendo cada decisión antes de escribir código.

### Cómo se organizó el trabajo

| Etapa | Qué hizo la IA | Herramienta |
|---|---|---|
| Arquitectura | Discutimos medallion, Docker, el alcance de Airflow y cómo simular el batch diario. Me hizo preguntas y propuso alternativas con sus trade-offs; yo decidí. | skill `superpowers:brainstorming` |
| Exploración de bronze | Perfiló las 4 tablas de `raw` (tipos, nulos, duplicados, metadatos de ingesta, secuencias de estados) y escribió el catálogo de [`catalog/bronze/`](catalog/bronze/README.md). En paralelo, yo exploré con la UI de DuckDB. | subagente `researcher` (modelo Sonnet), en segundo plano |
| Verificación del catálogo | El agente principal recalculó por otro camino las cifras clave del subagente (filas, duplicados, ingreso, estados) antes de usarlas para diseñar. | DuckDB CLI |
| Silver y gold | Escribió los modelos dbt y sus tests de a un archivo, explicando cada concepto nuevo. Las definiciones de negocio (venta, ingreso, cliente activo) las elegí yo entre opciones que la IA presentó con su impacto en los números. | dbt |
| Dashboard | Diseñó los gráficos siguiendo una guía de visualización: forma según el dato, una serie por gráfico, tabla de respaldo para cada uno. | skill `dataviz` |
| Pruebas | Rompió cada test importante a propósito para confirmar que falla. Comparó 182 corridas incrementales contra un full-refresh y saboteó el incremental para confirmar que esa comparación detecta errores. Probó el dashboard con `streamlit.testing` (AppTest) y `docker compose up` sobre una copia limpia del repo. | dbt, DuckDB, AppTest, Docker |
| Documentación | Este README, el DAG de ejemplo y la guía de estudio de dbt. | — |

### Memoria del proyecto

- **[`decision-log.txt`](decision-log.txt):** la IA registró cada decisión (D001…D033) con
  su razón, las alternativas descartadas y quién la propuso (yo, la IA o la consigna). Lo
  usamos como índice de memoria entre sesiones y como roadmap.
- **[`docs/dbt.md`](docs/dbt.md):** no sabía usar dbt antes de esta prueba. La IA fue
  armando esta guía con los conceptos aplicados a este caso (sources, refs, materializaciones,
  tests, incremental, `QUALIFY`), más preguntas de repaso para la entrevista.

### Qué decidí yo y qué propuso la IA

- **Mías:** medallion, Docker, dbt, Airflow solo como ejemplo, Streamlit con el selector
  "procesar hasta esta fecha", nombres `silver_`/`gold_`, mover el cálculo del precio de
  silver a gold, y las tres definiciones de negocio.
- **Propuestas por la IA y aceptadas:**
  - escribir en un warehouse separado y dejar bronze en solo lectura;
  - simular el batch diario con `run_date`;
  - la clave del dedup y quedarse con la primera llegada;
  - el anti-join del incremental;
  - que el dashboard ejecute las mismas queries entregadas.
- **Advertencias de la IA que quedaron documentadas:** que la definición de cliente activo
  a 90 días casi no discrimina, que el ingreso usa el precio actual, y las limitaciones de
  DuckDB con más de un proceso escribiendo.

## Limitaciones y próximos pasos

- Precio histórico: con una tabla de precios por fecha, o el precio en `order_items`, el
  ingreso sería exacto.
- SCD tipo 2 para clientes y productos (`dbt snapshot`) si la fuente empieza a mandar cambios.
- `dbt source freshness` sobre `_ingested_at` para alertar si la extracción se atrasa.
- Si dos personas tocan el botón del dashboard a la vez, la segunda corrida falla por el lock
  de DuckDB, sin dañar datos. En producción eso se resuelve con Airflow.
- Documentación navegable con lineage: `cd dbt && dbt docs generate && dbt docs serve`.
