{#-
  Por defecto dbt nombra el schema "<target>_<custom>" (ej: main_silver).
  Acá usamos el nombre custom tal cual: silver, gold.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
