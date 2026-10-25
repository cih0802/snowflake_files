-- ============================================================================
-- 05_0_SV_DDL.sql — Semantic View 인덱스 · 공통 규약 · 전체 배포 검증 (SV 정의는 없다)
--   · 실행 순서(새 계정) = RBAC → SILVER/GOLD DDL → dbt build → 05_1 ~ 05_11 → 21 → 22 → 09_1 → 09_2
--       (정본 = 02_GN_DW_building/06_RUNBOOK.md §11.2-C · 09_2 를 빼면 Agent 도구가 0개다)
--   · 파일 간 순서 의존 없음 — 각 05_N 은 USE + SV + GRANT + 스모크를 모두 담아 단독 실행된다.
--   · 설계·실측 이력(이 파일의 종전 본문 포함) = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
--
-- ▶ 파일 ↔ SV
--   05_1  SV_MEMBER_MONTHLY        05_7   SV_AD
--   05_2  SV_MEMBER_EVENT          05_8   SV_DEV_ACHIEVEMENT
--   05_3  SV_MEMBER_COHORT         05_9   SV_MEMBER_FEE
--   05_4  SV_SERVICE               05_10  SV_MEMBER_SPONSOR_BIZ
--   05_5  SV_EVENT_PARTICIPATION   05_11  SV_TARGET_BIZ
--   05_6  SV_BUDGET
--   22    SV_ML_* 8종(base = 21_ML_SERVING_뷰_DDL 의 SERVING.ML_*_V)
--
-- ▶ 공통 규약
--   1) DDL = CREATE OR ALTER SEMANTIC VIEW — GRANT·소유권 보존. CREATE OR REPLACE 금지(GRANT 파괴 · owner 리셋).
--   2) 실행 역할 = GN_DW_ADMIN. 다른 역할로 신규 생성하면 owner 가 어긋난다(복구 = 아래 소유권 검증).
--   3) base 는 GOLD(또는 ML 은 SERVING.ML_*_V)만 — SERVING helper 뷰 참조 금지.
--   4) fan-out · 가산성: 월팩트→DIM_MONTH · 회원속성→DIM_MEMBER · 광고→WIDE_AD_COMBINED(1:1 pre-join).
--      F=SUM · 회원수=COUNT(DISTINCT MEMBER_DK) · 비율=분자·분모 각각 집계 후 나눗셈.
--   5) PK 는 실측 유일한 grain 만 선언한다. 원천 미적재 지표는 SV 에 넣지 않는다(빈 metric 금지).
--   6) metric 이름은 원본 컬럼명과 달라야 한다(같으면 Invalid metric definition).
--
-- ▶ COMMENT 규약(SV · 컬럼 공통)
--   1) 수치 금지 — 행수·합계·커버리지%·건수·금액·적재기간(Agent 가 COMMENT 를 사실로 인용한다).
--   2) [원천] 절은 이름만: 시스템=… · BRONZE=DB.스키마.테이블(핵심컬럼) · SILVER=…
--      컬럼 단위 계보는 30_output_share/04_컬럼계보매핑.md.
--   3) 저카디널리티 코드 차원은 실제 코드값을 열거한다(틀리면 Analyst 가 0행을 반환).
--   4) 세션 태그(O번호·날짜) 금지 — 경위는 원장·부록에 둔다. VQR VERIFIED_BY 는 예외(검증 주체 메타).
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 검증 1 — SV 별 metric·dimension 수 (각 05_N 의 METRICS/DIMENSIONS 항목 수와 같아야 한다)
SELECT SEMANTIC_VIEW_NAME,
       (SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_METRICS m
          WHERE m.SEMANTIC_VIEW_NAME = d.SEMANTIC_VIEW_NAME AND m.SEMANTIC_VIEW_SCHEMA = 'SERVING') AS metrics,
       COUNT(*) AS dims
FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS d
WHERE SEMANTIC_VIEW_SCHEMA = 'SERVING'
GROUP BY 1 ORDER BY 1;

-- 검증 2 — base 스키마: SV_ML_* 는 SERVING, 그 외는 전건 GOLD 단일이어야 한다
SELECT SEMANTIC_VIEW_NAME, COUNT(*) AS logical_tables,
       LISTAGG(DISTINCT BASE_TABLE_SCHEMA, ',') AS base_schemas
FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_TABLES
GROUP BY 1 ORDER BY 1;

-- 검증 3 — 소유권: 전건 owner = GN_DW_ADMIN
--   어긋나면: USE ROLE ACCOUNTADMIN;
--             GRANT OWNERSHIP ON SEMANTIC VIEW GN_DW.SERVING.<SV> TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
--             (COPY CURRENT GRANTS 를 빼면 소비 역할 GRANT 가 사라진다)
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;

-- 검증 4 — GRANT: OWNERSHIP(GN_DW_ADMIN) + REFERENCES/SELECT × ANALYST·VIEWER·SERVICE (SV 마다 동일)
SHOW GRANTS ON SEMANTIC VIEW GN_DW.SERVING.SV_AD;
SHOW GRANTS ON VIEW GN_DW.GOLD.WIDE_AD_COMBINED;

-- Agent 의 GRANT·CoWork 등록 검증은 09_1_AGENT_생성.sql 검증절 소관이다.
