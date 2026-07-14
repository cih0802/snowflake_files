-- CRM_PAYMENT_METHOD: 결제수단 현재상태 정제 (SCD1, DW_UPDATE_TS=LAST_UPDT_DT)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='SETLE_KEY',
    incremental_strategy='merge'
) }}

select
    SETLE_KEY::NUMBER(10,0)                               as SETLE_KEY,
    CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))       as MBER_NO,
    CAST({{ clean_str('SETLE_CD') }} AS VARCHAR(3))       as SETLE_CD,
    CAST(NULL AS VARCHAR)                                 as SETLE_NM,        -- CRM_CODE 적재 후 채움
    CAST({{ clean_str('CARD_DIV_CD') }} AS VARCHAR(3))    as CARD_DIV_CD,
    CAST({{ clean_str('FNLT_CD') }} AS VARCHAR(10))       as FNLT_CD,
    WTDRW_STRT_DE                                         as WTDRW_STRT_DE,
    CAST({{ clean_str('SETLE_STAT_CD') }} AS VARCHAR(3))  as SETLE_STAT_CD,
    'CRM'                                                 as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                   as DW_LOAD_TS,
    LAST_UPDT_DT                                          as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_PM_SETLE_INFO') }}
