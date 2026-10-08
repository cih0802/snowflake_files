create or replace view WIDE_SPNSR_CLS_AGGR(
	MONTH_KEY COMMENT '기준월 YYYYMM ← STDR_MT',
	CAL_YEAR COMMENT '연도 ← STDR_MT 앞 4자리',
	CAL_MONTH COMMENT '월(1~12) ← STDR_MT 뒤 2자리',
	AGGR_TY_NM COMMENT '집계 유형명(감액/개발/중단/활동/회비)',
	CPR_NM COMMENT '법인명',
	SPNSR_BSNS_GRP_NM COMMENT '후원 사업 그룹 명',
	NEW_EXST_DIV_NM COMMENT '신규기존구분명',
	HDQ_BRNCH_GRP_NM COMMENT '본부 지부 그룹 명',
	VALUE1 COMMENT '후원분류집계 예측값1 (명칭 = 원천 SILVER 테이블명 유래 · 현업 회신)',
	VALUE2 COMMENT '후원분류집계 예측값2 (명칭 = 원천 SILVER 테이블명 유래 · 현업 회신 · 회비 유형에만 값이 있고 나머지 유형은 NULL)'
) COMMENT='회원실 회비예측 월간 후원 분류별 집계(월 grain). 원천 = SILVER.MM_SPNSR_CLS_AGGR_DATA(부서 자체 수식 · ML 예측 아님). AGGR_TY_NM(감액/개발/중단/활동/회비)마다 VALUE1·VALUE2 의 뜻이 다를 수 있다 — 서로 다른 집계 유형을 합산하지 말 것. VALUE1·VALUE2 = 후원분류집계 예측값1·2 — 원천 SILVER 테이블명(회원실 회비예측 월간 후원 분류별 집계)에서 유래한 명칭이다(현업 회신 2026-10-03 · O200-D). 예측값2 는 회비 유형에만 값이 있다.'
 as (
      -- WIDE_SPNSR_CLS_AGGR: 회원실 회비예측 월간 후원 분류별 집계 소비뷰 (O200-A 신설)
-- Co-authored with CoCo
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
    );