-- SILVER 스키마명을 커스텀 값 그대로 사용(default_ 접두사 방지)
-- Co-authored with CoCo
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
