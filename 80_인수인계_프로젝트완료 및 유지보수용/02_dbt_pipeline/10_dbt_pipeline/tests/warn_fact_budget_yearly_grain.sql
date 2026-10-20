-- warn_fact_budget_yearly_grain: `FACT_BUDGET_YEARLY` 의 연×예산과목(최신차수) 단일 grain 불변식을 검증한다.
-- Co-authored with CoCo
--
-- 🔴 DEC-44 집행 검증: 최신 차수만 필터링한 FACT_BUDGET_YEARLY 는 (BUDGET_YEAR, BUDGET_ITEM_SK) 가 유일해야 한다.
-- 판정: 반환 행이 있으면 ERROR.
{{ config(severity = 'error') }}

SELECT
    BUDGET_YEAR,
    BUDGET_ITEM_SK,
    COUNT(*) AS N_ROWS
FROM {{ ref('FACT_BUDGET_YEARLY') }}
GROUP BY BUDGET_YEAR, BUDGET_ITEM_SK
HAVING COUNT(*) > 1
