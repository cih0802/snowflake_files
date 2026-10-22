create or replace view GN_DW.GOLD.WIDE_MBRFEE_PRDT_ACTL
    (
      MONTH_KEY COMMENT $$기준월 YYYYMM ← STDR_MT$$,
      CAL_YEAR COMMENT $$연도 ← STDR_MT 앞 4자리$$,
      CAL_MONTH COMMENT $$월(1~12) ← STDR_MT 뒤 2자리$$,
      DATA_TYPE_NM COMMENT $$예측 실적 구분 원천 라벨 raw(현업 수기 · 문구가 바뀔 수 있다). 🔴 필터·집계에는 DATA_TYPE_STD 를 쓴다 — 원천 라벨로 고정하면 라벨 개명 시 0행이 된다.$$,
      DATA_TYPE_STD COMMENT $$구분 표준값 3종: '예측'(일반 예측) · '연도초예측'(연도초 시점 예측 · 원천 라벨 '연초예측' 포함) · '실적'. 🔴🔴 '예측'과 '연도초예측'은 **서로 다른 계열**이다 — 「예측」 질문은 '예측' 하나로 고정하고, 연도초예측은 명시적으로 물을 때만 쓴다. 둘을 합산하지 않는다. NULL = 매핑에 없는 원천 라벨(분류 불가 · 추정 금지).$$,
      IS_FORECAST COMMENT $$일반 예측행 여부 ← DATA_TYPE_STD='예측'. 🔴 연도초예측은 FALSE 다(별도 계열) — 실적 여부로 쓰지 말 것(실적 = DATA_TYPE_STD='실적'). NULL = 분류 불가 라벨.$$,
      SPNSR_BSNS_GRP_NM COMMENT $$후원 사업 그룹 명$$,
      NEW_EXST_DIV_NM COMMENT $$신규기존구분명$$,
      HDQ_BRNCH_GRP_NM COMMENT $$본부 지부 그룹 명$$,
      DVLP_CNT COMMENT $$개발건수$$,
      CMLT_DVLP_CNT COMMENT $$누적개발건수$$,
      ADJ_DSCNTC_RT COMMENT $$[비가산] 조정 중단율$$,
      ADJ_DSCNTC_CNT COMMENT $$조정 중단건수$$,
      ADJ_RDCAMT_RT COMMENT $$[비가산] 조정 감액율$$,
      ADJ_RDCAMT_CNT COMMENT $$조정 감액건수$$,
      ADJ_RECALC_DSCNTC_RT COMMENT $$[비가산] 조정 재산출 중단율$$,
      ADJ_DSCNTC_CNT2 COMMENT $$조정 중단건수2$$,
      ADJ_CMLT_DSCNTC_CNT COMMENT $$조정 누계 중단건수$$,
      DSCNTC_RT COMMENT $$[비가산] 중단율$$,
      DSCNTC_CNT COMMENT $$중단건수$$,
      RDCAMT_RT COMMENT $$[비가산] 감액율$$,
      SPNSR_BSNS_CHN_DEC_CNT COMMENT $$후원사업변경감소건수$$,
      RDCAMT_CNT COMMENT $$감액 건수2$$,
      CMLT_EOM_ACT_MBER_CNT COMMENT $$누적 월말활동회원건수$$,
      CMLT_ACT_MBER_CNT COMMENT $$누적 활동회원건수$$,
      ACT_RT COMMENT $$[비가산] 활동율$$,
      ADJ_MT_PAY_RT COMMENT $$[비가산] 조정 월납입율$$,
      ADJ_MBRFEE_AMT COMMENT $$조정 회비$$,
      ADJ_CMLT_PAY_RT COMMENT $$[비가산] 조정 누계납입율$$,
      ADJ_CMLT_MBRFEE_AMT COMMENT $$조정 누계회비$$,
      CMLT_PAY_RT COMMENT $$[비가산] 누계납입율$$,
      CMLT_MBRFEE_AMT COMMENT $$누적 회비$$,
      MBRFEE_DIFF_AMT COMMENT $$회비 차액$$
    )
    comment = $$회원실 연간 회비 예측·실측(월 grain). 원천 = SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA(부서 자체 수식 · ML 예측 아님). 🔴 예측행·연도초예측행·실적행이 한 뷰에 함께 있다 — 합계·평균 전에 반드시 DATA_TYPE_STD 로 스코프할 것(예측과 연도초예측도 서로 합산 금지). 율(_RT) 컬럼은 비가산이다 — 합산하지 말 것.$$
    as (
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
    );