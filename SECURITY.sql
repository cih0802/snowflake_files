-- 만료된 Git 자격 증명 시크릿 갱신 방법
-- Co-authored with CoCo

-- ============================================================
-- 방법 1: 워크스페이스 Push 시 인라인 자격 증명 사용 (시크릿 수정 불필요)
-- ============================================================
-- Snowsight에서 Push 버튼 클릭 시 새 토큰을 직접 입력하거나,
-- SQL로 push할 경우:
--
-- ALTER STREAMLIT USER$.PUBLIC."snowflake_files" PUSH
--   USERNAME = '<git_username>'
--   PASSWORD = '<new_personal_access_token>'
--   NAME = '<git_author_name>'
--   EMAIL = '<git_author_email>';

-- ============================================================
-- 방법 2: 접근 가능한 DB에 새 시크릿 생성 후 참조
-- ============================================================
USE ROLE ACCOUNTADMIN;

-- 1) API Integration의 ALLOWED_AUTHENTICATION_SECRETS 업데이트
ALTER API INTEGRATION git_integration
  SET ALLOWED_AUTHENTICATION_SECRETS = ALL;

-- 2) 접근 가능한 DB/스키마에 새 시크릿 생성
CREATE DATABASE IF NOT EXISTS ADMIN_DB;
CREATE SCHEMA IF NOT EXISTS ADMIN_DB.PUBLIC;

CREATE OR REPLACE SECRET ADMIN_DB.PUBLIC.git_sec
    TYPE = PASSWORD
    USERNAME = 'cih0802'
    PASSWORD = '<NEW_PERSONAL_ACCESS_TOKEN>';  -- 여기에 새 PAT 입력

-- 3) 워크스페이스 Push 시 새 시크릿 참조
-- ALTER STREAMLIT USER$.PUBLIC."snowflake_files" PUSH
--   GIT_CREDENTIALS = ADMIN_DB.PUBLIC.git_sec
--   NAME = 'cih0802'
--   EMAIL = '<your_email>';

-- ============================================================
-- 방법 3 (가장 간단): Snowsight UI에서 직접 처리
-- ============================================================
-- 워크스페이스 상단 Git 메뉴 → Settings → Credentials에서
-- 새 토큰으로 업데이트
