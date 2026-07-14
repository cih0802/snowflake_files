-- CRM_CAMPAIGN: 캠페인 마스터 정제 (TM_CM_CMPGN_MNG + BRND_NM LEFT JOIN, Q2/Q3/Q16 미해소)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='CMPGN_CD',
    incremental_strategy='merge'
) }}

select
    CAST({{ clean_str('c.CMPGN_CD') }} AS VARCHAR(20))      as CMPGN_CD,
    CAST({{ clean_str('c.CMPGN_NM') }} AS VARCHAR(200))     as CMPGN_NM,
    CAST({{ clean_str('c.UPPER_CMPGN_CD') }} AS VARCHAR(20)) as UPPER_CMPGN_CD,
    CAST({{ clean_str('c.UPPER_CMPGN_YN') }} AS VARCHAR(1)) as UPPER_CMPGN_YN,
    CAST({{ clean_str('c.BRND_ID') }} AS VARCHAR(30))        as BRND_ID,
    CAST({{ clean_str('b.BRND_NM') }} AS VARCHAR(200))       as BRND_NM,
    CAST({{ clean_str('c.PR_MTH_CD') }} AS VARCHAR(3))       as PR_MTH_CD,
    CAST({{ clean_str('c.SPNSR_BSNS_ID') }} AS VARCHAR(100)) as SPNSR_BSNS_ID,
    c.CMPGN_CTGR_CD::NUMBER(10,0)                            as CMPGN_CTGR_CD,
    c.CMPGN_TYPE1_BSN::NUMBER(10,0)                          as CMPGN_TYPE1_BSN,
    c.CMPGN_TYPE2_BSN::NUMBER(10,0)                          as CMPGN_TYPE2_BSN,
    c.MKTG_CMPGN_NM::NUMBER(10,0)                            as MKTG_CMPGN_NM,
    -- ⚠️Q16: TM_CM_MKTNG_CMPGN_MNG 조인키 미확정 → NULL 보존
    CAST(NULL AS VARCHAR(200))                               as MK_CMPGN_NM,
    CAST({{ clean_str('c.CMPGN_STRT_DE') }} AS VARCHAR(8))  as CMPGN_STRT_DE,
    'CRM'                                                    as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                      as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from {{ source('bronze_crm', 'TM_CM_CMPGN_MNG') }} c
left join {{ source('bronze_crm', 'TM_CM_BRND_MNG') }} b
    on {{ clean_str('c.BRND_ID') }} = {{ clean_str('b.BRND_ID') }}
