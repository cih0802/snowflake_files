-- CRM_EVENT: 행사 마스터 통합 (TM_MS_EVENT∪TM_MS_CRMN, EVENT_KEY=파생 접두 키)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='EVENT_KEY',
    incremental_strategy='merge'
) }}

with event as (
    select
        'EV-' || EVENT_CD::VARCHAR                               as EVENT_KEY,
        'EVENT'                                                  as EVENT_SOURCE,
        CAST({{ clean_str('EVENT_DIV_CD') }} AS VARCHAR(3))      as EVENT_DIV_CD,
        CAST({{ clean_str('EVENT_NM') }} AS VARCHAR(200))        as EVENT_NM,
        CAST({{ clean_str('STRT_DATE') }} AS VARCHAR(8))         as STRT_DE,
        CAST({{ clean_str('END_DATE') }} AS VARCHAR(8))          as END_DE,
        PRZWIN_PSNNL_CO::NUMBER(10,0)                            as RCRIT_PSNNL_CO,
        CAST(NULL AS VARCHAR(20))                                as BRNCH_DEPT_ID,
        {{ dw_meta('TM_MS_EVENT') }}
    from {{ source('bronze_crm', 'TM_MS_EVENT') }}
),

crmn as (
    select
        'CR-' || CRMN_CD::VARCHAR                                as EVENT_KEY,
        'CRMN'                                                   as EVENT_SOURCE,
        CAST({{ clean_str('CRMN_DIV_CD') }} AS VARCHAR(3))       as EVENT_DIV_CD,
        CAST({{ clean_str('CRMN_TIT') }} AS VARCHAR(200))        as EVENT_NM,
        CAST({{ clean_str('CRMN_STRT_DE') }} AS VARCHAR(8))      as STRT_DE,
        CAST({{ clean_str('CRMN_END_DE') }} AS VARCHAR(8))       as END_DE,
        RCRIT_PSNNL_CO::NUMBER(10,0)                             as RCRIT_PSNNL_CO,
        CAST({{ clean_str('BRNCH_DEPT_ID') }} AS VARCHAR(20))    as BRNCH_DEPT_ID,
        {{ dw_meta('TM_MS_CRMN') }}
    from {{ source('bronze_crm', 'TM_MS_CRMN') }}
)

select * from event
union all
select * from crmn
