-- =============================================================================
-- Purpose    : O240 운영계 실데이터 이상치 보강 배포 순서
-- Target     : DBT PROJECT GN_DW.OPS.DW_PIPELINE (실행)
-- Run order  : 기존 환경 갱신 #1 · 기존 환경 갱신 #4 · 기존 환경 갱신 #6
-- Depends on : GN_DW.GOLD.FACT_AD_PERFORMANCE, GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP, GN_DW.SILVER.AGENCY_AD_BROADCAST, GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY
-- Issue      : O240, O240-C
-- =============================================================================
-- ============================================================================
-- 30_DEPLOY_DATA_ANOMALY.sql — O240 운영계 실데이터 이상치 보강 배포 순서
--   작성 = 2026-10-16 · 사용자 승인(전부 진행)
--   WARN: 에이전트 세션은 Restricted Session Scope 라 DBT PROJECT·SEMANTIC VIEW·AGENT OWNERSHIP 작업이 거부됐다
--      ⇒ 아래 D1~D5 는 MANUAL: 사용자가 GN_DW_ADMIN 으로 실행한다.
--   롤백 기준점 = AGENT_MEMBER VERSION$7 · AGENT_MARKETING VERSION$5 · AGENT_EXECUTIVE VERSION$5 · dbt 직전 버전
-- ----------------------------------------------------------------------------
-- 변경 요지(근거 = 실측 이전 계정 2026-10-16)
--   ① SILVER.AGENCY_AD_PERFORMANCE · AGENCY_AD_BROADCAST — VIDEO BRDC_DATE 1970-01-01(에포크) 1,573행
--      → NULLIF 후 텍스트축 폴백(1,573행 전건 2025-03-04~2026-02-28 로 해석됨 · 사전 시뮬레이션)
--   ② GOLD.FACT_CAMPAIGN_MONTHLY · FACT_CAMPAIGN_CUM_STOP — 기준월 = var billing_coverage_start_month(202201) ~ 당월
--      (회비원장 2021년 6,319행 → 2022년 9,559,984행 · 2019~2021 누계중단율 85~99% → 제거 · 미래 선납월 제거)
--   ③ SV_GA_SESSION — 공98 AVG_SESSION_ENGAGEMENT_SEC · 공108 BOUNCE_RATE 신설(사전 실측 32.9초 · 53.82%)
--   ④ SV_AD — CTR 분자에서 노출 0 행의 클릭 제외(DIGITAL 3,190행)
--   ⑤ Agent 3종 orchestration 선두에 [O240 실데이터 이상치 가드] 규칙
--   ⑦ (O240-C) FACT_BUDGET·FACT_BUDGET_YEARLY 차수 규칙 = 편성액이 있는 차수 중 최신(2026 추경 행 편성 0 → 연사업)
--   ⑥ 코퍼스 = 변경 없음(재생성 결과 바이트 동일 · 공91·98·108 은 사전 FORMULA 공란이라 오버레이 비대상)
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [D0] 사전 값(비교용)
SELECT COUNT_IF(PERF_DATE_SK < 20000101) AS ad_epoch_rows FROM GN_DW.GOLD.FACT_AD_PERFORMANCE;           -- 기대 1,573
SELECT MIN(BASE_MONTH_KEY), MAX(BASE_MONTH_KEY), COUNT(*) FROM GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP;         -- 199101 · 202911 · 900,099

-- [D1] MANUAL: dbt 재배포 + build
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION O240_20261016
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ARGS = 'build --select AGENCY_AD_PERFORMANCE+ AGENCY_AD_BROADCAST+ FACT_CAMPAIGN_MONTHLY FACT_CAMPAIGN_CUM_STOP FACT_BUDGET+ FACT_BUDGET_YEARLY+';

-- [D2] 대사
SELECT COUNT_IF(PERF_DATE_SK < 20000101) AS ad_epoch_rows,                                              -- 기대 0
       SUM(AD_COST) AS ad_cost                                                                         -- 기대 = D0 와 같다(행 이동만)
FROM GN_DW.GOLD.FACT_AD_PERFORMANCE;
SELECT COUNT_IF(BROADCAST_DATE = '1970-01-01') FROM GN_DW.SILVER.AGENCY_AD_BROADCAST;                    -- 기대 0
SELECT MIN(BASE_MONTH_KEY), MAX(BASE_MONTH_KEY) FROM GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP;                  -- 기대 202201 · 당월
SELECT MIN(BASE_MONTH_KEY), MAX(BASE_MONTH_KEY) FROM GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY;                   -- 기대 202201 · 당월
SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_CAMPAIGN_CUM_STOP
         DIMENSIONS fccs.BASE_MONTH_KEY METRICS fccs.CUM_STOP_RATE)
WHERE BASE_MONTH_KEY IN (202212, 202312, 202412, 202512, 202609) ORDER BY 1;                             -- 기대 14.38 · 17.80 · 17.02 · 18.79 · 13.78(변경 전과 같다)

SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET_YEARLY
         DIMENSIONS fby.BUDGET_YEAR METRICS fby.EXEC_RATE_YEAR) ORDER BY 1;                               -- 기대 98.11 · 99.69 · 67.22(2026 = 연사업)

-- ============================================================================
-- WARN: 이 파일은 여기(D2)까지만 실행문이다. D3·D4 는 **다른 파일을 열어 전체 실행**한다(SV·Agent 도 MANUAL: 사용자 배포).
--    D3 를 하기 전에 아래 확인 SELECT 를 돌리면 「invalid identifier GS.AVG_SESSION_ENGAGEMENT_SEC」 가 난다(신설 metric 이 아직 없다).
-- ============================================================================

-- [D3] MANUAL: SV 2종 = 아래 두 파일을 각각 열어 전체 실행(각 파일 끝 스모크 포함)
--   ① 05_SV-Agent_ai/05_20_SV_DDL_GA_SESSION.sql (공98·공108 metric 신설)
--   ② 05_SV-Agent_ai/05_07_SV_DDL_AD.sql (CTR 분자 가드)
--   ③ D3 확인 — 두 파일 실행 후 아래 주석을 풀어 실행:
-- SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_GA_SESSION
--          METRICS gs.SESSION_CNT, gs.AVG_SESSION_ENGAGEMENT_SEC, gs.BOUNCE_RATE); -- 기대 1,190,210 · 32.9 · 53.82

-- [D4] MANUAL: Agent 3종 = 05_SV-Agent_ai/09_2_AGENT_버전업.sql 전체 실행(MEMBER · MARKETING · EXECUTIVE · WARN: D3 뒤에)
--   (코퍼스 26_BIZ_DEFINITION_CORPUS 재적재는 불필요 — O240 재생성 결과 바이트 동일)

-- [D5] 스모크(MANUAL: Snowflake Intelligence) — 기대 답변 요지
--   AGENT_MEMBER 「2021년 캠페인별 누계중단율」 → 회비원장이 2022-01부터 존재해 산출 불가
--   AGENT_MEMBER 「2026년 9월 선물금참여(원)」 → analyst_relation_activity TOTAL_GIFT_AMT · 결연활동 전체 기준 명시
--   AGENT_MARKETING 「2026년 9월 GA 평균세션시간과 이탈율」 → analyst_ga_session · GA4 정의 명시
--   AGENT_MARKETING 「2025년 예산 집행율」 → analyst_budget_yearly(연 축)
--   AGENT_EXECUTIVE 「2026년 사업목표 합계」 → 목표유형별 분리 · 합산 거부 · 추경 원천 없음

-- [D6] 롤백
--   dbt = 직전 버전으로 ALTER DBT PROJECT … SET DEFAULT_VERSION 후 같은 --select build
--   SV = 두 파일의 O240 변경 줄 되돌린 뒤 재실행 · Agent = 위 롤백 기준점 버전
