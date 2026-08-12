-- MIG_SHARE 공유 데이터의 BRONZE_* 테이블을 일회성으로 스테이지에 CSV export
-- Co-authored with CoCo

-- B 계정 (Consumer), ACCOUNTADMIN 역할
USE ROLE ACCOUNTADMIN;

-- 1. 수신 공유 확인 (INBOUND 항목에 CMRQTUT.XC97295 / MIG_SHARE 가 보여야 함)
SHOW SHARES;

-- 2. 로컬 인프라 생성 (스테이지가 먼저 있어야 COPY INTO 가능)
CREATE DATABASE IF NOT EXISTS SANDBOX;
CREATE SCHEMA IF NOT EXISTS SANDBOX.TOOLS;
CREATE OR REPLACE STAGE SANDBOX.TOOLS.my_export_stage
  FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' COMPRESSION = GZIP);

-- 3. 공유 데이터베이스 마운트 (읽기 전용)
CREATE DATABASE GN_DW_SHARED FROM SHARE CMRQTUT.XC97295.MIG_SHARE;

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
--    대상 스키마: BRONZE_AGENCY, BRONZE_CRM, BRONZE_ERP, BRONZE_GA4
--    경로 규칙: @stage/<스키마>/<테이블>/ , GZIP CSV
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

-- 6. Export 결과 확인
--    파일 수를 기록해 둔다 → C 업로드 후 동일한지 대조할 기준값이 된다.
LIST @SANDBOX.TOOLS.my_export_stage;
SELECT COUNT(*) AS unloaded_files FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- 7. 공유 DB 정리 (export가 정상 완료된 것을 6번에서 확인한 뒤 실행)
-- DROP DATABASE GN_DW_SHARED;
