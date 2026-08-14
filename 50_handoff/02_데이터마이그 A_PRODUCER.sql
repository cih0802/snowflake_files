-- A 계정(Provider) 실행 SQL — Direct Share 생성 및 DDL 추출
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   원본(A) 계정에서 GN_DW 브론즈 4개 스키마를 B 계정으로 Direct Share 하고,
--   C 계정에 동일 구조를 재현하기 위한 DDL 스냅샷을 추출한다.
--
-- 실행 계정 / 역할
--   A (Provider), ACCOUNTADMIN
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md
--              → 3.1(Share 생성/부여) / 3.2(GET_DDL 추출) / 7장(정리) 단계에서 본 파일을 사용.
--   [산출물]   50_handoff/02_1_A DB정보.sql  (본 스크립트 5·6단계 실행 결과 — A1~A6)
--              50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql  (위 A3~A6 DDL을 병합·정리)
--   [후속 SQL] 50_handoff/03_데이터마이그 B_BROKER.sql     (B: 공유 마운트/CSV 언로드)
--              50_handoff/05_데이터마이그 C_CONSUMER.sql   (C: 파일포맷/프로시저/적재/검증)
--
-- 식별자 / IDENTIFIERS
--   A(Provider) = CMRQTUT.XC97295 · B(Consumer) locator = GB72026 · 공유명 = MIG_SHARE
--   대상 DB/스키마 = GN_DW / BRONZE_CRM(45) · BRONZE_AGENCY(4) · BRONZE_ERP(1) · BRONZE_BIGQUERY(3) = 53 테이블
-- =====================================================================

USE ROLE ACCOUNTADMIN;

------------------------------------------------------------
-- 1. Share 생성
------------------------------------------------------------
CREATE SHARE mig_share COMMENT = 'A->B 데이터 마이그레이션 공유';

------------------------------------------------------------
-- 2. 공유할 DB/스키마/테이블에 대한 사용 권한 부여
--    ⚠️ 스키마 단위 USAGE가 필수. DB USAGE만 주면 B에서 테이블이 보이지 않는다.
------------------------------------------------------------
GRANT USAGE   ON DATABASE  GN_DW            TO SHARE mig_share;
GRANT USAGE   ON SCHEMA  GN_DW.BRONZE_CRM            TO SHARE mig_share;
GRANT USAGE   ON SCHEMA  GN_DW.BRONZE_BIGQUERY            TO SHARE mig_share;
GRANT USAGE   ON SCHEMA  GN_DW.BRONZE_ERP            TO SHARE mig_share;
GRANT USAGE   ON SCHEMA  GN_DW.BRONZE_AGENCY            TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_CRM TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_BIGQUERY TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_ERP TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_AGENCY TO SHARE mig_share;
-- 특정 테이블만: GRANT SELECT ON TABLE src_db.src_schema.tbl TO SHARE mig_share;
-- 주의: ALL TABLES는 '현재 존재하는' 테이블만 대상. 이후 추가된 테이블은 재부여 필요.

------------------------------------------------------------
-- 3. B 계정을 공유 대상으로 추가 (B의 account locator 또는 org.account 사용)
------------------------------------------------------------
-- ALTER SHARE mig_share ADD ACCOUNTS = <account locator>;
ALTER SHARE mig_share ADD ACCOUNTS = GB72026;

------------------------------------------------------------
-- 4. 확인
--    기대: 권한 = DB 1 + 스키마 4 + 테이블 53, SHOW SHARES의 to 컬럼에 GB72026
------------------------------------------------------------
SHOW GRANTS TO SHARE mig_share;
SHOW SHARES LIKE 'MIG_SHARE';

------------------------------------------------------------
-- 5. 이관 대상 목록/규모 스냅샷 (⚠️ 공유 전에 기록해 둘 기준값)
--    테이블 53개인지, 스키마별 행수/용량이 얼마인지 여기서 확정한다.
--    → 6장 검증에서 C의 GN_DW 집계와 테이블 단위로 대조하는 원본 기준값이다.
------------------------------------------------------------
SELECT table_schema, table_name, row_count, bytes
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE' AND table_schema LIKE 'BRONZE_%'
ORDER BY table_schema, table_name;

-- 스키마별 요약 (테이블 수 / 총 행수 / 총 용량)
SELECT table_schema,
       COUNT(*)        AS tables,
       SUM(row_count)  AS total_rows,
       SUM(bytes)      AS total_bytes
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE' AND table_schema LIKE 'BRONZE_%'
GROUP BY 1 ORDER BY 1;

-- 2026-08-12 실측 결과 (02_1_A DB정보.sql 의 A1/A2. B의 공유 DB 집계와 완전 일치 확인)
--   BRONZE_AGENCY   4 테이블 /     243,550 행 /     5,719,040 B
--   BRONZE_CRM     45 테이블 / 115,875,113 행 / 2,834,600,960 B
--   BRONZE_ERP      1 테이블 /       4,301 행 /       328,704 B
--   BRONZE_BIGQUERY      3 테이블 /     576,441 행 /   129,906,688 B
--   합계           53 테이블 / 116,699,405 행 / 2,970,555,392 B (약 2.77 GiB)
--
--   ⚠️ 2026-07-30 시점 문서는 51 테이블(CRM 43)로 기재되어 있었다. 실측은 53(CRM 45)이다.
--      누락되어 있던 2개: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT,
--                        BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR
--      → 04번 DDL 3판(2026-08-12)에 추가 완료. 이 스냅샷이 대조의 정본이다.

------------------------------------------------------------
-- 6. C 계정 재현용 DDL 추출 ========================
--    ⚠️ 공유받은(imported) DB에서는 GET_DDL이 제한될 수 있으므로 반드시 원본 A에서 수행한다.
--    결과를 04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql 로 저장한다.
------------------------------------------------------------
-- DB 전체를 한 번에 (스키마/시퀀스/파일포맷 포함)
-- SELECT GET_DDL('DATABASE', 'GN_DW', TRUE);

-- 스키마 단위로 분리 추출
-- SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_CRM', TRUE);
-- SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_BIGQUERY', TRUE);
-- SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_ERP', TRUE);
-- SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_AGENCY', TRUE);

------------------------------------------------------------
-- 7. Teardown — 이관·검증 완료 확인 후에만 실행 (01번 문서 7장)
--    ⚠️ B가 아직 언로드 중이거나 C 검증이 끝나지 않았으면 절대 실행하지 말 것.
--       공유를 끊으면 B의 GN_DW_SHARED 가 즉시 조회 불가가 된다.
--    순서: 대상 계정 제거 → 권한 회수 → Share 삭제
------------------------------------------------------------
-- -- 7.1 Share에서 B계정 제거
-- ALTER SHARE mig_share REMOVE ACCOUNTS = GB72026;
--
-- -- 7.2 Share에 부여한 권한 회수 (테이블 → 스키마 → DB 역순)
-- REVOKE SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_CRM    FROM SHARE mig_share;
-- REVOKE SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_AGENCY FROM SHARE mig_share;
-- REVOKE SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_ERP    FROM SHARE mig_share;
-- REVOKE SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_BIGQUERY    FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_CRM    FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_AGENCY FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_ERP    FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_BIGQUERY    FROM SHARE mig_share;
-- REVOKE USAGE  ON DATABASE GN_DW             FROM SHARE mig_share;
--
-- -- 7.3 Share 삭제
-- DROP SHARE mig_share;
--
-- -- 7.4 정리 확인 (0건이어야 함)
-- SHOW SHARES LIKE 'MIG_SHARE';
