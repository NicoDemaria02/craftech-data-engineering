-- Grano: 1 fila por evento de orden (una orden tiene varios: created, paid, shipped...).
-- raw.orders trae re-entregas: el mismo evento (order_id, status, event_at) llega más de
-- una vez con distinto _ingested_at. Nos quedamos con la primera llegada.
--
-- Incremental (D027): cada corrida lee lo que llegó desde la anterior, con 2 días de
-- lookback por las llegadas tardías, y descarta los eventos que ya están en la tabla.
-- Así una re-entrega posterior nunca reemplaza a la primera llegada.
{{ config(
    materialized='incremental',
    unique_key=['order_id', 'status', 'event_at'],
    incremental_strategy='delete+insert'
) }}

select
    src.order_id,
    src.customer_id,
    src.status,
    src.event_at,
    src._ingested_at
from {{ source('raw', 'orders') }} as src
where {{ run_date_filter('src._ingested_at') }}
{% if is_incremental() %}
    and src._ingested_at > (select max(_ingested_at) - interval 2 day from {{ this }})
    and not exists (
        select 1
        from {{ this }} as cur
        where cur.order_id = src.order_id
          and cur.status = src.status
          and cur.event_at = src.event_at
    )
{% endif %}
qualify row_number() over (
    partition by src.order_id, src.status, src.event_at
    order by src._ingested_at
) = 1
