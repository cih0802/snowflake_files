create or replace view MSTR_DVLP_YE_TREND_V(
	STRD_YY COMMENT '기준연도(YYYY 문자열)',
	AS_OF_MT COMMENT '산출 기준 최신 기준년월(진행 중 · 부분 실적)',
	DVLP_DIV_CD COMMENT '개발구분코드(MSTR)',
	DVLP_DIV_NM COMMENT '개발구분명 · 🔴 실질 목표는 신규만 있다',
	DEPT4_NM COMMENT '실적부서4(구분_팀) 명',
	DEPT3_NM COMMENT '실적부서3(본부/지부) 명',
	DEPT2_NM COMMENT '실적부서2(팀/지부) 명',
	DEPT_ID COMMENT '실적부서 ID',
	DEPT_NM COMMENT '실적부서명',
	YY_GOAL_CNT COMMENT '연 개발 목표(건) = 월 목표 합',
	CLOSED_ACT_CNT COMMENT '그 해 마감월 MSTR 개발(건) 실적 합',
	CUR_MONTH_ACT_CNT COMMENT '진행 중 최신 기준월의 부분 실적(건 · 참고 · 추세 산식에는 쓰지 않는다)',
	CLOSED_MONTHS COMMENT '그 해 마감월 수',
	LAST3_AVG_CNT COMMENT '직전 3개 마감월 월평균 실적(건 · 현재 연도만 · 지난 연도 0)',
	YE_TREND_CNT COMMENT '연도말 개발 추세 참고치(건) = 마감월 실적 + (12 − 마감월 수) × 직전 3개월 평균 · 🔴 모델 예측이 아니다'
) COMMENT='🆕 [O207] MSTR 연도말 개발 추세 참고치. 원천 = SERVING.MSTR_DVLP_GOAL_V. 🔴🔴 MSTR 에 예측 로직은 없다 — 이 값은 직전 3개월 평균을 남은 달에 이어 붙인 「추세 참고치」이며 모델 예측이 아니다. 🔴 MSTR 기준.'
 as
WITH cur AS (
  SELECT MAX(IFF(CLOSED_MONTH_YN = 'N' AND ACT_CNT IS NOT NULL, STRD_MT, NULL)) AS CUR_MT
  FROM GN_DW.SERVING.MSTR_DVLP_GOAL_V
), l3 AS (
  SELECT g.DEPT_ID, g.DVLP_DIV_CD, SUM(g.ACT_CNT) / 3 AS L3
  FROM GN_DW.SERVING.MSTR_DVLP_GOAL_V g CROSS JOIN cur
  WHERE g.STRD_MT < cur.CUR_MT
    AND g.STRD_MT >= TO_CHAR(DATEADD(MONTH, -3, TO_DATE(cur.CUR_MT, 'YYYYMM')), 'YYYYMM')
  GROUP BY 1, 2
), y AS (
  SELECT STRD_YY, DVLP_DIV_CD, ANY_VALUE(DVLP_DIV_NM) AS DVLP_DIV_NM,
         ANY_VALUE(DEPT4_NM) AS DEPT4_NM, ANY_VALUE(DEPT3_NM) AS DEPT3_NM, ANY_VALUE(DEPT2_NM) AS DEPT2_NM,
         DEPT_ID, ANY_VALUE(DEPT_NM) AS DEPT_NM,
         SUM(GOAL_CNT) AS YY_GOAL_CNT,
         SUM(IFF(CLOSED_MONTH_YN = 'Y', ACT_CNT, 0)) AS CLOSED_ACT_CNT,
         SUM(IFF(CLOSED_MONTH_YN = 'N', ACT_CNT, 0)) AS CUR_MONTH_ACT_CNT
  FROM GN_DW.SERVING.MSTR_DVLP_GOAL_V
  GROUP BY STRD_YY, DVLP_DIV_CD, DEPT_ID
)
SELECT
  y.STRD_YY, cur.CUR_MT, y.DVLP_DIV_CD, y.DVLP_DIV_NM,
  y.DEPT4_NM, y.DEPT3_NM, y.DEPT2_NM, y.DEPT_ID, y.DEPT_NM,
  y.YY_GOAL_CNT,
  ROUND(y.CLOSED_ACT_CNT, 4)::NUMBER(18,4),
  ROUND(y.CUR_MONTH_ACT_CNT, 4)::NUMBER(18,4),
  -- 🆕 [O207] 마감월 수 = 달력 기준(실적 없는 달도 마감월로 센다 · 행 존재로 세면 결측 월이 남은 월로 부풀려진다)
  IFF(y.STRD_YY = LEFT(cur.CUR_MT, 4), TO_NUMBER(RIGHT(cur.CUR_MT, 2)) - 1, IFF(y.STRD_YY < LEFT(cur.CUR_MT, 4), 12, 0)),
  ROUND(IFF(y.STRD_YY = LEFT(cur.CUR_MT, 4), COALESCE(l3.L3, 0), 0), 4)::NUMBER(18,4),
  ROUND(y.CLOSED_ACT_CNT
        + IFF(y.STRD_YY = LEFT(cur.CUR_MT, 4), COALESCE(l3.L3, 0) * (13 - TO_NUMBER(RIGHT(cur.CUR_MT, 2))), 0), 4)::NUMBER(18,4)
FROM y
CROSS JOIN cur
LEFT JOIN l3 ON l3.DEPT_ID = y.DEPT_ID AND l3.DVLP_DIV_CD = y.DVLP_DIV_CD;