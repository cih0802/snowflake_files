-- =============================================================================
-- Purpose    : 공통 코드그룹 차원 (CD_ID grain) — CRM_CODE_GROUP (+ 상세코드 수)
-- Target     : GOLD.DIM_CODE_GROUP (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_CODE, ref CRM_CODE_GROUP
-- Issue      : O188-F
-- =============================================================================
-- DIM_CODE_GROUP: 공통 코드그룹 차원 (CD_ID grain) — CRM_CODE_GROUP (+ 상세코드 수)
--  [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영


with dtl as (
    select CD_ID, COUNT(*) as DTL_CODE_CNT from GN_DW.SILVER.CRM_CODE group by 1
)
select
    g.CD_ID, g.CD_NM, g.CD_DC, g.SORT_ORDR, g.RM, g.USE_YN,
    COALESCE(d.DTL_CODE_CNT, 0) as DTL_CODE_CNT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID
from GN_DW.SILVER.CRM_CODE_GROUP g
left join dtl d on d.CD_ID = g.CD_ID