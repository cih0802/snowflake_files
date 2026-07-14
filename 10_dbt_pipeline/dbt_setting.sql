-- dbt 환경세팅 — GN_DW_ENGINEER Role 사용, Bronze-Silver-Gold 아키텍처
-- Co-authored with CoCo

/*
================================================================================
  GN_DW dbt 파이프라인 환경세팅
  대상 DB     : GN_DW
  아키텍처    : Bronze(원천적재) → Silver(정제) → Gold(분석)
  dbt 역할    : GN_DW_ENGINEER (기존 Role 체계 그대로 사용)
  웨어하우스  : GN_DW_ETL_WH (변환용) / GN_DW_DEV_WH (개발용)
--------------------------------------------------------------------------------
  dbt 모델 매핑:
    - source  → BRONZE_CRM, BRONZE_GA4, BRONZE_AGENCY, BRONZE_ERP (읽기 전용)
    - staging/intermediate → SILVER (CREATE TABLE, CREATE VIEW)
    - marts   → GOLD (DML on 기존 테이블, CREATE VIEW)
--------------------------------------------------------------------------------
  ※ GN_DW_ENGINEER Role에는 웨어하우스·DB 사용 권한이 이미 부여됨.
    (02_유저_Role 세팅.sql 참조)
  ※ MANAGED ACCESS 스키마이므로, 아래 GRANT는 GN_DW_ADMIN이 실행해야 함.
================================================================================
*/

-- ============================================================================
-- GN_DW_ENGINEER에 dbt가 필요로 하는 스키마별 권한 부여
-- (MANAGED ACCESS 스키마 → 스키마 Owner인 GN_DW_ADMIN으로 실행)
-- ============================================================================
USE ROLE GN_DW_ADMIN;

-- ----------------------------------------------------------------------------
-- Database 레벨 — USAGE (MANAGED ACCESS 스키마 접근의 전제조건)
-- ----------------------------------------------------------------------------
GRANT USAGE ON DATABASE GN_DW TO ROLE GN_DW_ENGINEER;

-- ----------------------------------------------------------------------------
-- Bronze 스키마 — SELECT만 (dbt source 읽기 전용)
-- ----------------------------------------------------------------------------
-- CRM
GRANT USAGE ON SCHEMA GN_DW.BRONZE_CRM TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_CRM TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.BRONZE_CRM TO ROLE GN_DW_ENGINEER;

-- GA4
GRANT USAGE ON SCHEMA GN_DW.BRONZE_GA4 TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_GA4 TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.BRONZE_GA4 TO ROLE GN_DW_ENGINEER;

-- 대행사 광고
GRANT USAGE ON SCHEMA GN_DW.BRONZE_AGENCY TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_AGENCY TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.BRONZE_AGENCY TO ROLE GN_DW_ENGINEER;

-- ERP
GRANT USAGE ON SCHEMA GN_DW.BRONZE_ERP TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_ERP TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.BRONZE_ERP TO ROLE GN_DW_ENGINEER;

-- ----------------------------------------------------------------------------
-- Silver 스키마 — 읽기 + 쓰기 (dbt staging & intermediate)
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT CREATE TABLE ON SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT CREATE VIEW ON SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;

-- ----------------------------------------------------------------------------
-- Gold 스키마 — 기존 테이블에 변환적재 + View 생성 (dbt marts)
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;
GRANT INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;
GRANT CREATE VIEW ON SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;

-- ============================================================================
-- 검증: GN_DW_ENGINEER에 부여된 권한 확인
-- ============================================================================
SHOW GRANTS TO ROLE GN_DW_ENGINEER;

/*
================================================================================
  향후 확장: GN_DW_DBT Role 분리 (방식 C)
  ※ 설계 상세: 02_GN_DW_building/01_환경 Role.md § 3 참조
--------------------------------------------------------------------------------
  트리거 조건:
    - Gold에 CREATE TABLE이 필요해질 때
    - dbt와 수동 ETL 권한을 격리해야 할 때
    - CI/CD 전용 서비스 계정이 필요할 때

  계층 구조:
    GN_DW_ADMIN
      └── GN_DW_DBT (ENGINEER 상속 + Gold CREATE TABLE)
            └── GN_DW_ENGINEER (현행 유지)

  구현 시 아래 주석 해제:
--------------------------------------------------------------------------------
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS GN_DW_DBT
    COMMENT = 'dbt 파이프라인 전용 - ENGINEER 상속 + Gold DDL';
GRANT ROLE GN_DW_ENGINEER TO ROLE GN_DW_DBT;
GRANT ROLE GN_DW_DBT TO ROLE GN_DW_ADMIN;

USE ROLE GN_DW_ADMIN;
GRANT CREATE TABLE ON SCHEMA GN_DW.GOLD TO ROLE GN_DW_DBT;

-- 이후 profiles.yml의 role을 GN_DW_DBT로 변경
================================================================================
*/
