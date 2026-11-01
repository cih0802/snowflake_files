-- =============================================================================
-- 49_DEPLOY_CORPUS_SCOPE_O270.sql — 지표사전 코퍼스 AGENT_SCOPE 를 원천별 접근통제에 맞춘다
-- O270-F · 2026-10-29 · 계획서 C7 · 사용자 승인(2026-10-29)
-- 대상 = TOOL_NAME 이 광고 도구(analyst_ad) 단독인 행 → AGENT_SCOPE = 'MARKETING'
--   · 실측(ZS83821 · 2026-10-29) = RT-02 · MET_CMN-5~10 · MET_CMN-12 (8행 · RT-32 시뮬레이터 행은 라이브 부재)
-- 혼합 도구 행(RT-15 · MET_NEW-10 등)은 그대로 둔다 — 다른 도구 소관 정의를 함께 담고 있다
-- 🔴 코퍼스는 정의·산식 문서다(수치 없음 규약) — 이 변경은 라우팅 메타데이터 정합이며 데이터 차단 수단이 아니다
--    데이터 차단 = 48_RBAC_SOURCE_ACCESS.sql
-- 롤백 = 아래 [R] 블록(원값 'MARKETING|MEMBER|EXECUTIVE' · RT-02 = 'MARKETING|EXECUTIVE')
-- =============================================================================
USE ROLE GN_DW_ADMIN;

-- [0] 사전 대조 — 기대 8행
SELECT DOC_ID, AGENT_SCOPE, TOOL_NAME
FROM GN_DW.SERVING.BIZ_DEFINITION_CORPUS
WHERE TRIM(TOOL_NAME) = 'analyst_ad'
ORDER BY DOC_ID;

-- [1] 적용
UPDATE GN_DW.SERVING.BIZ_DEFINITION_CORPUS
SET AGENT_SCOPE = 'MARKETING'
WHERE TRIM(TOOL_NAME) = 'analyst_ad'
  AND AGENT_SCOPE <> 'MARKETING';

-- [2] 검증 — 광고 단독 행 중 MARKETING 아닌 행 0
SELECT COUNT(*) AS NOT_MARKETING
FROM GN_DW.SERVING.BIZ_DEFINITION_CORPUS
WHERE TRIM(TOOL_NAME) = 'analyst_ad'
  AND AGENT_SCOPE <> 'MARKETING';

-- [R] 롤백(별도 승인)
-- UPDATE GN_DW.SERVING.BIZ_DEFINITION_CORPUS SET AGENT_SCOPE = 'MARKETING|EXECUTIVE'
--   WHERE DOC_ID = 'RT-02';
-- UPDATE GN_DW.SERVING.BIZ_DEFINITION_CORPUS SET AGENT_SCOPE = 'MARKETING|MEMBER|EXECUTIVE'
--   WHERE DOC_ID IN ('MET_CMN-5','MET_CMN-6','MET_CMN-7','MET_CMN-8','MET_CMN-9','MET_CMN-10','MET_CMN-12');
