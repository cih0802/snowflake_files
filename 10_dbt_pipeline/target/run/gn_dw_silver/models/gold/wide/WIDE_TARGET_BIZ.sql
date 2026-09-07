create or replace view GN_DW.GOLD.WIDE_TARGET_BIZ
    (
      MONTH_KEY COMMENT $$목표월 YYYYMM 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      CAL_YEAR COMMENT $$FLOOR(MONTH_KEY/100) — 연도 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      CAL_MONTH COMMENT $$MOD(MONTH_KEY,100) — 월 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      ANNUAL_GOAL_CNT COMMENT $$연사업목표(건) (#152) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      SUPP_GOAL_CNT COMMENT $$추경목표(건) (#153) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      ANNUAL_CUM_GOAL_CNT COMMENT $$연사업누계목표(건) (#154) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      SUPP_CUM_GOAL_CNT COMMENT $$추경누계목표(건) (#155) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      ORG_CORP COMMENT $$DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      ORG_DIVISION COMMENT $$DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      ORG_DEPARTMENT COMMENT $$DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34). 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      ORG_TEAM COMMENT $$DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      SPONSORSHIP_BK COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      SPONSORSHIP_NAME COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_BK COMMENT $$DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_BRAND COMMENT $$DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F.$$
    )
    comment = $$사업목표 팩트(FTG_B) 평탄화 — ORG·SPONSORSHIP·CAMPAIGN. 월 grain=MONTH_KEY. E-6 원천부재 0행(입고 시 자동 채워짐).$$
    as (
      -- WIDE_TARGET_BIZ: 사업목표 팩트(FTG_B) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.4)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    as CAL_MONTH,
    f.ANNUAL_GOAL_CNT, f.SUPP_GOAL_CNT,
    f.ANNUAL_CUM_GOAL_CNT, f.SUPP_CUM_GOAL_CNT,
    f.DW_SOURCE_SYSTEM,
    o.CORP       as ORG_CORP,
    o.DIVISION   as ORG_DIVISION,
    o.DEPARTMENT as ORG_DEPARTMENT,
    o.TEAM       as ORG_TEAM,
    s.SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME,
    c.CAMPAIGN_BK,
    c.BRAND      as CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME
from GN_DW.GOLD.FACT_TARGET_BIZ f
left join GN_DW.GOLD.DIM_ORG         o on f.ORG_SK = o.ORG_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c on f.CAMPAIGN_SK = c.CAMPAIGN_SK
    );