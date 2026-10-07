-- O209 X6 — native eval 결과 요약(4지표 · 채점 실패 수) · run_name 을 IN 목록에 넣어 실행
-- Co-authored with CoCo
SELECT a.agent, a.run, a.metric, ROUND(AVG(a.score), 4) AS score, COUNT(*) AS n, COUNT_IF(a.score IS NULL) AS fail, a.ver
FROM (
  SELECT 'AGENT_EXECUTIVE' AS agent,
         CAST(GET_PATH(record_attributes, '["snow.ai.observability.run.name"]') AS VARCHAR) AS run,
         CAST(GET_PATH(record_attributes, '["ai.observability.eval.metric_name"]') AS VARCHAR) AS metric,
         TRY_CAST(GET_PATH(record_attributes, '["ai.observability.eval_root.score"]')::VARCHAR AS FLOAT) AS score,
         CAST(GET_PATH(record_attributes, '["snow.ai.observability.object.version.name"]') AS VARCHAR) AS ver
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS('GN_DW', 'SERVING', 'AGENT_EXECUTIVE', 'CORTEX AGENT'))
  WHERE CAST(GET_PATH(record_attributes, '["ai.observability.span_type"]') AS VARCHAR) = 'eval_root'
  UNION ALL
  SELECT 'AGENT_MEMBER',
         CAST(GET_PATH(record_attributes, '["snow.ai.observability.run.name"]') AS VARCHAR),
         CAST(GET_PATH(record_attributes, '["ai.observability.eval.metric_name"]') AS VARCHAR),
         TRY_CAST(GET_PATH(record_attributes, '["ai.observability.eval_root.score"]')::VARCHAR AS FLOAT),
         CAST(GET_PATH(record_attributes, '["snow.ai.observability.object.version.name"]') AS VARCHAR)
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS('GN_DW', 'SERVING', 'AGENT_MEMBER', 'CORTEX AGENT'))
  WHERE CAST(GET_PATH(record_attributes, '["ai.observability.span_type"]') AS VARCHAR) = 'eval_root'
  UNION ALL
  SELECT 'AGENT_MARKETING',
         CAST(GET_PATH(record_attributes, '["snow.ai.observability.run.name"]') AS VARCHAR),
         CAST(GET_PATH(record_attributes, '["ai.observability.eval.metric_name"]') AS VARCHAR),
         TRY_CAST(GET_PATH(record_attributes, '["ai.observability.eval_root.score"]')::VARCHAR AS FLOAT),
         CAST(GET_PATH(record_attributes, '["snow.ai.observability.object.version.name"]') AS VARCHAR)
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS('GN_DW', 'SERVING', 'AGENT_MARKETING', 'CORTEX AGENT'))
  WHERE CAST(GET_PATH(record_attributes, '["ai.observability.span_type"]') AS VARCHAR) = 'eval_root'
) a
WHERE a.run IN ('agent_executive_eval_o208c_v3', 'agent_executive_eval_o209_x6_v11',
                'agent_member_eval_o209_v10', 'agent_member_eval_o209_v11', 'agent_member_eval_o209_v12',
                'agent_marketing_eval_o209_before', 'agent_marketing_eval_o209_after')
GROUP BY a.agent, a.run, a.metric, a.ver
ORDER BY 1, 2, 3;
