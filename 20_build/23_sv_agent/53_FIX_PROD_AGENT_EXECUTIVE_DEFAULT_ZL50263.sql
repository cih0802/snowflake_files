-- =============================================================================
-- 53_FIX_PROD_AGENT_EXECUTIVE_DEFAULT_ZL50263.sql — 운영계 경영 Agent default 를 O270 반영 버전으로 옮긴다
-- O273-B · 2026-10-30 · 대상 = 운영계 ZL50263 전용
--
-- 증상 = O270 단계 4 `deploy_agents.py deploy` 후에도 AGENT_EXECUTIVE default = VERSION$20 · 도구 19
--        (기대 = 도구 17 · analyst_ad·analyst_ml_realtime_simulator 제거 · O270 W3 사용자 결정)
--        MEMBER·MARKETING 은 정상 반영 · 사전 대조 [0-C] EXECUTIVE 81408 = 개발계 정본 크기(17개판)
-- 추정 원인(미확정 — [1] 로 판정) = 새 버전은 생성됐으나 default 가 이전 버전에 고정돼 자동으로 옮겨지지 않았다
--        (09_2 [3] 「자동 is_default」 가정 · [6] 롤백의 SET DEFAULT_VERSION 이력이 있으면 깨질 수 있다)
-- 방식 = [2] 블록이 최신 명명 버전을 스스로 검사해 조건이 맞을 때만 default 를 옮긴다
--        조건 = 도구 17 · analyst_ad 없음 · analyst_ml_realtime_simulator 없음 · O270 안내 문구 있음
--        반환 = 'DONE …' · 'SKIP …'(이미 default) · 'ABORT …'(조건 불일치 — 아무것도 바꾸지 않음)
-- 🟢 버전은 불변 스냅샷이다 — default 만 옮기므로 [R] 한 줄로 즉시 되돌린다
-- 🟢 재실행 안전 — 이미 옮겨졌으면 SKIP
-- 🔴 개발계 사전 검증(TQ68205) = [1] 실행 · [2] = SKIP 경로(개발계는 최신 VERSION$4 가 이미 default)
-- =============================================================================

-- [1] 진단(읽기 전용) — 최신 5개 버전의 default 여부·도구 수
--   판정 A = 최신 행이 VERSION$21 이상 · TOOL_CNT 17 · HAS_AD FALSE · HAS_O270_TEXT TRUE · IS_DEFAULT false ⇒ [2] 실행
--   판정 B = 최신 행이 VERSION$20(19개) ⇒ 새 버전이 생성되지 않았다 ⇒ [2] 를 실행하지 말고 결과를 보고한다
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_EXECUTIVE;
SELECT "name", "is_default", "created_on",
       ARRAY_SIZE(PARSE_JSON("agent_spec"):tools) AS TOOL_CNT,
       ARRAY_CONTAINS('analyst_ad'::VARIANT,
         TRANSFORM(PARSE_JSON("agent_spec"):tools, t -> t:tool_spec:name)) AS HAS_AD,
       ARRAY_CONTAINS('analyst_ml_realtime_simulator'::VARIANT,
         TRANSFORM(PARSE_JSON("agent_spec"):tools, t -> t:tool_spec:name)) AS HAS_SIM,
       CONTAINS("agent_spec", 'O270 원천별 접근통제') AS HAS_O270_TEXT
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" IS NOT NULL
ORDER BY "created_on" DESC
LIMIT 5;

-- [2] default 이동(조건부) — 반환값 1줄을 그대로 보고한다
EXECUTE IMMEDIATE $$
DECLARE
  v_name VARCHAR; v_def VARCHAR; n_tool INTEGER; has_ad BOOLEAN; has_sim BOOLEAN; has_txt BOOLEAN; cur_def VARCHAR;
BEGIN
  SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_EXECUTIVE;
  SELECT "name", "is_default"::VARCHAR,
         ARRAY_SIZE(PARSE_JSON("agent_spec"):tools),
         ARRAY_CONTAINS('analyst_ad'::VARIANT, TRANSFORM(PARSE_JSON("agent_spec"):tools, t -> t:tool_spec:name)),
         ARRAY_CONTAINS('analyst_ml_realtime_simulator'::VARIANT, TRANSFORM(PARSE_JSON("agent_spec"):tools, t -> t:tool_spec:name)),
         CONTAINS("agent_spec", 'O270 원천별 접근통제')
    INTO :v_name, :v_def, :n_tool, :has_ad, :has_sim, :has_txt
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
   WHERE "name" IS NOT NULL
   ORDER BY "created_on" DESC
   LIMIT 1;

  IF (LOWER(v_def) = 'true') THEN
    RETURN 'SKIP — 최신 ' || v_name || ' 이 이미 default (도구 ' || n_tool || ')';
  END IF;
  -- 빈 spec 버전은 도구 수·포함 여부가 NULL 이다 ⇒ NULL 이 조건을 통과하지 않게 COALESCE(개발계 VERSION$1·$2 실측)
  IF (COALESCE(n_tool, 0) <> 17 OR COALESCE(has_ad, TRUE) OR COALESCE(has_sim, TRUE) OR NOT COALESCE(has_txt, FALSE)) THEN
    RETURN 'ABORT — 최신 ' || v_name || ' 이 O270 판이 아니다(도구 ' || NVL(n_tool::VARCHAR, 'NULL') || ' · ad ' || NVL(has_ad::VARCHAR, 'NULL')
           || ' · sim ' || NVL(has_sim::VARCHAR, 'NULL') || ' · O270문구 ' || NVL(has_txt::VARCHAR, 'NULL') || ') · 변경 없음';
  END IF;

  EXECUTE IMMEDIATE 'ALTER AGENT GN_DW.SERVING.AGENT_EXECUTIVE SET DEFAULT_VERSION = ''' || v_name || '''';

  SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_EXECUTIVE;
  SELECT MAX(IFF(LOWER("is_default"::VARCHAR) = 'true', "name", NULL)) INTO :cur_def
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
  RETURN 'DONE — default = ' || cur_def || ' (도구 ' || n_tool || ')';
END;
$$;

-- [3] 확인 — [1] 을 다시 실행한다. 기대 = 최신 행 IS_DEFAULT true · TOOL_CNT 17 · HAS_AD FALSE · HAS_SIM FALSE

-- [R] 롤백(문제 시에만 · 실행 전 사람 승인) — 이전 default 로 되돌린다
-- ALTER AGENT GN_DW.SERVING.AGENT_EXECUTIVE SET DEFAULT_VERSION = 'VERSION$20';
