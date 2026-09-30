CREATE OR REPLACE VIEW SANDBOX.PUBLIC.P_ML_LTV_FORECAST_V (
    LTV_TYPE      COMMENT 'LTV유형: UCMPGN_AVG_MEMBER(상위캠페인 회원평균) · CMPGN_TOTAL(일반캠페인 후원총액) — 🔴 하나로 고정',
    LTV_TYPE_NAME COMMENT 'LTV유형 라벨',
    SERIES_CD     COMMENT '계열 캠페인코드(유형별 상위캠페인 / 일반캠페인)',
    SERIES_NAME   COMMENT '계열 캠페인명(캠페인 마스터) — 미매칭 NULL',
    STDR_MT       COMMENT '예측 실행 기준월 YYYYMM',
    TS            COMMENT '예측월 시작일',
    FORECAST      COMMENT 'LTV 예측값(원) — 회원평균 유형은 합산 금지',
    LOWER_BOUND   COMMENT '95% 신뢰구간 하한(원)',
    UPPER_BOUND   COMMENT '95% 신뢰구간 상한(원)'
)
  COMMENT = 'ML LTV 월별 예측 2종. UCMPGN=상위캠페인 회원평균 LTV · CMPGN=일반캠페인 후원총액 LTV. 두 유형은 계열축과 의미가 달라 합산·비교할 수 없다. 단위=원. 예측치이며 실적이 아니다.'
AS SELECT NULL AS LTV_TYPE, NULL AS LTV_TYPE_NAME, NULL AS SERIES_CD, NULL AS SERIES_NAME, NULL AS STDR_MT, NULL AS TS, NULL AS FORECAST, NULL AS LOWER_BOUND, NULL AS UPPER_BOUND