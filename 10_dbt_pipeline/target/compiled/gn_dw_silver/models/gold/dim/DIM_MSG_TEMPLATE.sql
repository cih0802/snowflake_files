-- =============================================================================
-- Purpose    : 발송 템플릿 차원 (채널 × 템플릿 grain) — CRM_MSG_TEMPLATE (+ 버튼 수)
-- Target     : GOLD.DIM_MSG_TEMPLATE (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_MSG_TEMPLATE_BUTTON, ref CRM_MSG_TEMPLATE
-- Issue      : O188-F, O249, DR-31, A8-29
-- =============================================================================
-- DIM_MSG_TEMPLATE: 발송 템플릿 차원 (채널 × 템플릿 grain) — CRM_MSG_TEMPLATE (+ 버튼 수)
--  [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영


with btn as (
    select TMPLAT_ID, COUNT(*) as BUTTON_CNT
    from GN_DW.SILVER.CRM_MSG_TEMPLATE_BUTTON
    group by 1
)
select
    ABS(HASH(COALESCE(CAST(t.SEND_CHANNEL AS VARCHAR), '∅') || '‖' || COALESCE(CAST(t.TEMPLATE_KEY AS VARCHAR), '∅')))  as TEMPLATE_SK,
    t.SEND_CHANNEL, t.TEMPLATE_KEY, t.CPR_DIV_CD, t.SNDNG_CD_ID, t.SNDNG_DTL_CD_ID, t.ATMC_YN,
    t.TIT, t.TEMPLATE_CTNT, t.WRITNG_DEPT_ID, t.WRITNG_DEPT_NM, t.CHRG_DEPT_ID,
    t.APRV_STAT_CD, t.APRV_FAILR_CTNT, t.TEMPLATE_RM,
    t.ALTRTV_MSG_SNDNG_YN, t.ALTRTV_MSG_TMPLAT_KEY, t.ALTRTV_MSG_CTNT, t.ALTRTV_MSG_ATCHFL_ID,
    t.WRITNG_GUIDE_ATCHFL_ID, t.USE_YN, t.FRST_REGIST_DT, t.LAST_UPDT_DT,
    IFF(t.SEND_CHANNEL = 'MSG_AT', COALESCE(b.BUTTON_CNT, 0), NULL) as BUTTON_CNT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID
from GN_DW.SILVER.CRM_MSG_TEMPLATE t
left join btn b on t.SEND_CHANNEL = 'MSG_AT' and b.TMPLAT_ID = t.TEMPLATE_KEY

union all
--  [O249 · DR-31 · A8-29] unknown 멤버(SK=0): 템플릿 마스터에 없는 버튼(18 템플릿 · 21행)의 FK 고아 해소.
--   열 순서 = 라이브 28열(SK + 채널·키 + 20 NULL + BUTTON_CNT NULL + 감사 4).
select 0, '(미매핑)', '(미매핑)',
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID