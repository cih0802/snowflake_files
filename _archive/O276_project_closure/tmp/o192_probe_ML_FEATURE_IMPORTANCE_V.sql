CREATE OR REPLACE VIEW SANDBOX.PUBLIC.P_ML_FEATURE_IMPORTANCE_V (
    ANALYSIS_TYPE      COMMENT '분석유형: CHANNEL_NEW_SPNSR · DVLP_INC — 🔴 하나로 고정(유형 내 합계=1)',
    ANALYSIS_TYPE_NAME COMMENT '분석유형 라벨',
    STDR_MT            COMMENT '분석 실행 기준월 YYYYMM [원천]',
    RANK               COMMENT '피처 중요도 순위 [원천]',
    FEATURE            COMMENT '피처명(사람이 지정한 후보) [원천]',
    SCORE              COMMENT '피처 중요도 0~1(유형 내 합계=1) — 금액·건수 아님 · 인과 아님 [원천]',
    FEATURE_TYPE       COMMENT '피처 유형(user_provided = 사람이 지정) [원천]'
)
  COMMENT = 'ML 요인분석(피처 중요도) 2종. grain=기준월×분석유형×피처. 값은 0~1 기여도이며 금액·건수가 아니다(분석유형 내 합계=1). 모델 설명이며 업무 실적이 아니다.'
AS SELECT NULL AS ANALYSIS_TYPE, NULL AS ANALYSIS_TYPE_NAME, NULL AS STDR_MT, NULL AS RANK, NULL AS FEATURE, NULL AS SCORE, NULL AS FEATURE_TYPE