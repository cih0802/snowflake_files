-- C 계정(Target) 실행 SQL — Bronze 4개 스키마 데이터 적재 (GN_DW: CRM/AGENCY/ERP/GA4)
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   로컬에서 업로드한 CSV(GZIP)를 검증한 뒤 GN_DW 브론즈 53개 테이블에 적재하고,
--   GA4 VARIANT 컬럼을 TRY_PARSE_JSON 으로 복원한 다음 행수·무결성을 대조한다.
--
-- 실행 계정 / 역할
--   C (Target), ACCOUNTADMIN, WH=COMPUTE_WH — 계정 zx03676
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md
--              → 5.2(파일포맷/스테이지) / 5.3.1(적재 전 검증) / 5.4(일괄 적재) / 5.5(GA4) / 6장(검증) / 7장(정리)
--   [선행 필수] 50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql
--              → 반드시 먼저 실행해 테이블 53개를 생성한다. 미실행 시 loaded tables: 0.
--   [선행 SQL] 50_handoff/02_데이터마이그 A_PRODUCER.sql  (A: 공유/DDL 추출)
--              50_handoff/03_데이터마이그 B_BROKER.sql    (B: 공유 마운트/CSV 언로드)
--
-- 식별자 / IDENTIFIERS
--   적재 스테이지 = @SANDBOX.TOOLS.MIG_LOAD_STAGE/<SCHEMA>/<TABLE>/
--   파일 포맷 = SANDBOX.TOOLS.FF_CSV_LOAD (적재) · SANDBOX.TOOLS.FF_CSV_PEEK (진단)
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
CREATE DATABASE IF NOT EXISTS SANDBOX;
CREATE SCHEMA   IF NOT EXISTS SANDBOX.TOOLS;
CREATE STAGE    IF NOT EXISTS SANDBOX.TOOLS.MIG_LOAD_STAGE;
USE SCHEMA SANDBOX.TOOLS;


------------------------------------------------------------
-- A.1 적재 전 스테이지 검증 (⚠️ 반드시 먼저 수행)
--   여기서 잡아야 하는 사고는 원인이 두 종류다. 둘 다 증상이 '컬럼 수 불일치'로 같아서
--   혼동하기 쉬우므로 검사도 두 갈래로 나눠 둔다.
--
--   [원인 A] 스테이지에 이전 배치 파일이 남았다 (파일 쪽 문제)
--     B 언로드 스테이지를 비우지 않아 구 스키마 파일이 살아남고, 그것이 로컬·C까지 옮겨졌다.
--       (1) 구/신 파일 혼재    → 컬럼 수 불일치로 적재 실패
--       (2) 동일 스키마 중복본 → 오류 없이 중복 적재 (더 위험)
--     → 아래 (3) 에서 파일끼리 헤더·지문을 비교해 잡는다.
--
--   [원인 B] 04번 DDL 테이블 구조가 CSV와 다르다 (테이블 쪽 문제)
--     B 언로드는 'SELECT * FROM GN_DW_SHARED...' 이므로 CSV 헤더가 곧 A 원본 구조다.
--     즉 CSV 가 정본이고, 04번 DDL 이 원본과 어긋나면 그 테이블만 적재가 깨진다.
--     실제 발생: 2026-08-13 BRONZE_ERP.BDGT_ACMSLT_LEDGER
--       "Number of columns in file (65) does not match that of the corresponding table (64)"
--       원인 — 04번 DDL 에 MNYRS_COST_DIV_YN(13번째, '모금비구분') 이 누락되어 있었다.
--     ⚠️ (3) 은 파일끼리만 비교하므로 이 유형을 절대 잡지 못한다(모든 파일 헤더가 동일하므로 통과).
--     → 아래 (4) 에서 CSV 헤더 ↔ 대상 테이블 컬럼을 대조해 잡는다. 이것이 유일한 방어선이다.
--
--   이상이 있으면: 원인 A → REMOVE 후 재업로드 / 원인 B → 04번 DDL 수정 후 테이블 재생성.
------------------------------------------------------------
-- (1) 파일 수 대조: B의 언로드 결과(03번 6단계)와 같아야 함
--     2026-08-12 B 기준값: 435 파일 / 52 폴더 / 3,427,853,840 B
--       BRONZE_AGENCY 4폴더 5파일 · BRONZE_CRM 45폴더 389파일
--       BRONZE_ERP    1폴더 1파일 · BRONZE_BIGQUERY 2폴더  40파일
--     ⚠️ 폴더가 52개인 이유: BRONZE_BIGQUERY.SYNC_ERR_INFO 는 0행이라 언로드 파일이 없다.
--        테이블은 53개를 만들되 이 테이블만 0건 적재되는 것이 정상이다.
LIST @SANDBOX.TOOLS.MIG_LOAD_STAGE;

SELECT SPLIT_PART("name", '/', 2) AS table_schema,
       COUNT(DISTINCT SPLIT_PART("name", '/', 3)) AS table_folders,
       COUNT(*)    AS files,
       SUM("size") AS bytes
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
GROUP BY 1 ORDER BY 1;

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

-- (4) ⭐ CSV 헤더 ↔ 대상 테이블 구조 대조 — [원인 B] 방어선 (04번 DDL 오류 탐지)
--     COPY 는 '위치 기반' 적재이므로 컬럼 수뿐 아니라 순서까지 같아야 한다.
--     헤더 1줄만 읽으므로 (3) 과 달리 비용이 거의 없다. 04번 DDL 실행 직후 반드시 실행할 것.
--     ⚠️ 04번 DDL(테이블 생성)이 끝난 뒤에 실행해야 한다. 미실행 시 전 테이블이 TABLE_MISSING 으로 나온다.
WITH stage_hdr AS (
  SELECT SPLIT_PART(METADATA$FILENAME, '/', 1)                              AS sch,
         SPLIT_PART(METADATA$FILENAME, '/', 2)                              AS tbl,
         MIN(CASE WHEN METADATA$FILE_ROW_NUMBER = 1 THEN $1::VARCHAR END)   AS header_line
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE
       (FILE_FORMAT => 'SANDBOX.TOOLS.FF_CSV_PEEK', PATTERN => '.*[.]csv[.]gz')
  GROUP BY 1, 2
),
f AS (
  SELECT sch, tbl,
         ARRAY_SIZE(SPLIT(header_line, ','))              AS file_cols,
         UPPER(REPLACE(header_line, '"', ''))             AS file_col_list
  FROM stage_hdr
),
t AS (
  SELECT table_schema AS sch, table_name AS tbl,
         COUNT(*)                                                                       AS tbl_cols,
         UPPER(LISTAGG(column_name, ',') WITHIN GROUP (ORDER BY ordinal_position))       AS tbl_col_list
  FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
  WHERE table_schema LIKE 'BRONZE_%'
  GROUP BY 1, 2
)
SELECT COALESCE(f.sch, t.sch) AS sch,
       COALESCE(f.tbl, t.tbl) AS tbl,
       f.file_cols, t.tbl_cols,
       CASE
         WHEN t.tbl_cols IS NULL                        THEN 'TABLE_MISSING — 04번 DDL 미실행/테이블명 불일치'
         WHEN f.file_cols IS NULL                       THEN 'FILE_MISSING — 스테이지 폴더 없음 (0행 테이블이면 정상)'
         WHEN f.file_cols <> t.tbl_cols                 THEN 'COUNT_MISMATCH — 04번 DDL 컬럼 누락/추가'
         WHEN f.file_col_list <> t.tbl_col_list          THEN 'ORDER_OR_NAME_MISMATCH — 위치 적재 시 값 밀림 위험'
       END AS diagnosis,
       f.file_col_list, t.tbl_col_list
FROM f FULL OUTER JOIN t ON f.sch = t.sch AND f.tbl = t.tbl
WHERE f.file_cols     IS DISTINCT FROM t.tbl_cols
   OR f.file_col_list IS DISTINCT FROM t.tbl_col_list
ORDER BY 1, 2;
-- → 기대 결과: BRONZE_BIGQUERY / SYNC_ERR_INFO 의 FILE_MISSING 1건만 나온다 (원본 A도 0행 → 정상).
--   COUNT_MISMATCH / ORDER_OR_NAME_MISMATCH 가 나오면 절대 적재하지 말고 04번 DDL 을 먼저 고친다.
--     · 정본은 50_handoff/02_1_A DB정보.sql (A 계정 GET_DDL 실측) 이다.
--     · file_col_list 와 tbl_col_list 를 나란히 놓고 어긋나는 지점을 찾는다.
--     · 수정 후 해당 테이블만 CREATE OR REPLACE 하고 이 쿼리를 다시 돌린다.
--   TABLE_MISSING 이 다수면 04번 DDL 자체를 실행하지 않은 것이다.
--   ORDER_OR_NAME_MISMATCH 는 COPY 가 오류 없이 통과할 수 있어 가장 위험하다. 반드시 해소할 것.

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
--   BRONZE_BIGQUERY 는 프로시저로 적재하지 않는다.
--   events_* 의 VARIANT 컬럼이 JSON '문자열'로 들어가 col:key / col[0] 탐색이 불가해진다.
--   → GA4 는 전부 A.5 에서 개별 처리.
--   프로시저는 INFORMATION_SCHEMA 를 순회하므로 04번 DDL로 생성된 테이블 수를 그대로 따른다.
--   기대 반환값: ERP 'loaded tables: 1' / AGENCY 'loaded tables: 4' / CRM 'loaded tables: 45'
--   ⚠️ CRM 이 43 으로 나오면 04번 DDL 2판(51테이블)을 실행한 것이다. 3판으로 다시 생성할 것.
--   ⚠️ 선행 조건: A.1 (4) 가 'FILE_MISSING 1건(BRONZE_BIGQUERY.SYNC_ERR_INFO)' 외 0건이어야 한다.
--      COUNT_MISMATCH 가 남아 있으면 해당 테이블에서 ON_ERROR=ABORT_STATEMENT 로 CALL 전체가 중단된다.
--        예) 2026-08-13 BRONZE_ERP — file 65 vs table 64 로 프로시저 21행(EXECUTE IMMEDIATE)에서 실패.
--   ⚠️ 중단 후 재실행은 안전하다. COPY 는 FORCE=TRUE 가 없으면 이미 적재된 파일을 건너뛴다(적재 메타데이터 64일).
--      단, 실패한 테이블을 CREATE OR REPLACE 로 다시 만들었다면 그 테이블의 메타데이터도 초기화되어 정상 재적재된다.
------------------------------------------------------------
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_CRM');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_AGENCY');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_ERP');
-- CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_BIGQUERY');   -- 사용 금지 (위 주석 참조)

------------------------------------------------------------
-- A.5 GA4 적재 — CSV + TRY_PARSE_JSON 변환
-- VARIANT 컬럼 위치(1-based): 4,11,12,14,15,16,18,22,23,24,29  (두 events 테이블 공통)
--   events_20260501 : 30컬럼
--   events_20260719 : 31컬럼 (끝에 event_original_occurrence_timestamp 추가)
--   SYNC_ERR_INFO   : VARIANT 없음 → 일반 COPY
------------------------------------------------------------
-- A.5.1 events_20260501 (30컬럼)
COPY INTO GN_DW.BRONZE_BIGQUERY."events_20260501"
FROM (
  SELECT $1,$2,$3, TRY_PARSE_JSON($4), $5,$6,$7,$8,$9,$10,
         TRY_PARSE_JSON($11), TRY_PARSE_JSON($12), $13, TRY_PARSE_JSON($14),
         TRY_PARSE_JSON($15), TRY_PARSE_JSON($16), $17, TRY_PARSE_JSON($18),
         $19,$20,$21, TRY_PARSE_JSON($22), TRY_PARSE_JSON($23), TRY_PARSE_JSON($24),
         $25,$26,$27,$28, TRY_PARSE_JSON($29), $30
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_BIGQUERY/events_20260501/
)
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT;

-- A.5.2 events_20260719 (31컬럼 — $31 은 스칼라)
COPY INTO GN_DW.BRONZE_BIGQUERY."events_20260719"
FROM (
  SELECT $1,$2,$3, TRY_PARSE_JSON($4), $5,$6,$7,$8,$9,$10,
         TRY_PARSE_JSON($11), TRY_PARSE_JSON($12), $13, TRY_PARSE_JSON($14),
         TRY_PARSE_JSON($15), TRY_PARSE_JSON($16), $17, TRY_PARSE_JSON($18),
         $19,$20,$21, TRY_PARSE_JSON($22), TRY_PARSE_JSON($23), TRY_PARSE_JSON($24),
         $25,$26,$27,$28, TRY_PARSE_JSON($29), $30, $31
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_BIGQUERY/events_20260719/
)
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT;

-- A.5.3 SYNC_ERR_INFO (운영 로그 — 이관 대상 데이터가 없을 수 있음)
COPY INTO GN_DW.BRONZE_BIGQUERY.SYNC_ERR_INFO
FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_BIGQUERY/SYNC_ERR_INFO/
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
-- 기대값 (2026-08-12 A/B 실측):
--   BRONZE_AGENCY   4 /     243,550
--   BRONZE_CRM     45 / 115,875,113
--   BRONZE_ERP      1 /       4,301
--   BRONZE_BIGQUERY      3 /     576,441
--   합계           53 / 116,699,405

-- (2) 빈 테이블 점검
--     기대: BRONZE_BIGQUERY.SYNC_ERR_INFO 1건만 나온다 (원본 A도 0행 → 정상).
--     그 외 테이블이 나오면 해당 폴더의 파일이 누락된 것이므로 재업로드·재적재한다.
SELECT table_schema, table_name
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema LIKE 'BRONZE_%' AND table_type='BASE TABLE' AND row_count=0;

-- (3) GA4 JSON 파싱 확인 → PTYPE=ARRAY, PARSED=N_ROWS 여야 정상
SELECT 'events_20260501' AS tbl, COUNT(*) AS n_rows,
       COUNT("event_params"[0]) AS parsed, TYPEOF("event_params") AS ptype
FROM GN_DW.BRONZE_BIGQUERY."events_20260501" GROUP BY 1, 4
UNION ALL
SELECT 'events_20260719', COUNT(*), COUNT("event_params"[0]), TYPEOF("event_params")
FROM GN_DW.BRONZE_BIGQUERY."events_20260719" GROUP BY 1, 4;

-- (4) 테이블별 행수 대조표 (⚠️ 01번 문서 6.2의 '미완료(권장)' 항목)
--     이 결과를 03번 3.1(B의 GN_DW_SHARED 스냅샷)과 테이블 단위로 비교한다.
--     스키마별 합계만 맞고 테이블별로 어긋나는 경우(중복 적재 + 누락 상쇄)를 잡는 유일한 검사다.
SELECT table_schema, table_name, row_count, bytes
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema LIKE 'BRONZE_%' AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;

-- (5) VALIDATE — 직전 COPY의 거부 행 확인 (기대: 0건)
--     ⚠️ JOB_ID => '_last' 는 '현재 세션의 마지막 COPY' 기준이므로,
--        각 COPY 직후에 실행해야 의미가 있다. 사후 점검은 아래 COPY_HISTORY를 쓴다.
-- SELECT * FROM TABLE(VALIDATE(GN_DW.BRONZE_BIGQUERY."events_20260719", JOB_ID => '_last'));

--     세션이 끊긴 뒤에는 COPY_HISTORY 로 전체 적재 이력을 확인한다.
--     기대: STATUS = 'Loaded', ERROR_COUNT = 0, ROW_PARSED = ROW_COUNT
SELECT table_schema_name, table_name, file_name, status,
       row_count, row_parsed, error_count, first_error_message, last_load_time
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE table_schema_name LIKE 'BRONZE_%'
  AND last_load_time >= DATEADD('day', -2, CURRENT_TIMESTAMP())
  AND (status <> 'Loaded' OR error_count > 0)
ORDER BY last_load_time DESC;
-- → 0건이어야 정상. (ACCOUNT_USAGE 는 최대 2시간 지연될 수 있다.
--    즉시 확인이 필요하면 INFORMATION_SCHEMA.COPY_HISTORY 테이블 함수를 쓴다.)

------------------------------------------------------------
-- A.7 정리(Teardown) — 01번 문서 7장
--   ⚠️ A.6 검증이 전부 통과한 뒤에만 실행한다.
--      스테이지를 비우면 재적재 시 로컬 업로드부터 다시 해야 한다.
------------------------------------------------------------
-- REMOVE @SANDBOX.TOOLS.MIG_LOAD_STAGE/;
-- LIST   @SANDBOX.TOOLS.MIG_LOAD_STAGE;    -- 0건이어야 함

-- 진단용 임시 객체 정리 (FF_CSV_LOAD 는 재적재 대비 남겨둘 수 있다)
-- DROP FILE FORMAT IF EXISTS SANDBOX.TOOLS.FF_CSV_PEEK;
-- DROP PROCEDURE  IF EXISTS SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA(STRING);



