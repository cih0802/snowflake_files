-- ─────────────────────────────────────────────────────────────────────────────
-- Step 2 — 문법 및 컴파일 검증 (엔지니어 역할: GN_DW_DBT)
-- ─────────────────────────────────────────────────────────────────────────────
USE ROLE GN_DW_DBT;
USE WAREHOUSE GN_DW_ETL_WH;

-- 모델, 매크로, 스냅샷, yml 문법 검증
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';

-- SQL 렌더링 및 참조 무결성 컴파일 검증
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile';


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3 — 파이프라인 실행 (엔지니어 역할: GN_DW_DBT)
-- ─────────────────────────────────────────────────────────────────────────────
-- ⚠️ 실행 순서: 스냅샷을 먼저 실행하여 원천 마스터의 최신 변경분을 보존한 후, build를 수행합니다.
-- 최초 배포 후 '08_After_Deploy_DBT.sql' 돌리고 ENGINEER권한으로 BUILD
USE ROLE GN_DW_DBT;
USE WAREHOUSE GN_DW_ETL_WH;

-- [3-1] 마스터 스냅샷 실행 (BRONZE 마스터 SCD Type 2 이력 누적)
-- 전체 스냅샷 실행:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot';

-- 특정 티어 또는 개별 스냅샷만 실행 시:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot --select snp_crm_tm_cm_cmpgn_mng snp_crm_tm_cm_dept_info snp_crm_tm_cm_spnsr_bsns_info';

-- [3-2] SILVER / GOLD 정제 및 테스트 실행 (build = run + test 게이트)
-- 전체 빌드:
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select BIGQUERY_BASIC+ FACT_MESSAGE_DISPATCH+ --vars ''{"bigquery_dt_ranges": [["1945-01-01", "9999-12-31"]]}''';
-- 운영계 일배치 테스트용 target변경
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --target dev2';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --target dev2 --select BIGQUERY_BASIC+ FACT_MESSAGE_DISPATCH+ --vars ''{"bigquery_dt_ranges": [["1945-01-01", "9999-12-31"]]}''';

-- build 실패시 수정 후 실패지점부터 이어서 진행
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='retry';

-- 도메인/레이어별 부분 빌드:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.crm';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select gold.dim';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select gold.fact';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select tag:gold_wide';


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3-3 — 🔴🔴 [필수] 재배포 후 BIGQUERY 체인 일자 수 확인 (엔지니어 역할)
-- ─────────────────────────────────────────────────────────────────────────────
-- 🔴🔴 왜 이 단계가 필수인가 (2026-09-22 O178 · 실사고 규명)
--   BIGQUERY 파생(BIGQUERY_BASIC·BIGQUERY_EVENT·FACT_BIGQUERY_BEHAVIOR)은 O177 부터
--   **롤링 윈도우 증분**이다 — 매 run 이 다시 만드는 구간은 [오늘 - bigquery_lookback_days, ∞) 뿐이고
--   창 밖 과거는 손대지 않는다(macros/bigquery_range_predicate.sql · 개명 예정).
--   ⇒ 🔴 **재배포로 SILVER/GOLD 가 빈 상태가 되면 그 빈 상태가 영구히 남는다.**
--      창에 원천 데이터가 없으면 모델은 SUCCESS 로 끝나고 **행수만 조용히 0** 이다.
--
--   실사고(2026-09-21 20:39~20:57 · 쿼리이력으로 규명):
--     ㉠ 재배포로 테이블이 비었다(그 시점 DELETE 가 0행을 지웠다 = 이미 비어 있었다)
--     ㉡ **구 버전**(6월 고정창) 빌드가 먼저 돌아 3일치 1,299,412행만 채웠다
--     ㉢ **신 버전** 롤링 윈도우는 창 [2026-09-19, ∞) 에 원천이 없어 **정상 no-op** 했다
--        (원천 최대 일자가 2026-09-14 였다)
--     ⇒ 하류가 33일 → **3일치로 회귀**했고 **ERROR 는 0** 이었다. 완전 무증상이다.
--   🟢 판정식 = **증분 파이프라인에서는 「배포 순서」가 데이터 범위를 결정한다.**
--      전량 TRUNCATE 시절에는 배포 순서가 데이터에 영향을 주지 않았다 —
--      증분화가 **배포 절차를 데이터 정합성의 일부로** 만들었다.
--
-- 🔴 아래 2개 쿼리는 **재배포 + build 직후 매번** 돌린다. Step 4 의 일일 배치 Task 를
--    RESUME 하기 **전에** 반드시 통과시킬 것 — 자동화되면 이 사고가 무인으로 반복된다.
USE ROLE GN_DW_DBT;
USE WAREHOUSE GN_DW_ETL_WH;

-- [3-3-a] 원천 ↔ 하류 **일자 수 대조** (기대 = 세 값이 모두 같다)
--   🔴 행수가 아니라 **일자 수**를 본다 — 일자 단위 창이 누락의 단위이기 때문이다.
--   ⚠️ 이 개발 계정의 원천은 월 1일씩 샘플링돼 들어온다(운영 원천은 전일자다) ⇒
--      「33」 같은 절대값을 기대값으로 박지 말고 **원천과 같은지**를 본다.
SELECT 'SRC  BIGQUERY_REFINED_DATA' AS LAYER,
       COUNT(DISTINCT TRY_TO_DATE(EVENT_DATE, 'YYYYMMDD')) AS DAYS_,
       COUNT(*)                                           AS ROWS_
  FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
 WHERE EVENT_DATE IS NOT NULL
UNION ALL
SELECT 'SILVER BIGQUERY_BASIC', COUNT(DISTINCT EVENT_DT), COUNT(*)
  FROM GN_DW.SILVER.BIGQUERY_BASIC
UNION ALL
SELECT 'SILVER BIGQUERY_EVENT', COUNT(DISTINCT EVENT_DT), COUNT(*)
  FROM GN_DW.SILVER.BIGQUERY_EVENT
UNION ALL
SELECT 'GOLD  FACT_BIGQUERY_BEHAVIOR', COUNT(DISTINCT DATE_SK), COUNT(*)
  FROM GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR
ORDER BY 1;

-- [3-3-b] 감시 테이블 확인 (기대 = 전건 0행)
--   🔴 WARN_BIGQUERY_LOAD_GAP(개명 예정 = WARN_BIGQUERY_LOAD_GAP) 이 **양방향** 감시다:
--      DIRECTION='SRC_ONLY'  = 원천에 있고 하류에 없다(누락 · 위 사고가 여기 걸렸다 · 30행)
--      DIRECTION='DW_ONLY'   = 하류에 있고 원천에 없다(고아 · 창 밖이라 영구 잔존)
--      DIRECTION='BAD_DATE_FORMAT' = 원천 EVENT_DATE 가 YYYYMMDD 로 파싱되지 않는다
SELECT 'WARN_BIGQUERY_LOAD_GAP' AS MONITOR, COUNT(*) AS ROWS_ FROM GN_DW.OPS.WARN_BIGQUERY_LOAD_GAP
UNION ALL
SELECT 'WARN_GOLD_FACT_BIGQUERY_DATE_SK_ZERO', COUNT(*) FROM GN_DW.OPS.WARN_GOLD_FACT_BIGQUERY_DATE_SK_ZERO
UNION ALL
SELECT 'WARN_BIGQUERY_NULL_USER_PSEUDO_ID', COUNT(*) FROM GN_DW.OPS.WARN_BIGQUERY_NULL_USER_PSEUDO_ID
ORDER BY 1;

-- 🔴 [3-3-a] 일자 수가 원천보다 적거나 [3-3-b] 가 0행이 아니면 **여기서 멈춰라.**
--    🟢🟢 [2026-09-28 O187-C] **백필 정본 = ARGS 1줄**(재배포·주석 편집 불요 · 리스트 var 전달 실측 xf98254):
--      ① EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile --select BIGQUERY_BASIC --vars ''{"bigquery_dt_ranges": [["YYYY-MM-DD", "YYYY-MM-DD"]]}''';
--         → 컴파일 SQL 의 `EVENT_DATE between '…' and '…'` 가 지정 구간인지 **먼저 확인**한다(판정식 = 렌더된 창)
--      ② 같은 ARGS 에서 compile → build 로, --select 를 BIGQUERY_BASIC+ 로 바꿔 실행 · ③ [3-3-a]·[3-3-b] 대사
--      🔴 **EXECUTE DBT PROJECT 경로 + JSON 표기만** — Workspaces dbt 클라이언트에서는 여전히 전달되지 않는다.
--      🟢 파일을 건드리지 않으므로 종전 ㉣(재잠금 누락 → 매일 전 기간 재적재) 위험이 **구조적으로 사라진다**.
--    ⬇ 아래 ㉠~㉤ 는 **대체 경로**(ARGS 전달이 안 되는 실행 환경용)로 강등한다.
--    복구 경로는 **ⓐ 수동 백필 하나뿐**이다(롤링 윈도우는 창 밖을 건드리지 않고,
--    SILVER·GOLD 는 full_refresh:false 라 --full-refresh 도 막혀 있다):
--      ㉠ dbt_project.yml vars 의 `bigquery_dt_ranges` 주석을 **일시적으로 풀고** 구간을 적는다
--         (전량이면 ['2024-01-01', '9999-12-31'] · 🔴 하한은 원천 최소일과 대조할 것)
--      ㉡ ALTER DBT PROJECT … ADD VERSION 으로 **재배포**한다(파일만 고쳐도 반영되지 않는다)
--      ㉢ EXECUTE DBT PROJECT … ARGS='build --select BIGQUERY_BASIC+'
--      ㉣ 🔴 **주석을 다시 잠그고 재배포한다** — 상주시키면 이중 샘플링이 재발하고
--         일일 배치가 매일 전 기간을 재적재한다(O178 이 이 재잠금 반영을 별도 검증했다)
--      ㉤ 위 [3-3-a]·[3-3-b] 를 다시 돌려 대사한다
--    🟢🟢 [2026-09-28 O187 확정] **`--vars` 는 전달된다** — 실험 A(JSON)·B(YAML) 모두 `bigquery_lookback_days: 999` 가
--       창 하한 `20240103`(= 실행일 − 999일)로 렌더됐다(xf98254). 종전 「조용히 무시된다」(O177)는 **실행 경로 한정 사실**이었다 —
--       실패 = Snowsight **Workspaces dbt 클라이언트**(공백 절단·인용부호 제거 · `dbt_project.yml:97`) · 성공 = **`EXECUTE DBT PROJECT` ARGS**.
--       ⇒ 쓸 때는 **`EXECUTE DBT PROJECT` 경로 + JSON 형태**를 쓴다(Workspaces 클라이언트에서는 여전히 쓰지 않는다): ARGS='… --vars ''{"키": 값}'''.
--       🟢 [O187-C] 리스트 var(`bigquery_dt_ranges`)도 전달 확인 — 창 `between '20250601' and '20250630'` 렌더 ⇒ 위 ARGS 1줄이 정본.
--    ~~🔴🔴 `--vars` 로 오버라이드하지 마라 — 값이 반영되지 않는 현상이 관측됐다(O177).~~ (이력 · O187 이 기각)
--    🟢 실증(O178) = 전량 백필로 3일치 → 33일 10,332,737행 복구 · WARN 30행 → 0행.



-- ─────────────────────────────────────────────────────────────────────────────
-- Step 4 — 일일 스케줄 자동화 DAG (관리자 역할: GN_DW_ADMIN)
-- ─────────────────────────────────────────────────────────────────────────────
-- 📌 일일 배치 순서:
--   1. [선행 루트 Task (05:30 KST)]: dbt snapshot 실행 (원천 마스터 이력 누적)
--   2. [후속 자식 Task (완료 즉시)]: dbt build 실행 (SILVER/GOLD 전체 정제 및 테스트)
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;

-- (A) 선행 루트 태스크 (스냅샷):
-- CREATE OR ALTER TASK GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY
--   WAREHOUSE = GN_DW_ETL_WH
--   SCHEDULE = 'USING CRON 30 5 * * * Asia/Seoul'
--   COMMENT = 'dbt snapshot 일일 실행 (마스터 SCD Type 2 변경분 누적)'
-- AS
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot';

-- (B) 후속 차일드 태스크 (빌드):
-- CREATE OR ALTER TASK GN_DW.OPS.TASK_DW_BUILD_DAILY
--   WAREHOUSE = GN_DW_ETL_WH
--   AFTER GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY
--   COMMENT = '스냅샷 완료 후 DW_PIPELINE 일일 build(run+test) 자동 실행'
-- AS
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- (C) 태스크 체인 활성화 (자식 태스크 먼저 RESUME ➔ 루트 태스크 RESUME):
ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_BUILD_DAILY RESUME;
ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY RESUME;

-- (D) 태스크 상태 확인 및 일시 중지:
SHOW TASKS LIKE '%DW_%' IN SCHEMA GN_DW.OPS;
ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY SUSPEND;
ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_BUILD_DAILY SUSPEND;


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 5 — 하류 SERVING 계층 및 Cortex Agent 연계 (관리자 역할: GN_DW_ADMIN)
-- ─────────────────────────────────────────────────────────────────────────────
-- 📌 01_환경 Role.md 원칙: GN_DW DB·전 스키마·테이블/뷰·SV/Agent 소유 = GN_DW_ADMIN 소유
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;

-- [5-1] Semantic View 배포 및 비즈니스 모델링
-- 05_SV-Agent_ai/05_1~05_10_SV_DDL_*.sql  ➔ SEMANTIC VIEW 10종 배포 및 검증

-- [5-2] Cortex Agent 객체 생성 및 서비스 스펙 등록
-- 05_SV-Agent_ai/09_1_AGENT_생성.sql     ➔ Cortex Agent 객체 생성
-- 05_SV-Agent_ai/09_2_AGENT_버전업.sql   ➔ Cortex Agent 스펙(Instruction/도구) 배포
