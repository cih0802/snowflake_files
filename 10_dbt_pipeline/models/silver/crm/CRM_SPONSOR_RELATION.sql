-- CRM_SPONSOR_RELATION: 결연(회원×아동) 정제 (grain=RELATNSP_KEY, Q15 SPNSR_BSNS_ID 크로스워크 파생)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='RELATNSP_KEY',
    incremental_strategy='merge'
) }}

select
    RELATNSP_KEY::NUMBER(10,0)                              as RELATNSP_KEY,
    CAST({{ clean_str('SPNSR_NO') }} AS VARCHAR(9))         as SPNSR_NO,
    SPNSR_BSNS_NO::NUMBER(19,0)                            as SPNSR_BSNS_NO,
    -- ⚠️Q15: SPNSR_BSNS_NO→SPNSR_BSNS_ID 크로스워크. CRM_MEMBER_SPONSOR_BIZ 적재 후 채움
    CAST(NULL AS VARCHAR(20))                              as SPNSR_BSNS_ID,
    CHILD_CD::NUMBER(10,0)                                 as CHILD_CD,
    CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))         as MBER_NO,
    RELATNSP_STRT_DE                                       as RELATNSP_STRT_DE,
    RELATNSP_DSCNTC_DE                                     as RELATNSP_DSCNTC_DE,
    CAST({{ clean_str('RELATNSP_DSCNTC_YN') }} AS VARCHAR(1)) as RELATNSP_DSCNTC_YN,
    'CRM'                                                  as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                    as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_RM_RELATNSP_MSTR_INFO') }}
