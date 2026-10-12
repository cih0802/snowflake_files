-- ==============================================================================
-- [GN_DW] OPS 알림 수신자 관리 표준 및 파이프라인 에러 이메일 알림 연동
-- 문서번호: 08_mornitoring/07_OPS_알림수신자관리_및_파이프라인_이메일알림_표준.sql
-- 세션라벨: O210 (2026-10-08)
--
-- 목표:
--   1. Notification Integration 생성 (계정 내 전체 인증 유저 대상)
--   2. GN_DW.OPS.ALERT_RECIPIENT_CONFIG 테이블 생성 (USER 기반 페르소나별 수신자 관리)
--   3. 사용자 동기화 프로시저 USP_SYNC_ALERT_RECIPIENTS 생성 (SHOW USERS 기반 자동 MERGE)
--   4. 파이프라인 에러 알림 발송 프로시저 USP_SEND_PIPELINE_ERROR_ALERT 생성 (역할/페르소나별 라우팅)
--   5. RBAC 권한 부여 (GN_DW_ADMIN, GN_DW_ENGINEER, SYSADMIN 등)
--   6. 스케줄링 Task 연동 예시
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE GN_DW;
USE SCHEMA OPS;

-- ------------------------------------------------------------------------------
-- 1. [Notification Integration] 이메일 알림 연동 객체 생성
-- ------------------------------------------------------------------------------
-- ALLOWED_RECIPIENTS를 생략하여 계정에 등록된 모든 인증 유저(미래 유저 포함)에게 발송 허용
CREATE OR REPLACE NOTIFICATION INTEGRATION EMAIL_ALERT_INTEGRATION
  TYPE = EMAIL
  ENABLED = TRUE
  COMMENT = 'GN_DW 데이터 파이프라인 및 거버넌스 에러 알림 연동';

-- 역할(Role)에 Integration 사용 권한 부여
GRANT USAGE ON INTEGRATION EMAIL_ALERT_INTEGRATION TO ROLE SYSADMIN;
GRANT USAGE ON INTEGRATION EMAIL_ALERT_INTEGRATION TO ROLE GN_DW_ADMIN;
GRANT USAGE ON INTEGRATION EMAIL_ALERT_INTEGRATION TO ROLE GN_DW_ENGINEER;


-- ------------------------------------------------------------------------------
-- 2. [OPS 메타데이터] 알림 수신자 관리 테이블 생성
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS GN_DW.OPS.ALERT_RECIPIENT_CONFIG (
    USER_NAME              STRING        NOT NULL COMMENT 'Snowflake 사용자명 (예: TRIALADMIN)',
    USER_EMAIL             STRING        NOT NULL COMMENT '사용자 인증 이메일 주소',
    DISPLAY_NAME           STRING        COMMENT '표시 이름 (이름/부서 등)',
    IS_ACTIVE_YN           VARCHAR(1)    DEFAULT 'Y' COMMENT '수신 활성화 여부 (Y/N)',
    IS_PIPELINE_ADMIN_YN   VARCHAR(1)    DEFAULT 'N' COMMENT 'ETL/데이터 파이프라인 장애 알림 수신 여부 (Y/N)',
    IS_ANALYST_YN          VARCHAR(1)    DEFAULT 'N' COMMENT '데이터/마트 분석가 알림 수신 여부 (Y/N)',
    IS_BUSINESS_USER_YN    VARCHAR(1)    DEFAULT 'N' COMMENT '현업 비즈니스 리포트 알림 수신 여부 (Y/N)',
    UPDATED_AT             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT '최종 수정 시각',
    UPDATED_BY             STRING        DEFAULT CURRENT_USER() COMMENT '최종 수정자',
    CONSTRAINT PK_ALERT_RECIPIENT_CONFIG PRIMARY KEY (USER_NAME)
)
COMMENT = '데이터 파이프라인 및 마트 알림 수신자 관리 메타데이터 테이블';


-- ------------------------------------------------------------------------------
-- 3. [동기화 프로시저] Snowflake USERS -> ALERT_RECIPIENT_CONFIG 자동 동기화
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.OPS.USP_SYNC_ALERT_RECIPIENTS()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'sync_users'
EXECUTE AS OWNER
AS
$$
import snowflake.snowpark as snowpark

def sync_users(session: snowpark.Session) -> str:
    # 1. SHOW USERS 실행하여 계정 내 유저 정보 조회
    user_rows = session.sql("SHOW USERS").collect()
    
    upserted_count = 0
    for u in user_rows:
        uname = u['name']
        email = u['email']
        dname = u['display_name'] or u['first_name'] or uname
        disabled = str(u['disabled']).lower() == 'true'
        
        # 이메일이 없는 시스템/더미 계정은 제외
        if not email or not email.strip():
            continue
            
        clean_email = email.strip().lower()
        active_yn = 'N' if disabled else 'Y'
        
        # 2. 신규 유저는 등록하고, 기존 유저는 이메일/활성상태 갱신 (YN 플래그는 기존값 보존)
        merge_sql = f"""
        MERGE INTO GN_DW.OPS.ALERT_RECIPIENT_CONFIG T
        USING (SELECT '{uname}' AS USER_NAME, '{clean_email}' AS USER_EMAIL, '{dname}' AS DISPLAY_NAME, '{active_yn}' AS IS_ACTIVE_YN) S
        ON T.USER_NAME = S.USER_NAME
        WHEN MATCHED THEN
            UPDATE SET 
                T.USER_EMAIL = S.USER_EMAIL,
                T.DISPLAY_NAME = S.DISPLAY_NAME,
                T.IS_ACTIVE_YN = S.IS_ACTIVE_YN,
                T.UPDATED_AT = CURRENT_TIMESTAMP(),
                T.UPDATED_BY = CURRENT_USER()
        WHEN NOT MATCHED THEN
            INSERT (USER_NAME, USER_EMAIL, DISPLAY_NAME, IS_ACTIVE_YN, IS_PIPELINE_ADMIN_YN, IS_ANALYST_YN, IS_BUSINESS_USER_YN)
            VALUES (S.USER_NAME, S.USER_EMAIL, S.DISPLAY_NAME, S.IS_ACTIVE_YN, 'N', 'N', 'N')
        """
        session.sql(merge_sql).collect()
        upserted_count += 1
        
    return f"SUCCESS: Synchronized {upserted_count} users into ALERT_RECIPIENT_CONFIG."
$$;

-- 동기화 초기 1회 실행
CALL GN_DW.OPS.USP_SYNC_ALERT_RECIPIENTS();

-- 초기 기본 파이프라인 관리자 플래그 부여 예시 (현재 로그인 유저 TRIALADMIN)
UPDATE GN_DW.OPS.ALERT_RECIPIENT_CONFIG
SET IS_PIPELINE_ADMIN_YN = 'Y',
    IS_ANALYST_YN = 'Y'
WHERE USER_NAME = 'TRIALADMIN';


-- ------------------------------------------------------------------------------
-- 4. [알림 공통 프로시저] 대상 타겟(PIPELINE, ANALYST, BIZ)별 에러 메일 발송
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.OPS.USP_SEND_PIPELINE_ERROR_ALERT(
    pipeline_name STRING,
    error_summary STRING,
    stack_trace STRING,
    target_role_category STRING  -- 'PIPELINE_ADMIN', 'ANALYST', 'BUSINESS_USER', 'ALL'
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_alert'
EXECUTE AS OWNER
AS
$$
import snowflake.snowpark as snowpark

def send_alert(session: snowpark.Session, pipeline_name: str, error_summary: str, stack_trace: str, target_role_category: str = "PIPELINE_ADMIN") -> str:
    integration_name = "EMAIL_ALERT_INTEGRATION"
    
    # 1. 수신 대상 필터링 쿼리 구성
    where_clause = "IS_ACTIVE_YN = 'Y'"
    if target_role_category == "PIPELINE_ADMIN":
        where_clause += " AND IS_PIPELINE_ADMIN_YN = 'Y'"
    elif target_role_category == "ANALYST":
        where_clause += " AND IS_ANALYST_YN = 'Y'"
    elif target_role_category == "BUSINESS_USER":
        where_clause += " AND IS_BUSINESS_USER_YN = 'Y'"
    elif target_role_category == "ALL":
        where_clause += " AND (IS_PIPELINE_ADMIN_YN = 'Y' OR IS_ANALYST_YN = 'Y' OR IS_BUSINESS_USER_YN = 'Y')"
    
    sql = f"""
    SELECT DISTINCT LOWER(TRIM(USER_EMAIL)) AS EMAIL
    FROM GN_DW.OPS.ALERT_RECIPIENT_CONFIG
    WHERE {where_clause}
    """
    df = session.sql(sql).collect()
    email_list = [row['EMAIL'] for row in df if row['EMAIL']]
    
    if not email_list:
        return "SKIPPED: No active recipients found for category " + target_role_category
    
    # 중복 제거 및 쉼표 구분 문자열 생성
    recipients_str = ", ".join(sorted(list(set(email_list))))
    
    # 2. 메일 본문(HTML) 구성
    email_subject = f"[GN_DW 장애 알림] {pipeline_name} 파이프라인 오류"
    email_body = f"""<html>
<body style='font-family: Arial, sans-serif;'>
    <div style='background-color: #f8d7da; color: #721c24; padding: 15px; border-radius: 5px; border: 1px solid #f5c6cb;'>
        <h2 style='margin-top: 0;'>⚠️ GN_DW 데이터 파이프라인 에러 알림</h2>
        <p><strong>Pipeline / Task:</strong> {pipeline_name}</p>
        <p><strong>Target Category:</strong> {target_role_category}</p>
        <p><strong>Error Summary:</strong></p>
        <pre style='background: #fff; padding: 10px; border: 1px solid #ddd; border-radius: 4px; color: #c7254e;'>{error_summary}</pre>
    </div>
    <br>
    <details open>
        <summary style='cursor: pointer; font-weight: bold;'>🔍 상세 Stack Trace (Click)</summary>
        <pre style='background-color: #f8f9fa; padding: 12px; border: 1px solid #e9ecef; border-radius: 4px; font-size: 12px; overflow-x: auto;'>{stack_trace}</pre>
    </details>
    <br>
    <hr style='border: 0; border-top: 1px solid #eee;'>
    <p style='color: #888; font-size: 11px;'>본 메일은 Snowflake GN_DW.OPS.USP_SEND_PIPELINE_ERROR_ALERT 에 의해 자동으로 발송되었습니다.</p>
</body>
</html>"""

    # 3. SYSTEM$SEND_EMAIL 발송
    send_sql = f"""
    CALL SYSTEM$SEND_EMAIL(
        '{integration_name}',
        '{recipients_str}',
        '{email_subject}',
        '{email_body.replace("'", "''")}',
        'text/html'
    )
    """
    session.sql(send_sql).collect()
    return f"SUCCESS: Alert sent to [{recipients_str}]"
$$;


-- ------------------------------------------------------------------------------
-- 5. [파이프라인 적용 예시 프로시저] 실제 비즈니스/ETL 프로시저 내 적용 패턴
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.OPS.SAMPLE_ETL_PIPELINE_PROC(target_table_name STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_etl'
EXECUTE AS OWNER
AS
$$
import traceback
import snowflake.snowpark as snowpark

def run_etl(session: snowpark.Session, target_table_name: str) -> str:
    pipeline_name = f"ETL_LOAD_{target_table_name}"
    
    try:
        # [실제 작업 로직 수행]
        # 예시: 테이블 접근 및 데이터 카운트
        df = session.table(target_table_name)
        cnt = df.count()
        return f"SUCCESS: Processed {target_table_name} with {cnt} rows."
        
    except Exception as e:
        error_summary = str(e).replace("'", "''")
        stack_trace = traceback.format_exc().replace("'", "''")
        
        # 장애 알림 공통 프로시저 호출 (PIPELINE_ADMIN 대상 라우팅)
        try:
            alert_call_sql = f"""
            CALL GN_DW.OPS.USP_SEND_PIPELINE_ERROR_ALERT(
                '{pipeline_name}',
                '{error_summary}',
                '{stack_trace}',
                'PIPELINE_ADMIN'
            )
            """
            session.sql(alert_call_sql).collect()
        except Exception as alert_err:
            pass  # 알림 발송 실패가 원래 에러 처리를 방해하지 않도록 방어
            
        # 태스크 및 상위 오케스트레이터가 장애를 인지할 수 있도록 에러 raise
        raise RuntimeError(f"Pipeline {pipeline_name} failed. Error: {e}")
$$;


-- ------------------------------------------------------------------------------
-- 6. [RBAC 권한 부여]
-- ------------------------------------------------------------------------------
GRANT USAGE ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ADMIN;
GRANT USAGE ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ENGINEER;
GRANT USAGE ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ANALYST;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE GN_DW.OPS.ALERT_RECIPIENT_CONFIG TO ROLE GN_DW_ADMIN;
GRANT SELECT ON TABLE GN_DW.OPS.ALERT_RECIPIENT_CONFIG TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON TABLE GN_DW.OPS.ALERT_RECIPIENT_CONFIG TO ROLE GN_DW_ANALYST;

GRANT USAGE ON PROCEDURE GN_DW.OPS.USP_SYNC_ALERT_RECIPIENTS() TO ROLE GN_DW_ADMIN;
GRANT USAGE ON PROCEDURE GN_DW.OPS.USP_SEND_PIPELINE_ERROR_ALERT(STRING, STRING, STRING, STRING) TO ROLE GN_DW_ADMIN;
GRANT USAGE ON PROCEDURE GN_DW.OPS.USP_SEND_PIPELINE_ERROR_ALERT(STRING, STRING, STRING, STRING) TO ROLE GN_DW_ENGINEER;
GRANT USAGE ON PROCEDURE GN_DW.OPS.SAMPLE_ETL_PIPELINE_PROC(STRING) TO ROLE GN_DW_ADMIN;
GRANT USAGE ON PROCEDURE GN_DW.OPS.SAMPLE_ETL_PIPELINE_PROC(STRING) TO ROLE GN_DW_ENGINEER;
