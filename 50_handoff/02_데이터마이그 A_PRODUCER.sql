-- A 계정(Provider) 실행 SQL — Direct Share 생성 및 DDL 추출

USE ROLE ACCOUNTADMIN;

------------------------------------------------------------
-- 1. Share 생성
------------------------------------------------------------
CREATE SHARE mig_share COMMENT = 'A->B 데이터 마이그레이션 공유';

------------------------------------------------------------
-- 2. 브론즈 3개 스키마 부여
--    ⚠️ 스키마 단위 USAGE가 필수. DB USAGE만 주면 B에서 테이블이 보이지 않는다.
--    ⚠️ ALL TABLES 는 '현재 존재하는' 테이블만 대상. 이후 추가된 테이블은 재부여 필요.
------------------------------------------------------------
GRANT USAGE   ON DATABASE  GN_DW                          TO SHARE mig_share;
GRANT USAGE   ON SCHEMA    GN_DW.BRONZE_CRM               TO SHARE mig_share;
GRANT USAGE   ON SCHEMA    GN_DW.BRONZE_ERP               TO SHARE mig_share;
GRANT USAGE   ON SCHEMA    GN_DW.BRONZE_AGENCY            TO SHARE mig_share;
GRANT USAGE   ON SCHEMA    GN_DW.BRONZE_GA4               TO SHARE mig_share;
GRANT USAGE   ON SCHEMA    GN_DW.BRONZE_GSC               TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_CRM    TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_ERP    TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_AGENCY TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_GA4    TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_GSC    TO SHARE mig_share;

------------------------------------------------------------
-- 2.1 SILVER 부여 — 정제 테이블 1개만
--    ⚠️ ALL TABLES 금지. 이관 대상이 아닌 테이블이 함께 열린다.
------------------------------------------------------------
GRANT USAGE  ON SCHEMA GN_DW.SILVER                        TO SHARE mig_share;
GRANT SELECT ON TABLE  GN_DW.SILVER.BIGQUERY_REFINED_DATA  TO SHARE mig_share;

------------------------------------------------------------
-- 2.2 ⛔ BRONZE_BIGQUERY — 부여하지 않는다
--    실수로 부여했다면 즉시 회수할 것:
------------------------------------------------------------
-- REVOKE SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_BIGQUERY  FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_BIGQUERY                FROM SHARE mig_share;

------------------------------------------------------------
-- 2-B. ML 스키마 부여 — 예측결과 12종만
--    🆕 [2026-10-02 O198 · 사용자 지시] 17 → 12종 확정.
--       + 신규 2 = MKTG_CHANNEL_MBER_AVG_LTV · CMPGN_SPNSR_AMT_LTV
--       − 제외 4 = UCMPGN_LTV · UCMPGN_LTV_SCORE · CMPGN_LTV · CMPGN_LTV_SCORE (아래 2-C 에서 REVOKE)
--       − 기획실 3 = O195 DROP 유지
--    ⚠️ ALL TABLES 금지. 학습용 20종 + 스냅샷 12종 + 로그 1종이 함께 열려
--       Agent 노출 금지 지시를 위반한다(상단 '테이블 단위 부여 원칙' 참조).
------------------------------------------------------------
GRANT USAGE ON SCHEMA GN_DW.ML TO SHARE mig_share;

-- 회원실 5종
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M                     TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M                      TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT                      TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MBER_INC_12M                        TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_LOYAL_MBER                          TO SHARE mig_share;
-- 기획실 3종 ⛔ [2026-10-01 O195] 운영계·개발계 모두 DROP 완료(사용자 지시) — 재생성하지 않는다. 재활성은 O192-A D-3 사용자 결정
-- GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT               TO SHARE mig_share;
-- GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT      TO SHARE mig_share;
-- GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT            TO SHARE mig_share;
-- 나눔마케팅본부 7종
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_DVLP_AMT                    TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV           TO SHARE mig_share;  -- 🆕 O198
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_CMPGN_SPNSR_AMT_LTV                 TO SHARE mig_share;  -- 🆕 O198
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT              TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION               TO SHARE mig_share;
GRANT SELECT ON TABLE GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION                     TO SHARE mig_share;

------------------------------------------------------------
-- 2-C. 🆕 [O198] 재공유 시 제외 4종 회수 — 기존 share 를 재사용할 때만 실행
--    🔴 GRANT 만 다시 돌리면 이전에 부여한 4종이 share 에 **그대로 남는다**(조용히 열려 있다).
--    ⚠️ 원천에 이미 없는 테이블이면 REVOKE 가 「does not exist」로 실패한다 — 그 줄은 건너뛴다(정상).
------------------------------------------------------------
REVOKE SELECT ON TABLE GN_DW.ML.ML_RST_DATA_UCMPGN_LTV          FROM SHARE mig_share;
REVOKE SELECT ON TABLE GN_DW.ML.ML_RST_DATA_UCMPGN_LTV_SCORE    FROM SHARE mig_share;
REVOKE SELECT ON TABLE GN_DW.ML.ML_RST_DATA_CMPGN_LTV           FROM SHARE mig_share;
REVOKE SELECT ON TABLE GN_DW.ML.ML_RST_DATA_CMPGN_LTV_SCORE     FROM SHARE mig_share;

-- ⛔ 부여하지 않는 것 (부여하면 사용자 지시 위반) — 참고용 목록, 실행하지 말 것
--    ML_TRAIN_DATA_* 20종 / CMPGN_MBER_SNAPSHOT · CMPGN_MONTHLY_SNAPSHOT · DAILY_CMPGN_DVLP_AMT ·
--    DVLP_AMT_SNAPSHOT · MBER_MONTHLY_INFO · MBER_MONTHLY_SETLE_INFO · MBER_MONTHLY_SNAPSHOT ·
--    MBER_NO_DSCNT_ML_DATA · MBER_SERVICE_INFO · MBRFEE_PAY_DTLS · MONTHLY_SPNSR_DVLP_AMT ·
--    SNPSR_BSNS_NO_DSCNT_ML_DATA (스냅샷 12종) / ML_PROCEDURE_LOG (로그 1종)
--    · 뷰 4종(ML_TRAIN_DATA_*_V) 도 부여하지 않는다.

------------------------------------------------------------
-- 3. B 계정을 공유 대상으로 추가 (B의 account locator 또는 org.account 사용)
------------------------------------------------------------
-- ALTER SHARE mig_share ADD ACCOUNTS = <account locator>;
ALTER SHARE mig_share ADD ACCOUNTS = PH62230;
-- ALTER SHARE mig_share REMOVE ACCOUNTS = BHZYJSX.AB90688;
-- ALTER SHARE mig_share REMOVE ACCOUNTS = CGAWPLL.FP89006;

------------------------------------------------------------
-- 4. 부여 결과 확인
--    기대: DB 1 + 스키마 7(BRONZE 5 + SILVER + ML) + 테이블 77(브론즈 64 + SILVER 1 + ML 12)  🆕 [O198] ML 17→12 · 총계 82→77
--    🔴 [2026-09-17] 종전 기재 「테이블 67(브론즈 50)」·「77(브론즈 60)」은 stale 이었다 — 현행은 브론즈 61 · 총계 78.  (🔴 2026-09-28 현행 = 브론즈 64 · CRM 53 · ML 17 · 총계 82)
--       브론즈 5 = BRONZE_CRM(53) · BRONZE_AGENCY(4) · BRONZE_ERP(2) · BRONZE_GA4(2) · BRONZE_GSC(3)
------------------------------------------------------------
SHOW GRANTS TO SHARE mig_share;
SHOW SHARES LIKE 'MIG_SHARE';   -- to 컬럼에 RPKTYWX.JX43598 이 보여야 함

-- 4.1 부여 집계 점검 (한 번에 판정)
SHOW GRANTS TO SHARE mig_share;
SELECT
  COUNT_IF("granted_on" = 'TABLE' AND "name" LIKE 'GN_DW.BRONZE_CRM.%') AS crm_tables,        -- 기대 50
  COUNT_IF("granted_on" = 'TABLE' AND "name" LIKE 'GN_DW.ML.%')      AS ml_tables,        -- 기대 12 (O198)
  COUNT_IF("granted_on" = 'TABLE' AND "name" LIKE 'GN_DW.SILVER.%')  AS silver_tables,    -- 기대 1
  COUNT_IF("granted_on" = 'SCHEMA')                                  AS schemas,          -- 기대 7
  COUNT_IF("name" ILIKE '%BRONZE_BIGQUERY%')                         AS bigquery_grants   -- 기대 0
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
-- → bigquery_grants ≠ 0 이면 2.2 하단의 REVOKE 로 즉시 회수한다.
--   ml_tables ≠ 12 또는 silver_tables ≠ 1 이면 2.1 / 2-B / 2-C 를 다시 실행한다(12 초과 = 2-C 미실행 · 제외 4종 잔존).

------------------------------------------------------------
-- 5. 대조 기준값 스냅샷 (⚠️ 공유 직후 기록)
--    결과를 02_1_A DB정보.sql 에 보관한다.
--    → B(03번 3.1) · C(06번 A.6) 가 테이블 단위로 대조하는 원본 기준값이다.
--    ⚠️ ML 필터는 **12종 명시 목록**이다(🆕 O198 · 종전 `LIKE 'ML_RST_DATA_%'` 폐기).
--       원천에 제외 대상 ML_RST_DATA_*(구 LTV 4종 등)가 남아 있으면 LIKE 로는 기준값이 부풀어 C 검증이 어긋난다.
--       스키마 통짜로 세면 학습·스냅샷 33종까지 섞인다.
--    ⚠️ 브론즈 필터를 `LIKE 'BRONZE_%'` 로 되돌리지 말 것 — 공유 대상 아닌 스키마가 섞인다.
------------------------------------------------------------
SELECT table_schema, table_name, row_count, bytes
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY', 'BRONZE_GA4', 'BRONZE_GSC')
        OR (table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')
        OR (table_schema = 'ML'     AND table_name IN ('ML_RST_DATA_SPNSR_CHURN_12M','ML_RST_DATA_MBER_CHURN_12M','ML_RST_DATA_CMPGN_CTGR_AMT',
                                    'ML_RST_DATA_MBER_INC_12M','ML_RST_DATA_LOYAL_MBER','ML_RST_DATA_MONTHLY_DVLP_AMT',
                                    'ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV','ML_RST_DATA_CMPGN_SPNSR_AMT_LTV',
                                    'ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION','ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT',
                                    'ML_RST_DATA_DVLP_INC_CONTRIBUTION','ML_RST_DATA_ONCE_CONVERSION')) )
ORDER BY table_schema, table_name;

-- 스키마별 요약 (기대: AGENCY 4 · CRM 53 · ERP 2 · GA4 2 · GSC 3 · ML 12 · SILVER 1 = 77)  🆕 [O198]
--   🔴 [2026-09-17] 종전 기재 「CRM 45 · ERP 1 · = 67」·「총계 77」은 stale 이었다 — 현행은 CRM 50 · 총계 78.  (🔴 2026-09-28 현행 = 브론즈 64 · CRM 53 · ML 17 · 총계 82)
SELECT table_schema,
       COUNT(*)       AS tables,
       SUM(row_count) AS total_rows,
       SUM(CASE WHEN row_count = 0 THEN 1 ELSE 0 END) AS zero_row_tables
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY', 'BRONZE_GA4', 'BRONZE_GSC')
        OR (table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA')
        OR (table_schema = 'ML'     AND table_name IN ('ML_RST_DATA_SPNSR_CHURN_12M','ML_RST_DATA_MBER_CHURN_12M','ML_RST_DATA_CMPGN_CTGR_AMT',
                                    'ML_RST_DATA_MBER_INC_12M','ML_RST_DATA_LOYAL_MBER','ML_RST_DATA_MONTHLY_DVLP_AMT',
                                    'ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV','ML_RST_DATA_CMPGN_SPNSR_AMT_LTV',
                                    'ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION','ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT',
                                    'ML_RST_DATA_DVLP_INC_CONTRIBUTION','ML_RST_DATA_ONCE_CONVERSION')) )
GROUP BY 1 ORDER BY 1;

-- 5.1 반정형 컬럼 통제총계 (⚠️ C 검증에 필수 — 없으면 파싱 실패를 검출할 수 없다)
--   CSV 왕복 시 반정형은 JSON 문자열이 되고 C 에서 TRY_PARSE_JSON 으로 복원한다.
--   TRY_PARSE_JSON 은 실패 시 조용히 NULL 을 돌려주므로, **A 측 기대 NULL 수**가 없으면
--   '파싱 실패'와 '원래 NULL'을 구분할 수 없다. 아래 결과를 반드시 C 에 전달한다.
SELECT 'SILVER.BIGQUERY_REFINED_DATA' AS tbl, 'ITEMS' AS col,
       COUNT(*) AS n_rows, COUNT(*) - COUNT(ITEMS) AS n_null, SUM(ARRAY_SIZE(ITEMS)) AS total_elements
FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
UNION ALL
SELECT 'ML.ML_RST_DATA_SPNSR_CHURN_12M', 'PREDICTION',
       COUNT(*), COUNT(*) - COUNT(PREDICTION), NULL FROM GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M
UNION ALL
SELECT 'ML.ML_RST_DATA_MBER_CHURN_12M', 'PREDICTION',
       COUNT(*), COUNT(*) - COUNT(PREDICTION), NULL FROM GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M
UNION ALL
SELECT 'ML.ML_RST_DATA_MBER_INC_12M', 'PREDICTION',
       COUNT(*), COUNT(*) - COUNT(PREDICTION), NULL FROM GN_DW.ML.ML_RST_DATA_MBER_INC_12M
UNION ALL
SELECT 'ML.ML_RST_DATA_LOYAL_MBER', 'PREDICTION',
       COUNT(*), COUNT(*) - COUNT(PREDICTION), NULL FROM GN_DW.ML.ML_RST_DATA_LOYAL_MBER;

-- 5.2 SILVER 구조 확인 (기대: 118 컬럼 · ITEMS 가 118번째 · ARRAY)
--   이 값이 06번 SILVER DDL 및 07번 A.5 의 TRY_PARSE_JSON($118) 위치와 일치해야 한다.
SELECT MAX(ordinal_position)                                        AS n_cols,
       MAX(CASE WHEN data_type = 'ARRAY' THEN column_name END)      AS array_col,
       MAX(CASE WHEN data_type = 'ARRAY' THEN ordinal_position END) AS array_pos
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA';

-- ⚠️ ML 은 프로시저가 월별로 DELETE+INSERT 하므로 기준월이 늘어나면 행수가 증가한다.
--    ⇒ 이관 시점에 다시 측정한 값만 대조 기준으로 쓴다.
--    ⚠️ BRONZE_CRM 은 과거 문서에 43 테이블로 기재된 적이 있으나 2026-08-12 실측은 45 였다.
--       (누락분: TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT · TM_MM_FDRM_MBER_SPNSR)
--       🔴 [2026-09-15] 현행 CRM 은 50 이다(개편 반영) — 위 45 는 그 시점 기록이다.

------------------------------------------------------------
-- 6. C 계정 재현용 DDL 추출
--    ⚠️ 공유받은(imported) DB에서는 GET_DDL이 제한될 수 있으므로 반드시 원본 A에서 수행한다.
------------------------------------------------------------
-- 6.1 브론즈 5개 스키마 → 04_데이터마이그 GN_DW_BRONZE_DDL.sql 로 저장
SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_CRM', TRUE);
SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_ERP', TRUE);
SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_AGENCY', TRUE);
SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_GA4', TRUE);
SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_GSC', TRUE);
--   ⚠️ GET_DDL('DATABASE', 'GN_DW', TRUE) 는 쓰지 않는다.
--      공유 대상이 아닌 스키마·테이블까지 전부 덤프된다.

-- 6.2 SILVER 정제 테이블 1개 → 06_데이터마이그 GN_DW_SILVER_DDL.sql 로 저장
-- SELECT GET_DDL('TABLE', 'GN_DW.SILVER.BIGQUERY_REFINED_DATA', TRUE);
--   ⚠️ SCHEMA 단위로 뽑지 말 것. 대상 아닌 테이블까지 포함된다.
--   ⚠️ 컬럼 수/순서가 06번(06_데이터마이그 GN_DW_SILVER_DDL.sql) 파일과 다르면
--      C 적재가 전량 실패하거나 한 칸씩 밀려 오적재된다.
--      이관 직전 반드시 06번 파일과 대조할 것 (5.2 결과와 함께 본다).
--   🔴 [2026-09-15] 이 SILVER 정의의 원천 문서(99_provided_definition/18_…)가 소실되었다
--      (내용이 16번 BRONZE_GSC DDL 로 교체됨) ⇒ 여기서 뽑은 GET_DDL 이 **유일한 대조 기준**이다.

-- 🟢 ML 은 이미 추출되어 있다 — 재추출 불필요
--    산출물 = 99_provided_definition/20_ML_ddl.sql (프로시저·모델 포함 전량)
--    이관용 구조 발췌 = 50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql (예측결과 12종만 · O198)
--    🔴 [O198] 신규 2종(MKTG_CHANNEL_MBER_AVG_LTV · CMPGN_SPNSR_AMT_LTV)은 20_ML_ddl.sql 에 없다 ⇒ 아래 6.3 을 실행해 05번을 확정한다.
--    ⚠️ 모델·프로시저가 교체되어 결과 테이블 컬럼이 바뀌면 아래를 재실행해 05번을 갱신한다.
-- SELECT GET_DDL('SCHEMA', 'GN_DW.ML', TRUE);

-- 6.3 🆕 [O198] 신규 ML 2종 구조 추출 → 05번의 「추정 구조」 2블록을 이 출력으로 교체한다
--    🔴 05번의 두 CREATE 문은 구 LTV 테이블 구조로 **추정**해 둔 것이다(원천 정의 부재).
--       컬럼 수·순서가 다르면 C 의 위치 기반 CSV 적재가 한 칸씩 밀린다 ⇒ 반드시 이 결과로 대조·교체.
SELECT GET_DDL('TABLE', 'GN_DW.ML.ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV', TRUE);
SELECT GET_DDL('TABLE', 'GN_DW.ML.ML_RST_DATA_CMPGN_SPNSR_AMT_LTV', TRUE);
SELECT table_name, ordinal_position, column_name, data_type
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'ML'
  AND table_name IN ('ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV', 'ML_RST_DATA_CMPGN_SPNSR_AMT_LTV')
ORDER BY 1, 2;

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
-- -- SILVER / ML: 부여를 테이블 단위로 했으므로 회수도 테이블 단위다.
-- --   🟢 ALL TABLES 를 써도 안전하다(부여하지 않은 것은 회수할 것이 없다).
-- --      단 회수 후 4.1 을 다시 돌려 ml_tables=0 · silver_tables=0 인지 확인한다.
-- REVOKE SELECT ON TABLE GN_DW.SILVER.BIGQUERY_REFINED_DATA FROM SHARE mig_share;
-- REVOKE SELECT ON ALL TABLES IN SCHEMA GN_DW.ML            FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_CRM    FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_AGENCY FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.BRONZE_ERP    FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.SILVER        FROM SHARE mig_share;
-- REVOKE USAGE  ON SCHEMA GN_DW.ML            FROM SHARE mig_share;
-- REVOKE USAGE  ON DATABASE GN_DW             FROM SHARE mig_share;
--
-- -- 7.3 Share 삭제
-- DROP SHARE mig_share;
--
-- -- 7.4 정리 확인 (0건이어야 함)
-- SHOW SHARES LIKE 'MIG_SHARE';
