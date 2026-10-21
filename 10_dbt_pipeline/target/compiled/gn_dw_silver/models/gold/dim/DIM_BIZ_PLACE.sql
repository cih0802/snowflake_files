-- =============================================================================
-- Purpose    : 결연 사업장 차원 (BPLC_CD grain) — CRM_BIZ_PLACE
-- Target     : GOLD.DIM_BIZ_PLACE (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_BIZ_PLACE
-- Issue      : O188-F
-- =============================================================================
-- DIM_BIZ_PLACE: 결연 사업장 차원 (BPLC_CD grain) — CRM_BIZ_PLACE
--  [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영


select
    ABS(HASH(COALESCE(CAST(BPLC_CD AS VARCHAR), '∅')))     as BIZ_PLACE_SK,
    BPLC_CD, NATION_CD, BPLC_KORNM, BPLC_ENGNM,
    BSNS_STRT_DE, BSNS_END_DE, RELATNSP_BSNS_YN, RELATNSP_BSNS_DSCNTC_DE,
    GFTMNEY_PSBL_YN, LETTER_PSBL_YN, BPLC_DC, WTWK_FROM_DSTNC, CNCSN_RSN, BPLC_MTCHG_MNG_YN,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID
from GN_DW.SILVER.CRM_BIZ_PLACE
union all
-- unknown 멤버(SK=0): 아동 마스터의 사업장코드가 사업장 마스터에 없는 행( 3,821명) 조인 유실 방지
select 0, NULL, NULL, '(미매핑)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID