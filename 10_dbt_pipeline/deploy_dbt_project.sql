-- <!-- LLM-METADATA
-- doc_id: GN_DW_DEPLOY_DBT_PROJECT_SQL
-- doc_role: Snowflake Native DBT PROJECT (GN_DW.OPS.DW_PIPELINE) 배포, 실행, 스냅샷, 빌드 및 스케줄링 운영 정본 SQL
-- project: GN_DW (굿네이버스)
-- updated: 2026-09-09
-- updated_by: TRIALADMIN
-- index: 20_issue/00_INDEX_이슈원장.md
-- source_refs:
--   - 10_dbt_pipeline/00_배포운영_통합_20260715.md
--   - 06_snapshot/01_스냅샷_아키텍처_및_네이밍룰.md
--   - 06_snapshot/02_스냅샷_파이프라인_구축_작업계획.md
-- END-METADATA -->

-- ============================================================================
-- [GN_DW] Snowflake Native dbt Project 배포 및 운영 런북 (정본)
--
-- 📌 핵심 운영 원칙:
--   1. 프로젝트 위치: GN_DW.OPS.DW_PIPELINE (운영/툴링 스키마)
--   2. 실행 역할 / 웨어하우스: GN_DW_ADMIN / GN_DW_DEV_WH(개발·검증) · GN_DW_ETL_WH(배치)
--   3. 구조 소유권: SILVER/GOLD 테이블 DDL은 SQL DDL이 소유하며, dbt는 데이터 정제만 담당(DDL 보존).
--   4. 실행 순서: parse ➔ compile ➔ snapshot (SCD2 누적) ➔ build (SILVER/GOLD 정제+테스트)
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 0 — 사전 환경 및 세션 확인 (안전, 읽기 전용)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT CURRENT_ACCOUNT() AS ACCOUNT, CURRENT_ROLE() AS ROLE, CURRENT_WAREHOUSE() AS WAREHOUSE;

-- OPS 스키마 및 기존 DBT PROJECT 확인
SHOW SCHEMAS IN DATABASE GN_DW;
SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1 — DBT PROJECT 배포 (최초 배포 또는 새 버전 추가)
-- ─────────────────────────────────────────────────────────────────────────────
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- (1) OPS 스키마 보장 및 권한 (필요 시)
CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
  COMMENT = 'dbt project 등 ETL 운영/툴링 객체 전용 스키마';

-- (2-A) [최초 1회만] DBT PROJECT 신규 생성 (VERSION$1)
-- CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE
--   FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';

-- (2-B) [코드 수정 시] 신규 버전 추가 배포 (VERSION$N+1 자동 증가 및 default 승격)
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION V_20260909_SNAPSHOT
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';

ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE SET
  COMMENT = 'BRONZE→SNAPSHOT(SCD2)→SILVER→GOLD. [20260909] dbt snapshot 파이프라인(11종) 및 Point-in-Time 조인 배선.';

-- (3) 배포된 버전 상태 확인
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;
DESCRIBE DBT PROJECT GN_DW.OPS.DW_PIPELINE;


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 2 — 문법 및 컴파일 검증 (데이터 변경 없음, 안전)
-- ─────────────────────────────────────────────────────────────────────────────
-- 모델, 매크로, 스냅샷, yml 문법 검증
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';

-- SQL 렌더링 및 참조 무결성 컴파일 검증
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile';


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3 — 파이프라인 실행 (Snapshot ➔ Build)
-- ─────────────────────────────────────────────────────────────────────────────
-- ⚠️ 실행 순서: 스냅샷을 먼저 실행하여 원천 마스터의 최신 변경분을 보존한 후, build를 수행합니다.

-- [3-1] 마스터 스냅샷 실행 (BRONZE 마스터 SCD Type 2 이력 누적)
-- 전체 스냅샷 실행:
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot';

-- 특정 티어 또는 개별 스냅샷만 실행 시:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot --select snp_crm_tm_cm_cmpgn_mng snp_crm_tm_cm_dept_info snp_crm_tm_cm_spnsr_bsns_info';

-- [3-2] SILVER / GOLD 정제 및 테스트 실행 (build = run + test 게이트)
-- 전체 빌드:
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- 도메인/레이어별 부분 빌드:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.crm';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select gold.dim';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select gold.fact';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select tag:gold_wide';


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 4 — 일일 스케줄 자동화 DAG (Snowflake TASK)
-- ─────────────────────────────────────────────────────────────────────────────
-- 📌 일일 배치 순서:
--   1. [선행 루트 Task (05:30 KST)]: dbt snapshot 실행 (원천 마스터 이력 누적)
--   2. [후속 자식 Task (완료 즉시)]: dbt build 실행 (SILVER/GOLD 전체 정제 및 테스트)

-- (A) 선행 루트 태스크 (스냅샷):
-- CREATE OR ALTER TASK GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY
--   WAREHOUSE = GN_DW_DEV_WH
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
-- Step 5 — 하류 SERVING 계층 및 Cortex Agent 연계 (참고)
-- ─────────────────────────────────────────────────────────────────────────────
-- dbt build 완료 후 Semantic View 및 Agent를 갱신할 때 아래 파일을 순서대로 실행합니다:
--   1. 05_SV-Agent_ai/05_1~05_9_SV_DDL_*.sql  ➔ SEMANTIC VIEW 배포
--   2. 05_SV-Agent_ai/09_1_AGENT_생성.sql     ➔ Cortex Agent 객체 생성
--   3. 05_SV-Agent_ai/09_2_AGENT_버전업.sql   ➔ Cortex Agent 스펙(Instruction/도구) 배포
