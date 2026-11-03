-- dbt_build_fact_ad_performance_budget.sql — 「기존 환경 갱신」 16번(O245) 정본: W6 재방송 상위캠페인코드 결합 · 예산 차수 주석
--   🔴 👤 사용자가 실행한다(dbt 정지점) · 운영계 백필 없음(R2-9)
--   🆕 2026-10-21 = 본문이 O248 일회성 build(FACT_AD_INFLOW_ALLOC · FACT_MEMBER_EVENT_COHORT)로 덮여 있던 것을 16번 정의로 되돌렸다
--      (O248 두 모델은 개발계 SR61467 · 운영계 ZL50263 에 이미 있다 = 85 _ENV/ZL50263 캡처 2026-10-21)
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';

USE ROLE GN_DW_DBT;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select FACT_AD_PERFORMANCE+ FACT_BUDGET FACT_BUDGET_YEARLY';

-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='retry';