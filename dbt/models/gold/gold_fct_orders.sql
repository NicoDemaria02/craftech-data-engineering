-- Grano: 1 fila por orden.
-- El estado actual es el último evento por event_at (no por _ingested_at: un evento puede
-- llegar tarde). Ingreso = monto de la orden solo si su estado actual es delivered (D024).
with events as (
    select
        order_id,
        any_value(customer_id)                          as customer_id,
        min(event_at) filter (where status = 'created') as created_at,
        min(event_at)                                   as first_event_at,
        arg_max(status, event_at)                       as current_status,
        max(event_at)                                   as current_status_at,
        min(event_at) filter (where status = 'delivered') as delivered_at,
        min(event_at) filter (where status = 'cancelled') as cancelled_at,
        min(event_at) filter (where status = 'returned')  as returned_at
    from {{ ref('silver_orders') }}
    group by order_id
),

amounts as (
    select
        order_id,
        count(*)         as n_lines,
        sum(quantity)    as n_units,
        sum(line_amount) as order_amount
    from {{ ref('gold_fct_order_items') }}
    group by order_id
)

select
    e.order_id,
    e.customer_id,
    -- 5 órdenes no tienen evento created en la extracción: se usa su primer evento conocido.
    coalesce(e.created_at, e.first_event_at)   as ordered_at,
    e.created_at is not null                   as has_created_event,
    e.current_status,
    e.current_status_at,
    e.delivered_at,
    e.cancelled_at,
    e.returned_at,
    e.current_status = 'delivered'             as is_delivered,
    e.current_status = 'cancelled'             as is_cancelled,
    coalesce(a.n_lines, 0)                     as n_lines,
    coalesce(a.n_units, 0)                     as n_units,
    coalesce(a.order_amount, 0)                as order_amount,
    case when e.current_status = 'delivered'
         then coalesce(a.order_amount, 0) else 0 end as revenue_amount
from events as e
left join amounts as a
    on e.order_id = a.order_id
