-- CRM_RELATION_ACTIVITY: 결연활동 통합 (서신∪선물금, EHGT 제외, ACTIVITY_KEY=파생 접두 키)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='ACTIVITY_KEY',
    incremental_strategy='merge'
) }}

with letter as (
    select
        'LT-' || RELATNSP_KEY::VARCHAR || '-' || MNG_NO          as ACTIVITY_KEY,
        'LETTER'                                                  as ACTIVITY_TYPE,
        RELATNSP_KEY::NUMBER(10,0)                               as RELATNSP_KEY,
        CAST({{ clean_str('MNG_NO') }} AS VARCHAR(7))            as MNG_NO,
        CAST(NULL AS NUMBER(10,0))                               as GFTMNEY,
        LETTER_DIV_CD::NUMBER(10,0)                              as LETTER_DIV_CD,
        RCEPT_DE                                                 as RCEPT_DE,
        SNDNG_DE                                                 as SNDNG_DE,
        {{ dw_meta('TM_RM_RELATNSP_LETTER_INFO') }}
    from {{ source('bronze_crm', 'TM_RM_RELATNSP_LETTER_INFO') }}
),

gftmney as (
    select
        'GF-' || RELATNSP_KEY::VARCHAR || '-' || MNG_NO          as ACTIVITY_KEY,
        'GIFTMONEY'                                              as ACTIVITY_TYPE,
        RELATNSP_KEY::NUMBER(10,0)                               as RELATNSP_KEY,
        CAST({{ clean_str('MNG_NO') }} AS VARCHAR(7))            as MNG_NO,
        GFTMNEY::NUMBER(10,0)                                    as GFTMNEY,
        CAST(NULL AS NUMBER(10,0))                               as LETTER_DIV_CD,
        SETLE_DE                                                 as RCEPT_DE,
        SNDNG_DE                                                 as SNDNG_DE,
        {{ dw_meta('TM_RM_RELATNSP_GFTMNEY_INFO') }}
    from {{ source('bronze_crm', 'TM_RM_RELATNSP_GFTMNEY_INFO') }}
)

select * from letter
union all
select * from gftmney
