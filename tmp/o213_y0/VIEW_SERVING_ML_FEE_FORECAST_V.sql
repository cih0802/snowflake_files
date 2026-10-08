create or replace view ML_FEE_FORECAST_V(
	STDR_MT COMMENT '예측 실행 기준월 YYYYMM',
	STDR_MONTH_KEY COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
	CMPGN_CTGR_CD COMMENT '캠페인카테고리코드(예측 계열)',
	CMPGN_CTGR_NAME COMMENT '캠페인카테고리명(캠페인 마스터 DISTINCT) — 미매칭 NULL',
	FORECAST_TS COMMENT '예측월 시작일',
	FORECAST_MONTH_KEY COMMENT '예측월 YYYYMM(FORECAST_TS 파생)',
	FORECAST_AMT COMMENT '예측 회비(후원금액) — 🔴 단위 원(개발금액 예측 만원과 다름)',
	FORECAST_LOWER COMMENT '95% 신뢰구간 하한(원)',
	FORECAST_UPPER COMMENT '95% 신뢰구간 상한(원)'
) COMMENT='ML 캠페인카테고리별 회비(후원금액) 예측. grain=기준월×캠페인카테고리×예측월. 단위=원. 개발금액 예측(만원)과 단위가 다르므로 합산하지 않는다. 예측치이며 실적이 아니다.'
 as
SELECT
    r.STDR_MT                        AS STDR_MT,
    TO_NUMBER(r.STDR_MT)             AS STDR_MONTH_KEY,
    r.CMPGN_CTGR_CD                  AS CMPGN_CTGR_CD,
    ctgr.CMPGN_CTGR_NM               AS CMPGN_CTGR_NAME,
    r.TS                             AS FORECAST_TS,
    TO_NUMBER(TO_CHAR(r.TS,'YYYYMM')) AS FORECAST_MONTH_KEY,
    r.FORECAST                       AS FORECAST_AMT,
    r.LOWER_BOUND                    AS FORECAST_LOWER,
    r.UPPER_BOUND                    AS FORECAST_UPPER
FROM GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT r
LEFT JOIN (
    SELECT DISTINCT CMPGN_CTGR_CD::VARCHAR AS CTGR_CD, CMPGN_CTGR_NM
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE CMPGN_CTGR_CD IS NOT NULL
) ctgr ON ctgr.CTGR_CD = r.CMPGN_CTGR_CD;