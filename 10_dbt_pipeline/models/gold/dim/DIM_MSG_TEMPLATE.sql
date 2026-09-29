-- DIM_MSG_TEMPLATE: 발송 템플릿 차원 (채널 × 템플릿 grain) — CRM_MSG_TEMPLATE (+ 버튼 수)
-- Co-authored with CoCo
-- 🆕 [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
{{ config(
    materialized='incremental',
    unique_key='TEMPLATE_SK',
    tags=['gold_pending']
) }}

with btn as (
    select TMPLAT_ID, COUNT(*) as BUTTON_CNT
    from {{ ref('CRM_MSG_TEMPLATE_BUTTON') }}
    group by 1
)
select
    {{ gold_sk(['t.SEND_CHANNEL', 't.TEMPLATE_KEY']) }}  as TEMPLATE_SK,
    t.SEND_CHANNEL, t.TEMPLATE_KEY, t.CPR_DIV_CD, t.SNDNG_CD_ID, t.SNDNG_DTL_CD_ID, t.ATMC_YN,
    t.TIT, t.TEMPLATE_CTNT, t.WRITNG_DEPT_ID, t.WRITNG_DEPT_NM, t.CHRG_DEPT_ID,
    t.APRV_STAT_CD, t.APRV_FAILR_CTNT, t.TEMPLATE_RM,
    t.ALTRTV_MSG_SNDNG_YN, t.ALTRTV_MSG_TMPLAT_KEY, t.ALTRTV_MSG_CTNT, t.ALTRTV_MSG_ATCHFL_ID,
    t.WRITNG_GUIDE_ATCHFL_ID, t.USE_YN, t.FRST_REGIST_DT, t.LAST_UPDT_DT,
    IFF(t.SEND_CHANNEL = 'MSG_AT', COALESCE(b.BUTTON_CNT, 0), NULL) as BUTTON_CNT,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_MSG_TEMPLATE') }} t
left join btn b on t.SEND_CHANNEL = 'MSG_AT' and b.TMPLAT_ID = t.TEMPLATE_KEY
