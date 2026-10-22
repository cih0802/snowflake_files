-- =============================================================================
-- Purpose    : 회원실 연간 회비 예측·실측 소비뷰 (O200-A 신설)
-- Target     : GOLD.WIDE_MBRFEE_PRDT_ACTL (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : source silver_external.ANNUAL_MBRFEE_PRDT_ACTL_DATA
-- Issue      : O200-A
-- =============================================================================
-- WIDE_MBRFEE_PRDT_ACTL: 회원실 연간 회비 예측·실측 소비뷰 (O200-A 신설)
-- 원천 = SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA(외부 적재 · 부서 자체 수식 · ML 산출물 아님).
-- 변환 = STDR_MT(TEXT) → MONTH_KEY·CAL_YEAR·CAL_MONTH 숫자 파생 · DATA_TYPE_NM → IS_FORECAST 플래그.
--   measure 23종은 이름·값 무변경(행 grain 유지 — 예측/실측을 열로 펼치면 46열이 되어 SV 가독성이 떨어진다).
-- grain = MONTH_KEY × DATA_TYPE_NM × SPNSR_BSNS_GRP_NM × NEW_EXST_DIV_NM × HDQ_BRNCH_GRP_NM.
-- WARN: 예측행과 실측행을 같은 합계에 섞지 말 것 — 반드시 DATA_TYPE_NM(또는 IS_FORECAST)으로 스코프한다.
-- [2026-10-22] 원천 구분값 3종 = 예측 · 실적 · 연도초예측(현업 회신). 원천 라벨이 수기라 문구가 바뀐다
--   (운영계 실측 '연초예측' 528행 → 현업 예고 '연도초예측'). 종전 `DATA_TYPE_NM = '예측'` 하드코딩은
--   라벨이 바뀌자 예측 528행을 IS_FORECAST=FALSE(=실측 취급)로 조용히 오분류했다.
--   ⇒ 라벨 → 표준값 매핑을 이 CASE 한 곳에 둔다. 원천 라벨 추가·개명 시 여기만 고친다.
--   WARN: 연도초예측은 일반 예측과 **다른 계열**이다 — 같은 STD 로 합치지 않는다(「예측」 질문에 섞이면 이중계상).
--   WARN: 매핑에 없는 라벨은 NULL(=모른다) — 실적·예측 어느 쪽으로도 추정하지 않는다. 테스트 warn 으로 드러난다.


select
    TO_NUMBER(STDR_MT)                 as MONTH_KEY,
    FLOOR(TO_NUMBER(STDR_MT) / 100)    as CAL_YEAR,
    MOD(TO_NUMBER(STDR_MT), 100)       as CAL_MONTH,
    DATA_TYPE_NM,
    case TRIM(DATA_TYPE_NM)
        when '예측'       then '예측'
        when '실적'       then '실적'
        when '연도초예측' then '연도초예측'
        when '연초예측'   then '연도초예측'    -- 현행 원천 라벨(개명 예고 · 2026-10-22)
    end                                as DATA_TYPE_STD,
    case TRIM(DATA_TYPE_NM)
        when '예측'       then TRUE
        when '실적'       then FALSE
        when '연도초예측' then FALSE
        when '연초예측'   then FALSE
    end                                as IS_FORECAST,
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