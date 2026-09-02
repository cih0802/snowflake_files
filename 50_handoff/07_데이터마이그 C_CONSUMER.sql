-- C 계정(Target) 실행 SQL — 브론즈 3개 스키마 + SILVER 정제 테이블 + ML 예측결과 적재
-- 2026-08-20
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   로컬에서 업로드한 CSV(GZIP)를 검증한 뒤 GN_DW 에 적재하고,
--   반정형 컬럼(SILVER.ITEMS · ML.PREDICTION)을 TRY_PARSE_JSON 으로 복원한 다음
--   행수·무결성을 대조한다.
--
-- 이관 경로 / TOPOLOGY
--   A ──(Direct Share · 동일 리전)──▶ B ──(로컬 다운로드)──▶ 로컬 ──(업로드)──▶ C (다른 리전)
--   본 파일은 그 중 **C 구간**을 담당한다.
--
-- 실행 계정 / 역할
--   C (Target), ACCOUNTADMIN, WH=COMPUTE_WH
--   ⚠️ 계정 식별자는 실행 직전에 `SELECT CURRENT_ACCOUNT();` 로 확인한다.
--      과거 문서에 기재된 zx03676 / DV07626 은 재구축으로 바뀐 이력이 있다.
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md
--              → 5.2(파일포맷/스테이지) / 5.3.1(적재 전 검증) / 5.4(일괄 적재) /
--                5.5(SILVER) / 5.6(ML) / 6장(검증) / 7장(정리)
--   [선행 필수] 50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql   → 브론즈 52 테이블 생성
--              50_handoff/06_데이터마이그 GN_DW_SILVER_DDL_20260820.sql   → SILVER 1 테이블 생성
--              50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql       → ML 16 테이블 생성
--              ⚠️ 셋 다 먼저 실행해야 한다. 미실행 시 loaded tables: 0. 상호 선후 관계는 없다.
--   [선행 SQL] 50_handoff/02_데이터마이그 A_PRODUCER.sql  (A: 공유/DDL 추출)
--              50_handoff/03_데이터마이그 B_BROKER.sql    (B: 공유 마운트/CSV 언로드)
--
-- 갱신 이력 / CHANGES
--   2026-08-29  선행 DDL 3종의 2026-08-29 갱신에 맞춰 **수치·파일명만** 정정했다(SQL 본문 무변경).
--     · 브론즈 50 → **52** (CRM 45 → 46 · ERP 1 → 2) · 총계 67 → **69**
--     · 파일명 정정: 「04_2번 SILVER」 → **06번** (실제 파일명이 06_ 이다)
--     · 🔴 A.1 [원인 B] 사례(2026-08-13 BDGT_ACMSLT_LEDGER)의 **결론이 뒤집혔다** — 아래 A.1 참조.
--     · A.1 (4) · A.6 (1) 의 SQL 은 스키마 조건으로 돌기 때문에 **쿼리 수정이 불필요**했다
--       (테이블이 늘어도 자동으로 포함된다). 고친 것은 주석의 기대값뿐이다.
--
-- 식별자 / IDENTIFIERS
--   적재 스테이지 = @SANDBOX.TOOLS.MIG_LOAD_STAGE/<SCHEMA>/<TABLE>/
--   파일 포맷 = SANDBOX.TOOLS.FF_CSV_LOAD (적재) · SANDBOX.TOOLS.FF_CSV_PEEK (진단)
--
-- 적재 대상 / SCOPE (69 테이블)
--   BRONZE_CRM 46 · BRONZE_AGENCY 4 · BRONZE_ERP 2   → A.4 프로시저 일괄 적재
--   SILVER.BIGQUERY_REFINED_DATA 1                    → A.5 개별 적재
--   ML.ML_RST_DATA_* 16                               → A.5-B (12종 프로시저 + 4종 개별)
--
-- 🔴 반정형 컬럼 총람 (일반 COPY 금지 · 전부 TRY_PARSE_JSON 변환 필요)
--   SILVER.BIGQUERY_REFINED_DATA    118컬럼 · ARRAY   $118 (ITEMS)         → A.5
--   ML.ML_RST_DATA_SPNSR_CHURN_12M   18컬럼 · VARIANT $18  (PREDICTION)    → A.5-B.2
--   ML.ML_RST_DATA_MBER_CHURN_12M    18컬럼 · VARIANT $18  (PREDICTION)    → A.5-B.2
--   ML.ML_RST_DATA_MBER_INC_12M      21컬럼 · VARIANT $21  (PREDICTION)    → A.5-B.2
--   ML.ML_RST_DATA_LOYAL_MBER        22컬럼 · VARIANT $22  (PREDICTION)    → A.5-B.2
--   ⇒ 브론즈 52개 테이블에는 반정형 컬럼이 없다. A.4 프로시저로 그대로 처리 가능하다.
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
--   [원인 B] DDL 테이블 구조가 CSV와 다르다 (테이블 쪽 문제)
--     B 언로드는 'SELECT * FROM GN_DW_SHARED...' 이므로 CSV 헤더가 곧 A 원본 구조다.
--     즉 CSV 가 정본이고, DDL 이 원본과 어긋나면 그 테이블만 적재가 깨진다.
--     실제 발생: 2026-08-13 BRONZE_ERP.BDGT_ACMSLT_LEDGER
--       "Number of columns in file (65) does not match that of the corresponding table (64)"
--       원인 — 04번 DDL 에 MNYRS_COST_DIV_YN(13번째, '모금비구분') 이 누락되어 있었다.
--     🔴 **[2026-08-29] 위 처방을 그대로 실행하지 마라 — 결론이 뒤집혔다.**
--        A 원천(99_provided_definition/13번)에서 그 컬럼은 **삭제**되었고 대신
--        BDGT_PRCD_NM(3번째 삽입) · DIRECT_MNYRS_YN_1 · DIRECT_MNYRS_YN_2 가 추가되어
--        **65 → 67 컬럼**이 되었다. 04번은 2026-08-29 자로 그 구조를 반영했다.
--        ⇒ 지금 같은 오류를 만나면 **MNYRS_COST_DIV_YN 을 되살리는 것이 아니라**
--           04번의 현행 67컬럼 구조와 CSV 헤더를 (4) 로 대조하는 것이 정답이다.
--        ⇒ 🔴 **이 테이블은 컬럼 순서가 3번째부터 밀렸다.** 2026-08-29 이전에 적재한 데이터가
--           남아 있으면 값이 한 칸씩 어긋나 있다 — TRUNCATE 후 재적재 대상이다.
--        🟢 **[2026-08-29 O114 실측] 현 C 계정에는 그 「이전 적재분」이 없었다.**
--           근거 3축 = ㉠ 라이브 67컬럼 · BDGT_PRCD_NM 3번째 실재 · MNYRS_COST_DIV_YN 부재
--                      ㉡ 직접 COUNT(*) = 0행 (ROW_COUNT 0 · BYTES 0)
--                      ㉢ 아래 (4) 를 BRONZE_ERP 로 범위 한정해 실행 → 67/67 MATCH
--           ⇒ 🔴 **TRUNCATE 를 실행하지 마라 — 대상 행이 0이라 효과가 없다.**
--              남은 일은 「재적재」가 아니라 **최초 적재**(A.4)다.
--           ⚠️ 위 조문은 **다른 계정·다른 시점에는 여전히 유효**하므로 지우지 않는다
--              (계정은 계속 바뀐다 · 판정 근거는 그때 다시 조회한 결과뿐이다 · R2-8-4).
--        🟢 이 사례를 지우지 않고 남긴 이유: 「왜 (4) 검사가 유일한 방어선인가」의 실물 근거이고,
--           결론만 바뀌었을 뿐 교훈은 그대로 유효하다.
--     ⚠️ (3) 은 파일끼리만 비교하므로 이 유형을 절대 잡지 못한다(모든 파일 헤더가 동일하므로 통과).
--     → 아래 (4) 에서 CSV 헤더 ↔ 대상 테이블 컬럼을 대조해 잡는다. 이것이 유일한 방어선이다.
--
--   이상이 있으면: 원인 A → REMOVE 후 재업로드 / 원인 B → DDL 수정 후 테이블 재생성.
------------------------------------------------------------
-- (1) 파일 수 대조: B의 언로드 결과(03번 6단계)와 같아야 함
--     ⚠️ 03번 6단계에서 기록한 스키마별 폴더/파일 수를 옆에 두고 비교한다.
--        0행 테이블은 폴더가 생기지 않으므로 03번 3.1 의 zero_row_tables 만큼 차이가 나는 것이 정상이다.
LIST @SANDBOX.TOOLS.MIG_LOAD_STAGE;

SELECT SPLIT_PART("name", '/', 2) AS table_schema,
       COUNT(DISTINCT SPLIT_PART("name", '/', 3)) AS table_folders,
       COUNT(*)    AS files
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
GROUP BY 1 ORDER BY 1;

-- (1-1) 대상 외 폴더 점검 (0건이어야 함)
LIST @SANDBOX.TOOLS.MIG_LOAD_STAGE;
SELECT COUNT(*) AS stray_files
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE SPLIT_PART("name", '/', 2)
      NOT IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY','BRONZE_GA4','BRONZE_GSC', 'SILVER', 'ML');
-- → 0 이 아니면 이전 배치 잔존이다. C 에 대상 테이블이 없어 적재가 실패하거나 무시된다. REMOVE 할 것.

-- (2) 진단용 포맷: 줄 전체를 $1 로 읽는다(FIELD_DELIMITER=NONE, 헤더 포함).
--     → 헤더 문자열 비교로 컬럼 수·순서 차이를, 줄 전체 해시로 파일 중복을 동시에 잡는다.
CREATE OR REPLACE FILE FORMAT SANDBOX.TOOLS.FF_CSV_PEEK
  TYPE = CSV
  COMPRESSION = GZIP
  FIELD_DELIMITER = NONE
  SKIP_HEADER = 0;

-- (3) 스테이지 이상 탐지 — 스키마 혼재 + 중복 파일
--     ⚠️ 스테이지 전량 스캔이므로 시간/비용이 든다. 업로드 직후 1회만 실행.
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

-- (4) ⭐ CSV 헤더 ↔ 대상 테이블 구조 대조 — [원인 B] 방어선 (04·05·06번 DDL 오류 탐지)
--     COPY 는 '위치 기반' 적재이므로 컬럼 수뿐 아니라 순서까지 같아야 한다.
--     헤더 1줄만 읽으므로 (3) 과 달리 비용이 거의 없다. DDL 실행 직후 반드시 실행할 것.
--     ⚠️ DDL(테이블 생성)이 끝난 뒤에 실행해야 한다. 미실행 시 전 테이블이 TABLE_MISSING 으로 나온다.
--     ⚠️ 대상 = 브론즈 3스키마 + SILVER 대상 1테이블 + ML 결과 16종.
--        DDL 이 그 범위만 만들기 때문에 필터도 같은 범위로 맞춘다.
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
  WHERE table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY','BRONZE_GA4','BRONZE_GSC')
     OR (table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')
     OR (table_schema = 'ML'     AND table_name LIKE 'ML_RST_DATA_%')
  GROUP BY 1, 2
)
SELECT COALESCE(f.sch, t.sch) AS sch,
       COALESCE(f.tbl, t.tbl) AS tbl,
       f.file_cols, t.tbl_cols,
       CASE
         WHEN t.tbl_cols IS NULL                        THEN 'TABLE_MISSING — DDL 미실행·테이블명 불일치'
         WHEN f.file_cols IS NULL                       THEN 'FILE_MISSING — 스테이지 폴더 없음 (0행 테이블이면 정상)'
         WHEN f.file_cols <> t.tbl_cols                 THEN 'COUNT_MISMATCH — DDL 컬럼 누락/추가'
         WHEN f.file_col_list <> t.tbl_col_list          THEN 'ORDER_OR_NAME_MISMATCH — 위치 적재 시 값 밀림 위험'
       END AS diagnosis,
       f.file_col_list, t.tbl_col_list
FROM f FULL OUTER JOIN t ON f.sch = t.sch AND f.tbl = t.tbl
WHERE f.file_cols     IS DISTINCT FROM t.tbl_cols
   OR f.file_col_list IS DISTINCT FROM t.tbl_col_list
ORDER BY 1, 2;
-- → 기대 결과: 0건. (원본이 0행인 테이블만 FILE_MISSING 으로 나오는 것은 정상 — 03번 3.1 로 확인)
--   COUNT_MISMATCH / ORDER_OR_NAME_MISMATCH 가 나오면 절대 적재하지 말고 DDL 을 먼저 고친다.
--     · 🔴 **[2026-08-29 정본 교체] 브론즈 정본은 99_provided_definition/11~13번이다.**
--       종전 기재 「02_1_A DB정보.sql (A 계정 GET_DDL 실측)」은 **낡았다** —
--       그 파일은 CRM 45 · ERP 1 이고 삭제된 MNYRS_COST_DIV_YN 이 남아 있다(1341행).
--       ⇒ 02_1 을 정본으로 쓰면 이 검사에서 나온 불일치를 **거꾸로** 고치게 된다.
--       근거·판정식은 04번 「병합 규칙」 2026-08-29 개정 절을 읽어라.
--     · SILVER 정본은 02번 6.2 의 GET_DDL 결과이며, 06번 파일은 그 발췌다
--       (원천 대조본 = 99_provided_definition/18번 · 2026-08-29 차이 0건).
--     · ML 정본은 99_provided_definition/20_ML_ddl.sql (A 계정 GET_DDL 실측) 이며,
--       05번 파일은 그 파일에서 무변경 발췌한 것이다 ⇒ 어긋나면 **원천 ML 이 교체된 것**이므로
--       20_ML_ddl.sql 을 A 에서 재추출한 뒤 05번을 갱신한다(모델 교체 시 실제로 일어난다).
--     · 🟢 04·05·06번 ↔ 원천 11~13·18·20번의 대조는 **기계로 먼저 돌린다**:
--         python3 scripts/handoff_ddl_gate.py
--       6축(테이블집합·컬럼순서·타입·DEFAULT·컬럼COMMENT·테이블COMMENT)을 각각 숫자로 낸다.
--       이 게이트가 FAIL 이면 C 계정에 DDL 을 실행하기 전에 해소한다(적재까지 가지 마라).
--     · file_col_list 와 tbl_col_list 를 나란히 놓고 어긋나는 지점을 찾는다.
--     · 수정 후 해당 테이블만 CREATE OR REPLACE 하고 이 쿼리를 다시 돌린다.
--   TABLE_MISSING 이 다수면 DDL 자체를 실행하지 않은 것이다.
--     · ML 만 전량 → 05번 미실행 · SILVER 만 → 06번 미실행 · 브론즈만 전량 → 04번 미실행.
--   🔴 ORDER_OR_NAME_MISMATCH 는 COPY 가 오류 없이 통과할 수 있어 가장 위험하다. 반드시 해소할 것.
--      A.5 의 $118 · A.5-B.2 의 $n 위치 기반 적재가 전부 이 검사에 의존한다.

------------------------------------------------------------
-- A.2 적재용 파일 포맷 생성 (NULL 토큰 \\N 3글자 대응)
--   ⚠️ 언로드 데이터의 NULL 은 `\\N`(백슬래시 2개 + N, 3글자)로 기록돼 있다.
--      숫자 컬럼에서 `Numeric value '\N' is not recognized` 오류의 직접 원인이므로
--      NULL_IF 에 3글자 토큰을 반드시 포함한다.
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
-- A.4 브론즈 CSV 스키마 적재 실행 (ERP → AGENCY → CRM 순)
--   기대 반환값: ERP 'loaded tables: 2' / AGENCY 'loaded tables: 4' / CRM 'loaded tables: 46'
--   ⚠️ CRM 이 43·45 로 나오면 04번 DDL 구판을 실행한 것이다(45 = 2026-08-20 판). 최신판으로 다시 생성할 것.
--   ⚠️ ERP 가 1 로 나오면 EXPENSE_RESOLUTION 이 없는 구판이다. 04번 최신판으로 다시 생성할 것.
--   ⚠️ 선행 조건: A.1 (4) 가 0건(또는 0행 테이블의 FILE_MISSING 만)이어야 한다.
--
--   🔴 SILVER · ML 은 이 프로시저로 적재하지 않는다.
--      전 테이블에 일반 COPY 를 걸기 때문에 반정형 컬럼이 **JSON 문자열**로 들어가고
--      `ITEMS[0]` · `PREDICTION:probability:"1"` 탐색이 불가해진다. 오류는 나지 않는다.
--      ⇒ SILVER 는 A.5, ML 은 A.5-B 에서 처리한다.
------------------------------------------------------------
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_ERP');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_AGENCY');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_CRM');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_GA4');
CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('BRONZE_GSC');
-- CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('SILVER');   -- 사용 금지 (ITEMS 가 문자열로 적재된다)
-- CALL SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA('ML');       -- 사용 금지 (PREDICTION 4종이 문자열로 적재된다)

------------------------------------------------------------
-- A.5 SILVER 적재 — CSV + TRY_PARSE_JSON 변환
--   대상: GN_DW.SILVER.BIGQUERY_REFINED_DATA (118 컬럼)
--   반정형 컬럼 위치(1-based): 118 = ITEMS (ARRAY) — 이 1개뿐이다.
--   ⚠️ $1~$117 은 스칼라이므로 변환하지 않는다.
--   ⚠️ 컬럼 순서/개수가 06번 DDL 과 어긋나면 전량 실패하거나 한 칸씩 밀려 오적재된다.
--      A.1 (4) 가 이 테이블에 대해 0건인 것을 반드시 먼저 확인한다.
--      DDL 이 바뀌면 아래 $118 위치를 함께 갱신해야 한다.
------------------------------------------------------------
COPY INTO GN_DW.SILVER.BIGQUERY_REFINED_DATA
FROM (
  SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
         $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
         $21, $22, $23, $24, $25, $26, $27, $28, $29, $30,
         $31, $32, $33, $34, $35, $36, $37, $38, $39, $40,
         $41, $42, $43, $44, $45, $46, $47, $48, $49, $50,
         $51, $52, $53, $54, $55, $56, $57, $58, $59, $60,
         $61, $62, $63, $64, $65, $66, $67, $68, $69, $70,
         $71, $72, $73, $74, $75, $76, $77, $78, $79, $80,
         $81, $82, $83, $84, $85, $86, $87, $88, $89, $90,
         $91, $92, $93, $94, $95, $96, $97, $98, $99, $100,
         $101, $102, $103, $104, $105, $106, $107, $108, $109, $110,
         $111, $112, $113, $114, $115, $116, $117,
         TRY_PARSE_JSON($118)          -- ITEMS (ARRAY)
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/SILVER/BIGQUERY_REFINED_DATA/
)
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT
PURGE = FALSE;

-- A.5.1 적재 직후 거부 행 확인 (기대: 0건) — 세션이 살아 있을 때만 유효
-- SELECT * FROM TABLE(VALIDATE(GN_DW.SILVER.BIGQUERY_REFINED_DATA, JOB_ID => '_last'));

------------------------------------------------------------
-- A.5-B ML 예측결과 적재 — 16종
--   ⚠️ 선행 필수: 05_데이터마이그 GN_DW_ML_DDL_20260814.sql 실행(ML 테이블 16개 생성).
--      미실행 상태로 적재하면 A.1 (4) 가 ML 전량 TABLE_MISSING 을 낸다.
--   ⚠️ 선행 필수: A.1 (4) 에서 ML 관련 COUNT_MISMATCH / ORDER_OR_NAME_MISMATCH 가 0건이어야 한다.
--
--   🔴 **A.3 의 LOAD_BRONZE_SCHEMA('ML') 를 쓰지 않는다.**
--      그 프로시저는 전 테이블에 일반 COPY 를 걸기 때문에 VARIANT 4종의 PREDICTION 이
--      **JSON 문자열**로 들어가고, `PREDICTION:probability:"1"` 탐색이 불가해진다.
--      ⇒ VARIANT 없는 12종은 A.5-B.1 전용 프로시저로, VARIANT 4종은 A.5-B.2 개별 COPY 로 처리한다.
--
--   🔴 SERVING 뷰가 이 평탄화 결과에 의존한다(05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql).
--      문자열로 적재되면 오류 없이 **SV 층에서 조용히 NULL** 이 된다 — 반드시 A.5-B.4 (3) 으로 확인한다.
------------------------------------------------------------
-- A.5-B.1 VARIANT 없는 12종 일괄 적재
--   대상 = ML_RST_DATA_* 중 VARIANT 컬럼이 없는 것.
--   제외 4종은 프로시저 안에서 이름으로 걸러낸다(위치가 아니라 이름 기준 — 안전하다).
CREATE OR REPLACE PROCEDURE SANDBOX.TOOLS.LOAD_ML_RESULT_TABLES()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  c1 CURSOR FOR
    SELECT table_name FROM GN_DW.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'ML'
      AND table_type = 'BASE TABLE'
      AND table_name LIKE 'ML_RST_DATA_%'
      AND table_name NOT IN ('ML_RST_DATA_SPNSR_CHURN_12M',
                             'ML_RST_DATA_MBER_CHURN_12M',
                             'ML_RST_DATA_MBER_INC_12M',
                             'ML_RST_DATA_LOYAL_MBER');
  v_tbl STRING DEFAULT NULL;
  v_sql STRING;
  v_cnt INT DEFAULT 0;
BEGIN
  OPEN c1;
  LOOP
    v_tbl := NULL;
    FETCH c1 INTO v_tbl;
    IF (v_tbl IS NULL) THEN
      BREAK;
    END IF;
    v_sql := 'COPY INTO GN_DW.ML."' || :v_tbl || '" '
          || 'FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/ML/' || :v_tbl || '/ '
          || 'FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD) '
          || 'ON_ERROR = ABORT_STATEMENT PURGE = FALSE';
    EXECUTE IMMEDIATE :v_sql;
    v_cnt := v_cnt + 1;
  END LOOP;
  CLOSE c1;
  RETURN 'ML non-variant loaded tables: ' || v_cnt;
END;
$$;

-- 기대 반환값: 'ML non-variant loaded tables: 12'
--   ⚠️ 12 가 아니면 05번 DDL 이 16종을 다 만들지 않은 것이다. A.1 (4) 로 어느 테이블인지 특정한다.
CALL SANDBOX.TOOLS.LOAD_ML_RESULT_TABLES();

-- A.5-B.2 VARIANT 4종 — PREDICTION 을 TRY_PARSE_JSON 으로 복원
--   PREDICTION 은 전부 **마지막 컬럼**이므로 앞 컬럼은 스칼라로 그대로 넘긴다.
--   ⚠️ 05번 DDL 의 컬럼 순서가 바뀌면 아래 $n 목록을 함께 갱신해야 한다(위치 기반 적재).

-- (1) ML_RST_DATA_SPNSR_CHURN_12M — 18컬럼 · VARIANT $18
COPY INTO GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M
FROM (
  SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
         $11,$12,$13,$14,$15,$16,$17, TRY_PARSE_JSON($18)
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/ML/ML_RST_DATA_SPNSR_CHURN_12M/
)
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT
PURGE = FALSE;

-- (2) ML_RST_DATA_MBER_CHURN_12M — 18컬럼 · VARIANT $18
COPY INTO GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M
FROM (
  SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
         $11,$12,$13,$14,$15,$16,$17, TRY_PARSE_JSON($18)
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/ML/ML_RST_DATA_MBER_CHURN_12M/
)
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT
PURGE = FALSE;

-- (3) ML_RST_DATA_MBER_INC_12M — 21컬럼 · VARIANT $21
COPY INTO GN_DW.ML.ML_RST_DATA_MBER_INC_12M
FROM (
  SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
         $11,$12,$13,$14,$15,$16,$17,$18,$19,$20, TRY_PARSE_JSON($21)
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/ML/ML_RST_DATA_MBER_INC_12M/
)
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT
PURGE = FALSE;

-- (4) ML_RST_DATA_LOYAL_MBER — 22컬럼 · VARIANT $22
COPY INTO GN_DW.ML.ML_RST_DATA_LOYAL_MBER
FROM (
  SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
         $11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21, TRY_PARSE_JSON($22)
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/ML/ML_RST_DATA_LOYAL_MBER/
)
FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD)
ON_ERROR = ABORT_STATEMENT
PURGE = FALSE;

-- A.5-B.3 ⛔ 하지 않는 것
--   · 학습·스냅샷·로그 33종 적재 — A 가 부여하지 않았으므로 스테이지에 파일 자체가 없다.
--   · 프로시저 14종 · SNOWFLAKE.ML 모델 14종 생성 — 학습 데이터가 없어 불가하다.
--     ⇒ 🔴 **C 계정에서 모델 재실행·재예측은 불가하다.** 새 기준월 예측이 필요하면
--        원천 계정에서 프로시저를 돌린 뒤 결과를 다시 이관한다(A.5-B 을 재실행).
--   · ML 뷰 4종(ML_TRAIN_DATA_*_V) 생성 — 학습 입력 뷰이며 노출 대상이 아니다.

-- A.5-B.4 ML 적재 검증
-- (1) 테이블 수 / 총 행수 — 03번 3.1 의 ML 집계와 대조
SELECT COUNT(*) AS tables, SUM(row_count) AS total_rows
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'ML' AND table_type = 'BASE TABLE';
-- 기대: tables = 16 · total_rows = 03번 3.1 실측값과 일치
--   정본 = 05_SV-Agent_ai/20_ML_SV_설계.md §0-A (테이블별 행수)

-- (2) 테이블별 행수 대조표 — 03번 3.1 과 테이블 단위로 비교
SELECT table_name, row_count, bytes
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'ML' AND table_type = 'BASE TABLE'
ORDER BY 1;

-- (3) 🔴 PREDICTION JSON 파싱 확인 — **가장 중요한 검사**
--     기대: PTYPE = 'OBJECT' · PARSED = N_ROWS · UNPARSED = 0
--     PTYPE 가 'VARCHAR' 로 나오면 문자열로 적재된 것이다 ⇒ 해당 테이블을 TRUNCATE 하고
--     A.5-B.2 의 해당 COPY 를 다시 실행한다(일반 COPY 로 적재한 경우 발생).
--     ⚠️ UNPARSED > 0 이면 A 측 기대 NULL 수(02번 5.1)와 대조한다. 값이 같으면 원래 NULL 이고,
--        더 많으면 TRY_PARSE_JSON 파싱 실패다.
SELECT 'ML_RST_DATA_SPNSR_CHURN_12M' AS tbl, COUNT(*) AS n_rows,
       COUNT(PREDICTION:class) AS parsed,
       COUNT(*) - COUNT(PREDICTION:class) AS unparsed,
       TYPEOF(PREDICTION) AS ptype
FROM GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M GROUP BY 1, 5
UNION ALL
SELECT 'ML_RST_DATA_MBER_CHURN_12M', COUNT(*),
       COUNT(PREDICTION:class), COUNT(*) - COUNT(PREDICTION:class), TYPEOF(PREDICTION)
FROM GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M GROUP BY 1, 5
UNION ALL
SELECT 'ML_RST_DATA_MBER_INC_12M', COUNT(*),
       COUNT(PREDICTION:class), COUNT(*) - COUNT(PREDICTION:class), TYPEOF(PREDICTION)
FROM GN_DW.ML.ML_RST_DATA_MBER_INC_12M GROUP BY 1, 5
UNION ALL
SELECT 'ML_RST_DATA_LOYAL_MBER', COUNT(*),
       COUNT(PREDICTION:class), COUNT(*) - COUNT(PREDICTION:class), TYPEOF(PREDICTION)
FROM GN_DW.ML.ML_RST_DATA_LOYAL_MBER GROUP BY 1, 5
ORDER BY 1;

-- (4) 확률 평탄화 스모크 — SERVING 뷰가 쓰는 경로를 직접 확인한다
--     기대: 확률이 0~1 범위이고 NULL 이 없다. NULL 이면 (3) 이 통과했어도 키 경로가 다른 것이다.
SELECT COUNT(*)                                                    AS n_rows,
       COUNT(PREDICTION:probability:"1"::FLOAT)                    AS prob_not_null,
       MIN(PREDICTION:probability:"1"::FLOAT)                      AS min_prob,
       MAX(PREDICTION:probability:"1"::FLOAT)                      AS max_prob,
       COUNT(DISTINCT PREDICTION:class::VARCHAR)                   AS n_classes
FROM GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M;

-- (5) 기준월 확인 — 이관된 STDR_MT 목록
--     🔴 원천 프로시저는 월별 DELETE+INSERT 누적이므로 **여러 기준월이 섞여 있을 수 있다.**
--        여러 개면 SV·Agent 에서 기준월을 반드시 고정해야 한다(합산하면 같은 미래월이 중복 계상된다).
SELECT DISTINCT STDR_MT FROM GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M ORDER BY 1;

-- A.5-B.5 ML 적재 후 후속 작업 (본 파일 범위 밖 · 포인터만)
--   1) SERVING 뷰 7종 생성  → 05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql
--   2) Semantic View 7종 생성 → 05_SV-Agent_ai/22_ML_SV_DDL.sql
--   3) Agent 도구 등록(MEMBER +3 · OVERALL +4) → cortex_project/agents/*/agent_spec.yaml
--   🟢 GN_DW.ML 에 소비 역할 GRANT 는 불필요하다 — 뷰가 소유자 권한으로 읽고 SV 로만 노출된다
--      (근거·실측 = 20_ML_SV_설계.md §7-A) ⇒ 학습·중간 테이블이 구조적으로 차폐된다.
--   ⚠️ 위 1)~3) 은 계정 재구축 이력이 있어 배포 상태를 실행 직전에 확인해야 한다
--      (`SHOW VIEWS IN SCHEMA GN_DW.SERVING` · `SHOW SEMANTIC VIEWS`).

------------------------------------------------------------
-- A.6 검증
--   ML 전용 심화 검증(JSON 파싱·확률 평탄화·기준월)은 A.5-B.4 가 담당한다.
------------------------------------------------------------
-- (1) 스키마별 테이블 수 / 총 행수  → B의 GN_DW_SHARED 집계(03번 3.1)와 대조
SELECT table_schema, COUNT(*) AS tables, SUM(row_count) AS total_rows
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY','BRONZE_GA4','BRONZE_GSC')
        OR (table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')
        OR (table_schema = 'ML'     AND table_name LIKE 'ML_RST_DATA_%') )
GROUP BY 1 ORDER BY 1;
-- 기대: BRONZE_AGENCY 4 · BRONZE_CRM 46 · BRONZE_ERP 2 · ML 16 · SILVER 1 = 69 테이블
--       행수는 03번 3.1 / 02번 5단계 실측값과 일치해야 한다.
--       🔴 이 수치는 04·05·06번 DDL 의 2026-08-29 판 기준이다. DDL 을 갱신하면 여기도 함께 고쳐라
--          (수치가 문서 두 곳에 있으므로 한 곳만 고치면 조용히 어긋난다).

-- (2) 빈 테이블 점검
--     기대: 03번 3.1 의 zero_row_tables 와 같은 목록만 나온다.
--     그 외 테이블이 나오면 해당 폴더의 파일이 누락된 것이므로 재업로드·재적재한다.
--     ⚠️ BRONZE_AGENCY.SYNC_ERR_INFO 는 운영 로그이므로 원본이 0행이면 정상 예외다.
--     ⚠️ ML 테이블이 나오면 원천에서 그 예측이 산출되지 않은 것인지 A 에 확인한다.
SELECT table_schema, table_name
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE' AND row_count = 0
  AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY','BRONZE_GA4','BRONZE_GSC')
        OR (table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')
        OR (table_schema = 'ML'     AND table_name LIKE 'ML_RST_DATA_%') );

-- (3) 🔴 SILVER ITEMS JSON 파싱 확인 → PTYPE = 'ARRAY' 여야 정상
--     PTYPE 가 'VARCHAR' 로 나오면 TRY_PARSE_JSON 이 적용되지 않은 것이다
--     (A.4 프로시저로 잘못 적재했을 가능성) ⇒ TRUNCATE 후 A.5 로 재적재.
--     ⚠️ n_null / total_elements 를 02번 5.1 의 A 측 통제총계와 대조한다.
--        n_null 이 A 측보다 크면 파싱 실패가 섞인 것이다.
SELECT COUNT(*)                    AS n_rows,
       COUNT(ITEMS)                AS n_not_null,
       COUNT(*) - COUNT(ITEMS)     AS n_null,
       SUM(ARRAY_SIZE(ITEMS))      AS total_elements,
       TYPEOF(ITEMS)               AS ptype
FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
GROUP BY 5;

-- (4) 테이블별 행수 대조표
--     이 결과를 03번 3.1(B의 GN_DW_SHARED 스냅샷)과 테이블 단위로 비교한다.
--     스키마별 합계만 맞고 테이블별로 어긋나는 경우(중복 적재 + 누락 상쇄)를 잡는 유일한 검사다.
SELECT table_schema, table_name, row_count, bytes
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY','BRONZE_GA4','BRONZE_GSC')
        OR (table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')
        OR (table_schema = 'ML'     AND table_name LIKE 'ML_RST_DATA_%') )
ORDER BY table_schema, table_name;

-- (5) VALIDATE — 직전 COPY의 거부 행 확인 (기대: 0건)
--     ⚠️ JOB_ID => '_last' 는 '현재 세션의 마지막 COPY' 기준이므로,
--        각 COPY 직후에 실행해야 의미가 있다. 사후 점검은 아래 COPY_HISTORY를 쓴다.
-- SELECT * FROM TABLE(VALIDATE(GN_DW.SILVER.BIGQUERY_REFINED_DATA, JOB_ID => '_last'));

--     세션이 끊긴 뒤에는 COPY_HISTORY 로 전체 적재 이력을 확인한다.
--     기대: STATUS = 'Loaded', ERROR_COUNT = 0, ROW_PARSED = ROW_COUNT
SELECT table_schema_name, table_name, file_name, status,
       row_count, row_parsed, error_count, first_error_message, last_load_time
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE table_schema_name IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY','BRONZE_GA4','BRONZE_GSC', 'SILVER', 'ML')
  AND last_load_time >= DATEADD('day', -2, CURRENT_TIMESTAMP())
  AND (status <> 'Loaded' OR error_count > 0)
ORDER BY last_load_time DESC;
-- → 0건이어야 정상. (ACCOUNT_USAGE 는 최대 2시간 지연될 수 있다.
--    즉시 확인이 필요하면 INFORMATION_SCHEMA.COPY_HISTORY 테이블 함수를 쓴다.)

------------------------------------------------------------
-- A.7 정리(Teardown) — 01번 문서 7장
--   ⚠️ A.6 검증 + A.5-B.4 (ML) 이 전부 통과한 뒤에만 실행한다.
--      스테이지를 비우면 재적재 시 로컬 업로드부터 다시 해야 한다.
------------------------------------------------------------
-- REMOVE @SANDBOX.TOOLS.MIG_LOAD_STAGE/;
-- LIST   @SANDBOX.TOOLS.MIG_LOAD_STAGE;    -- 0건이어야 함

-- 진단용 임시 객체 정리 (FF_CSV_LOAD 는 재적재 대비 남겨둘 수 있다)
-- DROP FILE FORMAT IF EXISTS SANDBOX.TOOLS.FF_CSV_PEEK;
-- DROP PROCEDURE  IF EXISTS SANDBOX.TOOLS.LOAD_BRONZE_SCHEMA(STRING);
-- DROP PROCEDURE  IF EXISTS SANDBOX.TOOLS.LOAD_ML_RESULT_TABLES();
