-- WIDE_MBRFEE_PRDT_ACTL: 회원실 연간 회비 예측·실측 소비뷰 (O200-A 신설)
-- Co-authored with CoCo
-- 원천 = SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA(외부 적재 · 부서 자체 수식 · ML 산출물 아님).
-- 변환 = STDR_MT(TEXT) → MONTH_KEY·CAL_YEAR·CAL_MONTH 숫자 파생 · DATA_TYPE_NM → IS_FORECAST 플래그.
--   measure 23종은 이름·값 무변경(행 grain 유지 — 예측/실측을 열로 펼치면 46열이 되어 SV 가독성이 떨어진다).
-- grain = MONTH_KEY × DATA_TYPE_NM × SPNSR_BSNS_GRP_NM × NEW_EXST_DIV_NM × HDQ_BRNCH_GRP_NM.
-- 🔴 예측행과 실측행을 같은 합계에 섞지 말 것 — 반드시 DATA_TYPE_NM(또는 IS_FORECAST)으로 스코프한다.
{{ config(
    materialized='gn_view_commented'
) }}

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
from {{ source('silver_external', 'ANNUAL_MBRFEE_PRDT_ACTL_DATA') }}
