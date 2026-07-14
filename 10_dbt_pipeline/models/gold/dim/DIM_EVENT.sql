-- DIM_EVENT: 행사 차원 스캐폴드 (CRM_EVENT, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ APPLY_CHANNEL 원천/파생규칙 미정(ADMIN A-10 대기).
{{ config(
    materialized='incremental',
    unique_key='EVENT_SK',
    tags=['gold_pending']
) }}

with e as (
    select * from {{ ref('CRM_EVENT') }}
)

select
    {{ gold_sk(['EVENT_KEY']) }}                  as EVENT_SK,
    EVENT_KEY                                     as EVENT_BK,
    EVENT_SOURCE                                  as EVENT_KIND,
    EVENT_DIV_CD                                  as EVENT_CATEGORY,
    EVENT_NM                                      as EVENT_NAME,
    TRY_TO_DATE(STRT_DE, 'YYYYMMDD')              as EVENT_START_DATE,
    TRY_TO_DATE(END_DE, 'YYYYMMDD')               as EVENT_END_DATE,
    CAST(NULL AS VARCHAR)                          as APPLY_CHANNEL,   -- ⚠️ A-10 대기
    {{ gold_meta('CRM') }}
from e

union all
-- unknown 멤버(SK=0): 팩트 EVENT_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', NULL, NULL, '(미매핑)', NULL, NULL, NULL,
    {{ gold_meta('CRM') }}
