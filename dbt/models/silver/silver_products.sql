-- Grano: 1 fila por producto. raw.products viene limpio (ver catalog/bronze/products.md).
-- unit_price es el precio de lista ACTUAL: no hay historial de precios en la fuente.
-- Es una foto completa (un solo _extracted_at): se reconstruye entera en cada corrida.
select
    product_id,
    product_name,
    category,
    unit_price,
    currency,
    created_at,
    updated_at,
    _extracted_at
from {{ source('raw', 'products') }}
where {{ run_date_filter('created_at') }}
