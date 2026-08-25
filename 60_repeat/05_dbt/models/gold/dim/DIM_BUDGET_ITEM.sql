-- DIM_BUDGET_ITEM: 예산 세세목 차원 (SILVER.ERP_BUDGET_ITEM → 세세목명/예산구분), 순서9-C 신설.
-- Co-authored with CoCo
-- 매핑: BUDGET_ITEM_NAME=최하위 예산과목(세세목 우선 COALESCE) · BUDGET_CATEGORY=수입/지출 구분(INCOME_EXPENSE_DIV).
--   장/관/항/목/세목 상위 계층은 GOLD DDL(2속성 최소차원)에 미수용 → 필요 시 DDL 확장 후 추가.
{{ config(
    materialized='incremental',
    unique_key='BUDGET_ITEM_SK',
    tags=['gold_ready']
) }}

with s as (
    select * from {{ ref('ERP_BUDGET_ITEM') }}
)

select
    {{ gold_sk(['BUDGET_ITEM_DK']) }}                 as BUDGET_ITEM_SK,
    COALESCE(SUBDTL_ITEM_NM, DTL_ITEM_NM, MOK_NM)     as BUDGET_ITEM_NAME,   -- 세세목명(최하위 우선)
    INCOME_EXPENSE_DIV                                as BUDGET_CATEGORY,    -- 예산구분(수입/지출)
    {{ gold_meta('ERP') }}
from s

union all
-- unknown 멤버(SK=0): FACT_BUDGET.BUDGET_ITEM_SK 미매핑 조인 유실 방지 센티넬
select 0, '(미매핑)', NULL,
    {{ gold_meta('ERP') }}
