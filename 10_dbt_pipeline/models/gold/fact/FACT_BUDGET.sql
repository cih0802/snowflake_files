-- FACT_BUDGET: 예산 팩트 (SILVER.ERP_BUDGET 월별 언피벗 → MONTH×BUDGET_ITEM), 순서9-C 신설.
-- Co-authored with CoCo
-- 보수 매핑(재무 오귀속 방지): EXEC_BUDGET_ERP=EXEC_AMT · PLAN_BUDGET_MONTH=YEAR_BUDGET_AMT(월 편성) 만 확정.
--   ORG_SK=0: ERP_BUDGET 원장에 조직 귀속 없음(원천 grain=예산과목×월) → Unknown 라우팅.
--   CAMPAIGN_SK=0·SPONSORSHIP_SK=NULL: 원천 연결 없음.
--   NULL(원천 부재/미해소): PLAN_BUDGET_YEAR(추경 CHN·조정 ADJ 는 GOLD 슬롯 부재 → 매핑확인 TODO)·
--     EXEC_BUDGET_EST(추정집행)·FUNDRAISING_COST(E-1 원천부재)·AD_COST(E-4 원천부재).
{{ config(
    tags=['gold_pending']
) }}

with b as (
    select * from {{ ref('ERP_BUDGET') }}
)

select
    COALESCE({{ month_key_clamp('TRY_TO_NUMBER(MONTH_KEY)') }}, 0)  as MONTH_KEY,
    0                                     as ORG_SK,            -- 원천 조직귀속 없음 → Unknown
    {{ gold_sk(['BUDGET_ITEM_DK']) }}     as BUDGET_ITEM_SK,
    0                                     as CAMPAIGN_SK,       -- 원천 연결 없음
    CAST(NULL AS NUMBER(38,0))            as SPONSORSHIP_SK,
    YEAR_BUDGET_AMT                       as PLAN_BUDGET_MONTH, -- 월 편성예산
    CAST(NULL AS NUMBER(18,2))            as PLAN_BUDGET_YEAR,  -- TODO: 추경(CHN)/조정(ADJ) 슬롯 매핑 확인
    EXEC_AMT                              as EXEC_BUDGET_ERP,   -- ERP 집행
    CAST(NULL AS NUMBER(18,2))            as EXEC_BUDGET_EST,   -- 추정집행 미산출
    CAST(NULL AS NUMBER(18,2))            as FUNDRAISING_COST,  -- E-1 원천부재
    CAST(NULL AS NUMBER(18,2))            as AD_COST,           -- E-4 원천부재
    {{ gold_meta('ERP') }}
from b
