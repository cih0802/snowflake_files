-- FACT_RELATION_CHANGE: 결연 교체 팩트 (RELATNSP_KEY grain) — CRM_RELATION_CHANGE × CRM_SPONSOR_RELATION
-- Co-authored with CoCo
-- 🆕 [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
-- 🟢 회원 = 결연키 → CRM_SPONSOR_RELATION(키 유일 실측) · 📏 매칭 실패 32행은 MEMBER_DK NULL(고아 결연 · 행은 보존).
{{ config(
    tags=['gold_pending']
) }}

with rel as (
    select RELATNSP_KEY, MBER_NO
    from {{ ref('CRM_SPONSOR_RELATION') }}
    qualify row_number() over (partition by RELATNSP_KEY order by MBER_NO) = 1
)
select
    COALESCE({{ date_sk('c.CHG_DE') }}, 0)       as DATE_SK,
    r.MBER_NO                                  as MEMBER_DK,
    c.RELATNSP_KEY, c.CHG_RELATNSP_KEY,
    c.CHG_YN, c.CHG_RSN_CD, c.CHG_RST_CD, c.CHG_PERSON_ID, c.CHG_DE,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_RELATION_CHANGE') }} c
left join rel r on r.RELATNSP_KEY = c.RELATNSP_KEY
