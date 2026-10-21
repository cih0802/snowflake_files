-- =============================================================================
-- Purpose    : 알림톡 템플릿 버튼 (템플릿 × 버튼순번 grain) — CRM_MSG_TEMPLATE_BUTTON
-- Target     : GOLD.DIM_MSG_TEMPLATE_BUTTON (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_MSG_TEMPLATE_BUTTON, ref CRM_MSG_TEMPLATE
-- Issue      : O188-F, O249, DR-31
-- =============================================================================
-- DIM_MSG_TEMPLATE_BUTTON: 알림톡 템플릿 버튼 (템플릿 × 버튼순번 grain) — CRM_MSG_TEMPLATE_BUTTON
--  [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영


select
    ABS(HASH(COALESCE(CAST(b.TMPLAT_ID AS VARCHAR), '∅') || '‖' || COALESCE(CAST(b.BTN_SEQ AS VARCHAR), '∅')))      as TEMPLATE_BUTTON_SK,
    --  [O249 · DR-31] 템플릿 마스터에 없는 버튼 = SK 0(DIM_MSG_TEMPLATE unknown 멤버) · 원천 TMPLAT_ID 는 그대로 남긴다
    IFF(t.TEMPLATE_KEY IS NULL, 0, ABS(HASH(COALESCE(CAST('MSG_AT' AS VARCHAR), '∅') || '‖' || COALESCE(CAST(b.TMPLAT_ID AS VARCHAR), '∅')))) as TEMPLATE_SK,
    b.TMPLAT_ID, b.BTN_SEQ, b.BTN_TY_CD, b.BTN_NM, b.ANDROID_URL, b.IOS_URL, b.MOBILE_URL, b.PC_URL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID
from GN_DW.SILVER.CRM_MSG_TEMPLATE_BUTTON b
left join (select distinct TEMPLATE_KEY from GN_DW.SILVER.CRM_MSG_TEMPLATE where SEND_CHANNEL = 'MSG_AT') t
    on t.TEMPLATE_KEY = b.TMPLAT_ID