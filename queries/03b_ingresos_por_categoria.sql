-- Pregunta 3: ingresos por categoría de producto.
select
    i.category                                   as categoria,
    sum(i.line_amount)                           as ingresos,
    round(100.0 * sum(i.line_amount) / sum(sum(i.line_amount)) over (), 2) as pct_ingresos,
    sum(i.quantity)                              as unidades
from gold.gold_fct_order_items as i
inner join gold.gold_fct_orders as o
    on i.order_id = o.order_id
where o.is_delivered
group by 1
order by ingresos desc
