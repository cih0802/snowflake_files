-- FACT_RELATION_DEV: 결연 개발금액 사건 팩트 (발생일 × 일련번호 grain) — CRM_RELATION_DEV
-- Co-authored with CoCo
-- 🆕 [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
-- ⚠️ 상태 코드는 코드군 미확정 ⇒ raw degen. 후원사업 SK 는 SPNSR_BSNS_NO 가 사업 마스터 키가 아니라 두지 않는다(degen 유지).
{{ config(
    tags=['gold_pending']
) }}

select
    COALESCE({{ date_sk("TRY_TO_DATE(OCCRRNC_DE, 'YYYYMMDD')") }}, 0) as DATE_SK,
    MBER_NO                                    as MEMBER_DK,
    OCCRRNC_DE, SER_NO, SPNSR_NO, SPNSR_BSNS_NO,
    SPNSR_AMT,
    BF_STAT_CD, AF_STAT_CD, RELATNSP_DVLP_DIV_CD, ACCNUT_STATS_CD, CHILD_STATS_CD,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_RELATION_DEV') }}
