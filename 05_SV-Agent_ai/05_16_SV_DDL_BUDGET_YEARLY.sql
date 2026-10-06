-- ============================================================================
-- 05_16_SV_DDL_BUDGET_YEARLY.sql — Semantic View DDL 정본: SV_BUDGET_YEARLY (🆕 O203 · T8 2차)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 근거(2026-10-06 실측): 2024 연 편성 204.9억원은 이 팩트에만 있다(FACT_BUDGET 2024 월 편성 = 0).
--     2025·2026 은 연 편성·연 집행 합계가 FACT_BUDGET 월 합계와 원 단위까지 일치 ⇒ 같은 원장의 연 grain.
--   · 1 SV = 1 base FACT(fan-out 방지) — SV_BUDGET(월 grain)과 분리한다.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET_YEARLY
  TABLES (
    fby AS GN_DW.GOLD.FACT_BUDGET_YEARLY
      WITH SYNONYMS ('연 예산', '연간 예산', '연 편성예산')
      COMMENT = '연 예산 편성·집행 팩트(base: GOLD.FACT_BUDGET_YEARLY). [Grain: 연 × 부서 × 예산과목 × 예산절차]. 🟢 2024 연 편성예산은 이 SV 에만 있다(월 예산 SV 의 2024 월 편성은 0). [원천: ERP → GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER → SILVER.ERP_BUDGET_YEARLY → GOLD.FACT_BUDGET_YEARLY].',
    item AS GN_DW.GOLD.DIM_BUDGET_ITEM
      PRIMARY KEY (BUDGET_ITEM_SK)
      WITH SYNONYMS ('세세목', '예산항목')
      COMMENT = '예산 세세목 차원. [원천] ERP · BRONZE_ERP.BDGT_ACMSLT_LEDGER — DISTINCT 마스터.'
  )
  RELATIONSHIPS (
    fby_to_item AS fby (BUDGET_ITEM_SK) REFERENCES item
  )
  DIMENSIONS (
    fby.BUDGET_YEAR AS fby.BUDGET_YEAR WITH SYNONYMS ('예산연도', '연도', '년') COMMENT = '예산 연도. 실제값 3종: 2024·2025·2026',
    fby.BUDGET_PROCEDURE AS fby.BUDGET_PROCEDURE WITH SYNONYMS ('예산절차', '예산 단계') COMMENT = '예산 절차. 실제값: 2024·2025 = ''추가경정'' · 2026 = ''연사업''. 🔴 연도마다 절차가 다르다 — 연도 비교 시 함께 밝힌다',
    item.BUDGET_ITEM_NAME AS item.BUDGET_ITEM_NAME WITH SYNONYMS ('세세목명', '예산항목명') COMMENT = '예산 세세목명',
    item.BDGT_UNIT_NM AS item.BDGT_UNIT_NM WITH SYNONYMS ('예산단위', '예산 팀', '예산 부서', '예산단위명') COMMENT = '예산단위명(ERP 표기 그대로)'
  )
  METRICS (
    fby.TOTAL_PLAN_BUDGET_YEAR AS SUM(fby.PLAN_BUDGET_YEAR)
      WITH SYNONYMS ('연 편성예산', '연간 편성예산', '연 예산') COMMENT = '연 편성예산 합계(원). F(가산 · 연도 간 합산은 의미 없음 — 연도를 고정한다).',
    fby.TOTAL_EXEC_BUDGET_YEAR AS SUM(fby.EXEC_BUDGET_YEAR)
      WITH SYNONYMS ('연 집행예산', '연간 집행액') COMMENT = '연 집행예산 합계(원). 🔴 진행 중 연도(2026)는 적재된 월까지의 누계다 — 연말 확정값이 아니다.',
    fby.EXEC_RATE_YEAR AS SUM(fby.EXEC_BUDGET_YEAR) / NULLIF(SUM(fby.PLAN_BUDGET_YEAR), 0) * 100
      WITH SYNONYMS ('연 집행율', '연간 집행율') COMMENT = '연 집행율(%) = 연 집행 ÷ 연 편성 ×100. 비율(N · 재합산 금지). 🔴 진행 중 연도는 연간 편성 대비 누계라 구조적으로 낮다 — 그 사실을 밝힌다.'
  )
  COMMENT = '연 예산 SV(🆕 O203). 「2024 연 편성예산」·「연도별 편성 대비 집행」 질문용. 월별 편성·집행·세세목 추이는 SV_BUDGET(월 grain)이다. 🔴 두 SV 의 수치를 한 표에 합산하지 않는다.'
  AI_SQL_GENERATION '핵심 규칙: (1) 연 편성=TOTAL_PLAN_BUDGET_YEAR, 연 집행=TOTAL_EXEC_BUDGET_YEAR, 연 집행율=EXEC_RATE_YEAR(%). (2) 연도(BUDGET_YEAR)를 반드시 GROUP BY 하거나 고정한다 — 여러 연도를 하나로 합산하지 않는다. (3) 결과에 예산절차(BUDGET_PROCEDURE)를 함께 보여준다. (4) 2026 은 진행 중 연도이므로 집행·집행율이 부분 연도임을 밝힌다. (5) ORDER BY 에는 SELECT 별칭을 그대로 쓴다.'
  AI_VERIFIED_QUERIES (
    vqr_o203_yearly_plan_exec AS (
      QUESTION '연도별 편성예산과 집행예산, 집행율'
      VERIFIED_BY '(DW = O203 · 2024 편성 20,494,617,159원)'
      SQL 'SELECT fby.BUDGET_YEAR, fby.BUDGET_PROCEDURE, SUM(fby.PLAN_BUDGET_YEAR) AS TOTAL_PLAN_BUDGET_YEAR, SUM(fby.EXEC_BUDGET_YEAR) AS TOTAL_EXEC_BUDGET_YEAR, SUM(fby.EXEC_BUDGET_YEAR) / NULLIF(SUM(fby.PLAN_BUDGET_YEAR), 0) * 100 AS EXEC_RATE_YEAR FROM fby GROUP BY fby.BUDGET_YEAR, fby.BUDGET_PROCEDURE ORDER BY fby.BUDGET_YEAR'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET_YEARLY TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET_YEARLY TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET_YEARLY TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인)
SELECT (SELECT TOTAL_PLAN_BUDGET_YEAR FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET_YEARLY METRICS fby.TOTAL_PLAN_BUDGET_YEAR)) AS sv_val,
       (SELECT SUM(PLAN_BUDGET_YEAR) FROM GN_DW.GOLD.FACT_BUDGET_YEARLY)                                           AS fact_val;
