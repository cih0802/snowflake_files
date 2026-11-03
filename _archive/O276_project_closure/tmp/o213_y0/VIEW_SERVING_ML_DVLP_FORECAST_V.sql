create or replace view ML_DVLP_FORECAST_V(
	SERIES_TYPE COMMENT '계열유형: TOTAL·CAMPAIGN — 🔴 유형 간 합산은 중복계상 · 항상 고정·그룹 (부서·후원사업·신규기존은 원천 삭제로 비활성)',
	SERIES_CD COMMENT '계열코드(유형에 따라 캠페인 코드 / (전사))',
	SERIES_NAME COMMENT '계열명(마스터 조인 라벨 · 미매칭 NULL)',
	STDR_MT COMMENT '예측 실행 기준월 YYYYMM [원천]',
	TS COMMENT '예측월 시작일 [원천]',
	FORECAST COMMENT '예측 개발금액 — 🔴 단위 만원(신규+증액+재후원) [원천]',
	LOWER_BOUND COMMENT '95% 신뢰구간 하한(만원)',
	UPPER_BOUND COMMENT '95% 신뢰구간 상한(만원)'
) COMMENT='ML 개발금액 예측 2종(전사·캠페인) 통합. 부서·후원사업·신규기존 예측은 원천 삭제로 제공하지 않음. grain=기준월×계열유형×계열×예측월. 단위=만원. 계열유형 간 합산은 중복계상이다. 예측치이며 실적이 아니다.'
 as
SELECT 'TOTAL'                          AS SERIES_TYPE,
       '(전사)'                          AS SERIES_CD,
       '(전사 합계)'                      AS SERIES_NAME,
       t.STDR_MT, t.TS, t.FORECAST, t.LOWER_BOUND, t.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_DVLP_AMT t
-- ⛔ [2026-09-30] 원천 테이블 삭제로 비활성 · [2026-10-01 O196] D-3 종결 = 재활성하지 않는다(라이브 DROP · 되살리려면 새 사용자 결정)
--    기획실 3종(MONTHLY_DEPT_DVLP_AMT · MONTHLY_SPNSR_BSNS_ID_DVLP_AMT · MONTHLY_NEW_OLD_DVLP_AMT)은 O198 이관 범위에서도 제외다.
--    되살릴 경우 원천의 SERIES 컬럼명이 바뀌었는지 05번 DDL 로 먼저 확인한다(O198 에서 다른 시계열은 의미 컬럼명으로 바뀌었다).
UNION ALL
SELECT 'CAMPAIGN', c.CMPGN_CD, cm.CMPGN_NM,
       c.STDR_MT, c.TS, c.FORECAST, c.LOWER_BOUND, c.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT c
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm ON cm.CMPGN_CD = c.CMPGN_CD;