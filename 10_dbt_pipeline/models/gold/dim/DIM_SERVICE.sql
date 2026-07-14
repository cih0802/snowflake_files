-- DIM_SERVICE: 발송 서비스 차원 스캐폴드 (CRM_SEND_REQUEST DISTINCT, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ SEND_TYPE_L/M/S(대/중/소) 코드체계 검수 대기(설계 §8). 현재 CHANNEL/SUBTYPE만.
{{ config(
    materialized='incremental',
    unique_key='SERVICE_SK',
    tags=['gold_pending']
) }}

with src as (
    select distinct SEND_CHANNEL, SNDNG_TY_CD
    from {{ ref('CRM_SEND_REQUEST') }}
)

select
    {{ gold_sk(['SEND_CHANNEL','SNDNG_TY_CD']) }} as SERVICE_SK,
    CAST(NULL AS VARCHAR)                          as SEND_TYPE_L,   -- ⚠️ 대분류 미해소
    CAST(NULL AS VARCHAR)                          as SEND_TYPE_M,   -- ⚠️ 중분류 미해소
    CAST(NULL AS VARCHAR)                          as SEND_TYPE_S,   -- ⚠️ 소분류 미해소
    SNDNG_TY_CD                                   as SUBTYPE,
    SEND_CHANNEL                                  as CHANNEL,
    {{ gold_meta('CRM') }}
from src

union all
-- unknown 멤버(SK=0): 팩트 SERVICE_SK=0(미매핑) 조인 유실 방지
select 0, NULL, NULL, NULL, '(미매핑)', '(미매핑)',
    {{ gold_meta('CRM') }}
