-- FACT_RELATION_ACTIVITY: 결연활동 팩트 (ACTIVITY_KEY grain = 1행/서신·선물금 활동) — CRM_RELATION_ACTIVITY × CRM_SPONSOR_RELATION
-- Co-authored with CoCo
-- 🆕 [2026-10-01 O196-D · DEC-58 #2] 신설 — O191-G 보류분 결연활동 12 의 GOLD 반영.
--   🟢 회원 = 결연키 → CRM_SPONSOR_RELATION(결연키당 회원 1명 실측) · 📏 매칭 실패 315행은 MEMBER_DK NULL(고아 결연 · 행은 보존).
--   🟢 사건일 = 서신 접수일(RCEPT_DE) · 선물금은 원천에 접수일이 없어 발송일(SNDNG_DE) — FMD followup 과 같은 규칙.
--   🔴 measure = ACTIVITY_CNT(건) · GFTMNEY(원 · 선물금 행만). 회원수는 MEMBER_DK 중복제거로 센다(합산 금지).
{{ config(
    tags=['gold_pending']
) }}

with rel as (
    select RELATNSP_KEY, MBER_NO
    from {{ ref('CRM_SPONSOR_RELATION') }}
    qualify row_number() over (partition by RELATNSP_KEY order by MBER_NO) = 1
)
select
    COALESCE({{ date_sk("(CASE WHEN a.ACTIVITY_TYPE = '서신' THEN a.RCEPT_DE ELSE a.SNDNG_DE END)") }}, 0) as DATE_SK,
    r.MBER_NO                                  as MEMBER_DK,
    a.ACTIVITY_KEY, a.ACTIVITY_TYPE, a.RELATNSP_KEY, a.MNG_NO,
    1                                          as ACTIVITY_CNT,
    a.GFTMNEY, a.LETTER_DIV_CD, a.RCEPT_DE, a.SNDNG_DE,
    -- 결연활동 12 (SILVER 2차-B · 서신 계열 5 · 선물금 계열 7 · 미답신사유는 양쪽 원천 · 비해당 NULL)
    a.LETTER_STAT_CD, a.LANG_CD, a.ONLINE_POST_WRITNG_YN, a.ONLINE_INFLOW_CD, a.UNREPLY_RSN_CD,
    a.MBRFEE_KEY, a.SETLE_DE, a.SETLE_CD, a.GFT_DIV_CD, a.GFTMNEY_DOLLAR_AMT, a.APRV_DE, a.TRNSFER_YN,
    {{ gold_meta('CRM') }},
    -- 🆕 [2026-10-08 O213-F Y3-J] 선물금 정산은행 — 코드군 PM039(자동이체 은행코드 · 커버리지 143,866/144,232 실측) · 서신 행 NULL(개념 없음)
    a.SETLE_BANK_CD,
    bk.DTL_CD_NM                               as SETLE_BANK_NAME
from {{ ref('CRM_RELATION_ACTIVITY') }} a
left join rel r on r.RELATNSP_KEY = a.RELATNSP_KEY
left join {{ ref('CRM_CODE') }} bk on bk.CD_ID = 'PM039' and bk.DTL_CD_ID = a.SETLE_BANK_CD
