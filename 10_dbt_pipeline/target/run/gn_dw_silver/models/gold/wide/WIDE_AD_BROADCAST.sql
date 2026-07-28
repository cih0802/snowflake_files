
  create or replace   view GN_DW.GOLD.WIDE_AD_BROADCAST
  
   as (
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
from GN_DW.GOLD.FACT_AD_BROADCAST b
join      GN_DW.GOLD.FACT_AD_PERFORMANCE f  on b.AD_PERF_DK    = f.AD_PERF_DK
left join GN_DW.GOLD.DIM_DATE            d  on f.PERF_DATE_SK  = d.DATE_SK
left join GN_DW.GOLD.DIM_CAMPAIGN        c  on f.CAMPAIGN_SK   = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_AD_CREATIVE     ac on f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
  );

