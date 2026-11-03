-- ============================================================================
-- 🔴 [O250-E 2026-10-21] 이력 보존 파일 — 신규 구축에서 실행하지 않는다.
--   정본 = 뷰 2종 → 21_ML_SERVING_뷰_DDL.sql [O250] 절 · SV 2종 → 05_29_SV_DDL_ML_MEMBER_PRED_AXIS.sql · 05_30_SV_DDL_ML_FEE_FORECAST_AXIS.sql
--   (문면 무변경 이관 · 토큰 대조 부재 0) · 이 파일을 고치지 말고 정본을 고친다(두 곳 정본 = drift · P23).
-- ============================================================================
-- ============================================================================
-- 36_DEPLOY_ML_PRED_7AXIS.sql — 🆕 O250-A (2026-10-21 · TRIALADMIN(SR61467))
--   ML 회원예측(증액·중단·미납·회비) × 7축 서빙 뷰 2종 + SV 2종
--   · 배경 = 현업 요청: 증액·중단 예측이 캠페인카테고리까지만 보인다
--     ⇒ 신규기존·본부지부·후원사업·법인·공통브랜드·캠페인카테고리·마케팅캠페인명 7축을 함께 본다.
--   · 추천안 = 축별 뷰 7개가 아니라 「7축 조합 grain」 뷰 2개
--     (회원 예측 1 · 회비 예측 1) ⇒ 축 부분집합 어느 것으로 GROUP BY 해도 합이 맞는다.
--   · 축 원천 = GOLD.FACT_MEMBER_SPONSORSHIP_SPAN(기준월 말 활동 약정) · 법인 = 그 테이블의 ACQ_CPR_DIV_NM
--     (사용자 결정 ②) · 신규기존 = 회원 월실적(회원 축 · ML_MEMBER_ATTR_ASOF_V 와 같은 정의)
--   · 본부지부 = DIM_ORG.ACMSLT_DIV_GROUP_NM 8종 → 본부/지부/기타 3분류(사용자 결정 ①) · 원값 컬럼 병기
--   · 기존 뷰(ML_CHURN_BY_*·ML_INC_BY_MKTG_CMPGN_V·ML_FEE_FORECAST_ALLOC_V)는 손대지 않는다(신규 객체만).
--   · 구성 = USE → 뷰 2 → SV 2 → GRANT → 스모크. 파일 단독 실행 가능.
--   · 의존 = SERVING.ML_MEMBER_RISK_V · ML_SPONSOR_RISK_V · ML_MEMBER_ATTR_ASOF_V · ML_MEMBER_PRED_BRIDGE_V ·
--     ML_FEE_FORECAST_V(21_) · GOLD.FACT_MEMBER_SPONSORSHIP_SPAN · DIM_ORG · DIM_SPONSORSHIP ·
--     WIDE_MEMBER_FEE · FACT_MEMBER_MONTHLY
--   · 롤백 = DROP SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS;
--            DROP SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS;
--            DROP VIEW GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V;
--            DROP VIEW GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V;
-- Co-authored with CoCo
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

-- ▣ 1. 회원 예측(중단·증액·미납) × 7축
--   grain = 기준월 × 회원 × 7축 조합(기준월 말 활동 약정을 축 조합으로 묶는다).
--   회원이 여러 조합에 걸치면 여러 행이다 ⇒ 회원수는 DISTINCT · 기대 회원수는 MEMBER_WEIGHT 가중합.
--   기준월 말 활동 약정이 없는 예측 회원은 축이 전부 NULL 인 1행(R2-7 · 값 창작 금지).
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

-- ▣ 2. 회비 예측 × 7축 배분 추정
--   회비 예측 모델은 캠페인카테고리 집계 시계열이다(회원 단위 아님) ⇒ 7축은 실적 비중 배분 추정이다.
--   비중 = 카테고리 안에서 직전 12개월(기준월 포함) 회비 납입액의 7축 조합 비중.
--   납입 행의 축 = 그 달 활동 중인 같은 회원 × 같은 후원사업 약정(SPAN · 약정금액 최대 1건).
--   카테고리 = 그 약정의 ACQ_CMPGN_CTGR_CD(SPAN 기준 · 사용자 결정 ②).
--   실적 비중이 없는 카테고리는 축이 전부 NULL · IS_ALLOCATED = FALSE · 비중 1 인 1행(예측 합 보존).
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V (
    STDR_MT            COMMENT '예측 실행 기준월(YYYYMM)',
    CMPGN_CTGR_CD      COMMENT '캠페인카테고리코드(예측 계열)',
    CMPGN_CTGR_NAME    COMMENT '캠페인카테고리명(ML_FEE_FORECAST_V). NULL = 원천 마스터에 이름 없음',
    FORECAST_MONTH_KEY COMMENT '예측월(YYYYMM)',
    NEW_EXISTING       COMMENT '신규/기존(납입월 회원 월실적 FACT_MEMBER_MONTHLY.NEW_EXISTING_FLAG). NULL = 배분 불가 행 또는 그 달 월실적 없음',
    HQ_BRANCH_NM       COMMENT '본부지부 3분류(본부/지부/기타). NULL = 배분 불가 행',
    HQ_BRANCH_SRC_NM   COMMENT '본부지부 원값(DIM_ORG.ACMSLT_DIV_GROUP_NM 8종). NULL = 배분 불가 행',
    SPONSORSHIP_NAME   COMMENT '후원사업명(DIM_SPONSORSHIP). NULL = 배분 불가 행 또는 차원 미매핑',
    CPR_DIV_NM         COMMENT '법인(SPAN.ACQ_CPR_DIV_NM). NULL = 배분 불가 행',
    CMMN_BRND_NM       COMMENT '공통브랜드(SPAN.ACQ_CMMN_BRND_NM). NULL = 배분 불가 행 또는 원천 값 없음',
    MKTG_CMPGN_NM      COMMENT '마케팅캠페인명(SPAN.ACQ_MKTG_CMPGN_NM). NULL = 배분 불가 행 또는 원천 값 없음',
    IS_ALLOCATED       COMMENT 'TRUE = 실적 비중으로 배분됨 · FALSE = 그 카테고리에 직전 12개월 매칭 납입 실적이 없어 배분 불가(예측 전액이 이 1행)',
    ALLOC_SHARE        COMMENT '카테고리 내 7축 조합 비중 0~1(카테고리별 합 = 1)',
    ALLOC_FORECAST_AMT COMMENT '배분 추정 회비(원) = 카테고리 예측 × 비중 — 🔴 모델 예측치가 아니라 실적 비중 배분 추정치',
    ALLOC_LOWER        COMMENT '배분 하한(원) = 카테고리 95% 하한 × 비중',
    ALLOC_UPPER        COMMENT '배분 상한(원) = 카테고리 95% 상한 × 비중'
)
  COMMENT = 'ML 캠페인카테고리 회비 예측 × 7축 실적 비중 배분 추정. grain = 기준월 × 카테고리 × 예측월 × 7축 조합. 비중 원천 = GOLD.WIDE_MEMBER_FEE 직전 12개월 납입 × FACT_MEMBER_SPONSORSHIP_SPAN 활동 약정.'
AS
WITH fc AS (
    SELECT STDR_MT, CMPGN_CTGR_CD::VARCHAR AS CMPGN_CTGR_CD, CMPGN_CTGR_NAME, FORECAST_MONTH_KEY,
           FORECAST_AMT, FORECAST_LOWER, FORECAST_UPPER
    FROM GN_DW.SERVING.ML_FEE_FORECAST_V
), mt AS (
    SELECT DISTINCT STDR_MT, STDR_MT::INT AS MK FROM fc
), w AS (
    SELECT mt.STDR_MT, w.MONTH_KEY, w.MEMBER_DK, w.SPONSORSHIP_SK, SUM(w.PAID_FEE) AS AMT
    FROM GN_DW.GOLD.WIDE_MEMBER_FEE w
    JOIN mt
      ON w.MONTH_KEY <= mt.MK
     AND w.MONTH_KEY > mt.MK - 100
    WHERE w.PAID_FEE > 0
    GROUP BY 1, 2, 3, 4
), j AS (
    SELECT w.STDR_MT, w.MONTH_KEY, w.MEMBER_DK, w.AMT,
           s.ACQ_CMPGN_CTGR_CD::VARCHAR AS CMPGN_CTGR_CD,
           s.SPNSR_ACMSLT_DEPT_CD, s.SPONSORSHIP_SK,
           s.ACQ_CPR_DIV_NM, s.ACQ_CMMN_BRND_NM, s.ACQ_MKTG_CMPGN_NM
    FROM w
    JOIN GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN s
      ON s.MEMBER_DK = w.MEMBER_DK
     AND s.SPONSORSHIP_SK = w.SPONSORSHIP_SK
     AND s.START_MONTH_KEY <= w.MONTH_KEY
     AND (s.DSCNTC_MONTH_KEY IS NULL OR s.DSCNTC_MONTH_KEY > w.MONTH_KEY)
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY w.STDR_MT, w.MONTH_KEY, w.MEMBER_DK, w.SPONSORSHIP_SK
        ORDER BY s.SPNSR_AMT DESC NULLS LAST, s.SPNSR_NO
    ) = 1
), base AS (
    SELECT j.STDR_MT, j.CMPGN_CTGR_CD,
           fm.NEW_EXISTING_FLAG::STRING AS NEW_EXISTING,
           CASE
               WHEN o.ACMSLT_DIV_GROUP_NM IN ('본부', '시도본부', '시도본부 및 중앙', '본부(사복)') THEN '본부'
               WHEN o.ACMSLT_DIV_GROUP_NM IN ('지부', '지부(사복)') THEN '지부'
               WHEN o.ACMSLT_DIV_GROUP_NM IS NOT NULL THEN '기타'
           END AS HQ_BRANCH_NM,
           o.ACMSLT_DIV_GROUP_NM AS HQ_BRANCH_SRC_NM,
           ds.SPONSORSHIP_NAME,
           j.ACQ_CPR_DIV_NM AS CPR_DIV_NM,
           j.ACQ_CMMN_BRND_NM AS CMMN_BRND_NM,
           j.ACQ_MKTG_CMPGN_NM AS MKTG_CMPGN_NM,
           SUM(j.AMT) AS AMT
    FROM j
    LEFT JOIN GN_DW.GOLD.FACT_MEMBER_MONTHLY fm
      ON fm.MEMBER_DK = j.MEMBER_DK
     AND fm.MONTH_KEY = j.MONTH_KEY
    LEFT JOIN GN_DW.GOLD.DIM_ORG o
      ON o.ORG_DK = ABS(HASH(j.SPNSR_ACMSLT_DEPT_CD))
    LEFT JOIN GN_DW.GOLD.DIM_SPONSORSHIP ds
      ON ds.SPONSORSHIP_SK = j.SPONSORSHIP_SK
    WHERE j.CMPGN_CTGR_CD IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
), sh AS (
    SELECT b.*, TRUE AS IS_ALLOCATED,
           AMT / SUM(AMT) OVER (PARTITION BY STDR_MT, CMPGN_CTGR_CD) AS SHARE
    FROM base b
), k AS (
    SELECT DISTINCT STDR_MT, CMPGN_CTGR_CD FROM fc
), sh_full AS (
    SELECT STDR_MT, CMPGN_CTGR_CD, NEW_EXISTING, HQ_BRANCH_NM, HQ_BRANCH_SRC_NM, SPONSORSHIP_NAME,
           CPR_DIV_NM, CMMN_BRND_NM, MKTG_CMPGN_NM, IS_ALLOCATED, SHARE
    FROM sh
    WHERE (STDR_MT, CMPGN_CTGR_CD) IN (SELECT STDR_MT, CMPGN_CTGR_CD FROM k)
    UNION ALL
    SELECT k.STDR_MT, k.CMPGN_CTGR_CD,
           NULL, NULL, NULL, NULL, NULL, NULL, NULL,
           FALSE, 1
    FROM k
    WHERE NOT EXISTS (
        SELECT 1 FROM sh
        WHERE sh.STDR_MT = k.STDR_MT AND sh.CMPGN_CTGR_CD = k.CMPGN_CTGR_CD
    )
)
SELECT f.STDR_MT, f.CMPGN_CTGR_CD, f.CMPGN_CTGR_NAME, f.FORECAST_MONTH_KEY,
       s.NEW_EXISTING, s.HQ_BRANCH_NM, s.HQ_BRANCH_SRC_NM, s.SPONSORSHIP_NAME,
       s.CPR_DIV_NM, s.CMMN_BRND_NM, s.MKTG_CMPGN_NM,
       s.IS_ALLOCATED, s.SHARE,
       f.FORECAST_AMT * s.SHARE,
       f.FORECAST_LOWER * s.SHARE,
       f.FORECAST_UPPER * s.SHARE
FROM fc f
JOIN sh_full s
  ON s.STDR_MT = f.STDR_MT
 AND s.CMPGN_CTGR_CD = f.CMPGN_CTGR_CD;

-- ▣ 3. SV — 회원 예측 7축
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS
  TABLES (
    pa AS GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V
      WITH SYNONYMS ('회원 예측 7축', '증액 중단 미납 예측 축별', '회원예측 세부축')
      COMMENT = 'ML 회원예측(중단·증액) + 미납 실적 × 7축 조합(base: SERVING.ML_MEMBER_PRED_AXIS_V). [Grain: 기준월 × 회원 × 7축 조합]. [축: 기준월 말 활동 약정 기준 신규기존·본부지부·후원사업·법인·공통브랜드·캠페인카테고리·마케팅캠페인명]. [주의: 회원당 여러 행 · 회원수는 중복제거 · 기대 회원수는 MEMBER_WEIGHT 가중]. [원천: ML 예측 → SERVING.ML_MEMBER_RISK_V · ML_SPONSOR_RISK_V · 약정 → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].'
  )
  DIMENSIONS (
    pa.STDR_MT AS pa.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '모델 실행월')
      COMMENT = '모델 실행 기준월(YYYYMM 문자열). 🔴 여러 기준월을 합산하지 않는다 — 미지정 시 최신 기준월 하나로 한정한다.',
    pa.MBER_NO AS pa.MBER_NO
      WITH SYNONYMS ('회원번호', '회원')
      COMMENT = '회원번호. 회원수는 이 축의 중복제거로 센다.',
    pa.NEW_EXISTING AS pa.NEW_EXISTING
      WITH SYNONYMS ('신규기존', '신규/기존', '신규기존구분')
      COMMENT = '신규/기존(회원 월실적 · 회원 축). 🔴 약정 축이 아니라 회원 축이다.',
    pa.HQ_BRANCH_NM AS pa.HQ_BRANCH_NM
      WITH SYNONYMS ('본부지부', '본부/지부', '본부지부구분', '부서구분')
      COMMENT = '본부지부 3분류. 실제값 3종: ''본부''·''지부''·''기타''. 기타 = 협력시설·지부외. 원천 8종이 필요하면 HQ_BRANCH_SRC_NM.',
    pa.HQ_BRANCH_SRC_NM AS pa.HQ_BRANCH_SRC_NM
      WITH SYNONYMS ('본부지부 원값', '실적부서 구분')
      COMMENT = '본부지부 원값 8종(DIM_ORG.ACMSLT_DIV_GROUP_NM). 사용자가 세부 구분을 요청할 때만 쓴다.',
    pa.SPONSORSHIP_NAME AS pa.SPONSORSHIP_NAME
      WITH SYNONYMS ('후원사업', '후원사업구분', '후원사업명')
      COMMENT = '기준월 말 활동 약정의 후원사업명.',
    pa.CPR_DIV_NM AS pa.CPR_DIV_NM
      WITH SYNONYMS ('법인', '법인구분', '사단법인')
      COMMENT = '활동 약정의 법인(약정 테이블 ACQ_CPR_DIV_NM). 실제값 3종: ''통합''·''사단''·''사복''.',
    pa.CMMN_BRND_NM AS pa.CMMN_BRND_NM
      WITH SYNONYMS ('공통브랜드')
      COMMENT = '활동 약정의 획득 공통브랜드.',
    pa.CMPGN_CTGR_NM AS pa.CMPGN_CTGR_NM
      WITH SYNONYMS ('캠페인카테고리', '주요캠페인')
      COMMENT = '활동 약정의 획득 캠페인카테고리.',
    pa.MKTG_CMPGN_NM AS pa.MKTG_CMPGN_NM
      WITH SYNONYMS ('마케팅캠페인명', '마케팅캠페인', '마케팅캠페인명구분')
      COMMENT = '활동 약정의 획득 마케팅캠페인명. 🔴 SV_ML_INC_CAMPAIGN 의 MSTR 개발 귀속 마케팅캠페인과 기준이 다르다.',
    pa.CHURN_GRADE AS pa.CHURN_GRADE
      WITH SYNONYMS ('중단위험 등급', '중단 등급')
      COMMENT = '회원 단위 중단위험 등급. 실제값 3종: ''고위험''·''주의''·''일반''.',
    pa.INC_CLASS AS pa.INC_CLASS
      WITH SYNONYMS ('증액 예측 판정')
      COMMENT = '증액 모델 판정 0/1. 🔴 ''1'' 이 극소수라 비교에 쓰지 않는다.',
    pa.SPONSOR_CHURN_GRADE AS pa.SPONSOR_CHURN_GRADE
      WITH SYNONYMS ('후원건 이탈 등급')
      COMMENT = '이 조합 약정의 후원건 이탈위험 최고 등급(후원건 단위 모델 · 회원 단위 등급과 다른 모델).',
    pa.IS_UNPAID_STDR AS pa.IS_UNPAID_STDR
      WITH SYNONYMS ('기준월 미납 여부', '미납 회원')
      COMMENT = '실적 · 기준월 미납 청구 보유. 🔴 미납 예측 모델은 없다 — 「미납 예측」 질문은 이 실적 상태 × 중단확률로 답하고 그 사실을 밝힌다.'
  )
  METRICS (
    pa.PREDICTED_MEMBERS AS COUNT(DISTINCT pa.MBER_NO)
      WITH SYNONYMS ('예측 대상 회원수', '회원수')
      COMMENT = '예측 대상 회원수(명 · 중복제거).',
    pa.CHURN_HIGH_MEMBERS AS COUNT(DISTINCT CASE WHEN pa.CHURN_GRADE = '고위험' THEN pa.MBER_NO END)
      WITH SYNONYMS ('중단 고위험 회원수')
      COMMENT = '회원 단위 중단위험 고위험 회원수(명 · 중복제거).',
    pa.EXPECTED_CHURN_MEMBERS AS SUM(pa.CHURN_PROB * pa.MEMBER_WEIGHT)
      WITH SYNONYMS ('기대 중단 회원수', '예상 중단 회원수')
      COMMENT = '기대 중단 회원수(명) = 중단확률 × 회원 가중치 합. 어떤 축으로 나눠도 합이 전체와 같다.',
    pa.AVG_CHURN_PROB AS AVG(pa.CHURN_PROB)
      WITH SYNONYMS ('평균 중단확률')
      COMMENT = '중단확률 평균(0~1 · 표기 %). 축 값 안 회원 단순 평균.',
    pa.EXPECTED_INC_MEMBERS AS SUM(pa.INC_PROB * pa.MEMBER_WEIGHT)
      WITH SYNONYMS ('기대 증액 회원수', '예상 증액 회원수')
      COMMENT = '기대 증액 회원수(명) = 증액확률 × 회원 가중치 합. 「N월 증액 건수」가 아니다.',
    pa.AVG_INC_PROB AS AVG(pa.INC_PROB)
      WITH SYNONYMS ('평균 증액확률')
      COMMENT = '증액확률 평균(0~1 · 표기 %).',
    pa.UNPAID_MEMBERS AS COUNT(DISTINCT CASE WHEN pa.IS_UNPAID_STDR THEN pa.MBER_NO END)
      WITH SYNONYMS ('기준월 미납 회원수', '미납 회원수')
      COMMENT = '실적 · 기준월 미납 회원수(명 · 중복제거).',
    pa.UNPAID_HIGH_CHURN_MEMBERS AS COUNT(DISTINCT CASE WHEN pa.IS_UNPAID_STDR AND pa.CHURN_GRADE = '고위험' THEN pa.MBER_NO END)
      WITH SYNONYMS ('미납 중 중단 고위험 회원수')
      COMMENT = '실적 미납 × 예측 중단 고위험 회원수(명). 미납 예측의 대체 지표다.',
    pa.ACTIVE_AGREEMENTS AS SUM(pa.ACTIVE_SPNSR_CNT)
      WITH SYNONYMS ('활동 약정 수')
      COMMENT = '기준월 말 활동 약정 수(건).'
  )
  COMMENT = 'ML 회원예측 × 7축 SV. base=SERVING.ML_MEMBER_PRED_AXIS_V. 「증액·중단·미납 예측을 신규기존·본부지부·후원사업·법인·공통브랜드·캠페인카테고리·마케팅캠페인명별로」 질문에 쓴다. 🔴🔴 머신러닝 예측치이며 실적이 아니다(미납 컬럼만 실적). 🔴 미납 예측 모델은 없다 — 실적 미납 × 중단확률로 답하고 밝힌다. 🔴 머신러닝은 테스트 단계다. 🔴 축 = 기준월 말 활동 약정 기준(증액 MSTR 귀속 기준은 SV_ML_INC_CAMPAIGN). 🔴 회원당 여러 행 — 회원수 중복제거 · 기대 회원수는 가중합.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥에서 쓰는 차원은 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 날짜 필터는 이 시맨틱 뷰에 선언된 차원 이름만 쓴다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(WITH SYNONYMS 첫 항목 · 단위 괄호).
  핵심 규칙: (1) 기준월 미지정 시 최신 기준월(MAX(pa.STDR_MT)) 하나로 한정하고 밝힌다. (2) 회원수는 COUNT(DISTINCT pa.MBER_NO) · 기대 회원수는 SUM(prob * pa.MEMBER_WEIGHT) 로 계산하고 COUNT(*) 를 쓰지 않는다. (3) 요청한 축만 GROUP BY 한다 — 축을 여러 개 요청하면 함께 GROUP BY 한다. (4) 축이 NULL 인 행(활동 약정 없음)은 순위에서 빼고 그 회원수를 따로 밝힌다. (5) 평균 확률 순위는 회원 100명 이상 축 값으로 한정하고 하한을 밝힌다. (6) 🔴 실적 SV 와 조인하지 않는다. (7) 🆕 [O250-D 출력 형식] 모든 출력 열에 한글 별칭(예: "법인" · "본부지부" · "기준월 미납 회원수(명)") · 기대 회원수 ROUND(…, 1) · 확률은 ROUND(AVG(prob)*100, 2) AS "평균 증액확률(%)" 처럼 % 로 낸다 · 차원 열을 지표 열보다 앞에 둔다.';

-- ▣ 4. SV — 회비 예측 7축 배분
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS
  TABLES (
    fx AS GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V
      WITH SYNONYMS ('회비 예측 7축', '회비 예측 축별 배분')
      COMMENT = 'ML 회비 예측 × 7축 실적 비중 배분 추정(base: SERVING.ML_FEE_FORECAST_AXIS_V). [Grain: 기준월 × 캠페인카테고리 × 예측월 × 7축 조합]. [산식: 카테고리 예측 × 직전 12개월 회비 납입 조합 비중]. [원천: ML 회비예측 → SERVING.ML_FEE_FORECAST_V · 비중 → GOLD.WIDE_MEMBER_FEE × FACT_MEMBER_SPONSORSHIP_SPAN].'
  )
  DIMENSIONS (
    fx.STDR_MT AS fx.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월')
      COMMENT = '예측 실행 기준월(YYYYMM). 🔴 여러 기준월 합산은 중복계상이다 — 미지정 시 최신 하나.',
    fx.FORECAST_MONTH_KEY AS fx.FORECAST_MONTH_KEY
      WITH SYNONYMS ('예측월')
      COMMENT = '예측월(YYYYMM).',
    fx.CMPGN_CTGR_NAME AS fx.CMPGN_CTGR_NAME
      WITH SYNONYMS ('캠페인카테고리', '주요캠페인')
      COMMENT = '캠페인카테고리명(예측 계열). 일부는 원천 마스터에 이름이 없어 NULL 이다.',
    fx.NEW_EXISTING AS fx.NEW_EXISTING
      WITH SYNONYMS ('신규기존', '신규/기존', '신규기존구분')
      COMMENT = '납입월 회원 월실적의 신규/기존.',
    fx.HQ_BRANCH_NM AS fx.HQ_BRANCH_NM
      WITH SYNONYMS ('본부지부', '본부/지부', '본부지부구분', '부서구분')
      COMMENT = '본부지부 3분류. 실제값 3종: ''본부''·''지부''·''기타''.',
    fx.HQ_BRANCH_SRC_NM AS fx.HQ_BRANCH_SRC_NM
      WITH SYNONYMS ('본부지부 원값')
      COMMENT = '본부지부 원값 8종. 세부 구분 요청 시만.',
    fx.SPONSORSHIP_NAME AS fx.SPONSORSHIP_NAME
      WITH SYNONYMS ('후원사업', '후원사업구분')
      COMMENT = '후원사업명.',
    fx.CPR_DIV_NM AS fx.CPR_DIV_NM
      WITH SYNONYMS ('법인', '법인구분', '사단법인')
      COMMENT = '약정 법인. 실제값 3종: ''통합''·''사단''·''사복''.',
    fx.CMMN_BRND_NM AS fx.CMMN_BRND_NM
      WITH SYNONYMS ('공통브랜드')
      COMMENT = '약정 획득 공통브랜드.',
    fx.MKTG_CMPGN_NM AS fx.MKTG_CMPGN_NM
      WITH SYNONYMS ('마케팅캠페인명', '마케팅캠페인', '마케팅캠페인명구분')
      COMMENT = '약정 획득 마케팅캠페인명.',
    fx.IS_ALLOCATED AS fx.IS_ALLOCATED
      WITH SYNONYMS ('배분 여부')
      COMMENT = 'FALSE = 실적 비중이 없어 배분 불가인 카테고리 예측(축 NULL). 금액을 따로 밝힌다.'
  )
  METRICS (
    fx.TOTAL_ALLOC_FORECAST_FEE AS SUM(fx.ALLOC_FORECAST_AMT)
      WITH SYNONYMS ('배분 추정 회비', '예측 회비')
      COMMENT = '배분 추정 회비(원). 어떤 축 부분집합으로 나눠도 합 = 카테고리 예측 합. 🔴 추정치.',
    fx.TOTAL_ALLOC_FORECAST_LOWER AS SUM(fx.ALLOC_LOWER)
      WITH SYNONYMS ('배분 하한')
      COMMENT = '배분 하한(원).',
    fx.TOTAL_ALLOC_FORECAST_UPPER AS SUM(fx.ALLOC_UPPER)
      WITH SYNONYMS ('배분 상한')
      COMMENT = '배분 상한(원).'
  )
  COMMENT = 'ML 회비 예측 × 7축 배분 SV. base=SERVING.ML_FEE_FORECAST_AXIS_V. 「회비 예측을 신규기존·본부지부·후원사업·법인·공통브랜드·캠페인카테고리·마케팅캠페인명별로」 질문에 쓴다. 🔴🔴 모델 예측은 캠페인카테고리 단위뿐이다 — 7축 값은 직전 12개월 실적 비중 배분 추정치이며 그렇게 밝힌다. 🔴 단위 = 원. 🔴 기준월 여러 개 합산 금지. 🔴 회비 실적(SV_MEMBER_FEE)과 같은 표에 합산하지 않는다. 기존 축별 배분(SV_ML_FEE_FORECAST FA)과 카테고리 연결 기준이 다르다(이 SV = 약정 테이블 카테고리).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — CTE 안에서는 베이스 컬럼을 SUM 으로 직접 집계한다. (나) CTE 를 거쳐 바깥에서 쓰는 차원은 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 날짜 필터는 이 시맨틱 뷰에 선언된 차원 이름만 쓴다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(WITH SYNONYMS 첫 항목 · 단위 괄호).
  핵심 규칙: (1) 기준월 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (2) 예측월 미지정 시 그 기준월의 예측월 전체 합계를 쓰고 기간을 밝힌다. (3) 요청한 축만 GROUP BY 하고 SUM(fx.ALLOC_FORECAST_AMT) 로 집계한다. (4) IS_ALLOCATED = FALSE 금액은 별도 행 「배분 불가(실적 비중 없음)」로 밝힌다. (5) 금액은 원 단위 반올림 · 🔴 실적 SV 와 조인하지 않는다. (6) 🆕 [O250-D 출력 형식] 모든 출력 열에 한글 별칭 · 차원 열을 지표 열보다 앞에 둔다 · 배분 불가 행은 순위 행과 섞지 않고 맨 끝 1행으로 둔다.';

-- ▣ 5. GRANT
GRANT SELECT ON VIEW GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V TO ROLE GN_DW_SERVICE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS TO ROLE GN_DW_SERVICE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS TO ROLE GN_DW_SERVICE;

-- ▣ 6. 스모크
-- (a) 회원수 = ML_MEMBER_RISK_V 회원수 · 회원별 가중치 합 = 1
SELECT STDR_MT, COUNT(DISTINCT MBER_NO) AS MEM, ROUND(SUM(MEMBER_WEIGHT), 3) AS W_SUM, COUNT(*) AS ROWS_N
FROM GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V
GROUP BY STDR_MT ORDER BY STDR_MT;
-- (b) 회비 배분 합 = 카테고리 예측 합
SELECT a.STDR_MT, a.ALLOC, f.FC, ROUND(a.ALLOC - f.FC, 2) AS DIFF
FROM (SELECT STDR_MT, SUM(ALLOC_FORECAST_AMT) AS ALLOC FROM GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V GROUP BY 1) a
JOIN (SELECT STDR_MT, SUM(FORECAST_AMT) AS FC FROM GN_DW.SERVING.ML_FEE_FORECAST_V GROUP BY 1) f
  ON f.STDR_MT = a.STDR_MT
ORDER BY 1;
