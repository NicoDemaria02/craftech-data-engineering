-- Pregunta 2: cantidad de ventas por semana (ISO, empieza el lunes).
-- La primera y la última semana del dataset son parciales.
select
    date_trunc('week', ordered_at)::date as semana,
    count(*)                             as ventas,
    count(distinct ordered_at::date)     as dias_con_ventas
from gold.gold_fct_orders
group by 1
order by 1
