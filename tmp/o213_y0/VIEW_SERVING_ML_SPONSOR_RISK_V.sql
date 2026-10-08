create or replace view ML_SPONSOR_RISK_V(
	STDR_MT COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
	STDR_MONTH_KEY COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
	MBER_NO COMMENT '회원번호 — 회원수는 COUNT(DISTINCT) 로 센다(후원건 grain)',
	SPNSR_BSNS_ID COMMENT '후원사업ID [원천]',
	SPNSR_BSNS_NAME COMMENT '후원사업명(SILVER.CRM_SPONSORSHIP) — 미매칭 NULL',
	SPNSR_BSNS_NO COMMENT '후원사업번호(약정) [원천]',
	CMPGN_CTGR_CD COMMENT '캠페인카테고리코드 [원천]',
	CMPGN_CTGR_NAME COMMENT '캠페인카테고리명(캠페인 마스터 DISTINCT · 코드당 1개 실측) — 미매칭 NULL',
	CHURN_PROB COMMENT '후원건 이탈 예측 확률(0~1) · 예측 지평 미발행',
	CHURN_CLASS COMMENT '이탈 예측 분류(모델 class) — 업무 판정선 아님',
	PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICTION:logs:Error 비어있지 않음)',
	CHURN_GRADE COMMENT '후원건 이탈위험 등급(F-4 · O190) — 기준월 내 후원건 백분위: 상위 5% 고위험 · 5~25% 주의 · 나머지 일반. 🔴 확률 임계가 아니라 순위다'
) COMMENT='ML 후원건단위 이탈 예측. grain=기준월×회원×후원사업ID×후원사업번호(실측 유일 · 202606 840,471행). 회원수는 반드시 중복제거로 센다. 예측치이며 실적이 아니다.'
 as
SELECT
    r.STDR_MT                                     AS STDR_MT,
    TO_NUMBER(r.STDR_MT)                          AS STDR_MONTH_KEY,
    r.MBER_NO                                     AS MBER_NO,
    r.SPNSR_BSNS_ID                               AS SPNSR_BSNS_ID,
    sp.SPNSR_BSNS_NM                              AS SPNSR_BSNS_NAME,
    r.SPNSR_BSNS_NO                               AS SPNSR_BSNS_NO,
    r.CMPGN_CTGR_CD                               AS CMPGN_CTGR_CD,
    ctgr.CMPGN_CTGR_NM                            AS CMPGN_CTGR_NAME,
    r.PREDICTION:probability:"1"::FLOAT            AS CHURN_PROB,
    r.PREDICTION:class::VARCHAR                    AS CHURN_CLASS,
    ARRAY_SIZE(r.PREDICTION:logs:Error) > 0        AS PREDICTION_HAS_ERROR,
    CASE WHEN r.PREDICTION:probability:"1"::FLOAT IS NULL THEN NULL
         WHEN PERCENT_RANK() OVER (PARTITION BY r.STDR_MT, r.PREDICTION:probability:"1"::FLOAT IS NULL
                                   ORDER BY r.PREDICTION:probability:"1"::FLOAT DESC) < 0.05 THEN '고위험'
         WHEN PERCENT_RANK() OVER (PARTITION BY r.STDR_MT, r.PREDICTION:probability:"1"::FLOAT IS NULL
                                   ORDER BY r.PREDICTION:probability:"1"::FLOAT DESC) < 0.25 THEN '주의'
         ELSE '일반' END                             AS CHURN_GRADE
FROM GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M r
LEFT JOIN GN_DW.SILVER.CRM_SPONSORSHIP sp ON sp.SPNSR_BSNS_ID = r.SPNSR_BSNS_ID
LEFT JOIN (
    SELECT DISTINCT CMPGN_CTGR_CD::VARCHAR AS CTGR_CD, CMPGN_CTGR_NM
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE CMPGN_CTGR_CD IS NOT NULL
) ctgr ON ctgr.CTGR_CD = r.CMPGN_CTGR_CD;