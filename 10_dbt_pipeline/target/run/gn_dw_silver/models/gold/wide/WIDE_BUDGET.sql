create or replace view GN_DW.GOLD.WIDE_BUDGET
    (
      MONTH_KEY COMMENT $$예산월 YYYYMM$$,
      CAL_YEAR COMMENT $$FLOOR(MONTH_KEY/100) — 연도$$,
      CAL_MONTH COMMENT $$MOD(MONTH_KEY,100) — 월$$,
      PLAN_BUDGET_MONTH COMMENT $$편성예산(월, 원)$$,
      PLAN_BUDGET_YEAR COMMENT $$편성예산(연, 원) 🔴🔴**[2026-08-20 O96 · DEC42] 폐기 슬롯 — 의도적 영구 NULL 이다.** 🔴 종전의 「원천 부재 · 대행사 미보고 · 외부 원천 미입고(E-1/E-4 하드블로커)」 주장은 **철회한다 — 거짓이었다**(원문 인용은 이슈원장 문서30 §7-A 에 보존). 원천 `BDGT_ACMSLT_LEDGER.YEAR_BDGT_TOT_AMT` 는 실재하며 O93 에서 적재됐다 (적재 규모 실측은 이슈원장 문서30 §7-A · `R2-6` 수치 분리). 🟢 **연 편성예산은 `FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR`(연 grain)를 쓴다.** 🔴 이 컬럼(월 grain)에 연값을 채우지 않는 이유 = **grain 혼입**이다 — 연값을 12개월에 복제하면 `SUM` 이 12배로 부풀고 그 오류는 에러 없이 조용히 나온다. ⚠️ 여전히 필터 조건으로 쓰면 전건이 탈락한다(값이 없는 것은 정상이다).$$,
      EXEC_BUDGET_ERP COMMENT $$집행예산(ERP 월, 원)$$,
      EXEC_BUDGET_EST COMMENT $$집행예산(추정, 원) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`ERP 집행 추정 원천`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴외부 원천 미입고(E-1/E-4 하드블로커). 실측 규모는 이슈원장 §O51-F.$$,
      FUNDRAISING_COST COMMENT $$모금성비용(원) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`ERP 모금성비용 원천`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴외부 원천 미입고(**E-1** 하드블로커) — 모금성비용은 원천 확정 대기다. 실측 규모는 이슈원장 §O51-F.$$,
      AD_COST COMMENT $$광고비(원) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`ERP 예산 원장의 광고비 컬럼`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴예산 원장에는 광고비 항목이 없다(**E-4**) — 광고비는 대행사 원천(`WIDE_AD_PERFORMANCE`)에서 가져오며 **예산과 같은 표에 합산하지 말 것**(원천이 다르다 · 순서9-K 표 분리 근거). 실측 규모는 이슈원장 §O51-F.$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별$$,
      ORG_CORP COMMENT $$DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.$$,
      ORG_DIVISION COMMENT $$DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.$$,
      ORG_DEPARTMENT COMMENT $$DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34). 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.ORG_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🔴🔴예산 원장은 **부서별 분해가 현재 불가능**하다 — 「부서별 예산·집행」 요구에 총계 1행이 돌아온다. 실측 규모는 이슈원장 §O51-F.$$,
      ORG_TEAM COMMENT $$DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.$$,
      BUDGET_ITEM_NAME COMMENT $$DIM_BUDGET_ITEM.BUDGET_ITEM_NAME — 세세목명$$,
      BUDGET_CATEGORY COMMENT $$DIM_BUDGET_ITEM.BUDGET_CATEGORY — 예산구분$$,
      CAMPAIGN_BK COMMENT $$DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_BRAND COMMENT $$DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.$$,
      SPONSORSHIP_BK COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      SPONSORSHIP_NAME COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$
    )
    comment = $$예산 팩트(FBD) 평탄화 — ORG·BUDGET_ITEM·CAMPAIGN·SPONSORSHIP. 월 grain=MONTH_KEY. 🔴외부 원천 미입고로 전건 NULL: 집행 추정 · FUNDRAISING_COST(**E-1**) · AD_COST(**E-4**). 🔴🔴[2026-08-20 O96] **연간 편성은 이 목록에서 제외했다** — 원천 미입고가 아니라 **연 grain 을 `FACT_BUDGET_YEARLY` 로 분리**했기 때문이다(`PLAN_BUDGET_YEAR` = 폐기 슬롯·의도적 영구 NULL · DEC42). 연 편성예산을 물으면 `WIDE_BUDGET` 이 아니라 **`FACT_BUDGET_YEARLY`** 를 봐야 한다. ⚠️광고비는 예산 원장에 항목이 없다 — 대행사 원천(`WIDE_AD_PERFORMANCE`)에서 가져오며 **예산과 같은 표에 합산하지 말 것**(원천이 다르다 · 순서9-K 표 분리 근거). 🔴🔴[O51-F 실측] **부서·캠페인별 분해가 현재 불가능**하다 — `ORG_DEPARTMENT`·`CAMPAIGN_BK`·`CAMPAIGN_NAME` 이 전건 `'(미매핑)'` 센티넬이라 「부서별 예산·집행」 요구에 **조용히 총계 1행**이 돌아온다. 조직 상위 계층(CORP·DIVISION·TEAM)도 차원 자체가 비어 있다(CONF-4).$$
    as (
      -- WIDE_BUDGET: 예산 팩트(FBD) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.9)
-- Co-authored with CoCo
-- ⚠️ FACT_BUDGET 는 편성/집행만 적재. FUNDRAISING_COST(E-1)·AD_COST(E-4) 원천부재로 현재 NULL(외부 입고 대기).
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    as CAL_MONTH,
    f.PLAN_BUDGET_MONTH, f.PLAN_BUDGET_YEAR,
    f.EXEC_BUDGET_ERP, f.EXEC_BUDGET_EST,
    f.FUNDRAISING_COST, f.AD_COST,
    f.DW_SOURCE_SYSTEM,
    o.CORP as ORG_CORP, o.DIVISION as ORG_DIVISION,
    o.DEPARTMENT as ORG_DEPARTMENT, o.TEAM as ORG_TEAM,
    bi.BUDGET_ITEM_NAME as BUDGET_ITEM_NAME, bi.BUDGET_CATEGORY as BUDGET_CATEGORY,
    c.CAMPAIGN_BK as CAMPAIGN_BK, c.BRAND as CAMPAIGN_BRAND, c.CAMPAIGN_NAME as CAMPAIGN_NAME,
    s.SPONSORSHIP_BK as SPONSORSHIP_BK, s.SPONSORSHIP_NAME as SPONSORSHIP_NAME
from GN_DW.GOLD.FACT_BUDGET f
left join GN_DW.GOLD.DIM_ORG         o  on f.ORG_SK         = o.ORG_SK
left join GN_DW.GOLD.DIM_BUDGET_ITEM bi on f.BUDGET_ITEM_SK = bi.BUDGET_ITEM_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c  on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP s  on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
    );