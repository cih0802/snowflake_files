-- =====================================================================
-- AI 비용 가드 구축 (사용자 기반 하드 차단 + 관찰)
--   대상 계정 : os09358 (TRIALADMIN)
--   구축일    : 2026-08-12
--   실행 역할 : ACCOUNTADMIN
-- ---------------------------------------------------------------------
-- 오브젝트 배치 원칙 (GN_DW 설계의도 기준)
--   GN_DW.OPS      = 운영/비용 객체 → quota 인스턴스, 관찰 뷰
--                    (기존 GN_DW.OPS.DW_PIPELINE = dbt 프로젝트와 동일 계층)
--   GN_DW.SECURITY = 거버넌스 정책 객체 → 적용대상 판별 TAG
-- ---------------------------------------------------------------------
-- 본 파일의 모든 구문은 2026-08-12 세션에서 실제 실행·검증되었다.
-- 주석으로 남긴 구문(-- [옵션])은 의도적으로 미적용 상태다.
-- Co-authored with CoCo
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;


------------------------------------------------------------
-- 0. 왜 Resource Monitor 가 아니라 Per-user quota 인가
------------------------------------------------------------
--   Resource Monitor 는 웨어하우스 전용이며 서버리스·AI 서비스에는 적용되지 않는다.
--   (공식문서 user-guide/resource-monitors 명시: "Resource monitors work for
--    warehouses only. You can't use a resource monitor to track spending
--    associated with serverless features and AI services.")
--   따라서 CoCo·CoWork·Agent·AI 함수의 하드 차단 수단은 아래 둘뿐이다.
--     (1) Per-user quota  → 사용자별 상한 + 내장 Block  ★본 파일
--     (2) RBAC            → 접근 자체 차단             (07 섹션)
--   Budget 은 알림·커스텀액션 전용이며 그 자체로는 차단하지 않는다.


------------------------------------------------------------
-- 1. 적용대상 판별 TAG (GN_DW.SECURITY)
------------------------------------------------------------
--   quota 의 기본 스코프는 "계정 전체 사용자"다. 그대로 두면 관리자도 차단 대상이 된다.
--   EXCLUDE_USERS('USER', [...]) 로 개별 제외를 시도했으나 Preview 결함으로 실패한다
--   (INVALID_TARGET_TYPE: 허용값으로 'USER' 를 안내하면서 'USER' 를 거부. 2026-08-12 실측).
--   ⇒ 태그 기반 스코프로 구현한다. 태그가 없는 사용자는 스코프에서 제외된다.
CREATE TAG IF NOT EXISTS GN_DW.SECURITY.AI_COST_SCOPE
  ALLOWED_VALUES 'GOVERNED', 'EXEMPT'
  COMMENT = 'AI 비용 quota 적용 대상 구분. GOVERNED=사용자별 한도 적용, EXEMPT=제외(관리자·서비스계정). 미부여 사용자는 quota 스코프에서 제외됨.';

--   신규 사용자를 한도 적용 대상으로 넣을 때:
-- ALTER USER <username> SET TAG GN_DW.SECURITY.AI_COST_SCOPE = 'GOVERNED';
--
--   TRIALADMIN 은 의도적으로 태그를 부여하지 않는다(= 제외).
--   ⚠️ 운영 전환 시 주의: 태그를 부여하지 않으면 한도도 걸리지 않는다.
--      사용자를 추가할 때마다 위 ALTER USER 를 함께 수행해야 가드가 실제로 작동한다.
--      자동화가 필요하면 SCIM 의 snowflakeTags 속성으로 프로비저닝 시 자동 부여한다.


------------------------------------------------------------
-- 2. Per-user quota 인스턴스 생성 (GN_DW.OPS)
------------------------------------------------------------
--   Preview - Open (모든 계정 사용 가능). SNOWFLAKE.CORE.QUOTA 클래스 인스턴스다.
--   ⚠️ CREATE ... QUOTA 는 only_compile(구문검증)을 지원하지 않는다. 실제 생성만 가능.
--   ⚠️ IF NOT EXISTS 를 지원하지 않으므로 이 구문만은 재실행 시 실패한다.
--      본 파일 전체를 다시 돌릴 때는 2번을 건너뛰거나 11번 롤백을 먼저 수행할 것.
--      (3~8번은 멱등하다: ADD_SHARED_RESOURCE 중복 호출·CREATE OR REPLACE VIEW·CREATE TAG IF NOT EXISTS)
CREATE SNOWFLAKE.CORE.QUOTA GN_DW.OPS.AI_USER_QUOTA();


------------------------------------------------------------
-- 3. 감시 도메인 등록
------------------------------------------------------------
--   ⚠️ 한 quota 에 WAREHOUSE 와 AI 도메인을 섞을 수 없다.
--      측정단위가 다르다(credits vs AI credits). 웨어하우스는 별도 quota 로 분리.
--   ⚠️ Block 은 AI 도메인에만 적용된다. WAREHOUSE 는 추적만 되고 차단되지 않는다.
CALL GN_DW.OPS.AI_USER_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');            -- AI_COMPLETE, AI_CLASSIFY 등
CALL GN_DW.OPS.AI_USER_QUOTA!ADD_SHARED_RESOURCE('CORTEX CODE');            -- CoCo (CLI + Snowsight + Desktop)
CALL GN_DW.OPS.AI_USER_QUOTA!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE'); -- CoWork
CALL GN_DW.OPS.AI_USER_QUOTA!ADD_SHARED_RESOURCE('CORTEX AGENT');           -- Cortex Agents

--   특정 객체만 좁혀 감시하려면 2번째 인자에 참조를 전달한다.
-- CALL GN_DW.OPS.AI_USER_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_CLASSIFY');
-- CALL GN_DW.OPS.AI_USER_QUOTA!ADD_SHARED_RESOURCE('CORTEX AGENT',
--        (SELECT SYSTEM$REFERENCE('CORTEX AGENT', 'myagent')));


------------------------------------------------------------
-- 4. 스코프 지정 — GOVERNED 태그 보유자만
------------------------------------------------------------
--   OPERATION_MODE: 'UNION'(태그 하나라도 일치) | 'INTERSECTION'(전부 일치)
CALL GN_DW.OPS.AI_USER_QUOTA!SET_USER_TAGS(
  [[(SELECT SYSTEM$REFERENCE('TAG', 'GN_DW.SECURITY.AI_COST_SCOPE', 'SESSION', 'APPLYBUDGET')), 'GOVERNED']],
  'UNION');


------------------------------------------------------------
-- 5. 사용자별 지출 한도  ★현재 미적용 (= 무한대)
------------------------------------------------------------
--   ⚠️ 한도를 설정하지 않으면 enforcement 는 전혀 발생하지 않는다.
--      공식문서: "No enforcement occurs until a per-user spending limit is set."
--      본 계정은 관찰 단계이므로 의도적으로 NULL 로 둔다.
--
--   실측 근거 (2026-08-12, SNOWFLAKE_COCO_USAGE_HISTORY):
--      TRIALADMIN 1인이 CoCo Snowsight 로 하루 37요청 / 5.50 credits 소비.
--      요청당 약 0.15 credits.
--
--   [옵션 A] 30 credits/사용자/월 — 보수적. 토이모델 생산이 아닌 일반 사용 기준.
--            하루 3.3 credits 속도면 약 9일치.
-- CALL GN_DW.OPS.AI_USER_QUOTA!SET_PER_USER_LIMIT(30);
--
--   [옵션 B] 100 credits/사용자/월 — 상시 개발 사용자 1인 실사용량 기준(3.3/일 × 30일).
-- CALL GN_DW.OPS.AI_USER_QUOTA!SET_PER_USER_LIMIT(100);
--
--   [옵션 C] 300 credits/사용자/월 — 여유 한도. 차단은 사실상 이상징후
--            (러너웨이 쿼리·대용량 AI 함수) 전용 안전장치로만 동작.
-- CALL GN_DW.OPS.AI_USER_QUOTA!SET_PER_USER_LIMIT(300);
--
--   [옵션] 일 한도 — 2번째 인자에 CYCLE 을 준다. 일·월은 독립 평가된다.
--            (월 한도 내에 있어도 일 한도로 차단될 수 있고, 그 역도 성립)
-- CALL GN_DW.OPS.AI_USER_QUOTA!SET_PER_USER_LIMIT(5,  'DAILY');   -- 실측 3.3/일 대비 약간 여유
-- CALL GN_DW.OPS.AI_USER_QUOTA!SET_PER_USER_LIMIT(10, 'DAILY');   -- 집중 작업일 허용, 폭증만 차단
--
--   해제
-- CALL GN_DW.OPS.AI_USER_QUOTA!UNSET_PER_USER_LIMIT('MONTHLY');
-- CALL GN_DW.OPS.AI_USER_QUOTA!UNSET_PER_USER_LIMIT('DAILY');


------------------------------------------------------------
-- 6. 내장 Block 활성화  ★현재 비활성 (FALSE)
------------------------------------------------------------
--   한도 도달 시 Snowflake 가 신규 AI 요청을 자동 차단한다. 사용자 코드 불필요.
--   사이클(일/월) 리셋 또는 한도 상향 시 자동 해제된다.
--
--   ⚠️ 활성화 전 반드시 확인할 것
--     - 4번 태그 스코프가 의도대로 좁혀졌는지 (GET_USERS() 로 실제 대상 확인)
--     - 관리자 계정이 대상에 없는지 → 있으면 본인이 CoCo 에서 잠긴다
--   ⚠️ 차단은 요청시점 평가가 아니라 소비 후 수 분 내 평가다. 따라서 한도를 넘겨
--      약간 초과(overshoot)한 뒤 차단된다. 대용량 단일 AI 함수는 초과폭이 클 수 있다.
--   ⚠️ 일·월 사이클은 UTC 자정 리셋. 경계 직전 사용자는 리셋 전 한도 + 리셋 후 한도를
--      연속 소비할 수 있다.
--
-- CALL GN_DW.OPS.AI_USER_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);
--   2번째 인자는 차단 시 사용자 이메일 발송 여부
-- CALL GN_DW.OPS.AI_USER_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE, TRUE);


------------------------------------------------------------
-- 7. (선택) 알림 — 한도 도달 전 경고
------------------------------------------------------------
--   SPEND_STRATEGY: 'ACTUAL'(실지출) | 'PROJECTED'(월말 추정치)
--   THRESHOLD     : 월 한도에 대한 백분율
-- CALL GN_DW.OPS.AI_USER_QUOTA!SET_ADMIN_EMAILS('admin@example.com');
-- CALL GN_DW.OPS.AI_USER_QUOTA!ADD_NOTIFICATION_THRESHOLD(80, 'PROJECTED', TRUE);
-- CALL GN_DW.OPS.AI_USER_QUOTA!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL',   TRUE);
-- CALL GN_DW.OPS.AI_USER_QUOTA!GET_NOTIFICATION_THRESHOLDS();
--   ⚠️ 이메일은 사전 검증(verified)된 주소만 발송된다.


------------------------------------------------------------
-- 8. 관찰용 통합 뷰 (GN_DW.OPS)
------------------------------------------------------------
--   ⚠️ 중복 합산 함정: CORTEX_CODE_{CLI,SNOWSIGHT,DESKTOP}_USAGE_HISTORY 는
--      SNOWFLAKE_COCO_USAGE_HISTORY 의 인터페이스별 부분집합이다.
--      2026-08-12 실측: COCO 34행/4.4743cr == CODE_SNOWSIGHT 34행/4.4743cr
--      ⇒ 함께 더하면 2배로 과대집계된다. 통합뷰만 쓴다.
--   ⚠️ CORTEX_AISQL_USAGE_HISTORY 에는 USER_NAME 이 없다(USER_ID 만).
--      ACCOUNT_USAGE.USERS 조인으로 해석해야 한다.
--   ⚠️ CORTEX_ANALYST_USAGE_HISTORY 는 컬럼명이 USERNAME / CREDITS 로 다르다.
CREATE OR REPLACE VIEW GN_DW.OPS.V_AI_SPEND_BY_USER
  COMMENT = 'AI 도메인별 사용자별 크레딧 소비 통합 뷰(관찰용). 각 도메인의 정본 뷰만 사용하므로 도메인 간 합산 안전. CORTEX_CODE_{CLI,SNOWSIGHT,DESKTOP}_USAGE_HISTORY 는 SNOWFLAKE_COCO_USAGE_HISTORY 의 부분집합이라 제외.'
AS
-- CoCo (Cortex Code) : 전 인터페이스 통합 정본
SELECT 'CORTEX CODE'            AS domain,
       c.interface              AS detail,
       c.user_name              AS user_name,
       c.usage_time::DATE       AS usage_date,
       c.token_credits          AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY c
UNION ALL
-- CoWork (Snowflake Intelligence)
SELECT 'SNOWFLAKE INTELLIGENCE', i.agent_name, i.user_name, i.start_time::DATE, i.token_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY i
UNION ALL
-- Cortex Agents
SELECT 'CORTEX AGENT', a.agent_name, a.user_name, a.start_time::DATE, a.token_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY a
UNION ALL
-- AI 함수(AISQL) : USER_NAME 컬럼이 없어 USERS 뷰로 해석
SELECT 'AI FUNCTION', q.function_name, u.name, q.usage_time::DATE, q.token_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY q
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON u.user_id = q.user_id
UNION ALL
-- Cortex Analyst : 컬럼명이 USERNAME / CREDITS
SELECT 'CORTEX ANALYST', NULL, n.username, n.start_time::DATE, n.credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY n;


------------------------------------------------------------
-- 9. 검증 쿼리 (구축 후 / 정기 점검)
------------------------------------------------------------
-- 9-1 현재 설정 확인
--   PER_USER_LIMIT / PER_USER_LIMIT_DAILY 가 NULL 이면 한도 없음(=차단 없음)
--   BLOCK_ENFORCEMENT_ENABLED 가 FALSE 면 차단 비활성
--   REFRESH_TIER 기본값은 TIER_1H
CALL GN_DW.OPS.AI_USER_QUOTA!GET_CONFIG();

-- 9-2 감시 도메인·스코프 확인
CALL GN_DW.OPS.AI_USER_QUOTA!GET_QUOTA_SCOPE();

-- 9-3 실제 적용 대상 사용자 확인  ★차단 활성화 전 필수
--     0행이면 아무도 한도 적용을 받지 않는다(현재 상태).
CALL GN_DW.OPS.AI_USER_QUOTA!GET_USERS();

-- 9-4 사용자별 AI 지출 (관찰)
SELECT domain, user_name, usage_date,
       ROUND(SUM(credits), 4) AS credits,
       COUNT(*)               AS events
FROM GN_DW.OPS.V_AI_SPEND_BY_USER
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1, 2, 3
ORDER BY credits DESC;

-- 9-5 quota 자체 집계로 교차검증
CALL GN_DW.OPS.AI_USER_QUOTA!GET_SPENDING_DETAILS_BY_USERS(
       DATEADD('day', -30, CURRENT_DATE()), CURRENT_DATE());

-- 9-6 차단 이력·현재 차단자
CALL GN_DW.OPS.AI_USER_QUOTA!GET_ACTIVE_BLOCKS();
CALL GN_DW.OPS.AI_USER_QUOTA!GET_ENFORCEMENT_HISTORY(
       DATEADD('day', -30, CURRENT_DATE()), CURRENT_DATE());

-- 9-7 계정 전체 AI 크레딧 (metering 기준)
--     ⚠️ service_type 실측값은 SNOWFLAKE_COCO_SNOWSIGHT 다.
--        구 문서의 CORTEX_CODE_SNOWSIGHT 는 metering 의 service_type 이 아니다.
SELECT service_type, ROUND(SUM(credits_used), 4) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1
ORDER BY credits DESC;


------------------------------------------------------------
-- 10. (선택) RBAC — 접근 자체 차단 (최후 방어선)
------------------------------------------------------------
--   quota 는 "얼마나" 를 막고, RBAC 는 "누가" 를 막는다.
--   SNOWFLAKE.CORTEX_USER 가 PUBLIC 에 부여되어 있으면 전 사용자가 LLM 함수를 쓸 수 있다.
--   ⚠️ 회수는 조직 전체에 영향을 준다. 사전 공지·영향도 검토 후 적용할 것.
-- SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.CORTEX_USER;
-- CREATE ROLE IF NOT EXISTS GN_AI_USER;
-- GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE GN_AI_USER;
-- REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;
-- GRANT ROLE GN_AI_USER TO USER <username>;


------------------------------------------------------------
-- 11. 롤백
------------------------------------------------------------
-- DROP SNOWFLAKE.CORE.QUOTA GN_DW.OPS.AI_USER_QUOTA;
-- DROP VIEW  IF EXISTS GN_DW.OPS.V_AI_SPEND_BY_USER;
-- DROP TAG   IF EXISTS GN_DW.SECURITY.AI_COST_SCOPE;


-- =====================================================================
-- 현재 상태 요약 (2026-08-12 실측)
--   GN_DW.OPS.AI_USER_QUOTA        생성 완료 · 4개 AI 도메인 감시
--   GN_DW.SECURITY.AI_COST_SCOPE   생성 완료 · quota 스코프로 연결
--   GN_DW.OPS.V_AI_SPEND_BY_USER   생성 완료 · 관찰 가능
--   PER_USER_LIMIT                 NULL  (무한대 — 미적용)
--   PER_USER_LIMIT_DAILY           NULL  (미적용)
--   BLOCK_ENFORCEMENT_ENABLED      FALSE (미적용)
--   GET_USERS()                    0행   (TRIALADMIN 태그 미부여 = 제외)
--   ⇒ 현재는 순수 관찰 상태이며 어떤 사용자도 차단되지 않는다.
--   ⇒ 차단 전환 절차: 5번 한도 설정 → 1번 태그 부여 → 9-3 대상 확인 → 6번 활성화
-- =====================================================================
