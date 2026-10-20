-- DIM_MSG_TEMPLATE_BUTTON: 알림톡 템플릿 버튼 (템플릿 × 버튼순번 grain) — CRM_MSG_TEMPLATE_BUTTON
-- Co-authored with CoCo
-- 🆕 [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
{{ config(
    materialized='incremental',
    unique_key='TEMPLATE_BUTTON_SK',
    tags=['gold_pending']
) }}

select
    {{ gold_sk(['TMPLAT_ID', 'BTN_SEQ']) }}          as TEMPLATE_BUTTON_SK,
    {{ gold_sk(["'MSG_AT'", 'TMPLAT_ID']) }}         as TEMPLATE_SK,
    TMPLAT_ID, BTN_SEQ, BTN_TY_CD, BTN_NM, ANDROID_URL, IOS_URL, MOBILE_URL, PC_URL,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_MSG_TEMPLATE_BUTTON') }}
