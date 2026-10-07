-- ============================================================================
-- 05_13_SV_DDL_DEPT_AGGR.sql — Semantic View DDL 정본: SV_DVLP_GOAL_ACMSLT · SV_MBRFEE_PRDT_ACTL · SV_SPNSR_CLS_AGGR
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT. 파일 단독 실행 가능.
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql
--   · 🆕 2026-10-02 O200-B 신설. base = GOLD dbt 뷰 3종(models/gold/wide/ · O200-A).
--       원천 = 부서 자체 수식 집계(ML 모델 산출물 아님) · 요청 부서 = 50_handoff/06번 SILVER DDL 머리말.
--       ~~SV_DVLP_GOAL_ACMSLT = 기획실 → AGENT_EXECUTIVE 도구 · 나머지 2종 = 회원실 → AGENT_MEMBER 도구.~~
--       🔴 [2026-10-03 O200-C 정정] 실제 배선 = **3종 전부 AGENT_MEMBER**(스펙 · 09_2 [0] · 라이브 VERSION$4 일치).
--          EXECUTIVE 스펙에는 SV_DVLP_GOAL_ACMSLT 참조가 0건이다 — 위 줄은 배선 전 계획 문안이었다.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

-- ----------------------------------------------------------------------------
-- [1] SV_DVLP_GOAL_ACMSLT — 기획실 연간 개발 목표·실적
-- ----------------------------------------------------------------------------
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_DVLP_GOAL_ACMSLT
  TABLES (
    ga AS GN_DW.GOLD.WIDE_DVLP_GOAL_ACMSLT
      PRIMARY KEY (MONTH_KEY, DEPT_DIV_NM, NEW_EXST_DIV_NM, SPNSR_BSNS_GRP_NM)
      WITH SYNONYMS ('개발 목표', '개발 실적', '목표 대비 실적', '개발 달성률', '기획실 개발 목표')
      COMMENT = '기획실 연간 개발 목표·실적 부서 집계 (base: GOLD.WIDE_DVLP_GOAL_ACMSLT). [Grain: 월 × 부서구분 × 신규기존 × 후원사업그룹]. [활성 지표: 목표건수/실적건수/달성률]. [주의: 부서 자체 수식 집계이며 ML 예측 아님, 미도래 월 실적은 NULL]. [원천: 기획실 집계 → SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA].'
  )
  DIMENSIONS (
    ga.MONTH_KEY AS ga.MONTH_KEY
      WITH SYNONYMS ('기준월', '연월')
      COMMENT = '기준월 YYYYMM(정수).',
    ga.CAL_YEAR AS ga.CAL_YEAR
      WITH SYNONYMS ('연도', '사업연도')
      COMMENT = '연도. 🔴 실제값은 열거하지 않는다 — 조회해서 확인한다.',
    ga.CAL_MONTH AS ga.CAL_MONTH
      WITH SYNONYMS ('월')
      COMMENT = '월(1~12).',
    ga.DEPT_DIV_NM AS ga.DEPT_DIV_NM
      WITH SYNONYMS ('부서', '부서구분')
      COMMENT = '부서 구분 명(기획실 집계 기준 · DIM_ORG 부서와 같은 조직으로 단정하지 않는다).',
    ga.NEW_EXST_DIV_NM AS ga.NEW_EXST_DIV_NM
      WITH SYNONYMS ('신규기존', '신규/기존')
      COMMENT = '신규기존구분명.',
    ga.SPNSR_BSNS_GRP_NM AS ga.SPNSR_BSNS_GRP_NM
      WITH SYNONYMS ('후원사업그룹', '후원사업')
      COMMENT = '후원 사업 그룹 명.'
  )
  METRICS (
    ga.TOTAL_GOAL_CNT AS SUM(ga.GOAL_CNT)
      WITH SYNONYMS ('목표 건수', '개발 목표 건수')
      COMMENT = '개발 목표 건수 합계(건).',
    ga.TOTAL_ACMSLT_CNT AS SUM(ga.ACMSLT_CNT)
      WITH SYNONYMS ('실적 건수', '개발 실적 건수')
      COMMENT = '개발 실적 건수 합계(건). 미도래 월은 NULL 이라 합계에서 빠진다.',
    ga.GOAL_TO_DATE_CNT AS SUM(CASE WHEN ga.ACMSLT_CNT IS NOT NULL THEN ga.GOAL_CNT END)
      WITH SYNONYMS ('실적월 목표 건수', '누적 목표')
      COMMENT = '실적이 있는 월에 한정한 목표 건수 합계(건) — 달성률의 분모.',
    ga.ACMSLT_RATE AS SUM(ga.ACMSLT_CNT) / NULLIF(SUM(CASE WHEN ga.ACMSLT_CNT IS NOT NULL THEN ga.GOAL_CNT END), 0)
      WITH SYNONYMS ('달성률', '목표 달성률')
      COMMENT = '[비가산] 달성률 = 실적 ÷ 실적이 있는 월의 목표. 연간 목표 대비 진척률은 TOTAL_ACMSLT_CNT ÷ TOTAL_GOAL_CNT 로 따로 계산한다.'
  )
  COMMENT = '기획실 연간 개발 목표·실적 SV. base=GOLD.WIDE_DVLP_GOAL_ACMSLT. 🔴🔴 부서 자체 수식 집계이며 ML 예측이 아니다 — ML 개발금액 예측(SV_ML_DVLP_FORECAST · 만원)과 같은 표에 합산하지 않는다. 🔴 단위는 건이다(금액 아님). 🔴 미도래 월의 실적은 NULL 이며 0 이 아니다. ⚠️ 부서구분은 기획실 집계 기준이며 GN_DW 조직 차원과 같은 조직이라 단정하지 않는다. 활성: 목표·실적·달성률 · 월/부서구분/신규기존/후원사업그룹 축. 비활성: 금액 목표(원천 부재) · 본부·지부 분해(원천 축 부재).'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **달성률을 물으면 ACMSLT_RATE 정의식(실적 ÷ 실적이 있는 월의 목표)을 쓴다** — 연간 목표 전체를 분모로 쓰면 미도래 월 때문에 과소가 된다. 연간 진척률을 물으면 두 값을 구분해 함께 밝힌다. (2) 🔴 **미도래 월 실적을 0 으로 채우지 않는다** — NULL 이다. (3) 🔴 **단위는 건이다** — 금액 지표나 ML 개발금액 예측(만원)과 합산하지 않는다. (4) 🔴 **ML 예측치와 섞지 않는다** — 이 SV 는 부서 자체 집계다. (5) **연도 미지정 시 데이터에 존재하는 최신 연도로 한정하고 밝힌다.** (6) 🔴 **본부·지부별 분해를 물으면 SQL 을 만들지 않는다** — 축이 없다고 답하고 부서구분·후원사업그룹별 분해를 안내한다. (7) 적용 조건(그룹 미지정 시): 최신 연도로 한정해 월별 목표·실적·달성률을 반환한다. (8) 🔴 metric 이름을 ga 컬럼처럼 참조하지 않는다 — 정의식(SUM(ga.ACMSLT_CNT) 등)으로 집계한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_DVLP_GOAL_ACMSLT TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_DVLP_GOAL_ACMSLT TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_DVLP_GOAL_ACMSLT TO ROLE GN_DW_SERVICE;

-- ----------------------------------------------------------------------------
-- [2] SV_MBRFEE_PRDT_ACTL — 회원실 연간 회비 예측·실측
-- ----------------------------------------------------------------------------
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MBRFEE_PRDT_ACTL
  TABLES (
    mp AS GN_DW.GOLD.WIDE_MBRFEE_PRDT_ACTL
      PRIMARY KEY (MONTH_KEY, DATA_TYPE_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM)
      WITH SYNONYMS ('회비 예측 실측', '회원실 회비예측', '연간 회비 예측', '회비 계획')
      COMMENT = '회원실 연간 회비 예측·실측 (base: GOLD.WIDE_MBRFEE_PRDT_ACTL). [Grain: 월 × 예측실측구분 × 후원사업그룹 × 신규기존 × 본부지부그룹]. [활성 지표: 개발·중단·감액 건수 · 회비 · 누계 · 비율]. [주의: 부서 자체 수식이며 ML 예측 아님, 예측/실측 행 혼재, 누계 컬럼 월 합산 금지]. [원천: 회원실 집계 → SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA].'
  )
  DIMENSIONS (
    mp.MONTH_KEY AS mp.MONTH_KEY
      WITH SYNONYMS ('기준월', '연월')
      COMMENT = '기준월 YYYYMM(정수).',
    mp.CAL_YEAR AS mp.CAL_YEAR
      WITH SYNONYMS ('연도', '사업연도')
      COMMENT = '연도.',
    mp.CAL_MONTH AS mp.CAL_MONTH
      WITH SYNONYMS ('월')
      COMMENT = '월(1~12).',
    mp.DATA_TYPE_NM AS mp.DATA_TYPE_NM
      WITH SYNONYMS ('예측실측구분', '예측/실측', '구분')
      COMMENT = '예측 실측 구분(예측/실측). 🔴 반드시 WHERE 로 고정하거나 GROUP BY 에 넣는다.',
    mp.IS_FORECAST AS mp.IS_FORECAST
      WITH SYNONYMS ('예측여부')
      COMMENT = '예측행 여부(DATA_TYPE_NM=예측).',
    mp.SPNSR_BSNS_GRP_NM AS mp.SPNSR_BSNS_GRP_NM
      WITH SYNONYMS ('후원사업그룹', '후원사업')
      COMMENT = '후원 사업 그룹 명.',
    mp.NEW_EXST_DIV_NM AS mp.NEW_EXST_DIV_NM
      WITH SYNONYMS ('신규기존', '신규/기존')
      COMMENT = '신규기존구분명.',
    mp.HDQ_BRNCH_GRP_NM AS mp.HDQ_BRNCH_GRP_NM
      WITH SYNONYMS ('본부지부', '본부/지부', '지부그룹')
      COMMENT = '본부 지부 그룹 명(회원실 집계 기준).'
  )
  METRICS (
    mp.TOTAL_DVLP_CNT AS SUM(mp.DVLP_CNT)
      WITH SYNONYMS ('개발건수', '월 개발건수')
      COMMENT = '월 개발건수 합계(건 · 월 합산 가능).',
    mp.TOTAL_DSCNTC_CNT AS SUM(mp.DSCNTC_CNT)
      WITH SYNONYMS ('중단건수')
      COMMENT = '월 중단건수 합계(건 · 월 합산 가능).',
    mp.TOTAL_ADJ_DSCNTC_CNT AS SUM(mp.ADJ_DSCNTC_CNT)
      WITH SYNONYMS ('조정 중단건수')
      COMMENT = '월 조정 중단건수 합계(건).',
    mp.TOTAL_RDCAMT_CNT AS SUM(mp.RDCAMT_CNT)
      WITH SYNONYMS ('감액건수')
      COMMENT = '월 감액건수 합계(건).',
    mp.TOTAL_ADJ_RDCAMT_CNT AS SUM(mp.ADJ_RDCAMT_CNT)
      WITH SYNONYMS ('조정 감액건수')
      COMMENT = '월 조정 감액건수 합계(건).',
    mp.TOTAL_SPNSR_BSNS_CHN_DEC_CNT AS SUM(mp.SPNSR_BSNS_CHN_DEC_CNT)
      WITH SYNONYMS ('후원사업변경 감소건수')
      COMMENT = '월 후원사업변경 감소건수 합계(건).',
    mp.TOTAL_ADJ_MBRFEE_AMT AS SUM(mp.ADJ_MBRFEE_AMT)
      WITH SYNONYMS ('조정 회비', '월 회비')
      COMMENT = '월 조정 회비 합계(원 · 월 합산 가능).',
    mp.TOTAL_MBRFEE_DIFF_AMT AS SUM(mp.MBRFEE_DIFF_AMT)
      WITH SYNONYMS ('회비 차액')
      COMMENT = '회비 차액 합계(원). 원천 정의 그대로이며 산식을 추정해 설명하지 않는다.',
    mp.CMLT_DVLP_CNT_AT_MONTH AS SUM(mp.CMLT_DVLP_CNT)
      WITH SYNONYMS ('누적개발건수', '연누계 개발건수')
      COMMENT = '🔴 누계(건). 한 기준월로 고정해서만 쓴다 — 여러 달을 더하면 중복계상이다.',
    mp.CMLT_MBRFEE_AMT_AT_MONTH AS SUM(mp.CMLT_MBRFEE_AMT)
      WITH SYNONYMS ('누적 회비', '연누계 회비')
      COMMENT = '🔴 누계(원). 한 기준월로 고정해서만 쓴다.',
    mp.ADJ_CMLT_MBRFEE_AMT_AT_MONTH AS SUM(mp.ADJ_CMLT_MBRFEE_AMT)
      WITH SYNONYMS ('조정 누계회비')
      COMMENT = '🔴 누계(원). 한 기준월로 고정해서만 쓴다.',
    mp.ADJ_CMLT_DSCNTC_CNT_AT_MONTH AS SUM(mp.ADJ_CMLT_DSCNTC_CNT)
      WITH SYNONYMS ('조정 누계 중단건수')
      COMMENT = '🔴 누계(건). 한 기준월로 고정해서만 쓴다.',
    mp.CMLT_ACT_MBER_CNT_AT_MONTH AS SUM(mp.CMLT_ACT_MBER_CNT)
      WITH SYNONYMS ('누적 활동회원건수')
      COMMENT = '🔴 누계(건). 한 기준월로 고정해서만 쓴다.',
    mp.CMLT_EOM_ACT_MBER_CNT_AT_MONTH AS SUM(mp.CMLT_EOM_ACT_MBER_CNT)
      WITH SYNONYMS ('누적 월말활동회원건수')
      COMMENT = '🔴 누계(건). 한 기준월로 고정해서만 쓴다.',
    mp.AVG_DSCNTC_RT AS AVG(mp.DSCNTC_RT)
      WITH SYNONYMS ('중단율')
      COMMENT = '[비가산] 중단율(0~1) 행 평균. 그룹을 묶으면 단순평균이 되어 원천 비율과 다르다.',
    mp.AVG_RDCAMT_RT AS AVG(mp.RDCAMT_RT)
      WITH SYNONYMS ('감액율')
      COMMENT = '[비가산] 감액율(0~1) 행 평균.',
    mp.AVG_ACT_RT AS AVG(mp.ACT_RT)
      WITH SYNONYMS ('활동율')
      COMMENT = '[비가산] 활동율(0~1) 행 평균.',
    mp.AVG_CMLT_PAY_RT AS AVG(mp.CMLT_PAY_RT)
      WITH SYNONYMS ('누계납입율')
      COMMENT = '[비가산] 누계납입율(0~1) 행 평균.'
  )
  COMMENT = '회원실 연간 회비 예측·실측 SV. base=GOLD.WIDE_MBRFEE_PRDT_ACTL. 🔴🔴 **예측행과 실측행이 함께 있다** — DATA_TYPE_NM 을 고정하거나 그룹에 넣지 않으면 예측과 실측이 합산된다. 🔴🔴 부서 자체 수식이며 ML 예측이 아니다 — ML 회비 예측(SV_ML_FEE_FORECAST)·회비 실적(SV_MEMBER_FEE)과 같은 표에 합산하지 않는다. 🔴🔴 누계(_AT_MONTH) 지표는 한 기준월로 고정해서만 쓴다. 🔴 비율(_RT)은 비가산이다. 단위 = 건수는 건 · 금액은 원. 활성: 개발·중단·감액 건수 · 조정회비 · 누계 · 비율 · 월/구분/후원사업그룹/신규기존/본부지부 축. 비활성: 회원 단위 분해(원천 grain 이 집계).'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **DATA_TYPE_NM 을 반드시 WHERE 로 고정하거나 GROUP BY 에 넣는다.** 「예측」 질문은 ''예측'', 「실적·실측」 질문은 ''실측'' 이다. 예측 대비 실측을 물으면 두 값을 열로 나란히 두고 각각을 밝힌다. (2) 🔴🔴 **누계 지표(이름이 _AT_MONTH 로 끝남)는 MONTH_KEY 하나로 고정한다** — 여러 달을 더하지 않는다. 연간 누계를 물으면 해당 연도의 가장 늦은 월 하나를 쓰고 그 월을 밝힌다. (3) 🔴 **비율(AVG_*_RT)을 합하지 않는다** — 그룹별로 제시하고, 여러 그룹을 묶은 평균은 단순평균임을 밝힌다. 비율은 백분율로 바꿔 표기해도 된다. (4) 🔴 **ML 예측과 섞지 않는다** — 이 SV 는 회원실 자체 수식이다. (5) **단위를 밝힌다** — 건수는 건, 금액은 원. (6) **연도 미지정 시 데이터에 존재하는 최신 연도로 한정하고 밝힌다.** (7) 🔴 **회원 단위·캠페인 단위 분해를 물으면 SQL 을 만들지 않는다** — 이 SV 의 grain 이 집계라고 답한다. (8) 적용 조건(그룹 미지정 시): 최신 연도로 한정해 월별 예측·실측 조정회비와 개발건수를 나란히 반환한다. (9) 🔴 metric 이름을 mp 컬럼처럼 참조하지 않는다 — 정의식(SUM(mp.ADJ_MBRFEE_AMT) 등)으로 집계한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MBRFEE_PRDT_ACTL TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MBRFEE_PRDT_ACTL TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MBRFEE_PRDT_ACTL TO ROLE GN_DW_SERVICE;

-- ----------------------------------------------------------------------------
-- [3] SV_SPNSR_CLS_AGGR — 회원실 회비예측 월간 후원 분류별 집계
-- ----------------------------------------------------------------------------
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_SPNSR_CLS_AGGR
  TABLES (
    sc AS GN_DW.GOLD.WIDE_SPNSR_CLS_AGGR
      PRIMARY KEY (MONTH_KEY, AGGR_TY_NM, CPR_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM)
      WITH SYNONYMS ('후원 분류별 집계', '회비예측 분류 집계', '후원분류 예측값')
      COMMENT = '회원실 회비예측 월간 후원 분류별 집계 (base: GOLD.WIDE_SPNSR_CLS_AGGR). [Grain: 월 × 집계유형 × 법인 × 후원사업그룹 × 신규기존 × 본부지부그룹]. [활성 지표: 예측값1/예측값2]. [주의: 집계유형 간 합산 금지, 부서 자체 수식이며 ML 예측 아님]. [원천: 회원실 집계 → SILVER.MM_SPNSR_CLS_AGGR_DATA].'
  )
  DIMENSIONS (
    sc.MONTH_KEY AS sc.MONTH_KEY
      WITH SYNONYMS ('기준월', '연월')
      COMMENT = '기준월 YYYYMM(정수).',
    sc.CAL_YEAR AS sc.CAL_YEAR
      WITH SYNONYMS ('연도')
      COMMENT = '연도.',
    sc.CAL_MONTH AS sc.CAL_MONTH
      WITH SYNONYMS ('월')
      COMMENT = '월(1~12).',
    sc.AGGR_TY_NM AS sc.AGGR_TY_NM
      WITH SYNONYMS ('집계유형', '분류', '후원분류')
      COMMENT = '집계 유형명(감액/개발/중단/활동/회비). 🔴 반드시 WHERE 로 고정하거나 GROUP BY 에 넣는다.',
    sc.CPR_NM AS sc.CPR_NM
      WITH SYNONYMS ('법인', '법인명')
      COMMENT = '법인명.',
    sc.SPNSR_BSNS_GRP_NM AS sc.SPNSR_BSNS_GRP_NM
      WITH SYNONYMS ('후원사업그룹', '후원사업')
      COMMENT = '후원 사업 그룹 명.',
    sc.NEW_EXST_DIV_NM AS sc.NEW_EXST_DIV_NM
      WITH SYNONYMS ('신규기존', '신규/기존')
      COMMENT = '신규기존구분명.',
    sc.HDQ_BRNCH_GRP_NM AS sc.HDQ_BRNCH_GRP_NM
      WITH SYNONYMS ('본부지부', '본부/지부')
      COMMENT = '본부 지부 그룹 명(회원실 집계 기준).'
  )
  METRICS (
    sc.TOTAL_VALUE1 AS SUM(sc.VALUE1)
      WITH SYNONYMS ('예측값1', '후원분류집계 예측값1')
      COMMENT = '후원분류집계 예측값1 합계. 🔴 집계유형 하나로 고정해서만 쓴다(유형마다 값의 척도가 다르다 · 단위는 원천 미기재).',
    sc.TOTAL_VALUE2 AS SUM(sc.VALUE2)
      WITH SYNONYMS ('예측값2', '후원분류집계 예측값2')
      COMMENT = '후원분류집계 예측값2 합계. ⚠️회비 유형에만 값이 있고 나머지 유형은 NULL 이다(0 이 아니다).'
  )
  COMMENT = '회원실 회비예측 월간 후원 분류별 집계 SV. base=GOLD.WIDE_SPNSR_CLS_AGGR. 🔴🔴 **AGGR_TY_NM(감액/개발/중단/활동/회비)을 고정하거나 그룹에 넣는다** — 유형마다 값의 단위·뜻이 달라 섞어 합하면 의미가 없다. 🔴🔴 부서 자체 수식이며 ML 예측이 아니다 — ML 예측 SV 와 같은 표에 합산하지 않는다. ⚠️ 예측값2 는 회비 유형에만 있다. 활성: 예측값1·예측값2 · 월/집계유형/법인/후원사업그룹/신규기존/본부지부 축. 비활성: 예측값1·2 의 산식 설명(원천 정의만 제공).'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **AGGR_TY_NM 을 WHERE 로 하나 고정하거나 GROUP BY 에 넣는다.** 유형을 섞어 합하지 않는다. (2) 🔴 **단위를 단정하지 않는다** — 원천에 단위가 기재되지 않았다. 원·건 같은 단위를 붙이지 말고 「예측값」으로 표기한다. (3) 🔴 **예측값1·예측값2 의 산식을 추정해 설명하지 않는다** — 「회원실 후원분류집계 예측값1/2」로만 부른다. (4) 🔴 **예측값2 가 NULL 인 유형을 0 으로 답하지 않는다** — 그 유형에는 값이 없다고 밝힌다. (5) 🔴 **ML 예측과 섞지 않는다.** (6) **기준월 미지정 시 데이터에 존재하는 최신 기준월로 한정하고 밝힌다.** (7) 적용 조건(그룹 미지정 시): 최신 기준월로 한정해 집계유형별 예측값1·예측값2 를 반환한다. (8) 🔴 metric 이름을 sc 컬럼처럼 참조하지 않는다 — 정의식(SUM(sc.VALUE1) 등)으로 집계한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SPNSR_CLS_AGGR TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SPNSR_CLS_AGGR TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SPNSR_CLS_AGGR TO ROLE GN_DW_SERVICE;
