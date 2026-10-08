create or replace view WIDE_MBRFEE_PRDT_ACTL(
	MONTH_KEY COMMENT '기준월 YYYYMM ← STDR_MT',
	CAL_YEAR COMMENT '연도 ← STDR_MT 앞 4자리',
	CAL_MONTH COMMENT '월(1~12) ← STDR_MT 뒤 2자리',
	DATA_TYPE_NM COMMENT '예측 실측 구분 명(예측/실측)',
	IS_FORECAST COMMENT '예측행 여부 ← DATA_TYPE_NM=''예측''',
	SPNSR_BSNS_GRP_NM COMMENT '후원 사업 그룹 명',
	NEW_EXST_DIV_NM COMMENT '신규기존구분명',
	HDQ_BRNCH_GRP_NM COMMENT '본부 지부 그룹 명',
	DVLP_CNT COMMENT '개발건수',
	CMLT_DVLP_CNT COMMENT '누적개발건수',
	ADJ_DSCNTC_RT COMMENT '[비가산] 조정 중단율',
	ADJ_DSCNTC_CNT COMMENT '조정 중단건수',
	ADJ_RDCAMT_RT COMMENT '[비가산] 조정 감액율',
	ADJ_RDCAMT_CNT COMMENT '조정 감액건수',
	ADJ_RECALC_DSCNTC_RT COMMENT '[비가산] 조정 재산출 중단율',
	ADJ_DSCNTC_CNT2 COMMENT '조정 중단건수2',
	ADJ_CMLT_DSCNTC_CNT COMMENT '조정 누계 중단건수',
	DSCNTC_RT COMMENT '[비가산] 중단율',
	DSCNTC_CNT COMMENT '중단건수',
	RDCAMT_RT COMMENT '[비가산] 감액율',
	SPNSR_BSNS_CHN_DEC_CNT COMMENT '후원사업변경감소건수',
	RDCAMT_CNT COMMENT '감액 건수2',
	CMLT_EOM_ACT_MBER_CNT COMMENT '누적 월말활동회원건수',
	CMLT_ACT_MBER_CNT COMMENT '누적 활동회원건수',
	ACT_RT COMMENT '[비가산] 활동율',
	ADJ_MT_PAY_RT COMMENT '[비가산] 조정 월납입율',
	ADJ_MBRFEE_AMT COMMENT '조정 회비',
	ADJ_CMLT_PAY_RT COMMENT '[비가산] 조정 누계납입율',
	ADJ_CMLT_MBRFEE_AMT COMMENT '조정 누계회비',
	CMLT_PAY_RT COMMENT '[비가산] 누계납입율',
	CMLT_MBRFEE_AMT COMMENT '누적 회비',
	MBRFEE_DIFF_AMT COMMENT '회비 차액'
) COMMENT='회원실 연간 회비 예측·실측(월 grain). 원천 = SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA(부서 자체 수식 · ML 예측 아님). 🔴 예측행과 실측행이 한 뷰에 함께 있다 — 합계·평균 전에 반드시 DATA_TYPE_NM(또는 IS_FORECAST)으로 스코프할 것. 율(_RT) 컬럼은 비가산이다 — 합산하지 말 것.'
 as (
      -- WIDE_MBRFEE_PRDT_ACTL: 회원실 연간 회비 예측·실측 소비뷰 (O200-A 신설)
-- Co-authored with CoCo
-- 원천 = SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA(외부 적재 · 부서 자체 수식 · ML 산출물 아님).
-- 변환 = STDR_MT(TEXT) → MONTH_KEY·CAL_YEAR·CAL_MONTH 숫자 파생 · DATA_TYPE_NM → IS_FORECAST 플래그.
--   measure 23종은 이름·값 무변경(행 grain 유지 — 예측/실측을 열로 펼치면 46열이 되어 SV 가독성이 떨어진다).
-- grain = MONTH_KEY × DATA_TYPE_NM × SPNSR_BSNS_GRP_NM × NEW_EXST_DIV_NM × HDQ_BRNCH_GRP_NM.
-- 🔴 예측행과 실측행을 같은 합계에 섞지 말 것 — 반드시 DATA_TYPE_NM(또는 IS_FORECAST)으로 스코프한다.


select
    TO_NUMBER(STDR_MT)                 as MONTH_KEY,
    FLOOR(TO_NUMBER(STDR_MT) / 100)    as CAL_YEAR,
    MOD(TO_NUMBER(STDR_MT), 100)       as CAL_MONTH,
    DATA_TYPE_NM,
    DATA_TYPE_NM = '예측'              as IS_FORECAST,
    SPNSR_BSNS_GRP_NM,
    NEW_EXST_DIV_NM,
    HDQ_BRNCH_GRP_NM,
    DVLP_CNT,
    CMLT_DVLP_CNT,
    ADJ_DSCNTC_RT,
    ADJ_DSCNTC_CNT,
    ADJ_RDCAMT_RT,
    ADJ_RDCAMT_CNT,
    ADJ_RECALC_DSCNTC_RT,
    ADJ_DSCNTC_CNT2,
    ADJ_CMLT_DSCNTC_CNT,
    DSCNTC_RT,
    DSCNTC_CNT,
    RDCAMT_RT,
    SPNSR_BSNS_CHN_DEC_CNT,
    RDCAMT_CNT,
    CMLT_EOM_ACT_MBER_CNT,
    CMLT_ACT_MBER_CNT,
    ACT_RT,
    ADJ_MT_PAY_RT,
    ADJ_MBRFEE_AMT,
    ADJ_CMLT_PAY_RT,
    ADJ_CMLT_MBRFEE_AMT,
    CMLT_PAY_RT,
    CMLT_MBRFEE_AMT,
    MBRFEE_DIFF_AMT
from GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA
    );