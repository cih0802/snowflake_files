-- FACT_EXPENSE_RESOLUTION: 지출결의 팩트 (1행 = 원천 1행) · 🆕 [2026-10-08 O213-F Y3-K]
-- Co-authored with CoCo
-- grain: RESOLUTION_NO × ROW_SEQ (SILVER.ERP_EXPENSE_RESOLUTION 과 1:1)
-- 왜 신설했나 — 「부서별 지출」 질문의 유일한 원천이다(예산 원장 FACT_BUDGET.ORG_SK 는 전건 센티넬 · O51-F).
--   결의부서·목·세목·세세목·재원·출처구분이 SILVER/GOLD 어디에도 없었다(O213 Y1 NONE).
-- 🔴🔴 FACT_BUDGET·FACT_BUDGET_YEARLY 와 한 표 합산 금지(원천·범위가 다르다 · 조인 근거 없음).
-- 🔴 전 컬럼 동일 행 7,287 보존(제거 근거 없음) — 금액 합 = 원천 합 · 현업 확인 = 문서20 N-29 ⑧.
{{ config(
    tags=['gold_ready']
) }}

select
    COALESCE({{ date_sk('WRITE_DATE') }}, 0)   as DATE_SK,
    RESOLUTION_NO,
    ROW_SEQ,
    RESOLUTION_YEAR,
    RESOLUTION_DEPT_NM,
    EXPS_RESOLUTION_NM,
    SOURCE_DIV_NM,
    BDGT_UNIT_NM,
    MOK_NM,
    DTL_ITEM_NM,
    SUBDTL_ITEM_NM,
    FUND_SOURCE_NM,
    DESCRIPTION,
    SUM_AMT,
    {{ gold_meta('ERP') }}
from {{ ref('ERP_EXPENSE_RESOLUTION') }}
