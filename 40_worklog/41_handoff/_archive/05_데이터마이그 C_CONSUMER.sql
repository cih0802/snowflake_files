-- Bronze 4개 스키마 데이터 적재 (GN_DW: CRM/AGENCY/ERP/GA4)
-- Co-authored with CoCo

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
CREATE DATABASE IF NOT EXISTS SANDBOX;
CREATE SCHEMA   IF NOT EXISTS SANDBOX.TOOLS;
CREATE STAGE    IF NOT EXISTS SANDBOX.TOOLS.MIG_LOAD_STAGE;
USE SCHEMA SANDBOX.TOOLS;


------------------------------------------------------------
-- A.1 적재 전 스테이지 검증 (⚠️ 반드시 먼저 수행)
--   과거 사고: B 언로드 스테이지를 비우지 않아 이전 배치 파일이 살아남고,
--   그것이 로컬·C 스테이지까지 함께 옮겨져 아래 두 문제를 일으켰다.
--     (1) 컬럼 수 불일치 → 적재 실패 (BRONZE_ERP 62 vs 64)
--     (2) 동일 스키마 테이블 → 오류 없이 중복 적재
--   업로드 직후 여기서 잡아야 한다. 이상이 있으면 REMOVE 후 재업로드할 것.
------------------------------------------------------------
-- (1) 파일 수 대조: B의 unloaded_files(03번 6단계) 값과 같아야 함
LIST @SANDBOX.TOOLS.MIG_LOAD_STAGE;
SELECT COUNT(*) AS staged_files FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- (2) 진단용 포맷: 줄 전체를 $1 로 읽는다(FIELD_DELIMITER=NONE, 헤더 포함).
--     → 헤더 문자열 비교로 컬럼 수·순서 차이를, 줄 전체 해시로 파일 중복을 동시에 잡는다.
CREATE OR REPLACE FILE FORMAT SANDBOX.TOOLS.FF_CSV_PEEK
  TYPE = CSV
  COMPRESSION = GZIP
  FIELD_DELIMITER = NONE
  SKIP_HEADER = 0;

-- (3) 스테이지 이상 탐지 — 스키마 혼재 + 중복 파일
--     ⚠️ 스테이지 전량 스캔이므로 시간/비용이 든다(브론즈 전체 약 1억 행). 업로드 직후 1회만 실행.
WITH f AS (
  SELECT REGEXP_SUBSTR(METADATA$FILENAME, '^[^/]+/[^/]+')                      AS tbl_path,
         METADATA$FILENAME                                                     AS file_name,
         COUNT(*)                                                              AS lines_in_file,
         HASH_AGG(HASH($1))                                                    AS fingerprint,
         MIN(CASE WHEN METADATA$FILE_ROW_NUMBER = 1 THEN $1 END)               AS header_line
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE
       (FILE_FORMAT => 'SANDBOX.TOOLS.FF_CSV_PEEK', PATTERN => '.*[.]csv[.]gz')
  GROUP BY 1, 2
)
SELECT tbl_path,
       COUNT(*)                          AS files,
       COUNT(DISTINCT header_line)       AS distinct_headers,   -- 1 이 아니면 스키마 혼재
       COUNT(*) - COUNT(DISTINCT fingerprint) AS dup_files,     -- 0 이 아니면 중복 파일
       LISTAGG(file_name, ', ')          AS file_list
FROM f
GROUP BY 1
HAVING COUNT(DISTINCT header_line) > 1
    OR COUNT(*) > COUNT(DISTINCT fingerprint)
ORDER BY 1;
-- → 결과 0건이어야 적재 진행.
--   distinct_headers > 1 : 구/신 스키마 파일 혼재 → 구본 REMOVE
--   dup_files > 0        : 동일 내용 파일 중복 → 하나만 남기고 REMOVE
--   조치 후 (1)부터 다시 확인한다.

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
--   BRONZE_GA4 는 프로시저로 적재하지 않는다.
--   events_* 의 VARIANT 컬럼이 JSON '문자열'로 들어가 col:key / col[0] 탐색이 불가해진다.
--   → GA4 는 전부 A.5 에서 개별 처리.
------------------------------------------------------------
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_ERP');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_AGENCY');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_CRM');
-- CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_GA4');   -- 사용 금지 (위 주석 참조)

------------------------------------------------------------
-- A.5 GA4 적재 — CSV + TRY_PARSE_JSON 변환
-- VARIANT 컬럼 위치(1-based): 4,11,12,14,15,16,18,22,23,24,29  (두 events 테이블 공통)
--   events_20260501 : 30컬럼
--   events_20260719 : 31컬럼 (끝에 event_original_occurrence_timestamp 추가)
--   SYNC_ERR_INFO   : VARIANT 없음 → 일반 COPY
------------------------------------------------------------
-- A.5.1 events_20260501 (30컬럼)
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

-- A.5.2 events_20260719 (31컬럼 — $31 은 스칼라)
COPY INTO GN_DW.BRONZE_GA4."events_20260719"
FROM (
  SELECT $1,$2,$3, TRY_PARSE_JSON($4), $5,$6,$7,$8,$9,$10,
         TRY_PARSE_JSON($11), TRY_PARSE_JSON($12), $13, TRY_PARSE_JSON($14),
         TRY_PARSE_JSON($15), TRY_PARSE_JSON($16), $17, TRY_PARSE_JSON($18),
         $19,$20,$21, TRY_PARSE_JSON($22), TRY_PARSE_JSON($23), TRY_PARSE_JSON($24),
         $25,$26,$27,$28, TRY_PARSE_JSON($29), $30, $31
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_GA4/events_20260719/
)
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT;

-- A.5.3 SYNC_ERR_INFO (운영 로그 — 이관 대상 데이터가 없을 수 있음)
COPY INTO GN_DW.BRONZE_GA4.SYNC_ERR_INFO
FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_GA4/SYNC_ERR_INFO/
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT
PURGE = FALSE;

------------------------------------------------------------
-- A.6 검증
------------------------------------------------------------
-- (1) 스키마별 테이블 수 / 총 행수  → B의 GN_DW_SHARED 집계와 대조
SELECT table_schema, COUNT(*) AS tables, SUM(row_count) AS total_rows
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema LIKE 'BRONZE_%' AND table_type='BASE TABLE'
GROUP BY 1 ORDER BY 1;

-- (2) 빈 테이블 점검 (SYNC_ERR_INFO 는 원본이 비어 있을 수 있어 정상)
SELECT table_schema, table_name
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema LIKE 'BRONZE_%' AND table_type='BASE TABLE' AND row_count=0;

-- (3) GA4 JSON 파싱 확인 → PTYPE=ARRAY, PARSED=N_ROWS 여야 정상
SELECT 'events_20260501' AS tbl, COUNT(*) AS n_rows,
       COUNT("event_params"[0]) AS parsed, TYPEOF("event_params") AS ptype
FROM GN_DW.BRONZE_GA4."events_20260501" GROUP BY 1, 4
UNION ALL
SELECT 'events_20260719', COUNT(*), COUNT("event_params"[0]), TYPEOF("event_params")
FROM GN_DW.BRONZE_GA4."events_20260719" GROUP BY 1, 4;


