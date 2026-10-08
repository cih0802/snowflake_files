-- ============================================================================
-- 05_6_SV_DDL_BUDGET.sql — Semantic View DDL 정본: SV_BUDGET
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET
  TABLES (
    fbd AS GN_DW.GOLD.FACT_BUDGET
      PRIMARY KEY (MONTH_KEY, BUDGET_ITEM_SK, DVLP_INBOUND_PATH)
      WITH SYNONYMS ('예산', '예산 집행')
      COMMENT = '예산 편성 및 집행 실적 분석 (base: GOLD.FACT_BUDGET). [Grain: 월 × 부서 × 예산과목]. [활성 지표: 편성예산/집행예산/집행률(%)]. [주의: 월 집행액을 더해 연 총액으로 쓰지 말 것 — 연 예산 정본은 GOLD.FACT_BUDGET_YEARLY 이나 어떤 Semantic View 에도 미배선이므로 이 SV 로 연 총액 질의에 답하지 않는다]. [원천: ERP → BRONZE_ERP → SILVER.ERP_BUDGET → GOLD.FACT_BUDGET].',
    month AS GN_DW.GOLD.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '예산월')
      COMMENT = '월 차원. fan-out 차단용 helper 뷰. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    item AS GN_DW.GOLD.DIM_BUDGET_ITEM
      PRIMARY KEY (BUDGET_ITEM_SK)
      WITH SYNONYMS ('세세목', '예산항목')
      COMMENT = '예산 세세목 차원. [원천] 시스템=ERP · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(JANG_NM~SUBDTL_ITEM_NM 장·관·항·목·세목·세세목 계층 + BDGT_UNIT_NM 예산단위) — DISTINCT 마스터화·MD5 대리키 · SILVER=ERP_BUDGET_ITEM.'
  )
  RELATIONSHIPS (
    fbd_to_month AS fbd (MONTH_KEY)      REFERENCES month,
    fbd_to_item  AS fbd (BUDGET_ITEM_SK) REFERENCES item
  )
  DIMENSIONS (
    month.MONTH_KEY  AS month.MONTH_KEY WITH SYNONYMS ('예산연월', '연월') COMMENT = 'YYYYMM 정수',
    month.CAL_YEAR   AS month.YEAR      WITH SYNONYMS ('연도', '년')      COMMENT = '연도',
    month.CAL_MONTH  AS month.MONTH     WITH SYNONYMS ('월')             COMMENT = '월(1~12)',
    item.BUDGET_ITEM_NAME AS item.BUDGET_ITEM_NAME WITH SYNONYMS ('세세목명', '예산항목명') COMMENT = '예산 세세목명',
    item.BUDGET_CATEGORY  AS item.BUDGET_CATEGORY  WITH SYNONYMS ('예산구분', '예산카테고리') COMMENT = '예산 구분. 실제값 1종: ''지출'' + NULL. 🔴 **''수입''은 이 데이터에 존재하지 않는다** — ''수입'' 으로 필터하면 0행이 반환되므로 「수입 예산」 질문에 이 축으로 답하지 말 것. 🟢 사유는 실측으로 확인됐다: **적재된 예산 원장의 장(章) 계정이 전부 비용(지출) 계정**이므로 이 데이터에는 지출 예산만 있다. 🔴 다만 「ERP 원본에 수입 예산이 있는데 업로드 범위에서 빠진 것인지」는 **확인 전**이다 ⇒ 「조직에 수입 예산이 없다」로 확대해 답하지 말고 **「적재된 예산 데이터에는 지출만 있다」**로 답한다(추정치 생성 금지). ⚠️ 이 축은 사실상 단일값이라 그루핑 축으로서의 정보량이 없다',
    item.BDGT_UNIT_NM AS item.BDGT_UNIT_NM WITH SYNONYMS ('예산단위', '예산 팀', '예산 부서', '예산단위명')
      COMMENT = '예산단위명(ERP 표기 그대로 · 세세목 1:1 · O198 DEC-60). 실측 값 6종 = 데이터분석센터 · 마케팅기획1팀 · 마케팅기획2팀 · 매체운영팀 · 사회복지법인예산 · 콘텐츠기획팀. 🔴 CRM 조직(DIM_ORG)과 다른 체계다 — 부서·팀 이름이 CRM 조직명과 같아 보여도 같은 조직으로 단정하지 말 것. 🔴 목록에 없는 팀(예: 「컬쳐콘텐츠팀」)을 물으면 0 으로 답하지 말고 「현재 데이터에서 조회되지 않고 <조회되는 유사 예산단위>가 조회된다」고 밝힌 뒤 그 예산단위의 수치를 제시한다(같은 조직이라 단정하지 않는다 · 유사 항목이 없으면 위 6종을 제시).',
    fbd.DVLP_INBOUND_PATH AS fbd.DVLP_INBOUND_PATH WITH SYNONYMS ('개발인입경로', '개발 유입경로', '인입경로', '유입경로', '개발경로')
      COMMENT = '개발 유입경로(ERP 원장 그대로 · O198 DEC-60). 실측 값 7종 = 디지털 · 방송 · 재송출 · 영상광고 · 뉴미디어 · 모금시스템 · 콜개발. 🔴 NULL = 원장에 경로가 기재되지 않은 예산(대부분 집행 0) — 「미분류」 같은 이름을 지어내지 말고 「경로 미기재」로 표기한다. 🔴 CRM 회원 가입경로(JOIN_PATH)와 다른 축이다.',
    item.ITEM_JANG_NM AS item.JANG_NM WITH SYNONYMS ('장', '예산 장') COMMENT = '예산 과목 계층 최상위 「장」(원값 = 모금비·사업비·사회복지법인예산·일반관리비 · ERP 원장). 장 > 관 > 항 > 목 > 세목 > 세세목 순으로 좁아진다.',
    item.ITEM_KWAN_NM AS item.KWAN_NM WITH SYNONYMS ('관', '예산 관') COMMENT = '예산 과목 계층 「관」(원값 = 국내사업비·나눔문화연구사업·모금비·사회복지법인예산·일반관리비·해외사업비).',
    item.ITEM_HANG_NM AS item.HANG_NM WITH SYNONYMS ('항', '예산 항') COMMENT = '예산 과목 계층 「항」(원값 = 국내아동권리지원사업·기획및연수인력사업·나눔문화연구사업·모금관리비·사무국운영사업·사회복지법인예산·해외기획사업·해외아동권리지원및지역개발사업·회원관리비).',
    item.ITEM_FUND_SOURCE_NM AS item.FUND_SOURCE_NM WITH SYNONYMS ('재원', '예산 재원') COMMENT = '예산 재원명(원값 = 국내지정·법인전입·비지정일반·사회복지법인예산·이월국내지정·이월비지정일반·이자수익·잡수익 · ERP 원장).'
  )
  METRICS (
    fbd.TOTAL_PLAN_BUDGET AS SUM(fbd.PLAN_BUDGET_MONTH)
      WITH SYNONYMS ('편성예산', '월 편성예산', '예산 편성액') COMMENT = '월 편성예산 합계(원). F(가산).',
    fbd.TOTAL_EXEC_BUDGET AS SUM(fbd.EXEC_BUDGET_ERP)
      WITH SYNONYMS ('집행예산', 'ERP 집행액', '예산 집행액') COMMENT = 'ERP 집행예산 합계(원). F(가산).',
    fbd.EXEC_RATE AS SUM(fbd.EXEC_BUDGET_ERP) / NULLIF(SUM(fbd.PLAN_BUDGET_MONTH), 0) * 100
      WITH SYNONYMS ('집행율', '예산 집행율') COMMENT = '집행율(%) = 집행예산 ÷ 편성예산 ×100. 비율(N). ⚠편성은 12개월 전량이지만 집행은 적재된 월까지만 존재하므로, 집행 미적재 월을 분모에 넣으면 집행율이 구조적으로 낮게 나온다 — 스코프 정합 규칙은 AI_SQL_GENERATION 참조.',
    fbd.DIRECT_FUNDRAISING_COST_1 AS SUM(fbd.EXEC_DIRECT_MNYRS_1)
      WITH SYNONYMS ('직접모금비1', '직접모금비 1', '모금성비용1')
      COMMENT = '직접모금비1(원) — 원장 플래그 직접모금비1(DIRECT_MNYRS_YN_1)=Y 인 원장행의 집행액 합. F(가산). 🔴 **화면·답변에는 「직접모금비1」 이름 그대로 표시한다**(현업 회신 42) — 「모금성비용」 하나로 부르지 말고 직접모금비2 와 나란히 보여준다. ⚠️ 두 값은 포함관계가 아니다(행 단위로 1 이 2 보다 큰 행이 있다) ⇒ 차이를 「1 을 뺀 나머지」로 해석하지 말 것.',
    fbd.DIRECT_FUNDRAISING_COST_2 AS SUM(fbd.EXEC_DIRECT_MNYRS_2)
      WITH SYNONYMS ('직접모금비2', '직접모금비 2', '모금성비용2')
      COMMENT = '직접모금비2(원) — 원장 플래그 직접모금비2(DIRECT_MNYRS_YN_2)=Y 인 원장행의 집행액 합. F(가산). 🔴 「직접모금비2」 이름 그대로 표시한다(현업 회신 42). ⚠️ 이 플래그는 사실상 전 원장행이 Y 라 합계가 집행예산(TOTAL_EXEC_BUDGET)과 거의 같다 — 「모금비가 전체 집행과 같다」로 해석하지 말고 플래그 정의가 넓다는 사실을 함께 밝힌다.'
  )
  COMMENT = 'Phase-1 예산 SV (base: GOLD.FACT_BUDGET, grain: 월×세세목 1행). ERP 예산 원장 기반 월별 편성예산(TOTAL_PLAN_BUDGET), 집행예산(TOTAL_EXEC_BUDGET), 집행율(EXEC_RATE, %) 및 세세목별 집계 뷰. ⚠️ 광고비는 본 뷰에 없으며 SV_AD 소관. 수입 예산은 적재 원천에 부재하며 지출 예산만 포함됨.'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 지표 매핑: 편성예산=TOTAL_PLAN_BUDGET, 집행예산=TOTAL_EXEC_BUDGET, 집행율=EXEC_RATE (%). (2) 집행율 산정: 집행예산이 적재된 월까지만 편성을 분모에 포함하여 산정(집행 미적재 월 분모 제외). (3) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (4) 예산구분: BUDGET_CATEGORY 는 ''지출'' 단일 계정이므로 ''수입'' 필터 사용 금지. (5) 2024년 편성 결손 가드: 2024년은 원천 예산 원장에 월별 편성 배분이 없고 연 총액만 있어 월 편성예산이 0 으로 집계되므로, 다년 집행율 산정 시 YEAR >= 2025 를 적용하거나 연도별로 표를 분리하여 제시하고 2024년 월별 집행율은 산출 불가로 답한다. 🆕 [O203] 2024 **연 편성예산·연 집행율**은 연 예산 SV(SV_BUDGET_YEARLY · 연 grain)에 있다 — 그 SV 를 쓰라고 안내하고 이 SV 와 한 표에 합산하지 않는다. (기준시점 규칙) 「최근 N개월」·기간 미지정 질의의 기준 월은 **비상관 CTE 1개**(SELECT MAX(fbd.MONTH_KEY) FROM fbd)로 구하고 CROSS JOIN 한다. ORDER BY … LIMIT/OFFSET 서브쿼리·스칼라 서브쿼리로 기준 월을 구하지 않는다(미지원 서브쿼리 오류). 월 경계는 TO_DATE(TO_VARCHAR(MONTH_KEY), ''YYYYMM'') 로 날짜화해 DATEADD 한다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다. (모금성비용) 「모금성비용·직접모금비」 질의는 DIRECT_FUNDRAISING_COST_1·_2 를 **둘 다** 「직접모금비1」「직접모금비2」 이름으로 나란히 보여주고 하나를 골라 단정하지 않는다.'
  AI_VERIFIED_QUERIES (
    vqr_monthly_plan_exec AS (
      QUESTION '월별 편성예산과 집행예산'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT month.CAL_YEAR, month.CAL_MONTH, SUM(fbd.PLAN_BUDGET_MONTH) AS TOTAL_PLAN_BUDGET, SUM(fbd.EXEC_BUDGET_ERP) AS TOTAL_EXEC_BUDGET FROM fbd LEFT JOIN month ON fbd.MONTH_KEY = month.MONTH_KEY GROUP BY month.CAL_YEAR, month.CAL_MONTH ORDER BY month.CAL_YEAR, month.CAL_MONTH'
    ),
    vqr_o191_last12m_by_item AS (
      QUESTION '최근 12개월 예산구분별·세세목별 편성예산과 집행예산'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH mx AS (SELECT MAX(fbd.MONTH_KEY) AS mk FROM fbd) SELECT item.BUDGET_CATEGORY, item.BUDGET_ITEM_NAME, SUM(fbd.PLAN_BUDGET_MONTH) AS TOTAL_PLAN_BUDGET, SUM(fbd.EXEC_BUDGET_ERP) AS TOTAL_EXEC_BUDGET FROM fbd JOIN item ON fbd.BUDGET_ITEM_SK = item.BUDGET_ITEM_SK CROSS JOIN mx WHERE fbd.MONTH_KEY > TO_NUMBER(TO_CHAR(DATEADD(MONTH, -12, TO_DATE(TO_VARCHAR(mx.mk), ''YYYYMM'')), ''YYYYMM'')) AND fbd.MONTH_KEY <= mx.mk GROUP BY item.BUDGET_CATEGORY, item.BUDGET_ITEM_NAME ORDER BY TOTAL_PLAN_BUDGET DESC NULLS LAST'
    )
  );

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET TO ROLE GN_DW_SERVICE;
