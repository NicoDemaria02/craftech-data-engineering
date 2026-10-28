# dbt: guía de estudio para este proyecto

Guía viva: se va completando a medida que construimos. Los ejemplos son de **este** caso
(e-commerce, DuckDB, medallion bronze → silver → gold).

---

## 1. Qué es dbt, en una frase

dbt toma archivos `.sql` que contienen **solo un `SELECT`** y se encarga de convertirlos en
tablas o vistas dentro de la base, en el orden correcto, con tests y documentación.

Vos no escribís `CREATE TABLE`, `INSERT` ni `MERGE`: escribís *qué* datos querés y dbt
resuelve el *cómo*.

> dbt es la **T** de ELT. No extrae ni carga datos: transforma lo que ya está en la base.
> En este caso, la E y la L ya están hechas, y su resultado es el schema `raw` del `.duckdb`.

## 2. Medallion en dbt

| Capa | Qué es | En dbt | En este proyecto |
|---|---|---|---|
| **bronze** | datos tal cual llegan | `source` (no es un modelo, se declara en un `.yml`) | schema `raw`: `customers`, `products`, `orders`, `order_items` |
| **silver** | limpio, tipado, deduplicado | modelos en `models/silver/` | `silver_orders`, `silver_order_items`, `silver_customers`, `silver_products` |
| **gold** | listo para el negocio | modelos en `models/gold/` | dims, facts y métricas (a definir) |

La convención de la comunidad dbt nombra estas capas `staging` / `intermediate` / `marts`
y usa prefijos `stg_`, `int_`, `fct_` y `dim_`. Acá elegimos `silver` / `gold` (D015).
Si en la entrevista te preguntan por esto, es lo mismo con otro nombre.

## 3. Estructura del proyecto

```
dbt_project.yml        # nombre del proyecto + config por carpeta (ej: silver = table)
profiles.yml           # conexión: tipo duckdb, path al archivo .duckdb
models/
  bronze/_sources.yml  # declara las tablas de raw como sources
  silver/
    _silver.yml        # tests + descripción de cada modelo silver
    silver_orders.sql
    silver_order_items.sql
  gold/
    ...
tests/                 # tests "singulares": un SELECT que devuelve las filas que violan algo
macros/                # funciones Jinja reutilizables
```

- **`dbt_project.yml`**: el "main" del proyecto.
- **`profiles.yml`**: credenciales y conexión. Normalmente vive en `~/.dbt/`; acá lo
  dejamos en el repo porque DuckDB es un archivo local y no hay secretos.

## 4. Las dos funciones que más vas a usar

### `source()`: leer bronze

```sql
select * from {{ source('raw', 'orders') }}
```

dbt lo reemplaza por `"ecommerce"."raw"."orders"`. Funciona porque en `_sources.yml` se
declaró:

```yaml
sources:
  - name: raw
    tables:
      - name: orders
      - name: order_items
```

### `ref()`: leer otro modelo

```sql
select * from {{ ref('silver_orders') }}
```

Con esto dbt **arma el grafo** (DAG): sabe que el modelo gold depende de `silver_orders`,
lo corre después y dibuja el lineage en `dbt docs`.

> **Regla de oro:** nunca escribas el nombre de una tabla a mano. Siempre usá `source` o `ref`.
> Si lo escribís a mano, dbt no se entera de la dependencia.

Las `{{ }}` son **Jinja**, un lenguaje de templates. dbt primero "compila" el Jinja a SQL
puro (lo deja en `target/compiled/`) y después lo ejecuta.

## 5. Materializaciones: cómo se guarda cada modelo

Se configuran en `dbt_project.yml` (por carpeta) o arriba del modelo con
`{{ config(materialized='...') }}`.

| Tipo | Qué hace | Cuándo |
|---|---|---|
| `view` | crea una vista; recalcula en cada consulta | modelos livianos |
| `table` | borra y recrea la tabla entera en cada corrida | default razonable si es chico |
| `incremental` | en la primera corrida crea la tabla; después solo procesa lo nuevo | datos grandes o que llegan por día (ver §8) |
| `ephemeral` | no crea nada; se inyecta como CTE en quien lo use | pasos intermedios |

## 6. Caso real: duplicados en `orders`

`orders` es un **log de eventos**: cada orden tiene varias filas, una por cambio de estado.
Eso NO es duplicado. Ejemplo real (O000005):

| status | event_at | _ingested_at | |
|---|---|---|---|
| created | 2026-01-01 08:24:02 | 2026-01-01 08:32:58 | evento legítimo |
| created | 2026-01-01 08:24:02 | 2026-01-02 20:08:47 | **copia**: mismo evento, llegó otra vez |
| paid | 2026-01-01 09:06:02 | 2026-01-01 09:19:58 | evento legítimo |
| shipped | 2026-01-03 12:06:02 | 2026-01-04 21:49:30 | evento legítimo (llegó 33 h tarde) |
| delivered | 2026-01-09 12:06:02 | 2026-01-11 06:15:48 | evento legítimo |
| returned | 2026-01-15 12:06:02 | 2026-01-15 12:17:39 | evento legítimo |

- **Duplicado** = misma `(order_id, status, event_at)`, distinto `_ingested_at`.
- Números: 15.608 filas → 15.165 eventos únicos (443 copias, en 426 órdenes).

### Opciones para deduplicar

```sql
-- ❌ no sirve: las copias difieren en _ingested_at
select distinct * from raw.orders

-- ❌ no sirve: colapsa los eventos legítimos, deja 1 fila por orden
... group by order_id

-- ✅ funciona, pero hay que listar columnas
select order_id, customer_id, status, event_at, min(_ingested_at) as _ingested_at
from raw.orders
group by order_id, customer_id, status, event_at

-- ✅ elegido (D012): conserva todas las columnas, se queda con la primera llegada
select *
from {{ source('raw', 'orders') }}
qualify row_number() over (
    partition by order_id, status, event_at
    order by _ingested_at
) = 1
```

- `row_number() over (partition by ... order by ...)` numera las filas 1, 2, 3… dentro de
  cada grupo.
- `qualify` filtra sobre ese número; es como un `where` para window functions.

Para `order_items`, la clave es `(order_id, line_number)`.

### ¿Son "duplicados" de verdad?

Técnicamente no son filas idénticas, porque cambia `_ingested_at`. Pero el **hecho de
negocio** es el mismo: el mismo evento llegó dos veces. Lo produce una extracción
*at-least-once*: ante la duda, el sistema reenvía, y prefiere repetir antes que perder.
Por eso es seguro quedarse con una copia: no se pierde información de negocio, solo la
fecha de la segunda llegada.

### `QUALIFY` + `row_number()` paso a paso

`row_number()` es una **window function**: calcula un valor por fila mirando un grupo
("ventana") de filas, **sin colapsarlas** como hace `group by`.

```sql
row_number() over (partition by order_id, status, event_at order by _ingested_at)
```

- `partition by ...` arma un grupo por cada evento de negocio.
- `order by _ingested_at` ordena dentro del grupo, de la primera llegada a la última.
- `row_number()` numera 1, 2, 3… dentro de cada grupo.

Aplicado a O000005:

| status | event_at | _ingested_at | row_number |
|---|---|---|---|
| created | 2026-01-01 08:24:02 | 2026-01-01 08:32:58 | **1** ✅ |
| created | 2026-01-01 08:24:02 | 2026-01-02 20:08:47 | 2 ❌ |
| paid | 2026-01-01 09:06:02 | 2026-01-01 09:19:58 | **1** ✅ |
| shipped | 2026-01-03 12:06:02 | 2026-01-04 21:49:30 | **1** ✅ |
| delivered | 2026-01-09 12:06:02 | 2026-01-11 06:15:48 | **1** ✅ |
| returned | 2026-01-15 12:06:02 | 2026-01-15 12:17:39 | **1** ✅ |

`qualify ... = 1` se queda con las filas marcadas con 1.

**¿Por qué `QUALIFY`?** SQL ejecuta `WHERE` **antes** de calcular las window functions, así
que `where row_number() over (...) = 1` da error. `QUALIFY` es el filtro que corre
**después** de calcularlas. Sin `QUALIFY` (por ejemplo, en Postgres) hay que envolver la
consulta:

```sql
select * from (
    select *, row_number() over (partition by order_id, status, event_at
                                 order by _ingested_at) as rn
    from raw.orders
) where rn = 1
```

`QUALIFY` existe en DuckDB, Snowflake, BigQuery y Databricks, pero **no** en Postgres ni en
MySQL.

**¿Primera o última llegada?** Las copias son idénticas, así que el resultado de negocio es
el mismo. Elegimos la **primera** (`order by _ingested_at` ascendente) porque es estable: si
mañana llega una tercera copia, la fila que ya guardamos no cambia.

Otras window functions útiles para este caso: `rank()`, `lag()` / `lead()` (evento anterior
o siguiente de la misma orden) y `arg_max(status, event_at)`, que da el último estado de cada
orden y es específica de DuckDB.

## 7. Tests: probar que el dedup funcionó

En `_silver.yml`:

```yaml
models:
  - name: silver_orders
    description: Eventos de órdenes deduplicados (1 fila por evento).
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns: [order_id, status, event_at]
    columns:
      - name: order_id
        tests: [not_null]
      - name: status
        tests:
          - accepted_values:
              values: [created, paid, shipped, delivered, cancelled, returned]
```

| Tipo de test | Ejemplo |
|---|---|
| genéricos incluidos en dbt | `unique`, `not_null`, `accepted_values`, `relationships` (FK) |
| de paquetes | `dbt_utils.unique_combination_of_columns` |
| singulares | un `.sql` en `tests/` que devuelve las filas malas; si devuelve algo, falla |

Cómo funciona por dentro: cada test es un `SELECT` que busca **violaciones**. Si devuelve
0 filas, pasa.

> **Truco para validar un test:** sacá el `qualify` del modelo y corré `dbt test`. El test
> de unicidad **tiene que fallar**. Si no falla, el test no está probando nada.

## 8. Incremental (lo más preguntado en entrevistas)

```sql
{{ config(materialized='incremental', unique_key=['order_id', 'status', 'event_at']) }}

select * from {{ source('raw', 'orders') }}
where _ingested_at <= '{{ var("run_date") }}'
{% if is_incremental() %}
  -- solo lo que llegó desde la última corrida, menos 2 días de lookback
  and _ingested_at > (select max(_ingested_at) - interval 2 day from {{ this }})
{% endif %}
qualify row_number() over (partition by order_id, status, event_at order by _ingested_at) = 1
```

- **`is_incremental()`**: es `false` en la primera corrida o con `--full-refresh` (procesa
  todo), y `true` cuando la tabla ya existe (procesa solo lo nuevo).
- **`{{ this }}`**: la tabla que este mismo modelo ya creó.
- **`unique_key`**: si una fila nueva tiene una clave que ya existe, la reemplaza en lugar
  de duplicarla. Eso hace que reprocesar sea seguro (**idempotencia**).
- **Lookback de 2 días**: hay eventos que llegan hasta ~48 h tarde. Re-leer esa ventana
  asegura no perderlos, y `unique_key` evita duplicarlos.
- **¿Por qué filtrar por `_ingested_at` y no por `event_at`?** Porque la pregunta del
  incremental es "¿qué **llegó** nuevo?", no "¿qué **pasó** nuevo?". Si filtrás por
  `event_at`, un evento del lunes que llega el miércoles nunca entra.
- **`var("run_date")`**: simula "hoy" (D009). Se pasa con
  `dbt build --vars '{run_date: 2026-01-15}'`.

**Prueba de oro del incremental:** correr día por día desde el 2026-01-01 hasta el
2026-07-01 tiene que dar exactamente lo mismo que una sola corrida con `--full-refresh`.

### Cómo quedó en este proyecto (D027)

Usamos `incremental_strategy='delete+insert'`: dbt borra de la tabla las claves que
vienen en el lote nuevo y después las inserta.

Al esquema de arriba le agregamos un **anti-join**:

```sql
{% if is_incremental() %}
    and src._ingested_at > (select max(_ingested_at) - interval 2 day from {{ this }})
    and not exists (
        select 1 from {{ this }} as cur
        where cur.order_id = src.order_id
          and cur.status = src.status
          and cur.event_at = src.event_at
    )
{% endif %}
```

**¿Por qué?** Sin el anti-join, si la segunda copia de un evento llega en un lote posterior,
`delete+insert` reemplaza la primera llegada por la segunda: cambia `_ingested_at` y el
resultado ya no es igual al del full-refresh. Lo comprobamos rompiéndolo: en enero solo
quedaban 34 eventos distintos.

El filtro de `run_date` vive en una macro propia, `macros/run_date_filter.sql`:

```sql
where {{ run_date_filter('src._ingested_at') }}
-- con run_date: src._ingested_at < cast('2026-03-15' as date) + interval 1 day
-- sin run_date: true
```

**Resultado:** 182 corridas diarias (+ repetir el último día) == 1 full-refresh, con 0 filas de
diferencia en silver y gold.

**Volver atrás en el tiempo:** un incremental solo **agrega**. Si ya procesaste hasta julio y
querés ver "cómo estaba en marzo", tenés que reconstruir con
`--full-refresh --vars '{run_date: 2026-03-31}'`. El botón de Streamlit lo hace solo.

### `env_var()`: config que cambia por entorno

```yaml
path: "{{ env_var('WAREHOUSE_PATH', '../data/warehouse.duckdb') }}"
```

Lee una variable de entorno, con un valor por defecto si no está definida. Es la forma
estándar de pasarle a dbt rutas, credenciales o el entorno (dev/prod) sin tocar los
archivos.

## 9. Comandos

| Comando | Qué hace |
|---|---|
| `dbt debug` | verifica conexión y config |
| `dbt deps` | instala paquetes (`dbt_utils`) definidos en `packages.yml` |
| `dbt run` | construye modelos |
| `dbt test` | corre tests |
| `dbt build` | run + test (+ seeds y snapshots) en orden del DAG; si un test falla, no construye lo que depende de él |
| `dbt build --select silver_orders+` | ese modelo y todo lo que depende de él (`+` adelante = sus padres) |
| `dbt build --full-refresh` | recrea los incrementales desde cero |
| `dbt compile` | solo genera el SQL compilado en `target/` (útil para ver qué ejecuta) |
| `dbt docs generate && dbt docs serve` | sitio web con documentación + grafo de lineage |

## 10. Preguntas probables en la entrevista

- ¿Qué diferencia hay entre `source` y `ref`?
- ¿Por qué `table` y no `view` (o `incremental`) en tal modelo?
- ¿Cómo garantizás que el dedup funciona? → test de unicidad + validarlo rompiéndolo (§7).
- ¿Qué pasa si corrés el pipeline dos veces el mismo día? → idempotencia con `unique_key`.
- ¿Cómo manejás datos que llegan tarde? → filtrar por `_ingested_at` + lookback.
- ¿Cómo hacés backfill? → `--full-refresh`, o Airflow con `catchup` pasando `run_date`.
- ¿Por qué el ingreso no se calcula juntando `order_items` con `orders` crudo? → `orders` tiene
  N eventos por orden; el join multiplica las líneas (×4,05 en este dataset).

## 11. Setup real de este proyecto (sesión 2026-10-28)

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt   # dbt-core 1.12.6, dbt-duckdb 1.11.1
cd dbt
../.venv/bin/dbt debug    # ¿encuentra profiles.yml y conecta?
../.venv/bin/dbt deps     # baja dbt_utils a dbt_packages/
../.venv/bin/dbt build    # modelos + tests
```

### `profiles.yml`: dos bases a la vez

```yaml
path: ../data/warehouse.duckdb        # donde dbt ESCRIBE (silver, gold)
attach:
  - path: ../data/ecommerce.duckdb    # bronze, solo LECTURA
    alias: bronze
    read_only: true
```

DuckDB permite "adjuntar" otro archivo y consultarlo como si fuera otra base
(`bronze.raw.orders`). Por eso en `_sources.yml` el source declara `database: bronze`.

- dbt busca `profiles.yml` primero en la carpeta desde donde lo corrés. Por eso se corre
  desde `dbt/`, y los paths relativos (`../data/...`) parten de ahí.

### Schemas: `generate_schema_name`

Si en `dbt_project.yml` ponés `+schema: silver`, dbt por defecto crea `main_silver`
(`<schema del target>_<custom>`). Lo hace para que cada developer tenga sus propios
schemas sin pisarse. Para que se llame `silver` a secas, se **sobrescribe la macro**
`generate_schema_name` (en `macros/`).

Esto muestra algo importante: buena parte del comportamiento de dbt son macros que podés
reemplazar con una propia del mismo nombre.

### Configuración por carpeta

```yaml
models:
  ecommerce:          # nombre del proyecto
    silver:           # carpeta models/silver
      +schema: silver
      +materialized: table
```

El `+` indica que es una config que se aplica a todo lo que está debajo de esa carpeta.

### Sintaxis de tests (dbt ≥ 1.10)

```yaml
columns:
  - name: segment
    data_tests:
      - accepted_values:
          arguments:            # los parámetros del test van dentro de "arguments"
            values: [retail, wholesale]
```

En tutoriales viejos vas a ver `tests:` y los parámetros sin `arguments:`. Es la sintaxis
anterior.

### Leer la salida de `dbt build`

```
1 of 5 OK created sql table model silver.silver_customers
2 of 5 PASS accepted_values_silver_customers_segment__retail__wholesale
...
Done. PASS=5 WARN=0 ERROR=0 SKIP=0
```

- `SKIP` aparece cuando un modelo no se construye porque falló algo de lo que depende.
- El SQL que dbt ejecutó de verdad queda en `target/run/`. Es útil para debuggear.

### Silver terminado: 4 modelos, 29 tests

| modelo | raw | silver | qué hace |
|---|---|---|---|
| `silver_customers` | 600 | 600 | 1:1 |
| `silver_products` | 80 | 80 | 1:1 |
| `silver_orders` | 15.608 | 15.165 | dedup por (order_id, status, event_at) |
| `silver_order_items` | 7.820 | 7.615 | dedup por (order_id, line_number) |

Tests nuevos que aparecen:

- **`relationships`**: es la FK de dbt. Chequea que cada `customer_id` de `silver_orders`
  exista en `silver_customers`. Como usa `ref()`, dbt sabe que tiene que construir los dos
  modelos antes de correr el test.
- **`dbt_utils.expression_is_true`**: cualquier condición SQL, por ejemplo `quantity > 0`.
- **Test de modelo vs. test de columna**: `unique_combination_of_columns` se declara a
  nivel modelo (`data_tests:` bajo el modelo) porque involucra varias columnas. Los demás se
  declaran bajo cada columna.

**Sabotaje real:** sacamos el `QUALIFY` de los dos modelos y corrimos `dbt build`:

```
FAIL 443 dbt_utils_unique_combination_of_columns_silver_orders_order_id__status__event_at
FAIL 205 dbt_utils_unique_combination_of_columns_silver_order_items_order_id__line_number
```

El número después de `FAIL` es la cantidad de filas que violan el test, y coincide con las
copias que encontró el catálogo. Eso prueba que el test mide lo que dice medir.

**Por qué silver no hace joins (D019):** cada modelo silver lee **una sola** tabla de bronze
y la limpia en un paso. Joins y reglas de negocio, como el precio, van en gold. Es la regla
de dbt "staging = 1:1 con la fuente".

**El WARNING `Configuration paths exist ... which do not apply to any resources`** aparece
porque `dbt_project.yml` configura la carpeta `gold`, pero todavía no tiene modelos.

## 12. Glosario

- **Modelo**: un `.sql` con un `SELECT`; dbt lo convierte en tabla o vista.
- **Source**: una tabla que no crea dbt (bronze), declarada en un `.yml`.
- **DAG**: grafo de dependencias entre modelos, armado con `ref` y `source`.
- **Materialización**: cómo se persiste un modelo (view, table, incremental, ephemeral).
- **Jinja**: templates `{{ }}` y `{% %}`; se compilan a SQL antes de ejecutar.
- **Grano**: qué representa una fila. Ejemplo: `silver_orders` = 1 fila por evento de orden.
- **Idempotencia**: correr dos veces da el mismo resultado que correr una.
