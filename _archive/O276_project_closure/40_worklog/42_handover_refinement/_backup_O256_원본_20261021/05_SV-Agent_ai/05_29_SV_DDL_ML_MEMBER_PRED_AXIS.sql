-- ============================================================================
-- 05_29_SV_DDL_ML_MEMBER_PRED_AXIS.sql — Semantic View DDL 정본: SV_ML_MEMBER_PRED_AXIS (🆕 O250 · O250-E 단독 파일로 이관)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 대상 = ML 회원예측(중단·증액) + 미납 실적 × 7축 (3 Agent · analyst_ml_pred_axis)
--   · 선행 = GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V(21_ML_SERVING_뷰_DDL.sql [O250] 절) ⇒ 🔴 21_ 다음에 실행
--   · 원 배포 파일 = 36_DEPLOY_ML_PRED_7AXIS.sql(이력 보존 · 문면 무변경 이관)
--   · 공통 규약 = 05_0_SV_DDL.sql
-- Co-authored with CoCo
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

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
  핵심 규칙: (1) 기준월 미지정 시 최신 기준월(MAX(pa.STDR_MT)) 하나로 한정하고 밝힌다. (2) 회원수는 COUNT(DISTINCT pa.MBER_NO) · 기대 회원수는 SUM(prob * pa.MEMBER_WEIGHT) 로 계산하고 COUNT(*) 를 쓰지 않는다. (3) 요청한 축만 GROUP BY 한다 — 축을 여러 개 요청하면 함께 GROUP BY 한다. (4) 축이 NULL 인 행(활동 약정 없음)은 순위에서 빼고 그 회원수를 따로 밝힌다. (5) 평균 확률 순위는 회원 100명 이상인 축 값으로 한정하고 하한을 밝힌다. (6) 🔴 실적 SV 와 조인하지 않는다. (7) 🆕 [O250-D 출력 형식] 모든 출력 열에 한글 별칭(예: "법인" · "본부지부" · "기준월 미납 회원수(명)") · 기대 회원수 ROUND(…, 1) · 확률은 ROUND(AVG(prob)*100, 2) AS "평균 증액확률(%)" 처럼 % 로 낸다 · 차원 열을 지표 열보다 앞에 둔다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS TO ROLE GN_DW_SERVICE;

-- 스모크
USE WAREHOUSE GN_DW_ANALYTICS_WH;
SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS
  DIMENSIONS pa.STDR_MT METRICS pa.PREDICTED_MEMBERS, pa.EXPECTED_CHURN_MEMBERS, pa.EXPECTED_INC_MEMBERS);
