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
-- 🟢 [2026-08-18] STREAMLIT 도 동일 제약(FUTURE grant 미지원)이며 앱 배포 후 개별 부여한다.
--    부여 템플릿·소유 통제(앱 소유 = GN_DW_SERVICE, caller's rights 표준)는 07 §D.7-3 참조.
--    ANALYST 의 Streamlit "저작"은 개인 Workspace 에서 수행 → SERVING 에 CREATE STREAMLIT 부여 없음(07 §D.8).

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
   G. ⛔⛔ [2026-08-10 O55] **절 폐지 — 삭제 완료. 실행 라인 0.**
      종전 내용 = SERVING helper 뷰 3종 생성(`DIM_MONTH`·구 `DIM_MEMBER_CURRENT`) + 소비 3역할 SELECT GRANT.
      O54 에서 SV 9종 base 를 GOLD 정본으로 재배선했고, O55 에서 **물리 객체를 DROP** 했다.
        · `SERVING.DIM_MONTH`          → `GOLD.DIM_MONTH`(BASE TABLE)
        · `SERVING.DIM_MEMBER_CURRENT` → `GOLD.DIM_MEMBER_CURRENT`(BASE TABLE)
        · `SERVING.FACT_AD_COMBINED`   → `GOLD.WIDE_AD_COMBINED`(VIEW · 구조·COMMENT 모두 dbt 소유)
      🔴 [2026-08-12 O64 소유주 기재 교정] 종전 이 자리는 `DIM_MONTH` 를 「06_DDL 소유」, 구 `DIM_MEMBER_CURRENT` 를
         「**dbt 소유**」로 적어 **성격이 같은 두 객체를 다르게** 기재했다(`dbt_project.yml` 소유주 표·`06_DDL.sql` 과도 어긋났다).
         실측 = 둘 다 `06_DDL.sql` 에 `CREATE OR REPLACE TABLE` 로 선언돼 있고(96행·182행) 둘 다 dbt dim 모델이 있다.
         ⇒ 정확한 서술은 **소유가 두 층으로 갈린다**는 것이다:
           · **구조·타입·제약·COMMENT = `06_DDL.sql` 소유** — dbt 는 `incremental` + `+full_refresh:false` 라 구조를 덮지 않고,
             `persist_docs` 를 쓰지 않으므로 build 가 COMMENT 를 덮지 않는다(O63 실측 = 파일↔라이브 634/634 일치).
           · **데이터 적재 = dbt 모델**(`models/gold/dim/`).
         ⚠️ 따라서 GOLD **테이블** COMMENT 를 고칠 때는 `06_DDL.sql` + `ALTER TABLE … ALTER COLUMN … COMMENT` 이고
            **`dbt build` 는 정지점이 아니다**. GOLD **뷰**만 `_wide_schema.yml` + build 가 유일 경로다(O63).
      🔴 DROP 전 사전 검증(3원 교차): SV base 참조 0(`INFORMATION_SCHEMA.SEMANTIC_TABLES`
         `BASE_TABLE_SCHEMA='SERVING'`) · 뷰 정의 참조 0(자기 제외) · `ACCOUNT_USAGE.OBJECT_DEPENDENCIES` 0.
      🔴 DROP 후 판정: SERVING 잔존 helper **0** · SV **9종·논리테이블 32건 전건 GOLD 유지**.
      ⚠️ 롤백 근거 DDL 은 `_archive/O55_helper_rollback_20260810/`(166행)에 채취해 뒀다 —
         되살릴 필요가 생기면 SV base 도 함께 되돌려야 한다(둘은 한 쌍이다).
      ⚠️ 신규 계정 재현에서 이 절은 **없는 것이 정상**이다. 선행 조건은 `dbt build` 뿐이다.
   ===================================================================== */

-- =====================================================================
-- 0단계 완료 — WH 3 · 역할 6+계층 · WH/스키마 grant · SERVING 스키마 · CoWork object.
--   ⛔ [2026-08-10 O54·O55] 종전 이 줄 끝의 「helper 뷰 2」는 완료 요건에서 **빠졌다** — §G 절이 삭제됐다.
-- 다음: 05_1~05_9_SV_DDL_*.sql(SV **9종** · 각 파일 독립 실행 · base 전건 GOLD)
--   ⛔ [2026-08-10 O54] 종전 「05_1~05_7 · SV 6종 · `05_7` 에 FACT_AD_COMBINED 동봉」은 **거짓이 됐다**
--      — SV 는 9종이고(`05_8` DEV_ACHIEVEMENT · `05_9` MEMBER_FEE 신설) `05_7` 의 helper 생성 블록은 제거됐다.
--       → 09_1_AGENT_생성.sql(Agent 껍데기 2) → 09_2_AGENT_버전업.sql(스펙 본문) ★필수
-- 🔴 [2026-08-04 O36 교정] 종전 'SV 5'는 SV_AD 신설 이전 수치이고, `09_AGENT_spec_구현.sql` 은
--    [DEPRECATED 2026-07-31] 스텁이다. `09_2` 를 빼면 Agent 가 도구 0개로 남는다.
--    전체 순서 정본 = 06_RUNBOOK.md §11.2-C(신규 계정) · §11.2-B(기존 계정 복구)
-- =====================================================================
-- drop schema gn_dw.snapshot;


/* =====================================================================
   D.9 🆕 [2026-09-28 O184] dbt 전용 롤 GN_DW_DBT — ENGINEER(사람+dbt 혼용) 분리
      설계 정본 = 99_NEXT_SESSION_조각/99_NEXT_SESSION-O0182-A.md ▣ O182-A-6 (사용자 지시)
      🔴 D.5 의 「별도 GN_DW_DBT 롤 불필요」 결정은 이 절로 **대체**된다(O182 사용자 지시).
      📏 착수 실측(xf98254 · 2026-09-28) — 설계안과 다른 점 3건:
        ㉠ GOLD WIDE 뷰 14개 · OPS store_failures 테이블 9개의 **소유자가 GN_DW_ENGINEER** 다
           (dbt 가 만든 객체 = 생성 롤 소유). 롤만 바꾸면 `create or replace view` 가 OWNERSHIP 부재로 죽는다
           ⇒ **소유권 이관(COPY CURRENT GRANTS)이 전환의 필수 단계**다(설계안에 없었다).
        ㉡ SNAPSHOT 스키마는 라이브에 **없고** snapshots 는 `+enabled: false` ⇒ 권한 미부여(D.6-3 과 같은 보류).
        ㉢ SILVER merge 모델 **0건**(grep 실측) ⇒ SILVER UPDATE 불요 · GOLD dim(unique_key·기본 merge)만 UPDATE.
      🔴 순서 = [1] 롤·GRANT(07 §D.9 · 프로젝트 생성 전) → [1-e] 프로젝트 GRANT → [2] 소유권 이관 → [3] profiles.yml role 전환 → [4] 사용자 dbt build.
         [2] 이후 ENGINEER 로 dbt 를 돌리면 WIDE 뷰 재생성이 실패한다 ⇒ [2]·[3] 은 같은 세션에 끝낸다.
      🟢 롤백 = profiles.yml role 을 GN_DW_ENGINEER 로 되돌리고 아래 [2] 를 TO ROLE GN_DW_ENGINEER 로 재실행.
      🔴 ENGINEER 축소는 이 절에 없다 — 전환 build PASS 확인 **후** 별도 단위(O182-A-6 ㉢).
   ===================================================================== */
-- [1] 🔴 [2026-10-01 O193] 롤 생성·[1-a]~[1-d] GRANT 는 **07_ENVIRONMENT_RBAC_setup.sql §D.9 로 이동**했다
--     (CREATE DBT PROJECT 가 생성 시점에 GN_DW_DBT 로 실행되므로 프로젝트 생성 **전**에 필요). 이 파일에는 프로젝트 의존분만 남긴다.

USE ROLE GN_DW_ADMIN;  -- 🔴 [O193] 종전엔 위 [1] 블록이 지정했다 · 이동 후 명시
-- [1-e] 배포 dbt 프로젝트 실행(EXECUTE DBT PROJECT)
GRANT USAGE, MONITOR ON DBT PROJECT GN_DW.OPS.DW_PIPELINE TO ROLE GN_DW_DBT;

-- [2] 소유권 이관(㉠) — dbt 생성 객체만(ENGINEER 소유 GOLD 뷰 · OPS 테이블). ADMIN 소유 DDL 테이블은 건드리지 않는다.
--     대상은 실행 시점에 INFORMATION_SCHEMA 로 다시 뽑는다(목록 하드코딩 금지 · O184 실행기 = 동적 생성).
--     형태: GRANT OWNERSHIP ON VIEW  GN_DW.GOLD.<WIDE_*> TO ROLE GN_DW_DBT COPY CURRENT GRANTS;
--           GRANT OWNERSHIP ON TABLE GN_DW.OPS.<store_failures> TO ROLE GN_DW_DBT COPY CURRENT GRANTS;

/*
-- [3] 🆕 [2026-09-28 O185] ENGINEER 축소 — 전환 검증 후(DW_PIPELINE parse·compile·build 전건 GN_DW_DBT SUCCESS ·
--     build PASS 543 · WARN 21 · ERROR 0). ENGINEER 는 사람 작업(SILVER 개발 · GOLD/BRONZE 읽기)만 남긴다.
--     📏 사전 실측 = ENGINEER 소유 태스크·프로시저 0 · GOLD DML 이력은 전환 전 dbt 실행분뿐.
--     🟢 부수 종결 = O181-B ▣2-7 「GRANT UPDATE 처분」(SILVER UPDATE ALL/FUTURE 회수 · merge 모델 0건 실측).
--     🔴 DBT_PROJECT USAGE 회수 = 「틀린 롤로 배포본 실행」 재발 차단(O184 실사고: 구 배포본이 ENGINEER 로 돌았다).
USE ROLE GN_DW_ADMIN;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES    IN SCHEMA GN_DW.GOLD FROM ROLE GN_DW_ENGINEER;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA GN_DW.GOLD FROM ROLE GN_DW_ENGINEER;
REVOKE CREATE VIEW ON SCHEMA GN_DW.GOLD FROM ROLE GN_DW_ENGINEER;
REVOKE UPDATE ON ALL TABLES    IN SCHEMA GN_DW.SILVER FROM ROLE GN_DW_ENGINEER;
REVOKE UPDATE ON FUTURE TABLES IN SCHEMA GN_DW.SILVER FROM ROLE GN_DW_ENGINEER;
REVOKE CREATE TABLE ON SCHEMA GN_DW.OPS             FROM ROLE GN_DW_ENGINEER;
REVOKE CREATE TABLE ON SCHEMA GN_DW.dbt_test__audit FROM ROLE GN_DW_ENGINEER;
REVOKE USAGE, MONITOR ON DBT PROJECT GN_DW.OPS.DW_PIPELINE FROM ROLE GN_DW_ENGINEER;
--     🔴 이 절 이후 D.2·D.3·D.5·D.6 의 ENGINEER GRANT 중 위 항목은 **이력**이다(재실행하면 되살아난다 — 재구축 시 D.9 를 마지막에 돌려라).
*/


/* =====================================================================
   [4] 🆕 [2026-10-02 O198] 월마감 + ML 파이프라인 실행 — GN_DW_LOADER
      출처 = 임시 파일 `ML스키마에 LOADER롤추가_작업후삭제.sql` §2·§3 (이 절로 편입 · 원 파일은 삭제 대상).
      🔴 선행 = 07번 §D.5-B(LOADER 프로시저·ML·WH 권한) · BRONZE 적재 완료 · BRONZE_CRM/SILVER/ML 프로시저 생성 완료.
      🔴 기준월은 **실행할 때마다 바꾼다** — 아래 '202609' 는 예시다(마감 대상 월 YYYYMM).
      ⚠️ SP_EXEC_MONTH_END 는 SILVER 집계(ANNUAL_* · MM_SPNSR_CLS_AGGR_DATA)와 ML 예측결과(ML_RST_DATA_*)를 다시 쓴다
         ⇒ dbt build 와 동시에 돌리지 말 것(같은 SILVER 를 읽고 쓴다).
      🔴 [2026-10-03 O200-D 실측 · 계정 pw69582(개발계)] 이 절은 **이 계정에서 실행할 수 없다**.
         · `SP_EXEC_MONTH_END` 부재(`SHOW USER PROCEDURES IN DATABASE GN_DW` = MSTR 13종뿐) · `ML_PROCEDURE_LOG` 부재.
         · 이유 = 이관 범위가 ML **결과 테이블 12종**뿐이고 원천 프로시저·로그는 인도되지 않았다(O198 결정).
         ⇒ O198-C ⑦ 「첫 실행 권한 오류 시 LOADER DML 부여」는 **전제 미충족**이다 — 권한을 미리 만들지 않는다.
            프로시저가 인도되는 계정(운영)에서 이 절을 처음 돌릴 때 ⑦ 을 판정한다(EXECUTE AS CALLER/OWNER 확인 포함).
   ===================================================================== */
/*
USE ROLE GN_DW_LOADER;
USE WAREHOUSE GN_DW_ETL_WH;

CALL GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END('202609');

-- [4-a] 실행 결과·로그 확인(최근 1시간) — STATUS 가 전건 성공이어야 하며 실패 행은 ERROR_MSG 로 원인을 본다.
--   ⚠️ LOADER 는 ML 테이블 SELECT 권한이 없다(07번 D.5 = 소비 3역할만) ⇒ 조회는 ADMIN 으로 한다.
USE ROLE GN_DW_ADMIN;
SELECT
    PROC_NAME,
    STDR_MT,
    START_TIME,
    END_TIME,
    DURATION_SEC,
    STATUS,
    ERROR_MSG
FROM GN_DW.ML.ML_PROCEDURE_LOG
WHERE START_TIME >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
ORDER BY START_TIME DESC;
*/