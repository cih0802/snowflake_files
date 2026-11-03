create or replace view ML_ONCE_CONVERSION_V(
	STDR_MT COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
	STDR_MONTH_KEY COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
	ONCE_MBER_NO COMMENT '일시회원번호(S 접두) — 정기회원번호와 체계가 달라 조인 금지',
	CONVERT_PROB COMMENT '정기 전환 예측 확률(0~1) · 예측 지평 미발행',
	CONVERT_CLASS COMMENT '전환 예측 분류(모델 class) — 업무 판정선 미확정',
	PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICT:logs:Error 비어있지 않음)',
	SEX_NAME COMMENT '성별 라벨(SILVER.CRM_MEMBER 현재 스냅샷)',
	MEMBER_DIV_NAME COMMENT '회원구분 라벨(현재 스냅샷)',
	REGIST_DEPT_NAME COMMENT '등록부서명(DIM_ORG · 현재 스냅샷)'
) COMMENT='ML 일시후원회원의 정기후원 전환 예측. grain=기준월×일시후원회원이나 원천이 회원당 다중 예측행을 담는다(실행순번 없음 · DEC-59 #1 유지). 회원수는 중복제거로 센다. 예측치이며 실적이 아니다.'
 as
SELECT
    o.STDR_MT                                 AS STDR_MT,
    TO_NUMBER(o.STDR_MT)                      AS STDR_MONTH_KEY,
    o.ONCE_MBER_NO                            AS ONCE_MBER_NO,
    o.PREDICT:probability:"1"::FLOAT          AS CONVERT_PROB,
    o.PREDICT:class::VARCHAR                  AS CONVERT_CLASS,
    ARRAY_SIZE(o.PREDICT:logs:Error) > 0      AS PREDICTION_HAS_ERROR,
    m.SEX_NM                                  AS SEX_NAME,
    m.MBER_DIV_NM                             AS MEMBER_DIV_NAME,
    og.DEPARTMENT                             AS REGIST_DEPT_NAME
FROM GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION o
LEFT JOIN GN_DW.SILVER.CRM_MEMBER m ON m.MEMBER_DK = o.ONCE_MBER_NO
LEFT JOIN GN_DW.GOLD.DIM_ORG og     ON og.ORG_DK   = ABS(HASH(m.REGIST_DEPT_CD));