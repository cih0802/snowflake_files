-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_ML_FEE_FORECAST_AXIS (🆕 O250 · O250-E 단독 파일로 이관)
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS
-- Run order  : 운영계 #52
-- Depends on : -
-- Issue      : O250, O250-E
-- =============================================================================
-- ============================================================================
-- 05_30_SV_DDL_ML_FEE_FORECAST_AXIS.sql — Semantic View DDL 정본: SV_ML_FEE_FORECAST_AXIS ( O250 · O250-E 단독 파일로 이관)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 대상 = ML 회비 예측 × 7축 실적 비중 배분 추정 (MEMBER·MARKETING · analyst_ml_fee_axis)
--   · 선행 = GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V(21_ML_SERVING_뷰_DDL.sql [O250] 절) ⇒ WARN: 21_ 다음에 실행
--   · 원 배포 파일 = 36_DEPLOY_ML_PRED_7AXIS.sql(이력 보존 · 문면 무변경 이관)
--   · 공통 규약 = 05_0_SV_DDL.sql
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

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
      COMMENT = '납입월 회원 월실적의 신규/기존. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''기존''·''신규''',
    fx.HQ_BRANCH_NM AS fx.HQ_BRANCH_NM
      WITH SYNONYMS ('본부지부', '본부/지부', '본부지부구분', '부서구분')
      COMMENT = '본부지부 3분류. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''본부''·''지부''·''기타''.',
    fx.HQ_BRANCH_SRC_NM AS fx.HQ_BRANCH_SRC_NM
      WITH SYNONYMS ('본부지부 원값')
      COMMENT = '본부지부 원값. 세부 구분 요청 시만. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''본부''·''본부(사복)''·''시도본부''·''시도본부 및 중앙''·''지부''·''지부(사복)''·''지부외''·''협력시설''',
    fx.SPONSORSHIP_NAME AS fx.SPONSORSHIP_NAME
      WITH SYNONYMS ('후원사업', '후원사업구분')
      COMMENT = '후원사업명. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''결식아동지원''·''국내사업''·''국내아동권리보호사업(사단법인)''·''국내아동권리보호사업(사회복지법인)''·''대북지원사업''·''보건의료지원사업''·''복지관후원''·''식수위생지원사업''·''아동복지시설지원''·''아동학대예방''·''재난구호지원사업''·''저소득가정지원''·''전체사업지원''·''좋은이웃''·''좋은이웃(사복)''·''해외교육지원사업''·''해외아동결연''·''해외지역개발사업''·''희망학교지원사업''',
    fx.CPR_DIV_NM AS fx.CPR_DIV_NM
      WITH SYNONYMS ('법인', '법인구분', '사단법인')
      COMMENT = '약정 법인. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''통합''·''사단''·''사복''.',
    fx.CMMN_BRND_NM AS fx.CMMN_BRND_NM
      WITH SYNONYMS ('공통브랜드')
      COMMENT = '약정 획득 공통브랜드. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''교육기관''·''기업''·''뉴미디어''·''대면모금''·''디지털''·''마케팅콜개발''·''방송''·''영상광고''·''재송출''·''지역개발''·''회원 기타''·''회원 오프라인개발''·''회원 온라인개발''·''회원 콜개발''',
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
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다. [공통 규칙 보충 · 이 SV] 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — CTE 안에서는 베이스 컬럼을 SUM 으로 직접 집계한다. CTE 를 거쳐 바깥에서 쓰는 차원은 그 CTE 의 SELECT 목록에 먼저 넣는다. 날짜 필터는 이 시맨틱 뷰에 선언된 차원 이름만 쓴다. 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(WITH SYNONYMS 첫 항목 · 단위 괄호). (R-SV3) 「미배분」·「배분 불가」처럼 구분 값을 가진 행은 합계·소계 행이 아니다 — 아래 핵심 규칙이 그 행을 따로 붙이라고 하면 공통 규칙의 합계·소계 행 금지와 충돌하지 않는다.
  핵심 규칙: (1) 기준월 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (2) 예측월 미지정 시 그 기준월의 예측월 전체 합계를 쓰고 기간을 밝힌다. (3) 요청한 축만 GROUP BY 하고 SUM(fx.ALLOC_FORECAST_AMT) 로 집계한다. (4) IS_ALLOCATED = FALSE 금액은 별도 행 「배분 불가(실적 비중 없음)」로 밝힌다. (5) 금액은 원 단위 반올림 · 🔴 실적 SV 와 조인하지 않는다. (6) 🆕 [O250-D 출력 형식] 모든 출력 열에 한글 별칭 · 차원 열을 지표 열보다 앞에 둔다 · 배분 불가 행은 순위 행과 섞지 않고 맨 끝 1행으로 둔다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS TO ROLE GN_DW_AR_SRC_COMMON;  -- O270 원천별 접근 역할
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS TO ROLE GN_DW_SERVICE;

-- 스모크
USE WAREHOUSE GN_DW_ANALYTICS_WH;
SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS
  DIMENSIONS fx.STDR_MT, fx.IS_ALLOCATED METRICS fx.TOTAL_ALLOC_FORECAST_FEE);
