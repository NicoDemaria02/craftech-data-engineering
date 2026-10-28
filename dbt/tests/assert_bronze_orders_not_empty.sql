-- Falla si la extracción de órdenes llegó vacía (devuelve 1 fila = violación).
select 'raw.orders vacío' as problema
where (select count(*) from {{ source('raw', 'orders') }}) = 0
