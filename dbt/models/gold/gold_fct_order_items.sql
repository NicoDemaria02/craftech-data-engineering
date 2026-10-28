-- Grano: 1 fila por línea de orden (order_id, line_number).
-- Supuesto (D013/D019): raw no trae el precio de venta. Se usa el precio de lista ACTUAL
-- del catálogo, así que el monto de una línea no refleja cambios de precio posteriores.
select
    i.order_id,
    i.line_number,
    i.product_id,
    p.category,
    i.quantity,
    p.unit_price,
    i.quantity * p.unit_price as line_amount
from {{ ref('silver_order_items') }} as i
inner join {{ ref('silver_products') }} as p
    on i.product_id = p.product_id
