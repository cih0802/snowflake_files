create or replace view GN_DW.GOLD.WIDE_AD_BROADCAST
    (
      AD_PERF_DK COMMENT $$광고성과 행 식별자(grain) — 코어 WIDE_AD_PERFORMANCE 조인키$$,
      AD_SOURCE_TYPE COMMENT $$광고 원천유형 — 본 뷰는 방송 2종(**VIDEO·REBROADCAST**)만 담는다. 🔴두 원천은 보고 항목이 다르다: 전용 컬럼이 서로 배타적이며 NULL 은 결측이 아니라 개념 부재다. 디지털은 본 뷰에 없다 — 전 유형 집계는 코어 `WIDE_AD_PERFORMANCE`.$$,
      PERF_DATE_SK COMMENT $$광고 실적일 YYYYMMDD$$,
      AD_COST COMMENT $$[코어] 광고비(원) — VIDEO=실집행·REBRDC=편성비용$$,
      INBOUND_CALL COMMENT $$[코어] 인입콜수 🔴[O51-F 실측] 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🔴채널·시간대별 인입콜 비교 시 미보고 행이 0 이 아니라 NULL 이므로 평균이 왜곡될 수 있다. 실측 규모는 이슈원장 §O51-F.$$,
      TIME_BAND COMMENT $$시간대$$,
      CM_POSITION COMMENT $$CM위치 (VIDEO 전용)$$,
      RT_TYPE COMMENT $$RT(재방송)유형 (REBRDC 전용)$$,
      AD_START_TIME COMMENT $$광고시작시간 (VIDEO 전용)$$,
      AD_END_TIME COMMENT $$광고종료시간 (VIDEO 전용) 🔴[O51-F 실측] 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. ⚠️시작시간은 더 많이 채워져 있어 **시작·종료를 함께 요구하면 표본이 줄어든다**. 실측 규모는 이슈원장 §O51-F.$$,
      BROADCAST_DATE COMMENT $$송출일 — 실적일(PERF_DATE_SK)과 다를 수 있음$$,
      PROGRAM_NM COMMENT $$프로그램/편성명$$,
      CHANNEL_COMPANY COMMENT $$채널사$$,
      CHANNEL_COMPANY_TYPE COMMENT $$채널사유형 (VIDEO 전용)$$,
      SPOT_TYPE COMMENT $$SPOT유형 (VIDEO 전용) 🔴[O51-F 실측] 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.$$,
      DURATION_SEC COMMENT $$광고 초수 (VIDEO 전용)$$,
      DAY_DIV COMMENT $$요일구분 평일/주말 (VIDEO 전용)$$,
      PRG_START_TIME COMMENT $$프로그램 시작시간 (VIDEO 전용)$$,
      CTV_DIV COMMENT $$CTV구분 (VIDEO 전용) 🔴[O51-F 실측] 채움이 **VIDEO 안에서도 소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.$$,
      BRDC_DIV COMMENT $$방송구분 (REBRDC 전용) 🔴[O51-F 실측] 채움이 **REBROADCAST 안에서도 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.$$,
      AD_CNT COMMENT $$광고횟수$$,
      CONV_CALL_CNT COMMENT $$전환콜 (VIDEO 전용) — 인입콜과 별개 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴🔴종전 문서가 *「VIDEO 는 개발실적 대신 전환콜을 보고한다」* 고 적었으나 **그 컬럼도 원천에서 전건 비어 있다** — 즉 VIDEO 구간은 개발도 전환콜도 측정할 수 없다(AD-5 보강). REBROADCAST 원천에는 컬럼 자체가 없다. 실측 규모는 이슈원장 §O51-F.$$,
      DVLP_MEMBER_CNT COMMENT $$개발회원수 (REBRDC 전용) — ⚠️GA 전환이 아님(O16 분리) ⚠️**REBROADCAST 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다. ⚠️GA 전환이 아니다(O16 분리) — 재방송 개발실적이다.$$,
      DVLP_CNT COMMENT $$개발건수 (REBRDC 전용) — ⚠️GA 전환이 아님(O16 분리) ⚠️**REBROADCAST 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다. ⚠️GA 전환이 아니다(O16 분리) — 재방송 개발실적이다.$$,
      AD_VIEW_RT_SRC COMMENT $$광고시청률(대행사 산정) — 비가산 N, 재합산 금지. ⚠️**VIDEO 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다.$$,
      CPC_SRC COMMENT $$CPC(대행사 산정) — 비가산 N, 재합산 금지. ⚠️**VIDEO 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다.$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별$$,
      PERF_FULL_DATE COMMENT $$DIM_DATE.FULL_DATE — 실적일 일자$$,
      PERF_YEAR COMMENT $$DIM_DATE.YEAR — 실적일 년$$,
      PERF_MONTH COMMENT $$DIM_DATE.MONTH — 실적일 월$$,
      PERF_QUARTER COMMENT $$DIM_DATE.QUARTER — 실적일 분기$$,
      PERF_IS_HOLIDAY COMMENT $$DIM_DATE.IS_HOLIDAY — 실적일 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다(O45) — 광고↔개발 결합은 그 grain 에서 한다. 실측 규모는 이슈원장 §O51-F.$$,
      AD_MEDIA_NAME COMMENT $$DIM_AD_CREATIVE.MEDIA_NAME — 매체명 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.$$,
      AD_CREATIVE COMMENT $$DIM_AD_CREATIVE.CREATIVE — 소재 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.$$
    )
    comment = $$방송광고 위성 팩트(FAD_B) 평탄화 — grain=AD_PERF_DK. 코어와 1:1 이라 코어 measure(AD_COST·INBOUND_CALL) 동반 노출 → 방송 분석을 단일 뷰로 완결한다. ⚠️코어 뷰(WIDE_AD_PERFORMANCE)와 함께 합산하면 방송 행이 이중계상된다 — 전 유형 집계는 코어 뷰만. ⚠️컬럼 NULL 은 두 방송 원천(VIDEO·REBROADCAST) 중 한쪽 전용 속성이며 결측이 아니다. DVLP_MEMBER_CNT·DVLP_CNT = 재방송 개발실적(O16 분리 · GA 전환 아님). _SRC 는 대행사 산정 비가산(N). 🔴[O51-F] 매체·소재축과 캠페인명은 사용 불가 상태다(FK 미배선 = P52·O38-C·Q10) · 휴일축 미주입(HOL-1). 🔴행수는 하드코딩하지 않는다 — 재적재마다 변한다(규칙 7).$$
    as (
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
    );