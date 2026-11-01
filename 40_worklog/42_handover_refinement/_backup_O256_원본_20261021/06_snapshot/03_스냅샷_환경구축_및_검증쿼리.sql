-- LLM-METADATA
-- doc_id: GN_DW_SNAPSHOT_SETUP_AND_VERIFICATION_SQL
-- doc_role: GN_DW dbt Snapshot 스키마 구축, 마트 DDL 선행 적용 및 무결성 검증 쿼리 모음
-- project: GN_DW (굿네이버스)
-- created: 2026-09-09
-- created_by: TRIALADMIN
-- index: 20_issue/00_INDEX_이슈원장.md
-- source_refs:
--   - 06_snapshot/01_스냅샷_아키텍처_및_네이밍룰.md
--   - 06_snapshot/02_스냅샷_파이프라인_구축_작업계획.md
-- END-METADATA

-- ============================================================================
-- [GN_DW] dbt Snapshot 환경 구축, DDL 선행 적용 및 검증 SQL 모음
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Snowflake SNAPSHOT 전용 스키마 생성 및 RBAC 권한 설정
--    (정본 원칙: 02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql 소유 모델 준수)
--    - 소유자: GN_DW_ADMIN (처음부터 ADMIN 역할로 직접 생성하여 생성 즉시 ADMIN 소유)
--    - ENGINEER: dbt snapshot 파이프라인 테이블 생성 및 적재/갱신 권한
--    - 소비 역할(ANALYST/VIEWER/SERVICE): 미부여 (스냅샷은 내부 ETL/이력 원천이며,
--      소비자는 완성된 GOLD/SERVING 마트의 Two-tier 컬럼을 통해 소비)
-- ----------------------------------------------------------------------------
USE ROLE GN_DW_ADMIN;

-- (1) SNAPSHOT 스키마 직접 생성 (생성 시점부터 GN_DW_ADMIN 소유)
CREATE SCHEMA IF NOT EXISTS GN_DW.SNAPSHOT
  COMMENT = 'dbt Snapshot 전용 이력 보존 스키마 (SCD Type 2 영구 보존 영역)';

-- (2) ADMIN 및 ENGINEER 역할 권한 부여 (소비 역할 제외 — 최소 권한 원칙 준수)
GRANT ALL PRIVILEGES ON SCHEMA GN_DW.SNAPSHOT TO ROLE GN_DW_ADMIN;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA GN_DW.SNAPSHOT TO ROLE GN_DW_ADMIN;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA GN_DW.SNAPSHOT TO ROLE GN_DW_ADMIN;

GRANT USAGE, CREATE TABLE ON SCHEMA GN_DW.SNAPSHOT TO ROLE GN_DW_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA GN_DW.SNAPSHOT TO ROLE GN_DW_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA GN_DW.SNAPSHOT TO ROLE GN_DW_ENGINEER;

-- 스키마 소유자 및 권한 확인
SHOW SCHEMAS LIKE 'SNAPSHOT' IN DATABASE GN_DW;
SHOW GRANTS ON SCHEMA GN_DW.SNAPSHOT;


-- ----------------------------------------------------------------------------
-- 2. GOLD 마트 DDL 선행 적용 (Two-tier 캠페인명 컬럼 추가)
-- ----------------------------------------------------------------------------
ALTER TABLE GN_DW.GOLD.DIM_MEMBER_ACQUISITION 
  ADD COLUMN IF NOT EXISTS ACQ_CAMPAIGN_NAME_AT_ACQ VARCHAR(300) 
  COMMENT '회원 획득 당시 캠페인명 (Snapshot 기반 시점 동결)';

-- 컬럼 추가 상태 확인
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    CHARACTER_MAXIMUM_LENGTH, 
    COMMENT
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'GOLD'
  AND TABLE_NAME = 'DIM_MEMBER_ACQUISITION'
  AND COLUMN_NAME LIKE '%CAMPAIGN_NAME%';


-- ----------------------------------------------------------------------------
-- 3. 원천 마스터 복합키 고유성 사전 검증 쿼리
-- ----------------------------------------------------------------------------
-- (1) TM_CM_MBER_DVLP_GOAL surrogate key (GOAL_SK) 고유성 검증 (일치율 100% 필수)
SELECT 
    'TM_CM_MBER_DVLP_GOAL' AS table_name,
    COUNT(*) AS total_rows, 
    COUNT(DISTINCT MD5(COALESCE(DEPT_ID,'') || '|' || COALESCE(STDYY,'') || '|' || COALESCE(STDR_MT,'') || '|' || COALESCE(MBER_DVLP_DIV_CD,''))) AS distinct_keys
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL
UNION ALL
-- (2) TC_CMMN_DTL_CD surrogate key (CMMN_DTL_CD_SK) 고유성 검증 (일치율 100% 필수)
SELECT 
    'TC_CMMN_DTL_CD',
    COUNT(*),
    COUNT(DISTINCT MD5(COALESCE(CD_ID,'') || '|' || COALESCE(DTL_CD_ID,'')))
FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD;


-- ----------------------------------------------------------------------------
-- 4. 전체 dbt Snapshot (총 11종) 실행 후 적재 및 SCD Type 2 무결성 검증 쿼리
-- ----------------------------------------------------------------------------
-- (1) SNAPSHOT 스키마 내 생성된 테이블 목록 및 행수 확인
SHOW TABLES IN SCHEMA GN_DW.SNAPSHOT;

-- (2) 전체 11개 스냅샷 테이블 초기 적재 무결성 검증 (초기 적재 시 active_rows = total_rows)
SELECT 
    'SNP_CRM_TM_CM_BRND_MNG' AS table_name, 
    COUNT(*) AS total_rows, 
    COUNT_IF(dbt_valid_to IS NULL) AS active_rows,
    COUNT_IF(dbt_valid_to IS NOT NULL) AS expired_rows
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_CM_BRND_MNG
UNION ALL
SELECT 
    'SNP_CRM_TM_RM_BPLC_MNG', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_RM_BPLC_MNG
UNION ALL
SELECT 
    'SNP_CRM_TM_CM_MBER_DVLP_GOAL', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_CM_MBER_DVLP_GOAL
UNION ALL
SELECT 
    'SNP_CRM_TM_CM_CMPGN_MNG', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_CM_CMPGN_MNG
UNION ALL
SELECT 
    'SNP_CRM_TM_CM_DEPT_INFO', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_CM_DEPT_INFO
UNION ALL
SELECT 
    'SNP_CRM_TM_MS_EVENT', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_MS_EVENT
UNION ALL
SELECT 
    'SNP_CRM_TM_MS_EMAIL_TMPLAT_MNG', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_MS_EMAIL_TMPLAT_MNG
UNION ALL
SELECT 
    'SNP_CRM_TM_MS_CRMN', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_MS_CRMN
UNION ALL
SELECT 
    'SNP_CRM_TC_CMMN_CD', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TC_CMMN_CD
UNION ALL
SELECT 
    'SNP_CRM_TM_CM_SPNSR_BSNS_INFO', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_CM_SPNSR_BSNS_INFO
UNION ALL
SELECT 
    'SNP_CRM_TC_CMMN_DTL_CD', 
    COUNT(*), 
    COUNT_IF(dbt_valid_to IS NULL),
    COUNT_IF(dbt_valid_to IS NOT NULL)
FROM GN_DW.SNAPSHOT.SNP_CRM_TC_CMMN_DTL_CD;


-- ----------------------------------------------------------------------------
-- 5. GOLD.DIM_MEMBER_ACQUISITION Two-tier 배선 및 Cold Start 결손 방어 검증 쿼리
-- ----------------------------------------------------------------------------
-- Two-tier 컬럼 비교 및 과거 가입자 결손률(0% 목표) 검증
SELECT 
    COUNT(*) AS total_members,
    COUNT(ACQ_CAMPAIGN_NAME) AS current_campaign_cnt,
    COUNT(ACQ_CAMPAIGN_NAME_AT_ACQ) AS at_acq_campaign_cnt,
    COUNT_IF(ACQ_CAMPAIGN_NAME_AT_ACQ IS NULL AND ACQ_CAMPAIGN_SK > 0) AS missing_acq_campaign_cnt,
    ROUND(COUNT(ACQ_CAMPAIGN_NAME_AT_ACQ) / NULLIF(COUNT(ACQ_CAMPAIGN_NAME), 0) * 100, 2) AS match_rate_pct
FROM GN_DW.GOLD.DIM_MEMBER_ACQUISITION;

-- 샘플 데이터 대조 조회 (최신 캠페인명 vs 가입 당시 스냅샷 캠페인명)
SELECT 
    MEMBER_DK,
    ACQ_DATE_SK,
    ACQ_CAMPAIGN_SK,
    ACQ_CAMPAIGN_NAME AS CURRENT_CAMPAIGN_NAME,
    ACQ_CAMPAIGN_NAME_AT_ACQ AS CAMPAIGN_NAME_AT_ACQ
FROM GN_DW.GOLD.DIM_MEMBER_ACQUISITION
WHERE ACQ_CAMPAIGN_SK > 0
LIMIT 100;


-- ----------------------------------------------------------------------------
-- 6. 일 배치 운영 모니터링: 스냅샷 변경 이력(SCD Type 2) 발생 감지 쿼리
-- ----------------------------------------------------------------------------
-- 최근 N일 내 변경 이력이 발생하여 만료된 레코드(과거 버전) 및 신규 버전 감지
SELECT 
    'SNP_CRM_TM_CM_CMPGN_MNG' AS table_name,
    CMPGN_CD AS key_id,
    CMPGN_NM AS val_nm,
    dbt_valid_from,
    dbt_valid_to,
    dbt_updated_at
FROM GN_DW.SNAPSHOT.SNP_CRM_TM_CM_CMPGN_MNG
WHERE dbt_valid_to IS NOT NULL
ORDER BY dbt_valid_to DESC
LIMIT 50;
