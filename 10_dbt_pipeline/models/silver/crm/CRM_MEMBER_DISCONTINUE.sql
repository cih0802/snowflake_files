-- CRM_MEMBER_DISCONTINUE: 정기회원 후원중단 사건 정제 (grain=MBER_NO×SPNSR_DSCNTC_DE×SER_NO)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['MBER_NO', 'SPNSR_DSCNTC_DE', 'SER_NO'],
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))         as MBER_NO,
    CAST({{ clean_str('SPNSR_DSCNTC_DE') }} AS VARCHAR(8))  as SPNSR_DSCNTC_DE,
    SER_NO::NUMBER(10,0)                                     as SER_NO,
    CAST({{ clean_str('DSCNTC_RSN_CD') }} AS VARCHAR(3))    as DSCNTC_RSN_CD,
    CAST(NULL AS VARCHAR)                                    as DSCNTC_RSN_NM,   -- CRM_CODE 적재 후 채움
    CAST({{ clean_str('DSCNTC_PATH') }} AS VARCHAR(1))      as DSCNTC_PATH,
    CAST({{ clean_str('REGIST_DEPT_CD') }} AS VARCHAR(10))  as REGIST_DEPT_CD,
    'CRM'                                                    as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                      as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_MM_FDRM_MBER_SPNSR_DSCNTC') }}
