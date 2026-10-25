-- =============================================================================
-- Purpose    : O262(O261-B ㉮) — SILVER.AGENCY_AD_PERFORMANCE 상위캠페인 코드·이름 2열 분리 (기존 환경 갱신)
-- Target     : TABLE GN_DW.SILVER.AGENCY_AD_PERFORMANCE
-- Run order  : 기존 환경 갱신 #39 ([D0] → [D1] → MANUAL: dbt 재배포·build → [D2])
-- Depends on : 42_DEPLOY_AGENCY_AD_SRC_RENAME.sql(#36) 선행 · 08 SILVER DDL 2026-10-25 판
-- Issue      : O262, O261-B, O260, O238
-- =============================================================================
-- 무엇이 바뀌나
--   원천 VIDEO.UPPER_CMPGN_CD 는 이름이 _CD 이나 값이 혼재다(개발 환경 실측 2026-10-25):
--     · 코드형 ^U[0-9]+$ = 2026-06 이후 행(CRM CMPGN_CD 와 일치)
--     · 이름형 = 2026-05 이전 행(원천이 개명 전 값을 그대로 둠)
--   코어 출력을 형태로 나눈다:
--     · UPPER_CAMPAIGN_CD(신규 · 맨 끝 열) = 코드형만
--     · UPPER_CAMPAIGN_NM(기존) = 이름형만(코드형 행은 NULL 이 된다)
--   DIGITAL·REBROADCAST 는 두 열 다 NULL. GOLD FACT_AD_PERFORMANCE 는 staging 을 직접 조인하므로 매핑 결과 불변.
--
-- 왜 이 파일이 필요한가
--   GN_DW_DBT 는 SILVER 에 ALTER 권한이 없다(구조 = DDL · 데이터 = dbt) ⇒ 열을 DDL 쪽에서 먼저 추가한다.
--   정본 = /04_silver_design/08_SILVER_테이블DDL_20260714.sql 의 AGENCY_AD_PERFORMANCE 블록(2026-10-25 판).
--   WARN: 08 SILVER DDL 파일 전체를 재실행하지 마라(CREATE OR REPLACE ⇒ SILVER 전량 비워짐 · R2-9).
--   새로 구축하는 환경은 이 파일이 필요 없다(08 이 이미 새 열로 만든다) — [D1] 은 IF NOT EXISTS 라 재실행 무해.
-- =============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [D0] build 전 형태 분포 — 기대 = 코드형 종은 전부 is_cmpgn_cd TRUE · 이름형은 code_shaped FALSE.
--      코드형인데 CRM 에 없는 값이 나오면 규칙을 바꾸기 전에 멈춘다. 결과를 이력에 남긴다.
SELECT REGEXP_LIKE(UPPER_CAMPAIGN_NM, '^U[0-9]+$')                                  AS code_shaped,
       UPPER_CAMPAIGN_NM IN (SELECT CMPGN_CD::VARCHAR FROM GN_DW.SILVER.CRM_CAMPAIGN) AS is_cmpgn_cd,
       COUNT(DISTINCT UPPER_CAMPAIGN_NM)                                             AS n_values,
       COUNT(*)                                                                      AS n_rows,
       MIN(AD_DATE)                                                                  AS d0,
       MAX(AD_DATE)                                                                  AS d1
FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE
WHERE UPPER_CAMPAIGN_NM IS NOT NULL
GROUP BY 1, 2
ORDER BY 1, 2;

-- [D0-b] build 전 FACT 매핑 경로 기준값(⇒ [D2] ② 와 비교)
SELECT AD_SOURCE_TYPE, MKTG_MAP_METHOD, COUNT(*) AS n_rows
FROM GN_DW.GOLD.FACT_AD_PERFORMANCE
GROUP BY 1, 2
ORDER BY 1, 2;

-- [D1] 열 추가 (dbt build 전) — 재실행 무해
ALTER TABLE GN_DW.SILVER.AGENCY_AD_PERFORMANCE ADD COLUMN IF NOT EXISTS UPPER_CAMPAIGN_CD VARCHAR
    COMMENT '상위 캠페인코드 (VIDEO 전용) — 원천 VIDEO.UPPER_CMPGN_CD 값 중 코드형(^U[0-9]+$ · CRM CMPGN_CD). 이름형 행은 NULL(UPPER_CAMPAIGN_NM 에 있음) · 그 외 소스는 원천 개념 부재 NULL (O262)';
ALTER TABLE GN_DW.SILVER.AGENCY_AD_PERFORMANCE ALTER COLUMN UPPER_CAMPAIGN_NM
    COMMENT '상위 캠페인명 (VIDEO 전용) — 원천 VIDEO.UPPER_CMPGN_CD 값 중 이름형(^U[0-9]+$ 아님 · 2026-05 이전 행). 코드형은 UPPER_CAMPAIGN_CD. 그 외 소스는 원천 개념 부재 NULL (O262)';

-- [D1-b] GOLD 승격 (O262 · 사용자 결정 = N-29 ⑥ 보류 해제 · O261-B ㉮ [5] 채택) — FACT 소유자 = GN_DW_ADMIN ⇒ 열을 DDL 쪽에서 먼저 추가
--   정본 = /03_top-down_gold/06_DDL.sql FACT_AD_PERFORMANCE 블록 맨 끝 2열 · MKTG_MAP_METHOD 값 UPPER_NAME 추가
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD COLUMN IF NOT EXISTS UPPER_CAMPAIGN_CD VARCHAR
    COMMENT '상위 캠페인코드 [VIDEO 전용] — 원천 상위캠페인 값 중 코드형(U#### · CRM 상위캠페인코드). 이름형 행·그 밖 원천 = NULL.';
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD COLUMN IF NOT EXISTS UPPER_CAMPAIGN_NM VARCHAR
    COMMENT '상위 캠페인명 [VIDEO 전용] — 원천 상위캠페인 값 중 이름형(2026-05 이전 행). 코드형은 UPPER_CAMPAIGN_CD · 그 밖 원천 = NULL.';
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ALTER COLUMN MKTG_MAP_METHOD
    COMMENT '마케팅캠페인 귀속 경로 NAME(대행사 캠페인명 일치)·UTM(UTM as-of 규칙)·CREATIVE_MAP(O232 소재 매핑표 · MKTG 수준)·UPPER_CODE(O238 영상 상위캠페인코드 → 하위 캠페인 마케팅캠페인 1:1)·UPPER_NAME(O262 영상 이름형 상위캠페인 = 마케팅캠페인명 유일 일치)·NONE(미매핑 SK=0).';

-- MANUAL: [D1 다음] dbt 재배포 후 build (에이전트는 실행하지 않는다 · R4-1)
--   /10_dbt_pipeline/01_deploy_dbt_project.sql 로 재배포 →
--   build --select AGENCY_AD_PERFORMANCE+
--   (+ = AGENCY_AD_DIGITAL · FACT_AD_PERFORMANCE · 그 하류 WIDE_AD_* 까지)

-- [D2] 대사 (백필 없음 · 같은 원천이면 아래가 build 전 값과 같아야 한다)
--   ① VIDEO 분리 등식 — n_cd + n_nm = build 전 UPPER_CAMPAIGN_NM 채움 · n_both = 0 · 비VIDEO 채움 = 0
SELECT AD_SOURCE_TYPE,
       COUNT(*)                                                           AS n_rows,
       COUNT(UPPER_CAMPAIGN_CD)                                           AS n_cd,
       COUNT(UPPER_CAMPAIGN_NM)                                           AS n_nm,
       COUNT_IF(UPPER_CAMPAIGN_CD IS NOT NULL AND UPPER_CAMPAIGN_NM IS NOT NULL) AS n_both,
       COUNT_IF(UPPER_CAMPAIGN_CD IS NOT NULL
                AND NOT REGEXP_LIKE(UPPER_CAMPAIGN_CD, '^U[0-9]+$'))      AS n_cd_bad_shape,
       COUNT_IF(REGEXP_LIKE(UPPER_CAMPAIGN_NM, '^U[0-9]+$'))              AS n_nm_code_shaped
FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE
GROUP BY 1
ORDER BY 1;
--   ② FACT 매핑 경로별 행수 불변([D0-b] 와 동일 · [5] 미적용 시)
SELECT AD_SOURCE_TYPE, MKTG_MAP_METHOD, COUNT(*) AS n_rows
FROM GN_DW.GOLD.FACT_AD_PERFORMANCE
GROUP BY 1, 2
ORDER BY 1, 2;
--   ③ 열 실재
SELECT column_name, data_type, comment
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SILVER' AND table_name = 'AGENCY_AD_PERFORMANCE'
  AND column_name IN ('UPPER_CAMPAIGN_CD', 'UPPER_CAMPAIGN_NM');
