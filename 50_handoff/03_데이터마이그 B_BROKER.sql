-- B 계정(Broker) 실행 SQL — MIG_SHARE 공유 데이터의 BRONZE_* + ML 테이블을 스테이지에 CSV export
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   A로부터 받은 Direct Share(MIG_SHARE)를 읽기 전용 DB로 마운트하고,
--   BRONZE_* 전 테이블 + ML 예측결과 16종을 CSV+GZIP으로 스테이지에 언로드해
--   로컬 다운로드 대상을 만든다.
--   ⚠️ 로컬 다운로드 규모는 약 62.4 GiB / 6,858 파일이다(초기 설계값 3.4 GB 아님).
--      디스크 여유공간과 GET 소요시간을 미리 확보한다.
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
-- 이관 규모 / SCALE  (2026-08-18 공유 DB(GN_DW_SHARED) 실측 — 확정값)
--   978 테이블 / 402,841,646 행 / 51,250,913,280 B (약 47.73 GiB)
--     BRONZE_BIGQUERY 912 · BRONZE_CRM 45 · BRONZE_AGENCY 4 · BRONZE_ERP 1 · ML 16
--   → 언로드 산출물: 6,858 파일 / 977 폴더 / 67,011,767,456 B (약 62.41 GiB, GZIP CSV)
--     ※ 산출물이 원본 바이트보다 큰 것은 정상이다. GZIP CSV 는 Snowflake 내부 컬럼 압축보다 효율이 낮다.
--     ※ 폴더가 978 이 아니라 977 인 이유는 6단계 주석 참조(0행 테이블 1건).
--   ML 16 테이블 = 1,045,732 행 / 31,001,088 B ⇒ 전체 행의 약 0.26% 로 언로드 시간 영향은 미미하다.
--     (원천 계정 참고값 약 1,045,732 행 — 정본 05_SV-Agent_ai/20_ML_SV_설계.md §0-A — 과 정확히 일치)
--
--   ⚠️ 규모 이력: 초기 설계 시점(2026-08-12)의 '53 테이블 / 1.17억 행 / 약 2.8 GB' 는
--      BRONZE_BIGQUERY 를 3 테이블로 잡은 값이다. 실제 공유에는 BIGQUERY 912 테이블이 포함되어
--      행 수는 약 3.5배, 바이트는 약 17배로 커졌다. 웨어하우스 사이징·소요시간 판단은 위 확정값을 쓴다.
--
-- 🔴 ML 언로드 범위가 자동으로 16종인 이유
--   A 가 ML 을 **테이블 단위로만 부여**했으므로(02번 2-B) 공유받은 GN_DW_SHARED 의
--   INFORMATION_SCHEMA 에는 예측결과 16종만 나타난다. 학습·스냅샷 33종은 보이지 않는다.
--   ⇒ 5단계 커서는 `table_schema = 'ML'` 만 추가하면 되고, 테이블명 화이트리스트가 필요 없다.
--   ⚠️ 단 **보이는 개수를 3.1 에서 반드시 확인**한다. 16이 아니면 A 부여가 잘못된 것이다
--      (많으면 ALL TABLES 오사용 · 적으면 재생성으로 GRANT 소실 → A 에게 2-B 재실행 요청).
--      ✅ 2026-08-18 확인 완료: ML 16종, 전부 `ML_RST_DATA_` 접두 — 부여 정상.
-- =====================================================================

-- B 계정 (Consumer), ACCOUNTADMIN 역할
USE ROLE ACCOUNTADMIN;

-- ⚠️ 웨어하우스 지정 필수. 5단계 언로드는 978 테이블 / 4.03억 행 / 약 47.7 GiB 를 처리한다.
--    COMPUTE_WH 는 X-Small 이라 XS로는 매우 오래 걸리고 문장 타임아웃 위험이 크다.
--    특히 BRONZE_BIGQUERY 912 테이블(전체 행의 71% · 바이트의 94%)이 소요시간을 지배한다.
--    언로드 구간에서만 상향(LARGE 이상)한 뒤 6단계 확인 후 원복하는 것을 권장한다.
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
--     ℹ️ 2026-08-18 실행 시 imported DB 의 row_count/bytes 는 정상 반환됐다(NULL 아님).
--        만약 NULL 로 나오는 환경이면 02_1_A DB정보.sql 의 A1/A2 결과를 기준값으로 쓰거나 COUNT(*) 를 쓴다.
SELECT table_schema, table_name, row_count, bytes
FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (table_schema LIKE 'BRONZE_%' OR table_schema = 'ML')
ORDER BY table_schema, table_name;

-- 스키마별 요약
--   기대(2026-08-18 실측 확정값):
--     BRONZE_AGENCY     4 테이블 /     243,550 행 /      5,719,040 B
--     BRONZE_BIGQUERY 912 테이블 / 285,676,588 행 / 48,362,186,752 B
--     BRONZE_CRM       45 테이블 / 115,871,475 행 /  2,851,677,696 B
--     BRONZE_ERP        1 테이블 /       4,301 행 /        328,704 B
--     ML               16 테이블 /   1,045,732 행 /     31,001,088 B
--     합계            978 테이블 / 402,841,646 행 / 51,250,913,280 B
--   🔴 ML 이 16이 아니면 즉시 멈춘다 — A 부여 오류다(상단 'ML 언로드 범위' 참조).
--      16 초과 = A 가 ALL TABLES 로 부여해 학습·스냅샷이 열렸다 ⇒ A 에서 회수 후 2-B 재실행.
--      16 미만 = 결과 테이블이 재생성되어 GRANT 가 소실됐다 ⇒ A 에서 2-B 재실행.
SELECT table_schema,
       COUNT(*)       AS tables,
       SUM(row_count) AS total_rows,
       SUM(bytes)     AS total_bytes,
       SUM(CASE WHEN row_count = 0 THEN 1 ELSE 0 END) AS zero_row_tables  -- 폴더가 생기지 않는 테이블 수
FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (table_schema LIKE 'BRONZE_%' OR table_schema = 'ML')
GROUP BY 1 ORDER BY 1;

-- 3.1-B ML 대상 테이블명 확인 (기대: 16행 · 전부 ML_RST_DATA_ 접두 — 2026-08-18 확인 완료)
--   접두가 다른 테이블이 한 건이라도 나오면 학습·스냅샷이 섞인 것이므로 언로드하지 않는다.
SELECT table_name,
       CASE WHEN table_name LIKE 'ML_RST_DATA_%' THEN 'OK'
            ELSE 'NOT_A_RESULT_TABLE — 부여 오류' END AS diagnosis
FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'ML' AND table_type = 'BASE TABLE'
ORDER BY 1;

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
--    대상 스키마: BRONZE_BIGQUERY(912) + BRONZE_CRM(45) + BRONZE_AGENCY(4) + BRONZE_ERP(1) + ML(16) = 978 테이블
--    경로 규칙: @stage/<스키마>/<테이블>/ , GZIP CSV
--    ⚠️ EXECUTE IMMEDIATE $$ ... $$ 로 감싼 이유:
--       Workspace의 '파일 전체 실행'은 세미콜론 단위로 문장을 잘라 보낸다.
--       익명 블록(DECLARE...END;)을 그대로 두면 블록 내부 세미콜론에서 조각나 문법 오류가 난다.
--       $$ 로 감싸면 블록 전체가 단일 문장으로 전달된다.
--    ℹ️ WHERE 절의 `OR table_schema = 'ML'`:
--       ML 은 A 가 16종만 부여했으므로 이 조건만으로 정확히 16종이 대상이 된다(3.1-B 에서 확인 완료).
--       🔴 ML 결과 4종은 `PREDICTION VARIANT` 컬럼을 갖는다. **언로드는 브론즈와 동일하게 처리해도 되지만**
--          (CSV 로 나가면 JSON 문자열이 된다) **C 적재에서 TRY_PARSE_JSON 복원이 필수**다
--          — BIGQUERY 와 같은 함정이며 05번 A.5-B.2 가 담당한다. 언로드 쪽에서 할 일은 없다.
--    ℹ️ 반환값은 커서 대상 테이블 수와 같다 ⇒ 'UNLOAD 완료: 978개 테이블' 이 나와야 정상.
--       (0행 테이블도 COPY INTO 는 성공하므로 cnt 에 포함된다. 폴더만 생기지 않는다.)
EXECUTE IMMEDIATE $$
DECLARE
  c1 CURSOR FOR
    SELECT table_schema, table_name
    FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
    WHERE table_type = 'BASE TABLE'
      AND (table_schema LIKE 'BRONZE_%' OR table_schema = 'ML');
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

-- 2026-08-18 실행 결과 (기준값 — C 업로드 후 이 값과 대조한다)
--   BRONZE_AGENCY     4 폴더 /     5 파일 /      4,129,568 B
--   BRONZE_BIGQUERY 911 폴더 / 6,517 파일 / 63,725,277,056 B
--   BRONZE_CRM       45 폴더 /   281 파일 /  3,252,000,576 B
--   BRONZE_ERP        1 폴더 /     1 파일 /         55,888 B
--   ML               16 폴더 /    54 파일 /     30,304,368 B
--   합계            977 폴더 / 6,858 파일 / 67,011,767,456 B (약 62.41 GiB)
--
--   ⚠️ 테이블은 978개인데 폴더는 977개다. 정상이다.
--      BRONZE_BIGQUERY.SYNC_ERR_INFO 는 0행이라 COPY INTO 가 파일을 만들지 않아 폴더가 생기지 않는다.
--      → C에서는 이 테이블을 '구조만 생성'하고 적재 대상에서 빠지는 것이 정상 동작이다.
--      (0행 테이블은 3.1 요약의 zero_row_tables 컬럼으로 사전에 특정할 수 있다. 실측 = BIGQUERY 1건뿐)
--
--   ✅ ML 16 폴더 = 16종 전부 1행 이상 언로드됨(0행 없음). 54 파일 / 30,304,368 B.
--      🔴 재실행 시 폴더가 16 미만이면 0행 테이블이 생겼다는 뜻이다. 3.1 요약으로 특정하고,
--         원천에서 정말 0행인지(= 그 예측이 산출되지 않았는지) A 에 확인한다.
--         0행 테이블은 C 에서 '구조만 생성 + 0건 적재'가 정상 동작이다(SYNC_ERR_INFO 와 동일).
--
--   ⚠️ 이 기준값은 05번 A.1 (1) 의 기준값 주석과 반드시 일치해야 한다(어긋나면 검증이 무력화된다).

-- 7. 정리(Teardown) — 01번 문서 7장
--    ⚠️ 순서 주의: 로컬 다운로드(4.3)와 C 적재·검증(6장)이 끝난 뒤에 실행한다.
--       스테이지를 먼저 비우면 재다운로드가 불가능해 B 언로드부터 다시 해야 한다.

-- 7.1 공유 DB 정리 (export가 정상 완료된 것을 6번에서 확인한 뒤 실행)
-- DROP DATABASE GN_DW_SHARED;

-- 7.2 언로드 스테이지 정리 (로컬 다운로드 및 C 검증 완료 후)
-- REMOVE @SANDBOX.TOOLS.my_export_stage/;
-- LIST   @SANDBOX.TOOLS.my_export_stage;   -- 0건이어야 함
