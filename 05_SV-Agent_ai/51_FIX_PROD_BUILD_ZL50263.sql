-- =============================================================================
-- 51_FIX_PROD_BUILD_ZL50263.sql — 운영계 build 실패 20건 복구(전체 선택 → 순서대로 실행)
-- O271-D · 2026-10-30 · 대상 = 운영계 ZL50263 전용(개발계는 이미 이 상태 · 실행 불필요)
--
-- 원인 ① WIDE 뷰 003509 = 운영계 GOLD 가 MANAGED ACCESS → dbt 역할이 +grants·copy grants 를 못 한다
--        설계 정본 = 02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql:134
--        「BRONZE_*·SECURITY = MANAGED ACCESS. SILVER/GOLD/SERVING/OPS = 일반.」 ⇒ 설계로 되돌린다(사용자 결정 ㉮)
-- 원인 ② FACT_MKTG_CAMPAIGN_MONTHLY_COST 003001 = 47번 [D1] 컬럼 5개 미추가 → dbt 가 ALTER 시도 → 소유자 권한 필요
--        소유자 = GN_DW_ADMIN(O271 단계 4 이전 완료) ⇒ GN_DW_ADMIN 으로 [D1] 실행
-- 🟢 모든 문장은 재실행해도 안전하다(IF NOT EXISTS · DISABLE 은 멱등)
-- =============================================================================

-- [1] 진단(읽기 전용) — 결과 options 열에 MANAGED ACCESS 가 있는 스키마 확인(기대 = BRONZE_* · SECURITY · GOLD)
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
SHOW SCHEMAS IN DATABASE GN_DW;

-- [2] 원인 ② — 47번 [D1] 물리 컬럼 추가(05_SV-Agent_ai/47_DEPLOY_FINAL_AD_COST.sql [D1] 원문 그대로)
USE ROLE GN_DW_ADMIN;
USE DATABASE GN_DW;
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

-- [2-확인] 기대 = 5행
SELECT COLUMN_NAME, DATA_TYPE
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'GOLD' AND TABLE_NAME = 'FACT_MKTG_CAMPAIGN_MONTHLY_COST'
  AND COLUMN_NAME IN ('AD_COST_REBROADCAST_TOT', 'FINAL_AD_COST', 'FINAL_AD_COST_NULL_ROWS', 'DEV_CNT_CRM', 'NEW_DEV_CNT_CRM');

-- [3] 원인 ① — GOLD managed access 해제(설계 정본 복귀)
--     ACCOUNTADMIN = 스키마 소유자(GN_DW_ADMIN) 상위 + MANAGE GRANTS 보유(GOLD 에 FUTURE GRANT 가 있어 필요)
--     🟢 기존 객체 GRANT·FUTURE GRANT 는 그대로 유지된다
USE ROLE ACCOUNTADMIN;
ALTER SCHEMA GN_DW.GOLD DISABLE MANAGED ACCESS;

-- [3-확인] 기대 = IS_MANAGED_ACCESS = NO
SELECT SCHEMA_NAME, SCHEMA_OWNER, IS_MANAGED_ACCESS
FROM GN_DW.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME IN ('GOLD', 'SERVING', 'SILVER', 'OPS');

-- [4] dbt retry — 직전 실행에서 실패·건너뜀 모델만 재실행(GN_DW_DBT)
USE ROLE GN_DW_DBT;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='retry';

-- [5] 결과 확인 — 실패 모델이 이제 GRANT 를 가졌는가(기대 = GN_DW_AR_SRC_AGENCY 행 존재)
USE ROLE ACCOUNTADMIN;
SHOW GRANTS ON VIEW GN_DW.GOLD.WIDE_AD_COMBINED;
-- 이후 = O270 운영계 LLM 프롬프트 단계 4(Agent 재배포)부터 · 47번 [D2] 대사는 그 전에 1회 실행 권장
