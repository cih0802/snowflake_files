select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- warn_fact_budget_grain: `FACT_BUDGET` 의 월×예산과목(최신차수) 단일 grain 불변식을 검증한다.
-- Co-authored with CoCo
--
-- 🔴 DEC-44 집행 검증: 최신 차수만 필터링한 FACT_BUDGET 은 (MONTH_KEY, BUDGET_ITEM_SK) 가 유일해야 한다.
-- 판정: 반환 행이 있으면 ERROR.


SELECT
    MONTH_KEY,
    BUDGET_ITEM_SK,
    COUNT(*) AS N_ROWS
FROM GN_DW.GOLD.FACT_BUDGET
GROUP BY MONTH_KEY, BUDGET_ITEM_SK
HAVING COUNT(*) > 1
      
    ) dbt_internal_test