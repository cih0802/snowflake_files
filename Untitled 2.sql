-- A1. GN_DW 스키마 목록 (GOLD/SILVER/BRONZE 존재 확인)
SHOW SCHEMAS IN DATABASE GN_DW;

-- A2. GOLD 테이블 실존 여부 (문서: DDL 24개 중 6개 미적재 주장 → 실제 몇 개?)
SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT, BYTES
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('GOLD','SILVER')
ORDER BY TABLE_SCHEMA, TABLE_NAME;



-- B1. 배포된 dbt project 객체·버전 목록
SHOW DBT PROJECTS IN ACCOUNT;
SHOW VERSIONS IN DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE;

-- B2. GOLD 모델이 배포 버전에 포함됐는지 (컴파일만, 실행 아님)

-- C1. [G-5 하드블로커] GA4 샤드가 1일뿐인가, 전기간 입고됐나
SHOW TABLES LIKE 'events_%' IN SCHEMA GN_DW.BRONZE_GA4;

-- C2. [E-6] ERP_BIZ_TARGET 원천 0행 여부 (사업목표 FTG-B)
SELECT COUNT(*) AS erp_biz_target_rows FROM GN_DW.SILVER.ERP_BIZ_TARGET;

-- C3. [의심데이터 E / BLOCKING-2] EVENT_KEY→CRM_EVENT 고아 (참여 23%, 263,611행 주장)
SELECT COUNT(*) AS orphan_event_keys
FROM GN_DW.SILVER.CRM_EVENT_PARTICIPATION p
LEFT JOIN GN_DW.SILVER.CRM_EVENT e ON p.EVENT_KEY = e.EVENT_KEY
WHERE e.EVENT_KEY IS NULL;

-- C4(수정). [BLOCKING-1 / 의심B] 회원 마스터 고아 (MBER_NO→MEMBER_DK, 9,248명 주장)
SELECT COUNT(DISTINCT p.MBER_NO) AS orphan_members
FROM GN_DW.SILVER.CRM_EVENT_PARTICIPATION p
LEFT JOIN GN_DW.SILVER.CRM_MEMBER m ON p.MBER_NO = m.MEMBER_DK
WHERE m.MEMBER_DK IS NULL;

-- C5. [Q1/ID-활성] GA↔CRM identity 실측 채움률 (4.22% 주장)
SELECT COUNT(*) AS xref_rows,
       COUNT(DISTINCT MBER_NO) AS matched_members
FROM GN_DW.SILVER.IDENTITY_MEMBER_XREF;

-- C6. [#80/DEC-4] UNPAID_MEMBERS 모델이 이미 생성됐나 (미납회원 신설)
SHOW TABLES LIKE '%UNPAID%' IN SCHEMA GN_DW.GOLD;
SHOW VIEWS LIKE '%UNPAID%' IN SCHEMA GN_DW.GOLD;

-- C7. [A-2/Q9] 광고 _SOURCE_SYSTEM 출처구분이 실제 값으로 채워졌나
SELECT DW_SOURCE_SYSTEM, COUNT(*) 
FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE GROUP BY 1;

-- C8. GOLD WIDE VIEW 9개가 실제 존재하나 (GOLD 스키마 설명의 "WIDE VIEW 9개")
SHOW VIEWS IN SCHEMA GN_DW.GOLD;
--=======================================================================
CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
  COMMENT = 'dbt project 등 운영/툴링 객체 전용 (데이터 레이어 아님)';

CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = 'BRONZE→SILVER 32 + SILVER→GOLD 18객체. 정본 09_SILVER_적재쿼리_20260714.';

SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;

EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile';

EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.ga4+';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.crm';



SELECT SYSTEM$GET_DBT_LOG('01c5b78b-3202-f18f-0017-aaa60002303a');

-- 1) 수정분 신규 버전 등록 (= default)
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = 'fix: GA4/AGENCY/ERP 테스트 정의버그(7) + GA4_EVENT_DIM grain(1) + 참조무결성 severity:warn(9)';

-- 2) 전체 build (run + test)
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';



-- 1) 원복분(GA4_EVENT_DIM 모델 + unique 제거) 신규 버전 등록
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = 'fix: GA4_EVENT_DIM 조합 grain 원복 + unique(EVENT_NAME) 오탐 제거';

-- 2) merge 차원 stale 행 제거(정리) 후 GA4 계열 재적재
TRUNCATE TABLE GN_DW.GOLD.DIM_GA_EVENT;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.ga4+';

-- 3) 검증: 2842 복원 + FACT 정합
SELECT COUNT(*) FROM GN_DW.GOLD.DIM_GA_EVENT;   -- 기대 ~2842


-- 1) 신규/수정분 재배포
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = '순서9-C: GOLD 미작성 4종(DIM_AD_CREATIVE·DIM_BUDGET_ITEM·FACT_BUDGET·FACT_AD_PERFORMANCE) + #80 FMM UNPAID 플래그';

-- 2) 신규/수정 5종만 build(의존순 자동·테스트 포함)
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ARGS='build --select DIM_BUDGET_ITEM DIM_AD_CREATIVE FACT_BUDGET FACT_AD_PERFORMANCE FACT_MEMBER_MONTHLY';

-- 3) 적재 확인
SELECT 'DIM_AD_CREATIVE' o, COUNT(*) n FROM GN_DW.GOLD.DIM_AD_CREATIVE
UNION ALL SELECT 'DIM_BUDGET_ITEM', COUNT(*) FROM GN_DW.GOLD.DIM_BUDGET_ITEM
UNION ALL SELECT 'FACT_BUDGET', COUNT(*) FROM GN_DW.GOLD.FACT_BUDGET
UNION ALL SELECT 'FACT_AD_PERFORMANCE', COUNT(*) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE
UNION ALL SELECT 'FMM_UNPAID_EOM_true', COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY WHERE UNPAID_FLAG_EOM;


-- 1) 워크스페이스 → 스테이지 반영 후 새 버전 등록
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE ADD VERSION
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';

-- 2) WIDE 뷰만 선빌드 (COMMENT post_hook 포함)
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select tag:gold_wide';

-- 3) 전체 회귀 green 재확인
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';




-- ================================== 20260716
-- 1) 현행 버전 목록·날짜 확인 (VERSION$5가 오늘 변경 이전인지 확인)
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;

-- 2) 오늘(2026-07-15) identity 배선 포함 live 워크스페이스를 새 버전으로 추가 → VERSION$6
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION identity_wired_20260715
  FROM 'snow://workspace/user$.public."snowflake_files"/versions/live/10_dbt_pipeline';

-- 3) 검증: VERSION$6(alias identity_wired_20260715)가 생기고 LAST가 이를 가리키는지
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;


EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --target dev --select FACT_GA_BEHAVIOR WIDE_GA_BEHAVIOR'

;;


CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER (
    MEMBER_SK           NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '버전 대리키',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키(조인용)',
    GENDER              VARCHAR         COMMENT '성별(#130)',
    REGION              VARCHAR         COMMENT '지역(#131)',
    AGE_BAND            VARCHAR         COMMENT '연령대(overview). 원천: 개발/증감 테이블 AGE 스냅샷',
    MEMBER_STATUS       VARCHAR         COMMENT '회원상태(#132)',
    MEMBER_TYPE         VARCHAR         COMMENT '회원구분(05 2-1). 원천: MBER_DIV_CD(MM018 개인/기업/단체)',
    NEW_EXISTING_FLAG   VARCHAR         COMMENT '신규기존구분(#113)',
    FIRST_JOIN_DATE     DATE            COMMENT '최초가입일=회원번호 생성일(#28)',
    FIRST_CAMPAIGN      VARCHAR         COMMENT '최초캠페인(#29)',
    ENROLL_PATH         VARCHAR         COMMENT '가입경로(overview 2-1). 원천: JOIN_PATH_CD(MM014)',
    FIRST_SPONSORSHIP   VARCHAR         COMMENT '최초후원사업(회원 스냅샷). 원천: TM_MM_FDRM_MBER_SPNSR_BSNS',
    LAST_STOP_DATE      DATE            COMMENT '최종중단일(#30)',
    LAST_CAMPAIGN       VARCHAR         COMMENT '최종캠페인(#31)',
    CURRENT_SPONSORSHIP VARCHAR         COMMENT '현재후원사업(회원 스냅샷). 원천: TM_MM_FDRM_MBER_SPNSR_BSNS',
    EFFECTIVE_FROM      DATE            COMMENT 'SCD2 유효시작',
    EFFECTIVE_TO        DATE            COMMENT 'SCD2 유효종료',
    IS_CURRENT          BOOLEAN         COMMENT '현재행 여부',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 차원 (SCD2 · 회원 상태버전)';

drop schema gn_dw.silver;
drop schema gn_dw.gold;


--======================================================
--20260722
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE ADD VERSION
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';


USE ROLE GN_DW_ENGINEER;
USE WAREHOUSE GN_DW_ETL_WH;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';