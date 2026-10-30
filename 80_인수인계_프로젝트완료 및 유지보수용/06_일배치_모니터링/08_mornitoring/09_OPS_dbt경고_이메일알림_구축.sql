-- =============================================================================
-- Purpose    : [GN_DW] dbt 데이터 품질 경고(WARN 테스트) 이메일 알림 구축
-- Target     : PROCEDURE GN_DW.OPS.USP_SEND_DBT_WARN_SPNSR_CLS_DUP, ALERT GN_DW.OPS.ALERT_DBT_WARN_SPNSR_CLS_DUP, ALERT GN_DW.OPS.ALERT_DAILY_TASK_FAILED(§7)
-- Run order  : 운영계 #16
-- Depends on : GN_DW.OPS.WARN_SPNSR_CLS_AGGR_SRC_DUP, GN_DW.OPS.ALERT_RECIPIENT_CONFIG
-- Issue      : -
-- =============================================================================
-- ==============================================================================
-- [GN_DW] dbt 데이터 품질 경고(WARN 테스트) 이메일 알림 구축
-- 문서번호: 08_mornitoring/09_OPS_dbt경고_이메일알림_구축.sql
-- 세션라벨: 2026-10-16 (dbt grain 보정 후속)
--
-- 왜 07 과 문서를 나누는가
--   07 = 수신자 관리(누구에게) + 발송 공통 프로시저(어떻게 보내나) — 표준·공용.
--   09 = dbt WARN 결과를 「언제·무엇을 보고」 발송할지 — 감시 대상별 ALERT 구축 런북.
--   ⇒ 수신자는 07 §3-1 변수 DBT_ALERT_RECIPIENTS 가 정본이다. 이 문서에는 수신자를 적지 않는다.
--
-- 감시 대상 (store_failures = true, schema = 'OPS' 로 OPS 에 고정되는 dbt WARN 테스트)
--   · GN_DW.OPS.WARN_SPNSR_CLS_AGGR_SRC_DUP — 외부 수기 업로드 SILVER.MM_SPNSR_CLS_AGGR_DATA grain 중복
--       (tests/warn_spnsr_cls_aggr_src_dup.sql · 1행 = 중복 키 1개 · GOLD 는 큰 값 1건 유지로 이미 방어됨)
--        2026-10-16 첫 실행 = 459키 (202607·202608·202609 업로드분)
--   WARN: store_failures 테이블은 테스트가 돌 때마다 다시 만들어진다 ⇒ 0행 = 최신 빌드에서 해소됨.
--
-- 전제
--   1) 07 실행 완료 (ALERT_RECIPIENT_CONFIG · IS_DBT_ALERT_YN · USP_SEND_PIPELINE_ERROR_ALERT 'DBT_ALERT' 분기)
--   2) 07 §3-1 로 수신자 1명 이상 IS_DBT_ALERT_YN = 'Y'
--   3) dbt build 1회 이상 실행되어 OPS.WARN_SPNSR_CLS_AGGR_SRC_DUP 실재
--   4) 이 문서를 실행하는 역할(GN_DW_ADMIN)에 07 공통 프로시저 USAGE 가 있어야 한다 — §2 는 EXECUTE AS OWNER 다.
--      (07 2026-10-16 판부터 공통 프로시저 자체가 GN_DW_ADMIN 소유 ⇒ 소유권으로 충족)
--   5) GN_DW_ADMIN 에 계정 권한 EXECUTE ALERT — 07 §1 (ACCOUNTADMIN 구간)에서 부여.
--   실행 역할 = 전 구간 GN_DW_ADMIN (ACCOUNTADMIN 불필요 · OPS 소유자 = GN_DW_ADMIN).
--      WARN: 07 §4 를 CREATE OR REPLACE 로 다시 배포하면 GRANT 가 사라진다 ⇒ 07 §6 을 반드시 다시 실행.
--      (2026-10-16 실측: 재배포 후 §6 누락 → 'Unknown user-defined function USP_SEND_PIPELINE_ERROR_ALERT')
-- ==============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;
USE DATABASE GN_DW;
USE SCHEMA OPS;

-- ------------------------------------------------------------------------------
-- 0. [설정 변수] 실행 시각 — 일일 dbt build(TASK_DW_BUILD_DAILY) 종료 이후로 맞춘다.
-- ------------------------------------------------------------------------------
--   WARN: 2026-10-16 현재 GN_DW_ADMIN 에서 TASK_DW_BUILD_DAILY 가 조회되지 않아 실행 시각을 실측하지 못했다.
--      SHOW TASKS 로 build 스케줄을 확인한 뒤 그보다 늦은 시각으로 고친다.
SET DBT_ALERT_SCHEDULE = 'USING CRON 0 9 * * * Asia/Seoul';


-- ------------------------------------------------------------------------------
-- 1. [사전 점검] 감시 테이블과 수신자
-- ------------------------------------------------------------------------------
SELECT COUNT(*) AS DUP_KEYS FROM GN_DW.OPS.WARN_SPNSR_CLS_AGGR_SRC_DUP;

SELECT USER_NAME, USER_EMAIL
FROM GN_DW.OPS.ALERT_RECIPIENT_CONFIG
WHERE IS_ACTIVE_YN = 'Y' AND IS_DBT_ALERT_YN = 'Y';   -- 0행이면 07 §3-1 먼저

-- 전제 4) 확인: GN_DW_ADMIN 행이 USAGE 로 있어야 한다(없으면 07 §6 재실행 · ACCOUNTADMIN)
SHOW GRANTS ON PROCEDURE GN_DW.OPS.USP_SEND_PIPELINE_ERROR_ALERT(STRING, STRING, STRING, STRING);

-- ------------------------------------------------------------------------------
-- 2. [발송 프로시저] 경고 요약 조립 → 07 공통 프로시저('DBT_ALERT')로 발송
-- ------------------------------------------------------------------------------
--   ALERT 의 THEN 절은 단일 문장이라 요약 조립을 프로시저로 뺀다.
CREATE OR REPLACE PROCEDURE GN_DW.OPS.USP_SEND_DBT_WARN_SPNSR_CLS_DUP()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    v_keys    NUMBER;
    v_summary STRING;
    v_detail  STRING;
    v_result  STRING;
BEGIN
    SELECT COUNT(*),
           LISTAGG(DISTINCT STDR_MT, ', ') WITHIN GROUP (ORDER BY STDR_MT)
      INTO :v_keys, :v_detail
      FROM GN_DW.OPS.WARN_SPNSR_CLS_AGGR_SRC_DUP;

    IF (v_keys = 0) THEN
        RETURN 'SKIPPED: no duplicate keys';
    END IF;

    v_summary := '외부 수기 업로드 SILVER.MM_SPNSR_CLS_AGGR_DATA 에 같은 grain 중복 ' || v_keys ||
                 '키 (기준월: ' || v_detail || '). GOLD.WIDE_SPNSR_CLS_AGGR 는 큰 값 1건으로 계속 서비스 중 — ' ||
                 '원천 파일에서 중복 행을 정리해 다시 업로드해 주세요.';

    SELECT LISTAGG(STDR_MT || ' | ' || AGGR_TY_NM || ' | ' || CPR_NM || ' | ' || SPNSR_BSNS_GRP_NM || ' | ' ||
                   NEW_EXST_DIV_NM || ' | ' || HDQ_BRNCH_GRP_NM || ' | 행 ' || ROW_CNT ||
                   ' | VALUE1 ' || VALUE1_MIN || ' ~ ' || VALUE1_MAX, '\n')
             WITHIN GROUP (ORDER BY STDR_MT, AGGR_TY_NM, CPR_NM, SPNSR_BSNS_GRP_NM)
      INTO :v_detail
      FROM (SELECT * FROM GN_DW.OPS.WARN_SPNSR_CLS_AGGR_SRC_DUP
            ORDER BY STDR_MT, AGGR_TY_NM, CPR_NM, SPNSR_BSNS_GRP_NM LIMIT 100);   -- 메일 본문 상한

    CALL GN_DW.OPS.USP_SEND_PIPELINE_ERROR_ALERT(
        'dbt WARN · warn_spnsr_cls_aggr_src_dup',
        :v_summary,
        '기준월 | 집계유형 | 법인 | 후원사업그룹 | 신규기존 | 본부지부 | 행수 | VALUE1 범위 (상위 100키)\n' || :v_detail,
        'DBT_ALERT') INTO :v_result;
    RETURN v_result;
END;
$$;


-- ------------------------------------------------------------------------------
-- 3. [ALERT] 매일 build 후 중복이 남아 있으면 발송
-- ------------------------------------------------------------------------------
--   SCHEDULE 은 §0 변수를 쓴다(ALERT DDL 은 세션 변수를 직접 받지 않으므로 EXECUTE IMMEDIATE 로 조립).


EXECUTE IMMEDIATE
$$
BEGIN
    LET sched STRING := (SELECT $DBT_ALERT_SCHEDULE);
    EXECUTE IMMEDIATE
        'CREATE OR REPLACE ALERT GN_DW.OPS.ALERT_DBT_WARN_SPNSR_CLS_DUP
           WAREHOUSE = GN_DW_ETL_WH
           SCHEDULE = ''' || sched || '''
           COMMENT = ''dbt WARN warn_spnsr_cls_aggr_src_dup → 07 DBT_ALERT 수신자 메일 (09 문서)''
           IF (EXISTS (SELECT 1 FROM GN_DW.OPS.WARN_SPNSR_CLS_AGGR_SRC_DUP))
           THEN CALL GN_DW.OPS.USP_SEND_DBT_WARN_SPNSR_CLS_DUP()';
    RETURN 'ALERT created with ' || sched;
END;
$$;

-- ALERT 는 SUSPENDED 로 생성된다 — 수동 시험 발송 후 RESUME.
--   WARN: RESUME 전제 = ALERT 소유 역할(GN_DW_ADMIN)에 계정 권한 EXECUTE ALERT.
--      없으면 'Cannot execute alert, EXECUTE ALERT privilege must be granted to owner role' (2026-10-16 실측).
--      ⇒ 부여 위치 = 07 §1 (ACCOUNTADMIN 구간). 이 문서는 GN_DW_ADMIN 으로만 실행한다 — 아래는 확인만.
SHOW GRANTS TO ROLE GN_DW_ADMIN ->> SELECT "privilege" FROM $1 WHERE "privilege" = 'EXECUTE ALERT';   -- 1행 이어야 함
CALL GN_DW.OPS.USP_SEND_DBT_WARN_SPNSR_CLS_DUP();     -- 시험 발송(수신함 확인)
ALTER ALERT GN_DW.OPS.ALERT_DBT_WARN_SPNSR_CLS_DUP RESUME;


-- ------------------------------------------------------------------------------
-- 4. [운영 확인]
-- ------------------------------------------------------------------------------
SHOW ALERTS LIKE 'ALERT_DBT_WARN%' IN SCHEMA GN_DW.OPS;

SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, SQL_ERROR_MESSAGE
FROM TABLE(GN_DW.INFORMATION_SCHEMA.ALERT_HISTORY(
       SCHEDULED_TIME_RANGE_START => DATEADD('day', -6, CURRENT_TIMESTAMP())))
WHERE NAME = 'ALERT_DBT_WARN_SPNSR_CLS_DUP'
ORDER BY SCHEDULED_TIME DESC;

-- 일시 중지 / 재개
-- ALTER ALERT GN_DW.OPS.ALERT_DBT_WARN_SPNSR_CLS_DUP SUSPEND;
-- ALTER ALERT GN_DW.OPS.ALERT_DBT_WARN_SPNSR_CLS_DUP RESUME;


-- ------------------------------------------------------------------------------
-- 5. [RBAC]
-- ------------------------------------------------------------------------------
GRANT USAGE ON PROCEDURE GN_DW.OPS.USP_SEND_DBT_WARN_SPNSR_CLS_DUP() TO ROLE GN_DW_ENGINEER;
GRANT MONITOR ON ALERT GN_DW.OPS.ALERT_DBT_WARN_SPNSR_CLS_DUP TO ROLE GN_DW_ENGINEER;
-- WARN: CREATE OR REPLACE ALERT/PROCEDURE 는 GRANT 를 지운다 — §2·§3 을 다시 실행했으면 위 2줄도 다시 실행.
-- ALERT 소유 역할의 EXECUTE ALERT(계정 권한)는 07 §1 에서 부여된다 — §3 RESUME 앞 확인 쿼리 참조.


-- ------------------------------------------------------------------------------
-- 6. [확장 패턴] 다른 dbt WARN 테스트를 메일로 받으려면
-- ------------------------------------------------------------------------------
--   ① 테스트 config 에 store_failures = true, schema = 'OPS' (이 프로젝트 확립 패턴)
--   ② §2 프로시저를 복제해 요약 SELECT 만 바꾼다
--   ③ §3 ALERT 를 복제해 IF EXISTS 대상 테이블만 바꾼다
--   수신자는 늘 07 §3-1 변수 하나로 관리한다.


-- ------------------------------------------------------------------------------
-- 7. [ALERT] 정기 dbt build Task("daily") 실패 → PIPELINE_ADMIN 메일 [2026-10-27 · A8-10]
-- ------------------------------------------------------------------------------
--   왜: 10-22~10-26 "daily" 실패 5회에 메일이 한 통도 나가지 않았다(85 R92). 공통 프로시저는 SP 내부 예외용이라 Task 실패에 걸려 있지 않았다.
--   왜 Alert: Task ERROR_INTEGRATION 은 SNS·Event Grid·Pub/Sub 전용 — 이메일 통합은 받지 않는다(Snowflake docs tasks-errors).
--   수신자 = 07 §3 변수 PIPELINE_ADMIN_RECIPIENTS (운영계 CHOIH · 개발 환경 TRIALADMIN). 이 문서에는 수신자를 적지 않는다.
--   WARN: category 는 반드시 'PIPELINE_ADMIN' — 07 §4 2026-10-27 판 이전 프로시저는 모르는 값이면 활성 수신자 전원에게 보낸다.
--   전제: 10_dbt_pipeline/03_create_daily_task.sql 로 GN_DW.OPS."daily" 실재 (개발 환경에 없으면 Alert 는 늘 CONDITION_FALSE)
CREATE OR REPLACE ALERT GN_DW.OPS.ALERT_DAILY_TASK_FAILED
  WAREHOUSE = GN_DW_ETL_WH
  SCHEDULE = 'USING CRON 30 6-23 * * * Asia/Seoul'
  COMMENT = '"daily" Task 실패 → 07 PIPELINE_ADMIN 수신자 메일 (09 §7 · A8-10)'
  IF (EXISTS (
    SELECT SCHEDULED_TIME, COMPLETED_TIME, ERROR_MESSAGE
    FROM TABLE(GN_DW.INFORMATION_SCHEMA.TASK_HISTORY(
           TASK_NAME => 'daily',
           SCHEDULED_TIME_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP()),
           ERROR_ONLY => TRUE))
    WHERE DATABASE_NAME = 'GN_DW' AND SCHEMA_NAME = 'OPS'
      AND COMPLETED_TIME >  COALESCE(SNOWFLAKE.ALERT.LAST_SUCCESSFUL_SCHEDULED_TIME(), DATEADD('hour', -1, CURRENT_TIMESTAMP()))
      AND COMPLETED_TIME <= SNOWFLAKE.ALERT.SCHEDULED_TIME()
  ))
  THEN
  EXECUTE IMMEDIATE $$
  DECLARE
    v_summary STRING;
    v_detail  STRING;
  BEGIN
    SELECT 'GN_DW.OPS."daily" 실패 ' || COUNT(*) || '건 · 마지막 ' || TO_VARCHAR(MAX(COMPLETED_TIME), 'YYYY-MM-DD HH24:MI'),
           LEFT(LISTAGG(TO_VARCHAR(SCHEDULED_TIME, 'MM-DD HH24:MI') || ' ' || ERROR_MESSAGE, '\n'), 4000)
      INTO :v_summary, :v_detail
      FROM TABLE(RESULT_SCAN(SNOWFLAKE.ALERT.GET_CONDITION_QUERY_UUID()));
    CALL GN_DW.OPS.USP_SEND_PIPELINE_ERROR_ALERT('daily', :v_summary, :v_detail, 'PIPELINE_ADMIN');
  END;
  $$;

-- 확인: PIPELINE_ADMIN 수신자 = 1명(운영 CHOIH / 개발 TRIALADMIN)
SELECT USER_NAME, IS_PIPELINE_ADMIN_YN FROM GN_DW.OPS.ALERT_RECIPIENT_CONFIG WHERE IS_ACTIVE_YN = 'Y' AND IS_PIPELINE_ADMIN_YN = 'Y';
-- 시험 발송 — 기대: SUCCESS: Alert sent to [<수신자 1명>] · 수신함 확인 후 RESUME
CALL GN_DW.OPS.USP_SEND_PIPELINE_ERROR_ALERT('daily', '[테스트] daily 실패 알림 경로 확인(09 §7)', '실제 장애 아님', 'PIPELINE_ADMIN');
ALTER ALERT GN_DW.OPS.ALERT_DAILY_TASK_FAILED RESUME;
GRANT MONITOR ON ALERT GN_DW.OPS.ALERT_DAILY_TASK_FAILED TO ROLE GN_DW_ENGINEER;

-- 운영 확인(다음날 · 평소 CONDITION_FALSE · 실패일 TRIGGERED)
SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, SQL_ERROR_MESSAGE
FROM TABLE(GN_DW.INFORMATION_SCHEMA.ALERT_HISTORY(
       SCHEDULED_TIME_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP()),
       ALERT_NAME => 'ALERT_DAILY_TASK_FAILED'))
ORDER BY SCHEDULED_TIME DESC;
-- ALTER ALERT GN_DW.OPS.ALERT_DAILY_TASK_FAILED SUSPEND;
