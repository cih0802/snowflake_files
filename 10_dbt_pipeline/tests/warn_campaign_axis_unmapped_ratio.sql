-- =============================================================================
-- Purpose    : [2026-10-14 O225-C] 캠페인 축 배선 후 미매핑(CAMPAIGN_SK = 0) 비율 경고 — 3팩트.
-- Target     : dbt singular test warn_campaign_axis_unmapped_ratio (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref FACT_PAYMENT_BILLING_STATUS, ref FACT_MEMBER_MONTHLY, ref FACT_MESSAGE_DISPATCH
-- Issue      : O225-C, O224
-- =============================================================================
-- [2026-10-14 O225-C] 캠페인 축 배선 후 미매핑(CAMPAIGN_SK = 0) 비율 경고 — 3팩트.
--
-- 왜: 캠페인 키는 원천이 비어도 에러 없이 0 으로 떨어진다. 비율이 갑자기 오르면 원천 코드 결손·마스터 미등록·
--   조인 키 형변환 같은 배선 결함이다(O224 의 「미매핑 33.7% 를 아무도 몰랐다」 재발 방지).
--   임계 = O225-C dry-run(xh20001) 실측 + 여유:
--     · 회비청구(금액) 캠페인 보유 98.86% ⇒ 미매핑 금액 > 5% 경고
--     · 회원월실적(행) 단일 95.4% · 다중 4.6% ⇒ 다중 아닌 미매핑 행 > 10% 경고(회비 행 있는 월 한정)
--     · 발송(SND 행) 원천 캠페인코드 채움 43%(4,931,549 / 11,545,247 · 마스터 일치 100%) ⇒ SND 행 중 매핑 < 35% 경고
-- 판정: 반환 행이 있으면 WARN.
{{ config(severity = 'warn') }}

with pbs as (
    select SUM(iff(CAMPAIGN_SK = 0, PAID_FEE, 0)) / NULLIF(SUM(PAID_FEE), 0) as R
    from {{ ref('FACT_PAYMENT_BILLING_STATUS') }}
),
fmm as (
    select COUNT_IF(CAMPAIGN_SK = 0 and not IS_MULTI_CAMPAIGN) / NULLIF(COUNT(*), 0) as R
    from {{ ref('FACT_MEMBER_MONTHLY') }}
    where HAS_BILLING
),
snd as (
    select COUNT_IF(f.CAMPAIGN_SK <> 0) / NULLIF(COUNT(*), 0) as R
    from {{ ref('FACT_MESSAGE_DISPATCH') }} f
    where f.SEND_TYPE = 'SND'
)
select 'FPBS_UNMAPPED_AMT' as CHECK_NM, ROUND(R * 100, 2) as PCT from pbs where R > 0.05
union all
select 'FMM_UNMAPPED_SINGLE_ROWS', ROUND(R * 100, 2) from fmm where R > 0.10
union all
select 'FMD_SND_MAPPED_ROWS_LOW', ROUND(R * 100, 2) from snd where R < 0.35
