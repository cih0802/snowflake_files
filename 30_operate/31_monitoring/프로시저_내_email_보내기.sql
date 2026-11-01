-- ==============================================================================
-- 제목: Snowflake 파이썬 프로시저 에러 이메일 알림 종합 가이드
-- 구성:
--   CASE 1. Notification Integration 생성 (화이트리스트 vs 전체 허용)
--   CASE 2. 권한 및 롤(Role) 제어 (OWNER vs CALLER 권한 위임)
--   CASE 3. 파이썬 프로시저 내 이메일 발송 패턴 (단일 / 다중 / 동적 조회 / HTML 서식)
--   CASE 4. Task 연동 및 실행 검증
-- ==============================================================================

-- ==============================================================================
-- 0. 초기 시트 실행 권한
-- ==============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE GN_DW;
USE SCHEMA OPS;

-- ==============================================================================
-- 1. [Notification Integration] 이메일 연동 객체 생성 (ACCOUNTADMIN 권한 필요)
-- ==============================================================================

-- [방법 A] 특정 이메일만 허용하는 화이트리스트 방식 (보안 권장)
-- ※ 등록할 이메일은 Snowflake 계정에 존재하는 유저의 이메일(인증 완료)이어야 합니다.
CREATE OR REPLACE NOTIFICATION INTEGRATION email_alert_integration_whitelist
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('sample@example.com', 'admin@example.com')
  DEFAULT_RECIPIENTS = ('sample@example.com')
  COMMENT = '화이트리스트 기반 이메일 알림 연동';

-- [방법 B] 계정 내 모든 인증 유저에게 발송을 허용하는 방식 (유연한 운영)
-- ALLOWED_RECIPIENTS를 생략하면 미래에 새로 가입/생성되는 유저를 포함하여 발송 가능
CREATE OR REPLACE NOTIFICATION INTEGRATION email_alert_integration
  TYPE = EMAIL
  ENABLED = TRUE
  COMMENT = '계정 내 모든 유저 대상 이메일 알림 연동';


-- ==============================================================================
-- 2. [권한 관리] Role에 Integration 사용 권한 부여
-- ==============================================================================

-- 프로시저/태스크를 수행할 Role에 USAGE 권한 부여
GRANT USAGE ON INTEGRATION email_alert_integration TO ROLE sysadmin;
GRANT USAGE ON INTEGRATION email_alert_integration TO ROLE accountadmin;
GRANT USAGE ON INTEGRATION email_alert_integration_whitelist TO ROLE sysadmin;
GRANT USAGE ON INTEGRATION email_alert_integration TO ROLE GN_DW_LOADER;

-- ==============================================================================
-- 3. [파이썬 프로시저] 에러 발생 시 이메일 발송 샘플 (다양한 케이스 지원)
-- ==============================================================================
CREATE OR REPLACE PROCEDURE send_email_on_error_sample(
    target_table STRING,
    recipient_type STRING -- 'SINGLE', 'MULTI', 'DYNAMIC' 중 선택
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_process'
EXECUTE AS OWNER  -- OWNER 권한: 프로시저 소유 Role의 Integration 권한으로 일괄 실행
AS
$$
import traceback
import snowflake.snowpark as snowpark

def run_process(session: snowpark.Session, target_table: str, recipient_type: str = "SINGLE") -> str:
    integration_name = "EMAIL_ALERT_INTEGRATION"
    
    # --------------------------------------------------------------------------
    # [수신자 목록 결정 로직]
    # SYSTEM$SEND_EMAIL은 2번째 인자로 "이메일1, 이메일2" 형태의 쉼표 구분 문자열(VARCHAR)을 받습니다.
    # --------------------------------------------------------------------------
    # CASE 1: 단일 수신자
    if recipient_type == "SINGLE":
        recipients_str = "tigerof11@gmail.com"
        
    # CASE 2: 다중 수신자 (쉼표로 구분된 문자열)
    elif recipient_type == "MULTI":
        # ※ 실제 발송을 위해서는 나열된 모든 이메일이 Snowflake 계정에 유저로 등록/인증되어 있어야 합니다.
        recipients_str = "sample@example.com,sample@example.com,sample@example.com"  # 예: "engineer@company.com, admin@company.com"
        
    # CASE 3: 계정 내 활성 유저 이메일 동적 조회 (SHOW USERS 활용)
    elif recipient_type == "DYNAMIC":
        try:
            user_df = session.sql("SHOW USERS").collect()
            email_list = [row['email'] for row in user_df if row['email']]
            if email_list:
                recipients_str = ", ".join(list(set(email_list)))
            else:
                recipients_str = "sample@example.com"
        except Exception:
            recipients_str = "sample@example.com"
    else:
        recipients_str = "sample@example.com"

    # --------------------------------------------------------------------------
    # [메인 로직 실행 및 에러 캐치]
    # --------------------------------------------------------------------------
    try:
        # 데이터 조회 / ETL 작업 (예시: 테이블 접근)
        df = session.table(target_table)
        row_count = df.count()
        return f"SUCCESS: Processed {target_table} successfully ({row_count} rows)."

    except Exception as e:
        # 에러 메시지 및 Stack Trace 수집 (SQL 따옴표 이스케이프)
        error_msg = str(e).replace("'", "''")
        stack_trace = traceback.format_exc().replace("'", "''")
        
        email_subject = f"[Snowflake Alert] Procedure Failure: {target_table}"
        
        # HTML 형식 본문 템플릿
        email_body = f"""<html>
<body>
    <h2 style='color: #d9534f;'>⚠️ Snowflake 데이터 파이프라인 에러 알림</h2>
    <p><strong>Target Object:</strong> {target_table}</p>
    <p><strong>Recipient Type:</strong> {recipient_type}</p>
    <p><strong>Error Message:</strong><br><pre>{error_msg}</pre></p>
    <details open>
        <summary><strong>Stack Trace</strong></summary>
        <pre style='background-color: #f8f9fa; padding: 10px; border: 1px solid #ddd;'>{stack_trace}</pre>
    </details>
</body>
</html>"""
        
        # SYSTEM$SEND_EMAIL 호출
        email_sql = f"""
        CALL SYSTEM$SEND_EMAIL(
            '{integration_name}',
            '{recipients_str}',
            '{email_subject}',
            '{email_body.replace("'", "''")}',
            'text/html'
        )
        """
        
        try:
            session.sql(email_sql).collect()
        except Exception as mail_err:
            pass
        
        # Task/호출자가 실패 상태를 감지할 수 있도록 에러 발생
        raise RuntimeError(f"Procedure execution failed: {e}")
$$;


-- ==============================================================================
-- 4. [Task 연동 및 스케줄링]
-- ==============================================================================

-- Task 생성 (예시: 의도적 에러 발생 테스트용)
CREATE OR REPLACE TASK run_daily_process_task
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = 'USING CRON 0 9 * * * Asia/Seoul'
AS
  CALL send_email_on_error_sample('SANDBOX.PUBLIC.NON_EXISTENT_TABLE', 'MULTI');

-- Task 즉시 테스트 실행
-- EXECUTE TASK run_daily_process_task;

CALL send_email_on_error_sample('SANDBOX.PUBLIC.NON_EXISTENT_TABLE', 'SINGLE');

-- Task 실행 이력 및 상태 확인
-- SELECT *
-- FROM TABLE(SANDBOX.INFORMATION_SCHEMA.TASK_HISTORY(
--     TASK_NAME => 'RUN_DAILY_PROCESS_TASK'
-- ))
-- ORDER BY SCHEDULED_TIME DESC;
