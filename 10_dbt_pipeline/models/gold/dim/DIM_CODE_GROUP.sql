-- DIM_CODE_GROUP: 공통 코드그룹 차원 (CD_ID grain) — CRM_CODE_GROUP (+ 상세코드 수)
-- Co-authored with CoCo
-- 🆕 [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
{{ config(
    materialized='incremental',
    unique_key='CD_ID',
    tags=['gold_pending']
) }}

with dtl as (
    select CD_ID, COUNT(*) as DTL_CODE_CNT from {{ ref('CRM_CODE') }} group by 1
)
select
    g.CD_ID, g.CD_NM, g.CD_DC, g.SORT_ORDR, g.RM, g.USE_YN,
    COALESCE(d.DTL_CODE_CNT, 0) as DTL_CODE_CNT,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_CODE_GROUP') }} g
left join dtl d on d.CD_ID = g.CD_ID
