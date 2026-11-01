-- O209 X4 — AGENT_GUIDE(안 A 안내형) 생성 · 개발계 ij48528 · 소유 = GN_DW_ADMIN(ACCOUNTADMIN 금지)
-- 스펙 정본 = 12_agent개선과제/09_O209_AGENT_GUIDE_spec.yaml(아래 본문과 동일해야 한다)
-- 되돌리기 = DROP AGENT GN_DW.SERVING.AGENT_GUIDE(승인 후)
-- Co-authored with CoCo
USE ROLE GN_DW_ADMIN;

CREATE AGENT GN_DW.SERVING.AGENT_GUIDE
  COMMENT = '굿네이버스 분석 Agent 안내(O209 · 안 A). 질문을 지표 기준으로 분류해 경영·전사/회원/마케팅 Agent 중 하나를 추천하고 질문을 다듬는다. 수치를 답하지 않는다.'
  PROFILE = '{"display_name": "분석 Agent 안내", "color": "#5B5B5B"}'
  FROM SPECIFICATION
$$
__SPEC__
$$;
