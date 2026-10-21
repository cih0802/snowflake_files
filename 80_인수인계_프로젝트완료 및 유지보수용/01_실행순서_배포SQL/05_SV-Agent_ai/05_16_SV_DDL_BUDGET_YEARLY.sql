-- ============================================================================
-- 05_16_SV_DDL_BUDGET_YEARLY.sql — Semantic View DDL 정본: SV_BUDGET_YEARLY ( O203 · T8 2차)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 근거(2026-10-06 실측): 2024 연 편성 204.9억원은 이 팩트에만 있다(FACT_BUDGET 2024 월 편성 = 0).
--     2025·2026 은 연 편성·연 집행 합계가 FACT_BUDGET 월 합계와 원 단위까지 일치 ⇒ 같은 원장의 연 grain.
--   · 1 SV = 1 base FACT(fan-out 방지) — SV_BUDGET(월 grain)과 분리한다.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET_YEARLY
  TABLES (
    fby AS GN_DW.GOLD.FACT_BUDGET_YEARLY
      WITH SYNONYMS ('연 예산', '연간 예산', '연 편성예산')
      COMMENT = '연 예산 편성·집행 팩트(base: GOLD.FACT_BUDGET_YEARLY). [Grain: 연 × 부서 × 예산과목 × 예산절차]. 🟢 2024 연 편성예산은 이 SV 에만 있다(월 예산 SV 의 2024 월 편성은 0). [원천: ERP → GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER → SILVER.ERP_BUDGET_YEARLY → GOLD.FACT_BUDGET_YEARLY].',
    item AS GN_DW.GOLD.DIM_BUDGET_ITEM
      PRIMARY KEY (BUDGET_ITEM_SK)
      WITH SYNONYMS ('세세목', '예산항목')
      COMMENT = '예산 세세목 차원. [원천] ERP · BRONZE_ERP.BDGT_ACMSLT_LEDGER — DISTINCT 마스터.'
  )
  RELATIONSHIPS (
    fby_to_item AS fby (BUDGET_ITEM_SK) REFERENCES item
  )
  DIMENSIONS (
    fby.BUDGET_YEAR AS fby.BUDGET_YEAR WITH SYNONYMS ('예산연도', '연도', '년') COMMENT = '예산 연도. 실제값 3종: 2024·2025·2026',
    fby.BUDGET_PROCEDURE AS fby.BUDGET_PROCEDURE WITH SYNONYMS ('예산절차', '예산 단계') COMMENT = '예산 절차. 실제값: 2024·2025 = ''추가경정'' · 2026 = ''연사업''. 🔴 연도마다 절차가 다르다 — 연도 비교 시 함께 밝힌다',
    item.BUDGET_ITEM_NAME AS item.BUDGET_ITEM_NAME WITH SYNONYMS ('세세목명', '예산항목명') COMMENT = '예산 세세목명',
    item.BDGT_UNIT_NM AS item.BDGT_UNIT_NM WITH SYNONYMS ('예산단위', '예산 팀', '예산 부서', '예산단위명') COMMENT = '예산단위명(ERP 표기 그대로)',
    item.ITEM_JANG_NM AS item.JANG_NM WITH SYNONYMS ('장', '예산 장') COMMENT = '예산 과목 계층 최상위 「장」(원값 = 모금비·사업비·사회복지법인예산·일반관리비 · ERP 원장). 장 > 관 > 항 > 목 > 세목 > 세세목 순으로 좁아진다.',
    item.ITEM_KWAN_NM AS item.KWAN_NM WITH SYNONYMS ('관', '예산 관') COMMENT = '예산 과목 계층 「관」(원값 = 국내사업비·나눔문화연구사업·모금비·사회복지법인예산·일반관리비·해외사업비).',
    item.ITEM_HANG_NM AS item.HANG_NM WITH SYNONYMS ('항', '예산 항') COMMENT = '예산 과목 계층 「항」(원값 = 국내아동권리지원사업·기획및연수인력사업·나눔문화연구사업·모금관리비·사무국운영사업·사회복지법인예산·해외기획사업·해외아동권리지원및지역개발사업·회원관리비).',
    item.ITEM_FUND_SOURCE_NM AS item.FUND_SOURCE_NM WITH SYNONYMS ('재원', '예산 재원') COMMENT = '예산 재원명(원값 = 국내지정·법인전입·비지정일반·사회복지법인예산·이월국내지정·이월비지정일반·이자수익·잡수익 · ERP 원장).'
  )
  METRICS (
    fby.TOTAL_PLAN_BUDGET_YEAR AS SUM(fby.PLAN_BUDGET_YEAR)
      WITH SYNONYMS ('연 편성예산', '연간 편성예산', '연 예산') COMMENT = '연 편성예산 합계(원). F(가산 · 연도 간 합산은 의미 없음 — 연도를 고정한다).',
    fby.TOTAL_EXEC_BUDGET_YEAR AS SUM(fby.EXEC_BUDGET_YEAR)
      WITH SYNONYMS ('연 집행예산', '연간 집행액') COMMENT = '연 집행예산 합계(원). 🔴 진행 중 연도(2026)는 적재된 월까지의 누계다 — 연말 확정값이 아니다.',
    fby.EXEC_RATE_YEAR AS SUM(fby.EXEC_BUDGET_YEAR) / NULLIF(SUM(fby.PLAN_BUDGET_YEAR), 0) * 100
      WITH SYNONYMS ('연 집행율', '연간 집행율') COMMENT = '연 집행율(%) = 연 집행 ÷ 연 편성 ×100. 비율(N · 재합산 금지). 🔴 진행 중 연도는 연간 편성 대비 누계라 구조적으로 낮다 — 그 사실을 밝힌다.'
  )
  COMMENT = '연 예산 SV. 「2024 연 편성예산」·「연도별 편성 대비 집행」 질문용. 월별 편성·집행·세세목 추이는 SV_BUDGET(월 grain)이다. 🔴 두 SV 의 수치를 한 표에 합산하지 않는다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 연 편성=TOTAL_PLAN_BUDGET_YEAR, 연 집행=TOTAL_EXEC_BUDGET_YEAR, 연 집행율=EXEC_RATE_YEAR(%). (2) 연도(BUDGET_YEAR)를 반드시 GROUP BY 하거나 고정한다 — 여러 연도를 하나로 합산하지 않는다. (3) 결과에 예산절차(BUDGET_PROCEDURE)를 함께 보여준다. (4) 2026 은 진행 중 연도이므로 집행·집행율이 부분 연도임을 밝힌다. (5) ORDER BY 에는 SELECT 별칭을 그대로 쓴다.'
  AI_VERIFIED_QUERIES (
    vqr_o203_yearly_plan_exec AS (
      QUESTION '연도별 편성예산과 집행예산, 집행율'
      VERIFIED_BY '(DW = O203 · 2024 편성 20,494,617,159원)'
      SQL 'SELECT BUDGET_YEAR AS "연도", BUDGET_PROCEDURE AS "예산차수", TOTAL_PLAN_BUDGET_YEAR AS "편성예산(원)", TOTAL_EXEC_BUDGET_YEAR AS "집행예산(원)", ROUND(EXEC_RATE_YEAR, 2)::NUMBER(38,2) AS "집행율(%)" FROM (SELECT fby.BUDGET_YEAR, fby.BUDGET_PROCEDURE, SUM(fby.PLAN_BUDGET_YEAR) AS TOTAL_PLAN_BUDGET_YEAR, SUM(fby.EXEC_BUDGET_YEAR) AS TOTAL_EXEC_BUDGET_YEAR, SUM(fby.EXEC_BUDGET_YEAR) / NULLIF(SUM(fby.PLAN_BUDGET_YEAR), 0) * 100 AS EXEC_RATE_YEAR FROM fby GROUP BY fby.BUDGET_YEAR, fby.BUDGET_PROCEDURE ORDER BY fby.BUDGET_YEAR) ORDER BY BUDGET_YEAR'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET_YEARLY TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET_YEARLY TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET_YEARLY TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인)
SELECT (SELECT TOTAL_PLAN_BUDGET_YEAR FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET_YEARLY METRICS fby.TOTAL_PLAN_BUDGET_YEAR)) AS sv_val,
       (SELECT SUM(PLAN_BUDGET_YEAR) FROM GN_DW.GOLD.FACT_BUDGET_YEARLY)                                           AS fact_val;
