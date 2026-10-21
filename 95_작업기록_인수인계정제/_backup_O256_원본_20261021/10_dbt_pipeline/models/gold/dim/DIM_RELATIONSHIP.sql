-- DIM_RELATIONSHIP: 결연 차원 (1행 = 1결연 · RELATNSP_KEY) · 🆕 [2026-10-08 O213-F Y3-J]
-- Co-authored with CoCo
-- 왜 신설했나 — 결연 중단 여부·중단 사유가 SILVER.CRM_SPONSOR_RELATION 에만 있고 GOLD·SV 어디에도 없었다(O213 Y1 NONE).
--   GOLD 결연 3팩트(ACTIVITY·CHANGE·DEV)는 전부 사건 grain 이라 결연 상태를 담을 곳이 없다 ⇒ 결연 grain 차원 신설.
--   SV_RELATION_ACTIVITY 는 fra.RELATNSP_KEY → 이 차원으로 연결해 「중단된 결연의 서신·선물금」 같은 질문을 받는다.
-- 🔴 중단사유 라벨 = 코드군 MM002(후원사업취소사유) — 원천 명세가 아니라 **커버리지로 특정**했다
--    (실측 2026-10-08: MM002 676,396 / 676,399행 · 30코드 중 29 · 차순위 MM005 후원중단사유 605,671행).
--    라벨이 결연 종료 사유와 맞는다(후원중단·18세종결교체·아동퇴소교체 …). 🔴 현업 확인 대상 = 문서20 N-29 ⑦.
-- 🔴 RELATNSP_DSCNTC_YN 원값 = '0'/'1' 문자(1 = 중단) — 라벨을 만들지 않고 IS_DISCONTINUED(Y/N)로 파생만 한다.
{{ config(
    materialized='incremental',
    unique_key='RELATNSP_KEY',
    tags=['gold_ready']
) }}

with code as (
    select CD_ID, DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }}
)

select
    r.RELATNSP_KEY,
    r.MBER_NO                                  as MEMBER_DK,
    r.SPNSR_NO,
    r.SPNSR_BSNS_NO,
    r.CHILD_CD,
    r.RELATNSP_STRT_DE,
    r.RELATNSP_DSCNTC_DE,
    r.RELATNSP_DSCNTC_YN,
    IFF(r.RELATNSP_DSCNTC_YN = '1', 'Y', IFF(r.RELATNSP_DSCNTC_YN = '0', 'N', NULL)) as IS_DISCONTINUED,
    r.RELATNSP_DSCNTC_RSN_CD,
    rs.DTL_CD_NM                               as RELATNSP_DSCNTC_RSN_NAME,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_SPONSOR_RELATION') }} r
left join code rs on rs.CD_ID = 'MM002' and rs.DTL_CD_ID = r.RELATNSP_DSCNTC_RSN_CD
