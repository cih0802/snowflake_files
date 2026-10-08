-- ============================================================================
-- 05_23_SV_DDL_EXPENSE_RESOLUTION.sql — Semantic View DDL 정본: SV_EXPENSE_RESOLUTION (🆕 O213-F Y3-K)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 🔴 선행 = dbt build `ERP_EXPENSE_RESOLUTION+`.
--   · 왜 신설했나 — 「부서별 지출(집행)」을 물을 곳이 없었다. 예산 SV(SV_BUDGET)의 부서 축은 전건 센티넬(O51-F)이고
--     결의부서를 가진 원천 BRONZE_ERP.EXPENSE_RESOLUTION 은 소비 모델 0 이었다(O114-B 선언만).
--   · 🔴🔴 SV_BUDGET·SV_BUDGET_YEARLY 와 금액을 대조·합산하지 않는다 — 과목키 일치 0.02% · 금액 규모 약 9.9배(원천·범위 상이).
--   · 🔴 원천 전 컬럼 동일 행 7,287 을 보존했다(반복 명세인지 적재 중복인지 미판별 · 문서20 N-29 ⑧).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_EXPENSE_RESOLUTION
  TABLES (
    exp AS GN_DW.GOLD.FACT_EXPENSE_RESOLUTION
      WITH SYNONYMS ('지출결의', '지출 결의', '부서별 지출', '집행 내역', '지출 내역')
      COMMENT = '지출결의 팩트(원천 명세 1행 = 1행). 「부서별·목/세목/세세목별·재원별 지출 금액」 질문용. [원천: ERP → BRONZE_ERP.EXPENSE_RESOLUTION → SILVER.ERP_EXPENSE_RESOLUTION → GOLD.FACT_EXPENSE_RESOLUTION]. 🔴 예산(편성·집행 원장 SV_BUDGET)과 다른 원천이라 금액을 서로 대조·합산하지 않는다.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '결의일')
      COMMENT = '일 차원. [원천] ETL 생성(달력).'
  )
  RELATIONSHIPS (
    exp_to_date AS exp (DATE_SK) REFERENCES date
  )
  DIMENSIONS (
    date.RESOLUTION_DATE AS date.FULL_DATE WITH SYNONYMS ('결의일', '작성일', '일자') COMMENT = '지출결의 작성일.',
    date.CAL_YEAR AS date.YEAR WITH SYNONYMS ('연도', '년') COMMENT = '연도(작성일 기준).',
    date.CAL_MONTH AS date.MONTH WITH SYNONYMS ('월') COMMENT = '월(1~12 · 작성일 기준).',
    exp.RESOLUTION_YEAR AS exp.RESOLUTION_YEAR WITH SYNONYMS ('회계연도') COMMENT = '회계연도(원천 YEAR). 작성일 연도와 다를 수 있다.',
    exp.RESOLUTION_DEPT_NM AS exp.RESOLUTION_DEPT_NM WITH SYNONYMS ('결의부서', '부서', '지출 부서') COMMENT = '결의부서명(원값 55종). 「부서별 지출」의 1순위 축.',
    exp.SOURCE_DIV_NM AS exp.SOURCE_DIV_NM WITH SYNONYMS ('출처구분') COMMENT = '출처구분명(원값 6종).',
    exp.BDGT_UNIT_NM AS exp.BDGT_UNIT_NM WITH SYNONYMS ('예산단위') COMMENT = '예산단위명(원값).',
    exp.MOK_NM AS exp.MOK_NM WITH SYNONYMS ('목', '예산 목') COMMENT = '예산 과목 목(원값 12종).',
    exp.DTL_ITEM_NM AS exp.DTL_ITEM_NM WITH SYNONYMS ('세목') COMMENT = '예산 과목 세목(원값).',
    exp.SUBDTL_ITEM_NM AS exp.SUBDTL_ITEM_NM WITH SYNONYMS ('세세목', '지출 항목') COMMENT = '예산 과목 세세목(원값 100종).',
    exp.FUND_SOURCE_NM AS exp.FUND_SOURCE_NM WITH SYNONYMS ('재원', '재원명') COMMENT = '재원명(원값 26종).',
    exp.EXPS_RESOLUTION_NM AS exp.EXPS_RESOLUTION_NM WITH SYNONYMS ('지출결의명', '결의 제목') COMMENT = '지출결의명(자유문 · 부분일치 검색용).',
    exp.RESOLUTION_NO AS exp.RESOLUTION_NO WITH SYNONYMS ('결의번호') COMMENT = '결의번호 — 1결의가 여러 명세행이다.'
  )
  METRICS (
    exp.SUM_AMT_TOTAL AS SUM(exp.SUM_AMT)
      WITH SYNONYMS ('지출액', '지출 금액', '집행액', '지출액(원)')
      COMMENT = '지출 금액 합(원). F(가산).',
    exp.RESOLUTION_CNT AS COUNT(DISTINCT exp.RESOLUTION_NO)
      WITH SYNONYMS ('결의 건수', '지출결의 건수', '결의(건)')
      COMMENT = '고유 결의번호 수(건). 🔴 비가산 — 부서 합과 전체 값이 다를 수 있다.'
  )
  COMMENT = '지출결의 SV(🆕 O213-F). 「부서·과목(목/세목/세세목)·재원·출처구분별 지출 금액과 결의 건수」 질문에 쓴다. 🔴 예산 편성·집행 원장(SV_BUDGET·SV_BUDGET_YEARLY)과 다른 원천이다 — 「예산 대비 지출」을 이 SV 와 예산 SV 를 섞어 계산하지 말고 두 값을 따로 밝힌다.'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "지출액(원)"). 영문 식별자를 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. [O206-C 합계 규칙] 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행을 반환한다.
  핵심 규칙: (1) 기간 미지정 시 데이터에 존재하는 최신 연도 하나로 한정하고 밝힌다(작성일 기준). (2) 부서별 질문은 RESOLUTION_DEPT_NM 으로 묶고 상위 20개로 한정해 밝힌다. (3) 예산 대비 비율을 요구받으면 이 SV 로 계산하지 말고 원천이 다르다고 밝힌다. (4) 결의 건수는 COUNT DISTINCT 이므로 부서별 합이 전체와 다를 수 있다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EXPENSE_RESOLUTION TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EXPENSE_RESOLUTION TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EXPENSE_RESOLUTION TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크 — SV 지출액 합 = 팩트 = 원천(212,342,534,942원 · 2026-10-08)
SELECT (SELECT SUM_AMT_TOTAL FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_EXPENSE_RESOLUTION METRICS exp.SUM_AMT_TOTAL)) AS sv_val,
       (SELECT SUM(SUM_AMT) FROM GN_DW.GOLD.FACT_EXPENSE_RESOLUTION)                                        AS fact_val,
       (SELECT SUM(SUM_AMT) FROM GN_DW.BRONZE_ERP.EXPENSE_RESOLUTION)                                       AS src_val;
