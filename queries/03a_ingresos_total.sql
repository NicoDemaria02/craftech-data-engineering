-- Pregunta 3: ingresos totales.
-- Ingreso = órdenes con estado actual delivered (D024), a precio de lista actual (D019).
select
    sum(revenue_amount)                                    as ingresos_total,
    count(*) filter (where is_delivered)                   as ordenes_con_ingreso,
    sum(order_amount) filter (where current_status in ('created', 'paid', 'shipped'))
                                                           as monto_en_curso
from gold.gold_fct_orders
