create or replace view GN_DW.GOLD.WIDE_AD_DIGITAL
    (
      AD_PERF_DK COMMENT $$광고성과 행 식별자(grain) — 코어 WIDE_AD_PERFORMANCE 조인키$$,
      AD_SOURCE_TYPE COMMENT $$광고 원천유형. 🔴본 뷰는 **DIGITAL 단일값**이다(위성이 원천유형으로 수직분할되어 있다) — GROUP BY 대상이 아니며, 유형 간 비교는 코어 `WIDE_AD_PERFORMANCE` 에서 한다.$$,
      PERF_DATE_SK COMMENT $$광고 실적일 YYYYMMDD$$,
      AD_COST COMMENT $$[코어] GA 광고비(원)$$,
      IMPRESSIONS COMMENT $$[코어] 노출수 — CTR 분모$$,
      CLICKS COMMENT $$[코어] 클릭수 — CTR 분자$$,
      GA_CONV_MEMBERS COMMENT $$[코어] GA전환수(명) — CVR 분자(O16 교정 후 디지털 전용)$$,
      GA_CONV_CNT COMMENT $$[코어] GA전환수(건/VU) — CPA 분모(O16 교정 후 디지털 전용) 🔴[O51-F 실측] 채움이 **부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🔴비율 metric 의 분모로 쓸 때는 분자 커버리지를 먼저 맞출 것 — 분모만 부분이면 조용히 과대계상된다(P18). 실측 규모는 이슈원장 §O51-F.$$,
      PAGE_TYPE COMMENT $$페이지유형 🔴[O51-F 실측] 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.$$,
      AD_GROUP_NM COMMENT $$광고그룹명 🔴[O51-F 실측] 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.$$,
      GROUP_DIV COMMENT $$그룹구분 🔴[O51-F 실측] 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.$$,
      CREATIVE_TYPE COMMENT $$소재유형(원천 표기) 🔴[O51-F 실측] 채움이 **부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.$$,
      AD_TYPE_NM COMMENT $$광고유형명(대행사 표기). [O51-F BRONZE 실측] 실적재 값 = **하단DA·DA·CPT·BSA·SA·CPM**. 🔴`AD_SOURCE_TYPE`(VIDEO/REBROADCAST/DIGITAL)과 **다른 개념**이다 — 이름이 비슷해 혼용되기 쉽다.$$,
      READ_CNT COMMENT $$읽음수 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.$$,
      MEDIA_POTENTIAL_CUST_CNT COMMENT $$매체 잠재고객수 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.MEDIA_PTNT_CUST_CNT`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-F.$$,
      CRM_DEV_CNT COMMENT $$CRM 개발건수$$,
      CTR_SRC COMMENT $$CTR(대행사 산정) — 비가산 N. DW 재계산=SUM(CLICKS)/SUM(IMPRESSIONS) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.$$,
      CVR_SRC COMMENT $$CVR(대행사 산정) — 비가산 N. DW 재계산=SUM(GA_CONV_MEMBERS)/SUM(CLICKS) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.$$,
      CPC_SRC COMMENT $$CPC(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(CLICKS) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.$$,
      CPM_SRC COMMENT $$CPM(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(IMPRESSIONS)*1000 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.$$,
      CPA_SRC COMMENT $$CPA(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(GA_CONV_CNT) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.$$,
      DEV_UNIT_PRICE_SRC COMMENT $$개발단가(대행사 산정) — 비가산 N 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. ⚠️원천 포맷 변경으로 개발건수와 **상호배타**다(AD-3) — 개발단가는 두 컬럼이 기간을 보완하는 관계이며 교차검증 관계가 아니다. 실측 규모는 이슈원장 §O51-F.$$,
      VTR_SRC COMMENT $$VTR(대행사 산정) — 비가산 N, base 부재로 재계산 불가 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. base 가 원천에 없어 DW 재계산도 불가하다. 실측 규모는 이슈원장 §O51-F.$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별$$,
      PERF_FULL_DATE COMMENT $$DIM_DATE.FULL_DATE — 실적일 일자$$,
      PERF_YEAR COMMENT $$DIM_DATE.YEAR — 실적일 년$$,
      PERF_MONTH COMMENT $$DIM_DATE.MONTH — 실적일 월$$,
      PERF_QUARTER COMMENT $$DIM_DATE.QUARTER — 실적일 분기$$,
      PERF_IS_HOLIDAY COMMENT $$DIM_DATE.IS_HOLIDAY — 실적일 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다(O45) — 광고↔개발 결합은 그 grain 에서 한다. 실측 규모는 이슈원장 §O51-F.$$,
      AD_MEDIA_NAME COMMENT $$DIM_AD_CREATIVE.MEDIA_NAME — 매체명 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.$$,
      AD_CREATIVE COMMENT $$DIM_AD_CREATIVE.CREATIVE — 소재 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.$$,
      DEVICE_TYPE COMMENT $$DIM_DEVICE.DEVICE_TYPE — M / PC (디지털은 기기 실존)$$
    )
    comment = $$디지털광고 위성 팩트(FAD_D) 평탄화 — grain=AD_PERF_DK. 코어와 1:1 이라 코어 measure(AD_COST·IMPRESSIONS·CLICKS·GA_CONV_*) 동반 노출 → 비율 재계산 base 를 같은 뷰에서 확보한다. ⚠️코어 뷰와 함께 합산하면 디지털 행이 이중계상된다. _SRC 7종은 대행사 산정 **비가산(N)** — 집계는 base 재계산(예: CTR=SUM(CLICKS)/SUM(IMPRESSIONS))이고 _SRC 는 행 단위 대조용이다. DEVICE_TYPE 동반(디지털은 기기가 실존 · 실적재 PC·M). 🔴[O51-F] 매체·소재축과 캠페인명은 사용 불가 상태다(FK 미배선 = P52·O38-C·Q10) · 휴일축 미주입(HOL-1) · AD_SOURCE_TYPE 은 단일값이다. 🔴행수는 하드코딩하지 않는다(규칙 7).$$
    as (
      -- WIDE_AD_DIGITAL: 디지털광고 위성 팩트(FAD_D) 평탄화 소비뷰 — 순서9-I 신설(DEC-8)
-- Co-authored with CoCo
-- grain = AD_PERF_DK (FAD_D 와 1:1). 원천유형 DIGITAL 단독 지분이다.
-- 🔴 행수를 여기에 적지 않는다(규칙 7) — 종전 하드코딩이 재적재로 stale 이 됐다. 규모는 이슈원장 §O51-F.
--
-- ⚠️ 설계 의도: 분석가·SV·Agent 가 **이 뷰 하나로 디지털광고 분석을 끝낼 수 있게** 만든다.
--    위성은 코어와 1:1 이므로 코어 measure 를 함께 노출해도 fan-out 이 없다.
--    → "페이지유형별 CTR", "광고그룹별 전환수" 같은 질문에 조인 없이 답할 수 있다.
-- ⚠️ 중복 합산 금지: 코어 measure 는 `WIDE_AD_PERFORMANCE` 에도 존재한다. 두 뷰를 함께 합산하면
--    디지털 행이 이중 계상된다. **전체 광고 집계는 코어 뷰만** 사용할 것.
-- ⚠️ 기기축 동반: 디지털은 기기(M/PC)가 실존하므로 DEVICE_TYPE 을 노출한다(DEC-10 실배선).
-- ⚠️ **비율 지표 사용 원칙(DEC-9)**: `_SRC` 는 대행사가 계산해 넘긴 값으로 **비가산(N)**이다.
--    집계 시에는 반드시 base 로 재계산할 것 — 예: CTR = SUM(CLICKS)/SUM(IMPRESSIONS).
--    `_SRC` 는 대행사 산식과 DW 산식을 **대조**하는 용도이며, 행 단위 참조만 유효하다.
--    VTR_SRC 는 base 가 원천에 없어 재계산이 불가하다(대조 대상 아님).
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-10 O51-F] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.
--   🔄 종전 「DROP 예정」 결정 철회(2026-08-10): 이 뷰는 dbt 모델이라 물리 DROP 은 다음 build 가 되살리며,
--     DEC-8/DEC-10 이 위성 단독 완결을 설계 의도로 명시한다. 보존 + COMMENT 이관으로 확정했다.


select
    g.AD_PERF_DK,
    f.AD_SOURCE_TYPE,
    f.PERF_DATE_SK,
    -- [코어 measure] 위성과 1:1 이므로 동반 노출 안전. 비율 재계산의 base 이기도 하다.
    f.AD_COST, f.IMPRESSIONS, f.CLICKS,
    f.GA_CONV_MEMBERS, f.GA_CONV_CNT,
    -- [위성 고유속성]
    g.PAGE_TYPE, g.AD_GROUP_NM, g.GROUP_DIV, g.CREATIVE_TYPE, g.AD_TYPE_NM,
    g.READ_CNT, g.MEDIA_POTENTIAL_CUST_CNT, g.CRM_DEV_CNT,
    -- [대행사 산정 _SRC] 전량 비가산 N — 집계 금지, 대조용
    g.CTR_SRC, g.CVR_SRC, g.CPC_SRC, g.CPM_SRC, g.CPA_SRC,
    g.DEV_UNIT_PRICE_SRC, g.VTR_SRC,
    g.DW_SOURCE_SYSTEM,
    -- [차원 속성] 단독 사용 가능하도록 동반
    d.FULL_DATE           as PERF_FULL_DATE,
    d.YEAR                as PERF_YEAR,
    d.MONTH               as PERF_MONTH,
    d.QUARTER             as PERF_QUARTER,
    d.IS_HOLIDAY          as PERF_IS_HOLIDAY,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    ac.MEDIA_NAME         as AD_MEDIA_NAME,
    ac.CREATIVE           as AD_CREATIVE,
    dv.DEVICE_TYPE        as DEVICE_TYPE
from GN_DW.GOLD.FACT_AD_DIGITAL g
join      GN_DW.GOLD.FACT_AD_PERFORMANCE f  on g.AD_PERF_DK    = f.AD_PERF_DK
left join GN_DW.GOLD.DIM_DATE            d  on f.PERF_DATE_SK  = d.DATE_SK
left join GN_DW.GOLD.DIM_CAMPAIGN        c  on f.CAMPAIGN_SK   = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_AD_CREATIVE     ac on f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
left join GN_DW.GOLD.DIM_DEVICE          dv on f.DEVICE_SK     = dv.DEVICE_SK
    );