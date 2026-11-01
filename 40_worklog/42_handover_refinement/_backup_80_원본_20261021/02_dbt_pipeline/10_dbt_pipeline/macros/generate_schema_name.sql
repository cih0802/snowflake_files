-- target=dev2(일적재 테스트) 실행 시 SILVER/GOLD 산출 스키마에 _2 접미를 붙인다(11_일적재pipeline 구성 §O1).
-- Co-authored with CoCo
-- SILVER 스키마명을 커스텀 값 그대로 사용(default_ 접두사 방지)
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set suffix = '_2' if target.name == 'dev2' else '' -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ (custom_schema_name | trim) ~ suffix }}
    {%- endif -%}
{%- endmacro %}
