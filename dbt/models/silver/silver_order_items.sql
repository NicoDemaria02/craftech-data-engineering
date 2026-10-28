-- Grano: 1 fila por línea de orden (order_id, line_number).
-- raw.order_items trae re-entregas de la misma línea con distinto _ingested_at.
-- Nos quedamos con la primera llegada. El precio se agrega en gold (D019).
-- Incremental con lookback de 2 días, igual que silver_orders (D027).
{{ config(
    materialized='incremental',
    unique_key=['order_id', 'line_number'],
    incremental_strategy='delete+insert'
) }}

select
    src.order_id,
    src.line_number,
    src.product_id,
    src.quantity,
    src._ingested_at
from {{ source('raw', 'order_items') }} as src
where {{ run_date_filter('src._ingested_at') }}
{% if is_incremental() %}
    and src._ingested_at > (select max(_ingested_at) - interval 2 day from {{ this }})
    and not exists (
        select 1
        from {{ this }} as cur
        where cur.order_id = src.order_id
          and cur.line_number = src.line_number
    )
{% endif %}
qualify row_number() over (
    partition by src.order_id, src.line_number
    order by src._ingested_at
) = 1
