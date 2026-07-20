-- FACT_AD_PERFORMANCE: 광고성과 팩트 스캐폴드 (SILVER.AGENCY_AD_PERFORMANCE), 순서9-C 신설.
-- Co-authored with CoCo
-- ⚠️ 스캐폴드: measure·PERF_DATE_SK·요일/주차 파생만 실적재. 차원 FK 는 게이트 미해소로 0(Unknown) 라우팅:
--   · CAMPAIGN_SK=0: 캠페인 이름매칭(Q10 연결키·DIM_CAMPAIGN 키 확정) 대기. 이름컬럼 존재 → 후속 매칭 가능.
--   · AD_CREATIVE_SK=0: DIM_AD_CREATIVE 키(MD5[SOURCE|MEDIA|CREATIVE|TYPE|CM_AREA|AD_SEC])가 성과테이블에 미보유(TYPE/CM_AREA/AD_SEC 부재) → 정합 조인 불가. 부분키 매칭 설계 대기.
--   · DEVICE_SK=0: AGENCY device 도메인 ≠ GA4 기반 DIM_DEVICE → 별도 매핑 필요.
--   완성 조건: Q10(캠페인)·소재 부분키·device 매핑 설계 (문서50 §GOLD 완성 진행 요건).


with p as (
    select * from GN_DW.SILVER.AGENCY_AD_PERFORMANCE
)

select
    COALESCE(CASE WHEN AD_DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(AD_DATE, 'YYYYMMDD')) END, 0)  as PERF_DATE_SK,
    0                            as CAMPAIGN_SK,      -- Q10 이름매칭 대기
    0                            as AD_CREATIVE_SK,   -- 소재 부분키 매칭 대기
    0                            as DEVICE_SK,        -- device 매핑 대기
    AD_COST                      as AD_COST,
    IMPRESSION_CNT               as IMPRESSIONS,
    CLICK_CNT                    as CLICKS,
    INBOUND_CALL_CNT             as INBOUND_CALL,
    CONV_MEMBER_CNT              as GA_CONV_MEMBERS,
    CONV_UNIT_CNT                as GA_CONV_CNT,
    DAYNAME(AD_DATE)             as DAY_OF_WEEK,       -- degen(AD_DATE 파생)
    WEEKOFYEAR(AD_DATE)          as WEEK_OF_YEAR,      -- degen(AD_DATE 파생)
    CAST(NULL AS VARCHAR)        as TIME_BAND,         -- 원천 부재
    CAST(NULL AS VARCHAR)        as CM_POSITION,       -- 원천 부재(성과테이블)
    CAST(NULL AS VARCHAR)        as RT_TYPE,           -- 원천 부재
    CAST(NULL AS VARCHAR)        as AD_START_TIME,     -- 원천 부재
    CAST(NULL AS DATE)           as BROADCAST_DATE,    -- 송출일 별도구분 미해소
    'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '50eaa2d8-6f32-46e5-ad87-91e23c3b74a4'                    AS DW_BATCH_ID
from p