-- WIDE_SPNSR_CLS_AGGR: 회원실 회비예측 월간 후원 분류별 집계 소비뷰 (O200-A 신설)
-- Co-authored with CoCo
-- 원천 = SILVER.MM_SPNSR_CLS_AGGR_DATA(외부 적재 · 부서 자체 수식 · ML 산출물 아님).
-- 변환 = STDR_MT(TEXT) → MONTH_KEY·CAL_YEAR·CAL_MONTH 숫자 파생 · 나머지 무변경.
-- grain = MONTH_KEY × AGGR_TY_NM × CPR_NM × SPNSR_BSNS_GRP_NM × NEW_EXST_DIV_NM × HDQ_BRNCH_GRP_NM.
-- VALUE1·VALUE2 COMMENT = 「후원분류집계 예측값1/2」 — 원천 SILVER 테이블명 유래(현업 회신 2026-10-03 · O200-D).
{{ config(
    materialized='gn_view_commented'
) }}

select
    TO_NUMBER(STDR_MT)                 as MONTH_KEY,
    FLOOR(TO_NUMBER(STDR_MT) / 100)    as CAL_YEAR,
    MOD(TO_NUMBER(STDR_MT), 100)       as CAL_MONTH,
    AGGR_TY_NM,
    CPR_NM,
    SPNSR_BSNS_GRP_NM,
    NEW_EXST_DIV_NM,
    HDQ_BRNCH_GRP_NM,
    VALUE1,
    VALUE2
from {{ source('silver_external', 'MM_SPNSR_CLS_AGGR_DATA') }}
