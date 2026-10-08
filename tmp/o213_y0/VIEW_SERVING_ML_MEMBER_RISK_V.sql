create or replace view ML_MEMBER_RISK_V(
	STDR_MT COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
	STDR_MONTH_KEY COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
	MBER_NO COMMENT '정기회원번호(7자리 TEXT) [원천: ML 회원 예측]',
	CHURN_PROB COMMENT '중단 예측 확률(0~1) — 원천 중복행 평균 · 예측 지평은 발행하지 않는다(원천 기간 표기 불일치)',
	CHURN_CLASS COMMENT '중단 예측 분류(모델 class) — 원천 중복행 중 하나라도 1 이면 1 · 업무 판정선 아님',
	CHURN_PRED_ROWS COMMENT '이 회원·기준월의 원천 중단 예측 행수 — 1 초과 = 원천 중복(평균으로 단일화됨)',
	INC_PROB COMMENT '증액 예측 확률(0~1) — 원천 중복행 평균',
	INC_CLASS COMMENT '증액 예측 분류(모델 class) — 원천 중복행 중 하나라도 1 이면 1',
	INC_PRED_ROWS COMMENT '이 회원·기준월의 원천 증액 예측 행수 — 1 초과 = 원천 중복',
	LOYAL_PROB COMMENT '충성회원 예측 확률(0~1) — 모집단이 중단·증액과 다르다(HAS_LOYAL_PRED)',
	LOYAL_CLASS COMMENT '충성회원 예측 분류(모델 class)',
	HAS_CHURN_PRED COMMENT '중단 예측 존재 여부 — 분모 판정용',
	HAS_INC_PRED COMMENT '증액 예측 존재 여부 — 분모 판정용',
	HAS_LOYAL_PRED COMMENT '충성 예측 존재 여부 — 분모 판정용(모집단 상이)',
	PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICTION:logs:Error 비어있지 않음) · 3종·중복행 중 하나라도',
	CHURN_GRADE COMMENT '중단위험 등급(F-4 · O190) — 기준월 내 백분위: 상위 10% 고위험 · 10~25% 주의 · 나머지 일반 · 예측 없음 NULL. 🔴 확률 임계가 아니라 순위다',
	LOYAL_GRADE COMMENT '장기회원 등급(F-4 · O190) — 기준월 내 백분위: 상위 5% 최상위 · 5~10% 상 · 10~25% 중 · 나머지 하 · 충성 예측 모집단만(그 외 NULL)'
) COMMENT='ML 회원단위 예측(중단·증액·충성) 통합. grain=기준월×회원(키 집계 후 유일). 원천 중복행은 확률 평균·분류 MAX 로 단일화했다(원천 미해소·완화 · O198 이후 피처 컬럼 없음). 예측치이며 실적이 아니다.'
 as
WITH churn AS (
  SELECT STDR_MT,
         MBER_NO,
         AVG(PREDICTION:probability:"1"::FLOAT)            AS CHURN_PROB,
         MAX(PREDICTION:class::VARCHAR)                     AS CHURN_CLASS,
         COUNT(*)                                           AS CHURN_PRED_ROWS,
         BOOLOR_AGG(ARRAY_SIZE(PREDICTION:logs:Error) > 0)  AS CHURN_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M
  GROUP BY 1, 2
),
inc AS (
  SELECT STDR_MT,
         MBER_NO,
         AVG(PREDICTION:probability:"1"::FLOAT)            AS INC_PROB,
         MAX(PREDICTION:class::VARCHAR)                     AS INC_CLASS,
         COUNT(*)                                           AS INC_PRED_ROWS,
         BOOLOR_AGG(ARRAY_SIZE(PREDICTION:logs:Error) > 0)  AS INC_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_MBER_INC_12M
  GROUP BY 1, 2
),
loyal AS (
  -- 실측 202606: 43,498행 = 43,498키(중복 없음). 원천 변경 대비 같은 방식으로 집계한다.
  SELECT STDR_MT,
         MBER_NO,
         AVG(PREDICTION:probability:"1"::FLOAT)            AS LOYAL_PROB,
         MAX(PREDICTION:class::VARCHAR)                     AS LOYAL_CLASS,
         BOOLOR_AGG(ARRAY_SIZE(PREDICTION:logs:Error) > 0)  AS LOYAL_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_LOYAL_MBER
  GROUP BY 1, 2
),
u AS (
  SELECT STDR_MT, MBER_NO FROM churn
  UNION
  SELECT STDR_MT, MBER_NO FROM inc
  UNION
  SELECT STDR_MT, MBER_NO FROM loyal
)
SELECT
    u.STDR_MT                                    AS STDR_MT,
    TO_NUMBER(u.STDR_MT)                         AS STDR_MONTH_KEY,
    u.MBER_NO                                    AS MBER_NO,
    c.CHURN_PROB                                 AS CHURN_PROB,
    c.CHURN_CLASS                                AS CHURN_CLASS,
    c.CHURN_PRED_ROWS                            AS CHURN_PRED_ROWS,
    i.INC_PROB                                   AS INC_PROB,
    i.INC_CLASS                                  AS INC_CLASS,
    i.INC_PRED_ROWS                              AS INC_PRED_ROWS,
    l.LOYAL_PROB                                 AS LOYAL_PROB,
    l.LOYAL_CLASS                                AS LOYAL_CLASS,
    c.MBER_NO IS NOT NULL                        AS HAS_CHURN_PRED,
    i.MBER_NO IS NOT NULL                        AS HAS_INC_PRED,
    l.MBER_NO IS NOT NULL                        AS HAS_LOYAL_PRED,
    COALESCE(c.CHURN_HAS_ERROR, FALSE)
      OR COALESCE(i.INC_HAS_ERROR, FALSE)
      OR COALESCE(l.LOYAL_HAS_ERROR, FALSE)      AS PREDICTION_HAS_ERROR,
    CASE WHEN c.CHURN_PROB IS NULL THEN NULL
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, c.CHURN_PROB IS NULL ORDER BY c.CHURN_PROB DESC) < 0.10 THEN '고위험'
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, c.CHURN_PROB IS NULL ORDER BY c.CHURN_PROB DESC) < 0.25 THEN '주의'
         ELSE '일반' END                          AS CHURN_GRADE,
    CASE WHEN l.LOYAL_PROB IS NULL THEN NULL
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, l.LOYAL_PROB IS NULL ORDER BY l.LOYAL_PROB DESC) < 0.05 THEN '최상위'
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, l.LOYAL_PROB IS NULL ORDER BY l.LOYAL_PROB DESC) < 0.10 THEN '상'
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, l.LOYAL_PROB IS NULL ORDER BY l.LOYAL_PROB DESC) < 0.25 THEN '중'
         ELSE '하' END                            AS LOYAL_GRADE
FROM u
LEFT JOIN churn c ON c.STDR_MT = u.STDR_MT AND c.MBER_NO = u.MBER_NO
LEFT JOIN inc   i ON i.STDR_MT = u.STDR_MT AND i.MBER_NO = u.MBER_NO
LEFT JOIN loyal l ON l.STDR_MT = u.STDR_MT AND l.MBER_NO = u.MBER_NO;