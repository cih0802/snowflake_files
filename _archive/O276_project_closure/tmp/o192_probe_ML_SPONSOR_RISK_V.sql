CREATE OR REPLACE VIEW SANDBOX.PUBLIC.P_ML_SPONSOR_RISK_V (
    STDR_MT              COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
    STDR_MONTH_KEY       COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
    MBER_NO              COMMENT '회원번호 — 회원수는 COUNT(DISTINCT) 로 센다(후원건 grain)',
    SPNSR_BSNS_ID        COMMENT '후원사업ID [원천]',
    SPNSR_BSNS_NAME      COMMENT '후원사업명(SILVER.CRM_SPONSORSHIP) — 미매칭 NULL',
    SPNSR_BSNS_NO        COMMENT '후원사업번호(약정) [원천]',
    CMPGN_CD             COMMENT '캠페인코드 [원천]',
    CMPGN_NAME           COMMENT '캠페인명(SILVER.CRM_CAMPAIGN) — 미매칭 NULL',
    UPPER_CMPGN_CD       COMMENT '상위캠페인코드(캠페인 마스터)',
    UPPER_CMPGN_NAME     COMMENT '상위캠페인명(캠페인 마스터 자기조인)',
    CMPGN_CTGR_NAME      COMMENT '캠페인카테고리명(캠페인 마스터)',
    SETLE_CD             COMMENT '결제수단코드(PM040) — 라벨 미배선',
    TENURE_MONTHS        COMMENT '후원 유지기간(월) [원천]',
    STDR_MT_SPNSR_AMT    COMMENT '기준월 후원금액(원) [원천]',
    CHN_CNT              COMMENT '변경 건수 [원천]',
    INC_CNT              COMMENT '증액 건수 [원천]',
    DEC_CNT              COMMENT '감액 건수 [원천]',
    RE_CNT               COMMENT '재후원 건수 [원천]',
    CANCL_CNT            COMMENT '해지 건수 [원천]',
    PAY_RATE             COMMENT '납입 성공률 [원천]',
    CHURN_PROB           COMMENT '후원건 이탈 예측 확률(0~1) · 예측 지평 미발행',
    CHURN_CLASS          COMMENT '이탈 예측 분류(모델 class) — 업무 판정선 아님',
    PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICTION:logs:Error 비어있지 않음)',
    CHURN_GRADE          COMMENT '후원건 이탈위험 등급(F-4 · O190) — 기준월 내 후원건 백분위: 상위 5% 고위험 · 5~25% 주의 · 나머지 일반. 🔴 확률 임계가 아니라 순위다'
)
  COMMENT = 'ML 후원건단위 이탈 예측. grain=기준월×회원×후원사업ID×후원사업번호(실측 유일). 회원수는 반드시 중복제거로 센다. 예측치이며 실적이 아니다.'
AS SELECT NULL AS STDR_MT, NULL AS STDR_MONTH_KEY, NULL AS MBER_NO, NULL AS SPNSR_BSNS_ID, NULL AS SPNSR_BSNS_NAME, NULL AS SPNSR_BSNS_NO, NULL AS CMPGN_CD, NULL AS CMPGN_NAME, NULL AS UPPER_CMPGN_CD, NULL AS UPPER_CMPGN_NAME, NULL AS CMPGN_CTGR_NAME, NULL AS SETLE_CD, NULL AS TENURE_MONTHS, NULL AS STDR_MT_SPNSR_AMT, NULL AS CHN_CNT, NULL AS INC_CNT, NULL AS DEC_CNT, NULL AS RE_CNT, NULL AS CANCL_CNT, NULL AS PAY_RATE, NULL AS CHURN_PROB, NULL AS CHURN_CLASS, NULL AS PREDICTION_HAS_ERROR, NULL AS CHURN_GRADE