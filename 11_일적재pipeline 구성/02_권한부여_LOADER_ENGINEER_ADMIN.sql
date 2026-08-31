-- BRONZE_CRM_2 / SILVER_2 / GOLD_2 권한 부여 — LOADER / ENGINEER / ADMIN 3역할 한정
-- Co-authored with CoCo
--
-- 근거: 00_개요_및_실행순서.md "역할 계층 관련 중요 정정" — GN_DW_LOADER 와 GN_DW_ENGINEER 는
--   형제 관계(둘 다 GN_DW_ADMIN 의 직속 자식)라 서로 상속하지 않는다. 따라서 두 role 모두에
--   실제 역할에 맞는 권한을 명시로 부여한다. ANALYST/VIEWER/SERVICE 는 대상에서 제외(테스트 격리).
-- 패턴 근거: 02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql §D.2~D.5 (원본 SILVER/GOLD/BRONZE_CRM 패턴)를
--   _2 스키마로 그대로 이식했다.
-- 실행 role: GN_DW_ADMIN (스키마 소유자만 grant 발급 가능 — WITH MANAGED ACCESS).
-- 멱등: GRANT 재실행은 무해.

USE ROLE GN_DW_ADMIN;

/* =====================================================================
   A. BRONZE_CRM_2 — LOADER: 적재(INSERT/UPDATE) · ENGINEER: dbt 읽기(SELECT) · ADMIN: 전체(소유자)
   ===================================================================== */
GRANT ALL PRIVILEGES ON SCHEMA GN_DW.BRONZE_CRM_2 TO ROLE GN_DW_ADMIN;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA GN_DW.BRONZE_CRM_2 TO ROLE GN_DW_ADMIN;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA GN_DW.BRONZE_CRM_2 TO ROLE GN_DW_ADMIN;

GRANT USAGE ON SCHEMA GN_DW.BRONZE_CRM_2 TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON ALL TABLES    IN SCHEMA GN_DW.BRONZE_CRM_2 TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.BRONZE_CRM_2 TO ROLE GN_DW_ENGINEER;

GRANT USAGE ON SCHEMA GN_DW.BRONZE_CRM_2 TO ROLE GN_DW_LOADER;
GRANT INSERT, UPDATE ON ALL TABLES    IN SCHEMA GN_DW.BRONZE_CRM_2 TO ROLE GN_DW_LOADER;
GRANT INSERT, UPDATE ON FUTURE TABLES IN SCHEMA GN_DW.BRONZE_CRM_2 TO ROLE GN_DW_LOADER;

/* =====================================================================
   B. SILVER_2 — ENGINEER: dbt 적재(원본 SILVER 와 동일 패턴 · D.3+D.5) · ADMIN: 전체(소유자)
      LOADER 는 SILVER_2 에 권한 없음(원본과 동일 — LOADER 는 BRONZE 전용).
   ===================================================================== */
GRANT ALL PRIVILEGES ON SCHEMA GN_DW.SILVER_2 TO ROLE GN_DW_ADMIN;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA GN_DW.SILVER_2 TO ROLE GN_DW_ADMIN;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA GN_DW.SILVER_2 TO ROLE GN_DW_ADMIN;

GRANT USAGE, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE FUNCTION
  ON SCHEMA GN_DW.SILVER_2 TO ROLE GN_DW_ENGINEER;
GRANT SELECT, INSERT, TRUNCATE, DELETE ON ALL TABLES    IN SCHEMA GN_DW.SILVER_2 TO ROLE GN_DW_ENGINEER;
GRANT SELECT, INSERT, TRUNCATE, DELETE ON FUTURE TABLES IN SCHEMA GN_DW.SILVER_2 TO ROLE GN_DW_ENGINEER;

-- CRM_MEMBER_DEV 는 원본과 동일하게 incremental_strategy='merge' 모델이라 UPDATE 가 추가로 필요하다
-- (07_ENVIRONMENT_RBAC_setup.sql §D.5 의 테이블 단위 좁은 부여 원칙 계승).
-- 01_스키마생성_및_구조복제.sql 실행 후에만 테이블이 존재하므로, 먼저 그 스크립트를 실행할 것.
GRANT UPDATE ON TABLE GN_DW.SILVER_2.CRM_MEMBER_DEV TO ROLE GN_DW_ENGINEER;

/* =====================================================================
   C. GOLD_2 — ENGINEER: dbt 적재(원본 GOLD 와 동일 패턴 · D.2+D.5) · ADMIN: 전체(소유자)
   ===================================================================== */
GRANT ALL PRIVILEGES ON SCHEMA GN_DW.GOLD_2 TO ROLE GN_DW_ADMIN;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA GN_DW.GOLD_2 TO ROLE GN_DW_ADMIN;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA GN_DW.GOLD_2 TO ROLE GN_DW_ADMIN;

GRANT USAGE, CREATE VIEW ON SCHEMA GN_DW.GOLD_2 TO ROLE GN_DW_ENGINEER;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES    IN SCHEMA GN_DW.GOLD_2 TO ROLE GN_DW_ENGINEER;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA GN_DW.GOLD_2 TO ROLE GN_DW_ENGINEER;

/* =====================================================================
   D. 참고 — 이번 스코프에서 그대로 재사용하는 기존 권한(변경 없음, 확인용 조회만)
      · GN_DW_ENGINEER 는 BRONZE_ERP / BRONZE_AGENCY / SILVER(silver_external.BIGQUERY_REFINED_DATA) 를
        이미 SELECT 가능하다(07_ENVIRONMENT_RBAC_setup.sql §D.3/§D.4) — _2 파이프라인도 이 원천들을
        원본 그대로 재사용하므로 추가 grant가 필요 없다.
      · dbt test store_failures(GN_DW.OPS.dbt_test__audit / GN_DW.OPS) 권한도 target 과 무관하게
        동일 위치를 쓰므로 추가 grant 불필요(07 §D.6).
   ===================================================================== */
-- SHOW GRANTS TO ROLE GN_DW_ENGINEER;  -- 필요 시 위 전제 확인용

SHOW GRANTS TO ROLE GN_DW_ENGINEER;