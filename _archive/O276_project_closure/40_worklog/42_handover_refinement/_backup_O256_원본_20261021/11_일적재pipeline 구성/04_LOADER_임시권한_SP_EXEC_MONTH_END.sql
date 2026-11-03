-- GN_DW_LOADER 임시권한 — CALL GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END('YYYYMM') 한 줄만 허용
-- Co-authored with CoCo
--
-- 목표: LOADER 가 월마감 프로시저를 CALL 할 수 있게 한다. dbt 는 LOADER 에게 직접 주지 않는다.
-- 원리: 프로시저를 EXECUTE AS OWNER(소유자 권한)로 만든다.
--   · CALL 하는 사람(LOADER)에게 필요한 것 = DB USAGE + 스키마 USAGE + 프로시저 USAGE + 웨어하우스 USAGE
--   · 프로시저 안의 EXECUTE DBT PROJECT 는 **소유자(GN_DW_ADMIN) 권한**으로 실행된다
--     ⇒ LOADER 에게 DBT PROJECT USAGE 를 줄 필요가 없다(최소권한, 임의 dbt 인자 실행 차단).
-- 실측(2026-09-30, GN_DW_ADMIN): SHOW PROCEDURES LIKE '%MONTH_END%' IN ACCOUNT = 0건
--   ⇒ 프로시저가 아직 없다. B 절에서 생성한다(이미 있으면 B 를 건너뛰고 C 로).
-- 이미 있는 권한(07_ENVIRONMENT_RBAC_setup.sql): USAGE ON DATABASE GN_DW(201행),
--   USAGE ON SCHEMA GN_DW.BRONZE_CRM(287행), USAGE ON WAREHOUSE GN_DW_ETL_WH(108행).
-- 실행 role: GN_DW_ADMIN (BRONZE_CRM 은 MANAGED ACCESS — 소유자만 grant 가능). 멱등.

USE ROLE GN_DW_ADMIN;

/* =====================================================================
   A. 사전 확인
   ===================================================================== */
SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;                    -- DW_PIPELINE 존재 확인
SHOW PROCEDURES LIKE 'SP_EXEC_MONTH_END' IN SCHEMA GN_DW.BRONZE_CRM;

/* =====================================================================
   B. 프로시저 생성 (EXECUTE AS OWNER) — 이미 있으면 생략
      · 인자 검증: 6자리 YYYYMM 만 허용 → ARGS 문자열 주입 차단
      · dbt 인자(--vars 키 이름·select 범위)는 프로젝트에 맞게 조정할 것
   ===================================================================== */
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END(P_YYYYMM VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
COMMENT = '월마감 dbt 실행 — LOADER 호출용(소유자 권한). 인자 YYYYMM'
AS
$$
DECLARE
  v_args VARCHAR;
  bad_arg EXCEPTION (-20001, 'P_YYYYMM must be YYYYMM (e.g. 202609)');
BEGIN
  IF (NOT REGEXP_LIKE(:P_YYYYMM, '^(19|20)[0-9]{2}(0[1-9]|1[0-2])$')) THEN
    RAISE bad_arg;
  END IF;
  v_args := 'build --target dev2 --vars ''{"base_ym": "' || :P_YYYYMM || '"}''';
  EXECUTE IMMEDIATE 'EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS = ''' || REPLACE(:v_args, '''', '''''') || '''';
  RETURN 'OK: month-end dbt build for ' || :P_YYYYMM;
END;
$$;

/* =====================================================================
   C. LOADER 임시권한 — 핵심은 이 한 줄(나머지는 멱등 재확인)
      프로시저 USAGE 는 인자 시그니처(VARCHAR)까지 적어야 한다.
   ===================================================================== */
GRANT USAGE ON DATABASE  GN_DW            TO ROLE GN_DW_LOADER;
GRANT USAGE ON SCHEMA    GN_DW.BRONZE_CRM TO ROLE GN_DW_LOADER;
GRANT USAGE ON WAREHOUSE GN_DW_ETL_WH     TO ROLE GN_DW_LOADER;
GRANT USAGE ON PROCEDURE GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END(VARCHAR) TO ROLE GN_DW_LOADER;

-- ⚠️ 소유자(GN_DW_ADMIN) 쪽 전제: ADMIN 이 DBT PROJECT GN_DW.OPS.DW_PIPELINE 을 소유 → 추가 grant 불요.
--    프로시저 소유자를 다른 롤로 바꾸면 그 롤에 아래가 필요하다:
-- GRANT USAGE ON DBT PROJECT GN_DW.OPS.DW_PIPELINE TO ROLE <OWNER_ROLE>;
-- ❌ LOADER 에게 직접 주지 말 것(임의 ARGS 로 dbt 실행 가능해짐):
-- GRANT USAGE ON DBT PROJECT GN_DW.OPS.DW_PIPELINE TO ROLE GN_DW_LOADER;

/* =====================================================================
   D. 검증 (LOADER 로 전환해서 실행)
   ===================================================================== */
SHOW GRANTS TO ROLE GN_DW_LOADER;
-- USE ROLE GN_DW_LOADER;
-- USE WAREHOUSE GN_DW_ETL_WH;
-- CALL GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END('202609');   -- 성공 기대
-- CALL GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END('2026-09');  -- -20001 오류 기대(인자 검증)
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS = 'build';  -- 권한 오류 기대(직접 실행 차단)

/* =====================================================================
   E. 임시권한 회수 (임시 기간 종료 시 — 파괴적 작업이므로 승인 후 실행)
   ===================================================================== */
-- USE ROLE GN_DW_ADMIN;
-- REVOKE USAGE ON PROCEDURE GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END(VARCHAR) FROM ROLE GN_DW_LOADER;
