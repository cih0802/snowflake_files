-- =============================================================================
-- Purpose    : 🆕 [2026-10-29 O270] 마케팅 피드백 3차 — 최종 광고비 통합(데분_1·6) · 제작비 규칙 확정(데분_2) · SV_AD 캠페인유형 열거(R95)
-- Target     : GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST · SERVING.SV_MKTG_CAMPAIGN_COST · SERVING.SV_AD · SV_SERVICE · SV_EVENT · AGENT_MARKETING
-- Run order  : 운영계 기존 환경 갱신 #47(46 다음) · 개발계 = 같은 순서
-- Depends on : 46_DEPLOY_AD_SETTLE_CAMPAIGN_COST.sql 완료
-- Issue      : O270 · O269-C-1 ① · R95
-- =============================================================================
-- 🔴 실행 = python3 scripts/run_sql_file.py 05_SV-Agent_ai/47_DEPLOY_FINAL_AD_COST.sql --apply (승인 후 · 기본은 dry-run)
-- 🔴 [D1] 은 컬럼 추가(ALTER)라 되돌림 = DROP COLUMN 3개 · gold fact 는 on_schema_change 로 컬럼을 만들지 않는다(dbt_project.yml O40-B)
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE DATABASE GN_DW;

-- [D1] 물리 컬럼 추가(구조 정본 = 03_top-down_gold/06_DDL.sql FACT_MKTG_CAMPAIGN_MONTHLY_COST 블록)
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS AD_COST_REBROADCAST_TOT NUMBER(38,2)
  COMMENT '방송(재송출·방송) 총비용(원) = 원천 REBRDC TOT_COST 합(편성비+콘텐츠구입비+콜센터운영비). 원천이 NULL 이면 NULL 로 둔다(0 으로 채우지 않는다).';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS FINAL_AD_COST NUMBER(38,2)
  COMMENT '최종 광고비(원) = 디지털 LAST_STMT_AMT(최종정산금액) + 영상 LAST_AD_COST(최종광고비) + 방송 TOT_COST(총비용) — 현업 확정(데분_6). 원천 값이 NULL 인 행은 더해지지 않는다 ⇒ FINAL_AD_COST_NULL_ROWS 를 함께 본다.';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS FINAL_AD_COST_NULL_ROWS NUMBER(38,0)
  COMMENT '최종 광고비 원천 값이 NULL 인 광고 행 수(그 달). 0 보다 크면 FINAL_AD_COST 는 하한값이다(예: 방송 총비용 미입력 월).';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS DEV_CNT_CRM NUMBER(18,4)
  COMMENT '🆕 [O270] CRM 개발(건) = FACT_MEMBER_EVENT.DEV_CNT 합(금액 ÷ 10,000 · 상계 규칙 적용 · 신규·증액·재후원) · 결합 = 사건 시점 마케팅캠페인 코드. 소수가 있다.';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS NEW_DEV_CNT_CRM NUMBER(18,4)
  COMMENT '🆕 [O270] CRM 신규 개발(건)(개발구분 1).';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST MODIFY COLUMN PROD_COST
  COMMENT '제작비(원) = 지출결의 금액 중 콘텐츠구분자(CONTENTS_DELIMITER = 세부캠페인코드) 기재분 전체 — 현업 확정 규칙(데분_2 · 2026-10-29). 미기재(NULL·「-」) 지출은 캠페인을 알 수 없어 빠진다.';

-- [D1-확인] 신규 컬럼 5 실재(INFORMATION_SCHEMA · P33)
SELECT COLUMN_NAME, DATA_TYPE
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'GOLD' AND TABLE_NAME = 'FACT_MKTG_CAMPAIGN_MONTHLY_COST'
  AND COLUMN_NAME IN ('AD_COST_REBROADCAST_TOT', 'FINAL_AD_COST', 'FINAL_AD_COST_NULL_ROWS', 'DEV_CNT_CRM', 'NEW_DEV_CNT_CRM');

-- 👤 [dbt] 재배포(ALTER DBT PROJECT … ADD VERSION) → 전체 build(사용자 결정 2026-10-29 · FACT_MEMBER_EVENT 선행 포함)
--    🔴 에이전트는 실행하지 않는다(R4-1) · build 후 아래 [D2] 부터 이어 실행

-- [D2] 대사 — 팩트 최종 광고비 = FACT_AD_PERFORMANCE 원천별 최종값 합(2026)
SELECT (SELECT SUM(FINAL_AD_COST) FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST WHERE MONTH_KEY BETWEEN 202601 AND 202612) AS mcc_final,
       (SELECT SUM(CASE AD_SOURCE_TYPE WHEN 'DIGITAL' THEN LAST_STMT_AMT WHEN 'VIDEO' THEN AD_COST WHEN 'REBROADCAST' THEN TOT_COST END)
          FROM GN_DW.GOLD.FACT_AD_PERFORMANCE WHERE PERF_DATE_SK BETWEEN 20260101 AND 20261231) AS fap_final,
       (SELECT COUNT_IF(FINAL_AD_COST IS NOT NULL) FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST) AS final_non_null_rows;

-- [D3] SV 재배포(각 파일 전체 · 문장 단위) — 순서대로
--   05_SV-Agent_ai/05_31_SV_DDL_MKTG_CAMPAIGN_COST.sql   (최종 광고비 지표 · 제작비 문안)
--   05_SV-Agent_ai/05_07_SV_DDL_AD.sql                    (캠페인유형 열거 = R95 운영계 실측 공통값)
--   05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql               (O269-B GA_CLICK_MAP_SRC 열거)
--   05_SV-Agent_ai/05_05_SV_DDL_EVENT_PARTICIPATION.sql   (O269-B EVENT_CATEGORY_NAME 열거)
-- [D4] Agent 재배포 = cortex_project/agents/AGENT_MARKETING/agent_spec.yaml (O270 광고비·출처 규칙)
-- [D5] 게이트 = python3 scripts/sv_code_label_gate.py --shard k/8 (8조각) · 🟠 열거 누락 0 확인
