-- CRM_MEMBER_SPONSOR_BIZ: 회원×후원사업 약정 정제 (grain=SPNSR_NO×SPNSR_BSNS_NO, Q15 NO→ID 크로스워크 소스)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['SPNSR_NO', 'SPNSR_BSNS_NO'],
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('SPNSR_NO') }} AS VARCHAR(9))              as SPNSR_NO,
    SPNSR_BSNS_NO::NUMBER(19,0)                                  as SPNSR_BSNS_NO,
    CAST({{ clean_str('SPNSR_BSNS_ID') }} AS VARCHAR(20))        as SPNSR_BSNS_ID,
    SPNSR_AMT::NUMBER(19,0)                                      as SPNSR_AMT,
    CAST({{ clean_str('SPNSR_DSCNTC_YN') }} AS VARCHAR(1))       as SPNSR_DSCNTC_YN,
    CAST({{ clean_str('SPNSR_DSCNTC_DE') }} AS VARCHAR(8))       as SPNSR_DSCNTC_DE,
    CAST({{ clean_str('SPNSR_DSCNTC_RSN_CD') }} AS VARCHAR(3))   as SPNSR_DSCNTC_RSN_CD,
    'CRM'                                                        as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                          as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_MM_FDRM_MBER_SPNSR_BSNS') }}
