-- =============================================================================
-- Purpose    : 예산 세세목 차원 (SILVER.ERP_BUDGET_ITEM → 세세목명/예산구분), 순서9-C 신설.
-- Target     : GOLD.DIM_BUDGET_ITEM (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref ERP_BUDGET_ITEM
-- Issue      : O198, DEC-60, O213-F
-- =============================================================================
-- DIM_BUDGET_ITEM: 예산 세세목 차원 (SILVER.ERP_BUDGET_ITEM → 세세목명/예산구분), 순서9-C 신설.
-- 매핑: BUDGET_ITEM_NAME=최하위 예산과목(세세목 우선 COALESCE) · BUDGET_CATEGORY=수입/지출 구분(INCOME_EXPS_DIV_NM).
--   장/관/항/목/세목 상위 계층은 GOLD DDL(2속성 최소차원)에 미수용 → 필요 시 DDL 확장 후 추가.


with s as (
    select * from GN_DW.SILVER.ERP_BUDGET_ITEM
)

select
    ABS(HASH(COALESCE(CAST(BUDGET_ITEM_DK AS VARCHAR), '∅')))                 as BUDGET_ITEM_SK,
    COALESCE(SUBDTL_ITEM_NM, DTL_ITEM_NM, MOK_NM)     as BUDGET_ITEM_NAME,   -- 세세목명(최하위 우선)
    INCOME_EXPS_DIV_NM                                as BUDGET_CATEGORY,    -- 예산구분(수입/지출)
    'ERP'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID,
    BDGT_UNIT_NM                                      as BDGT_UNIT_NM,       -- [O198 · DEC-60] 예산단위(세세목 1:1 · DDL 말미 ordinal)
    --  [2026-10-08 O213-F Y3-K] 예산 과목 계층 장·관·항 + 재원 — SILVER 에만 있던 4축(원천 컬럼명 원칙)
    JANG_NM,
    KWAN_NM,
    HANG_NM,
    FUND_SOURCE_NM
from s

union all
select 0, '(미매핑)', NULL,
    'ERP'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID,
    NULL,
    NULL, NULL, NULL, NULL