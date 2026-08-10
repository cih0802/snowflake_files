-- GN_DW Cortex Agent [1/2] 껍데기 생성 — 객체·소유권·GRANT·CoWork 등록만 (스펙 본문 없음)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상
--   Agent 객체를 **최소 스펙으로 만들고** 소유권·USAGE grant·CoWork SI 등록까지 끝낸다.
--   instructions·tools·tool_resources 등 **스펙 본문은 이 파일에 두지 않는다** →
--   스펙은 정본 yaml(`cortex_project/agents/<AGENT>/agent_spec.yaml`)이며
--   적용은 `09_2_AGENT_버전업.sql` 이 담당한다.
--
--   ⚠ 이렇게 분리한 이유 = **drift 제거**. 구 09 파일은 YAML 전문을 [1-ALT]·[4-B] 네 블록에
--     사본으로 갖고 있었고 "정본 변경 시 반드시 함께 갱신"이라는 규약에 의존했다. 그 규약이
--     지켜지지 않아 **동일 유형 drift 가 4회 재발**(교훈 P23)했다. 이제 SQL 파일에 스펙 사본이
--     0개이므로 구조적으로 drift 가 불가능하다.
--
-- ▶ 실행 순서
--   02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql → dbt(BRONZE→GOLD)
--   → 05_1~05_9_SV_DDL_*.sql(SV 9종 + 각 파일 GRANT·스모크) → **본 파일** → 09_2_AGENT_버전업.sql
--   ⚠ SV 가 없으면 Agent 는 만들어지지만 질의 시 도구가 깨진다(tool_resources 가 SV 를 참조).
--
-- ▶ 언제 이 파일을 다시 실행하는가
--   · 신규 계정 재현 / Agent 를 실수로 DROP 한 경우 → 전체 실행
--   · COMMENT·PROFILE 만 바꿀 때 → [5] 만 실행(스펙 무관한 DDL 속성)
--   · 스펙(instructions·tools)을 바꿀 때 → **이 파일 아님** → 09_2 실행
--   🔴 이미 운영 중인 Agent 에 `CREATE OR REPLACE` 를 다시 쓰면 **버전 이력이 VERSION$1 로
--      초기화되고 USAGE grant·CoWork SI 등록이 파괴**된다([2][3][4] 재실행 필요).
--      운영 계정에서 스펙만 갱신하려면 반드시 09_2 를 쓴다.
--
-- ▶ 실측 근거 (2026-07-31 mq60369, AGENT_ZZ_PROBE 로 검증 후 DROP)
--   · `CREATE AGENT` 는 `FROM SPECIFICATION` 이 **필수**다(생략 불가). 다만 최소 스펙
--     `models: orchestration: auto` 만으로도 생성된다 → 껍데기 생성 성립.
--   · 생성 시 `VERSION$1` + live 가 자동 생성된다.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;


-- ============================================================================
-- [1] Agent 껍데기 생성 — 최소 스펙
--     COMMENT·PROFILE 은 spec 이 아닌 DDL 속성이라 09_2 의 버전업으로는 바뀌지 않는다.
--     따라서 이 파일이 COMMENT·PROFILE 의 정본이다.
-- ============================================================================
CREATE OR REPLACE AGENT GN_DW.SERVING.AGENT_MEMBER
  -- 🔴 [2026-08-10 O52] 종전 COMMENT 는 "SV 4종" 이었는데 `09_2` 가 도구를 **7종**으로 늘렸다.
  --   즉 이 파일만 보면 도구 수를 오인한다 — `09_1` 은 껍데기이고 정본 도구 목록은 `09_2` 다.
  --   ⇒ COMMENT 를 실제 7종으로 맞췄다(`SHOW AGENTS` 의 comment 로 노출되는 값이다).
  COMMENT = '굿네이버스 회원 도메인 분석 Agent(Phase-1). SV 7종: 월실적·상태전이·서비스발송·행사참여·획득코호트·개발목표달성·회비분해.'
  PROFILE = '{"display_name":"회원 분석","color":"#29B5E8"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  $$;

CREATE OR REPLACE AGENT GN_DW.SERVING.AGENT_OVERALL
  COMMENT = '굿네이버스 전사·재무 요약 분석 Agent(Phase-1). 예산 + 광고 실적 + 회원월실적·발송 전사 요약.'
  PROFILE = '{"display_name":"전사·예산 분석","color":"#11567F"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  $$;


-- ============================================================================
-- [2] 소유권 — 위 [1] 을 GN_DW_ADMIN 으로 실행했다면 **불요(SKIP)**
--     owner 가 ACCOUNTADMIN 으로 찍혔을 때만 아래를 실행한다(SV 9종과 소유 정합 = GN_DW_ADMIN · O55 실측).
-- ============================================================================
-- USE ROLE ACCOUNTADMIN;
-- GRANT OWNERSHIP ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
-- GRANT OWNERSHIP ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;


-- ============================================================================
-- [3] 소비 USAGE grant (소유자 GN_DW_ADMIN 이 부여)
--     ⚠ `CREATE OR REPLACE AGENT` 로 소실되므로 [1] 재실행 시 반드시 함께 재실행.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_SERVICE;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_SERVICE;


-- ============================================================================
-- [4] CoWork(Snowflake Intelligence) 연결 — 멱등 (SI object owner=ACCOUNTADMIN)
--     `ADD AGENT` 는 기등록 상태에서 재실행하면 에러이고 `IF NOT EXISTS` 는 미지원 →
--     `SHOW AGENTS IN SNOWFLAKE INTELLIGENCE` 로 사전 확인 후 분기한다(재실행 시 skipped).
--     · 제거는 `REMOVE AGENT` 가 아니라 **`DROP AGENT`**.
--     · SHOW 결과 컬럼명은 소문자 → RESULT_SCAN 에서 큰따옴표 필수.
--     · `FOR rec IN (…) DO` 커서 변수는 스크립팅 표현식에서 참조 불가 → 루프 대신 명시 분기.
--     근거·검증 상세 = 08 §4.4 · 20_issue/10_진단_원인분석.md §11-D (교훈 P26)
-- ============================================================================
USE ROLE ACCOUNTADMIN;

EXECUTE IMMEDIATE $$
DECLARE
  res STRING DEFAULT '';
BEGIN
  SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
  LET c1 INT := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
                  WHERE "database_name" = 'GN_DW' AND "schema_name" = 'SERVING'
                    AND "name" = 'AGENT_MEMBER');
  IF (c1 = 0) THEN
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
      ADD AGENT GN_DW.SERVING.AGENT_MEMBER;
    res := res || 'AGENT_MEMBER=added ';
  ELSE
    res := res || 'AGENT_MEMBER=skipped ';
  END IF;

  SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
  LET c2 INT := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
                  WHERE "database_name" = 'GN_DW' AND "schema_name" = 'SERVING'
                    AND "name" = 'AGENT_OVERALL');
  IF (c2 = 0) THEN
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
      ADD AGENT GN_DW.SERVING.AGENT_OVERALL;
    res := res || 'AGENT_OVERALL=added';
  ELSE
    res := res || 'AGENT_OVERALL=skipped';
  END IF;

  RETURN res;
END;
$$;


-- ============================================================================
-- [5] COMMENT·PROFILE 갱신 (선택) — spec 경로(09_2)로는 안 바뀌는 DDL 속성
--     ⚠ SET 절은 콤마 구분 필수. 현행값이 이미 최신이면 생략 가능(무해).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
-- ALTER AGENT GN_DW.SERVING.AGENT_MEMBER SET
--   COMMENT = '굿네이버스 회원 도메인 분석 Agent(Phase-1). SV 4종: 월실적·상태전이·서비스발송·행사참여.',
--   PROFILE = '{"display_name":"회원 분석","color":"#29B5E8"}';
-- ALTER AGENT GN_DW.SERVING.AGENT_OVERALL SET
--   COMMENT = '굿네이버스 전사·재무 요약 분석 Agent(Phase-1). 예산 + 광고 실적 + 회원월실적·발송 전사 요약.',
--   PROFILE = '{"display_name":"전사·예산 분석","color":"#11567F"}';


-- ============================================================================
-- [6] 검증
-- ============================================================================
USE ROLE GN_DW_ADMIN;
SHOW AGENTS IN SCHEMA GN_DW.SERVING;              -- 2행 · owner=GN_DW_ADMIN · comment/profile 최신
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MEMBER;  -- OWNERSHIP + USAGE×3 = 4행
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_OVERALL; -- 동일 4행
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;
--   기대: VERSION$1(최소 스펙) + live. 스펙 본문은 아직 비어 있다 → 09_2 로 채운다.

USE ROLE ACCOUNTADMIN;
SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;  -- 2행(CoWork 노출)

--   ▶ 다음 단계: `09_2_AGENT_버전업.sql` 로 정본 yaml 을 적용해야 도구가 붙는다.
--     이 파일만 실행한 상태의 Agent 는 tool 이 없어 데이터 질문에 답하지 못한다.
-- ============================================================================
