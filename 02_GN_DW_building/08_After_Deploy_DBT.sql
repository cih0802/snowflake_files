-- DBT 생성 후 진행
-- snow://workspace/USER$.PUBLIC."snowflake_files"/versions/head/10_dbt_pipeline/deploy_dbt_project.sql
-- OPS 스키마 + DBT PROJECT 실행권(EXECUTE DBT PROJECT = USAGE ON DBT PROJECT) + run history 조회(MONITOR)
-- (DBT PROJECT 소유 = GN_DW_ADMIN — Phase 4 에서 ADMIN 이 CREATE DBT PROJECT 로 직접 생성)
GRANT USAGE   ON SCHEMA GN_DW.OPS                    TO ROLE GN_DW_ENGINEER;
GRANT USAGE   ON DBT PROJECT GN_DW.OPS.DW_PIPELINE   TO ROLE GN_DW_ENGINEER;
GRANT MONITOR ON DBT PROJECT GN_DW.OPS.DW_PIPELINE   TO ROLE GN_DW_ENGINEER;

/* =====================================================================
   E. SERVING 스키마 소비 권한 (P7 serving_separation) — SV·Agent 배치 계층
      SERVING 스키마 자체는 §B.5(3)에서 GN_DW_ADMIN 이 생성(소유=ADMIN).
      GOLD는 cross-schema 참조(SERVING→GOLD 단방향).
   ===================================================================== */
USE ROLE GN_DW_ADMIN;

-- E.1 SERVING 소비 권한: ENGINEER USAGE / 소비 3역할 USAGE
GRANT USAGE ON SCHEMA GN_DW.SERVING TO ROLE GN_DW_ENGINEER;
GRANT USAGE ON SCHEMA GN_DW.SERVING TO ROLE GN_DW_ANALYST;
GRANT USAGE ON SCHEMA GN_DW.SERVING TO ROLE GN_DW_VIEWER;
GRANT USAGE ON SCHEMA GN_DW.SERVING TO ROLE GN_DW_SERVICE;

-- ⚠️ SV·Agent object USAGE는 FUTURE grant 미지원(USAGE ON FUTURE SEMANTIC VIEWS = SQL 컴파일 오류).
--    → SV/Agent별 USAGE는 3·5단계 CREATE 직후 대상 객체에 명시 부여한다:
--        GRANT USAGE ON SEMANTIC VIEW GN_DW.SERVING.<SV> TO ROLE GN_DW_ANALYST; (VIEWER/SERVICE 동일)
--        GRANT USAGE ON AGENT GN_DW.SERVING.<AGENT> TO ROLE GN_DW_ANALYST; (VIEWER/SERVICE 동일)

/* =====================================================================
   F. CoWork object (Snowflake Intelligence) — Agent 가시성 큐레이션
      계정당 1개·고정명 SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT.
      구 SNOWFLAKE_INTELLIGENCE.AGENTS 스키마는 deprecated → 미사용.
   ===================================================================== */
USE ROLE ACCOUNTADMIN;

CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- ADMIN이 5·6단계에서 ADD AGENT 할 수 있도록 MODIFY 위임
GRANT MODIFY ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE GN_DW_ADMIN;

-- 소비 역할에 CoWork object 가시성(USAGE)
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE GN_DW_ANALYST;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE GN_DW_VIEWER;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE GN_DW_SERVICE;

-- 참고: Cortex 사용 권한(SNOWFLAKE.CORTEX_USER)은 기본 PUBLIC에 부여되어 있어 소비 역할이 상속.
--       선택적 제한이 필요하면 7단계에서 CORTEX_USER 회수 후 CORTEX_AGENT_USER 명시 부여.

/* =====================================================================
   G. SERVING helper 뷰 — SV fan-out 차단용 (04_SV_설계.md §0.1)
      소유 = GN_DW_ADMIN. SV relationship에서 이 뷰를 logical table로 참조.
   ===================================================================== */
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- G.1 DIM_MONTH: 월팩트(FMM·FBD·FTG_D·FTG_B) 시간차원 — DIM_DATE 직접 조인 시 28~31× fan-out 방지
CREATE OR REPLACE VIEW GN_DW.SERVING.DIM_MONTH
  COMMENT = 'GOLD.DIM_DATE에서 월 grain DISTINCT 추출 — 월팩트 시간차원(fan-out 차단). PK=MONTH_KEY.'
AS
SELECT DISTINCT
    MONTH_KEY,
    YEAR,
    MONTH,
    QUARTER
FROM GN_DW.GOLD.DIM_DATE
WHERE MONTH_KEY IS NOT NULL;

-- G.2 DIM_MEMBER_CURRENT: SCD2 현재행만 — 회원당 다버전 fan-out 방지
--   🔴 [2026-08-04 O27 반영] 종전 이 뷰는 `NEW_EXISTING_FLAG`·`LAST_CAMPAIGN`·`CURRENT_SPONSORSHIP`
--      3컬럼을 SELECT 했으나, O27 이 `GOLD.DIM_MEMBER` 에서 **DROP** 한 컬럼이라
--      **이 문장이 `invalid identifier` 로 실패**했다(2026-08-04 실측 확인).
--      → 3컬럼 제거. SV 는 이 3컬럼을 참조하지 않으므로(05_SV_DDL.sql 실측 0건) 소비 영향 없다.
--      DROP 사유: 시점귀속(#113)→정소재지 FMM · 대표규칙 O8 미결 · 동시 다중후원 정상.
--   ⚠️ O27 신규 4컬럼(AREA_CD·AGE·PREV_MBER_STAT_CD·PREV_MEMBER_STATUS_NAME)은 **의도적으로 미노출**이다
--      — SV 가 사용하지 않는다. 필요해지면 여기와 05_SV_DDL.sql 을 함께 고친다.
--   ⚠️ `GOLD.DIM_MEMBER_CURRENT`(dbt 모델 소유, DEC-27 §17-A)와 **다른 객체**다. 역할 분리:
--        · 본 뷰(SERVING) = **SV 전용** fan-out 차단 논리테이블(05_SV_DDL.sql 4곳 참조)
--        · GOLD 판          = **분석가 기본 진입점**(전건 NULL 컬럼 미노출 · 감사컬럼 포함)
--      두 판의 컬럼 구성은 의도적으로 다르다 — 한쪽만 고치지 말 것.
CREATE OR REPLACE VIEW GN_DW.SERVING.DIM_MEMBER_CURRENT
  COMMENT = 'GOLD.DIM_MEMBER SCD2 현재행(IS_CURRENT=TRUE)만 추출 — 1:1 회원조인(fan-out 차단). PK=MEMBER_DK. SV 전용 — 분석가용은 GOLD.DIM_MEMBER_CURRENT.'
AS
SELECT
    MEMBER_SK,
    MEMBER_DK,
    -- [2026-08-03 O26] 코드=BRONZE 원천명 / 라벨=분석 용어. GENDER→SEX · MEMBER_STATUS→MBER_STAT_CD
    --   · MEMBER_TYPE→MBER_DIV_CD · ENROLL_PATH→JOIN_PATH_CD. SEX_NM(CM013 원천 라벨) 신설.
    SEX,
    SEX_NM,
    GENDER_NAME,
    REGION,
    AGE_BAND,
    MBER_STAT_CD,
    MBER_DIV_CD,
    MEMBER_TYPE_NAME,
    MEMBER_STATUS_NAME,
    MEMBER_STATUS_GROUP,
    FIRST_JOIN_DATE,
    FIRST_CAMPAIGN,
    JOIN_PATH_CD,
    ENROLL_PATH_NAME,
    FIRST_SPONSORSHIP,
    LAST_STOP_DATE,
    EFFECTIVE_FROM
FROM GN_DW.GOLD.DIM_MEMBER
WHERE IS_CURRENT = TRUE;

-- G.3 소비 권한: helper 뷰에 SELECT (SV caller가 접근)
GRANT SELECT ON VIEW GN_DW.SERVING.DIM_MONTH          TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.DIM_MONTH          TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.DIM_MONTH          TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.DIM_MEMBER_CURRENT TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.DIM_MEMBER_CURRENT TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.DIM_MEMBER_CURRENT TO ROLE GN_DW_SERVICE;

-- =====================================================================
-- 0단계 완료 — WH 3 · 역할 6+계층 · WH/스키마 grant · SERVING 스키마 · CoWork object · helper 뷰 2.
-- 다음: 05_SV_DDL.sql(SV **6종** + FACT_AD_COMBINED)
--       → 09_1_AGENT_생성.sql(Agent 껍데기 2) → 09_2_AGENT_버전업.sql(스펙 본문) ★필수
-- 🔴 [2026-08-04 O36 교정] 종전 'SV 5'는 SV_AD 신설 이전 수치이고, `09_AGENT_spec_구현.sql` 은
--    [DEPRECATED 2026-07-31] 스텁이다. `09_2` 를 빼면 Agent 가 도구 0개로 남는다.
--    전체 순서 정본 = 06_RUNBOOK.md §11.2-C(신규 계정) · §11.2-B(기존 계정 복구)
-- =====================================================================
