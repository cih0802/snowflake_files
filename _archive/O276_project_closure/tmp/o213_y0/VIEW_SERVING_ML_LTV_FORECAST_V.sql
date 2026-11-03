create or replace view ML_LTV_FORECAST_V(
	LTV_TYPE COMMENT 'LTV유형: MKTG_CHANNEL_AVG_MEMBER(마케팅채널 회원평균) · CMPGN_TOTAL(캠페인 월간 후원금액) — 🔴 하나로 고정',
	LTV_TYPE_NAME COMMENT 'LTV유형 라벨',
	SERIES_CD COMMENT '계열코드(유형별 마케팅채널 코드 / 캠페인코드) — 원천 컬럼명은 둘 다 MKTG_CHANNEL',
	SERIES_NAME COMMENT '계열명(마케팅채널명 / 캠페인명 · 캠페인 마스터) — 미매칭 NULL',
	STDR_MT COMMENT '예측 실행 기준월 YYYYMM',
	TS COMMENT '예측월 시작일',
	FORECAST COMMENT '예측값(원) — 회원평균 유형은 합산 금지',
	LOWER_BOUND COMMENT '95% 신뢰구간 하한(원)',
	UPPER_BOUND COMMENT '95% 신뢰구간 상한(원)'
) COMMENT='ML LTV 월별 예측 2종. MKTG_CHANNEL_AVG_MEMBER=마케팅채널별 회원평균 후원금액 · CMPGN_TOTAL=캠페인별 월간 후원금액(원천 컬럼명은 MKTG_CHANNEL 이나 값은 캠페인코드). 두 유형은 계열축과 의미가 달라 합산·비교할 수 없다. 단위=원. 예측치이며 실적이 아니다.'
 as
SELECT 'MKTG_CHANNEL_AVG_MEMBER'           AS LTV_TYPE,
       '마케팅채널 회원평균 후원금액'        AS LTV_TYPE_NAME,
       a.MKTG_CHANNEL                      AS SERIES_CD,
       ch.MKTG_CHANNEL_NM                  AS SERIES_NAME,
       a.STDR_MT, a.TS, a.FORECAST, a.LOWER_BOUND, a.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV a
LEFT JOIN (
    SELECT DISTINCT MKTG_CHANNEL::VARCHAR AS MKTG_CHANNEL, MKTG_CHANNEL_NM
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE MKTG_CHANNEL IS NOT NULL
) ch ON ch.MKTG_CHANNEL = a.MKTG_CHANNEL
UNION ALL
SELECT 'CMPGN_TOTAL',
       '캠페인 월간 후원금액',
       s.MKTG_CHANNEL,
       cm.CMPGN_NM,
       s.STDR_MT, s.TS, s.FORECAST, s.LOWER_BOUND, s.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_CMPGN_SPNSR_AMT_LTV s
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm ON cm.CMPGN_CD = s.MKTG_CHANNEL;