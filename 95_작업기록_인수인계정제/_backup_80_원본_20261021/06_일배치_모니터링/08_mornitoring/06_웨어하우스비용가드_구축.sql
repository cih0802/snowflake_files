-- =====================================================================
-- 웨어하우스 비용 가드 구축 (총량 차단 + 쿼리 시간 제한 + 사용자별 관찰)
--   대상 계정 : ad50130 (TRIALADMIN)
--   구축일    : 2026-08-13
--   실행 역할 : ACCOUNTADMIN
--   대상 WH   : ML_WH (LARGE) — ML 학습/추론 전용
-- ---------------------------------------------------------------------
-- 05_AI비용가드_구축.sql 의 자매 문서다. 05 는 AI 도메인(CoCo·CoWork·Agent·
-- AI 함수)을 다루고, 본 파일은 웨어하우스 컴퓨트를 다룬다.
--   ⚠️ 하나의 quota 에 WAREHOUSE 와 AI 도메인을 섞을 수 없다(측정단위 상이).
--      따라서 05 의 AI_USER_QUOTA 와 본 파일의 ML_WH_USER_QUOTA 는 별도 인스턴스다.
-- ---------------------------------------------------------------------
-- 오브젝트 배치 원칙 (GN_DW 설계의도 기준)
--   GN_DW.OPS      = 운영/비용 객체 → quota 인스턴스, 관찰 뷰, 감사 로그, 프로시저
--   GN_DW.SECURITY = 거버넌스 정책 객체 → 적용대상 판별 TAG
--   Resource Monitor 는 계정 레벨 객체라 스키마에 속하지 않는다.
-- ---------------------------------------------------------------------
-- 본 파일의 모든 구문은 2026-08-13 세션에서 실제 실행·검증되었다.
-- 주석으로 남긴 구문(-- [옵션])은 의도적으로 미적용 상태다.
-- Co-authored with CoCo
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;


------------------------------------------------------------
-- 0. 웨어하우스 비용 제어 수단의 정리
------------------------------------------------------------
--   웨어하우스에 쓸 수 있는 제어 수단은 3개이며 역할이 다르다.
--
--   (1) Resource Monitor        → 웨어하우스 총 크레딧 상한. 유일한 "내장 하드 차단".
--                                 한도 도달 시 Snowflake 가 직접 SUSPEND 한다.
--                                 단, 사용자를 구분하지 못한다(전원 동시 차단).
--   (2) STATEMENT_TIMEOUT       → 개별 쿼리 실행시간 상한. 러너웨이 쿼리 방지.
--                                 크레딧 총량이 아니라 "단위 쿼리"를 막는다.
--   (3) Per-user quota(WAREHOUSE) → 사용자별 소비 추적 + 알림 + Custom Action.
--                                 ★내장 Block 은 웨어하우스에 적용되지 않는다(1번 참조).
--
--   ⚠️ 05 파일의 내장 Block(SET_BLOCK_ENFORCEMENT_ENABLED)은 AI 도메인 전용이다.
--      공식문서 명시: "Block enforcement supports only the AI domains... Warehouse
--      spend can be tracked in a separate quota, but block enforcement doesn't
--      apply to warehouses."
--   ⚠️⚠️ 실측 함정 (2026-08-13): 웨어하우스 quota 에서 SET_BLOCK_ENFORCEMENT_ENABLED(TRUE)
--      를 호출하면 오류 없이 "Block enforcement has been enabled." 를 반환한다.
--      즉 시스템이 막아주지 않으므로, 설정값만 보고 "차단이 걸렸다"고 오인할 수 있다.
--      웨어하우스 하드 차단은 반드시 Resource Monitor 로 구성할 것.


------------------------------------------------------------
-- 1. Resource Monitor 생성 — 총량 하드 차단 (제1방어선)
------------------------------------------------------------
--   FREQUENCY : DAILY | WEEKLY | MONTHLY | YEARLY | NEVER
--   액션 개수 제한: SUSPEND 1개, SUSPEND_IMMEDIATE 1개, NOTIFY 최대 5개.
--   ⚠️ 액션을 하나도 정의하지 않으면 한도 도달 시 아무 일도 일어나지 않는다.
--   ⚠️ ALTER RESOURCE MONITOR 의 TRIGGERS 는 가산되지 않는다(전체 교체).
--      CREDIT_QUOTA 만 바꾸려 해도 TRIGGERS 를 다시 전부 명시해야 기존 액션이 유지된다.
--   ⚠️ used_credits 는 웨어하우스 크레딧 + 이를 지원한 cloud services 크레딧의 합이다.
--      실측: ML_WH 를 SUSPENDED 로만 만든 직후 이미 0.20 크레딧이 집계되었다.
--      (cloud services 의 일 10% 무료 조정은 반영되지 않는다 — 청구되지 않는 소비도 계산됨)
--   ⚠️ NOTIFY_USERS 의 이메일은 사전 검증(verified)되어야 실제 발송된다.
CREATE OR REPLACE RESOURCE MONITOR ML_WH_MONITOR
  WITH CREDIT_QUOTA = 100                -- 월 100 크레딧
       FREQUENCY = MONTHLY
       START_TIMESTAMP = IMMEDIATELY
       NOTIFY_USERS = (TRIALADMIN)
  TRIGGERS
    ON  50 PERCENT DO NOTIFY             -- 조기 경보
    ON  80 PERCENT DO NOTIFY             -- 임박 경보
    ON 100 PERCENT DO SUSPEND            -- 실행 중 쿼리 완료 후 정지
    ON 110 PERCENT DO SUSPEND_IMMEDIATE; -- 실행 중 쿼리 취소하고 즉시 정지

--   ⚠️ SUSPEND 로 정지된 웨어하우스는 AUTO_RESUME 이 TRUE 라도 재개되지 않는다.
--      아래 중 하나가 충족되어야 한다: 다음 주기 시작 / CREDIT_QUOTA 상향 /
--      트리거 임계 상향 / 모니터 할당 해제 / 모니터 DROP.


------------------------------------------------------------
-- 2. ML 웨어하우스 생성 — Large + 타임아웃 + 모니터 연결
------------------------------------------------------------
--   ⚠️ LARGE 는 X-Small 의 8배 크레딧/시간을 소비한다. AUTO_SUSPEND 를 짧게 둔다.
--   ⚠️ INITIALLY_SUSPENDED = TRUE 로 생성해야 생성 즉시 과금이 시작되지 않는다.
--   ⚠️ AUTO_RESUME = TRUE 이면 이 웨어하우스로 라우팅된 쿼리 한 건이 Large 를 깨운다.
--      의도치 않은 기동을 막으려면 RBAC 로 USAGE 를 제한할 것(7번).
--   ⚠️ 한 웨어하우스는 계정 레벨 외에 단 하나의 Resource Monitor 에만 할당된다.
CREATE WAREHOUSE IF NOT EXISTS ML_WH
  WAREHOUSE_SIZE = 'LARGE'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND = 60                          -- 60초 유휴 시 정지
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  RESOURCE_MONITOR = ML_WH_MONITOR
  STATEMENT_TIMEOUT_IN_SECONDS = 900         -- 쿼리 15분 제한
  STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300  -- 큐 대기 5분 제한
  COMMENT = 'ML 학습/추론 전용. Large. 비용가드: ML_WH_MONITOR(월100cr) + 쿼리 15분 제한';

--   기존 웨어하우스에 사후 적용할 때
-- ALTER WAREHOUSE ML_WH SET RESOURCE_MONITOR = ML_WH_MONITOR;
-- ALTER WAREHOUSE ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
-- ALTER WAREHOUSE ML_WH SET STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300;


------------------------------------------------------------
-- 3. 타임아웃 파라미터의 적용 규칙
------------------------------------------------------------
--   STATEMENT_TIMEOUT_IN_SECONDS        기본 172800(48h). 0 이면 604800(7일)이 강제된다.
--   STATEMENT_QUEUED_TIMEOUT_IN_SECONDS 기본 0(비활성).
--
--   설정 가능 레벨: ACCOUNT / USER / SESSION / WAREHOUSE
--   ⚠️ 계층 덮어쓰기가 아니라 "모든 레벨 중 가장 작은 유효값"이 적용된다.
--      ⇒ 웨어하우스에 900 을 걸면 사용자가 ALTER SESSION 으로 값을 키워도 900 이 우선한다.
--         이것이 웨어하우스 레벨에 거는 이유다(사용자 우회 불가).
--
--   실측 검증 (2026-08-13, SHOW PARAMETERS ... IN WAREHOUSE ML_WH):
--      STATEMENT_TIMEOUT_IN_SECONDS        value=900 default=172800 level=WAREHOUSE
--      STATEMENT_QUEUED_TIMEOUT_IN_SECONDS value=300 default=0      level=WAREHOUSE

SHOW PARAMETERS LIKE 'STATEMENT%TIMEOUT%' IN WAREHOUSE ML_WH;

--   ML 워크로드는 장시간 학습이 정상일 수 있다. 15분이 과하게 짧다면 세분화한다.
-- ALTER WAREHOUSE ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 3600;  -- 1시간
-- ALTER WAREHOUSE ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 7200;  -- 2시간


------------------------------------------------------------
-- 4. 적용대상 판별 TAG (GN_DW.SECURITY)
------------------------------------------------------------
--   quota 기본 스코프는 "계정 전체 사용자"(ALL_USERS)다. 태그로 좁힌다.
--   태그가 없는 사용자는 스코프에서 제외된다.
--   ⚠️ 05 의 AI_COST_SCOPE 와 별도 태그를 쓴다. AI 한도 대상과 웨어하우스 한도 대상이
--      항상 같지는 않기 때문이다(예: ML 엔지니어는 WH 대상, 분석가는 AI 대상).
CREATE TAG IF NOT EXISTS GN_DW.SECURITY.WH_COST_SCOPE
  ALLOWED_VALUES 'GOVERNED', 'EXEMPT'
  COMMENT = '웨어하우스 비용 quota 적용 대상 구분. GOVERNED=사용자별 한도 적용, EXEMPT=제외(관리자·서비스계정). 미부여 사용자는 quota 스코프에서 제외됨.';

--   대상 사용자 등록
-- ALTER USER <username> SET TAG GN_DW.SECURITY.WH_COST_SCOPE = 'GOVERNED';
--
--   TRIALADMIN 은 의도적으로 태그를 부여하지 않는다(= 제외).
--   ⚠️ 태그를 부여하지 않으면 한도도 걸리지 않는다. 사용자 추가 시 함께 수행할 것.
--      자동화는 SCIM 의 snowflakeTags 속성 사용.


------------------------------------------------------------
-- 5. Per-user quota 인스턴스 생성 (GN_DW.OPS)
------------------------------------------------------------
--   Preview - Open. SNOWFLAKE.CORE.QUOTA 클래스 인스턴스다.
--   ⚠️ only_compile(구문검증) 미지원. IF NOT EXISTS 미지원 → 재실행 시 이 구문만 실패한다.
--      전체 재실행 시 5번을 건너뛰거나 11번 롤백을 먼저 수행할 것.
CREATE SNOWFLAKE.CORE.QUOTA GN_DW.OPS.ML_WH_USER_QUOTA();


------------------------------------------------------------
-- 6. 감시 대상 웨어하우스 등록
------------------------------------------------------------
--   WAREHOUSE 도메인은 웨어하우스 metering + query acceleration 비용을 포함한다.
--   ⚠️ AI 도메인처럼 도메인명만 넘기는 형태가 아니라, 객체 참조를 함께 넘긴다.
--   ⚠️ SYSTEM$SHOW_BUDGET_SHARED_RESOURCE_CANDIDATES 로는 웨어하우스를 조회할 수 없다.
--      실측: SELECT SYSTEM$SHOW_BUDGET_SHARED_RESOURCE_CANDIDATES('WAREHOUSE')
--            → "Invalid domain: WAREHOUSE". 이 함수는 AI 도메인 전용이다.
--            웨어하우스 목록은 SHOW WAREHOUSES 로 확인할 것.
CALL GN_DW.OPS.ML_WH_USER_QUOTA!ADD_SHARED_RESOURCE(
  'WAREHOUSE',
  (SELECT SYSTEM$REFERENCE('WAREHOUSE', 'ML_WH')));

--   여러 웨어하우스를 한 quota 로 묶을 때는 반복 호출한다.
-- CALL GN_DW.OPS.ML_WH_USER_QUOTA!ADD_SHARED_RESOURCE(
--   'WAREHOUSE', (SELECT SYSTEM$REFERENCE('WAREHOUSE', 'COMPUTE_WH')));


------------------------------------------------------------
-- 7. 스코프 지정 — GOVERNED 태그 보유자만
------------------------------------------------------------
--   OPERATION_MODE: 'UNION'(태그 하나라도 일치) | 'INTERSECTION'(전부 일치)
CALL GN_DW.OPS.ML_WH_USER_QUOTA!SET_USER_TAGS(
  [[(SELECT SYSTEM$REFERENCE('TAG', 'GN_DW.SECURITY.WH_COST_SCOPE', 'SESSION', 'APPLYBUDGET')), 'GOVERNED']],
  'UNION');


------------------------------------------------------------
-- 8. 사용자별 지출 한도  ★현재 미적용 (= 무한대)
------------------------------------------------------------
--   ⚠️ 한도를 설정하지 않으면 알림도 Custom Action 도 발생하지 않는다.
--      공식문서: "No enforcement occurs until a per-user spending limit is set."
--   ⚠️ 한도는 quota 내 모든 사용자에게 동일하게 적용된다(사용자별 차등 불가).
--   ⚠️ 사용자 합산 총액 한도는 지원되지 않는다. 총액은 Resource Monitor 의 몫이다.
--   ⚠️ 주기는 UTC 월력 고정. 커스텀 주기(주간·임의 시작일) 불가.
--
--   [옵션 A] 20 credits/사용자/월 — Large 기준 약 2.5시간 실행분. 보수적.
-- CALL GN_DW.OPS.ML_WH_USER_QUOTA!SET_PER_USER_LIMIT(20);
--
--   [옵션 B] 50 credits/사용자/월 — Large 약 6.25시간. 상시 ML 개발자 1인 기준.
-- CALL GN_DW.OPS.ML_WH_USER_QUOTA!SET_PER_USER_LIMIT(50);
--
--   [옵션] 일 한도 — 일·월은 독립 평가된다(월 한도 내여도 일 한도로 걸릴 수 있다).
-- CALL GN_DW.OPS.ML_WH_USER_QUOTA!SET_PER_USER_LIMIT(5, 'DAILY');
--
--   해제
-- CALL GN_DW.OPS.ML_WH_USER_QUOTA!UNSET_PER_USER_LIMIT('MONTHLY');
-- CALL GN_DW.OPS.ML_WH_USER_QUOTA!UNSET_PER_USER_LIMIT('DAILY');
--
--   ⚠️ SET_BLOCK_ENFORCEMENT_ENABLED 는 호출해도 웨어하우스에 효과가 없다(0번 참조).
--      의도적으로 사용하지 않는다.


------------------------------------------------------------
-- 9. Custom Action — quota 기반 소프트 차단
------------------------------------------------------------
-- 9-1 감사 로그 테이블
CREATE TABLE IF NOT EXISTS GN_DW.OPS.WH_QUOTA_ENFORCEMENT_LOG (
  LOGGED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  WAREHOUSE_NAME STRING,
  OFFENDING_USER STRING,
  ACTION_TAKEN   STRING,
  RESULT         STRING
)
COMMENT = 'ML_WH_USER_QUOTA Custom Action 실행 감사 로그. quota 가 위반 사용자명을 마지막 인자로 전달한다.';

-- 9-2 실행 프로시저
--   ★★ 실측으로 밝혀낸 시그니처 규칙 (2026-08-13) ★★
--   quota 의 ADD_CUSTOM_ACTION 은 프로시저에 "정적 인자 N개 + 위반 사용자명 1개"를
--   전달한다. 즉 프로시저는 N+1 개의 인자를 받아야 한다.
--     - 1인자 프로시저 + ARRAY_CONSTRUCT('ML_WH')  → ARGUMENTS_SIZE_MISMATCH 실패
--     - 2인자 프로시저 + ARRAY_CONSTRUCT('ML_WH')  → 성공
--   마지막 인자로 위반 사용자명이 주입되므로, 누가 초과했는지 로깅할 수 있다.
--   (Budget 의 ADD_CUSTOM_ACTION 은 정적 인자만 전달하므로 규칙이 다르다)
--
--   ⚠️ 프로시저 요건: EXECUTE AS OWNER, 30분 내 완료, OUTPUT 인자 불가,
--      실패 시 1회 재시도되므로 멱등해야 한다.
--   ⚠️ 본문에 문자열 리터럴이 있으면 $$ 로 감싸야 한다(미사용 시 syntax error).
CREATE OR REPLACE PROCEDURE GN_DW.OPS.SP_WH_QUOTA_ACTION(WH_NAME STRING, OFFENDER STRING)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  RESULT_MSG STRING;
BEGIN
  -- 이미 SUSPENDED 인 웨어하우스는 SUSPEND 가 실패한다. 재시도 멱등성을 위해 흡수한다.
  BEGIN
    EXECUTE IMMEDIATE 'ALTER WAREHOUSE IF EXISTS ' || :WH_NAME || ' SUSPEND';
    RESULT_MSG := 'suspended';
  EXCEPTION
    WHEN OTHER THEN
      RESULT_MSG := 'not suspendable: ' || SQLERRM;
  END;

  INSERT INTO GN_DW.OPS.WH_QUOTA_ENFORCEMENT_LOG
    (WAREHOUSE_NAME, OFFENDING_USER, ACTION_TAKEN, RESULT)
  VALUES (:WH_NAME, :OFFENDER, 'SUSPEND_WAREHOUSE', :RESULT_MSG);

  RETURN 'wh=' || :WH_NAME || ' offender=' || :OFFENDER || ' result=' || :RESULT_MSG;
END
$$;

-- 9-3 SNOWFLAKE 애플리케이션에 권한 부여 (필수)
--   ⚠️ CREATE OR REPLACE PROCEDURE 로 프로시저를 갱신하면 USAGE 를 다시 부여해야 한다.
GRANT USAGE ON DATABASE GN_DW TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA GN_DW.OPS TO APPLICATION SNOWFLAKE;
GRANT USAGE ON PROCEDURE GN_DW.OPS.SP_WH_QUOTA_ACTION(STRING, STRING) TO APPLICATION SNOWFLAKE;

-- 9-4 Custom Action 등록
--   SPEND_STRATEGY: 'ACTUAL'(실지출) | 'PROJECTED'(월말 추정). 임계는 월 한도 대비 %.
--   ⚠️ 호출 빈도 제한: PROJECTED 는 1일 1회, ACTUAL 은 1개월 1회까지만 실행된다.
--      ACTUAL 은 월중 한도를 올려도 재실행되지 않는다(다음 주기까지 대기).
CALL GN_DW.OPS.ML_WH_USER_QUOTA!ADD_CUSTOM_ACTION(
  SYSTEM$REFERENCE('PROCEDURE', 'GN_DW.OPS.SP_WH_QUOTA_ACTION(string, string)'),
  ARRAY_CONSTRUCT('ML_WH'),   -- 정적 인자. 뒤에 위반 사용자명이 자동 추가된다.
  'ACTUAL',
  100);

--   ⚠️ 이 액션은 웨어하우스 전체를 정지시킨다. 위반자 1인 때문에 전원이 멈춘다.
--      "위반자만" 막으려면 SUSPEND 대신 해당 사용자의 WH 접근 역할을 회수하도록
--      프로시저를 바꾼다(REVOKE ROLE ... FROM USER :OFFENDER). 단, 다른 역할 경로로
--      USAGE 를 얻고 있지 않은지 사전 확인이 필요하다.
--
--   해제
-- CALL GN_DW.OPS.ML_WH_USER_QUOTA!REMOVE_CUSTOM_ACTIONS();
-- CALL GN_DW.OPS.ML_WH_USER_QUOTA!REMOVE_CUSTOM_ACTIONS(100);


------------------------------------------------------------
-- 10. 관찰용 뷰 (GN_DW.OPS)
------------------------------------------------------------
--   ⚠️ QUERY_ATTRIBUTION_HISTORY 는 "쿼리 실행" 크레딧만 사용자에게 귀속한다.
--      유휴(idle) 시간, 웨어하우스 기동 최소 60초 과금 등은 포함되지 않는다.
--      ⇒ 사용자별 합계 < 웨어하우스 총액. 총액은 WAREHOUSE_METERING_HISTORY 로 본다.
--   ⚠️ CREDITS_USED_QUERY_ACCELERATION 은 NULL 일 수 있어 COALESCE 한다.
CREATE OR REPLACE VIEW GN_DW.OPS.V_WH_SPEND_BY_USER
  COMMENT = '웨어하우스 사용자별 크레딧 귀속 뷰(관찰용). QUERY_ATTRIBUTION_HISTORY 기준이므로 쿼리 실행 크레딧만 포함되며 유휴(idle) 크레딧은 제외된다. 웨어하우스 총액은 WAREHOUSE_METERING_HISTORY 로 별도 확인할 것.'
AS
SELECT warehouse_name,
       user_name,
       start_time::DATE AS usage_date,
       query_id,
       query_tag,
       credits_attributed_compute,
       COALESCE(credits_used_query_acceleration, 0) AS credits_qas,
       credits_attributed_compute + COALESCE(credits_used_query_acceleration, 0) AS credits_total
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY;


------------------------------------------------------------
-- 11. 검증 쿼리 (구축 후 / 정기 점검)
------------------------------------------------------------
-- 11-1 Resource Monitor 상태
--   used_credits / remaining_credits / notify_at / suspend_at 확인
--   실측(2026-08-13): ML_WH_MONITOR quota=100.00 used=0.20 level=WAREHOUSE
SHOW RESOURCE MONITORS;

-- 11-2 웨어하우스 상태·모니터 연결 확인
--   state 가 SUSPENDED 인지, resource_monitor 컬럼이 ML_WH_MONITOR 인지 본다.
SHOW WAREHOUSES LIKE 'ML_WH';

-- 11-3 타임아웃 파라미터 확인
SHOW PARAMETERS LIKE 'STATEMENT%TIMEOUT%' IN WAREHOUSE ML_WH;

-- 11-4 quota 설정 확인
--   PER_USER_LIMIT / PER_USER_LIMIT_DAILY 가 NULL 이면 한도 없음
--   BLOCK_ENFORCEMENT_ENABLED 는 웨어하우스에서 의미가 없다(0번 참조)
--   실측(2026-08-13): QUOTA_ID=7 PER_USER_LIMIT=NULL REFRESH_TIER=TIER_1H BLOCK=FALSE
CALL GN_DW.OPS.ML_WH_USER_QUOTA!GET_CONFIG();

-- 11-5 감시 대상·스코프 확인
--   실측(2026-08-13) 6번 직후: {"shared_resources":[{"domain":"WAREHOUSE","id":81,
--     "name":"ML_WH"}],"user_tags":{"operator":"ALL_USERS","tags":[]}}
--   7번 실행 후에는 user_tags 가 WH_COST_SCOPE=GOVERNED 로 바뀐다.
CALL GN_DW.OPS.ML_WH_USER_QUOTA!GET_QUOTA_SCOPE();

-- 11-6 실제 적용 대상 사용자  ★한도 설정 전 필수
--   0행이면 아무도 한도 적용을 받지 않는다(현재 상태).
CALL GN_DW.OPS.ML_WH_USER_QUOTA!GET_USERS();

-- 11-7 Custom Action 등록 상태와 유효성
--   IS_VALID=FALSE 면 프로시저가 교체되었거나 SNOWFLAKE 앱 권한이 소실된 것이다(9-3 재실행).
CALL GN_DW.OPS.ML_WH_USER_QUOTA!GET_CUSTOM_ACTIONS();
CALL GN_DW.OPS.ML_WH_USER_QUOTA!CONFIRM_CUSTOM_ACTIONS_ACCESS();

-- 11-8 사용자별 웨어하우스 지출 (관찰)
--   실측(2026-08-13): COMPUTE_WH / TRIALADMIN / 2026-08-11 → 0.251373cr / 58쿼리
SELECT warehouse_name, user_name, usage_date,
       ROUND(SUM(credits_total), 6) AS credits,
       COUNT(*)                     AS queries
FROM GN_DW.OPS.V_WH_SPEND_BY_USER
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1, 2, 3
ORDER BY credits DESC;

-- 11-9 웨어하우스 총액 (유휴 포함) — 11-8 과의 차이가 유휴 비용이다
SELECT warehouse_name,
       DATE_TRUNC('day', start_time)::DATE AS usage_date,
       ROUND(SUM(credits_used), 6)         AS credits_total,
       ROUND(SUM(credits_used_compute), 6) AS credits_compute,
       ROUND(SUM(credits_used_cloud_services), 6) AS credits_cloud
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY credits_total DESC;

-- 11-10 quota 자체 집계로 교차검증
CALL GN_DW.OPS.ML_WH_USER_QUOTA!GET_SPENDING_DETAILS_BY_USERS(
       DATEADD('day', -30, CURRENT_DATE()), CURRENT_DATE());

-- 11-11 Custom Action 실행 이력 (자체 감사 로그)
SELECT * FROM GN_DW.OPS.WH_QUOTA_ENFORCEMENT_LOG ORDER BY LOGGED_AT DESC;

-- 11-12 타임아웃으로 취소된 쿼리 탐지
--   ⚠️ error_code 값은 본 계정에서 실제 타임아웃이 발생한 적이 없어 미검증이다.
--      코드 대신 error_message 패턴으로 찾는 편이 안전하다.
SELECT warehouse_name, user_name, start_time,
       total_elapsed_time / 1000 AS elapsed_sec,
       error_code, error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND execution_status = 'FAIL'
  AND (error_message ILIKE '%timeout%' OR error_message ILIKE '%exceeded%')
ORDER BY start_time DESC;


------------------------------------------------------------
-- 12. (선택) RBAC — Large 웨어하우스 기동 자체를 통제
------------------------------------------------------------
--   AUTO_RESUME=TRUE 인 Large 는 쿼리 한 건으로 기동된다. 누가 기동할 수 있는지를 제한한다.
-- CREATE ROLE IF NOT EXISTS GN_ML_USER;
-- GRANT USAGE, OPERATE ON WAREHOUSE ML_WH TO ROLE GN_ML_USER;
-- GRANT ROLE GN_ML_USER TO USER <username>;
--   PUBLIC 에 USAGE 가 열려 있지 않은지 확인
-- SHOW GRANTS ON WAREHOUSE ML_WH;


------------------------------------------------------------
-- 13. 롤백
------------------------------------------------------------
-- CALL GN_DW.OPS.ML_WH_USER_QUOTA!REMOVE_CUSTOM_ACTIONS();
-- DROP SNOWFLAKE.CORE.QUOTA GN_DW.OPS.ML_WH_USER_QUOTA;
-- DROP VIEW      IF EXISTS GN_DW.OPS.V_WH_SPEND_BY_USER;
-- DROP TABLE     IF EXISTS GN_DW.OPS.WH_QUOTA_ENFORCEMENT_LOG;
-- DROP PROCEDURE IF EXISTS GN_DW.OPS.SP_WH_QUOTA_ACTION(STRING, STRING);
-- DROP TAG       IF EXISTS GN_DW.SECURITY.WH_COST_SCOPE;
-- ALTER WAREHOUSE ML_WH UNSET RESOURCE_MONITOR;
-- DROP RESOURCE MONITOR IF EXISTS ML_WH_MONITOR;
-- DROP WAREHOUSE IF EXISTS ML_WH;


-- =====================================================================
-- 현재 상태 요약 (2026-08-13 실측)
--   ML_WH_MONITOR                     생성 완료 · 월100cr · 50/80 NOTIFY · 100 SUSPEND · 110 SUSPEND_IMMEDIATE
--   ML_WH                             생성 완료 · LARGE · SUSPENDED · 모니터 연결 · 타임아웃 900/300
--   GN_DW.SECURITY.WH_COST_SCOPE      생성 완료 · quota 스코프로 연결
--   GN_DW.OPS.ML_WH_USER_QUOTA        생성 완료 · WAREHOUSE 도메인(ML_WH) 감시
--   GN_DW.OPS.SP_WH_QUOTA_ACTION      생성 완료 · SNOWFLAKE 앱 권한 부여 · IS_VALID=TRUE
--   GN_DW.OPS.WH_QUOTA_ENFORCEMENT_LOG 생성 완료 · 0행
--   GN_DW.OPS.V_WH_SPEND_BY_USER      생성 완료 · 관찰 가능
--   Custom Action                     등록 완료 · ACTUAL 100% · 정적인자 ['ML_WH']
--   PER_USER_LIMIT / _DAILY           NULL  (미적용 → Custom Action 도 발동하지 않음)
--   GET_USERS()                       0행   (TRIALADMIN 태그 미부여 = 제외)
--
--   ⇒ 실제 작동 중인 차단: Resource Monitor(총량 100cr) + 쿼리 타임아웃(15분) 2종.
--   ⇒ 사용자별 quota 는 관찰 상태. 활성화 절차: 8번 한도 설정 → 4번 태그 부여
--      → 11-6 대상 확인 → 11-7 액션 유효성 확인.
-- =====================================================================
