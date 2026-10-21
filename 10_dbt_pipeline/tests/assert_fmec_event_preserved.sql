-- =============================================================================
-- Purpose    : [2026-10-20 O248] FACT_MEMBER_EVENT_COHORT 경과월 0 의 사건 개발(건) 합은 FME DEV 합과 같아야 한다.
-- Target     : dbt singular test assert_fmec_event_preserved (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref FACT_MEMBER_EVENT, ref FACT_MEMBER_EVENT_COHORT
-- Issue      : O248
-- =============================================================================
-- [2026-10-20 O248] FACT_MEMBER_EVENT_COHORT 경과월 0 의 사건 개발(건) 합은 FME DEV 합과 같아야 한다.
--
-- 무엇을 지키는가: 코호트 키(회원 × 사건월 × 개발구분) 축약 · 13개월 스파인 전개가 사건을 잃거나 복제하지 않는다.
--   경과월 0 행은 코호트당 1행이고 EVENT_DEV_CNT 는 그 키의 FME DEV_CNT 합이다(O248 실측 1,467,783 = 1,467,783).
--   WARN: 경과월 전 행을 SUM 하면 13배가 된다 — 이 테스트가 소비 규칙(경과월 고정)의 기준값이다.
--
-- 판정: 0행이면 PASS.
{{ config(severity = 'error') }}

with fme as (
    select SUM(DEV_CNT) as DEV_CNT, count(*) as N
    from {{ ref('FACT_MEMBER_EVENT') }}
    where EVENT_TYPE = 'DEV'
      and DATE_SK >= {{ var('billing_coverage_start_month') }}01
      and DVLP_DIV_CD is not null
),
coh as (
    select SUM(EVENT_DEV_CNT) as DEV_CNT, SUM(EVENT_ROWS) as N, count(*) as COHORTS
    from {{ ref('FACT_MEMBER_EVENT_COHORT') }}
    where MONTHS_AFTER = 0
),
spine as (
    select count(*) as ROWS_ from {{ ref('FACT_MEMBER_EVENT_COHORT') }}
)
select f.DEV_CNT as FME_DEV_CNT, c.DEV_CNT as COH_DEV_CNT, f.N as FME_ROWS, c.N as COH_EVENT_ROWS,
       c.COHORTS, s.ROWS_
from fme f cross join coh c cross join spine s
where ABS(COALESCE(f.DEV_CNT, 0) - COALESCE(c.DEV_CNT, 0)) > 0.01
   or COALESCE(f.N, 0) <> COALESCE(c.N, 0)
   or s.ROWS_ <> c.COHORTS * 13
