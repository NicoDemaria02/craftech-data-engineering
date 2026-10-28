-- Grano: 1 fila por cliente.
-- Activo (D024): al menos 1 orden no cancelada en los 90 días previos a la fecha de corte.
-- Fecha de corte = último evento de orden procesado, así acompaña al run_date del incremental.
with reference as (
    select max(event_at)::date as reference_date
    from {{ ref('silver_orders') }}
),

orders as (
    select
        customer_id,
        count(*)        as n_orders,
        min(ordered_at) as first_order_at,
        max(ordered_at) as last_order_at
    from {{ ref('gold_fct_orders') }}
    where not is_cancelled
    group by customer_id
)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.country_code,
    c.segment,
    c.created_at                               as registered_at,
    coalesce(o.n_orders, 0)                    as n_orders,
    o.first_order_at,
    o.last_order_at,
    r.reference_date,
    coalesce(o.last_order_at >= r.reference_date - interval 90 day, false) as is_active
from {{ ref('silver_customers') }} as c
cross join reference as r
left join orders as o
    on c.customer_id = o.customer_id
