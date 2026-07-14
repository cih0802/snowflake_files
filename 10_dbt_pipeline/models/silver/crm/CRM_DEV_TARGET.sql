-- CRM_DEV_TARGET: 회원개발 목표 정제 (grain=STDYY×STDR_MT×MBER_DVLP_DIV_CD×DEPT_ID)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['STDYY', 'STDR_MT', 'MBER_DVLP_DIV_CD', 'DEPT_ID'],
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('STDYY') }} AS VARCHAR(4))             as STDYY,
    CAST({{ clean_str('STDR_MT') }} AS VARCHAR(6))           as STDR_MT,
    CAST({{ clean_str('MBER_DVLP_DIV_CD') }} AS VARCHAR(1)) as MBER_DVLP_DIV_CD,
    CAST({{ clean_str('DEPT_ID') }} AS VARCHAR(20))          as DEPT_ID,
    GOAL_CNT::NUMBER(10,0)                                   as GOAL_CNT,
    'CRM'                                                    as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                      as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_CM_MBER_DVLP_GOAL') }}
