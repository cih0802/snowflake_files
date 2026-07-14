-- CRM_MEMBER_AMT_CHANGE: 정기회원 증감(증액/감액) 사건 정제 (grain=OCCRRNC_DE×SER_NO)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['OCCRRNC_DE', 'SER_NO'],
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('OCCRRNC_DE') }} AS VARCHAR(8))    as OCCRRNC_DE,
    SER_NO::NUMBER(10,0)                                 as SER_NO,
    CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))      as MBER_NO,
    SPNSR_AMT::NUMBER(19,0)                              as SPNSR_AMT,
    CAST({{ clean_str('RDCAMT_YN') }} AS VARCHAR(1))     as RDCAMT_YN,
    CAST({{ clean_str('ACMSLT_DEPT_CD') }} AS VARCHAR(10)) as ACMSLT_DEPT_CD,
    CAST({{ clean_str('CMPGN_CD') }} AS VARCHAR(20))     as CMPGN_CD,
    'CRM'                                                as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_MM_FDRM_MBER_IRSD') }}
