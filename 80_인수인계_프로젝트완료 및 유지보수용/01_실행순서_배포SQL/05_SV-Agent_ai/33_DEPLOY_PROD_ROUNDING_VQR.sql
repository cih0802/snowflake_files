-- =============================================================================
-- Purpose    : O241-C(개발 환경 배포분) + O242 VQR 교정의 기존 환경(운영계) 반영 순서
-- Target     : - (조회·검증 전용 · 객체 생성 없음)
-- Run order  : 기존 환경 갱신 #11 · 기존 환경 갱신 #13
-- Depends on : GN_DW.INFORMATION_SCHEMA.VIEWS
-- Issue      : O241-C, O242, O241, O241-F 외 4
-- =============================================================================
-- ============================================================================
-- 33_DEPLOY_PROD_ROUNDING_VQR.sql — O241-C(개발 환경 배포분) + O242 VQR 교정의 기존 환경(운영계) 반영 순서
--   작성 = trialadmin · 2026-10-18 · O242 · 근거 = 99_NEXT_SESSION_조각/99_NEXT_SESSION-O0241-C.md ▣ O241-C-3 ⑤
--   WARN: 선행 = 32_DEPLOY_AB_DUAL_SV_WIRING.sql D1-a~D2(dbt) 완료 — 이 파일은 dbt 를 다시 돌리지 않는다.
--   WARN: D1·D2·D3 은 MANUAL: 사용자가 GN_DW_ADMIN 으로 실행한다(R4-1 · 뷰·SV·Agent 라이브 배포).
--   개발 환경 기준점(이전 계정 실측) = Agent 3종 VERSION$7 · 롤백 $4 = O241 직전 · $5 = O241-F/T · $6 = O241-M
--     WARN: 운영계는 번호가 다르다 ⇒ D0 에서 운영계 현재 default 버전을 먼저 적어 둔다(그것이 롤백 기준점).
-- ----------------------------------------------------------------------------
-- 변경 요지
--   ① 뷰 1 = SERVING.ML_MEMBER_ATTR_ASOF_V(O241-M · 기준월 말 시점 회원 특성 · 모델 피처 아님) — 21 파일 안
--   ② SV = O241-R 반올림 규칙(05_01~05_26 · 22 · 25) · O241-M `ma` 관계 + 차원 10(22 의 SV_ML_MEMBER_RISK ·
--      SV_ML_SPONSOR_RISK · 25 의 SV_ML_CHURN_CAMPAIGN) · O242 05_26 VQR 2건 한글 별칭·반올림
--   ③ Agent 3종 = O241-F 출력 자기점검 · O241-T 호출 절약 · O241-M 「회원 속성 축 없음」 문장 교체
--    ④ [O242-B] SV VQR 31건(17파일) 한글 별칭·반올림(원 SQL 바깥 감싸기 · 값 무변경) ·
--      ML_CHURN_BY_CMPGN_CTGR_V 정의 25 → 21 이동(문면 무변경 · 신규 구축 순서 의존성) ·
--      Agent ③ 정정(analyst → system_execute_sql 실행은 정상 경로 · SQL 도 SV 규칙) · ㉥ 이물 문자 점검 · MEMBER 캠페인별 예측+특성 라우팅
--      개발 환경 = Agent 3종 VERSION$8(롤백 $7)
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [D0] 사전 확인(기대 = 주석 값)
-- 0-1 ATTR 뷰가 참조하는 ML 뷰가 이미 있다(기대 3 · O242-B 이후 21 이 ML_CHURN_BY_CMPGN_CTGR_V 도 만든다 ⇒ 0~2 여도 D1 로 채워진다)
SELECT COUNT(*) AS ml_src_views
FROM GN_DW.INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'SERVING'
  AND TABLE_NAME IN ('ML_MEMBER_RISK_V', 'ML_SPONSOR_RISK_V', 'ML_CHURN_BY_CMPGN_CTGR_V');
-- 0-2 롤백 기준점 기록(각 Agent 의 is_default = true 버전 이름을 적어 둔다)
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_EXECUTIVE;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MARKETING;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;

-- ============================================================================
-- WARN: 이 파일은 여기(D0)까지만 실행문이다. D1~D3 은 **다른 파일을 열어 전체 실행**한다.
--    WARN: D1 전에 D2 의 22·25 를 돌리면 SV 생성이 ML_MEMBER_ATTR_ASOF_V 부재로 실패한다.
-- ============================================================================

-- [D1] MANUAL: 뷰 = 05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql 전체(CREATE OR REPLACE VIEW 만 · 파괴문 없음 · 말미 ML_CHURN_BY_CMPGN_CTGR_V → ML_MEMBER_ATTR_ASOF_V)
--   ① D1 확인 — 주석을 풀어 실행(개발 환경 실측 = 연령대 분해 합계 70,158 = 원본 · 매칭 97~99% · 운영계는 값이 다를 수 있다):
-- SELECT COUNT(*) AS rows_all, COUNT_IF(ATTR_MATCHED) / NULLIF(COUNT(*), 0) * 100 AS matched_pct
-- FROM GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V;

-- [D2] MANUAL: SV = 아래 28파일을 각각 열어 전체 실행(CREATE OR ALTER · 각 파일 끝 스모크 포함)
--   05_01 · 05_02 · 05_03 · 05_04 · 05_05 · 05_06 · 05_07 · 05_08 · 05_09 · 05_10 · 05_11 · 05_12 · 05_13 ·
--   05_14 · 05_15 · 05_16 · 05_17 · 05_18 · 05_19 · 05_20 · 05_21 · 05_22 · 05_23 · 05_24 · 05_25 · 05_26 ·
--   22_ML_SV_DDL.sql · 25_ML_CHURN_CMPGN_CTGR_DDL.sql
--   ① D2 확인 — 주석을 풀어 실행:
-- SELECT GET_DDL('SEMANTIC_VIEW', 'GN_DW.SERVING.SV_GA_CHILD_UNPAID') ILIKE '%AS "미납서비스 전환율(추천안A)(%)"%' AS o242_vqr; -- 기대 TRUE
-- SELECT GET_DDL('SEMANTIC_VIEW', 'GN_DW.SERVING.SV_ML_CHURN_CAMPAIGN') ILIKE '%ML_MEMBER_ATTR_ASOF_V%' AS o241m_ma; -- 기대 TRUE

-- [D3] MANUAL: Agent 3종 = 05_SV-Agent_ai/09_2_AGENT_버전업.sql 로 EXECUTIVE · MARKETING · MEMBER 버전업(WARN: D2 뒤에)
--   정본 = cortex_project/agents/*/agent_spec.yaml(O241-F · O241-T · O241-M 반영본)

-- [D4] 스모크(MANUAL: Snowflake Intelligence) — 개발 환경 기대
--   AGENT_MEMBER 「클릭월별 미납서비스 전환율」 → 열 이름 한글 · 전환율 소수 둘째 자리 · 전체 A 13.64% · B 33.10%(개발 환경)
--   AGENT_MEMBER 「캠페인별 중단 예측 회원의 연령대 분포」 → analyst_ml_churn_campaign(ma 축) 1회
--   AGENT_MARKETING 「GA 행동 대리지표 질문(Q25 유형)」 → 대리지표 + 한계 명시(답변 불가로 끝내지 않는다)
--   공통 = 태그·영문 진행 문장 없음 · 「① 핵심 요약」 1회 · 표 금액·건수 천단위 쉼표

-- [D5] 롤백
--   Agent = D0-2 에 적어 둔 버전으로 ALTER AGENT … SET DEFAULT_VERSION
--   SV = 직전 정본으로 되돌린 뒤 재실행(CREATE OR ALTER) · 뷰 = 남겨도 무해(SV 가 참조를 끊으면 미사용)
