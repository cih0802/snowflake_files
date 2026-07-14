-- CRM_MEMBER_STATUS_HIST: 정기회원 상태전이 이력 SCD2 (EFFECTIVE_FROM/TO·IS_CURRENT 파생)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['MBER_NO', 'SER_NO'],
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))      as MBER_NO,
    SER_NO::NUMBER(10,0)                                  as SER_NO,
    CAST({{ clean_str('BF_STAT_CD') }} AS VARCHAR(3))    as BF_STAT_CD,
    CAST(NULL AS VARCHAR)                                 as BF_STAT_NM,    -- CRM_CODE 적재 후 채움
    CAST({{ clean_str('CHN_STAT_CD') }} AS VARCHAR(3))   as CHN_STAT_CD,
    CAST(NULL AS VARCHAR)                                 as CHN_STAT_NM,   -- CRM_CODE 적재 후 채움
    FRST_REGIST_DT                                        as EFFECTIVE_FROM,
    LEAD(FRST_REGIST_DT) OVER (
        PARTITION BY MBER_NO ORDER BY SER_NO
    )                                                     as EFFECTIVE_TO,
    (LEAD(FRST_REGIST_DT) OVER (
        PARTITION BY MBER_NO ORDER BY SER_NO
    ) IS NULL)                                            as IS_CURRENT,
    'CRM'                                                 as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                   as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TH_MM_FDRM_MBER_STNG_DTLS') }}
