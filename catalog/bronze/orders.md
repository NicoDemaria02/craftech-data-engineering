# `raw.orders`

> Catálogo de la capa bronze · [← Volver al índice](README.md) · Fuente: `data/ecommerce.duckdb` (solo lectura) · Generado el 2026-10-27

**Tabla de eventos del ciclo de vida de los pedidos.** Cada fila es un cambio de estado (`created`, `paid`, `shipped`, ...) de un pedido, no un pedido. Hay 15608 filas para 3998 pedidos distintos (3.90 filas por pedido). Contar filas, o filtrar por `status` sin deduplicar, no responde ninguna de las preguntas de negocio.

| Propiedad | Valor |
|---|---|
| Filas | 15608 |
| Pedidos distintos (`order_id`) | 3998 |
| Grano | Un evento (cambio de estado) de un pedido en un instante. |
| Clave primaria candidata | No hay clave única en bruto. Tras deduplicar: (`order_id`, `status`) ó (`order_id`, `status`, `event_at`) (ver abajo). |
| Metadatos de carga | Solo `_ingested_at` (no tiene `_extracted_at`) |
| Rango de `event_at` | `2026-01-01 02:45:10` a `2026-07-01 02:56:29` |
| Constraints declarados en la base | 0 (sin PK, FK, UNIQUE ni NOT NULL) |


## Grano y clave primaria

| Verificación | Resultado |
|---|---|
| `count(*)` (filas) | 15608 |
| `count(distinct order_id)` | 3998 |
| `count(distinct (order_id, status))` | 15165 |
| `count(distinct (order_id, event_at))` | 15165 |
| `count(distinct (order_id, status, event_at))` | 15165 |
| `count(distinct <fila completa>)` | 15608 |
| Pedidos con más de 1 `customer_id` | 0 (máximo 1 cliente por pedido) |

Lectura:

- `order_id` no es único (15608 filas vs 3998 distintos): confirma que la tabla es de eventos.
- Ninguna combinación de columnas de negocio es única en bruto: hay 443 filas de más respecto de (`order_id`, `status`, `event_at`) (15608 vs 15165). Esas filas solo se diferencian por `_ingested_at` (ver Duplicados).
- Tras deduplicar por (`order_id`, `status`, `event_at`) quedan 15165 eventos y (`order_id`, `status`) pasa a ser único (15165 pares = 15165 filas). Además (`order_id`, `event_at`) tiene 15165 pares distintos: ningún pedido tiene dos estados en el mismo instante (0 empates).
- **Clave del evento (silver)**: (`order_id`, `status`). **Grano del pedido**: `order_id` (3998 pedidos), derivado agregando los eventos.


## Columnas

| Columna | Tipo DuckDB | Nulos (n y %) | Distintos | Min / Max (o valores si ≤ 10 distintos) | Ejemplos | Notas |
|---|---|---|---|---|---|---|
| `order_id` | `VARCHAR` | 0 (0.00%) | 3998 | `O000001` / `O004000` | `O000001`, `O000002`, `O000003` | Formato `O` + 6 dígitos (15608 de 15608 filas cumplen `^O[0-9]{6}$`). Rango `O000001` a `O004000`, con 2 ids ausentes en el rango (`O003986`, `O003994`). Orden por `order_id` = orden por fecha de creación (0 violaciones). |
| `customer_id` | `VARCHAR` | 0 (0.00%) | 402 | `C00001` / `C00598` | `C00388`, `C00092`, `C00407` | FK a `customers.customer_id` (0 huérfanos). Formato válido en 15608 de 15608 filas. Se repite en todos los eventos de un pedido (máx. 1 cliente por pedido). |
| `status` | `VARCHAR` | 0 (0.00%) | 6 | `created` (4106); `paid` (3792); `shipped` (3623); `delivered` (3489); `cancelled` (452); `returned` (146) | `created`, `paid`, `shipped` | Enum guardado como `VARCHAR`: 6 valores en minúscula, sin espacios (0 con mayúsculas, 0 con espacios). Ver tabla de estados. |
| `event_at` | `TIMESTAMP` | 0 (0.00%) | 15156 | `2026-01-01 02:45:10` / `2026-07-01 02:56:29` | `2026-01-01 02:45:10`, `2026-01-01 03:28:31`, `2026-01-01 03:42:31` | Instante en que ocurrió el cambio de estado, según el sistema origen. `TIMESTAMP` sin zona horaria. Es la columna que ordena el ciclo de vida. |
| `_ingested_at` | `TIMESTAMP` | 0 (0.00%) | 15600 | `2026-01-01 02:56:38` / `2026-07-01 02:59:07` | `2026-01-01 02:56:38`, `2026-01-01 03:43:54`, `2026-01-01 03:46:42` | Momento en que el evento aterrizó en el lake. Siempre posterior a `event_at` (0 casos anteriores o iguales). **No** ordena el ciclo de vida (ver más abajo). |


## Estados (`status`)

| status | Eventos en bruto | % de filas | Eventos deduplicados | Pedidos que pasaron por el estado | % de los pedidos |
|---|---|---|---|---|---|
| `created` | 4106 | 26.31% | 3993 | 3993 | 99.87% |
| `paid` | 3792 | 24.30% | 3687 | 3687 | 92.22% |
| `shipped` | 3623 | 23.21% | 3513 | 3513 | 87.87% |
| `delivered` | 3489 | 22.35% | 3395 | 3395 | 84.92% |
| `cancelled` | 452 | 2.90% | 434 | 434 | 10.86% |
| `returned` | 146 | 0.94% | 143 | 143 | 3.58% |

Los valores son los 6 estados del ciclo de vida: `created` → `paid` → `shipped` → `delivered` → (`returned`), y `cancelled` como salida desde `created` o `paid`. No hay casing inconsistente, espacios ni valores nulos. `delivered` sobre filas en bruto es 22.35%; sobre pedidos, 84.92% (alguna vez entregado) o 81.34% (estado actual). Esa diferencia es el error que produce no deduplicar ni agregar por pedido.


## Eventos por pedido

| Eventos por pedido | Pedidos (en bruto) | Pedidos (deduplicado) |
|---|---|---|
| 1 | 10 | 10 |
| 2 | 322 | 347 |
| 3 | 250 | 246 |
| 4 | 2915 | 3252 |
| 5 | 462 | 143 |
| 6 | 39 | 0 |

En bruto, un pedido llega a 6 filas, pero tras deduplicar el máximo real es 5 eventos (`created`, `paid`, `shipped`, `delivered`, `returned`). La diferencia son los duplicados por re-entrega.


## Secuencias típicas de estados

Secuencias por pedido, sobre eventos deduplicados y ordenados por `event_at`:

| Secuencia | Pedidos | % de pedidos |
|---|---|---|
| `created > paid > shipped > delivered` | 3252 | 81.34% |
| `created > cancelled` | 304 | 7.60% |
| `created > paid > shipped > delivered > returned` | 143 | 3.58% |
| `created > paid > cancelled` | 130 | 3.25% |
| `created > paid > shipped` | 116 | 2.90% |
| `created > paid` | 41 | 1.03% |
| `created` | 6 | 0.15% |
| `paid` | 4 | 0.10% |
| `created > shipped` | 1 | 0.03% |
| `paid > shipped` | 1 | 0.03% |

Interpretación: el camino feliz es `created > paid > shipped > delivered`. Las secuencias que no terminan en un estado final (`delivered`, `returned` o `cancelled`) son pedidos en vuelo (ver sección de estado actual). Las secuencias que no empiezan en `created` son pedidos a los que les falta el primer evento (5 pedidos; ver sección de cola de datos).


## Tiempos entre estados

Diferencia de `event_at` entre eventos consecutivos del mismo pedido (deduplicado). Sirve para detectar pedidos "trabados".

| Transición | Pedidos | Mínimo | Mediana | Máximo |
|---|---|---|---|---|
| `created → paid` | 3682 | 5 min | 1 h 3 min | 2 h |
| `paid → shipped` | 3512 | 12 h | 41 h | 3 d |
| `shipped → delivered` | 3395 | 2 d | 4 d 1 h | 6 d |
| `created → cancelled` | 304 | 12 min | 12 h 42 min | 23 h 55 min |
| `delivered → returned` | 143 | 3 d | 9 d | 15 d |
| `paid → cancelled` | 130 | 1 h | 18 h | 2 d |
| `created → shipped` | 1 | 14 h 34 min | 14 h 34 min | 14 h 34 min |


## Estados finales múltiples y consistencia del ciclo de vida

| Chequeo (sobre eventos deduplicados) | Pedidos |
|---|---|
| Con `delivered` **y** `cancelled` | 0 |
| Con `shipped` **y** `cancelled` | 0 |
| Con `paid` y `cancelled` (cancelación después del pago) | 130 |
| Con `returned` **y** `cancelled` | 0 |
| Con `returned` sin `delivered` | 0 |
| Con `delivered` **y** `returned` (devolución posterior a la entrega) | 143 |
| `delivered` sin `shipped` | 0 |
| `shipped` sin `paid` | 1 (pedido `O003965`) |
| Sin evento `created` (de ellos, con `paid` pero sin `created`) | 5 (5) |

No existen pedidos con dos estados terminales contradictorios (`delivered` + `cancelled`: 0). El único estado "posterior" a un final es `returned`, y siempre sigue a `delivered` (143 pedidos). Cuidado con el modelo: un pedido `returned` también fue `delivered`, así que "entregados" puede significar 3252 (estado actual) o 3395 (alguna vez).


## Orden de los eventos

| Chequeo | Resultado |
|---|---|
| Retrocesos de etapa al ordenar por `event_at` (p. ej. `shipped` antes que `paid`) | 0 |
| Empates de `event_at` dentro de un pedido | 0 |
| Eventos con etapa menor que el anterior al ordenar por `_ingested_at` (filas / pedidos) | 609 / 600 |
| Filas cuyo `event_at` es menor que el de la fila física anterior | 4107 |
| Filas cuyo `_ingested_at` es menor que el de la fila física anterior | 0 |

Por `event_at` el ciclo de vida es siempre coherente. Por orden de llegada, no: 600 pedidos recibieron una etapa posterior antes que una anterior (llegada fuera de orden por eventos tardíos). El orden físico de la tabla es el de ingesta (`_ingested_at` nunca retrocede), **no** el de `event_at`. Regla: ordenar siempre por `event_at`, nunca por posición de fila ni por `_ingested_at`.


## Duplicados y re-entregas

| Chequeo | Resultado |
|---|---|
| Filas exactamente duplicadas (todas las columnas, incluida `_ingested_at`) | 0 |
| Grupos (`order_id`, `status`, `event_at`) con más de una fila | 443 |
| Filas dentro de esos grupos | 886 |
| Filas "de más" a descartar | 443 (2.84% de las filas) |
| Máximo de copias por evento | 2 |
| Grupos con `customer_id` distinto entre copias | 0 |
| Grupos cuyas copias tienen el mismo `_ingested_at` | 0 |
| Separación entre la 1.ª y la 2.ª copia (mín / mediana / máx) | 1 min 29 s / 20 h 43 min / 47 h 56 min |

Son **re-entregas del mismo evento**: misma clave, mismo `event_at`, mismo cliente, distinto `_ingested_at` (siempre exactamente 2 copias). No son versiones con contenido distinto: el único campo que cambia es `_ingested_at`. Conviene conservar la copia con el `_ingested_at` más temprano.

Duplicados por estado:

| status | Eventos duplicados |
|---|---|
| `created` | 113 |
| `shipped` | 110 |
| `paid` | 105 |
| `delivered` | 94 |
| `cancelled` | 18 |
| `returned` | 3 |


## `_ingested_at`: rango, lotes y llegadas tardías

| Dato | Valor |
|---|---|
| Rango de `_ingested_at` | `2026-01-01 02:56:38` a `2026-07-01 02:59:07` |
| Valores distintos de `_ingested_at` | 15600 sobre 15608 filas |
| Días calendario distintos con ingesta | 182 |
| Horas distintas con ingesta | 4129 |
| Timestamps compartidos por más de una fila | 8 |
| Eventos posteriores al corte (`2026-07-01 03:00`) | 0 por `event_at`; 0 por `_ingested_at` |
| `_ingested_at` anterior o igual a `event_at` | 0 y 0 |
| Eventos cuyo día de ingesta difiere del día de `event_at` | 2378 |
| Eventos cuyo mes de ingesta difiere del mes de `event_at` | 89 |

**No hay lotes de ingesta**: la tabla se ingiere evento por evento (casi un timestamp distinto por fila). No existe `_extracted_at`, así que no se puede comparar extracción vs ingesta ni detectar `ingested < extracted`. La única referencia de latencia es `_ingested_at - event_at`.

**Latencia de ingesta (`_ingested_at - event_at`)**: mínimo 30 s, mediana 12 min 19 s, máximo 47 h 59 min.

| Latencia | Filas | % de filas |
|---|---|---|
| ≤ 1 h | 12834 | 82.23% |
| entre 1 h y 6 h | 38 | 0.24% |
| entre 6 h y 24 h | 1179 | 7.55% |
| entre 24 h y 48 h | 1557 | 9.98% |
| > 48 h | 0 | 0.00% |

La distribución es bimodal: 12834 filas llegan dentro de la hora y 2736 lo hacen entre 6 h y 48 h; solo 38 caen en el medio. Hay 2774 eventos (17.77%) ingeridos más de 1 h después de ocurrir, con tope observado de 47 h 59 min (< 48 h).

Origen de las llegadas tardías (> 1 h):

| Tipo de fila | Filas | Tardías (> 1 h) | Mediana de latencia |
|---|---|---|---|
| Evento sin duplicar | 14722 | 2267 | 11 min 59 s |
| Evento duplicado, 1.ª copia | 443 | 70 | 12 min 22 s |
| Evento duplicado, 2.ª copia (re-entrega) | 443 | 437 | 27 h 6 min |

| status | Eventos tardíos (> 1 h) | Eventos del estado | % tardío |
|---|---|---|---|
| `created` | 680 | 4106 | 16.56% |
| `paid` | 679 | 3792 | 17.91% |
| `shipped` | 664 | 3623 | 18.33% |
| `delivered` | 625 | 3489 | 17.91% |
| `cancelled` | 97 | 452 | 21.46% |
| `returned` | 29 | 146 | 19.86% |

Las llegadas tardías se reparten de forma parecida entre estados (16.56% a 21.46%). Consecuencias: (1) un incremental que filtre por `event_at` perderá eventos; usar `_ingested_at` como marca de agua y reprocesar al menos las últimas 48 h; (2) una etapa posterior puede llegar antes que una anterior (600 pedidos); (3) los últimos ~2 días del dataset pueden estar incompletos (ver siguiente sección).


## Cola del dataset: pedidos incompletos y en vuelo

El corte de extracción es `2026-07-01 03:00:00` (`customers`/`products`). Los eventos llegan a `2026-07-01 02:56:29`. Dado el tope de latencia observado, lo más reciente puede no haber aterrizado. Evidencia:

| Hallazgo | Detalle |
|---|---|
| Pedidos sin evento `created` | 5: `O003944` (2026-06-29 07:32:31, `paid`), `O003955` (2026-06-29 13:30:13, `shipped`), `O003981` (2026-06-30 12:26:55, `paid`), `O003985` (2026-06-30 13:57:15, `paid`), `O003996` (2026-06-30 23:03:29, `paid`) |
| ¿Son los mismos que no tienen filas en `order_items`? | Sí |
| `order_id` ausentes dentro del rango | `O003986`, `O003994` (vecinos: `O003985` 2026-06-30 13:57:15, `O003987` 2026-06-30 14:17:23, `O003993` 2026-06-30 17:19:42, `O003995` 2026-06-30 21:08:32) |
| Violaciones de cronología en el `order_id` (pedido con id mayor y `created` anterior) | 0 |

Hipótesis (no verificable con los datos): los eventos `created` de esos 5 pedidos y los eventos de los 2 ids ausentes llegarán dentro de las 48 h posteriores al corte. Es coherente con la latencia observada y con que los ids ausentes caen en la franja del 2026-06-30 en la que sí hay pedidos.

Pedidos en vuelo (estado actual no final), según `event_at`:

| Estado actual | Pedidos | Último evento (mín) | Último evento (máx) |
|---|---|---|---|
| `created` | 6 | 2026-06-30 02:47:37 | 2026-06-30 22:25:56 |
| `paid` | 45 | 2026-06-28 07:56:03 | 2026-07-01 00:30:27 |
| `shipped` | 118 | 2026-06-24 23:04:56 | 2026-07-01 02:35:50 |

Total en vuelo: 169 (4.23% de los pedidos). Casi todos se explican por el corte. Usando los máximos observados entre estados (`created`→24 h, `paid`→3 d, `shipped`→6 d), solo 2 exceden ese plazo: `O003764` (`shipped`, último evento 2026-06-24 23:04:56), `O003968` (`created`, último evento 2026-06-30 02:47:37).


## Cómo derivar el estado actual de un pedido

Reglas, verificadas contra los datos:

1. Deduplicar eventos por (`order_id`, `status`, `event_at`), conservando el menor `_ingested_at`.
2. `current_status` = `status` del evento con mayor `event_at`. Los empates (0 observados) se desempatan por etapa del ciclo de vida.
3. Para "alguna vez" (p. ej. entregado y luego devuelto) usar flags `bool_or(status = '...')`, no el estado actual.
4. **No** usar el mayor `_ingested_at` ni la última fila física: cambian el estado de 71 pedidos de 3998 (65 si antes se deduplica). Ejemplo: `cancelled` → `created` (52); `cancelled` → `paid` (9).

```sql
with eventos as (
    select * exclude (rn)
    from (
        select *,
               row_number() over (
                   partition by order_id, status, event_at
                   order by _ingested_at
               ) as rn
        from raw.orders
    )
    where rn = 1
),
con_etapa as (
    select *,
           case status
               when 'created'   then 1
               when 'paid'      then 2
               when 'shipped'   then 3
               when 'delivered' then 4
               when 'returned'  then 5
               when 'cancelled' then 6
           end as etapa
    from eventos
)
select
    order_id,
    any_value(customer_id)                        as customer_id,
    min(event_at)                                 as ordered_at,       -- primer evento
    arg_max(status, (event_at, etapa))            as current_status,   -- ultimo evento por event_at
    max(event_at)                                 as last_event_at,
    bool_or(status = 'delivered')                 as was_delivered,
    bool_or(status = 'cancelled')                 as was_cancelled,
    bool_or(status = 'returned')                  as was_returned
from con_etapa
group by order_id
```

Distribución del estado actual (3998 pedidos):

| Estado actual | Pedidos | % de pedidos |
|---|---|---|
| `delivered` | 3252 | 81.34% |
| `cancelled` | 434 | 10.86% |
| `returned` | 143 | 3.58% |
| `shipped` | 118 | 2.95% |
| `paid` | 45 | 1.13% |
| `created` | 6 | 0.15% |

Referencia para la pregunta de entregados vs cancelados (según la definición):

| Definición | Entregados | Cancelados |
|---|---|---|
| Sobre filas en bruto (incorrecta) | 3489 / 15608 = 22.35% | 452 / 15608 = 2.90% |
| Estado actual, sobre todos los pedidos | 3252 / 3998 = 81.34% | 434 / 3998 = 10.86% |
| "Alguna vez" entregado (incluye devueltos), sobre todos los pedidos | 3395 / 3998 = 84.92% | 434 / 3998 = 10.86% |
| Solo pedidos cerrados (entregado alguna vez + cancelado) | 3395 / 3829 = 88.67% | 434 / 3829 = 11.33% |


## Implicaciones para silver y gold

- Silver debe tener dos modelos: **eventos deduplicados** (clave `order_id`+`status`) y **pedido** (una fila por `order_id` con `current_status`, flags `was_*` y `ordered_at`).
- Siempre contar pedidos con `count(distinct order_id)` sobre el modelo de pedido: 3998 pedidos, no 15608.
- Definir con negocio qué es "entregado" (¿los devueltos cuentan?) y cuál es el denominador (¿se excluyen los pedidos en vuelo?). Ver tabla de referencia.
- Fecha del pedido para ventas por día y semana: `min(event_at)` (coincide con `created` salvo en 5 pedidos). Falta decidir la zona horaria.
- Incremental: marca de agua en `_ingested_at` con reprocesamiento de las últimas 48 h; ordenar por `event_at`; la deduplicación debe repetirse en cada corrida.
