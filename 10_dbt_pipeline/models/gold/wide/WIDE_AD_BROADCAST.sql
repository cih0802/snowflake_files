-- WIDE_AD_BROADCAST: 방송광고 위성 팩트(FAD_B) 평탄화 소비뷰 — 순서9-I 신설(DEC-8)
-- Co-authored with CoCo
-- grain = AD_PERF_DK (FAD_B 와 1:1). 실측 37,886행 (VIDEO 35,822 + REBRDC 2,064).
--
-- ⚠️ 설계 의도: 분석가·SV·Agent 가 **이 뷰 하나로 방송광고 분석을 끝낼 수 있게** 만든다.
--    위성은 코어와 1:1 이므로 코어 measure(AD_COST·INBOUND_CALL 등)를 함께 노출해도 fan-out 이 없다.
--    → "채널사별 방송 광고비", "시간대별 인입콜" 같은 질문에 조인 없이 답할 수 있다.
-- ⚠️ 중복 합산 금지: 코어 measure 는 `WIDE_AD_PERFORMANCE` 에도 존재한다. 두 뷰를 UNION 하거나
--    함께 합산하면 방송 행이 이중 계상된다. **전체 광고 집계는 코어 뷰만** 사용할 것.
-- ⚠️ 디지털 광고는 본 뷰에 없다(방송 전용 위성). 전 유형 집계는 `WIDE_AD_PERFORMANCE`.
-- ⚠️ 컬럼 NULL 은 '두 방송 원천 중 한쪽 전용 속성'이며 결측이 아니다.
--    VIDEO 전용: CM_POSITION·AD_START_TIME·AD_END_TIME·CHANNEL_COMPANY_TYPE·SPOT_TYPE·
--                DURATION_SEC·DAY_DIV·PRG_START_TIME·CTV_DIV·CONV_CALL_CNT·AD_VIEW_RT_SRC·CPC_SRC
--    REBRDC 전용: RT_TYPE·BRDC_DIV·DVLP_MEMBER_CNT·DVLP_CNT
-- ⚠️ `_SRC` = 대행사 산정 파생값(DEC-9) — **비가산(N)**. SUM/AVG 재합산 금지.
-- ⚠️ DVLP_* = 재방송 개발실적. 종전 코어 GA_CONV_* 로 혼입돼 있던 값(O16). GA 전환과 **다른 개념**.
{{ config(
    materialized='view',
    post_hook=[
      "COMMENT ON VIEW {{ this }} IS '방송광고 위성 팩트 평탄화 (FAD_B × DATE·CAMPAIGN·AD_CREATIVE, grain=AD_PERF_DK, 37,886행). 코어 measure 동반 노출(1:1이라 fan-out 없음) — 단 WIDE_AD_PERFORMANCE 와 합산 시 이중계상 주의. 방송 전용(디지털 제외).'",
      "ALTER VIEW {{ this }} ALTER COLUMN AD_PERF_DK COMMENT '광고성과 행 식별자(grain) — 코어 WIDE_AD_PERFORMANCE 조인키', COLUMN AD_SOURCE_TYPE COMMENT '광고 원천유형 VIDEO/REBROADCAST (본 뷰는 방송 2종만)', COLUMN PERF_DATE_SK COMMENT '광고 실적일 YYYYMMDD', COLUMN AD_COST COMMENT '[코어] 광고비(원) — VIDEO=실집행·REBRDC=편성비용', COLUMN INBOUND_CALL COMMENT '[코어] 인입콜수', COLUMN TIME_BAND COMMENT '시간대', COLUMN CM_POSITION COMMENT 'CM위치 (VIDEO 전용)', COLUMN RT_TYPE COMMENT 'RT(재방송)유형 (REBRDC 전용)', COLUMN AD_START_TIME COMMENT '광고시작시간 (VIDEO 전용)', COLUMN AD_END_TIME COMMENT '광고종료시간 (VIDEO 전용)', COLUMN BROADCAST_DATE COMMENT '송출일 — 실적일(PERF_DATE_SK)과 다를 수 있음', COLUMN PROGRAM_NM COMMENT '프로그램/편성명', COLUMN CHANNEL_COMPANY COMMENT '채널사', COLUMN CHANNEL_COMPANY_TYPE COMMENT '채널사유형 (VIDEO 전용)', COLUMN SPOT_TYPE COMMENT 'SPOT유형 (VIDEO 전용)', COLUMN DURATION_SEC COMMENT '광고 초수 (VIDEO 전용)', COLUMN DAY_DIV COMMENT '요일구분 평일/주말 (VIDEO 전용)', COLUMN PRG_START_TIME COMMENT '프로그램 시작시간 (VIDEO 전용)', COLUMN CTV_DIV COMMENT 'CTV구분 (VIDEO 전용)', COLUMN BRDC_DIV COMMENT '방송구분 (REBRDC 전용)', COLUMN AD_CNT COMMENT '광고횟수', COLUMN CONV_CALL_CNT COMMENT '전환콜 (VIDEO 전용) — 인입콜과 별개', COLUMN DVLP_MEMBER_CNT COMMENT '개발회원수 (REBRDC 전용) — ⚠️GA 전환이 아님(O16 분리)', COLUMN DVLP_CNT COMMENT '개발건수 (REBRDC 전용) — ⚠️GA 전환이 아님(O16 분리)', COLUMN AD_VIEW_RT_SRC COMMENT '광고시청률(대행사 산정) — 비가산 N, 재합산 금지', COLUMN CPC_SRC COMMENT 'CPC(대행사 산정) — 비가산 N, 재합산 금지', COLUMN DW_SOURCE_SYSTEM COMMENT '원천 시스템 식별', COLUMN PERF_FULL_DATE COMMENT 'DIM_DATE.FULL_DATE — 실적일 일자', COLUMN PERF_YEAR COMMENT 'DIM_DATE.YEAR — 실적일 년', COLUMN PERF_MONTH COMMENT 'DIM_DATE.MONTH — 실적일 월', COLUMN PERF_QUARTER COMMENT 'DIM_DATE.QUARTER — 실적일 분기', COLUMN PERF_IS_HOLIDAY COMMENT 'DIM_DATE.IS_HOLIDAY — 실적일 휴일여부', COLUMN CAMPAIGN_NAME COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명', COLUMN AD_MEDIA_NAME COMMENT 'DIM_AD_CREATIVE.MEDIA_NAME — 매체명', COLUMN AD_CREATIVE COMMENT 'DIM_AD_CREATIVE.CREATIVE — 소재'"
    ]
) }}

select
    b.AD_PERF_DK,
    f.AD_SOURCE_TYPE,
    f.PERF_DATE_SK,
    -- [코어 measure] 위성과 1:1 이므로 동반 노출 안전 (⚠️코어 뷰와 합산 시 이중계상)
    f.AD_COST,
    f.INBOUND_CALL,
    -- [위성 고유속성]
    b.TIME_BAND, b.CM_POSITION, b.RT_TYPE,
    b.AD_START_TIME, b.AD_END_TIME, b.BROADCAST_DATE,
    b.PROGRAM_NM, b.CHANNEL_COMPANY, b.CHANNEL_COMPANY_TYPE,
    b.SPOT_TYPE, b.DURATION_SEC, b.DAY_DIV, b.PRG_START_TIME,
    b.CTV_DIV, b.BRDC_DIV,
    b.AD_CNT, b.CONV_CALL_CNT,
    b.DVLP_MEMBER_CNT, b.DVLP_CNT,
    b.AD_VIEW_RT_SRC, b.CPC_SRC,
    b.DW_SOURCE_SYSTEM,
    -- [차원 속성] 단독 사용 가능하도록 동반
    d.FULL_DATE           as PERF_FULL_DATE,
    d.YEAR                as PERF_YEAR,
    d.MONTH               as PERF_MONTH,
    d.QUARTER             as PERF_QUARTER,
    d.IS_HOLIDAY          as PERF_IS_HOLIDAY,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    ac.MEDIA_NAME         as AD_MEDIA_NAME,
    ac.CREATIVE           as AD_CREATIVE
from {{ ref('FACT_AD_BROADCAST') }} b
join      {{ ref('FACT_AD_PERFORMANCE') }} f  on b.AD_PERF_DK    = f.AD_PERF_DK
left join {{ ref('DIM_DATE') }}            d  on f.PERF_DATE_SK  = d.DATE_SK
left join {{ ref('DIM_CAMPAIGN') }}        c  on f.CAMPAIGN_SK   = c.CAMPAIGN_SK
left join {{ ref('DIM_AD_CREATIVE') }}     ac on f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
