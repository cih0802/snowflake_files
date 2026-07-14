-- CRM_EVENT_PARTICIPATION: 행사×참여자 통합 (TD_MS_EVENT_PRTCPNT_DTL∪TD_MS_CRMN_PRTCPNT)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['EVENT_KEY', 'MBER_NO', 'PARTCPT_SEQ'],
    incremental_strategy='merge'
) }}

with event_part as (
    select
        'EV-' || EVENT_CD::VARCHAR                               as EVENT_KEY,
        CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))          as MBER_NO,
        PARTCPT_SEQ::NUMBER(10,0)                                as PARTCPT_SEQ,
        CAST({{ clean_str('PARTCPT_STAT_CD') }} AS VARCHAR(3))   as PARTCPT_STAT_CD,
        CAST({{ clean_str('PARTCPT_CHNNL_CD') }} AS VARCHAR(3))  as PARTCPT_CHNNL_CD,
        CAST({{ clean_str('PARTCPT_PATH_CD') }} AS VARCHAR(3))   as PARTCPT_PATH_CD,
        PRZWIN_CD::NUMBER(10,0)                                  as PRZWIN_CD,
        CAST(NULL AS NUMBER(19,0))                               as RCPMNY_AMT,
        PARTCPT_DT                                               as PARTCPT_DT,
        {{ dw_meta('TD_MS_EVENT_PRTCPNT_DTL') }}
    from {{ source('bronze_crm', 'TD_MS_EVENT_PRTCPNT_DTL') }}
),

crmn_part as (
    select
        'CR-' || CRMN_CD::VARCHAR                                as EVENT_KEY,
        CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))          as MBER_NO,
        PRTCPNT_KEY::NUMBER(10,0)                                as PARTCPT_SEQ,
        CAST({{ clean_str('PARTCPT_STAT_CD') }} AS VARCHAR(3))   as PARTCPT_STAT_CD,
        CAST({{ clean_str('RQST_PATH_CD') }} AS VARCHAR(3))      as PARTCPT_CHNNL_CD,
        CAST(NULL AS VARCHAR(3))                                 as PARTCPT_PATH_CD,
        CAST(NULL AS NUMBER(10,0))                               as PRZWIN_CD,
        RCPMNY_AMT::NUMBER(19,0)                                 as RCPMNY_AMT,
        FRST_REGIST_DT                                           as PARTCPT_DT,
        {{ dw_meta('TD_MS_CRMN_PRTCPNT') }}
    from {{ source('bronze_crm', 'TD_MS_CRMN_PRTCPNT') }}
)

select * from event_part
union all
select * from crmn_part
