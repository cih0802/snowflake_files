-- warn_erp_budget_month_grain: `ERP_BUDGET` 의 의도된 grain 이 유지되는지 관측한다.
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (2026-08-29 O114-B 신설)
--   `ERP_BUDGET` 헤더는 grain 을 **(BUDGET_ITEM_DK × MONTH_NO)** 로 선언하고, `FACT_BUDGET` 은
--   그 전제로 `MONTH_KEY × BUDGET_ITEM_SK` 팩트를 만든다. 그러나 모델에 `DISTINCT` 가 없고
--   `BUDGET_ITEM_DK` 산식이 원천의 구분 축 3개(`BDGT_PRCD_NM`·`BDGT_ITEM_NM`·`DVLP_INBOUND_PATH`)를
--   **버리므로** 한 (키, 월) 조합에 원천 행이 여럿 들어온다.
--   ⚠️ 이 자체가 곧 「틀렸다」는 뜻은 아니다 — 가법 측정치라면 SUM 은 여전히 총액을 준다.
--   🔴 문제는 ㉠ **비가법 소비**(최신값·평균·비율)가 조용히 틀어지고 ㉡ 차원으로 **분해**할 때
--      「합쳐진 것」이 「하나인 것」처럼 보인다는 점이다.
--
-- 🔴 왜 `unique` 스키마 테스트가 아닌가
--   복합키 유일성 테스트는 `dbt_utils.unique_combination_of_columns` 가 필요한데 이 프로젝트에는
--   **패키지가 설치돼 있지 않다**(`packages.yml` 부재) ⇒ singular test 로 같은 판정을 한다.
--
-- ⚠️ 이 테스트가 보지 못하는 것
--   ⓐ **원인은 알려주지 않는다** — 어느 축이 빠져서 뭉갰는지는
--      `warn_erp_budget_procedure_merge.sql`(차수 축)이 짚는다.
--   ⓑ 금액의 정오는 판정하지 않는다(가법성 판단은 현업 소관 · DEC-44).
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 중복된 (예산과목, 월) 조합 1건.
-- ⚠️ [DEC-44 관측 유지] 키 산식(10컬럼)을 유지하고 팩트(GOLD)에서 최신 차수만 필터링(안 ㉡)했으므로,
--    SILVER ERP_BUDGET 에는 원천 차수/구분축 중복(528건)이 보존된다.
--    따라서 이 테스트는 warn 으로 원천 상태를 관측하며, 최종 단일 grain 보장은 `warn_fact_budget_grain`(error)이 담당한다.
{{ config(severity = 'warn') }}

SELECT
    BUDGET_ITEM_DK          AS BUDGET_ITEM_DK,
    MONTH_NO                AS MONTH_NO,
    COUNT(*)                AS N_ROWS,
    SUM(YEAR_BUDGET_AMT)    AS SUMMED_PLAN_BUDGET_MONTH,
    SUM(EXEC_AMT)           AS SUMMED_EXEC_AMT
FROM {{ ref('ERP_BUDGET') }}
GROUP BY BUDGET_ITEM_DK, MONTH_NO
HAVING COUNT(*) > 1
ORDER BY N_ROWS DESC, BUDGET_ITEM_DK, MONTH_NO
