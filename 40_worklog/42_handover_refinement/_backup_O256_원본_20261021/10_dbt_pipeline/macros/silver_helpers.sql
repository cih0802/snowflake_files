-- 공통 정제 매크로 (BRONZE→SILVER 표준 규칙)
-- Co-authored with CoCo

-- 문자열 NULL 표준화: 빈문자·'NULL'·'-'·공백 → NULL, TRIM 적용
{% macro clean_str(col) -%}
    NULLIF(NULLIF(NULLIF(TRIM({{ col }}), ''), 'NULL'), '-')
{%- endmacro %}

-- SILVER 표준 감사 메타 — SOURCE_SYSTEM · SOURCE_TABLE · LOAD_TS(최초) · UPDATE_TS(최종) · BATCH_ID(=invocation_id)
-- src_table: 행별 출처 테이블명(다중원천 UNION 시 구분)
{% macro dw_meta(src_table) -%}
    'CRM'                                    AS DW_SOURCE_SYSTEM,
    '{{ src_table }}'                        AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '{{ invocation_id }}'                    AS DW_BATCH_ID
{%- endmacro %}
