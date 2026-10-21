-- =============================================================================
-- Purpose    : 회원실 회비예측 월간 후원 분류별 집계 소비뷰 (O200-A 신설)
-- Target     : GOLD.WIDE_SPNSR_CLS_AGGR (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : source silver_external.MM_SPNSR_CLS_AGGR_DATA
-- Issue      : O200-A, O200-D
-- =============================================================================
-- WIDE_SPNSR_CLS_AGGR: 회원실 회비예측 월간 후원 분류별 집계 소비뷰 (O200-A 신설)
-- 원천 = SILVER.MM_SPNSR_CLS_AGGR_DATA(외부 적재 · 부서 자체 수식 · ML 산출물 아님).
-- 변환 = STDR_MT(TEXT) → MONTH_KEY·CAL_YEAR·CAL_MONTH 숫자 파생 · 나머지 무변경.
-- grain = MONTH_KEY × AGGR_TY_NM × CPR_NM × SPNSR_BSNS_GRP_NM × NEW_EXST_DIV_NM × HDQ_BRNCH_GRP_NM.
-- VALUE1·VALUE2 COMMENT = 「후원분류집계 예측값1/2」 — 원천 SILVER 테이블명 유래(현업 회신 2026-10-03 · O200-D).


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
from GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
-- [2026-10-16 grain 보정 · 사용자 결정] 수기 업로드 문서라 같은 grain 에 값이 다른 행이 섞인다( 970행 / 511키).
--   예측값이라 정밀도 요구가 낮다 ⇒ 큰 값 1건을 유지한다. 중복 발생은 tests/warn_spnsr_cls_aggr_src_dup.sql
--   (store_failures → OPS) 가 기록하고 담당자 메일 알림의 근거가 된다.
qualify ROW_NUMBER() over (
    partition by STDR_MT, AGGR_TY_NM, CPR_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM
    order by VALUE1 desc nulls last, VALUE2 desc nulls last
) = 1