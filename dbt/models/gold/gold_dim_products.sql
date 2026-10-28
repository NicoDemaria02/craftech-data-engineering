-- Grano: 1 fila por producto.
select
    product_id,
    product_name,
    category,
    unit_price,
    currency
from {{ ref('silver_products') }}
