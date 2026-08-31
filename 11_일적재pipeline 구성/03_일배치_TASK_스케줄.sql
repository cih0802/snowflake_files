-- 일배치 TASK 등록 — dbt build --target dev2 (BRONZE_CRM_2 → SILVER_2/GOLD_2) 자동화
-- Co-authored with CoCo
--
-- 전제: 01_스키마생성_및_구조복제.sql, 02_권한부여_LOADER_ENGINEER_ADMIN.sql 실행 완료 +
--       `dbt build --target dev2` 수동 1회 테스트 성공(00_개요_및_실행순서.md §실행순서 4).
-- 소유 role: GN_DW_ENGINEER (dbt 실행 role과 동일 — 신규 role 없음, 기존 role 재사용 원칙 유지).
-- 배치 대상: GN_DW.OPS.DW_PIPELINE (기존 배포된 dbt 프로젝트, 신규 프로젝트 아님).

/* =====================================================================
   0) 사전 권한 확인/부여 — 계정 레벨 EXECUTE TASK 는 ACCOUNTADMIN 전용 구간
      (02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql 헤더 소유 모델과 동일 원칙:
       계정 레벨 권한은 ACCOUNTADMIN 유지 · GN_DW_ADMIN 으로는 부여 불가).
   ===================================================================== */
-- 최초 1회만 필요(이미 부여돼 있다면 재실행 무해):
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE GN_DW_ENGINEER;

-- OPS 스키마에 TASK 생성 권한 (07 §D.6 은 USAGE·CREATE TABLE 만 부여했다 — CREATE TASK 추가)
USE ROLE GN_DW_ADMIN;
GRANT CREATE TASK ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ENGINEER;

/* =====================================================================
   1) TASK 생성 — 매일 새벽 3시(Asia/Seoul, UTC+9 → cron 은 UTC 기준 18시) 실행
      실패 2회 연속 시 자동 SUSPEND(운영 전환 전 테스트 단계이므로 조기 발견 우선).
   ===================================================================== */
USE ROLE GN_DW_ENGINEER;

CREATE TASK IF NOT EXISTS GN_DW.OPS.TASK_DBT_DAILY_DEV2
  WAREHOUSE = GN_DW_ETL_WH
  SCHEDULE = 'USING CRON 0 18 * * * UTC'  -- Asia/Seoul 03:00
  SUSPEND_TASK_AFTER_NUM_FAILURES = 2
  COMMENT = '일적재 테스트 — BRONZE_CRM_2 -> SILVER_2/GOLD_2 (dbt target=dev2). 11_일적재pipeline 구성 산출물.'
AS
  EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS = 'build --target dev2';

-- 최초 생성 시 SUSPENDED 상태이므로 명시적으로 RESUME 해야 스케줄이 돈다.
ALTER TASK GN_DW.OPS.TASK_DBT_DAILY_DEV2 RESUME;

/* =====================================================================
   2) 수동 1회 실행(스케줄 대기 없이 즉시 검증하고 싶을 때)
   ===================================================================== */
-- EXECUTE TASK GN_DW.OPS.TASK_DBT_DAILY_DEV2;

/* =====================================================================
   3) 모니터링
   ===================================================================== */
-- SHOW TASKS LIKE 'TASK_DBT_DAILY_DEV2' IN SCHEMA GN_DW.OPS;
-- SELECT * FROM TABLE(GN_DW.INFORMATION_SCHEMA.TASK_HISTORY(
--   TASK_NAME => 'TASK_DBT_DAILY_DEV2', SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())
-- )) ORDER BY SCHEDULED_TIME DESC;

/* =====================================================================
   4) 테스트 종료/정리 시 (필요할 때만 실행 — 기본 비활성 상태로 둠)
   ===================================================================== */
-- ALTER TASK GN_DW.OPS.TASK_DBT_DAILY_DEV2 SUSPEND;
-- DROP TASK GN_DW.OPS.TASK_DBT_DAILY_DEV2;
