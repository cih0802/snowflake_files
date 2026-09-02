-- WIDE_AD_BROADCAST: 방송광고 위성 팩트(FAD_B) 평탄화 소비뷰 — 순서9-I 신설(DEC-8)
-- Co-authored with CoCo
-- grain = AD_PERF_DK (FAD_B 와 1:1). 원천유형 VIDEO·REBROADCAST 2종의 완전 수직분할 지분이다.
-- 🔴 행수를 여기에 적지 않는다(규칙 7) — 종전 하드코딩이 재적재로 stale 이 됐고 그 불일치가
--   「원인 미규명」으로 방치됐다. 원인은 재적재였다(O51-F 실측). 규모는 이슈원장 §O51-F.
--
-- ⚠️ 설계 의도: 분석가·SV·Agent 가 **이 뷰 하나로 방송광고 분석을 끝낼 수 있게** 만든다.
--    위성은 코어와 1:1 이므로 코어 measure(AD_COST·INBOUND_CALL 등)를 함께 노출해도 fan-out 이 없다.
--    → "채널사별 방송 광고비", "시간대별 인입콜" 같은 질문에 조인 없이 답할 수 있다.
-- ⚠️ 중복 합산 금지: 코어 measure 는 `WIDE_AD_PERFORMANCE` 에도 존재한다. 두 뷰를 UNION 하거나
--    함께 합산하면 방송 행이 이중 계상된다. **전체 광고 집계는 코어 뷰만** 사용할 것.
-- ⚠️ 디지털 광고는 본 뷰에 없다(방송 전용 위성). 전 유형 집계는 `WIDE_AD_PERFORMANCE`.
-- ⚠️ 컬럼 NULL 은 '두 방송 원천 중 한쪽 전용 속성'이며 결측이 아니다.
--    VIDEO 전용: CM_POSITION·AD_START_TIME·AD_END_TIME·CHANNEL_COMPANY_TYPE·SPOT_TYPE·
--                DURATION_SEC·DAY_DIV·PRG_START_TIME·CTV_DIV·AD_VIEW_RT_SRC·CPC_SRC
--    🔴 [O51-F 실측] CONV_CALL_CNT 는 VIDEO 전용 컬럼이 맞지만 **원천에서 전건 비어 있다** —
--      종전 「VIDEO 는 개발 대신 전환콜을 보고한다」는 기술은 컬럼 존재 기준으로만 참이다(AD-5 보강).
--    REBRDC 전용: RT_TYPE·BRDC_DIV·DVLP_MEMBER_CNT·DVLP_CNT
-- ⚠️ `_SRC` = 대행사 산정 파생값(DEC-9) — **비가산(N)**. SUM/AVG 재합산 금지.
-- ⚠️ DVLP_* = 재방송 개발실적. 종전 코어 GA_CONV_* 로 혼입돼 있던 값(O16). GA 전환과 **다른 개념**.
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-10 O51-F] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.
--   🔄 종전 「DROP 예정」 결정 철회(2026-08-10): 이 뷰는 dbt 모델이라 물리 DROP 은 다음 build 가 되살리며,
--     DEC-8/DEC-10 이 위성 단독 완결을 설계 의도로 명시한다. 보존 + COMMENT 이관으로 확정했다.


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