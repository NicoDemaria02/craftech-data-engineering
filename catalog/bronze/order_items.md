# `raw.order_items`

> Catálogo de la capa bronze · [← Volver al índice](README.md) · Fuente: `data/ecommerce.duckdb` (solo lectura) · Generado el 2026-10-27

Líneas de detalle de cada pedido (producto y cantidad). **No tiene precio, descuento ni importe**: el ingreso solo se puede calcular como `quantity * products.unit_price`.

| Propiedad | Valor |
|---|---|
| Filas | 7820 |
| Grano | Una línea (un producto) de un pedido, identificada por (`order_id`, `line_number`). |
| Clave primaria candidata | (`order_id`, `line_number`): 7615 combinaciones distintas sobre 7820 filas (no única en bruto; única tras deduplicar). |
| Pedidos distintos | 3993 |
| Metadatos de carga | Solo `_ingested_at` (no tiene `_extracted_at`) |
| Rango de `_ingested_at` | `2026-01-01 02:56:38` a `2026-06-30 23:44:52` |
| Constraints declarados en la base | 0 (sin PK, FK, UNIQUE ni NOT NULL) |


## Grano y clave primaria

| Verificación | Resultado |
|---|---|
| `count(*)` | 7820 |
| `count(distinct (order_id, line_number))` | 7615 |
| `count(distinct (order_id, line_number, product_id, quantity))` | 7615 |
| `count(distinct <fila completa>)` | 7820 |
| Combinaciones (`order_id`, `product_id`) repetidas, en bruto / deduplicado | 205 / 0 |

- (`order_id`, `line_number`) no es único en bruto: 7820 filas vs 7615 claves, o sea 205 filas de más.
- Tras deduplicar quedan 7615 líneas, (`order_id`, `line_number`) es clave y un producto no se repite dentro de un pedido (0 repeticiones).
- `line_number` va de 1 a 4 y es correlativo dentro de cada pedido: 3993 de 3993 pedidos tienen líneas 1..n sin huecos (deduplicado); en bruto solo 3880 de 3993, porque las copias duplicadas inflan el conteo.


## Columnas

| Columna | Tipo DuckDB | Nulos (n y %) | Distintos | Min / Max (o valores si ≤ 10 distintos) | Ejemplos | Notas |
|---|---|---|---|---|---|---|
| `order_id` | `VARCHAR` | 0 (0.00%) | 3993 | `O000001` / `O004000` | `O000001`, `O000002`, `O000003` | FK a `orders.order_id` (0 huérfanos). Formato válido en 7820 de 7820. Cubre 3993 de los 3998 pedidos: faltan los 5 pedidos sin evento `created`. |
| `line_number` | `INTEGER` | 0 (0.00%) | 4 | `1` (4106); `2` (2251); `3` (1067); `4` (396) | `1`, `2`, `3` | Número de línea dentro del pedido, 1 a 4. Parte de la PK. |
| `product_id` | `VARCHAR` | 0 (0.00%) | 80 | `P0001` / `P0080` | `P0030`, `P0019`, `P0040` | FK a `products.product_id` (0 huérfanos). 80 de 80 productos aparecen al menos una vez. Formato válido en 7820 de 7820. |
| `quantity` | `INTEGER` | 0 (0.00%) | 19 | `1` / `20` | `5`, `11`, `1` | Unidades. 0 valores ≤ 0. Bimodal: 1–3 para `retail` y 5–20 para `wholesale`; el 4 no aparece nunca (ver sección de cantidades). |
| `_ingested_at` | `TIMESTAMP` | 0 (0.00%) | 4105 | `2026-01-01 02:56:38` / `2026-06-30 23:44:52` | `2026-01-01 02:56:38`, `2026-01-01 03:43:54`, `2026-01-01 06:07:15` | Momento de ingesta. Para la primera copia de cada línea coincide exactamente con la ingesta del evento `created` del mismo pedido. |


## Duplicados y re-entregas

| Chequeo | Resultado |
|---|---|
| Filas exactamente duplicadas (incluida `_ingested_at`) | 0 |
| Claves (`order_id`, `line_number`) con más de una fila | 205 |
| Máximo de copias por clave | 2 |
| Claves duplicadas cuyas copias difieren en `product_id` / `quantity` | 0 / 0 |
| Pedidos afectados | 113 |
| Eventos `created` duplicados en `orders` (para comparar) | 113 |
| Copias cuyo `_ingested_at` coincide con el de alguna copia del evento `created` del pedido (1.ª / 2.ª copia) | 205 de 205 / 205 de 205 |

Son re-entregas **completas** de las líneas de un pedido: las 205 líneas repetidas pertenecen a 113 pedidos, que son exactamente los 113 pedidos con `created` re-entregado en `orders`, y cada copia llega junto con la copia correspondiente del evento `created`. El contenido es idéntico (mismo producto y cantidad); solo cambia `_ingested_at`. Conservar la copia con el menor `_ingested_at`.

Efecto si no se deduplica: 205 líneas de más (2.62% de las filas) e ingreso inflado en 126559.98 (2.91%).


## `_ingested_at`

| Dato | Valor |
|---|---|
| Rango | `2026-01-01 02:56:38` a `2026-06-30 23:44:52` |
| Valores distintos de `_ingested_at` | 4105 sobre 7820 filas (se ingiere por pedido, no por lote) |
| Filas físicas cuyo `_ingested_at` retrocede respecto de la anterior | 0 |
| Primera copia de cada línea: `_ingested_at` = ingesta de la primera copia del `created` (igual / posterior / anterior) | 7615 / 0 / 0 de 7615 |
| Latencia respecto de `event_at` del `created` > 1 h | 1266 de 7820 filas (16.19%) |
| Latencia máxima | 47 h 58 min |
| `_ingested_at` anterior al `created` | 0 |

Sin `_extracted_at`: no se puede comparar extracción e ingesta. Las líneas heredan la latencia de su evento `created` (misma ingesta); ver [orders](orders.md) para la distribución y el tope de ~48 h. Mes de ingesta (filas): 2026-01: 779, 2026-02: 965, 2026-03: 1128, 2026-04: 1373, 2026-05: 1658, 2026-06: 1917.


## Cantidades

| quantity | Líneas (en bruto) | Líneas (deduplicado) |
|---|---|---|
| 1 | 2310 | 2252 |
| 2 | 2295 | 2232 |
| 3 | 2252 | 2199 |
| 5 | 63 | 62 |
| 6 | 62 | 58 |
| 7 | 65 | 63 |
| 8 | 59 | 59 |
| 9 | 53 | 52 |
| 10 | 63 | 63 |
| 11 | 56 | 54 |
| 12 | 51 | 51 |
| 13 | 63 | 59 |
| 14 | 68 | 66 |
| 15 | 55 | 50 |
| 16 | 53 | 52 |
| 17 | 63 | 62 |
| 18 | 72 | 71 |
| 19 | 58 | 54 |
| 20 | 59 | 56 |

| Segmento del cliente | Líneas | Cantidad mín | Cantidad máx | Promedio | Líneas con cantidad ≥ 5 |
|---|---|---|---|---|---|
| `retail` | 6683 | 1 | 3 | 1.99 | 0 |
| `wholesale` | 932 | 5 | 20 | 12.47 | 932 |

Cantidades ≤ 0: 0. No hay valores nulos ni negativos. Las cantidades son bimodales y están determinadas por el segmento: `retail` compra de 1 a 3 unidades, `wholesale` de 5 a 20, y el valor 4 no ocurre. No es un error, pero hay que tenerlo presente al interpretar outliers: las cantidades altas son compras mayoristas legítimas.


## Contraste con `products` (precio, ingreso)

No existe un precio en `order_items`, así que **no hay un "precio de la línea" para comparar con el precio de lista**. El ingreso se deriva con el precio de lista actual de `products`:

```sql
with items as (
    select * exclude (rn)
    from (
        select *,
               row_number() over (
                   partition by order_id, line_number
                   order by _ingested_at
               ) as rn
        from raw.order_items
    )
    where rn = 1
)
select p.category,
       sum(i.quantity * p.unit_price) as revenue
from items i
join raw.products p using (product_id)
group by p.category
```

| Chequeo | Resultado |
|---|---|
| Líneas con `product_id` inexistente en `products` | 0 |
| Líneas (deduplicadas) con producto creado después del pedido | 0 |
| Líneas con producto modificado (`updated_at`) después del primer evento del pedido | 1014 de 7615 (13.32%) |
| Ingreso de esas líneas a precio actual | 692803.80 (15.93% del bruto) |
| Moneda | `USD` única (`products.currency`) |

**Ingreso por categoría de referencia** (`quantity * unit_price`, líneas deduplicadas, pedidos con items: 3993):

| Categoría | Ingreso bruto (todos los pedidos) | % del bruto | Ingreso sin pedidos cancelados | Líneas | Unidades |
|---|---|---|---|---|---|
| `electronics` | 2438921.48 | 56.08% | 2177443.70 | 1462 | 4658 |
| `home` | 766753.72 | 17.63% | 682947.43 | 1737 | 5555 |
| `sports` | 721120.90 | 16.58% | 634373.71 | 1611 | 5268 |
| `beauty` | 248000.88 | 5.70% | 222976.37 | 1422 | 4755 |
| `books` | 174203.93 | 4.01% | 159046.56 | 1383 | 4703 |
| **Total** | 4349000.91 | 100.00% | 3876787.77 | 7615 | 24939 |

Chequeo cruzado: la consulta del bloque SQL de arriba suma 4349000.91, igual al total de la tabla (4349000.91). "Sin pedidos cancelados" excluye los pedidos cuyo estado actual es `cancelled`.

Ingreso bruto por estado actual del pedido:

| Estado actual | Ingreso | Pedidos con items |
|---|---|---|
| `delivered` | 3502509.72 | 3252 |
| `cancelled` | 472213.14 | 434 |
| `returned` | 190050.32 | 143 |
| `shipped` | 114397.49 | 117 |
| `paid` | 50952.93 | 41 |
| `created` | 18877.31 | 6 |

Ingreso por segmento de cliente:

| Segmento | Ingreso bruto | % del bruto | Pedidos |
|---|---|---|---|
| `retail` | 2330026.59 | 53.58% | 3489 |
| `wholesale` | 2018974.32 | 46.42% | 504 |


## Errores típicos de cálculo y su efecto

| Cálculo | Filas | Ingreso | Relación con el correcto |
|---|---|---|---|
| Correcto: líneas deduplicadas × `unit_price` | 7615 | 4349000.91 | 1.00x |
| Sin deduplicar `order_items` | 7820 | 4475560.89 | +2.91% |
| `order_items` crudo unido a `orders` crudo por `order_id` (se repite cada línea por cada evento) | 30729 | 17598914.96 | 4.05x |


## Relación con `orders`

| Chequeo | Resultado |
|---|---|
| Líneas con `order_id` inexistente en `orders` (líneas / pedidos) | 0 / 0 |
| Pedidos en `orders` sin líneas (filas de evento / pedidos) | 6 / 5 |
| ¿Son los pedidos sin evento `created`? | Sí, son los mismos |
| Pedidos por cantidad de líneas (deduplicado) | 1 línea(s): 1795; 2 línea(s): 1163; 3 línea(s): 646; 4 línea(s): 389 |

Las líneas se ingieren junto con el evento `created`; si ese evento no llegó, el pedido no tiene líneas. Para esos 5 pedidos no se puede calcular ingreso.


## Implicaciones para silver y gold

- Deduplicar por (`order_id`, `line_number`) antes de cualquier suma; sin eso el ingreso queda inflado.
- Nunca unir `order_items` con los eventos de `orders`: unir contra el **modelo de pedido** (una fila por `order_id`). La unión directa multiplica el ingreso por 4.05.
- Hecho de ventas: grano = línea de pedido; medida `amount = quantity * products.unit_price` (precio vigente); la fecha viene del pedido (`ordered_at`).
- El precio efectivo y el posible historial de precios no están en la fuente: documentar el supuesto de precio vigente.
- Decidir con negocio si el ingreso total incluye pedidos cancelados y en vuelo (ver tabla por estado y las dos columnas de ingreso por categoría).
