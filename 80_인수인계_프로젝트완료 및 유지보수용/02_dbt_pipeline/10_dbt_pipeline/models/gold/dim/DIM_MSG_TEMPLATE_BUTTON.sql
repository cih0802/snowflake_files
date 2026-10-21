-- DIM_MSG_TEMPLATE_BUTTON: 알림톡 템플릿 버튼 (템플릿 × 버튼순번 grain) — CRM_MSG_TEMPLATE_BUTTON
--  [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
{{ config(
    materialized='incremental',
    unique_key='TEMPLATE_BUTTON_SK',
    tags=['gold_pending']
) }}

select
    {{ gold_sk(['b.TMPLAT_ID', 'b.BTN_SEQ']) }}      as TEMPLATE_BUTTON_SK,
    --  [O249 · DR-31] 템플릿 마스터에 없는 버튼 = SK 0(DIM_MSG_TEMPLATE unknown 멤버) · 원천 TMPLAT_ID 는 그대로 남긴다
    IFF(t.TEMPLATE_KEY IS NULL, 0, {{ gold_sk(["'MSG_AT'", 'b.TMPLAT_ID']) }}) as TEMPLATE_SK,
    b.TMPLAT_ID, b.BTN_SEQ, b.BTN_TY_CD, b.BTN_NM, b.ANDROID_URL, b.IOS_URL, b.MOBILE_URL, b.PC_URL,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_MSG_TEMPLATE_BUTTON') }} b
left join (select distinct TEMPLATE_KEY from {{ ref('CRM_MSG_TEMPLATE') }} where SEND_CHANNEL = 'MSG_AT') t
    on t.TEMPLATE_KEY = b.TMPLAT_ID
