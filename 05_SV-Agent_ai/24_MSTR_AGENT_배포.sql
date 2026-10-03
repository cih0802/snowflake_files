-- ============================================================================
-- 24_MSTR_AGENT_배포.sql — AGENT_MSTR(4번째 Agent) 최초 배포 정본 + MSTR SV 소유권 교정
--   · 구성 = [0] 소유권 교정 → [1] 사전검증 → [2] 껍데기 생성 → [3] owner 판정 → [4] USAGE
--            → [5] 스펙 동기화·대조 → [6] live 소진 + 버전 발행 → [7] CoWork 등록 → [8] 검증.
--     파일 단독 실행 가능(09_1 [1]~[5] + 09_2 [0-B]~[5] 의 AGENT_MSTR 판본).
--   · 🆕 2026-10-03 O200-C 신설. 선행 = `23_MSTR_SV_DDL.sql`(O200-B · 서빙뷰 + SV).
--   · 스펙 정본 = `cortex_project/agents/AGENT_MSTR/agent_spec.yaml` · 📎 Agent 정의 = `09_0_AGENT_정의서.md`.
--   · 🔴 Agent 의 규칙·주의는 스펙(instructions · tool description) 안에 있다 — 이 주석에 두지 않는다.
--   · 이후 스펙 변경(버전업)은 `09_2_AGENT_버전업.sql` 의 AGENT_MSTR 블록으로 한다(이 파일은 최초 배포용).
--
-- ▶ 설계 근거(원문 인용 · 좌표) — 판정보다 먼저 기록(R1-3-7-c)
--   ① 배치안 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0199-A.md:65-69`
--      "MSTR Agent = 신설 4번째 · 도구 재사용 구조" · "현업 승인 후 기존 Agent 에 같은 SV 를 도구로 추가한다(SV 복사 금지)"
--      · "같은 지표가 GN_DW 와 MSTR 에서 정의가 다를 수 있다 ⇒ 도구 description 에 「MSTR 기준」 명시 · 한 표 합산 금지 규칙"
--      ⇒ 2026-10-03 사용자 지시(「이어서 할 순서로 진행」)로 집행.
--   ② 소유 모델 = `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql:38`
--      "GN_DW DB 트리(DB·스키마·테이블/뷰·SV·Agent·DBT PROJECT) = GN_DW_ADMIN 소유(SYSADMIN 하위)."
--   ③ 같은 사고의 재발 = `20_issue/10_진단_원인분석_조각/10_진단_원인분석-015.md:57-61`
--      "SV 를 `ACCOUNTADMIN` 으로 생성해 소유권이 다른 7종과 어긋났다." ·
--      "ACCOUNTADMIN 으로 만들면 소유권이 어긋나 이후 재배포가 권한 오류로 막힌다" ·
--      "✅ `GRANT OWNERSHIP ... COPY CURRENT GRANTS` 로 교정"
--   ④ 처방 패턴 = `20_issue/10_진단_원인분석_조각/10_진단_원인분석-001.md:107`
--      "생성 후 `GRANT OWNERSHIP ON AGENT … TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS`로 소유권 이전(SV owner와 정합)."
--   ⑤ Agent 최초 생성은 09_1, 버전업은 09_2 = `05_SV-Agent_ai/09_2_AGENT_버전업.sql:236`
--      "`09_1` 을 먼저 돌려 Agent 3종을 만든 뒤 이 파일을 실행한다"
-- ============================================================================


-- ============================================================================
-- [0] 소유권 교정 — O200-B 가 ACCOUNTADMIN 세션으로 만든 2개 객체(근거 ②·③)
--     실측(2026-10-03 · pw69582) = MSTR_SPNSR_DVLP_V · SV_MSTR_SPNSR_DVLP owner = ACCOUNTADMIN
--       (GN_DW.MSTR 객체는 GN_DW_ADMIN 으로 정상 · 다른 SV 22종도 GN_DW_ADMIN).
--     🔴 `COPY CURRENT GRANTS` 를 빼면 소비 3역할 grant 가 소실된다.
--     🟢 이미 GN_DW_ADMIN 이면 무해하다(멱등).
-- ============================================================================
USE ROLE ACCOUNTADMIN;
GRANT OWNERSHIP ON VIEW GN_DW.SERVING.MSTR_SPNSR_DVLP_V
  TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP
  TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

SHOW GRANTS ON VIEW GN_DW.SERVING.MSTR_SPNSR_DVLP_V;           -- OWNERSHIP GN_DW_ADMIN + SELECT×3 = 4행
SHOW GRANTS ON SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP;  -- OWNERSHIP GN_DW_ADMIN + (REFERENCES·SELECT)×3 = 7행


-- ============================================================================
-- [1] 사전검증 — 참조 SV 실재 · base 뷰 행 존재 (blocking)
--     Agent 배포는 SV 실재를 검사하지 않는다 ⇒ 죽은 도구 방지(09_2 [0] 과 같은 축).
--     🟢 기대 = SV_EXISTS 1 · VIEW_ROWS > 0.
-- ============================================================================
SELECT
  (SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_VIEWS
    WHERE "SCHEMA" = 'SERVING' AND "NAME" = 'SV_MSTR_SPNSR_DVLP') AS SV_EXISTS,
  (SELECT COUNT(*) FROM GN_DW.SERVING.MSTR_SPNSR_DVLP_V)          AS VIEW_ROWS;


-- ============================================================================
-- [2] Agent 껍데기 생성 — 최소 스펙(09_1 [1] 규약 · `IF NOT EXISTS` · OR REPLACE 금지)
--     🔴 반드시 GN_DW_ADMIN 으로 실행한다(근거 ④ — 아니면 owner 가 어긋난다).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
CREATE AGENT IF NOT EXISTS GN_DW.SERVING.AGENT_MSTR
  COMMENT = '굿네이버스 MSTR 리포트 이관 결과 조회 Agent. SV 1종: MSTR 정기회원 후원개발(MSTR 기준 · GN_DW 지표와 합산 금지).'
  PROFILE = '{"display_name":"MSTR 리포트","color":"#7D44CF"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  $$;


-- ============================================================================
-- [3] owner 판정 (blocking) — 09_1 [2-A] 와 같은 판정식(Agent 4종 전체)
-- ============================================================================
SHOW AGENTS IN SCHEMA GN_DW.SERVING;
SELECT COUNT(*)                                        AS AGENTS,
       COALESCE(COUNT_IF("owner" <> 'GN_DW_ADMIN'), 0) AS OWNER_MISMATCH
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
--   🟢 기대 = AGENTS 4 · OWNER_MISMATCH 0. 불일치면 아래를 ACCOUNTADMIN 으로 실행한 뒤 재판정.
-- USE ROLE ACCOUNTADMIN;
-- GRANT OWNERSHIP ON AGENT GN_DW.SERVING.AGENT_MSTR TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
-- USE ROLE GN_DW_ADMIN;


-- ============================================================================
-- [4] 소비 USAGE grant (멱등)
-- ============================================================================
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MSTR TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MSTR TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MSTR TO ROLE GN_DW_SERVICE;


-- ============================================================================
-- [5] 스펙 동기화 → 대조(09_2 [0-B]·[0-C] 규약 · md5 금지 · size + 시각으로 판정)
-- ============================================================================
COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MSTR/
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/AGENT_MSTR/'
  PATTERN = '.*agent_spec[.]yaml';

LIST 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/AGENT_MSTR/'
  PATTERN = '.*agent_spec[.]yaml';
LIST @GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MSTR/ PATTERN = '.*agent_spec[.]yaml';
--   🟢 판정 = 두 LIST 의 size 동일 · 스테이지 last_modified ≥ 워크스페이스 last_modified.


-- ============================================================================
-- [6] live 소진(멱등) → 정본 yaml 로 버전 발행
--     [2] 가 방금 만든 Agent 는 live 가 자동 생성돼 있다 ⇒ COMMIT 없이는 ADD VERSION 이 거부된다.
-- ============================================================================
EXECUTE IMMEDIATE $$
BEGIN
  SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MSTR;
  LET n INT := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "name" IS NULL);
  IF (n > 0) THEN
    ALTER AGENT GN_DW.SERVING.AGENT_MSTR COMMIT COMMENT = 'live 소진(최초 배포 직전 · 빈 스펙)';
    RETURN 'AGENT_MSTR=committed';
  END IF;
  RETURN 'AGENT_MSTR=no_live';
END;
$$;

ALTER AGENT GN_DW.SERVING.AGENT_MSTR
  ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MSTR'
  COMMENT = '굿네이버스 MSTR 리포트 이관 결과 조회 Agent. SV 1종: MSTR 정기회원 후원개발(O200-C 최초 배포).';
--   ※ "Version nullsuccessfully created" 는 표시 버그다(09_2 [3] 실측) — [8] 로 판정한다.


-- ============================================================================
-- [7] CoWork(Snowflake Intelligence) 등록 — 멱등 · ACCOUNTADMIN(09_1 [4] 규약)
-- ============================================================================
USE ROLE ACCOUNTADMIN;
EXECUTE IMMEDIATE $$
BEGIN
  SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
  LET c INT := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
                 WHERE "database_name" = 'GN_DW' AND "schema_name" = 'SERVING'
                   AND "name" = 'AGENT_MSTR');
  IF (c = 0) THEN
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
      ADD AGENT GN_DW.SERVING.AGENT_MSTR;
    RETURN 'AGENT_MSTR=added';
  END IF;
  RETURN 'AGENT_MSTR=skipped';
END;
$$;
USE ROLE GN_DW_ADMIN;


-- ============================================================================
-- [8] 검증 — 도구·문항 수는 기계로 센다(09_2 [5] 규약)
-- ============================================================================
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MSTR;
SELECT "name" AS VER, "is_default" AS IS_DEF,
       REGEXP_COUNT("agent_spec", 'tool_spec')            AS TOOLS,
       REGEXP_COUNT("agent_spec", '"question"')           AS QUESTIONS,
       REGEXP_COUNT("agent_spec", 'SV_MSTR_SPNSR_DVLP')   AS SV_REFS
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
 ORDER BY VER;
--   🟢 기대 = 최신 버전 IS_DEF true · TOOLS 1 · QUESTIONS 5 · SV_REFS ≥ 1.
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MSTR;   -- OWNERSHIP GN_DW_ADMIN + USAGE×3 = 4행
--   🔴 트라이얼 계정은 Agent 자연어 실행이 차단된다(09_2 [7]) ⇒ 라우팅 검증은 CoWork UI 에서
--      추천질문 5개를 1회씩 눌러 확인한다. 「배포 완료」≠「라우팅 검증 완료」.

-- ============================================================================
-- [9] 롤백 — 최초 배포이므로 되돌릴 이전 버전이 없다(VERSION$1 = 빈 스펙).
--     🔴 VERSION$1 을 default 로 돌리면 도구 0 Agent 가 된다 ⇒ 롤백 대신 CoWork 에서 제거한다.
-- ============================================================================
-- USE ROLE ACCOUNTADMIN;
-- ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT DROP AGENT GN_DW.SERVING.AGENT_MSTR;
