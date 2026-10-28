# `raw.products`

> Catálogo de la capa bronze · [← Volver al índice](README.md) · Fuente: `data/ecommerce.duckdb` (solo lectura) · Generado el 2026-10-27

Dimensión de productos con su categoría y su **precio de lista actual**. Es una foto única; no guarda el historial de precios.

| Propiedad | Valor |
|---|---|
| Filas | 80 |
| Grano | Una fila por producto (verificado abajo). |
| Clave primaria candidata | `product_id` (80 distintos sobre 80 filas, 0 nulos) |
| Metadatos de carga | Solo `_extracted_at` (no tiene `_ingested_at`) |
| Lotes de extracción | 1 (`2026-07-01 03:00:00`, 80 filas) |
| Constraints declarados en la base | 0 (sin PK, FK, UNIQUE ni NOT NULL) |


## Grano y clave primaria

| Verificación | Resultado |
|---|---|
| `count(*)` | 80 |
| `count(distinct product_id)` | 80 |
| `count(distinct <fila completa>)` | 80 |
| `count(distinct product_name)` | 80 |
| `product_id` con formato `^P[0-9]{4}$` | 80 de 80 |
| Rango numérico del id | 1 a 80 (sin huecos) |

Conclusión: `count(*)` = `count(distinct product_id)` = 80, por lo tanto **`product_id` es clave primaria** y el grano es un producto por fila. La base no la declara.


## Columnas

| Columna | Tipo DuckDB | Nulos (n y %) | Distintos | Min / Max (o valores si ≤ 10 distintos) | Ejemplos | Notas |
|---|---|---|---|---|---|---|
| `product_id` | `VARCHAR` | 0 (0.00%) | 80 | `P0001` / `P0080` | `P0001`, `P0002`, `P0003` | PK candidata. Formato `P` + 4 dígitos, correlativo 1–80. |
| `product_name` | `VARCHAR` | 0 (0.00%) | 80 | `Beauty Eco 25` / `Sports Ultra 50` | `Sports Lite 1`, `Books Plus 2`, `Sports Classic 3` | Patrón `<Categoría> <Variante> <n>`: la categoría coincide con `category` en 80 de 80 filas y el número `<n>` con el de `product_id` en 80. Variantes: Lite (16), Classic (12), Ultra (12), Mini (10), Plus (10), Eco (9), Pro (9), Max (2). |
| `category` | `VARCHAR` | 0 (0.00%) | 5 | `home` (18); `sports` (17); `beauty` (15); `books` (15); `electronics` (15) | `sports`, `books`, `electronics` | Enum guardado como `VARCHAR`, siempre en minúsculas. Es la dimensión del ingreso por categoría. Conviene un test `accepted_values`. |
| `unit_price` | `DECIMAL(10,2)` | 0 (0.00%) | 80 | `6.28` / `1006.61` | `39.92`, `32.60`, `59.75` | Precio de lista **actual** por unidad (una sola foto). Es el único precio disponible en todo el modelo: `order_items` no trae precio. |
| `currency` | `VARCHAR` | 0 (0.00%) | 1 | `USD` (80) | `USD` | Una sola moneda (`USD`) en todas las filas: no hay conversión que resolver. |
| `created_at` | `TIMESTAMP` | 0 (0.00%) | 80 | `2025-03-02 12:46:22` / `2026-05-22 06:13:37` | `2025-08-31 03:09:42`, `2025-03-25 19:13:18`, `2025-05-03 23:07:43` | Alta del producto. `TIMESTAMP` sin zona horaria. |
| `updated_at` | `TIMESTAMP` | 0 (0.00%) | 80 | `2025-03-08 09:39:53` / `2026-06-13 13:20:36` | `2025-08-31 03:09:42`, `2026-05-22 21:35:26`, `2026-03-20 21:01:32` | Última modificación. Igual a `created_at` en 54 filas; posterior en 26; nunca anterior. No indica qué campo cambió. |
| `_extracted_at` | `TIMESTAMP` | 0 (0.00%) | 1 | `2026-07-01 03:00:00` (80) | `2026-07-01 03:00:00` | Metadato: momento de extracción. Valor único para toda la tabla. |


## Calidad de formato y dominios

| Chequeo | Filas afectadas | Observación |
|---|---|---|
| Espacios al inicio o al final en columnas de texto | 0 |  |
| Strings vacíos en columnas de texto | 0 |  |
| `category` con mayúsculas | 0 | Valores: `home` (18), `sports` (17), `beauty` (15), `books` (15), `electronics` (15) |
| `unit_price` ≤ 0 | 0 | Rango: 6.28 a 1006.61 |
| `currency` distinta de `USD` | 0 |  |
| `updated_at` < `created_at` | 0 |  |
| `created_at` o `updated_at` > `_extracted_at` | 0 |  |

`unit_price` es `DECIMAL(10,2)` (tipo numérico correcto, 2 decimales). No hay números ni fechas guardados como texto.


## Precios por categoría

| Categoría | Productos | Precio mín | Precio máx | Promedio | Mediana |
|---|---|---|---|---|---|
| `home` | 18 | 13.41 | 266.00 | 136.51 | 137.69 |
| `sports` | 17 | 31.95 | 292.93 | 139.13 | 161.55 |
| `beauty` | 15 | 6.28 | 110.49 | 52.12 | 37.09 |
| `books` | 15 | 6.95 | 58.43 | 36.71 | 36.87 |
| `electronics` | 15 | 33.82 | 1006.61 | 525.88 | 601.79 |

`electronics` concentra los precios altos (hasta 1006.61); ver su peso en el ingreso en [order_items](order_items.md).


## Duplicados y versiones

| Chequeo | Resultado |
|---|---|
| Filas exactamente duplicadas | 0 |
| Claves de negocio (`product_id`) repetidas | 0 |
| Versiones por clave | 1 (máximo 1) |
| Valores distintos de `_extracted_at` | 1 |

No hay re-extracciones. Hay 26 productos con `updated_at` > `created_at` (cambiaron al menos una vez), pero solo existe su versión final: **no hay historial de precios**.


## Metadatos de carga

| `_extracted_at` | Filas |
|---|---|
| `2026-07-01 03:00:00` | 80 |

Rango de `created_at`: `2025-03-02 12:46:22` a `2026-05-22 06:13:37`. Rango de `updated_at`: `2025-03-08 09:39:53` a `2026-06-13 13:20:36`. Sin `_ingested_at`: no se puede evaluar latencia ni llegadas tardías.


## Relación con `order_items` y riesgo de precio histórico

| Chequeo | Resultado |
|---|---|
| Líneas de `order_items` con `product_id` inexistente en `products` (líneas / productos distintos) | 0 / 0 |
| Productos que nunca aparecen en `order_items` | 0 |
| Líneas (sin duplicados) cuyo producto se creó **después** del pedido | 0 |
| Líneas (sin duplicados) cuyo producto tiene `updated_at` **posterior** al primer evento del pedido | 1014 de 7615 (13.32%), sobre 26 productos |
| Ingreso (a precio actual) de esas líneas | 692803.80 de 4349000.91 (15.93%) |

Como `products` solo guarda el precio actual, el ingreso calculado como `quantity * unit_price` usa el precio de hoy para pedidos pasados. Para esas líneas el ingreso podría diferir del cobrado si el cambio de `updated_at` fue de precio (los datos no permiten saberlo: `updated_at` no dice qué columna cambió). Es un **supuesto de negocio** que hay que dejar escrito.


## Implicaciones para silver y gold

- `products` no necesita deduplicación ni limpieza. `category` es la dimensión directa para el ingreso por categoría (5 valores, ninguno nulo).
- El precio efectivo de cada venta no está en `order_items`: el ingreso depende de `unit_price` y de aceptar el supuesto de precio vigente (ver sección anterior).
- Moneda única (`USD`): se puede mostrar ingreso sin conversión, pero conviene dejar `currency` en la dimensión por si cambia la fuente.
- Declarar tests `unique`/`not_null` de `product_id`, `accepted_values` de `category` y `unit_price > 0`.
