-- CRM_SEND_REQUEST: 발송요청 마스터 통합 (EMAIL∪MSG_AT∪PSTMTR, Q5 REQ_SEQ_NO 미해소)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='SNDNG_KEY',
    incremental_strategy='merge'
) }}

with email as (
    select
        SNDNG_KEY::NUMBER(10,0)                                  as SNDNG_KEY,
        'EMAIL'                                                  as SEND_CHANNEL,
        CAST({{ clean_str('SNDNG_TY_CD') }} AS VARCHAR(3))       as SNDNG_TY_CD,
        CAST({{ clean_str('TIT') }} AS VARCHAR(100))             as TIT,
        SNDNG_STDR_DE                                            as SNDNG_STDR_DE,
        CAST(NULL AS NUMBER(19,0))                               as REQ_SEQ_NO,   -- ⚠️Q5 미해소
        {{ dw_meta('TM_MS_EMAIL_SNDNG') }}
    from {{ source('bronze_crm', 'TM_MS_EMAIL_SNDNG') }}
),

msg_at as (
    select
        SNDNG_KEY::NUMBER(10,0)                                  as SNDNG_KEY,
        'MSG_AT'                                                 as SEND_CHANNEL,
        CAST({{ clean_str('SNDNG_TY_CD') }} AS VARCHAR(3))       as SNDNG_TY_CD,
        CAST({{ clean_str('TIT') }} AS VARCHAR(100))             as TIT,
        SNDNG_STDR_DE                                            as SNDNG_STDR_DE,
        CAST(NULL AS NUMBER(19,0))                               as REQ_SEQ_NO,
        {{ dw_meta('TM_MS_MSG_AT_SNDNG') }}
    from {{ source('bronze_crm', 'TM_MS_MSG_AT_SNDNG') }}
),

pstmtr as (
    select
        SNDNG_KEY::NUMBER(10,0)                                  as SNDNG_KEY,
        'PSTMTR'                                                 as SEND_CHANNEL,
        CAST({{ clean_str('SNDNG_TY_CD') }} AS VARCHAR(3))       as SNDNG_TY_CD,
        CAST(NULL AS VARCHAR(100))                               as TIT,
        SNDNG_STDR_DE::TIMESTAMP_NTZ                             as SNDNG_STDR_DE,
        CAST(NULL AS NUMBER(19,0))                               as REQ_SEQ_NO,
        {{ dw_meta('TM_MS_PSTMTR_SNDNG') }}
    from {{ source('bronze_crm', 'TM_MS_PSTMTR_SNDNG') }}
)

select * from email
union all
select * from msg_at
union all
select * from pstmtr
