-- B 계정(Broker) 실행 SQL — MIG_SHARE 공유 데이터의 BRONZE_* 테이블을 스테이지에 CSV export
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   A로부터 받은 Direct Share(MIG_SHARE)를 읽기 전용 DB로 마운트하고,
--   BRONZE_* 전 테이블을 CSV+GZIP으로 스테이지에 언로드해 로컬 다운로드 대상을 만든다.
--
-- 실행 계정 / 역할
--   B (Consumer/Broker), ACCOUNTADMIN — locator GB72026
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md
--              → 3.3(공유 DB 생성) / 4.1(스테이지 준비) / 4.2(일괄 언로드) / 4.3(로컬 다운로드) / 7장(정리)
--   [선행 SQL] 50_handoff/02_데이터마이그 A_PRODUCER.sql   (A: 공유 생성/권한 부여/GET_DDL)
--   [후속 SQL] 50_handoff/05_데이터마이그 C_CONSUMER.sql   (C: 파일포맷/프로시저/적재/검증)
--
-- 식별자 / IDENTIFIERS
--   공유 = CMRQTUT.XC97295.MIG_SHARE · 마운트 DB = GN_DW_SHARED (읽기 전용)
--   언로드 스테이지 = @SANDBOX.TOOLS.my_export_stage/<SCHEMA>/<TABLE>/
--
-- 이관 규모 / SCALE  (2026-08-12 A 실측 = 공유 DB 실측, 완전 일치 확인)
--   53 테이블 (CRM 45 · AGENCY 4 · ERP 1 · GA4 3) / 116,699,405 행 / 2,970,555,392 B
--   → 언로드 산출물: 435 파일 / 52 폴더 / 3,427,853,840 B (GZIP CSV)
-- =====================================================================

-- B 계정 (Consumer), ACCOUNTADMIN 역할
USE ROLE ACCOUNTADMIN;

-- ⚠️ 웨어하우스 지정 필수. 5단계 언로드는 1.17억 행 / 약 2.8GB 를 처리한다.
--    COMPUTE_WH 는 X-Small 이라 XS로는 매우 오래 걸리고 문장 타임아웃 위험이 있다.
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
--    (공유 내용이 바뀌어 다시 붙여야 하면 DROP DATABASE GN_DW_SHARED 후 재생성)
CREATE DATABASE IF NOT EXISTS GN_DW_SHARED FROM SHARE CMRQTUT.XC97295.MIG_SHARE;

-- 3.1 ⚠️ 대조 기준값 확보 (언로드 전에 기록) — 01번 문서 6.1
--     C 적재 후 GN_DW 집계와 테이블 단위로 비교할 원본 스냅샷이다.
--     A(02번 5단계)에서 뽑은 값과도 일치해야 한다. 다르면 공유 누락/부분 부여를 의심한다.
--     ⚠️ 공유받은(imported) DB는 INFORMATION_SCHEMA 의 row_count/bytes 가 NULL 로 나올 수 있다.
--        NULL 이면 02_1_A DB정보.sql 의 A1/A2 결과를 기준값으로 쓰거나, 3.2 의 COUNT(*) 방식을 쓴다.
SELECT table_schema, table_name, row_count, bytes
FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE' AND table_schema LIKE 'BRONZE_%'
ORDER BY table_schema, table_name;

-- 스키마별 요약 (기대: 53 테이블 = CRM 45 + AGENCY 4 + ERP 1 + GA4 3)
SELECT table_schema,
       COUNT(*)       AS tables,
       SUM(row_count) AS total_rows
FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE' AND table_schema LIKE 'BRONZE_%'
GROUP BY 1 ORDER BY 1;

-- 4. ⚠️ 언로드 전 스테이지 초기화 (필수)
--    COPY INTO ... OVERWRITE=TRUE 는 '같은 이름' 파일만 덮어쓴다. 폴더를 비우지 않는다.
--    언로드 병렬 워커 수/분할 개수가 배치마다 달라지면(예: data_0_2_0 → data_0_0_0)
--    이름이 겹치지 않은 이전 배치 파일이 그대로 살아남아 다음 두 사고를 일으킨다.
--      (1) 스키마가 바뀐 테이블: 컬럼 수 불일치로 C 적재 실패
--          예) BRONZE_ERP.BDGT_ACMSLT_LEDGER 62컬럼(구) vs 64컬럼(신)
--      (2) 스키마가 같은 테이블: 오류 없이 조용히 중복 적재(2배)
--    → 재언로드할 때는 반드시 먼저 비운다.
REMOVE @SANDBOX.TOOLS.my_export_stage;

-- 초기화 확인 (0건이어야 함)
LIST @SANDBOX.TOOLS.my_export_stage;

-- 5. INFORMATION_SCHEMA를 순회하며 각 테이블을 동적으로 COPY INTO
--    대상 스키마: BRONZE_AGENCY, BRONZE_CRM, BRONZE_ERP, BRONZE_BIGQUERY (총 53 테이블)
--    경로 규칙: @stage/<스키마>/<테이블>/ , GZIP CSV
--    ⚠️ EXECUTE IMMEDIATE $$ ... $$ 로 감싼 이유:
--       Workspace의 '파일 전체 실행'은 세미콜론 단위로 문장을 잘라 보낸다.
--       익명 블록(DECLARE...END;)을 그대로 두면 블록 내부 세미콜론에서 조각나 문법 오류가 난다.
--       $$ 로 감싸면 블록 전체가 단일 문장으로 전달된다.
EXECUTE IMMEDIATE $$
DECLARE
  c1 CURSOR FOR
    SELECT table_schema, table_name
    FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
    WHERE table_type = 'BASE TABLE'
      AND table_schema LIKE 'BRONZE_%';
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

-- 6. Export 결과 확인
--    파일 수를 기록해 둔다 → C 업로드 후 동일한지 대조할 기준값이 된다.
LIST @SANDBOX.TOOLS.my_export_stage;

-- 스키마별 파일/폴더 수 집계 (위 LIST 직후에 실행해야 RESULT_SCAN 이 유효)
SELECT SPLIT_PART("name", '/', 2) AS table_schema,
       COUNT(DISTINCT SPLIT_PART("name", '/', 3)) AS table_folders,
       COUNT(*)   AS files,
       SUM("size") AS bytes
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
GROUP BY 1 ORDER BY 1;

-- 2026-08-12 실행 결과 (기준값 — C 업로드 후 이 값과 대조한다)
--   BRONZE_AGENCY    4 폴더 /   5 파일 /     4,129,568 B
--   BRONZE_CRM      45 폴더 / 389 파일 / 3,239,132,784 B
--   BRONZE_ERP       1 폴더 /   1 파일 /        55,888 B
--   BRONZE_BIGQUERY       2 폴더 /  40 파일 /   184,535,600 B
--   합계            52 폴더 / 435 파일 / 3,427,853,840 B (약 3.19 GiB)
--
--   ⚠️ 테이블은 53개인데 폴더는 52개다. 정상이다.
--      BRONZE_BIGQUERY.SYNC_ERR_INFO 는 0행이라 COPY INTO 가 파일을 만들지 않아 폴더가 생기지 않는다.
--      → C에서는 이 테이블을 '구조만 생성'하고 적재 대상에서 빠지는 것이 정상 동작이다.

-- 7. 정리(Teardown) — 01번 문서 7장
--    ⚠️ 순서 주의: 로컬 다운로드(4.3)와 C 적재·검증(6장)이 끝난 뒤에 실행한다.
--       스테이지를 먼저 비우면 재다운로드가 불가능해 B 언로드부터 다시 해야 한다.

-- 7.1 공유 DB 정리 (export가 정상 완료된 것을 6번에서 확인한 뒤 실행)
-- DROP DATABASE GN_DW_SHARED;

-- 7.2 언로드 스테이지 정리 (로컬 다운로드 및 C 검증 완료 후)
-- REMOVE @SANDBOX.TOOLS.my_export_stage/;
-- LIST   @SANDBOX.TOOLS.my_export_stage;   -- 0건이어야 함
