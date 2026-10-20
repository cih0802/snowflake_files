-- DIM_BIZ_PLACE: 결연 사업장 차원 (BPLC_CD grain) — CRM_BIZ_PLACE
-- Co-authored with CoCo
-- 🆕 [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
{{ config(
    materialized='incremental',
    unique_key='BIZ_PLACE_SK',
    tags=['gold_pending']
) }}

select
    {{ gold_sk(['BPLC_CD']) }}     as BIZ_PLACE_SK,
    BPLC_CD, NATION_CD, BPLC_KORNM, BPLC_ENGNM,
    BSNS_STRT_DE, BSNS_END_DE, RELATNSP_BSNS_YN, RELATNSP_BSNS_DSCNTC_DE,
    GFTMNEY_PSBL_YN, LETTER_PSBL_YN, BPLC_DC, WTWK_FROM_DSTNC, CNCSN_RSN, BPLC_MTCHG_MNG_YN,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_BIZ_PLACE') }}
union all
-- unknown 멤버(SK=0): 아동 마스터의 사업장코드가 사업장 마스터에 없는 행(📏 3,821명) 조인 유실 방지
select 0, NULL, NULL, '(미매핑)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    {{ gold_meta('CRM') }}
