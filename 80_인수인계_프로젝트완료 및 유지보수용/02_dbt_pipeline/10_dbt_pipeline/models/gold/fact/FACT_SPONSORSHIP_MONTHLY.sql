-- FACT_SPONSORSHIP_MONTHLY: 기준연월 × 후원사업 월 팩트 (후원사업별 미납율 분자·분모)
--  [2026-10-16 O237-C · 공#79 후원사업별 미납율 = 후원사업 미납(건) ÷ 후원사업 활동(건)]
--   왜 새 팩트인가 = SV_MEMBER_MONTHLY 는 후원사업 축이 없고(FMM SPONSORSHIP_SK 는 단일 후원사업 월만 연결),
--   SV_MEMBER_FEE·PAYMENT_BILLING_STATUS 는 활동(건)이 없다 ⇒ 한 grain 에 둘을 함께 싣는다.
--    대상 집합·판정식은 FMM·FACT_CAMPAIGN_MONTHLY 와 같다(월별 합 = FMM 합 · 사전 대사 202609 DIFF 0):
--     · 대상 = FMM (MONTH_KEY, MEMBER_DK) 스파인
--     · 활동(건) = FMSS span as-of SPNSR_AMT ÷ 10,000 ⇒ 후원사업 = span SPONSORSHIP_SK
--     · 납입·미납회비 = FACT_MEMBER_FEE(회원×월×후원사업) ⇒ 후원사업 = 청구 행 SPONSORSHIP_SK
--   WARN: 비율은 저장하지 않는다 — SV 가 「합의 비」로 계산한다(미납(건) = UNPAID_BILLED_AMT ÷ 10,000).
{{ config(
    tags=['gold_ready']
) }}

with spine as (
    select distinct MONTH_KEY, MEMBER_DK
    from {{ ref('FACT_MEMBER_MONTHLY') }}
    where MONTH_KEY > 0
),

m_span as (
    select
        sp.MONTH_KEY, COALESCE(sn.SPONSORSHIP_SK, 0) as SPONSORSHIP_SK,
        SUM(case when sn.DSCNTC_MONTH_KEY is null or sn.DSCNTC_MONTH_KEY > sp.MONTH_KEY
                 then sn.SPNSR_AMT else 0 end) / 10000                        as ACTIVE_CNT
    from spine sp
    join {{ ref('FACT_MEMBER_SPONSORSHIP_SPAN') }} sn
      on sn.MEMBER_DK = sp.MEMBER_DK
     and (sn.START_MONTH_KEY <= sp.MONTH_KEY or sn.DSCNTC_MONTH_KEY = sp.MONTH_KEY)
    group by 1, 2
),

m_fee as (
    select f.MONTH_KEY, COALESCE(f.SPONSORSHIP_SK, 0) as SPONSORSHIP_SK,
           SUM(f.PAID_FEE_BILLABLE) as PAID_FEE_BILLABLE,
           SUM(f.UNPAID_BILLED_AMT) as UNPAID_BILLED_AMT
    from {{ ref('FACT_MEMBER_FEE') }} f
    join spine sp on sp.MONTH_KEY = f.MONTH_KEY and sp.MEMBER_DK = f.MEMBER_DK
    group by 1, 2
)

select
    COALESCE(s.MONTH_KEY, f.MONTH_KEY)              as BASE_MONTH_KEY,
    FLOOR(COALESCE(s.MONTH_KEY, f.MONTH_KEY) / 100) as BASE_YEAR,
    COALESCE(s.SPONSORSHIP_SK, f.SPONSORSHIP_SK)    as SPONSORSHIP_SK,
    COALESCE(s.ACTIVE_CNT, 0)                       as ACTIVE_CNT,
    COALESCE(f.PAID_FEE_BILLABLE, 0)                as PAID_FEE_BILLABLE,
    COALESCE(f.UNPAID_BILLED_AMT, 0)                as UNPAID_BILLED_AMT,
    {{ gold_meta('CRM') }}
from m_span s
full outer join m_fee f
  on f.MONTH_KEY = s.MONTH_KEY and f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
