CREATE OR REPLACE VIEW GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V (
    STDR_MT                COMMENT '모델 실행 기준월(YYYYMM)',
    MBER_NO                COMMENT '회원번호(정기회원 체계)',
    NEW_EXISTING           COMMENT '신규/기존(회원 축 · ML_MEMBER_ATTR_ASOF_V.NEW_EXISTING 그대로 · 기준월 행이 없으면 직전 12개월 최근 월 값)',
    HQ_BRANCH_NM           COMMENT '본부지부 3분류(본부/지부/기타) = 약정 실적부서의 DIM_ORG 구분 8종을 묶은 값. NULL = 활동 약정 없음',
    HQ_BRANCH_SRC_NM       COMMENT '본부지부 원값(DIM_ORG.ACMSLT_DIV_GROUP_NM 8종). NULL = 활동 약정 없음',
    SPONSORSHIP_NAME       COMMENT '활동 약정의 후원사업명(DIM_SPONSORSHIP). NULL = 활동 약정 없음 또는 차원 미매핑',
    CPR_DIV_NM             COMMENT '활동 약정의 법인(FACT_MEMBER_SPONSORSHIP_SPAN.ACQ_CPR_DIV_NM · 통합/사단/사복). NULL = 활동 약정 없음',
    CMMN_BRND_NM           COMMENT '활동 약정의 획득 공통브랜드. NULL = 활동 약정 없음 또는 원천 값 없음',
    CMPGN_CTGR_NM          COMMENT '활동 약정의 획득 캠페인카테고리. NULL = 활동 약정 없음 또는 원천 값 없음',
    MKTG_CMPGN_NM          COMMENT '활동 약정의 획득 마케팅캠페인명. NULL = 활동 약정 없음 또는 원천 값 없음',
    ACTIVE_SPNSR_CNT       COMMENT '이 조합에 속한 기준월 말 활동 약정 수(건). 0 = 활동 약정 없는 회원 행',
    MEMBER_WEIGHT          COMMENT '회원 가중치 0~1 = 이 조합 약정 수 ÷ 회원 전체 활동 약정 수(약정 없는 회원 = 1). 회원별 합 = 1',
    HAS_CHURN_PRED         COMMENT 'TRUE = 회원 단위 중단 예측 대상',
    CHURN_PROB             COMMENT '회원 단위 중단확률(0~1 · 예측치). NULL = 중단 예측 대상 아님',
    CHURN_GRADE            COMMENT '회원 단위 중단위험 등급(고위험/주의/일반). NULL = 중단 예측 대상 아님',
    HAS_INC_PRED           COMMENT 'TRUE = 증액 예측 대상',
    INC_PROB               COMMENT '증액확률(0~1 · 예측치). NULL = 증액 예측 대상 아님',
    INC_CLASS              COMMENT '증액 모델 판정 0/1. NULL = 증액 예측 대상 아님',
    HAS_SPONSOR_PRED       COMMENT 'TRUE = 이 조합 약정 중 후원건 단위 이탈 예측(ML_SPONSOR_RISK_V) 대상이 있다',
    SPONSOR_MAX_CHURN_PROB COMMENT '이 조합 약정의 후원건 이탈확률 최댓값(0~1). NULL = 후원건 예측 대상 아님',
    SPONSOR_CHURN_GRADE    COMMENT '이 조합 약정 중 가장 높은 후원건 이탈위험 등급. NULL = 후원건 예측 대상 아님',
    IS_UNPAID_STDR         COMMENT '실적 · TRUE = 기준월에 미납 청구가 있다(회원 축 · ML_MEMBER_PRED_BRIDGE_V). 🔴 미납 예측 모델은 없다',
    UNPAID_AMT_12M         COMMENT '실적 · 기준월 포함 직전 12개월 미납 청구액 합(원 · 회원 축). NULL = 12개월 청구 없음',
    UNPAID_MONTHS_12M      COMMENT '실적 · 직전 12개월 중 미납이 있는 월 수(개월 · 회원 축). NULL = 12개월 청구 없음'
)
  COMMENT = 'ML 회원예측(중단·증액) + 미납 실적 × 7축(신규기존·본부지부·후원사업·법인·공통브랜드·캠페인카테고리·마케팅캠페인명). grain = 기준월 × 회원 × 7축 조합. 축 원천 = GOLD.FACT_MEMBER_SPONSORSHIP_SPAN 기준월 말 활동 약정.'
AS
WITH r AS (
    SELECT STDR_MT, TO_NUMBER(STDR_MT) AS MK, MBER_NO,
           HAS_CHURN_PRED, CHURN_PROB, CHURN_GRADE,
           HAS_INC_PRED, INC_PROB, INC_CLASS
    FROM GN_DW.SERVING.ML_MEMBER_RISK_V
), act AS (
    SELECT r.STDR_MT, r.MBER_NO, s.SPNSR_NO, s.SPNSR_BSNS_NO,
           CASE
               WHEN o.ACMSLT_DIV_GROUP_NM IN ('본부', '시도본부', '시도본부 및 중앙', '본부(사복)') THEN '본부'
               WHEN o.ACMSLT_DIV_GROUP_NM IN ('지부', '지부(사복)') THEN '지부'
               WHEN o.ACMSLT_DIV_GROUP_NM IS NOT NULL THEN '기타'
           END AS HQ_BRANCH_NM,
           o.ACMSLT_DIV_GROUP_NM AS HQ_BRANCH_SRC_NM,
           ds.SPONSORSHIP_NAME,
           s.ACQ_CPR_DIV_NM AS CPR_DIV_NM,
           s.ACQ_CMMN_BRND_NM AS CMMN_BRND_NM,
           s.ACQ_CMPGN_CTGR_NM AS CMPGN_CTGR_NM,
           s.ACQ_MKTG_CMPGN_NM AS MKTG_CMPGN_NM
    FROM r
    JOIN GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN s
      ON s.MEMBER_DK = r.MBER_NO
     AND s.START_MONTH_KEY <= r.MK
     AND (s.DSCNTC_MONTH_KEY IS NULL OR s.DSCNTC_MONTH_KEY > r.MK)
    LEFT JOIN GN_DW.GOLD.DIM_ORG o
      ON o.ORG_DK = ABS(HASH(s.SPNSR_ACMSLT_DEPT_CD))
    LEFT JOIN GN_DW.GOLD.DIM_SPONSORSHIP ds
      ON ds.SPONSORSHIP_SK = s.SPONSORSHIP_SK
), sp AS (
    SELECT a.*, k.CHURN_PROB AS SP_PROB, k.CHURN_GRADE AS SP_GRADE, (k.MBER_NO IS NOT NULL) AS HAS_SP
    FROM act a
    LEFT JOIN GN_DW.SERVING.ML_SPONSOR_RISK_V k
      ON k.STDR_MT = a.STDR_MT
     AND k.MBER_NO = a.MBER_NO
     AND k.SPNSR_BSNS_NO = a.SPNSR_BSNS_NO
), g AS (
    SELECT STDR_MT, MBER_NO, HQ_BRANCH_NM, HQ_BRANCH_SRC_NM, SPONSORSHIP_NAME,
           CPR_DIV_NM, CMMN_BRND_NM, CMPGN_CTGR_NM, MKTG_CMPGN_NM,
           COUNT(DISTINCT SPNSR_NO) AS ACTIVE_SPNSR_CNT,
           BOOLOR_AGG(HAS_SP) AS HAS_SPONSOR_PRED,
           MAX(SP_PROB) AS SPONSOR_MAX_CHURN_PROB,
           CASE MAX(CASE SP_GRADE WHEN '고위험' THEN 3 WHEN '주의' THEN 2 WHEN '일반' THEN 1 END)
               WHEN 3 THEN '고위험' WHEN 2 THEN '주의' WHEN 1 THEN '일반'
           END AS SPONSOR_CHURN_GRADE
    FROM sp
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
)
SELECT r.STDR_MT,
       r.MBER_NO,
       at.NEW_EXISTING,
       g.HQ_BRANCH_NM,
       g.HQ_BRANCH_SRC_NM,
       g.SPONSORSHIP_NAME,
       g.CPR_DIV_NM,
       g.CMMN_BRND_NM,
       g.CMPGN_CTGR_NM,
       g.MKTG_CMPGN_NM,
       COALESCE(g.ACTIVE_SPNSR_CNT, 0),
       COALESCE(g.ACTIVE_SPNSR_CNT / NULLIF(SUM(g.ACTIVE_SPNSR_CNT) OVER (PARTITION BY r.STDR_MT, r.MBER_NO), 0), 1),
       r.HAS_CHURN_PRED,
       r.CHURN_PROB,
       r.CHURN_GRADE,
       r.HAS_INC_PRED,
       r.INC_PROB,
       r.INC_CLASS,
       COALESCE(g.HAS_SPONSOR_PRED, FALSE),
       g.SPONSOR_MAX_CHURN_PROB,
       g.SPONSOR_CHURN_GRADE,
       COALESCE(b.IS_UNPAID_STDR, FALSE),
       b.UNPAID_AMT_12M,
       b.UNPAID_MONTHS_12M
FROM r
LEFT JOIN g
  ON g.STDR_MT = r.STDR_MT AND g.MBER_NO = r.MBER_NO
LEFT JOIN GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V at
  ON at.STDR_MT = r.STDR_MT AND at.MBER_NO = r.MBER_NO
LEFT JOIN GN_DW.SERVING.ML_MEMBER_PRED_BRIDGE_V b
  ON b.STDR_MT = r.STDR_MT AND b.MBER_NO = r.MBER_NO;