-- Grano: 1 fila por cliente. raw.customers viene limpio (ver catalog/bronze/customers.md):
-- solo se seleccionan columnas explícitas para que un cambio en la fuente no pase en silencio.
-- Es una foto completa (un solo _extracted_at): se reconstruye entera en cada corrida.
select
    customer_id,
    first_name,
    last_name,
    email,
    country_code,
    segment,
    created_at,
    updated_at,
    _extracted_at
from {{ source('raw', 'customers') }}
where {{ run_date_filter('created_at') }}
