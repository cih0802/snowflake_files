-- CRM_ORG: 조직 마스터 정제 (grain=DEPT_ID, 실적상위=ACMSLT_UPPER_DEPT_ID 계층)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='DEPT_ID',
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('DEPT_ID') }} AS VARCHAR(20))             as DEPT_ID,
    CAST({{ clean_str('DEPT_NM') }} AS VARCHAR(50))             as DEPT_NM,
    CAST({{ clean_str('UPPER_DEPT_ID') }} AS VARCHAR(20))       as UPPER_DEPT_ID,
    CAST({{ clean_str('ACMSLT_UPPER_DEPT_ID') }} AS VARCHAR(20)) as ACMSLT_UPPER_DEPT_ID,
    CAST({{ clean_str('ACMSLT_DEPT_YN') }} AS VARCHAR(1))       as ACMSLT_DEPT_YN,
    STATS_DEPT_LVL::NUMBER(3,0)                                 as STATS_DEPT_LVL,
    CAST({{ clean_str('USE_YN') }} AS VARCHAR(1))               as USE_YN,
    SORT_ORDR::NUMBER(10,0)                                     as SORT_ORDR,
    'CRM'                                                       as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                         as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_CM_DEPT_INFO') }}
where {{ clean_str('DEPT_ID') }} is not null
