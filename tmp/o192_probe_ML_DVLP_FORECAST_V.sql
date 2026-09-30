CREATE OR REPLACE VIEW SANDBOX.PUBLIC.P_ML_DVLP_FORECAST_V (
    SERIES_TYPE COMMENT '계열유형: TOTAL·CAMPAIGN — 🔴 유형 간 합산은 중복계상 · 항상 고정·그룹 (부서·후원사업·신규기존은 원천 삭제로 비활성)',
    SERIES_CD   COMMENT '계열코드(유형에 따라 캠페인 코드 / (전사))',
    SERIES_NAME COMMENT '계열명(마스터 조인 라벨 · 미매칭 NULL)',
    STDR_MT     COMMENT '예측 실행 기준월 YYYYMM [원천]',
    TS          COMMENT '예측월 시작일 [원천]',
    FORECAST    COMMENT '예측 개발금액 — 🔴 단위 만원(신규+증액+재후원) [원천]',
    LOWER_BOUND COMMENT '95% 신뢰구간 하한(만원)',
    UPPER_BOUND COMMENT '95% 신뢰구간 상한(만원)'
)
  COMMENT = 'ML 개발금액 예측 2종(전사·캠페인) 통합. 부서·후원사업·신규기존 예측은 원천 삭제로 제공하지 않음. grain=기준월×계열유형×계열×예측월. 단위=만원. 계열유형 간 합산은 중복계상이다. 예측치이며 실적이 아니다.'
AS SELECT NULL AS SERIES_TYPE, NULL AS SERIES_CD, NULL AS SERIES_NAME, NULL AS STDR_MT, NULL AS TS, NULL AS FORECAST, NULL AS LOWER_BOUND, NULL AS UPPER_BOUND