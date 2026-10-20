-- DIM_CHILD: 결연 아동 차원 (CHILD_CD grain) — CRM_CHILD × DIM_BIZ_PLACE
-- Co-authored with CoCo
-- 🆕 [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
-- ⚠️ 상태 코드(RELATNSP_STAT_CD·CHILD_STAT_CD·CHILD_DTL_STAT_CD·REGIST_DIV_CD)는 코드군 미확정 ⇒ raw 유지(라벨 창작 금지).
{{ config(
    materialized='incremental',
    unique_key='CHILD_SK',
    tags=['gold_pending']
) }}

select
    {{ gold_sk(['c.CHILD_CD']) }}             as CHILD_SK,
    c.CHILD_CD, c.CHILD_NO, c.CMS_CHILD_NO,
    COALESCE(b.BIZ_PLACE_SK, 0)              as BIZ_PLACE_SK,
    c.BPLC_CD, c.MNYRS_NATION_CD, c.SEX,
    c.RELATNSP_STAT_CD, c.CHILD_STAT_CD, c.CHILD_DTL_STAT_CD, c.REGIST_DIV_CD,
    c.FRST_REGIST_DT, c.LAST_REGIST_DT, c.RE_UPDT_DT,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_CHILD') }} c
left join {{ ref('DIM_BIZ_PLACE') }} b on b.BPLC_CD = c.BPLC_CD
