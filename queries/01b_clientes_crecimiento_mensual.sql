-- Pregunta 1: ¿cómo crece la base de clientes mes a mes? (por fecha de registro)
with por_mes as (
    select
        date_trunc('month', registered_at)::date as mes,
        count(*)                                 as clientes_nuevos
    from gold.gold_dim_customers
    group by 1
)

select
    mes,
    clientes_nuevos,
    sum(clientes_nuevos) over (order by mes)     as clientes_acumulados,
    round(100.0 * clientes_nuevos
          / nullif(sum(clientes_nuevos) over (order by mes) - clientes_nuevos, 0), 2)
                                                 as pct_crecimiento_mensual
from por_mes
order by mes
