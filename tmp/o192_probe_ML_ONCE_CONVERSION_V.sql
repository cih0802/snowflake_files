CREATE OR REPLACE VIEW SANDBOX.PUBLIC.P_ML_ONCE_CONVERSION_V (
    ONCE_MBER_NO         COMMENT '일시회원번호(S 접두) — 정기회원번호와 체계가 달라 조인 금지',
    OBSERVE_MT           COMMENT '관측월 YYYYMM(원천 STDR_MT) — 모델 실행월이 아니다',
    OBSERVE_MONTH_KEY    COMMENT '관측월 숫자키',
    ONCE_JOIN_MT         COMMENT '관측창 첫 월(회원별 최소 관측월)',
    MONTHS_SINCE_JOIN    COMMENT '관측창 첫 월부터 경과 월수',
    IS_LATEST_OBSERVED   COMMENT '회원별 마지막 관측월 행 여부 — 🔴 [O190] 원천 grain 변경으로 회원당 1행 보장이 깨졌다(원천 확인 중)',
    CONVERT_PROB         COMMENT '정기 전환 예측 확률(0~1) · 예측 지평 미발행',
    CONVERT_CLASS        COMMENT '전환 예측 분류(모델 class) — 업무 판정선 미확정',
    PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICTION:logs:Error 비어있지 않음)',
    SEX_NAME             COMMENT '성별 라벨(SILVER.CRM_MEMBER 현재 스냅샷)',
    MEMBER_DIV_NAME      COMMENT '회원구분 라벨(현재 스냅샷)',
    REGIST_DEPT_NAME     COMMENT '등록부서명(DIM_ORG · 현재 스냅샷)'
)
  COMMENT = 'ML 일시후원회원의 정기후원 전환 예측. grain=일시후원회원×관측월(가입월부터 6개월). 관측월은 모델 실행월이 아니다. 미래 관측월(피처 없음)은 제외했다. 예측치이며 실적이 아니다.'
AS SELECT NULL AS ONCE_MBER_NO, NULL AS OBSERVE_MT, NULL AS OBSERVE_MONTH_KEY, NULL AS ONCE_JOIN_MT, NULL AS MONTHS_SINCE_JOIN, NULL AS IS_LATEST_OBSERVED, NULL AS CONVERT_PROB, NULL AS CONVERT_CLASS, NULL AS PREDICTION_HAS_ERROR, NULL AS SEX_NAME, NULL AS MEMBER_DIV_NAME, NULL AS REGIST_DEPT_NAME