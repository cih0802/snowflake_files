-- GN_DW dbt PROJECT 최초 생성 (계정 이전 KD03246 후 재배포) — 정본 위치 GN_DW.OPS.DW_PIPELINE
-- Co-authored with CoCo

-- ============================================================================
-- [GN_DW] dbt 배포 및 운영 가이드 (Snowflake Native DBT PROJECT)
--
-- · 대상 프로젝트: GN_DW.OPS.DW_PIPELINE (운영/툴링 스키마 GN_DW.OPS에 배포)
-- · 파이프라인 구성: BRONZE ➔ (SNAPSHOT) ➔ SILVER ➔ GOLD ➔ WIDE VIEW
-- · 핵심 불변식:
--   1. DDL 구조 소유권: SILVER(08_DDL) / GOLD(06_DDL) / VIEW(dbt 소유)
--   2. 멱등 적재 원칙: incremental + pre-hook TRUNCATE / merge (+full_refresh:false)
--   3. 마스터 시점 고정: dbt snapshot (SCD Type 2 · SNAPSHOT 스키마에 영구 누적)
--   4. 실행 순서: parse/compile ➔ dbt snapshot (마스터 이력 누적) ➔ dbt build (정제/적재)
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 0 — 사전 환경 및 기존 객체 확인 (읽기 전용, 안전)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT CURRENT_ACCOUNT() AS ACCOUNT, CURRENT_ROLE() AS ROLE, CURRENT_WAREHOUSE() AS WH;

-- 레이어별 테이블/뷰 객체 수 확인
SELECT TABLE_SCHEMA, TABLE_TYPE, COUNT(*) AS CNT
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('SNAPSHOT', 'SILVER', 'GOLD', 'SERVING', 'OPS')
GROUP BY 1, 2
ORDER BY 1, 2;

-- 기존 배포된 DBT PROJECT 객체 확인
SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1-1 — CREATE (최초 배포) : VERSION$1 자동 생성 및 default 지정
-- ─────────────────────────────────────────────────────────────────────────────
-- OPS 스키마 생성 (이미 존재 시 no-op)
CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
  COMMENT = 'dbt project 등 운영/툴링 객체 전용 (데이터 레이어 아님)';

-- 권한 및 컨텍스트 설정 (GN_DW_ADMIN 통일)
GRANT CREATE DBT PROJECT ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ADMIN;
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- 워크스페이스 코드를 기반으로 Snowflake Native DBT PROJECT 생성
CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/head/10_dbt_pipeline';

SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1-2 — 재배포 (버전 관리) : ALTER … ADD VERSION ➔ VERSION$N+1
-- ─────────────────────────────────────────────────────────────────────────────
-- 언제: 워크스페이스의 snapshots/, models/, macros/, dbt_project.yml 을 수정한 뒤.
-- ⚠️ 재배포 시 CREATE OR REPLACE 대신 반드시 ALTER ... ADD VERSION 을 사용하여 버전 이력을 보존합니다.

-- (1) 현재 배포 버전 확인
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;
DESCRIBE DBT PROJECT GN_DW.OPS.DW_PIPELINE;

-- (2) 새 버전 추가 (신규 배포 승격)
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION V_20260909_SNAPSHOT
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';

-- (3) 프로젝트 설명 갱신
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE SET
  COMMENT = 'BRONZE ➔ SNAPSHOT(SCD2 11종) ➔ SILVER ➔ GOLD + WIDE VIEW 배포본';

-- (4) 승격 확인
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;

-- ── 롤백 (문제 발생 시 직전 버전 복귀) ─────────────────────────────────────────
-- ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE SET DEFAULT_VERSION = 'VERSION$1';   -- 구버전 지정
-- ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE UNSET DEFAULT_VERSION;               -- LAST(최신)로 복귀

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 2 — 검증 (parse / compile / snapshot 검증 — 데이터 변경 없음)
-- ─────────────────────────────────────────────────────────────────────────────
-- 전체 모델 및 스냅샷 문법 파싱 검증
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';

-- 전체 SQL 쿼리 컴파일 검증
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile';

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3 — 적재 및 실행 (Snapshot ➔ Build 순차 실행)
-- ─────────────────────────────────────────────────────────────────────────────
-- 🔴 중요 실행 원칙:
--   1. 스냅샷(snapshot)을 먼저 실행하여 원천 마스터의 최신 변경분을 SCD Type 2로 동결 누적합니다.
--   2. 이어서 빌드(build)를 실행하여 스냅샷 및 원천 데이터를 바탕으로 SILVER/GOLD를 정제합니다.
--   3. run 대신 test 게이트가 결합된 build를 기본으로 사용합니다.

-- [1] dbt snapshot 실행 (마스터 시점 동결 이력 누적)
-- 전체 스냅샷 실행:
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot';

-- (선택) Tier 1 핵심 마스터 스냅샷만 실행:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot --select snp_crm_tm_cm_cmpgn_mng snp_crm_tm_cm_dept_info snp_crm_tm_cm_mber_dvlp_goal';

-- [2] dbt build 실행 (SILVER / GOLD 정제 적재 + 무결성 테스트 게이트)
-- 전체 파이프라인 build (SILVER + GOLD + WIDE VIEW + 테스트):
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- (선택) 부분 빌드:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.crm';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select path:models/gold';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select tag:gold_wide';

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 4 — 스케줄 자동화 (Snowflake TASK DAG) : 준비되면 주석 해제
-- ─────────────────────────────────────────────────────────────────────────────
-- (a) 선행 루트 태스크 : 매일 오전 05:30 KST 스냅샷 수집
-- CREATE OR ALTER TASK GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY
--   WAREHOUSE = GN_DW_DEV_WH
--   SCHEDULE = 'USING CRON 30 5 * * * Asia/Seoul'
--   COMMENT = 'dbt snapshot 일일 실행 (마스터 SCD Type 2 변경분 누적)'
-- AS
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot';

-- (b) 후속 차일드 태스크 : 스냅샷 완료 즉시 트리거되는 SILVER/GOLD build
-- CREATE OR ALTER TASK GN_DW.OPS.TASK_DW_BUILD_DAILY
--   WAREHOUSE = GN_DW_ETL_WH
--   AFTER GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY
--   COMMENT = '스냅샷 완료 후 DW_PIPELINE 일일 build(run+test) 자동 실행'
-- AS
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- (c) 태스크 체인 활성화 (자식 태스크 먼저 RESUME ➔ 루트 태스크 RESUME):
-- ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_BUILD_DAILY RESUME;
-- ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY RESUME;

-- (d) 태스크 상태 확인 / 일시 중지:
-- SHOW TASKS LIKE '%DW_%' IN SCHEMA GN_DW.OPS;
-- ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY SUSPEND;
-- ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_BUILD_DAILY SUSPEND;

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 5 — 하류 SERVING / Cortex Agent 연계 (참고용)
-- ─────────────────────────────────────────────────────────────────────────────
-- dbt build 완료 후 Semantic View 및 Cortex Agent 스펙을 적용하는 순서:
--   1. 05_SV-Agent_ai/05_1~05_9_SV_DDL_*.sql ➔ SEMANTIC VIEW 배포
--   2. 05_SV-Agent_ai/09_1_AGENT_생성.sql     ➔ Agent 객체 생성
--   3. 05_SV-Agent_ai/09_2_AGENT_버전업.sql   ➔ Agent 스펙(도구·instruction) 버전업

