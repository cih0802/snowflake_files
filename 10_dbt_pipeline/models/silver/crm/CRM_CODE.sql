-- CRM_CODE: 공통 코드 사전 정제 (TC_CMMN_DTL_CD, grain=CD_ID×DTL_CD_ID 복합키)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['CD_ID', 'DTL_CD_ID'],
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('CD_ID') }} AS VARCHAR(20))        as CD_ID,
    CAST({{ clean_str('DTL_CD_ID') }} AS VARCHAR(50))    as DTL_CD_ID,
    CAST({{ clean_str('DTL_CD_NM') }} AS VARCHAR(100))   as DTL_CD_NM,
    CAST({{ clean_str('UPPER_CD_ID') }} AS VARCHAR(20))  as UPPER_CD_ID,
    SORT_ORDR::NUMBER(10,0)                              as SORT_ORDR,
    CAST({{ clean_str('USE_YN') }} AS VARCHAR(1))        as USE_YN,
    'CRM'                                                as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TC_CMMN_DTL_CD') }}
where {{ clean_str('CD_ID') }} is not null
  and {{ clean_str('DTL_CD_ID') }} is not null
