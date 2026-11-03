-- =============================================================================
-- Purpose    : O260 요건 3 — 광고 원천(BRONZE_AGENCY) 컬럼 개명 2건을 SILVER staging 에 반영 (기존 환경 갱신)
-- Target     : TABLE GN_DW.SILVER.AGENCY_AD_ROW_VIDEO, TABLE GN_DW.SILVER.AGENCY_AD_ROW_REBRDC
-- Run order  : 기존 환경 갱신 #36 ([D0] → [D1] → 👤 dbt 재배포·build → [D2])
-- Depends on : BRONZE_AGENCY 원천 개명 입고 완료([D0] 로 확인) · 50_handoff/04 DDL 2026-10-23 판
-- Issue      : O260, O259 요건 3(D4), O238, O245
-- =============================================================================
-- 무엇이 바뀌나 (원천 = 90_provided_definition/13_bronze_agency_ddl.sql · 위치·타입 불변)
--   · VIDEO_AD_CMPGN_DTLS  19번째 : UPPER_CMPGN_NM('상위캠페인') → UPPER_CMPGN_CD('상위캠페인코드')
--   · REBRDC_AD_CMPGN_DTLS 17번째 : CMPGN_CD('캠페인코드')       → MKTG_CMPGN_NM('마케팅캠페인명')
--   dbt 모델 = AGENCY_AD_ROW_VIDEO · AGENCY_AD_ROW_REBRDC(원천명 그대로) · AGENCY_AD_PERFORMANCE(VIDEO 원천 컬럼만 교체)
--             · FACT_AD_PERFORMANCE(VIDEO 상위캠페인코드 조인 컬럼명만 교체) — 🟢 출력 컬럼·값 계약은 불변.
--   🔴 AD_PERF_DK 는 바뀐다 — staging ROW_HASH 가 OBJECT_CONSTRUCT(*) 의 키 이름까지 해시하기 때문이다
--      (개명 컬럼 값이 있는 행만). 같은 build 에서 FACT·위성이 함께 다시 계산되므로 하류 정합은 유지된다.
--
-- 왜 이 파일이 필요한가
--   GN_DW_DBT 는 SILVER 에 CREATE/ALTER 권한이 없다(07_ENVIRONMENT_RBAC_setup.sql §D.9 · 구조 = DDL · 데이터 = dbt).
--   staging 테이블은 08 SILVER DDL 이 만든 구조에 dbt 가 INSERT 한다 ⇒ 컬럼명을 DDL 쪽에서 먼저 바꿔야 한다.
--   정본 = /04_silver_design/08_SILVER_테이블DDL_20260714.sql 의 AGENCY_AD_ROW_VIDEO · AGENCY_AD_ROW_REBRDC 블록(2026-10-23 판).
--   WARN: 08 SILVER DDL 파일 전체를 재실행하지 마라(CREATE OR REPLACE ⇒ SILVER 전량 비워짐 · R2-9).
--   새로 구축하는 환경은 이 파일이 필요 없다(08 이 이미 새 이름으로 만든다) — [D1] 이 「does not exist」면 건너뛴다.
-- =============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [D0] 원천 개명 입고 확인 — 기대 = 신규 2행만(구 이름 0행). 구 이름이 나오면 원천 미반영이다 ⇒ 여기서 멈춘다.
SELECT table_name, column_name, ordinal_position, comment
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'BRONZE_AGENCY'
  AND (   (table_name = 'VIDEO_AD_CMPGN_DTLS'  AND column_name IN ('UPPER_CMPGN_NM', 'UPPER_CMPGN_CD'))
       OR (table_name = 'REBRDC_AD_CMPGN_DTLS' AND column_name IN ('CMPGN_CD', 'MKTG_CMPGN_NM')) )
ORDER BY table_name, ordinal_position;

-- [D0-b] 값 분포 실측(판정 근거 · 결과를 이력에 남긴다) — REBRDC 코어 승격(CAMPAIGN_NM) 판단 자료
SELECT 'VIDEO.UPPER_CMPGN_CD' AS col, COUNT(*) AS n_rows, COUNT(UPPER_CMPGN_CD) AS n_filled,
       COUNT(DISTINCT UPPER_CMPGN_CD) AS n_distinct
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
UNION ALL
SELECT 'REBRDC.MKTG_CMPGN_NM', COUNT(*), COUNT(MKTG_CMPGN_NM), COUNT(DISTINCT MKTG_CMPGN_NM)
FROM GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS;

-- [D0-c] REBRDC 마케팅캠페인명 ↔ DIM_MARKETING_CAMPAIGN 이름 일치율 (승격 시 FACT 이름매칭 경로가 잡을 행수)
SELECT COUNT(*)                                  AS n_filled,
       COUNT(mk.MKTG_CAMPAIGN_SK)                AS n_name_match
FROM GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS r
LEFT JOIN GN_DW.GOLD.DIM_MARKETING_CAMPAIGN mk
       ON mk.MKTG_CAMPAIGN_NAME = NULLIF(TRIM(r.MKTG_CMPGN_NM), '')
WHERE NULLIF(TRIM(r.MKTG_CMPGN_NM), '') IS NOT NULL;

-- [D1] SILVER staging 컬럼 개명 (dbt build 전) — 이미 새 이름이면 「does not exist」로 실패한다 ⇒ 그 문장은 건너뛴다(정상).
ALTER TABLE GN_DW.SILVER.AGENCY_AD_ROW_VIDEO  RENAME COLUMN UPPER_CMPGN_NM TO UPPER_CMPGN_CD;
ALTER TABLE GN_DW.SILVER.AGENCY_AD_ROW_VIDEO  ALTER COLUMN UPPER_CMPGN_CD
    COMMENT '[원천보존] 상위캠페인코드 (O260 원천 개명 · 구 UPPER_CMPGN_NM · 값은 종전에도 코드)';
ALTER TABLE GN_DW.SILVER.AGENCY_AD_ROW_REBRDC RENAME COLUMN CMPGN_CD TO MKTG_CMPGN_NM;
ALTER TABLE GN_DW.SILVER.AGENCY_AD_ROW_REBRDC ALTER COLUMN MKTG_CMPGN_NM
    COMMENT '[원천보존] 마케팅캠페인명 (O260 원천 개명 · 구 CMPGN_CD · 코어 승격 보류)';
ALTER TABLE GN_DW.SILVER.AGENCY_AD_ROW_REBRDC ALTER COLUMN UPPER_CMPGN_CD
    COMMENT '[원천보존] 상위캠페인코드 (O245 재측정 채움 · FACT 상위캠페인코드 경로 원천)';
ALTER TABLE GN_DW.SILVER.AGENCY_AD_PERFORMANCE ALTER COLUMN UPPER_CAMPAIGN_NM
    COMMENT '상위 캠페인 (VIDEO 전용) — 🔴 이름이 _NM 이나 값은 상위캠페인코드(원천 VIDEO.UPPER_CMPGN_CD · O260)';

-- 👤 [D1 다음] dbt 재배포 후 build (에이전트는 실행하지 않는다 · R4-1)
--   /10_dbt_pipeline/01_deploy_dbt_project.sql 로 재배포 →
--   build --select AGENCY_AD_ROW_VIDEO+ AGENCY_AD_ROW_REBRDC+
--   (+ = AGENCY_AD_PERFORMANCE · AGENCY_AD_BROADCAST · FACT_AD_PERFORMANCE · 위성 · WIDE_AD_* 까지 하류 전부)

-- [D2] 대사 — 신구 등식(백필 없음 · 같은 원천이면 아래가 build 전 기록값과 같아야 한다)
--   ① 소스별 행수·광고비 합계 불변
SELECT AD_SOURCE_TYPE, COUNT(*) AS n_rows, SUM(AD_COST) AS ad_cost
FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE
GROUP BY 1 ORDER BY 1;
--   ② 상위캠페인코드 경로 연결 행수 불변(O238 VIDEO · O245 재방송 1,809행 = 개발계 2026-10-18 · 새 계정은 build 전 값과 비교)
SELECT AD_SOURCE_TYPE, MKTG_MAP_METHOD, COUNT(*) AS n_rows
FROM GN_DW.GOLD.FACT_AD_PERFORMANCE
WHERE AD_SOURCE_TYPE IN ('VIDEO', 'REBROADCAST')
GROUP BY 1, 2 ORDER BY 1, 2;
--   ③ staging ↔ 코어 1:1(DK 재발급 후에도 유일 · 고아 0)
SELECT COUNT(*) AS n_orphan
FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE p
LEFT JOIN GN_DW.SILVER.AGENCY_AD_ROW_VIDEO v ON v.AD_PERF_DK = p.AD_PERF_DK
WHERE p.AD_SOURCE_TYPE = 'VIDEO' AND v.AD_PERF_DK IS NULL;
