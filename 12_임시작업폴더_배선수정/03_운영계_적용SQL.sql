-- ============================================================================
-- [GN_DW] 배선 수정 및 개명 원복 운영계 적용 SQL
-- ============================================================================
-- 문서 ID: GN_DW_REWIRE_PROD_SQL_O156
-- 생성일: 2026-09-11
-- 작성자: O156
-- 🔴 주의: 본 쿼리는 운영계(PROD) 적용 전용입니다.
--    개발계정(wz61282)은 데이터 미적재 환경이므로 본 세션에서는 실행하지 않습니다.
--    운영계 DBA/담당 엔지니어가 순서대로 실행합니다.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. GOLD 팩트 테이블 개명 원복 (현업 「중단고객 분석 보고서」 참조명 복원)
-- ----------------------------------------------------------------------------
-- ⚠️ 실행 전 확인: SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_LIFECYCLE;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_LIFECYCLE RENAME TO GN_DW.GOLD.FACT_MEMBER_EVENT;

-- ⚠️ RENAME 직후 GN_DW.GOLD.WIDE_MEMBER_EVENT 뷰가 무효화됩니다.
--    반드시 아래 dbt run 또는 뷰 DDL을 통해 WIDE 뷰를 재생성해야 합니다.


-- ----------------------------------------------------------------------------
-- 2. Two-tier 시점 동결 컬럼 제거 (탈배선 정합화)
-- ----------------------------------------------------------------------------
-- ⚠️ 사유: 이력 0건으로 실효가 없고(현재값과 100% 동일),
--    COMMENT가 'Snapshot 기반 시점 동결'을 거짓 표명하여 AI/Analyst를 오도하므로 제거합니다.
--    dbt 모델 및 DDL 정본과 물리 테이블의 컬럼 집합을 일치시킵니다.
ALTER TABLE GN_DW.GOLD.DIM_MEMBER_ACQUISITION DROP COLUMN ACQ_CAMPAIGN_NAME_AT_ACQ;
ALTER TABLE GN_DW.GOLD.DIM_MEMBER_ACQUISITION DROP COLUMN ACQ_DEPARTMENT_AT_ACQ;


-- ----------------------------------------------------------------------------
-- 3. 스냅샷 이력 축적 Task DAG 등록 (운영계 일배치 스케줄링)
-- ----------------------------------------------------------------------------
-- 🔴 사유: 개발계정 실측 시 Task 0건 확인됨(R2-8-4-d).
--    스냅샷 이력이 실제로 쌓이도록 운영계에 일배치 DAG를 등록합니다.
--    (선이력·후배선 원칙: 스냅샷을 먼저 실행하여 이력을 축적함)

CREATE OR REPLACE TASK GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = 'USING CRON 30 5 * * * Asia/Seoul'
    COMMENT   = 'BRONZE 마스터 11종 SCD2 이력 축적. 소비처 0(의도) — 배선은 현업 허가 후 추가.'
AS
    EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS = 'snapshot';

CREATE OR REPLACE TASK GN_DW.OPS.TASK_DW_BUILD_DAILY
    WAREHOUSE = COMPUTE_WH
    AFTER     = GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY
    COMMENT   = 'BRONZE→SILVER→GOLD 일배치. 스냅샷과 분리(선이력·후배선).'
AS
    EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS = 'build';

-- DAG 활성화 (자식 태스크부터 RESUME 후 루트 태스크 RESUME)
ALTER TASK GN_DW.OPS.TASK_DW_BUILD_DAILY RESUME;
ALTER TASK GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY RESUME;


-- ----------------------------------------------------------------------------
-- 4. 등록 상태 확인 쿼리 (2축 검증)
-- ----------------------------------------------------------------------------
SHOW TASKS IN SCHEMA GN_DW.OPS;
SELECT TASK_NAME, STATE, SCHEDULE, CONDITION 
FROM SNOWFLAKE.ACCOUNT_USAGE.TASKS
WHERE TASK_DATABASE = 'GN_DW' AND DELETED IS NULL;
