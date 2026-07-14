-- DIM_GA_EVENT: 이벤트분류 차원 (GA4_EVENT_DIM → category/label/action DISTINCT)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='GA_EVENT_SK',
    tags=['gold_ready']
) }}

with src as (
    select distinct EVENT_CATEGORY, EVENT_LABEL, EVENT_ACTION
    from {{ ref('GA4_EVENT_DIM') }}
)

select
    {{ gold_sk(['EVENT_CATEGORY','EVENT_LABEL','EVENT_ACTION']) }} as GA_EVENT_SK,
    EVENT_CATEGORY                  as EVENT_CATEGORY,
    EVENT_LABEL                     as EVENT_LABEL,
    EVENT_ACTION                    as EVENT_ACTION,
    {{ gold_meta('GA4') }}
from src
