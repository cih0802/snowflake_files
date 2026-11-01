-- 운영계 · AGENT_MARKETING 에 MONITOR(또는 OWNERSHIP) 권한이 있는 역할로 실행
-- ① 이벤트 종류와 속성 키 확인
SELECT RECORD:name::STRING AS event_name,
       ARRAY_AGG(DISTINCT k.value::STRING) AS attr_keys,
       COUNT(*) AS cnt
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS('GN_DW', 'SERVING', 'AGENT_MARKETING', 'CORTEX AGENT')) e,
     LATERAL FLATTEN(INPUT => OBJECT_KEYS(e.RECORD_ATTRIBUTES)) k
WHERE e.TIMESTAMP >= DATEADD(DAY, -14, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 3 DESC;

-- ② 피드백 4건 질문 원문 추출(질문·응답·SQL 이 RECORD_ATTRIBUTES 안에 들어 있다)
SELECT e.TIMESTAMP,
       e.TRACE:trace_id::STRING AS trace_id,
       e.RECORD:name::STRING AS event_name,
       e.RECORD_ATTRIBUTES,
       e.VALUE
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS('GN_DW', 'SERVING', 'AGENT_MARKETING', 'CORTEX AGENT')) e
WHERE e.TIMESTAMP >= DATEADD(DAY, -14, CURRENT_TIMESTAMP())
  AND e.TRACE:trace_id::STRING IN (
        SELECT DISTINCT TRACE:trace_id::STRING
        FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS('GN_DW', 'SERVING', 'AGENT_MARKETING', 'CORTEX AGENT'))
        WHERE TIMESTAMP >= DATEADD(DAY, -1, CURRENT_TIMESTAMP())
          AND (RECORD_ATTRIBUTES::STRING ILIKE '%광고비%'
            OR RECORD_ATTRIBUTES::STRING ILIKE '%제작비%'
            OR RECORD_ATTRIBUTES::STRING ILIKE '%캠페인명%'
            OR RECORD_ATTRIBUTES::STRING ILIKE '%LTV%'))
ORDER BY trace_id, e.TIMESTAMP;

-- ③ 질문·답변 본문: RECORD 열 포함(첫 쿼리에서 빠졌던 열)
SELECT e.TIMESTAMP,
       e.TRACE:trace_id::STRING AS trace_id,
       e.RECORD:name::STRING   AS event_name,
       e.RECORD,
       e.VALUE
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS('GN_DW', 'SERVING', 'AGENT_MARKETING', 'CORTEX AGENT')) e
WHERE e.TIMESTAMP >= DATEADD(DAY, -14, CURRENT_TIMESTAMP())
  AND e.RECORD:name::STRING IN ('CORTEX_AGENT_REQUEST', 'AgentV2RequestResponseInfo',
                                'ReasoningAgentStepResponseGeneration-0', 'ReasoningAgentStepResponseGeneration-1',
                                'ReasoningAgentStepResponseGeneration-2', 'ReasoningAgentStepResponseGeneration-3')
  AND LEFT(e.TRACE:trace_id::STRING, 8) IN ('00000000', '18636b21', '3baf1c8f', '856a8def', '8912d6b2',
                                            'a5281d2b', '816abbbb', '3d3494cb', '3295c80c', '78609abb')
ORDER BY trace_id, e.TIMESTAMP;

-- ④ Agent 가 실행한 SQL 원문(CSV 의 sql_execution.query_id 로 조회)
SELECT QUERY_ID, START_TIME, EXECUTION_STATUS, ERROR_MESSAGE, QUERY_TEXT
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(DAY, -3, CURRENT_TIMESTAMP())
  AND QUERY_ID IN ('01c80653-0002-4396-0001-72de08ac7fee', '01c80653-0002-42f2-0001-72de08ac88f2',
                   '01c806c7-0002-42f2-0001-72de08b26f1e', '01c806c7-0002-42f2-0001-72de08b26ff6',
                   '01c805cf-0002-42f2-0001-72de08a67772', '01c805cf-0002-4396-0001-72de08a6845a',
                   '01c805ca-0002-4404-0001-72de08a60e8e', '01c805d2-0002-4396-0001-72de08a68cd2',
                   '01c80625-0002-4396-0001-72de08aa4eae', '01c806c0-0002-4404-0001-72de08b22602',
                   '01c806c0-0002-4404-0001-72de08b22606', '01c806c0-0002-42f2-0001-72de08b24046',
                   '01c806de-0002-42f2-0001-72de08b438aa', '01c806de-0002-42f2-0001-72de08b43aca',
                   '01c806de-0002-42f2-0001-72de08b43ace')
ORDER BY START_TIME;

-- ⑤ 🆕 [O266] 질문·답변 원문 = CORTEX_AGENT_REQUEST(EVENT) 의 VALUE — request_body(질문) · response(답변 전문)
--   ③ 에서 빠진 이유 = EVENT 행은 trace 접두 필터에 걸리지 않는다 ⇒ thread_id·시각으로 고른다.
SELECT e.TIMESTAMP,
       e.RECORD_ATTRIBUTES:"snow.ai.observability.user.name"::STRING          AS user_name,
       e.RECORD_ATTRIBUTES:"snow.ai.observability.agent.thread_id"::STRING    AS thread_id,
       e.RECORD_ATTRIBUTES:"snow.ai.observability.object.version.name"::STRING AS agent_version,
       e.VALUE:"snow.ai.observability.request_body"::STRING                   AS request_body,
       e.VALUE:"snow.ai.observability.response"::STRING                       AS response
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS('GN_DW', 'SERVING', 'AGENT_MARKETING', 'CORTEX AGENT')) e
WHERE e.TIMESTAMP >= DATEADD(DAY, -14, CURRENT_TIMESTAMP())
  AND e.RECORD:name::STRING = 'CORTEX_AGENT_REQUEST'
  AND (e.VALUE::STRING ILIKE '%광고비%' OR e.VALUE::STRING ILIKE '%제작비%'
    OR e.VALUE::STRING ILIKE '%캠페인명%' OR e.VALUE::STRING ILIKE '%LTV%')
ORDER BY e.TIMESTAMP;

-- ⑥ 🆕 [O266] 스레드 목록(Observability 탭과 같은 내용 · 첫 질문 · 피드백 · 사용자)
SELECT THREAD_ID, FIRST_INPUT, MESSAGE_COUNT, USER_NAME, AGENT_VERSION, FIRST_TIMESTAMP, LAST_TIMESTAMP, USER_FEEDBACK
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_AGENT_MONITORING_DATA(
       'GN_DW', 'SERVING', 'AGENT_MARKETING',
       DATEADD(DAY, -14, CURRENT_TIMESTAMP())::TIMESTAMP_TZ, CURRENT_TIMESTAMP()::TIMESTAMP_TZ))
ORDER BY LAST_TIMESTAMP DESC;