CREATE OR REPLACE VIEW SANDBOX.PUBLIC.P_ML_LTV_SCORE_V (
    LTV_TYPE             COMMENT 'LTV유형: UCMPGN_AVG_MEMBER · CMPGN_TOTAL — 🔴 하나로 고정',
    LTV_TYPE_NAME        COMMENT 'LTV유형 라벨',
    SERIES_CD            COMMENT '계열 캠페인코드',
    SERIES_NAME          COMMENT '계열 캠페인명(캠페인 마스터) — 미매칭 NULL',
    STDR_MT              COMMENT '예측 실행 기준월 YYYYMM [원천]',
    HIST_TOTAL_AMT       COMMENT '과거 누적 금액 합계(원 · 학습 기간 전체) [원천]',
    FUTURE_TOTAL_AMT     COMMENT '향후 12개월 예측 금액 합계(원) [원천]',
    LTV                  COMMENT '장기가치 = 과거 누적 + 향후 예측(원) [원천]',
    AVG_MONTHLY_FORECAST COMMENT '향후 월평균 예측 금액(원) [원천]',
    AVG_MONTHLY_ACTUAL   COMMENT '과거 월평균 실제 금액(원) — 산출 맥락값이며 실적 정본 아님 [원천]',
    ACTIVE_MONTHS        COMMENT '과거 활성 월수 [원천]'
)
  COMMENT = 'ML LTV 스코어 2종(계열당 1행). UCMPGN=상위캠페인 · CMPGN=일반캠페인. 월별 예측 뷰와 grain 이 달라 합산하지 않는다. 단위=원. 예측치이며 실적이 아니다.'
AS SELECT NULL AS LTV_TYPE, NULL AS LTV_TYPE_NAME, NULL AS SERIES_CD, NULL AS SERIES_NAME, NULL AS STDR_MT, NULL AS HIST_TOTAL_AMT, NULL AS FUTURE_TOTAL_AMT, NULL AS LTV, NULL AS AVG_MONTHLY_FORECAST, NULL AS AVG_MONTHLY_ACTUAL, NULL AS ACTIVE_MONTHS