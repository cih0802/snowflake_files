-- [2026-10-20 O248] FACT_AD_INFLOW_ALLOC 는 배분 전후로 광고비를 잃거나 복제하지 않아야 한다.
--
-- 무엇을 지키는가: FACT_AD_PERFORMANCE(원천) ↔ 배분 팩트의 광고원천별 광고비 합계 일치.
--   배분은 (월 · 마케팅캠페인 · 원천) 안의 개발(건) 비중이라 비중 합 = 1 이어야 하고,
--   배분할 개발이 없는 광고비는 UNALLOC 행으로 남아야 한다(버리지 않는다).
--   WARN: 행 단위 NUMBER(18,2) 반올림 누적이 있어 원 단위 허용오차 1원 × 배분 행수를 둔다
--   (선례 = assert_fap_ad_cost_preserved O225-B 「반올림 누적 거짓 FAIL」).
--
-- 판정: 0행이면 PASS.
{{ config(severity = 'error') }}

with src as (
    select AD_SOURCE_TYPE, SUM(AD_COST) as COST
    from {{ ref('FACT_AD_PERFORMANCE') }}
    where PERF_DATE_SK > 0
    group by 1
),
fct as (
    select 'DIGITAL' as AD_SOURCE_TYPE, SUM(AD_COST_DIGITAL) as COST, count(*) as N from {{ ref('FACT_AD_INFLOW_ALLOC') }}
    union all
    select 'VIDEO', SUM(AD_COST_VIDEO), count(*) from {{ ref('FACT_AD_INFLOW_ALLOC') }}
    union all
    select 'REBROADCAST', SUM(AD_COST_REBROADCAST), count(*) from {{ ref('FACT_AD_INFLOW_ALLOC') }}
)
select
    COALESCE(s.AD_SOURCE_TYPE, f.AD_SOURCE_TYPE) as AD_SOURCE_TYPE,
    s.COST as SRC_COST,
    f.COST as ALLOC_COST,
    COALESCE(f.COST, 0) - COALESCE(s.COST, 0) as DIFF
from src s
full outer join fct f on f.AD_SOURCE_TYPE = s.AD_SOURCE_TYPE
where ABS(COALESCE(f.COST, 0) - COALESCE(s.COST, 0)) > COALESCE(f.N, 0) * 0.01
