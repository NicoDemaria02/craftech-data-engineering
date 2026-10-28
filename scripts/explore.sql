-- Sesión de exploración: adjunta bronze y el warehouse en solo lectura.
-- Uso (desde la raíz del repo):  duckdb -init scripts/explore.sql -ui
-- Cerrar la UI antes de correr dbt: un archivo abierto acá bloquea su escritura.
ATTACH 'data/ecommerce.duckdb' AS ecom (READ_ONLY);
ATTACH 'data/warehouse.duckdb' AS wh (READ_ONLY);
