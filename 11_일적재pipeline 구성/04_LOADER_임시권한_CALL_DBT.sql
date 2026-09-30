-- 일/월배치를 돌리기 위해 GN_DW_LOADER 롤에 임시로 권한을 주는 쿼리문
/* =====================================================================
   04_LOADER_임시권한_CALL_DBT.sql
   목적 : GN_DW_LOADER 에 아래 2가지 실행 권한을 임시 부여
          1) CALL GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END('YYYYMM');
          2) EXECUTE DBT PROJECT <dbt 프로젝트>
   환경 : 개발계에서 작성, 객체는 운영계 기준(GN_DW) → 운영계 계정에서 실행
   실행 : 객체 OWNER 역할(또는 SECURITYADMIN / MANAGE GRANTS 보유 역할)
   ※ <...> 표기는 실제 값으로 치환 후 실행
   ===================================================================== */

USE ROLE GN_DW_ADMIN;   -- 객체 OWNER 역할로 변경 필요 시 수정

/* ---------------------------------------------------------------------
   0. 사전 확인 : 프로시저 인자 시그니처 / 실행 모드(OWNER vs CALLER)
   --------------------------------------------------------------------- */
SHOW PROCEDURES LIKE 'SP_EXEC_MONTH_END' IN SCHEMA GN_DW.BRONZE_CRM;
DESC PROCEDURE GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END(VARCHAR);
-- execute as = OWNER  → 1번 GRANT만으로 CALL 가능
-- execute as = CALLER → 프로시저 내부에서 참조하는 테이블/DBT 권한도 LOADER에 필요

SHOW DBT PROJECTS IN DATABASE GN_DW;   -- dbt 프로젝트 FQN 확인

/* ---------------------------------------------------------------------
   1. 공통 : 컨테이너 / 웨어하우스 USAGE
   --------------------------------------------------------------------- */
GRANT USAGE ON DATABASE  GN_DW                   TO ROLE GN_DW_LOADER;
GRANT USAGE ON SCHEMA    GN_DW.BRONZE_CRM        TO ROLE GN_DW_LOADER;
GRANT USAGE ON SCHEMA    GN_DW.OPS TO ROLE GN_DW_LOADER;
GRANT USAGE ON WAREHOUSE GN_DW_ETL_WH      TO ROLE GN_DW_LOADER;

/* ---------------------------------------------------------------------
   2. 프로시저 CALL 권한 (프로시저는 USAGE 가 곧 CALL 권한, 인자 타입 필수)
   --------------------------------------------------------------------- */
GRANT USAGE ON PROCEDURE GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END(VARCHAR)
    TO ROLE GN_DW_LOADER;
-- 1. SILVER 스키마 USAGE 권한 부여
GRANT USAGE ON SCHEMA GN_DW.SILVER TO ROLE GN_DW_LOADER;

-- 2. SILVER 스키마 내 프로시저 USAGE 권한 부여
GRANT USAGE ON ALL PROCEDURES IN SCHEMA GN_DW.SILVER TO ROLE GN_DW_LOADER;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA GN_DW.SILVER TO ROLE GN_DW_LOADER;

-- 3. (필요 시) ML 스키마 및 로그 테이블 권한도 확인/부여
GRANT USAGE ON SCHEMA GN_DW.ML TO ROLE GN_DW_LOADER;
GRANT ALL ON TABLE GN_DW.ML.ML_PROCEDURE_LOG TO ROLE GN_DW_LOADER;

/* ---------------------------------------------------------------------
   3. DBT PROJECT EXECUTE 권한 (EXECUTE DBT PROJECT 는 USAGE 로 허용)
   --------------------------------------------------------------------- */
GRANT USAGE   ON DBT PROJECT GN_DW.OPS.DW_PIPELINE TO ROLE GN_DW_LOADER;
GRANT MONITOR ON DBT PROJECT GN_DW.OPS.DW_PIPELINE TO ROLE GN_DW_LOADER; -- 실행 이력/로그 조회용(선택)

/* ---------------------------------------------------------------------
   4. 검증 (LOADER 로 전환 후 실행)
   --------------------------------------------------------------------- */
SHOW GRANTS TO ROLE GN_DW_LOADER;

USE ROLE GN_DW_LOADER;
USE WAREHOUSE GN_DW_ETL_WH;
CALL GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END('202608');
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS = 'run';

/* ---------------------------------------------------------------------
   5. 임시권한 회수 (작업 종료 후)
   --------------------------------------------------------------------- */
-- USE ROLE GN_DW_ADMIN;
-- REVOKE USAGE   ON PROCEDURE GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END(VARCHAR)            FROM ROLE GN_DW_LOADER;
-- REVOKE USAGE   ON DBT PROJECT GN_DW.OPS.DW_PIPELINE       FROM ROLE GN_DW_LOADER;
-- REVOKE MONITOR ON DBT PROJECT GN_DW.OPS.DW_PIPELINE       FROM ROLE GN_DW_LOADER;
