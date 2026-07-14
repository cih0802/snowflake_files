-- CRM_PAYMENT_BILLING: 납입/청구 통합 (회비 TM_PM_MBRFEE_ACMSLT ∪ 기부금 TM_PM_DNTN_DTLS)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='PAY_KEY',
    incremental_strategy='merge'
) }}

with mbrfee as (
    select
        'MF-' || MBRFEE_KEY::VARCHAR                      as PAY_KEY,
        '회비'                                             as PAYMENT_TYPE,
        CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))   as MBER_NO,
        CAST({{ clean_str('SPNSR_BSNS_ID') }} AS VARCHAR(20)) as SPNSR_BSNS_ID,
        RELATNSP_KEY::NUMBER(10,0)                        as RELATNSP_KEY,
        CAST({{ clean_str('MBRFEE_MT') }} AS VARCHAR(6))  as MBRFEE_MT,
        MBRFEE_SQNC::NUMBER(3,0)                          as MBRFEE_SQNC,
        RQEST_AMT::NUMBER(19,0)                           as RQEST_AMT,
        RQEST_DE                                          as RQEST_DE,
        PAY_AMT::NUMBER(10,0)                             as PAY_AMT,
        PAY_DE                                            as PAY_DE,
        CAST({{ clean_str('PAY_STAT_CD') }} AS VARCHAR(3)) as PAY_STAT_CD,
        CAST({{ clean_str('SETLE_CD') }} AS VARCHAR(3))   as SETLE_CD,
        CAST({{ clean_str('GFT_DIV_CD') }} AS VARCHAR(3)) as GFT_DIV_CD,
        {{ dw_meta('TM_PM_MBRFEE_ACMSLT') }}
    from {{ source('bronze_crm', 'TM_PM_MBRFEE_ACMSLT') }}
),

dntn as (
    select
        'DN-' || DNTN_KEY::VARCHAR                        as PAY_KEY,
        '기부금'                                           as PAYMENT_TYPE,
        CAST({{ clean_str('ONCE_MBER_NO') }} AS VARCHAR(10)) as MBER_NO,
        CAST({{ clean_str('SPNSR_BSNS_ID') }} AS VARCHAR(20)) as SPNSR_BSNS_ID,
        CAST(NULL AS NUMBER(10,0))                        as RELATNSP_KEY,
        CAST(NULL AS VARCHAR(6))                          as MBRFEE_MT,
        CAST(NULL AS NUMBER(3,0))                         as MBRFEE_SQNC,
        CAST(NULL AS NUMBER(19,0))                        as RQEST_AMT,
        CAST(NULL AS DATE)                                as RQEST_DE,
        PAY_AMT::NUMBER(10,0)                             as PAY_AMT,
        PAY_DE                                            as PAY_DE,
        CAST({{ clean_str('PAY_STAT_CD') }} AS VARCHAR(3)) as PAY_STAT_CD,
        CAST({{ clean_str('SETLE_CD') }} AS VARCHAR(3))   as SETLE_CD,
        CAST(NULL AS VARCHAR(3))                          as GFT_DIV_CD,
        {{ dw_meta('TM_PM_DNTN_DTLS') }}
    from {{ source('bronze_crm', 'TM_PM_DNTN_DTLS') }}
)

select * from mbrfee
union all
select * from dntn
