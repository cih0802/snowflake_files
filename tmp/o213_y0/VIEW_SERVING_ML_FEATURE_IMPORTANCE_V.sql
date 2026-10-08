create or replace view ML_FEATURE_IMPORTANCE_V(
	ANALYSIS_TYPE COMMENT '분석유형: CHANNEL_NEW_SPNSR · DVLP_INC — 🔴 하나로 고정(유형 내 합계=1)',
	ANALYSIS_TYPE_NAME COMMENT '분석유형 라벨',
	STDR_MT COMMENT '분석 실행 기준월 YYYYMM [원천]',
	RANK COMMENT '피처 중요도 순위 [원천]',
	FEATURE COMMENT '피처명(사람이 지정한 후보) [원천]',
	SCORE COMMENT '피처 중요도 0~1(유형 내 합계=1) — 금액·건수 아님 · 인과 아님 [원천]',
	FEATURE_TYPE COMMENT '피처 유형(user_provided = 사람이 지정) [원천] — CHANNEL_NEW_SPNSR 는 원천 컬럼 제거로 NULL'
) COMMENT='ML 요인분석(피처 중요도) 2종. grain=기준월×분석유형×피처. 값은 0~1 기여도이며 금액·건수가 아니다(분석유형 내 합계=1). 모델 설명이며 업무 실적이 아니다.'
 as
SELECT 'CHANNEL_NEW_SPNSR'          AS ANALYSIS_TYPE,
       '신규 후원 유치 요인'          AS ANALYSIS_TYPE_NAME,
       a.STDR_MT, a.RANK, a.FEATURE, a.SCORE,
       NULL::VARCHAR                 AS FEATURE_TYPE
FROM GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION a
UNION ALL
SELECT 'DVLP_INC',
       '증액 개발 요인',
       b.STDR_MT, b.RANK, b.FEATURE, b.SCORE, b.FEATURE_TYPE
FROM GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION b;