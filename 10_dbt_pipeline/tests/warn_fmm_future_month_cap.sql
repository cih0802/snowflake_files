-- =============================================================================
-- Purpose    : FACT_MEMBER_MONTHLY 선납 회비월이 **인정 상한(당월 +37개월)** 을 넘는지 관측한다.
-- Target     : dbt singular test warn_fmm_future_month_cap (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref FACT_MEMBER_MONTHLY
-- Issue      : O216-D, O202
-- =============================================================================
-- warn_fmm_future_month_cap: FACT_MEMBER_MONTHLY 선납 회비월이 **인정 상한(당월 +37개월)** 을 넘는지 관측한다.
--
--  [2026-10-12 O216-D · BLOCKING-2 A 처방 · 권고 기본안]
--   미래월 행 = **선납 회비월**이다(O202 원인 규명 · 202611~202911 · 원천 납입일 오타 210103 3건은 현재 0).
--   ⇒ 행은 **유지**한다(절단하면 실제 선납 청구가 사라진다).
--   WARN: 그러나 `cal_end` 가 2145 로 넓어져 **달력 상한이 더 이상 방어선이 아니다** — 오타성 원거리 미래월이
--   다시 들어와도 조용히 적재된다. 이 테스트가 그 방어선이다.
--   · 상한 = 당월 +37개월 — CK24285 실측 최대 202911 = 당월(202610) +37개월 · 초과 0행.
--   · `MONTH_KEY = 0` 은 Unknown 격리 행이라 대상이 아니다(별도 관측 · BLOCKING-2 A).
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 상한 초과 MONTH_KEY 1개와 규모.
--    정상 상태 = 0행.
{{ config(severity = 'warn', store_failures = true, schema = 'OPS') }}

SELECT
    MONTH_KEY                                    AS MONTH_KEY,
    COUNT(*)                                     AS ROW_CNT,
    COUNT(DISTINCT MEMBER_DK)                    AS MEMBER_CNT
FROM {{ ref('FACT_MEMBER_MONTHLY') }}
WHERE MONTH_KEY > TO_NUMBER(TO_CHAR(DATEADD(month, 37, CURRENT_DATE), 'YYYYMM'))
GROUP BY 1
ORDER BY 1
