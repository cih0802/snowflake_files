-- =============================================================================
-- Purpose    : O258 라벨 매핑 seed 4종 SILVER 테이블 선생성 (기존 환경 갱신)
-- Target     : TABLE GN_DW.SILVER.MAP_BUDGET_PROCEDURE, TABLE GN_DW.SILVER.MAP_SPONSORSHIP_GROUP4, TABLE GN_DW.SILVER.MAP_EXT_DATA_TYPE, TABLE GN_DW.SILVER.MAP_SERVICE_GROUP_RULE
-- Run order  : 기존 환경 갱신 #33
-- Depends on : SCHEMA GN_DW.SILVER
-- Issue      : O258
-- =============================================================================
-- 왜 이 파일이 필요한가
--   GN_DW_DBT 는 SILVER·GOLD 에 CREATE TABLE 권한이 없다(07_ENVIRONMENT_RBAC_setup.sql §D.9 설계 · 구조 = DDL · 데이터 = dbt).
--   ⇒ seed 테이블도 DDL 이 먼저 만든다(37_DEPLOY_ORG_SUCCESSION.sql 의 GOLD.ORG_SUCCESSION_MANUAL 과 같은 방식).
--   이 단계를 건너뛰고 dbt seed 를 돌리면 003001 「must have CREATE TABLE granted on SCHEMA GN_DW.SILVER」 로 실패한다.
--   정본 = /04_silver_design/08_SILVER_테이블DDL_20260714.sql 끝의 같은 4블록(아래는 그 사본 · IF NOT EXISTS · 멱등).
--   WARN: 08 SILVER DDL 파일 전체를 재실행하지 마라(CREATE OR REPLACE ⇒ SILVER 전량 비워짐 · 운영계 백필 금지 R2-9).
--   DBT 의 DML 권한(SELECT·INSERT·DELETE·TRUNCATE)은 07 의 FUTURE TABLES GRANT 가 자동 부여한다 ⇒ 추가 GRANT 불요.
-- =============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [D1] seed 테이블 4종
CREATE TABLE IF NOT EXISTS GN_DW.SILVER.MAP_BUDGET_PROCEDURE (
    SRC_LABEL           VARCHAR         COMMENT '예산 편성 차수 원천 라벨(ERP·CRM 사업목표 BDGT_PRCD_NM)',
    PRCD_STD            VARCHAR         COMMENT '표준 차수(연사업·추가경정)',
    PRCD_SEQ            NUMBER(2,0)     COMMENT '차수 순번(1 연사업 · 2 추가경정) — FACT_BUDGET* 최신 편성 차수 판정',
    TARGET_TYPE         VARCHAR         COMMENT '사업목표 유형(당초·추경) — CRM_BIZ_TARGET.TARGET_TYPE',
    NOTE                VARCHAR         COMMENT '비고'
) COMMENT = '예산 편성 차수 라벨 매핑. [Grain: SRC_LABEL]. [주의: dbt seed 적재 · CSV 를 고친다]. [원천: 10_dbt_pipeline/seeds/MAP_BUDGET_PROCEDURE.csv].';

CREATE TABLE IF NOT EXISTS GN_DW.SILVER.MAP_SPONSORSHIP_GROUP4 (
    SRC_LABEL           VARCHAR         COMMENT '후원사업 그룹 코드명(CM003 DTL_CD_NM)',
    GROUP4_NAME         VARCHAR         COMMENT '4그룹(국내·결연·해외프로젝트·기타) — DIM_SPONSORSHIP.SPONSORSHIP_GROUP4_NAME',
    NOTE                VARCHAR         COMMENT '비고(결정 근거)'
) COMMENT = '후원사업 4그룹 접기 매핑(O190 F-2). [Grain: SRC_LABEL]. [주의: dbt seed 적재 · 없는 라벨은 4그룹 NULL]. [원천: 10_dbt_pipeline/seeds/MAP_SPONSORSHIP_GROUP4.csv].';

CREATE TABLE IF NOT EXISTS GN_DW.SILVER.MAP_EXT_DATA_TYPE (
    SOURCE_TABLE        VARCHAR         COMMENT '외부 적재 원천 테이블명(SILVER)',
    SRC_LABEL           VARCHAR         COMMENT 'DATA_TYPE_NM 수기 라벨',
    DATA_TYPE_STD       VARCHAR         COMMENT '구분 표준값',
    IS_FORECAST         BOOLEAN         COMMENT '일반 예측행 여부(회비예측 전용 · 개발목표는 NULL)',
    NOTE                VARCHAR         COMMENT '비고'
) COMMENT = '외부 적재 부서 집계 구분 라벨 매핑. [Grain: SOURCE_TABLE × SRC_LABEL]. [주의: dbt seed 적재 · 라벨 개명 시 행 추가]. [원천: 10_dbt_pipeline/seeds/MAP_EXT_DATA_TYPE.csv].';

CREATE TABLE IF NOT EXISTS GN_DW.SILVER.MAP_SERVICE_GROUP_RULE (
    SERVICE_GROUP_CD    VARCHAR         COMMENT '서비스 그룹 코드',
    SERVICE_GROUP_NAME  VARCHAR         COMMENT '서비스 그룹명',
    MATCH_BASIS         VARCHAR         COMMENT '판정 근거 CODE(MS049 상위코드) · TITLE(발송 제목 ILIKE)',
    SVC_UPPER_CD        VARCHAR         COMMENT 'CODE 판정 MS049 상위코드(선행 0 보존 · VARCHAR) — TITLE 이면 NULL',
    TITLE_PATTERN       VARCHAR         COMMENT 'TITLE 판정 ILIKE 패턴 — CODE 이면 NULL',
    NOTE                VARCHAR         COMMENT '비고'
) COMMENT = '서비스 그룹 판정 규칙(O206 A안). [Grain: 규칙 1행]. [주의: dbt seed 적재 · 제목이 바뀌면 TITLE 행 추가]. [원천: 10_dbt_pipeline/seeds/MAP_SERVICE_GROUP_RULE.csv].';

-- [D1 확인] 소유자 = GN_DW_ADMIN · GN_DW_DBT 권한(기대 = DELETE·INSERT·SELECT·TRUNCATE)
SHOW GRANTS ON TABLE GN_DW.SILVER.MAP_BUDGET_PROCEDURE;
SHOW GRANTS ON TABLE GN_DW.SILVER.MAP_SERVICE_GROUP_RULE;

-- ============================================================================
-- WARN: [D2] MANUAL: dbt 재배포 + seed → build — 사용자가 실행한다(dbt 정지점 · R4-1)
--   ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
--     ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
--   USE ROLE GN_DW_DBT;
--   USE WAREHOUSE GN_DW_ETL_WH;
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='seed --select MAP_BUDGET_PROCEDURE MAP_SPONSORSHIP_GROUP4 MAP_EXT_DATA_TYPE MAP_SERVICE_GROUP_RULE';
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select MAP_BUDGET_PROCEDURE+ MAP_SPONSORSHIP_GROUP4+ MAP_EXT_DATA_TYPE+ MAP_SERVICE_GROUP_RULE+ FACT_MESSAGE_DISPATCH+';
-- ============================================================================

-- [D3] 대사 — seed 행수(기대 = CSV 데이터 행수 3 · 7 · 6 · 11)
SELECT 'MAP_BUDGET_PROCEDURE' AS t, COUNT(*) AS n FROM GN_DW.SILVER.MAP_BUDGET_PROCEDURE
UNION ALL SELECT 'MAP_SPONSORSHIP_GROUP4', COUNT(*) FROM GN_DW.SILVER.MAP_SPONSORSHIP_GROUP4
UNION ALL SELECT 'MAP_EXT_DATA_TYPE', COUNT(*) FROM GN_DW.SILVER.MAP_EXT_DATA_TYPE
UNION ALL SELECT 'MAP_SERVICE_GROUP_RULE', COUNT(*) FROM GN_DW.SILVER.MAP_SERVICE_GROUP_RULE;
