-- CRM_SEND_MEMBER: 발송×회원 상세 통합 (EMAIL∪MSG_AT∪PSTMTR 발송 상세)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['SNDNG_KEY', 'SNDNG_DTL_KEY'],
    incremental_strategy='merge'
) }}

with email as (
    select
        SNDNG_KEY::NUMBER(10,0)                                  as SNDNG_KEY,
        SNDNG_DTL_KEY::NUMBER(10,0)                              as SNDNG_DTL_KEY,
        CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))          as MBER_NO,
        SNDNG_DE                                                 as SNDNG_DE,
        CAST({{ clean_str('SNDNG_RST_CD') }} AS VARCHAR(3))      as SNDNG_RST_CD,
        'EMAIL'                                                  as SEND_CHANNEL,
        {{ dw_meta('TD_MS_EMAIL_SNDNG_DTLS') }}
    from {{ source('bronze_crm', 'TD_MS_EMAIL_SNDNG_DTLS') }}
),

msg_at as (
    select
        SNDNG_KEY::NUMBER(10,0)                                  as SNDNG_KEY,
        SNDNG_DTL_KEY::NUMBER(10,0)                              as SNDNG_DTL_KEY,
        CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))          as MBER_NO,
        SNDNG_DT                                                 as SNDNG_DE,
        CAST({{ clean_str('TRNSMS_STAT_CD') }} AS VARCHAR(3))    as SNDNG_RST_CD,
        'MSG_AT'                                                 as SEND_CHANNEL,
        {{ dw_meta('TD_MS_MSG_AT_SNDNG_DTLS') }}
    from {{ source('bronze_crm', 'TD_MS_MSG_AT_SNDNG_DTLS') }}
),

pstmtr as (
    select
        SNDNG_KEY::NUMBER(10,0)                                  as SNDNG_KEY,
        SNDNG_DTL_KEY::NUMBER(10,0)                              as SNDNG_DTL_KEY,
        CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))          as MBER_NO,
        SNDNG_DE                                                 as SNDNG_DE,
        CAST(NULL AS VARCHAR(3))                                 as SNDNG_RST_CD,
        'PSTMTR'                                                 as SEND_CHANNEL,
        {{ dw_meta('TD_MS_PSTMTR_SNDNG_DTL') }}
    from {{ source('bronze_crm', 'TD_MS_PSTMTR_SNDNG_DTL') }}
)

select * from email
union all
select * from msg_at
union all
select * from pstmtr
