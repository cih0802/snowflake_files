-- ============================================================================
-- 29_DEPLOY_G1_REMAINDER.sql — O239 배포 실행 순서(사람 실행 · 라이브 DDL·dbt 포함 = R4-4-3 승인 대상)
--   · 대상 = G1 잔여 2건 = 공#122 결연아동코드 · 공#81 미납서비스 전환율 — 추천안 A/B 동시 탑재(현업이 Agent 실사용 후 결정)
--   · 사전 검증(ua91864 · 2026-10-16 · OPS probe 테이블·SV 생성 → 조회 → DROP · 라이브 GOLD 무변경)
--     FACT_GA_CHILD_VIEW = 15,250행 · 이벤트 합 196,282(= SILVER.BIGQUERY_EVENT childnum 포함 행) · grain 유일
--       결연아동코드 A(형식) 11,981 · B(CRM_CHILD.CHILD_NO 일치) 11,978 · 빈 값 이벤트 81,514
--     FACT_UNPAID_SERVICE_CONV = A 47행 · B 455행 · 전환율 A 14.8936% · B 38.9011% · SV = 팩트 직접식 일치
--   · 🔴 운영계 전체 재적재(문서실행순서.md)에서는 이 파일이 필요 없다 — 06_DDL·dbt build·05_26·26·09_2 가 순서에 들어 있다.
-- Co-authored with CoCo
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- [D1] 신규 테이블 2개 단독 생성(🔴 06_DDL.sql 전체를 다시 돌리지 마라 — CREATE OR REPLACE 로 GOLD 전량이 비워진다)
--      06_DDL.sql 의 「FACT_GA_CHILD_VIEW」·「FACT_UNPAID_SERVICE_CONV」 CREATE 블록을 IF NOT EXISTS 로 바꿔 실행한다(FK 없음)

-- [D2] 👤 dbt 재배포 + build
--   10_dbt_pipeline/01_deploy_dbt_project.sql (ADD VERSION · 버전명 예 O239_20261016)
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select FACT_GA_CHILD_VIEW FACT_UNPAID_SERVICE_CONV';

-- [D3] 대사(기대 = 위 사전 검증 값 · 운영계는 원천 규모가 달라 값만 다르다 — 등식만 본다)
-- 3-1 이벤트 합 = 원천 행수 · grain 유일
SELECT (SELECT SUM(EVENT_CNT) FROM GN_DW.GOLD.FACT_GA_CHILD_VIEW) AS FACT_EVENTS,
       (SELECT COUNT(*) FROM GN_DW.SILVER.BIGQUERY_EVENT WHERE PAGE_LOCATION ILIKE '%childnum=%') AS SRC_EVENTS,
       (SELECT COUNT(*) - COUNT(DISTINCT HASH(DATE_SK, PAGE_PATH, CHILD_CODE_RAW, URL_MEMBER_DK)) FROM GN_DW.GOLD.FACT_GA_CHILD_VIEW) AS DUP_KEYS;
-- 3-2 두 추천안 값
SELECT COUNT(DISTINCT IFF(IS_FORMAT_VALID, CHILD_CODE_RAW, NULL)) AS CHILD_A,
       COUNT(DISTINCT IFF(IS_CRM_MATCHED, CHILD_CODE_RAW, NULL))  AS CHILD_B
FROM GN_DW.GOLD.FACT_GA_CHILD_VIEW;
SELECT SVC_SCOPE, COUNT(*) AS CLICK_MEMBER_MONTHS,
       SUM(ARREAR_PAID_D30_FLAG) / NULLIF(COUNT(*), 0) * 100 AS RATE_ARREAR_D30,
       SUM(PAID_D30_FLAG) / NULLIF(COUNT(*), 0) * 100        AS RATE_ANY_D30
FROM GN_DW.GOLD.FACT_UNPAID_SERVICE_CONV GROUP BY 1 ORDER BY 1;

-- [D4] SV 신규 = 05_SV-Agent_ai/05_26_SV_DDL_GA_CHILD_UNPAID.sql 전체 실행(스모크 = SV 값 = 팩트 직접식)

-- [D5] 코퍼스 재적재 = 05_SV-Agent_ai/26_BIZ_DEFINITION_CORPUS_DDL_적재.sql 전체 실행
--   CSV 는 이미 재생성됨(o237_build_formula_map.py → build_biz_definition_corpus.py · 2,156행)
--   기대 COVERAGE(HAS_FORMULA='Y') = C1 65 · C2 17 · C3 8 · C4 21 · C5 32 · G2 3 · 합 146 (G1 = 0)
SELECT COVERAGE, COUNT(*) N FROM GN_DW.SERVING.BIZ_DEFINITION_CORPUS WHERE HAS_FORMULA = 'Y' GROUP BY ROLLUP(COVERAGE) ORDER BY 1;

-- [D6] Agent = 05_SV-Agent_ai/09_2_AGENT_버전업.sql(AGENT_MEMBER 도구 +1 analyst_ga_child_unpaid · 🔴 D4 뒤에 — 앞서면 죽은 도구)

-- [D7] 스모크(👤 Snowflake Intelligence · AGENT_MEMBER) — 기대 = 두 추천안 값 병기 + 「잠정」 문구
--   ① 「클릭월별 미납서비스 전환율」 → UNPAID_SVC_CONV_RATE_A · _B 와 각 분모
--   ② 「연도별 결연아동코드 수」 → CHILD_CODE_CNT_A · _B
--   ③ 「결연아동코드별 페이지뷰 상위 10」 → CHILD_CODE 차원 · CHILD_PAGE_VIEWS

-- [D8] 현업 결정 후 정리(별도 세션) = 고르지 않은 안의 metric·플래그 컬럼·overlay 문안을 걷어내고 「잠정」을 확정 문안으로 교체
-- [D9] 롤백 = DROP SEMANTIC VIEW GN_DW.SERVING.SV_GA_CHILD_UNPAID · DROP TABLE 두 팩트 · Agent 이전 VERSION ·
--      코퍼스 = tmp/o239/O217_biz_definition_corpus.csv 를 output 으로 되돌리고 26 재실행
