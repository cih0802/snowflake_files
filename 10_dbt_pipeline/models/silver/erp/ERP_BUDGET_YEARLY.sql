-- ERP_BUDGET_YEARLY: ERP 원장 연 총액 4종 (편성·추경·조정·집행) — 연 grain, O93 신설.
-- Co-authored with CoCo
--
-- 왜 신설했나: 형제 모델 `ERP_BUDGET` 은 같은 원장에서 **월별 12벌만** 언피벗한다.
--   원장은 그 옆에 **연 총액 4종**을 따로 들고 있는데 아무 모델도 읽지 않아 버려지고 있었다
--   ⇒ `GOLD.FACT_BUDGET.PLAN_BUDGET_YEAR` 가 전건 NULL 이었다.
-- 🔴 `ERP_BUDGET` 에 컬럼을 덧붙이지 않은 이유 = 그 모델은 **월 grain**(12행/원장행)이다.
--    연값을 거기 넣으면 12벌로 복제되고 SUM 이 12배가 된다. grain 이 다르면 모델을 나눈다.
-- 🟢 `BUDGET_ITEM_DK` 는 `ERP_BUDGET`·`ERP_BUDGET_ITEM` 과 **같은 MD5 식**이다 — 세 모델이
--    같은 과목축으로 조인·대조된다. 식을 바꿀 때는 세 곳을 함께 바꿔야 한다(같은 것을 다르게 재는 지점).
-- ⚠️ `INCOME_EXPS_DIV_NM = 'TOTAL'` 행은 제외한다 — 원장 자체의 합계행이라 과목 단위가 아니고,
--    남기면 이중계상된다. `ERP_BUDGET` 과 동일한 필터다.
SELECT
  MD5(COALESCE(TO_VARCHAR(YEAR),'')||'|'||COALESCE(INCOME_EXPS_DIV_NM,'')||'|'||COALESCE(BDGT_UNIT_NM,'')||'|'||
      COALESCE(JANG_NM,'')||'|'||COALESCE(KWAN_NM,'')||'|'||COALESCE(HANG_NM,'')||'|'||
      COALESCE(MOK_NM,'')||'|'||COALESCE(DTL_ITEM_NM,'')||'|'||COALESCE(SUBDTL_ITEM_NM,'')||'|'||
      COALESCE(FUND_SOURCE_NM,''))          AS BUDGET_ITEM_DK,
  TRY_TO_NUMBER(YEAR)                       AS BUDGET_YEAR,
  NULLIF(TRIM(BDGT_PRCD_NM),'')             AS BUDGET_PROCEDURE,
  YEAR_BDGT_TOT_AMT                         AS YEAR_BDGT_TOT_AMT,
  CHN_BDGT_TOT_AMT                          AS CHN_BDGT_TOT_AMT,
  ADJ_BDGT_TOT_AMT                          AS ADJ_BDGT_TOT_AMT,
  EXEC_TOT_AMT                              AS EXEC_TOT_AMT,
  'ERP'                                     AS DW_SOURCE_SYSTEM,
  'BRONZE_ERP.BDGT_ACMSLT_LEDGER'           AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()                       AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                       AS DW_UPDATE_TS,
  NULL                                      AS DW_BATCH_ID
FROM {{ source('bronze_erp','BDGT_ACMSLT_LEDGER') }}
WHERE INCOME_EXPS_DIV_NM <> 'TOTAL'
