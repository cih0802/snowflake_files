-- =============================================================================
-- Purpose    : 지출결의 팩트 (1행 = 원천 1행) · 🆕 [2026-10-08 O213-F Y3-K]
-- Target     : GOLD.FACT_EXPENSE_RESOLUTION (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_CAMPAIGN, ref DIM_MARKETING_CAMPAIGN, ref ERP_EXPENSE_RESOLUTION
-- Issue      : O213-F, O51-F, O213, O225-B
-- =============================================================================
-- FACT_EXPENSE_RESOLUTION: 지출결의 팩트 (1행 = 원천 1행) · [2026-10-08 O213-F Y3-K]
-- grain: RESOLUTION_NO × ROW_SEQ (SILVER.ERP_EXPENSE_RESOLUTION 과 1:1)
-- 왜 신설했나 — 「부서별 지출」 질문의 유일한 원천이다(예산 원장 FACT_BUDGET.ORG_SK 는 전건 센티넬 · O51-F).
--   결의부서·목·세목·세세목·재원·출처구분이 SILVER/GOLD 어디에도 없었다(O213 Y1 NONE).
-- WARN: FACT_BUDGET·FACT_BUDGET_YEARLY 와 한 표 합산 금지(원천·범위가 다르다 · 조인 근거 없음).
-- WARN: 전 컬럼 동일 행 7,287 보존(제거 근거 없음) — 금액 합 = 원천 합 · 현업 확인 = 문서20 N-29 ⑧.
{{ config(
    tags=['gold_ready']
) }}

--  [2026-10-14 O225-B] 콘텐츠구분자(= 세부캠페인코드 · 현업 확인) → CRM 캠페인 → 마케팅캠페인.
--   실측(xh20001): 값 150종 중 149종이 CRM_CAMPAIGN.CMPGN_CD 와 일치 · 코드 1개 → 마케팅캠페인 최대 1개(1:N 0건)
--   ⇒ 대표 선정 규칙이 필요 없다. 다만 CRM 원천은 같은 CMPGN_CD 가 여러 행일 수 있으므로 코드당 1행으로 접는다
--   (1:N 이 생기면 행수 최다 → 코드 순으로 결정 · `warn_fer_mktg_campaign_multi` 가 경고한다 · 버리지 않는다).
--   WARN: 연결 금액은 현재 2,893,355,860원(1.0%) — NULL·「-」 99% 는 향후 입고 가정(사용자 결정 O225-B).
with cmk as (
    select
        c.CMPGN_CD,
        mk.MKTG_CAMPAIGN_SK
    from {{ ref('CRM_CAMPAIGN') }} c
    join {{ ref('DIM_MARKETING_CAMPAIGN') }} mk
      on mk.MKTG_CAMPAIGN_BK = TO_VARCHAR(c.MKTG_CMPGN_NM)
    group by 1, 2
    qualify row_number() over (partition by c.CMPGN_CD order by count(*) desc, mk.MKTG_CAMPAIGN_SK) = 1
)

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
    {{ gold_meta('ERP') }},
    e.CONTENTS_DELIMITER                       as CONTENTS_DELIMITER,
    COALESCE(cmk.MKTG_CAMPAIGN_SK, 0)          as MKTG_CAMPAIGN_SK,
    --  [2026-10-25 O262-B · 33 §1] 예산항목명(원천 BDGT_ITEM_NM · 20종) — 목·세목·세세목과 다른 축(일치 451/61,785) · 06_DDL 동기 · 맨 끝 append
    e.BDGT_ITEM_NM                             as BDGT_ITEM_NM
from {{ ref('ERP_EXPENSE_RESOLUTION') }} e
left join cmk
       on cmk.CMPGN_CD = TRIM(e.CONTENTS_DELIMITER)
