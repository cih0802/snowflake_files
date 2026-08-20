-- B 계정(Broker) 실행 SQL — MIG_SHARE 공유 데이터를 스테이지에 CSV export
-- 2026-08-20
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   A(Provider)로부터 받은 Direct Share(MIG_SHARE)를 읽기 전용 DB로 마운트하고,
--   이관 대상 테이블을 CSV+GZIP으로 스테이지에 언로드해 로컬 다운로드 대상을 만든다.
--
-- 이관 경로 / TOPOLOGY
--   A ──(Direct Share · 동일 리전)──▶ B ──(로컬 다운로드)──▶ 로컬 ──(업로드)──▶ C (다른 리전)
--   본 파일은 그 중 **B 구간**을 담당한다.
--
-- 실행 계정 / 역할
--   B (Consumer/Broker), ACCOUNTADMIN — locator GB72026
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md
--              → 3.3(공유 DB 생성) / 4.1(스테이지 준비) / 4.2(일괄 언로드) / 4.3(로컬 다운로드) / 7장(정리)
--   [선행 SQL] 50_handoff/02_데이터마이그 A_PRODUCER.sql   (A: 공유 생성/권한 부여/GET_DDL)
--   [후속 SQL] 50_handoff/06_데이터마이그 C_CONSUMER.sql   (C: 파일포맷/프로시저/적재/검증)
--
-- 식별자 / IDENTIFIERS
--   공유 = CMRQTUT.XC97295.MIG_SHARE · 마운트 DB = GN_DW_SHARED (읽기 전용)
--   언로드 스테이지 = @SANDBOX.TOOLS.my_export_stage/<SCHEMA>/<TABLE>/
--
-- 이관 대상 / SCOPE  (A가 MIG_SHARE 로 부여한 범위와 동일)
--   ① BRONZE_CRM (45 테이블)
--   ② BRONZE_AGENCY (4 테이블)
--   ③ BRONZE_ERP (1 테이블)
--   ④ SILVER.BIGQUERY_REFINED_DATA (1 테이블 · 118컬럼 · ITEMS 가 ARRAY)
--   ⑤ ML.ML_RST_DATA_* (예측결과 16종만)
--   ⇒ 합계 67 테이블
--
--   ⛔ 대상 아님 — BRONZE_BIGQUERY
--      A가 공유하지 않는다. ④ SILVER 가 이 원천의 정제 결과를 대신한다.
--      ⇒ 아래 3.1/5 의 대상 필터가 `LIKE 'BRONZE_%'` 가 아니라 **명시 목록**인 이유다.
--        패턴으로 되돌리면 A의 공유 구성이 바뀔 때 의도하지 않은 스키마가 조용히 섞인다.
--
--   ⛔ 대상 아님 — ML 학습·스냅샷·로그 33종 + 뷰 4종
--      A가 부여하지 않았으므로 공유 DB의 INFORMATION_SCHEMA 에 보이지 않는다.
--      ⇒ 5번의 `table_schema = 'ML'` 조건만으로 정확히 16종이 대상이 된다(3.1-B 에서 확인).
-- =====================================================================

-- B 계정 (Consumer), ACCOUNTADMIN 역할
USE ROLE ACCOUNTADMIN;

-- ⚠️ 웨어하우스 지정 필수.
--    COMPUTE_WH 는 X-Small 이라 5단계 언로드가 오래 걸리고 문장 타임아웃 위험이 있다.
--    언로드 구간에서만 상향한 뒤 6단계 확인 후 원복하는 것을 권장한다.
USE WAREHOUSE COMPUTE_WH;
-- ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'LARGE';   -- 5단계 실행 전
-- ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL';  -- 6단계 확인 후 원복

-- 1. 수신 공유 확인 (INBOUND 항목에 CMRQTUT.XC97295 / MIG_SHARE 가 보여야 함)
SHOW SHARES;

-- 2. 로컬 인프라 생성 (스테이지가 먼저 있어야 COPY INTO 가능)
CREATE DATABASE IF NOT EXISTS SANDBOX;
CREATE SCHEMA IF NOT EXISTS SANDBOX.TOOLS;
CREATE OR REPLACE STAGE SANDBOX.TOOLS.my_export_stage
  FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' COMPRESSION = GZIP);

-- 3. 공유 데이터베이스 마운트 (읽기 전용)
--    재실행 시 이미 존재하면 실패하므로 IF NOT EXISTS 를 쓴다.
--    ⚠️ A가 공유 구성을 바꾼 뒤에는 반드시 DROP 후 재생성한다.
--       기존 마운트에는 새로 부여된 스키마/테이블이 보이지 않는다.
--         DROP DATABASE IF EXISTS GN_DW_SHARED;
CREATE DATABASE IF NOT EXISTS GN_DW_SHARED FROM SHARE CMRQTUT.XC97295.MIG_SHARE;

-- 3.0 공유 구성 점검
--     기대: BRONZE_AGENCY / BRONZE_CRM / BRONZE_ERP / SILVER / ML 이 보이고
--           BRONZE_BIGQUERY 는 보이지 않는다.
SHOW SCHEMAS IN DATABASE GN_DW_SHARED;

SELECT
  (SELECT COUNT(*) FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')  AS silver_visible,   -- 기대 1
  (SELECT COUNT(*) FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'ML' AND table_type = 'BASE TABLE')                 AS ml_visible,       -- 기대 16
  (SELECT COUNT(*) FROM GN_DW_SHARED.INFORMATION_SCHEMA.SCHEMATA
    WHERE schema_name = 'BRONZE_BIGQUERY')                                   AS bigquery_visible; -- 기대 0
-- → silver_visible = 0 이면 A가 2.1 GRANT 를 실행하지 않은 것이다(A에게 요청).
--   ml_visible ≠ 16 이면 A의 2-B 부여가 불완전하다.
--   bigquery_visible ≠ 0 이면 A가 2.2 를 실수로 실행한 것이다(A에게 REVOKE 요청).

-- 3.1 ⚠️ 대조 기준값 확보 (언로드 전에 기록) — 01번 문서 6.1
--     C 적재 후 GN_DW 집계와 테이블 단위로 비교할 원본 스냅샷이다.
--     A(02번 5단계)에서 뽑은 값과도 일치해야 한다. 다르면 공유 누락/부분 부여를 의심한다.
--     ⚠️ 공유받은(imported) DB는 INFORMATION_SCHEMA 의 row_count/bytes 가 NULL 로 나올 수 있다.
--        NULL 이면 02_1_A DB정보.sql 의 A1/A2 결과를 기준값으로 쓰거나, COUNT(*) 방식을 쓴다.
SELECT table_schema, table_name, row_count, bytes
FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY')
        OR (table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')
        OR  table_schema = 'ML' )
ORDER BY table_schema, table_name;

-- 스키마별 요약
--   기대: BRONZE_AGENCY 4 · BRONZE_CRM 45 · BRONZE_ERP 1 · ML 16 · SILVER 1 = 67 테이블
SELECT table_schema,
       COUNT(*)       AS tables,
       SUM(row_count) AS total_rows,
       SUM(CASE WHEN row_count = 0 THEN 1 ELSE 0 END) AS zero_row_tables  -- 폴더가 생기지 않는 테이블 수
FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY')
        OR (table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')
        OR  table_schema = 'ML' )
GROUP BY 1 ORDER BY 1;
--   ⚠️ zero_row_tables 를 기록해 둔다. 0행 테이블은 COPY INTO 가 파일을 만들지 않아
--      폴더가 생기지 않는다 ⇒ 6번의 '테이블 수 = 폴더 수' 판정에서 이 수만큼 차이가 나는 것이 정상이다.

-- 3.1-B ML 대상 테이블명 확인 (기대: 16행 · 전부 ML_RST_DATA_ 접두 — 2026-08-18 확인 완료)
--   접두가 다른 테이블이 한 건이라도 나오면 학습·스냅샷이 섞인 것이므로 언로드하지 않는다.
--   A 의 부여 오류이므로 A 에게 REVOKE 를 요청한 뒤 3번부터 다시 시작한다.
SELECT table_name,
       CASE WHEN table_name LIKE 'ML_RST_DATA_%' THEN 'OK'
            ELSE 'NOT_A_RESULT_TABLE — 부여 오류' END AS diagnosis
FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'ML' AND table_type = 'BASE TABLE'
ORDER BY 1;

-- 3.1-C SILVER 구조 확인 (기대: 118 컬럼 · ITEMS 가 118번째 · ARRAY)
--   이 값이 04_2번 DDL 과 어긋나면 C 적재가 전량 실패하거나 한 칸씩 밀려 오적재된다.
--   ⚠️ 06번 A.5 의 TRY_PARSE_JSON($118) 위치와 반드시 일치해야 한다.
SELECT MAX(ordinal_position)                                              AS n_cols,
       MAX(CASE WHEN data_type = 'ARRAY' THEN column_name END)            AS array_col,
       MAX(CASE WHEN data_type = 'ARRAY' THEN ordinal_position END)       AS array_pos
FROM GN_DW_SHARED.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA';

-- 4. ⚠️ 언로드 전 스테이지 초기화 (필수)
--    COPY INTO ... OVERWRITE=TRUE 는 '같은 이름' 파일만 덮어쓴다. 폴더를 비우지 않는다.
--    언로드 병렬 워커 수/분할 개수가 배치마다 달라지면(예: data_0_2_0 → data_0_0_0)
--    이름이 겹치지 않은 이전 배치 파일이 그대로 살아남아 다음 두 사고를 일으킨다.
--      (1) 스키마가 바뀐 테이블: 컬럼 수 불일치로 C 적재 실패
--          예) BRONZE_ERP.BDGT_ACMSLT_LEDGER 62컬럼(구) vs 64컬럼(신)
--      (2) 스키마가 같은 테이블: 오류 없이 조용히 중복 적재(2배)
--    ⚠️ 공유 구성이 바뀐 직후에는 특히 필수다. 이전 구성에서 만든 폴더
--       (예: BRONZE_BIGQUERY/ · BRONZE_GA4/)가 남아 있으면 C 에 없는 스키마의 파일이
--       로컬까지 따라온다.
REMOVE @SANDBOX.TOOLS.my_export_stage;

-- 초기화 확인 (0건이어야 함)
LIST @SANDBOX.TOOLS.my_export_stage;

-- 5. INFORMATION_SCHEMA를 순회하며 각 테이블을 동적으로 COPY INTO
--    대상: BRONZE_CRM(45) · BRONZE_AGENCY(4) · BRONZE_ERP(1) · SILVER(1) · ML(16) = 67
--    경로 규칙: @stage/<스키마>/<테이블>/ , GZIP CSV
--    ⚠️ WHERE 절을 LIKE 'BRONZE_%' 로 바꾸지 말 것 — 공유 구성 변경 시 의도 외 스키마가 섞인다.
--    ⚠️ EXECUTE IMMEDIATE $$ ... $$ 로 감싼 이유:
--       Workspace의 '파일 전체 실행'은 세미콜론 단위로 문장을 잘라 보낸다.
--       익명 블록(DECLARE...END;)을 그대로 두면 블록 내부 세미콜론에서 조각나 문법 오류가 난다.
--       $$ 로 감싸면 블록 전체가 단일 문장으로 전달된다.
--    ℹ️ WHERE 절의 `table_schema = 'ML'`:
--       ML 은 A 가 16종만 부여했으므로 이 조건만으로 정확히 16종이 대상이 된다(3.1-B 확인 완료).
--    ℹ️ 반정형 컬럼은 **언로드 쪽에서 할 일이 없다.** CSV 로 나가면 JSON 문자열이 되고,
--       복원은 C 적재에서 한다 — SILVER.ITEMS(ARRAY) → 06번 A.5,
--       ML PREDICTION(VARIANT) 4종 → 06번 A.5-B.2.
--    ℹ️ 반환값은 커서 대상 테이블 수와 같다 ⇒ 'UNLOAD 완료: 67개 테이블' 이 나와야 정상.
--       (0행 테이블도 COPY INTO 는 성공하므로 cnt 에 포함된다. 폴더만 생기지 않는다.)
EXECUTE IMMEDIATE $$
DECLARE
  c1 CURSOR FOR
    SELECT table_schema, table_name
    FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
    WHERE table_type = 'BASE TABLE'
      AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY')
            OR (table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')
            OR  table_schema = 'ML' );
  cnt INTEGER DEFAULT 0;
BEGIN
  FOR rec IN c1 DO
    EXECUTE IMMEDIATE
      'COPY INTO @SANDBOX.TOOLS.my_export_stage/' || rec.table_schema || '/' || rec.table_name || '/ '
      || 'FROM (SELECT * FROM GN_DW_SHARED."' || rec.table_schema || '"."' || rec.table_name || '" '
      -- || 'SAMPLE (10000 ROWS)'
      || ') '
      || 'FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = ''"'' COMPRESSION = GZIP) '
      || 'HEADER = TRUE '
      || 'OVERWRITE = TRUE';
    cnt := cnt + 1;
  END FOR;
  RETURN 'UNLOAD 완료: ' || cnt || '개 테이블';
END;
$$;
-- 기대 반환값: 'UNLOAD 완료: 67개 테이블'
--   67 이 아니면 3.0 / 3.1 로 돌아가 공유 구성을 다시 확인한다.

-- 6. Export 결과 확인
--    파일 수를 기록해 둔다 → C 업로드 후 동일한지 대조할 기준값이 된다(06번 A.1 (1)).
LIST @SANDBOX.TOOLS.my_export_stage;

-- 스키마별 파일/폴더 수 집계 (위 LIST 직후에 실행해야 RESULT_SCAN 이 유효)
SELECT SPLIT_PART("name", '/', 2) AS table_schema,
       COUNT(DISTINCT SPLIT_PART("name", '/', 3)) AS table_folders,
       COUNT(*)   AS files
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
GROUP BY 1 ORDER BY 1;
--   판정: 스키마별 table_folders = 3.1 의 tables − zero_row_tables 여야 한다.
--   ⚠️ 이 결과(스키마별 파일 수)를 기록해 C 업로드 후 06번 A.1 (1) 에서 대조한다.

-- 6.1 대상 외 폴더 잔존 점검 (0건이어야 함)
--     이전 배치 잔존 또는 대상 필터 오설정을 잡는다.
LIST @SANDBOX.TOOLS.my_export_stage;
SELECT COUNT(*) AS stray_files
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE SPLIT_PART("name", '/', 2)
      NOT IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY', 'SILVER', 'ML');
-- → 0 이 아니면 4번 REMOVE 를 건너뛴 것이다. 스테이지를 비우고 5번부터 다시 실행한다.

-- 7. 정리(Teardown) — 01번 문서 7장
--    ⚠️ 순서 주의: 로컬 다운로드(4.3)와 C 적재·검증(06번 A.6)이 끝난 뒤에 실행한다.
--       스테이지를 먼저 비우면 재다운로드가 불가능해 B 언로드부터 다시 해야 한다.

-- 7.1 공유 DB 정리 (export가 정상 완료된 것을 6번에서 확인한 뒤 실행)
-- DROP DATABASE GN_DW_SHARED;

-- 7.2 언로드 스테이지 정리 (로컬 다운로드 및 C 검증 완료 후)
-- REMOVE @SANDBOX.TOOLS.my_export_stage/;
-- LIST   @SANDBOX.TOOLS.my_export_stage;   -- 0건이어야 함
