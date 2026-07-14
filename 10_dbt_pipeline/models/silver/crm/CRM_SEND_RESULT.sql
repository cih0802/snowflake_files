-- CRM_SEND_RESULT: 발송×채널 집계 통합 (EMAIL∪MSG_AT∪PSTMTR 집계, TOT_CLICK_CNT VARCHAR→NUMBER)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['SNDNG_KEY', 'SEND_CHANNEL'],
    incremental_strategy='merge'
) }}

with email as (
    select
        SNDNG_KEY::NUMBER(10,0)                                  as SNDNG_KEY,
        'EMAIL'                                                  as SEND_CHANNEL,
        SNDNG_CNT::NUMBER(10,0)                                  as SNDNG_CNT,
        SUCCES_CNT::NUMBER(10,0)                                 as SUCCES_CNT,
        FAILR_CNT::NUMBER(10,0)                                  as FAILR_CNT,
        TRY_TO_NUMBER({{ clean_str('URL_OTHBC_CNT_CTNT') }})     as TOT_CLICK_CNT,
        {{ dw_meta('TD_MS_EMAIL_LQY_SNDNG') }}
    from {{ source('bronze_crm', 'TD_MS_EMAIL_LQY_SNDNG') }}
),

msg_at as (
    select
        SNDNG_KEY::NUMBER(10,0)                                  as SNDNG_KEY,
        'MSG_AT'                                                 as SEND_CHANNEL,
        SNDNG_CNT::NUMBER(10,0)                                  as SNDNG_CNT,
        SUCCES_CNT::NUMBER(10,0)                                 as SUCCES_CNT,
        AT_FAILR_CNT::NUMBER(10,0)                               as FAILR_CNT,
        TRY_TO_NUMBER({{ clean_str('TOT_CLICK_CNT_CTNT') }})     as TOT_CLICK_CNT,
        {{ dw_meta('TD_MS_MSG_AT_LQY_SNDNG') }}
    from {{ source('bronze_crm', 'TD_MS_MSG_AT_LQY_SNDNG') }}
),

pstmtr as (
    select
        SNDNG_KEY::NUMBER(10,0)                                  as SNDNG_KEY,
        'PSTMTR'                                                 as SEND_CHANNEL,
        SNDNG_CNT::NUMBER(10,0)                                  as SNDNG_CNT,
        CAST(NULL AS NUMBER(10,0))                               as SUCCES_CNT,
        CAST(NULL AS NUMBER(10,0))                               as FAILR_CNT,
        CAST(NULL AS NUMBER)                                     as TOT_CLICK_CNT,
        {{ dw_meta('TD_MS_PSTMTR_LQY_SNDNG') }}
    from {{ source('bronze_crm', 'TD_MS_PSTMTR_LQY_SNDNG') }}
)

select * from email
union all
select * from msg_at
union all
select * from pstmtr
