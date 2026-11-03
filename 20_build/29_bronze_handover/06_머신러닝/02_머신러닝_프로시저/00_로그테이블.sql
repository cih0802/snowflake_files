-- =============================================================================
-- 머신러닝 프로시저 실행 로그 테이블 생성 (최초 1회만 실행)
-- =============================================================================
CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_PROCEDURE_LOG (
    PROC_NAME VARCHAR,
    STDR_MT VARCHAR,
    START_TIME TIMESTAMP_NTZ,
    END_TIME TIMESTAMP_NTZ,
    DURATION_SEC NUMBER,
    STATUS VARCHAR,
    ERROR_MSG VARCHAR
);