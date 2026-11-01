-- =============================================================================
-- 50_RBAC_APP_OWNER_USER_ASSIGN.sql — Streamlit 소유자 이전 · 팀장 앱 USAGE · 사용자 배정(결정 즉시 실행용)
-- O271-C · 2026-10-30 · 사용자 지시 = 「롤 형식만 만들어두고 SQL 을 미리 만들어 결정되자마자 실행」
-- 정본 = 12_agent개선과제/O270_W8_운영계_실행카드.md §3-2 · 배정표 = 12_agent개선과제/O270_운영계_사용자배정표.md
--
-- 블록 = [1] 앱 소유 역할 생성(지금 실행) [2] 앱이 읽는 객체 실측(읽기 전용 · 지금 실행)
--        [3] 앱 소유 역할 권한(🔴 [2] 결과로 확정 후) [4] Streamlit 소유자 이전(🔴 앱별 승인)
--        [5] 팀장 역할 앱 USAGE(🔴 앱 목록 확정 후) [6] 사용자 배정(🔴 배정표 「확정」 행만) [7] 롤백
-- 🔴 [4] 를 끝내기 전에는 48번 [6](GN_DW_ANALYST 회수)을 실행하지 마라 — 앱 8개가 깨진다
-- 🔴 <...> 자리표시자가 남은 줄은 실행하지 마라
-- =============================================================================

-- [1] 앱 소유 역할 생성(형식만 · 권한 0 · 무해) --------------------------------
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS GN_DW_APP_OWNER
  COMMENT = 'O271 Streamlit 앱 소유 전용 역할 — 사람에게 부여하지 않는다 · 구 역할 GN_DW_ANALYST 회수 전 앱 소유권 이전처';
GRANT ROLE GN_DW_APP_OWNER TO ROLE SYSADMIN;

-- [2] 앱이 읽는 객체 실측(읽기 전용) --------------------------------------------
-- [2-a] 앱 목록(이름·위치·소유자·창고) → [4]·[5] 의 <앱 FQN> 을 여기서 채운다
SHOW STREAMLITS IN ACCOUNT;
-- [2-b] 최근 30일 GN_DW_ANALYST 소유 앱이 읽은 객체(앱 질의 = 소유자 역할로 실행)
--       <앱 서비스 사용자> = R97 Q04 의 Streamlit 서비스 계정 이름으로 채운다
SELECT f.value:"objectName"::STRING AS OBJ, COUNT(DISTINCT a.QUERY_ID) AS QUERY_CNT, MAX(a.QUERY_START_TIME) AS LAST_TS
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY a
JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY q ON q.QUERY_ID = a.QUERY_ID
, LATERAL FLATTEN(a.BASE_OBJECTS_ACCESSED) f
WHERE a.QUERY_START_TIME >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
  AND q.ROLE_NAME = 'GN_DW_ANALYST'
  AND q.USER_NAME = '<앱 서비스 사용자>'
GROUP BY 1
ORDER BY 2 DESC;

-- [3] 앱 소유 역할 권한(🔴 [2-b] 결과 스키마만 · 원칙 = 앱이 실제로 읽는 범위) -------
-- 기본안 = 접근 역할 4종 상속(GOLD·SERVING 전부) + 창고 · BRONZE·SILVER 를 읽으면 그 스키마만 추가
-- GRANT ROLE GN_DW_AR_SRC_COMMON     TO ROLE GN_DW_APP_OWNER;
-- GRANT ROLE GN_DW_AR_SRC_AGENCY     TO ROLE GN_DW_APP_OWNER;
-- GRANT ROLE GN_DW_AR_SRC_ERP        TO ROLE GN_DW_APP_OWNER;
-- GRANT ROLE GN_DW_AR_SRC_AGENCY_ERP TO ROLE GN_DW_APP_OWNER;
-- GRANT USAGE ON WAREHOUSE <앱 창고> TO ROLE GN_DW_APP_OWNER;
-- GRANT USAGE ON DATABASE <앱 DB> TO ROLE GN_DW_APP_OWNER;          -- 앱이 놓인 DB(LAB 등)
-- GRANT USAGE ON SCHEMA <앱 DB>.<앱 스키마> TO ROLE GN_DW_APP_OWNER;
-- GRANT CREATE STREAMLIT ON SCHEMA <앱 DB>.<앱 스키마> TO ROLE GN_DW_APP_OWNER;  -- 소유자가 앱을 고칠 때
-- (BRONZE·SILVER 를 읽는 경우만) GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.<스키마> TO ROLE GN_DW_APP_OWNER;

-- [4] Streamlit 소유자 이전(🔴 앱별 승인 · [3] 이후) -------------------------------
-- 앱 1개씩 이전하고 바로 열어 본다(화면이 깨지면 [7] 롤백 1줄)
-- USE ROLE ACCOUNTADMIN;
-- GRANT OWNERSHIP ON STREAMLIT <앱 FQN 1> TO ROLE GN_DW_APP_OWNER COPY CURRENT GRANTS;
-- GRANT OWNERSHIP ON STREAMLIT <앱 FQN 2> TO ROLE GN_DW_APP_OWNER COPY CURRENT GRANTS;
-- (… LAB 의 GN_DW_ANALYST 소유 8개 · GN_DW_ADMIN 소유 1개는 이전 여부 결정 · USER$CHOIH 3개는 개인 앱 = 대상 밖)
-- 확인 = SHOW STREAMLITS IN ACCOUNT; 의 owner = GN_DW_APP_OWNER

-- [5] 팀장 역할 앱 USAGE(🔴 앱 목록 확정 후) ---------------------------------------
-- USE ROLE SECURITYADMIN;
-- GRANT USAGE ON DATABASE <앱 DB> TO ROLE GN_DW_FR_LEAD;
-- GRANT USAGE ON SCHEMA <앱 DB>.<앱 스키마> TO ROLE GN_DW_FR_LEAD;
-- GRANT USAGE ON STREAMLIT <앱 FQN 1> TO ROLE GN_DW_FR_LEAD;
-- GRANT USAGE ON STREAMLIT <앱 FQN 2> TO ROLE GN_DW_FR_LEAD;
-- 🔴 팀장 역할에 테이블·SV·Agent GRANT 를 넣지 마라(앱은 소유자 권한으로 데이터를 읽는다)

-- [6] 사용자 배정(🔴 배정표 「확정」 열에 기능 역할 이름이 있는 행만 · 1인 1기능역할) ------
-- 🔴 「제외 — 개발자」 행(CHOIH · CRM_ETL · LEESH · SWLEE)은 만들지 마라
-- USE ROLE SECURITYADMIN;
-- GRANT ROLE <기능 역할> TO USER <사용자>;
-- ALTER USER <사용자> SET DEFAULT_ROLE = '<기능 역할>';
-- ALTER USER <사용자> SET DEFAULT_SECONDARY_ROLES = ();   -- 🔴 빼지 마라(사용자 승인 2026-10-30)
-- 확인 = SHOW GRANTS TO USER <사용자>; · DESC USER <사용자>; (DEFAULT_SECONDARY_ROLES = [])

-- [7] 롤백(🔴 별도 승인) ------------------------------------------------------------
-- GRANT OWNERSHIP ON STREAMLIT <앱 FQN> TO ROLE GN_DW_ANALYST COPY CURRENT GRANTS;   -- [4] 앱 1개 되돌리기
-- REVOKE ROLE <기능 역할> FROM USER <사용자>;                                         -- [6] 배정 되돌리기
-- ALTER USER <사용자> SET DEFAULT_SECONDARY_ROLES = ('ALL');
-- DROP ROLE IF EXISTS GN_DW_APP_OWNER;                                               -- [1] (소유 객체 0 일 때만)
