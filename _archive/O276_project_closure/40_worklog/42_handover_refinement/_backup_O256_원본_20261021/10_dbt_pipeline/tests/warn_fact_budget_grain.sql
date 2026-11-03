-- warn_fact_budget_grain: `FACT_BUDGET` 의 월×예산과목(최신차수) 단일 grain 불변식을 검증한다.
-- Co-authored with CoCo
--
-- 🔴 DEC-44 집행 검증: 최신 차수만 필터링한 FACT_BUDGET 은 (MONTH_KEY, BUDGET_ITEM_SK, DVLP_INBOUND_PATH) 가 유일해야 한다.
--   🆕 [2026-10-02 O198 · DEC-60] 개발 유입경로를 grain 키로 편입(원천 원장 grain 일치 · NULL 은 한 그룹으로 센다).
-- 판정: 반환 행이 있으면 ERROR.
{{ config(severity = 'error') }}

SELECT
    MONTH_KEY,
    BUDGET_ITEM_SK,
    DVLP_INBOUND_PATH,
    COUNT(*) AS N_ROWS
FROM {{ ref('FACT_BUDGET') }}
GROUP BY MONTH_KEY, BUDGET_ITEM_SK, DVLP_INBOUND_PATH
HAVING COUNT(*) > 1
