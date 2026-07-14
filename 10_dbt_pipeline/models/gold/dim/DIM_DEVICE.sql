-- DIM_DEVICE: 디바이스 차원 (GA4_DEVICE → DEVICE_TYPE DISTINCT, GOLD 축약)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='DEVICE_SK',
    tags=['gold_ready']
) }}

with src as (
    select distinct DEVICE_TYPE
    from {{ ref('GA4_DEVICE') }}
    where DEVICE_TYPE is not null
)

select
    {{ gold_sk(['DEVICE_TYPE']) }}  as DEVICE_SK,
    DEVICE_TYPE                     as DEVICE_TYPE,
    {{ gold_meta('GA4') }}
from src
