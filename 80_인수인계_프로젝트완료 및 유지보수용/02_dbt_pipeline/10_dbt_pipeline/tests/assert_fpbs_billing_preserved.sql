-- =============================================================================
-- Purpose    : [2026-10-14 O225-C] FACT_PAYMENT_BILLING_STATUS 는 캠페인 축(CAMPAIGN_SK)을 grain 에 넣은 뒤에도
-- Target     : dbt singular test assert_fpbs_billing_preserved (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_PAYMENT_BILLING, ref FACT_PAYMENT_BILLING_STATUS
-- Issue      : O225-C
-- =============================================================================
-- [2026-10-14 O225-C] FACT_PAYMENT_BILLING_STATUS 는 캠페인 축(CAMPAIGN_SK)을 grain 에 넣은 뒤에도
--   원천 청구 행·금액을 잃거나 복제하지 않아야 한다.
--
-- 왜: 캠페인은 `macros/billing_campaign_asof.sql` 이 청구 행마다 후원 span 을 left join 한 뒤
--   qualify row_number() = 1 로 1개를 고른다. 파티션 키(PAY_KEY · MBRFEE_SQNC · PAYMENT_TYPE)가 행을 유일하게
--   식별하지 못하면 qualify 가 **청구 행을 조용히 버린다**(에러 없음). 반대로 qualify 를 빼면 span 수만큼 복제된다.
--    이전 계정 실측 = 3키 유일 50,835,416 / 50,835,416 · dry-run grain 12,116 → 1,104,308행.
--   ⇒ 원천(MBER_NO 있는 행)과 팩트의 청구 행수·청구액·납입액을 원 단위로 대조한다.
-- 판정: 0행이면 PASS.
{{ config(severity = 'error') }}

with src as (
    select count(*) as N, SUM(RQEST_AMT) as BILLED, SUM(PAY_AMT) as PAID
    from {{ ref('CRM_PAYMENT_BILLING') }}
    where MBER_NO is not null
),
fct as (
    select SUM(BILLING_ROWS) as N, SUM(BILLED_AMT) as BILLED, SUM(PAID_FEE) as PAID
    from {{ ref('FACT_PAYMENT_BILLING_STATUS') }}
)
select s.N as SRC_ROWS, f.N as FACT_ROWS, s.BILLED as SRC_BILLED, f.BILLED as FACT_BILLED, s.PAID as SRC_PAID, f.PAID as FACT_PAID
from src s cross join fct f
where s.N <> f.N
   or ROUND(COALESCE(s.BILLED, 0), 2) <> ROUND(COALESCE(f.BILLED, 0), 2)
   or ROUND(COALESCE(s.PAID, 0), 2) <> ROUND(COALESCE(f.PAID, 0), 2)
