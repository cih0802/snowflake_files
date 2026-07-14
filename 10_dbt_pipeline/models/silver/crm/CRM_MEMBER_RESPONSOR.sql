-- CRM_MEMBER_RESPONSOR: 정기회원 재후원 사건 정제 (grain=MBER_NO×SER_NO×RE_SPNSR_DE)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['MBER_NO', 'SER_NO', 'RE_SPNSR_DE'],
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))        as MBER_NO,
    SER_NO::NUMBER(10,0)                                   as SER_NO,
    CAST({{ clean_str('RE_SPNSR_DE') }} AS VARCHAR(8))     as RE_SPNSR_DE,
    CAST({{ clean_str('REGIST_DEPT_CD') }} AS VARCHAR(10)) as REGIST_DEPT_CD,
    'CRM'                                                  as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                    as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_MM_FDRM_MBER_RE_SPNSR') }}
