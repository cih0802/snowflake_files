-- DIM_AD_CREATIVE: 광고소재/매체 차원 (SILVER.AGENCY_AD_CREATIVE 3소스 UNION → GOLD 소재차원), 순서9-C 신설.
-- Co-authored with CoCo
-- 매핑 가정(순서9-C 데이터 실측): PLATFORM=SOURCE_SYSTEM(DIGITAL/VIDEO/REBROADCAST 매체구분) · AD_TYPE=소재유형(CREATIVE_TYPE_NM)
--   · CM_POSITION=CM_AREA_NM · MEDIA_NAME=MEDIA_CHANNEL_NM · CREATIVE=CREATIVE_NM.
--   원천 부재 → NULL: PLATFORM_TYPE·RT_TYPE·TARGET_GROUP (AGENCY 원천 미보유. 입고/현업 확인 시 채움).
-- 🔴 [O29 2026-08-04 주석 회수] `DURATION_SEC` 를 위 "원천 부재" 목록에 넣은 것은 **거짓이었다** —
--   원천은 실재한다: SILVER `AGENCY_AD_CREATIVE.AD_SEC_NM` VIDEO 1,217/1,279=95.2% ·
--   BRONZE `VIDEO_AD_CMPGN_DTLS.AD_SEC` 33,890/36,416=93.1%. (P14 위반 사례)
--   🔴 그러나 **채움이 정답이 아니다** — 같은 축이 `FACT_AD_BROADCAST.DURATION_SEC` 에 이미
--   배선돼 있다(§18-D ① 같은 역할 컬럼 우선). 판정 = **중복축 DROP 또는 소재차원 정본 통합**이며
--   사용자 결정 대기다. 그때까지 `CAST(NULL)` 을 유지한다(임의 채움은 중복축을 고착시킨다).
--   DW_SOURCE_SYSTEM='AGENCY' 상수(A-2/Q9: 행단위 대행사/GoogleAds 구분 불요 — GoogleAds 는 GA4 트랙).


with s as (
    select * from GN_DW.SILVER.AGENCY_AD_CREATIVE
)

select
    ABS(HASH(COALESCE(CAST(CREATIVE_DK AS VARCHAR), '∅')))    as AD_CREATIVE_SK,
    CREATIVE_DK                       as AD_CREATIVE_BK,
    MEDIA_CHANNEL_NM                  as MEDIA_NAME,
    SOURCE_SYSTEM                     as PLATFORM,        -- 매체구분(DIGITAL/VIDEO/REBROADCAST)
    CAST(NULL AS VARCHAR)             as PLATFORM_TYPE,   -- 원천 부재
    CREATIVE_NM                       as CREATIVE,
    CM_AREA_NM                        as CM_POSITION,
    CAST(NULL AS NUMBER(9,0))         as DURATION_SEC,    -- 🔴 O29 중복축(헤더 참조). "원천 부재" 아님 — 결정 대기로 NULL 유지
    CAST(NULL AS VARCHAR)             as RT_TYPE,         -- 원천 부재
    CREATIVE_TYPE_NM                  as AD_TYPE,         -- 소재/광고유형
    CAST(NULL AS VARCHAR)             as TARGET_GROUP,    -- 원천 부재
    'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '5ef82815-e89f-4a45-805d-207f49bbc068'                    AS DW_BATCH_ID
from s

union all
-- unknown 멤버(SK=0): FACT_AD_PERFORMANCE.AD_CREATIVE_SK 미매핑 조인 유실 방지 센티넬
select 0, '(미매핑)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '5ef82815-e89f-4a45-805d-207f49bbc068'                    AS DW_BATCH_ID