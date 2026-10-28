-- Pregunta 4: ¿qué proporción de las órdenes se entrega y cuál se cancela?
-- Sobre el estado actual de cada orden (último evento por event_at).
select
    current_status                                   as estado,
    count(*)                                         as ordenes,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as pct_ordenes
from gold.gold_fct_orders
group by 1
order by ordenes desc
