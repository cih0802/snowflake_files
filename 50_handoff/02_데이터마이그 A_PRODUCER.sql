-- A 계정(Provider) 실행 SQL — Direct Share 생성 및 DDL 추출
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   원본(A) 계정에서 GN_DW 브론즈 4개 스키마 + ML 예측결과 16종을 B 계정으로 Direct Share 하고,
--   C 계정에 동일 구조를 재현하기 위한 DDL 스냅샷을 추출한다.
--
-- 실행 계정 / 역할
--   A (Provider), ACCOUNTADMIN
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md
--              → 3.1(Share 생성/부여) / 3.1-B(ML 부여) / 3.2(GET_DDL 추출) / 7장(정리) 단계에서 본 파일을 사용.
--   [산출물]   50_handoff/02_1_A DB정보.sql  (본 스크립트 5·6단계 실행 결과 — A1~A6)
--              50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql  (위 A3~A6 DDL을 병합·정리)
--              50_handoff/06_데이터마이그 GN_DW_ML_DDL_20260814.sql      (ML 예측결과 16종 구조)
--   [후속 SQL] 50_handoff/03_데이터마이그 B_BROKER.sql     (B: 공유 마운트/CSV 언로드)
--              50_handoff/05_데이터마이그 C_CONSUMER.sql   (C: 파일포맷/프로시저/적재/검증)
--
-- 식별자 / IDENTIFIERS
--   A(Provider) = CMRQTUT.XC97295 · B(Consumer) locator = GB72026 · 공유명 = MIG_SHARE
--   대상 DB/스키마 = GN_DW / BRONZE_CRM(45) · BRONZE_AGENCY(4) · BRONZE_ERP(1) · BRONZE_BIGQUERY(3) = 53 테이블
--                        + ML(예측결과 16종만 · 학습·스냅샷·로그 33종 제외) = 총 69 테이블
--
-- 🔴 ML 부여 원칙 (2026-08-14 신설)
--   브론즈는 `GRANT SELECT ON ALL TABLES` 로 스키마 통짜 부여지만 **ML 은 테이블을 하나씩 부여한다.**
--   이유 = ML 스키마에는 학습용 `ML_TRAIN_DATA_*` 20종·원천 스냅샷 12종·로그 1종이 함께 있고,
--          사용자 지시로 **학습용은 Agent 노출 금지**다. `ALL TABLES` 를 쓰면 33종이 함께 열린다.
--   부수 효과(의도한 것) = 공유받은 DB의 INFORMATION_SCHEMA 에는 **부여된 16종만 보인다**
--          ⇒ B 의 언로드 루프(03번 5단계)가 자동으로 16종만 대상으로 삼는다.
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
-- 2-B. ML 스키마 부여 (2026-08-14 신설) — 예측결과 16종만 테이블 단위로 부여
--    ⚠️ ALL TABLES 금지. 학습용 ML_TRAIN_DATA_* 20종 + 원천 스냅샷 12종 + 로그 1종이
--       함께 열려 Agent 노출 금지 지시를 위반한다(상단 'ML 부여 원칙' 참조).
--    ⚠️ ML 테이블은 원천이 `create or replace TABLE` 로 재생성될 수 있다(20_ML_ddl.sql).
--       재생성되면 아래 SELECT 부여가 소실되므로 **모델 재실행 후에는 이 구간을 다시 실행**한다.
------------------------------------------------------------
GRANT USAGE ON SCHEMA GN_DW.ML TO SHARE mig_share;

-- 회원실 5종
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M                     TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M                      TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT                      TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MBER_INC_12M                        TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_LOYAL_MBER                          TO SHARE mig_share;
-- 기획실 3종
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT               TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT      TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT            TO SHARE mig_share;
-- 나눔마케팅본부 8종
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_DVLP_AMT                    TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_UCMPGN_LTV                          TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_UCMPGN_LTV_SCORE                    TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_CMPGN_LTV                           TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_CMPGN_LTV_SCORE                     TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT              TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION               TO SHARE mig_share;

-- ⛔ 부여하지 않는 것 (부여하면 사용자 지시 위반) — 참고용 목록, 실행하지 말 것
--    ML_TRAIN_DATA_* 20종 / CMPGN_MBER_SNAPSHOT · CMPGN_MONTHLY_SNAPSHOT · DAILY_CMPGN_DVLP_AMT ·
--    DVLP_AMT_SNAPSHOT · MBER_MONTHLY_INFO · MBER_MONTHLY_SETLE_INFO · MBER_MONTHLY_SNAPSHOT ·
--    MBER_NO_DSCNT_ML_DATA · MBER_SERVICE_INFO · MBRFEE_PAY_DTLS · MONTHLY_SPNSR_DVLP_AMT ·
--    SNPSR_BSNS_NO_DSCNT_ML_DATA (스냅샷 12종) / ML_PROCEDURE_LOG (로그 1종)
--    · 뷰 4종(ML_TRAIN_DATA_*_V) 도 부여하지 않는다.

-- ML 부여 확인 (기대: 16행)
SHOW GRANTS TO SHARE mig_share;
SELECT COUNT(*) AS ml_table_grants
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "granted_on" = 'TABLE' AND "name" LIKE 'GN_DW.ML.%';

------------------------------------------------------------
-- 3. B 계정을 공유 대상으로 추가 (B의 account locator 또는 org.account 사용)
------------------------------------------------------------
-- ALTER SHARE mig_share ADD ACCOUNTS = <account locator>;
ALTER SHARE mig_share ADD ACCOUNTS = GB72026;

------------------------------------------------------------
-- 4. 확인
--    기대: 권한 = DB 1 + 스키마 5(BRONZE 4 + ML) + 테이블 69(BRONZE 53 + ML 16),
--          SHOW SHARES의 to 컬럼에 GB72026
------------------------------------------------------------
SHOW GRANTS TO SHARE mig_share;
SHOW SHARES LIKE 'MIG_SHARE';

------------------------------------------------------------
-- 5. 이관 대상 목록/규모 스냅샷 (⚠️ 공유 전에 기록해 둘 기준값)
--    테이블 53개(브론즈) + 16개(ML)인지, 스키마별 행수/용량이 얼마인지 여기서 확정한다.
--    → 6장 검증에서 C의 GN_DW 집계와 테이블 단위로 대조하는 원본 기준값이다.
--    ⚠️ ML 필터는 `table_schema='ML' AND table_name LIKE 'ML_RST_DATA_%'` 다.
--       스키마 통짜로 세면 학습·스냅샷 33종이 섞여 기준값이 부풀어 C 검증이 전부 어긋난다.
------------------------------------------------------------
SELECT table_schema, table_name, row_count, bytes
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (    table_schema LIKE 'BRONZE_%'
        OR (table_schema = 'ML' AND table_name LIKE 'ML_RST_DATA_%') )
ORDER BY table_schema, table_name;

-- 스키마별 요약 (테이블 수 / 총 행수 / 총 용량)
SELECT table_schema,
       COUNT(*)        AS tables,
       SUM(row_count)  AS total_rows,
       SUM(bytes)      AS total_bytes
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (    table_schema LIKE 'BRONZE_%'
        OR (table_schema = 'ML' AND table_name LIKE 'ML_RST_DATA_%') )
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
--
-- 🔴 ML 16종 = **A 계정 실측 미확보**. 위 쿼리를 실행해 결과를 02_1_A DB정보.sql 에 A7 로 추가한다.
--    참고 기준값(A 실측 아님 · 원천 계정 라이브 · 2026-08-14 O74):
--      정본 = 05_SV-Agent_ai/20_ML_SV_설계.md §0-A (테이블별 행수 16종 전량 · STDR_MT='202606' 단일)
--      합계 1,045,732 행 · 용량 미측정
--    ⚠️ 이 값은 **A 계정에서 재확인해야 한다.** ML 은 프로시저가 월별로 DELETE+INSERT 하므로
--       기준월이 늘어나면 행수가 증가한다 ⇒ 이관 시점에 다시 측정한 값만 대조 기준으로 쓴다.


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

-- 🟢 ML 은 이미 추출되어 있다 — 재추출 불필요..,
--    산출물 = 99_provided_definition/20_ML_ddl.sql (3,217줄 · 프로시저·모델 포함 전량)
--    이관용 구조 발췌 = 50_handoff/06_데이터마이그 GN_DW_ML_DDL_20260814.sql (예측결과 16종만)
--    ⚠️ 모델·프로시저가 교체되어 결과 테이블 컬럼이 바뀌면 아래를 재실행해 06번을 갱신한다.
-- SELECT GET_DDL('SCHEMA', 'GN_DW.ML', TRUE);

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
-- -- ML: 부여를 테이블 단위로 했으므로 회수도 테이블 단위다.
-- --     🟢 여기서는 ALL TABLES 를 써도 안전하다(부여하지 않은 33종은 회수할 것이 없다).
-- --        단 회수 결과를 확인해 16건만 사라졌는지 본다.
-- REVOKE SELECT ON ALL TABLES IN SCHEMA GN_DW.ML             FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_CRM    FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_AGENCY FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_ERP    FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_BIGQUERY    FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.ML            FROM SHARE mig_share;
-- REVOKE USAGE  ON DATABASE GN_DW             FROM SHARE mig_share;
--
-- -- 7.3 Share 삭제
-- DROP SHARE mig_share;
--
-- -- 7.4 정리 확인 (0건이어야 함)
-- SHOW SHARES LIKE 'MIG_SHARE';
