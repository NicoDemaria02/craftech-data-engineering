{#-
  Simula la corrida diaria (D009): con --vars '{run_date: 2026-03-15}' cada modelo solo
  "ve" lo que existía al final de ese día. Sin run_date, procesa todo.
-#}
{% macro run_date_filter(column) -%}
    {%- if var('run_date', none) -%}
        {{ column }} < cast('{{ var("run_date") }}' as date) + interval 1 day
    {%- else -%}
        true
    {%- endif -%}
{%- endmacro %}
