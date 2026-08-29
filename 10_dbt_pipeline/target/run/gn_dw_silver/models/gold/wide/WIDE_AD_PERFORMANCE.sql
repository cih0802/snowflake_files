create or replace view GN_DW.GOLD.WIDE_AD_PERFORMANCE
    (
      AD_PERF_DK COMMENT $$광고성과 행 식별자(grain) — 위성 뷰 조인키$$,
      PERF_DATE_SK COMMENT $$광고 실적일 YYYYMMDD$$,
      AD_COST COMMENT $$광고비(원)$$,
      IMPRESSIONS COMMENT $$노출수(디지털 전용)$$,
      CLICKS COMMENT $$클릭수(디지털 전용)$$,
      INBOUND_CALL COMMENT $$인입콜수$$,
      GA_CONV_MEMBERS COMMENT $$GA전환수(명) — 디지털 전용(O16 교정: 재방송 개발실적 제외)$$,
      GA_CONV_CNT COMMENT $$GA전환수(건/VU) — 디지털 전용(O16 교정: 재방송 개발실적 제외)$$,
      DAY_OF_WEEK COMMENT $$요일(팩트 degen)$$,
      WEEK_OF_YEAR COMMENT $$주차(팩트 degen)$$,
      AD_SOURCE_TYPE COMMENT $$광고 원천유형 DIGITAL/VIDEO/REBROADCAST — 출처 명시축(팩트 degen, DEC-8)$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별 (GA4/AGENCY/GADS)$$,
      PERF_FULL_DATE COMMENT $$DIM_DATE.FULL_DATE — 실적일 일자$$,
      PERF_YEAR COMMENT $$DIM_DATE.YEAR — 실적일 년$$,
      PERF_MONTH COMMENT $$DIM_DATE.MONTH — 실적일 월$$,
      PERF_QUARTER COMMENT $$DIM_DATE.QUARTER — 실적일 분기$$,
      PERF_IS_HOLIDAY COMMENT $$DIM_DATE.IS_HOLIDAY — 실적일 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_BK COMMENT $$DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_BRAND COMMENT $$DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_PARENT COMMENT $$DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_PROMO_METHOD COMMENT $$DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_TYPE COMMENT $$DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      AD_CREATIVE_BK COMMENT $$DIM_AD_CREATIVE.AD_CREATIVE_BK — 광고소재 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.$$,
      AD_MEDIA_NAME COMMENT $$DIM_AD_CREATIVE.MEDIA_NAME — 매체명 (#11) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.$$,
      AD_PLATFORM COMMENT $$DIM_AD_CREATIVE.PLATFORM — 플랫폼 (#12) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      AD_PLATFORM_TYPE COMMENT $$DIM_AD_CREATIVE.PLATFORM_TYPE — 플랫폼/매체유형 (#13) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      AD_CREATIVE COMMENT $$DIM_AD_CREATIVE.CREATIVE — 소재 (#20) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.$$,
      AD_CREATIVE_TYPE COMMENT $$DIM_AD_CREATIVE.AD_TYPE — 소재 광고유형 (⚠️AD_SOURCE_TYPE 과 다른 개념) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.$$,
      AD_TARGET_GROUP COMMENT $$DIM_AD_CREATIVE.TARGET_GROUP — 타겟그룹 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      DEVICE_TYPE COMMENT $$DIM_DEVICE.DEVICE_TYPE — PC / M / (해당없음)방송 / (unknown)$$,
      DEVICE_SCOPE_DESC COMMENT $$DIM_DEVICE.DEVICE_SCOPE_DESC — 기기축 적용범위 자기설명(DEC-10)$$
    )
    comment = $$광고 성과 **코어** 팩트(FAD) 평탄화 — DATE·CAMPAIGN·AD_CREATIVE·DEVICE. grain=AD_PERF_DK. [2026-07-28 DEC-8] 방송 degen 5종은 위성 뷰로 이관했다 — 본 뷰는 3원천 공통 컬럼만 담는다. **전 유형 집계는 본 뷰만 사용**할 것(위성 뷰와 합산하면 이중계상). 🔴[O51-F 실측] `CAMPAIGN_SK`·`AD_CREATIVE_SK` 는 **0 스캐폴드**이며 그 귀결이 컸다 — 캠페인·매체·소재 속성이 전건 NULL 또는 전건 `'(미매핑)'` 센티넬이다(기지 **P52·O38-C** · 연결키는 **Q10**). 센티넬은 GROUP BY 가 단일 그룹을 반환해 **오답이 에러 없이 나온다.** 🟢대안 = 마케팅캠페인 축(O45). 🔴휴일축(`PERF_IS_HOLIDAY`)도 전건 FALSE 로 미주입이다(**HOL-1**). DEVICE_SK 는 실배선 완료(DEC-10). ⚠️AD_SOURCE_TYPE(원천 출처축) ≠ AD_CREATIVE_TYPE(소재 광고유형). 🔴행수는 하드코딩하지 않는다 — 종전 기재가 재적재로 stale 이 됐다(규칙 7).$$
    as (
      -- WIDE_AD_PERFORMANCE: 광고 성과 **코어** 팩트(FAD) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.7)
-- Co-authored with CoCo
-- ⚠️ [2026-07-28 순서9-I DEC-8] 코어에서 위성으로 이관된 방송 degen 5종
--    (TIME_BAND·CM_POSITION·RT_TYPE·AD_START_TIME·BROADCAST_DATE)을 본 뷰에서 **제거**했다.
--    본 뷰는 팩트와 1:1 대응 원칙을 지키며 **코어 컬럼만** 평탄화한다.
--    → 방송 고유속성은 `WIDE_AD_BROADCAST` · 디지털은 `WIDE_AD_DIGITAL` · 사례는 `WIDE_AD_BROADCAST_CASE`.
-- ⚠️ 명명 충돌 해소: `AD_SOURCE_TYPE`(코어 degen = 원천 출처축 DIGITAL/VIDEO/REBROADCAST)과
--    `AD_CREATIVE_TYPE`(DIM_AD_CREATIVE 소재 광고유형)은 **다른 개념**이다. 종전 두 컬럼이 모두
--    `AD_TYPE` 이라 혼동 소지가 있었으므로 내용에 맞게 분리 명명했다(소비자 부재 확인 후 적용).
-- ⚠️ CAMPAIGN_SK·AD_CREATIVE_SK 는 여전히 0 스캐폴드(Q10 이름매칭·소재 부분키 대기) → 관련 컬럼 NULL.
--    DEVICE_SK 는 DEC-10 으로 실배선 완료(방송행은 `(해당없음)` 멤버).
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).


select
    f.AD_PERF_DK,
    f.PERF_DATE_SK,
    f.AD_COST, f.IMPRESSIONS, f.CLICKS, f.INBOUND_CALL,
    f.GA_CONV_MEMBERS, f.GA_CONV_CNT,
    f.DAY_OF_WEEK, f.WEEK_OF_YEAR,
    f.AD_SOURCE_TYPE,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE           as PERF_FULL_DATE,
    d.YEAR                as PERF_YEAR,
    d.MONTH               as PERF_MONTH,
    d.QUARTER             as PERF_QUARTER,
    d.IS_HOLIDAY          as PERF_IS_HOLIDAY,
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     as CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    c.PROMO_METHOD        as CAMPAIGN_PROMO_METHOD,
    c.CAMPAIGN_TYPE       as CAMPAIGN_TYPE,
    ac.AD_CREATIVE_BK     as AD_CREATIVE_BK,
    ac.MEDIA_NAME         as AD_MEDIA_NAME,
    ac.PLATFORM           as AD_PLATFORM,
    ac.PLATFORM_TYPE      as AD_PLATFORM_TYPE,
    ac.CREATIVE           as AD_CREATIVE,
    ac.AD_TYPE            as AD_CREATIVE_TYPE,   -- 소재 광고유형 (≠ AD_SOURCE_TYPE)
    ac.TARGET_GROUP       as AD_TARGET_GROUP,
    dv.DEVICE_TYPE        as DEVICE_TYPE,
    dv.DEVICE_SCOPE_DESC  as DEVICE_SCOPE_DESC
from GN_DW.GOLD.FACT_AD_PERFORMANCE f
left join GN_DW.GOLD.DIM_DATE        d  on f.PERF_DATE_SK   = d.DATE_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c  on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_AD_CREATIVE ac on f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
left join GN_DW.GOLD.DIM_DEVICE      dv on f.DEVICE_SK      = dv.DEVICE_SK
    );