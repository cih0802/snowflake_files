-- DIM_AD_CREATIVE: 광고소재/매체 차원 (SILVER.AGENCY_AD_CREATIVE 3소스 UNION → GOLD 소재차원), 순서9-C 신설.
-- Co-authored with CoCo
-- 매핑 가정(순서9-C 데이터 실측): PLATFORM=SOURCE_SYSTEM(DIGITAL/VIDEO/REBROADCAST 매체구분) · AD_TYPE=소재유형(CREATIVE_TYPE_NM)
--   · CM_POSITION=CM_AREA_NM · MEDIA_NAME=MEDIA_CHANNEL_NM · CREATIVE=CREATIVE_NM.
--   원천 부재 → NULL: PLATFORM_TYPE·DURATION_SEC(초수)·RT_TYPE·TARGET_GROUP (AGENCY 원천 미보유. 입고/현업 확인 시 채움).
--   DW_SOURCE_SYSTEM='AGENCY' 상수(A-2/Q9: 행단위 대행사/GoogleAds 구분 불요 — GoogleAds 는 GA4 트랙).
{{ config(
    materialized='incremental',
    unique_key='AD_CREATIVE_SK',
    tags=['gold_ready']
) }}

with s as (
    select * from {{ ref('AGENCY_AD_CREATIVE') }}
)

select
    {{ gold_sk(['CREATIVE_DK']) }}    as AD_CREATIVE_SK,
    CREATIVE_DK                       as AD_CREATIVE_BK,
    MEDIA_CHANNEL_NM                  as MEDIA_NAME,
    SOURCE_SYSTEM                     as PLATFORM,        -- 매체구분(DIGITAL/VIDEO/REBROADCAST)
    CAST(NULL AS VARCHAR)             as PLATFORM_TYPE,   -- 원천 부재
    CREATIVE_NM                       as CREATIVE,
    CM_AREA_NM                        as CM_POSITION,
    CAST(NULL AS NUMBER(9,0))         as DURATION_SEC,    -- 원천 부재(초수)
    CAST(NULL AS VARCHAR)             as RT_TYPE,         -- 원천 부재
    CREATIVE_TYPE_NM                  as AD_TYPE,         -- 소재/광고유형
    CAST(NULL AS VARCHAR)             as TARGET_GROUP,    -- 원천 부재
    {{ gold_meta('AGENCY') }}
from s

union all
-- unknown 멤버(SK=0): FACT_AD_PERFORMANCE.AD_CREATIVE_SK 미매핑 조인 유실 방지 센티넬
select 0, '(미매핑)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    {{ gold_meta('AGENCY') }}
