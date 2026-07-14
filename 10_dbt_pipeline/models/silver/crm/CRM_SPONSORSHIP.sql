-- CRM_SPONSORSHIP: 후원사업 마스터 정제 (grain=SPNSR_BSNS_ID, 실측 50개)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='SPNSR_BSNS_ID',
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('SPNSR_BSNS_ID') }} AS VARCHAR(20))       as SPNSR_BSNS_ID,
    CAST({{ clean_str('SPNSR_BSNS_NM') }} AS VARCHAR(50))       as SPNSR_BSNS_NM,
    CAST({{ clean_str('SPNSR_BSNS_ABRV_CD') }} AS VARCHAR(3))   as SPNSR_BSNS_ABRV_CD,
    CAST({{ clean_str('SPNSR_DIV_CD') }} AS VARCHAR(3))         as SPNSR_DIV_CD,
    CAST({{ clean_str('DNTN_TY_CD') }} AS VARCHAR(3))           as DNTN_TY_CD,
    CAST({{ clean_str('CPR_DIV_CD') }} AS VARCHAR(3))           as CPR_DIV_CD,
    'CRM'                                                       as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                         as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_CM_SPNSR_BSNS_INFO') }}
where {{ clean_str('SPNSR_BSNS_ID') }} is not null
