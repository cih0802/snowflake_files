-- CRM_MEMBER_DEV: 정기회원 개발약정 실적 정제 (grain=SPNSR_NO×SPNSR_BSNS_NO×OCCRRNC_DE×SER_NO)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['SPNSR_NO', 'SPNSR_BSNS_NO', 'OCCRRNC_DE', 'SER_NO'],
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('SPNSR_NO') }} AS VARCHAR(9))      as SPNSR_NO,
    SPNSR_BSNS_NO::NUMBER(19,0)                          as SPNSR_BSNS_NO,
    CAST({{ clean_str('OCCRRNC_DE') }} AS VARCHAR(8))    as OCCRRNC_DE,
    SER_NO::NUMBER(10,0)                                 as SER_NO,
    CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))      as MBER_NO,
    CAST({{ clean_str('SPNSR_BSNS_ID') }} AS VARCHAR(20)) as SPNSR_BSNS_ID,
    SPNSR_AMT::NUMBER(19,0)                              as SPNSR_AMT,
    CAST({{ clean_str('DVLP_DIV_CD') }} AS VARCHAR(3))   as DVLP_DIV_CD,
    CAST({{ clean_str('ACT_DEPT_CD') }} AS VARCHAR(10))  as ACT_DEPT_CD,
    CAST({{ clean_str('ACMSLT_DEPT_CD') }} AS VARCHAR(10)) as ACMSLT_DEPT_CD,
    CAST({{ clean_str('CMPGN_CD') }} AS VARCHAR(20))     as CMPGN_CD,
    CAST({{ clean_str('SETLE_CD') }} AS VARCHAR(3))      as SETLE_CD,
    'CRM'                                                as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_MM_FDRM_MBER_DVLP_AMT') }}
