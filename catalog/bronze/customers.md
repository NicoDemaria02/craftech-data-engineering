# `raw.customers`

> Catálogo de la capa bronze · [← Volver al índice](README.md) · Fuente: `data/ecommerce.duckdb` (solo lectura) · Generado el 2026-10-27

Dimensión de clientes. Es una **foto única** (snapshot) tomada en una sola extracción: no guarda historial de cambios, aunque tenga `updated_at`.

| Propiedad | Valor |
|---|---|
| Filas | 600 |
| Grano | Una fila por cliente (verificado abajo). |
| Clave primaria candidata | `customer_id` (600 distintos sobre 600 filas, 0 nulos) |
| Metadatos de carga | Solo `_extracted_at` (no tiene `_ingested_at`) |
| Lotes de extracción | 1 (`2026-07-01 03:00:00`, 600 filas) |
| Constraints declarados en la base | 0 (sin PK, FK, UNIQUE ni NOT NULL) |


## Grano y clave primaria

| Verificación | Resultado |
|---|---|
| `count(*)` | 600 |
| `count(distinct customer_id)` | 600 |
| `count(distinct <fila completa>)` | 600 |
| `customer_id` con formato `^C[0-9]{5}$` | 600 de 600 |
| Rango numérico del id | 1 a 600 (600 valores: sin huecos) |

Conclusión: `count(*)` = `count(distinct customer_id)` = 600, por lo tanto **`customer_id` es clave primaria** y el grano es un cliente por fila. La base no la declara (ver ficha); hoy se cumple por los datos, no por una restricción.


## Columnas

| Columna | Tipo DuckDB | Nulos (n y %) | Distintos | Min / Max (o valores si ≤ 10 distintos) | Ejemplos | Notas |
|---|---|---|---|---|---|---|
| `customer_id` | `VARCHAR` | 0 (0.00%) | 600 | `C00001` / `C00600` | `C00001`, `C00002`, `C00003` | PK candidata. Formato `C` + 5 dígitos, correlativo 1–600. |
| `first_name` | `VARCHAR` | 0 (0.00%) | 20 | `Ana` / `Valentina` | `Luis`, `Lucía`, `Ana` | Texto en formato Title Case (20 valores distintos). Con tildes (UTF-8). |
| `last_name` | `VARCHAR` | 0 (0.00%) | 20 | `Castro` / `Vargas` | `Castro`, `Romero`, `Pérez` | Texto en formato Title Case (20 valores distintos). Con tildes (UTF-8). |
| `email` | `VARCHAR` | 0 (0.00%) | 600 | `ana.flores437@example.com` / `valentina.vargas83@example.com` | `luis.castro1@example.com`, `lucia.romero2@example.com`, `ana.perez3@example.com` | Único, válido y de un solo dominio (`example.com`). El número antes de `@` coincide con el del `customer_id` en 600 de 600 filas. Dato de apariencia sintética; tratar como PII. |
| `country_code` | `VARCHAR` | 0 (0.00%) | 7 | `AR` (207); `MX` (118); `CO` (88); `CL` (59); `UY` (45); `PE` (43); `ES` (40) | `CL`, `MX`, `AR` | Código de país de 2 letras en mayúsculas. Es un enum guardado como `VARCHAR`: conviene un test `accepted_values`. |
| `segment` | `VARCHAR` | 0 (0.00%) | 2 | `retail` (509); `wholesale` (91) | `wholesale`, `retail` | Enum guardado como `VARCHAR` (`retail` / `wholesale`). Condiciona el comportamiento de compra (ver [order_items](order_items.md)). |
| `created_at` | `TIMESTAMP` | 0 (0.00%) | 600 | `2025-07-02 10:46:34` / `2026-06-30 22:22:51` | `2025-08-27 20:00:52`, `2026-02-13 20:22:40`, `2026-03-31 06:14:33` | Fecha de alta del cliente (se asume; la tabla no lo documenta). `TIMESTAMP` sin zona horaria. Base para el crecimiento mensual. |
| `updated_at` | `TIMESTAMP` | 0 (0.00%) | 600 | `2025-07-02 10:46:34` / `2026-06-30 22:22:51` | `2025-10-07 06:07:25`, `2026-02-13 20:22:40`, `2026-03-31 06:14:33` | Última modificación. Igual a `created_at` en 323 filas (53.83%); posterior en 277; nunca anterior. |
| `_extracted_at` | `TIMESTAMP` | 0 (0.00%) | 1 | `2026-07-01 03:00:00` (600) | `2026-07-01 03:00:00` | Metadato: momento en que se tomó del origen. Valor único para toda la tabla. |


## Calidad de formato y dominios

Todos los campos ya vienen con el tipo correcto (`TIMESTAMP` para fechas, `VARCHAR` para ids y textos). No hay fechas ni números guardados como texto. Los chequeos de texto dieron limpio:

| Chequeo | Filas afectadas | Observación |
|---|---|---|
| Espacios al inicio o al final en cualquier columna de texto | 0 |  |
| Strings vacíos (`''`) en cualquier columna de texto | 0 |  |
| Emails que no cumplen `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$` | 0 |  |
| Emails duplicados (sin distinguir mayúsculas ni espacios) | 0 |  |
| Nombres/apellidos fuera de Title Case (`^[A-ZÁÉÍÓÚÑ][a-záéíóúñü]+$`) | 0 |  |
| `country_code` fuera de `^[A-Z]{2}$` | 0 | Valores: `AR` (207), `MX` (118), `CO` (88), `CL` (59), `UY` (45), `PE` (43), `ES` (40) |
| `segment` fuera de {`retail`, `wholesale`} | 0 | Valores: `retail` (509), `wholesale` (91) |


## Fechas

| Chequeo | Resultado |
|---|---|
| Rango de `created_at` | `2025-07-02 10:46:34` a `2026-06-30 22:22:51` |
| Rango de `updated_at` | `2025-07-02 10:46:34` a `2026-06-30 22:22:51` |
| `updated_at` < `created_at` | 0 |
| `created_at` o `updated_at` > `_extracted_at` (fechas futuras respecto de la extracción) | 0 y 0 |
| Brecha entre `_extracted_at` y el mayor `updated_at` | 4 h 37 min |
| Pedidos cuyo primer evento es anterior al `created_at` del cliente | 0 |

Las fechas son `TIMESTAMP` sin zona horaria: no hay forma de saber en qué zona están expresadas. El día calendario de un alta puede cambiar según la zona que se asuma.

**Altas por mes** (base para la pregunta de crecimiento mensual de clientes). `Crec. del acumulado` = nuevos del mes / acumulado del mes anterior.

| Mes de `created_at` | Clientes nuevos | Acumulado | Crec. del acumulado vs mes anterior |
|---|---|---|---|
| 2025-07 | 26 | 26 | — |
| 2025-08 | 28 | 54 | 107.7% |
| 2025-09 | 32 | 86 | 59.3% |
| 2025-10 | 22 | 108 | 25.6% |
| 2025-11 | 24 | 132 | 22.2% |
| 2025-12 | 35 | 167 | 26.5% |
| 2026-01 | 43 | 210 | 25.7% |
| 2026-02 | 49 | 259 | 23.3% |
| 2026-03 | 66 | 325 | 25.5% |
| 2026-04 | 77 | 402 | 23.7% |
| 2026-05 | 85 | 487 | 21.1% |
| 2026-06 | 113 | 600 | 23.2% |

Total: 600 clientes; 167 dados de alta en 2025 (jul–dic) y 433 en 2026 (ene–jun). Los nuevos clientes por mes pasan de 26 en 2025-07 a 113 en 2026-06.


## Duplicados y versiones

| Chequeo | Resultado |
|---|---|
| Filas exactamente duplicadas | 0 |
| Claves de negocio (`customer_id`) repetidas | 0 |
| Versiones por clave | 1 (máximo 1) |
| Valores distintos de `_extracted_at` | 1 |

No hay re-extracciones: cada cliente aparece una sola vez y con una sola `_extracted_at`. Hay 277 clientes con `updated_at` > `created_at`, es decir que cambiaron alguna vez, pero solo está disponible su última versión; no se puede reconstruir qué valor tenían antes (país, segmento, email).


## Metadatos de carga

| `_extracted_at` | Filas |
|---|---|
| `2026-07-01 03:00:00` | 600 |

La tabla **no tiene `_ingested_at`**, así que no se puede medir latencia de ingesta ni llegadas tardías, ni verificar el caso `ingested < extracted`. El valor `2026-07-01 03:00:00` coincide con el de `raw.products` (sí) y es la fecha de corte natural del dataset.


## Relación con `orders`

| Chequeo | Resultado |
|---|---|
| Clientes en `orders` que no existen en `customers` (filas de evento / clientes / pedidos) | 0 / 0 / 0 |
| Clientes con al menos 1 pedido | 402 (67.00%) |
| Clientes sin ningún pedido | 198 (33.00%) |
| Pedidos por cliente con pedidos (mín / máx / promedio / mediana) | 1 / 26 / 9.95 / 10.0 |

**"Cliente activo" no está definido en los datos**: la tabla no tiene estado ni flag de actividad. El número cambia según la definición que se elija (pedido = primer evento del pedido; corte = `2026-07-01 03:00`):

| Definición candidata de activo | Clientes |
|---|---|
| Cliente con al menos 1 pedido (cualquier estado) | 402 |
| Cliente con al menos 1 pedido cuyo estado actual no es `cancelled` | 399 |
| Cliente con al menos 1 pedido que alguna vez llegó a `delivered` | 380 |
| Cliente con pedido en los 90 días previos al corte (2026-07-01 03:00) | 402 |
| Cliente con pedido en los 30 días previos al corte | 381 |
| Cliente con pedido en junio de 2026 | 381 |


## Implicaciones para silver y gold

- `customers` no necesita deduplicación ni limpieza de formato; sí conviene declarar los tests `unique` y `not_null` de `customer_id` y `accepted_values` de `segment` y `country_code`, porque la base no los garantiza.
- Total de clientes = 600 (`count(*)`). El crecimiento mensual se calcula con `created_at`; falta decidir la zona horaria del corte mensual.
- "Activos" requiere una definición de negocio explícita (ver tabla): entre 380 y 402 según el criterio.
- Sin historial: una dimensión tipo SCD2 no se puede construir desde esta fuente (una sola versión por cliente).
