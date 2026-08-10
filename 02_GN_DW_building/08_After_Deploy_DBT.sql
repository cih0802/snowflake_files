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
   G. ⛔⛔ [2026-08-10 O55] **절 폐지 — 삭제 완료. 실행 라인 0.**
      종전 내용 = SERVING helper 뷰 3종 생성(`DIM_MONTH`·`DIM_MEMBER_CURRENT`) + 소비 3역할 SELECT GRANT.
      O54 에서 SV 9종 base 를 GOLD 정본으로 재배선했고, O55 에서 **물리 객체를 DROP** 했다.
        · `SERVING.DIM_MONTH`          → `GOLD.DIM_MONTH`(BASE TABLE · 06_DDL 소유)
        · `SERVING.DIM_MEMBER_CURRENT` → `GOLD.DIM_MEMBER_CURRENT`(BASE TABLE · dbt 소유)
        · `SERVING.FACT_AD_COMBINED`   → `GOLD.WIDE_AD_COMBINED`(VIEW · dbt 소유)
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
