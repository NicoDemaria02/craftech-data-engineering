-- Pregunta 1: ¿cuántos clientes tenemos y cuántos están activos?
-- Activo = al menos 1 orden no cancelada en los 90 días previos a la fecha de corte (D024).
select
    any_value(reference_date)                          as fecha_corte,
    count(*)                                           as clientes_total,
    count(*) filter (where n_orders > 0)               as clientes_con_compras,
    count(*) filter (where is_active)                  as clientes_activos,
    round(100.0 * count(*) filter (where is_active) / count(*), 2) as pct_activos
from gold.gold_dim_customers
