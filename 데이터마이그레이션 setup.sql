-- Bronze 4개 스키마 데이터 적재 (GN_DW: CRM/AGENCY/ERP/GA4)
-- Co-authored with CoCo

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
CREATE DATABASE IF NOT EXISTS SANDBOX;
CREATE SCHEMA   IF NOT EXISTS SANDBOX.TOOLS;
CREATE STAGE    IF NOT EXISTS SANDBOX.TOOLS.MIG_LOAD_STAGE;
USE SCHEMA SANDBOX.TOOLS;


------------------------------------------------------------
-- A.2 적재용 파일 포맷 생성 (NULL 토큰 \\N 3글자 대응)
------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT SANDBOX.TOOLS.FF_CSV_LOAD
  TYPE = CSV
  COMPRESSION = GZIP
  FIELD_DELIMITER = ','
  RECORD_DELIMITER = '\n'
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('\\\\N', '\\N', '')
  EMPTY_FIELD_AS_NULL = TRUE
  TRIM_SPACE = FALSE
  ESCAPE_UNENCLOSED_FIELD = NONE;

------------------------------------------------------------
-- A.3 스키마 일괄 적재 프로시저
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA(SCH STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  c1 CURSOR FOR
    SELECT table_name FROM GN_DW.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = ? AND table_type = 'BASE TABLE';
  v_tbl STRING DEFAULT NULL;
  v_sql STRING;
  v_cnt INT DEFAULT 0;
BEGIN
  OPEN c1 USING (SCH);
  LOOP
    v_tbl := NULL;
    FETCH c1 INTO v_tbl;
    IF (v_tbl IS NULL) THEN
      BREAK;
    END IF;
    v_sql := 'COPY INTO GN_DW."' || :SCH || '"."' || :v_tbl || '" '
          || 'FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/' || :SCH || '/' || :v_tbl || '/ '
          || 'FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD) '
          || 'ON_ERROR = ABORT_STATEMENT PURGE = FALSE';
    EXECUTE IMMEDIATE :v_sql;
    v_cnt := v_cnt + 1;
  END LOOP;
  CLOSE c1;
  RETURN 'schema ' || :SCH || ' loaded tables: ' || v_cnt;
END;
$$;

------------------------------------------------------------
-- A.4 CSV 스키마 적재 실행 (ERP → AGENCY → CRM 순)
------------------------------------------------------------
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_ERP');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_AGENCY');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_CRM');

------------------------------------------------------------
-- A.5 GA4 적재 — CSV + TRY_PARSE_JSON 변환
-- VARIANT 컬럼 위치(1-based): 4,11,12,14,15,16,18,22,23,24,29
------------------------------------------------------------
COPY INTO GN_DW.BRONZE_GA4."events_20260501"
FROM (
  SELECT $1,$2,$3, TRY_PARSE_JSON($4), $5,$6,$7,$8,$9,$10,
         TRY_PARSE_JSON($11), TRY_PARSE_JSON($12), $13, TRY_PARSE_JSON($14),
         TRY_PARSE_JSON($15), TRY_PARSE_JSON($16), $17, TRY_PARSE_JSON($18),
         $19,$20,$21, TRY_PARSE_JSON($22), TRY_PARSE_JSON($23), TRY_PARSE_JSON($24),
         $25,$26,$27,$28, TRY_PARSE_JSON($29), $30
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_GA4/events_20260501/
)
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT;

------------------------------------------------------------
-- A.6 검증
------------------------------------------------------------
SELECT table_schema, COUNT(*) AS tables, SUM(row_count) AS total_rows
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema LIKE 'BRONZE_%' AND table_type='BASE TABLE'
GROUP BY 1 ORDER BY 1;

SELECT table_schema, table_name
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema LIKE 'BRONZE_%' AND table_type='BASE TABLE' AND row_count=0;
