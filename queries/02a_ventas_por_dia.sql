-- Pregunta 2: cantidad de ventas por día.
-- Venta = orden creada, cuente o no como ingreso después (D024).
select
    ordered_at::date as dia,
    count(*)         as ventas
from gold.gold_fct_orders
group by 1
order by 1
