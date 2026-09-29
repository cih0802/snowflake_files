-- DIM_MEMBER: 정규 회원 마스터 차원 (회원 1명 = 1행, IS_CURRENT=TRUE 투영) — 분석가 및 Cortex Analyst 기본 진입점
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook='TRUNCATE TABLE IF EXISTS {{ this }}',
    tags=['gold_ready']
) }}

select
    h.MEMBER_SK,
    h.MEMBER_DK,
    h.MEMBER_TYPE,
    h.SEX,
    h.SEX_NM,
    h.GENDER_NAME,
    h.MBER_STAT_CD,
    h.MEMBER_STATUS_NAME,
    h.MEMBER_STATUS_GROUP,
    h.MBER_DIV_CD,
    h.MEMBER_TYPE_NAME,
    h.JOIN_PATH_CD,
    h.ENROLL_PATH_NAME,
    h.FIRST_JOIN_DATE,
    h.FIRST_CAMPAIGN,
    h.REGION,
    h.AGE_BAND,
    h.FIRST_SPONSORSHIP,
    h.LAST_STOP_DATE,
    h.EFFECTIVE_FROM,
    h.DW_SOURCE_SYSTEM,
    h.DW_LOAD_TS,
    h.DW_UPDATE_TS,
    h.DW_BATCH_ID,
    -- 🆕 [2026-09-29 O188-F] 가입캠페인(CRM_MEMBER.CMPGN_CD)의 공통브랜드(MM297) — 「공통브랜드 기준 가입경로」.
    --   🟢 SILVER 에서 직접 조인한다 — DIM_MEMBER_ACQUISITION(FME→COHORT 경유)을 참조하면 의존이 길어지고
    --      순환 위험이 생긴다. 📏 xf98254 = 1,606,883명 채움 · 획득 차원 ACQ_CMMN_BRND_NM 과 99.73% 일치
    --      (불일치 = 가입캠페인 ≠ 최초개발캠페인 회원 · 둘은 다른 정의다).
    c.CMMN_BRND                                   as JOIN_CMMN_BRND,
    c.CMMN_BRND_NM                                as JOIN_CMMN_BRND_NM
from {{ ref('DIM_MEMBER_STATUS_HISTORY') }} h
left join {{ ref('CRM_MEMBER') }}   m on m.MEMBER_DK = h.MEMBER_DK
left join {{ ref('CRM_CAMPAIGN') }} c on c.CMPGN_CD  = m.CMPGN_CD
where h.IS_CURRENT
