select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- warn_erp_budget_yearly_grain: `ERP_BUDGET_YEARLY` 가 선언한 불변식을 관측한다.
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (2026-08-29 O114-B 신설)
--   `FACT_BUDGET_YEARLY` 헤더는 **「🟢 이 팩트는 SUM 이 항상 안전하다 — 1행 = 1(연 × 예산과목)」**
--   을 **불변식으로 선언**한다. 그 선언이 참인지 **아무 테스트도 확인하지 않았다**
--   (`ERP_BUDGET_YEARLY`·`FACT_BUDGET_YEARLY` 둘 다 스키마 yml 에 항목 자체가 없었다).
--   ⇒ 2026-08-29 원천 교체로 그 불변식이 깨졌는데 `dbt build` 는 🟢 를 냈을 것이다.
--   🔴 **주석이 선언한 불변식은 테스트가 아니다** — 이 파일이 그 간극을 메운다(`R3-9 ㉢` 축).
--
-- 🔴 이 팩트에서 중복이 왜 더 위험한가
--   `ERP_BUDGET`(월)은 12벌 언피벗이라 「1원장행 = 12행」이 정상이고 중복이 섞여도 눈에 덜 띈다.
--   반면 이 모델은 **1원장행 = 1행**이라 (키, 연) 중복은 곧 **연 총액의 중복 계상**이다.
--   실제로 `PLAN_BUDGET_YEAR` 는 본예산과 추경이 **한 키에 합쳐진** 값이 된다.
--
-- ⚠️ 이 테스트가 보지 못하는 것
--   ⓐ **어느 축이 빠졌는지** — 원인 축은 `warn_erp_budget_procedure_merge.sql` 이 짚는다.
--      키에 없는 구분 축은 차수 외에도 `BDGT_ITEM_NM`·`DVLP_INBOUND_PATH` 가 있다.
--   ⓑ `CHN`·`ADJ` 가 전건 0 인 것은 중복이 아니라 **원천 표현 방식 변경**이다 — 여기서 안 잡힌다
--      (그 사실은 `_gold_ready_schema.yml` `FACT_BUDGET_YEARLY` 컬럼 설명에 적혀 있다).
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 중복된 (예산과목, 연) 조합 1건.
-- ⚠️ [DEC-44 관측 유지] 키 산식(10컬럼)을 유지하고 팩트(GOLD)에서 최신 차수만 필터링(안 ㉡)했으므로,
--    SILVER ERP_BUDGET_YEARLY 에는 원천 차수/구분축 중복(44건)이 보존된다.
--    따라서 이 테스트는 warn 으로 원천 상태를 관측하며, 최종 단일 grain 보장은 `warn_fact_budget_yearly_grain`(error)이 담당한다.


SELECT
    BUDGET_ITEM_DK              AS BUDGET_ITEM_DK,
    BUDGET_YEAR                 AS BUDGET_YEAR,
    COUNT(*)                    AS N_ROWS,
    SUM(YEAR_BUDGET_TOT_AMT)    AS SUMMED_PLAN_BUDGET_YEAR,
    SUM(EXEC_TOT_AMT)           AS SUMMED_EXEC_TOT_AMT
FROM GN_DW.SILVER.ERP_BUDGET_YEARLY
GROUP BY BUDGET_ITEM_DK, BUDGET_YEAR
HAVING COUNT(*) > 1
ORDER BY N_ROWS DESC, SUMMED_PLAN_BUDGET_YEAR DESC
      
    ) dbt_internal_test