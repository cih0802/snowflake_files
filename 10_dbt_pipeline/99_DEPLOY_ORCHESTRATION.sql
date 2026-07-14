-- GN_DW SILVER dbt 파이프라인 배포·오케스트레이션 DDL (순서 7-D). ⚠️ 저작 전용 — 본 세션 미실행.
-- Co-authored with CoCo
-- ============================================================================
-- 순서 7 방침: dbt 모델(BRONZE→SILVER 32객체) 저작 + 배포/스케줄 DDL 저작까지.
--   · materialized='table' (INSERT OVERWRITE 멱등 = full_refresh 동치, 정본 7-E).
--   · GOLD 는 순서 8(별도 세션) — enabled:false 로 본 파이프라인에서 제외.
--   · SILVER 32객체는 이미 적재·검증 완료 → 아래 EXECUTE 는 재생성이므로 신중히 실행(멱등이나 데이터 재작성).
-- 워크스페이스 스테이지: snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- (1) DBT PROJECT 객체 생성 — 워크스페이스 dbt 프로젝트를 Snowflake 네이티브 객체로 배포
-- ─────────────────────────────────────────────────────────────────────────
CREATE DBT PROJECT IF NOT EXISTS GN_DW.SILVER.GN_DW_SILVER_PIPELINE
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = 'BRONZE→SILVER 정제 파이프라인(32객체). 정본 09_SILVER_적재쿼리_20260714. 순서 7.';

-- 배포 후 확인
-- SHOW DBT PROJECTS IN SCHEMA GN_DW.SILVER;

-- ─────────────────────────────────────────────────────────────────────────
-- (2) 검증 — 실제 테이블 생성 없이 파싱/컴파일만 (안전, SILVER 데이터 불변)
-- ─────────────────────────────────────────────────────────────────────────
-- EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='parse';
-- EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='compile';

-- ─────────────────────────────────────────────────────────────────────────
-- (3) 전체 실행(재생성) — ⚠️ 검증완료 SILVER 32테이블을 CREATE OR REPLACE (멱등). 실행 판단 후 주석 해제.
--     dbt ref DAG 가 의존순서 자동 보장: CRM_CODE→CRM_*, CRM_MEMBER_SPONSOR_BIZ→CRM_SPONSOR_RELATION,
--     (GA4_IDENTITY + CRM_MEMBER)→IDENTITY_MEMBER_XREF. CRM/ERP/AGENCY/GA4 는 상호 독립(병렬 스케줄).
-- ─────────────────────────────────────────────────────────────────────────
-- EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='run';                      -- 전체
-- EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='run --select silver.ga4+'; -- GA4 샤드 입고 시(하류 XREF 포함)
-- EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='test';                      -- not_null 등 스키마 테스트

-- ─────────────────────────────────────────────────────────────────────────
-- (4) 스케줄 TASK (순서 7-D) — 일배치. ⚠️ CREATE 후 RESUME 해야 가동. 저작만: 실행/RESUME 보류.
--     · CRM/ERP/AGENCY/GA4 는 dbt DAG 내 독립 → 단일 EXECUTE 로 dbt 가 병렬 처리(threads=4).
--     · GA4 신규 샤드(events_YYYYMMDD) 입고 트리거는 별도 STREAM/외부 오케스트레이션 소관(커넥터).
-- ─────────────────────────────────────────────────────────────────────────
CREATE TASK IF NOT EXISTS GN_DW.SILVER.TASK_SILVER_DAILY
  WAREHOUSE = COMPUTE_WH
  SCHEDULE  = 'USING CRON 0 5 * * * Asia/Seoul'   -- 매일 05:00 KST
  COMMENT   = 'BRONZE→SILVER 32객체 일배치 재정제(dbt run). 순서 7-D.'
AS
  EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='run';

-- (선택) GA4 전용 태스크 — 전기간 샤드 입고 파이프라인이 별도 스케줄일 때 분리 운영.
-- CREATE TASK IF NOT EXISTS GN_DW.SILVER.TASK_SILVER_GA4
--   WAREHOUSE = COMPUTE_WH
--   SCHEDULE  = 'USING CRON 0 6 * * * Asia/Seoul'
--   COMMENT   = 'GA4 5객체 + 하류 XREF 재정제(샤드 입고 후).'
-- AS
--   EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='run --select silver.ga4+';

-- 가동(저작 단계에서는 보류):
-- ALTER TASK GN_DW.SILVER.TASK_SILVER_DAILY RESUME;
-- 모니터링:
-- SELECT * FROM TABLE(GN_DW.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME=>'TASK_SILVER_DAILY')) ORDER BY SCHEDULED_TIME DESC;
