------------------------------------------------------
-- 5. 태스크 생성
------------------------------------------------------
USE ROLE GN_DW_ADMIN;

------------------------------------------------------
-- 권한 부여: 태스크 생성에 필요한 스키마 권한
-- (EXECUTE TASK / EXECUTE MANAGED TASK는 02번에서 부여 완료)
------------------------------------------------------
GRANT CREATE TASK ON SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT CREATE TASK ON SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;

USE ROLE GN_DW_ENGINEER;
USE WAREHOUSE GN_DW_ETL_WH;

------------------------------------------------------
-- 5.1 TASK_VALIDATE_BRONZE (Root - 정제 전 품질 게이트, Serverless)
--   품질 위반 시 SP가 예외 발생 → Root 실패 → 후속 child 미실행 (게이팅)
------------------------------------------------------
CREATE OR REPLACE TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'SMALL'
    SCHEDULE = 'USING CRON 30 5 * * * Asia/Seoul'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    USER_TASK_TIMEOUT_MS = 600000
    COMMENT = 'BRONZE 품질 검증 게이트 (매일 05:30 KST). 통과 시에만 후속 정제 트리거'
AS
    CALL GN_DW.SILVER.SP_VALIDATE_BRONZE_DATA();

------------------------------------------------------
-- 5.2 TASK_REFINEMENT_ROOT (Child AFTER VALIDATE - BRONZE→SILVER 정제)
------------------------------------------------------
CREATE OR REPLACE TASK GN_DW.SILVER.TASK_REFINEMENT_ROOT
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'SMALL'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    TASK_AUTO_RETRY_ATTEMPTS = 1
    USER_TASK_TIMEOUT_MS = 3600000
    AFTER GN_DW.SILVER.TASK_VALIDATE_BRONZE
    COMMENT = 'BRONZE→SILVER 전체 정제'
AS
    CALL GN_DW.SILVER.SP_RUN_ALL_REFINEMENT();

------------------------------------------------------
-- 5.2 TASK_REFRESH_FORECAST (Child AFTER REFINEMENT - GOLD 예측 갱신)
------------------------------------------------------
CREATE OR REPLACE TASK GN_DW.SILVER.TASK_REFRESH_FORECAST
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'SMALL'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    USER_TASK_TIMEOUT_MS = 3600000
    AFTER GN_DW.SILVER.TASK_REFINEMENT_ROOT
    COMMENT = 'GOLD 예측 데이터 갱신 (SNOWFLAKE.ML.FORECAST)'
AS
    CALL GN_DW.GOLD.SP_REFRESH_FORECAST_DATA();

------------------------------------------------------
-- 5.2 TASK_FINALIZER (Finalizer - DAG 완료 후 로그)
------------------------------------------------------
CREATE OR REPLACE TASK GN_DW.SILVER.TASK_FINALIZER
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    USER_TASK_TIMEOUT_MS = 60000
    COMMENT = 'DAG 완료 후 상태 로그 기록'
    FINALIZE = GN_DW.SILVER.TASK_VALIDATE_BRONZE
AS
BEGIN
    LET v_root_id VARCHAR := (SELECT SYSTEM$TASK_RUNTIME_INFO('CURRENT_ROOT_TASK_UUID'));
    LET v_start_time TIMESTAMP_LTZ := (SELECT SYSTEM$TASK_RUNTIME_INFO('CURRENT_TASK_GRAPH_ORIGINAL_SCHEDULED_TIMESTAMP')::TIMESTAMP_LTZ);

    INSERT INTO GN_DW.SILVER.ETL_LOG (PROC_NAME, STATUS, ROW_COUNT, ERROR_MSG, ENDED_AT)
    SELECT
        'TASK_GRAPH_RUN',
        CASE WHEN SUM(CASE WHEN STATE = 'FAILED' THEN 1 ELSE 0 END) > 0 THEN 'FAILED' ELSE 'SUCCESS' END,
        COUNT(*),
        LISTAGG(CASE WHEN STATE = 'FAILED' THEN NAME || ': ' || ERROR_MESSAGE ELSE NULL END, '; '),
        CURRENT_TIMESTAMP()
    FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
        ROOT_TASK_ID => :v_root_id,
        SCHEDULED_TIME_RANGE_START => :v_start_time,
        SCHEDULED_TIME_RANGE_END => CURRENT_TIMESTAMP()
    ));
END;

------------------------------------------------------
-- 태스크 활성화 (운영 시작 시 실행)
------------------------------------------------------
-- DAG: VALIDATE_BRONZE(Root) → REFINEMENT_ROOT → REFRESH_FORECAST → FINALIZER(Finalizer)
-- 순서: child/finalizer 먼저 RESUME → Root를 마지막에 RESUME (Root RESUME 시 스케줄 활성화)

-- ALTER TASK GN_DW.SILVER.TASK_FINALIZER RESUME;
-- ALTER TASK GN_DW.SILVER.TASK_REFRESH_FORECAST RESUME;
-- ALTER TASK GN_DW.SILVER.TASK_REFINEMENT_ROOT RESUME;
-- ALTER TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE RESUME;

-- 또는 한번에 (Root 기준 모든 dependent 활성화 + Root RESUME):
-- SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('GN_DW.SILVER.TASK_VALIDATE_BRONZE');

------------------------------------------------------
-- 태스크 중단 (유지보수 시) - Root부터 중단
------------------------------------------------------
-- ALTER TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE SUSPEND;
-- ALTER TASK GN_DW.SILVER.TASK_REFINEMENT_ROOT SUSPEND;
-- ALTER TASK GN_DW.SILVER.TASK_REFRESH_FORECAST SUSPEND;

------------------------------------------------------
-- 수동 실행 (테스트용) - Root 실행 시 전체 DAG 트리거
------------------------------------------------------
-- EXECUTE TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE;
