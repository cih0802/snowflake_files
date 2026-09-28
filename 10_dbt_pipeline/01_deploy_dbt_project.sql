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
-- 📌 핵심 운영 원칙 & RBAC 권한 분리:
--   1. 프로젝트 위치: GN_DW.OPS.DW_PIPELINE (운영/툴링 스키마)
--   2. 역할 분리 (최소 권한 원칙):
--      - 배포/관리/스케줄링: GN_DW_ADMIN (DBT PROJECT 소유자, DDL/Task 관리)
--      - 일상 실행/정제/검증: GN_DW_ENGINEER (파이프라인 실행자, DML/Test 수행)
--   3. 웨어하우스: GN_DW_DEV_WH(개발·검증) · GN_DW_ETL_WH(배치)
--   4. 구조 소유권: SILVER/GOLD 테이블 DDL은 SQL DDL이 소유하며, dbt는 데이터 정제만 담당(DDL 보존).
--   5. 실행 순서: parse ➔ compile ➔ snapshot (SCD2 누적) ➔ build (SILVER/GOLD 정제+테스트)
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 0 — 사전 환경 및 세션 확인 (안전, 읽기 전용)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT CURRENT_ACCOUNT() AS ACCOUNT, CURRENT_ROLE() AS ROLE, CURRENT_WAREHOUSE() AS WAREHOUSE;

-- OPS 스키마 및 기존 DBT PROJECT 확인
SHOW SCHEMAS IN DATABASE GN_DW;
SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1 — DBT PROJECT 배포 및 버전 관리 (관리자 역할: GN_DW_ADMIN)
-- ─────────────────────────────────────────────────────────────────────────────
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- (1) OPS 스키마 보장 및 권한 (필요 시)
CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
  COMMENT = 'dbt project 등 ETL 운영/툴링 객체 전용 스키마';

-- (2-A) [최초 1회만] DBT PROJECT 신규 생성 (VERSION$1)
-- 최초 배포 후 '08_After_Deploy_DBT.sql' 돌리고 ENGINEER권한으로 BUILD
-- CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE
  -- FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';

-- (2-B) [코드 수정 시] 신규 버전 추가 배포 (VERSION$N+1 자동 증가 및 default 승격)
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION SRCSYS_BIGQUERY_BACKFILL_20260922151530
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';

ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE SET
  COMMENT = 'BRONZE→SILVER→GOLD. [20260922] SOURCE 컬럼 값 최신화(BIGQUERY 명시)';

-- (3) 배포된 버전 상태 확인
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;
DESCRIBE DBT PROJECT GN_DW.OPS.DW_PIPELINE;


