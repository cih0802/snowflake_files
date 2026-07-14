-- DIM_PAYMENT: 결제수단 차원 스캐폴드 (CRM_PAYMENT_METHOD DISTINCT, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ FEE_TYPE(회비유형 정기/일시) 이중표현 설계결정 대기(§8). SETTLE_METHOD 라벨은 CRM_CODE 조인 후.
{{ config(
    materialized='incremental',
    unique_key='PAYMENT_SK',
    tags=['gold_pending']
) }}

with src as (
    select distinct SETLE_CD, SETLE_NM
    from {{ ref('CRM_PAYMENT_METHOD') }}
)

select
    {{ gold_sk(['SETLE_CD']) }}                   as PAYMENT_SK,
    SETLE_CD                                      as PAYMENT_METHOD,
    SETLE_NM                                      as SETTLE_METHOD,
    CAST(NULL AS VARCHAR)                          as FEE_TYPE,   -- ⚠️ 정기/일시 이중표현 결정 대기
    {{ gold_meta('CRM') }}
from src

union all
-- unknown 멤버(SK=0): 팩트 PAYMENT_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', NULL, NULL,
    {{ gold_meta('CRM') }}
