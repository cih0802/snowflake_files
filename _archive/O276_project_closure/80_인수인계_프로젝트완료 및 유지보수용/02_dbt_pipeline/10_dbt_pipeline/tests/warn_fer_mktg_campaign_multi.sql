-- =============================================================================
-- Purpose    : [2026-10-14 O225-B] 지출결의 세부캠페인코드 → 마케팅캠페인 1:N 발생 경고 + 행·금액 보존.
-- Target     : dbt singular test warn_fer_mktg_campaign_multi (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_CAMPAIGN, ref ERP_EXPENSE_RESOLUTION, ref FACT_EXPENSE_RESOLUTION
-- Issue      : O225-B, O224
-- =============================================================================
-- [2026-10-14 O225-B] 지출결의 세부캠페인코드 → 마케팅캠페인 1:N 발생 경고 + 행·금액 보존.
--
-- 왜: 현재 코드 1개 → 마케팅캠페인 최대 1개(1:N 0건 실측)라 `FACT_EXPENSE_RESOLUTION` 은 대표 선정 없이 붙인다.
--   CRM 원천에서 같은 CMPGN_CD 가 다른 마케팅캠페인으로 등록되면 모델은 행수 최다 1개를 고른다(버리지 않는다)
--   — 그 순간 규칙 검토가 필요하므로 경고로 알린다(O224 UTM 1:N 사고의 재발 방지 · 작업계획 §15-9).
-- 반환 행 = ㉠ 1:N 코드 ㉡ 팩트 ↔ SILVER 행수·금액 불일치(조인 fan-out 감지).
-- 판정: 반환 행이 있으면 WARN.
{{ config(severity = 'warn') }}

with multi as (
    select c.CMPGN_CD as K, count(distinct c.MKTG_CMPGN_NM) as V
    from {{ ref('CRM_CAMPAIGN') }} c
    where c.MKTG_CMPGN_NM is not null
      and c.CMPGN_CD in (select TRIM(CONTENTS_DELIMITER) from {{ ref('ERP_EXPENSE_RESOLUTION') }})
    group by 1
    having count(distinct c.MKTG_CMPGN_NM) > 1
),
src as (select count(*) as N, SUM(SUM_AMT) as AMT from {{ ref('ERP_EXPENSE_RESOLUTION') }}),
fct as (select count(*) as N, SUM(SUM_AMT) as AMT from {{ ref('FACT_EXPENSE_RESOLUTION') }})
select 'MULTI_MKTG:' || K as CHECK_NM, V from multi
union all
select 'ROW_OR_AMT_MISMATCH', f.N - s.N
from src s cross join fct f
where s.N <> f.N or COALESCE(s.AMT, 0) <> COALESCE(f.AMT, 0)
