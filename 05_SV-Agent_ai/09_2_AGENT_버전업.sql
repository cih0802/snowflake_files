-- GN_DW Cortex Agent [2/2] yaml 기반 버전업 — 정본 yaml 을 stage 에서 직접 읽어 새 버전 발행
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상
--   Agent **스펙**을 갱신하는 유일한 경로. 스펙 본문(YAML)을 이 파일에 **복사하지 않고**
--   워크스페이스 stage 의 정본 파일을 `ALTER AGENT … ADD VERSION FROM <stage>` 로 직접 읽는다.
--   → SQL 파일에 스펙 사본이 0개 = **drift 구조적 불가**(교훈 P23 재발 차단).
--
--   스펙 정본 = `cortex_project/agents/AGENT_MEMBER/agent_spec.yaml`
--              `cortex_project/agents/AGENT_OVERALL/agent_spec.yaml`
--
-- ▶ 🔴 파일 레이아웃 규약 (실측으로 확정 — 문서 예시가 틀렸다)
--   · `ADD VERSION FROM <경로>` 의 <경로>는 **디렉터리**이고, 그 안에 스펙 파일이 있어야 한다.
--   · 파일명은 반드시 **`agent_spec.yaml`** 이다.
--     Snowflake 공식 문서(cortex-agents-versioning)의 GET 예시는 `agent.yaml` 로 적고 있으나
--     실제 Agent 버전 stage 를 `LIST snow://agent/<FQN>/versions/VERSION$N/` 로 열어 보면
--     파일명이 `agent_spec.yaml` 이다(2026-07-31 실측). `agent.yaml` 로 두면 실패한다:
--       Error: No spec file present for the agent. @…/versions/live/cortex_project/agents/AGENT_MEMBER
--   · 디렉터리명은 Agent 이름과 일치할 필요가 없다(대상 Agent 는 ALTER 문이 지정한다).
--     다만 혼동을 막기 위해 Agent 이름과 같게 둔다.
--
-- ▶ 🔴 live 버전 선점 제약 (실측)
--   live 버전이 존재하면 `ADD VERSION FROM` 이 거부된다:
--       Error: There is already a live version. Please commit it first.
--   → 반드시 **`COMMIT` 으로 live 를 소진한 뒤** ADD VERSION 한다([2] 멱등 블록이 처리).
--   `ADD VERSION FROM` 은 live 를 거치지 않고 **명명 버전을 직접 생성**하며,
--   생성된 버전이 **자동으로 is_default=true** 가 된다(이전 버전은 보존).
--
-- ▶ 이 경로가 보존하는 것 (실측)
--   USAGE grant · CoWork SI 등록 · 이전 버전 전체(롤백 가능). `CREATE OR REPLACE` 와 정반대다.
--   ↔ COMMENT·PROFILE 은 spec 이 아닌 DDL 속성이라 **이 파일로는 안 바뀐다** → 09_1 [5] 사용.
--
-- ▶ 실행 순서 / 변경 반영 순서
--   05_1~05_9_SV_DDL_*.sql(SV 변경 시) → `cortex_project/agents/*/agent_spec.yaml` **정본 갱신**
--   → **본 파일** → (필요 시) 08_AGENT_spec.md 서술 동기화
--   ⚠ SV 를 바꿨는데 스펙을 안 바꿨더라도, instruction 이 SV 규칙을 사실로 안내하므로
--     SV 재배포 후에는 정본 yaml 의 서술이 여전히 맞는지 확인할 것.
--
-- ▶ 대안 경로 (동등)
--   CoCo/Snowsight 의 `cortex_agent_deploy`(save+publish)도 같은 결과를 낸다.
--   차이: deploy 는 live 를 수정해 commit 하고, 본 파일은 live 를 건너뛰고 stage 에서 직접 발행한다.
--   CI/CD·재현 스크립트에는 본 파일 경로가 적합하다(파일이 단일 진실원천).
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;


-- ============================================================================
-- [1] 갱신 전 상태 확인 — 어느 버전이 서비스 중이고 live 가 있는지
--     live 존재 판별 = spec_file_path 가 `…/versions/live/` 인 행
-- ============================================================================
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_OVERALL;

-- 정본 파일이 stage 에 실제로 있는지 확인 (파일명 `agent_spec.yaml` 필수)
LIST 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/';
--   기대: AGENT_MEMBER/agent_spec.yaml · AGENT_OVERALL/agent_spec.yaml
--   ※ 워크스페이스에 방금 추가·수정한 파일도 versions/live 에 즉시 반영된다(실측).


-- ============================================================================
-- [2] live 선소진 (멱등) — live 가 있으면 COMMIT, 없으면 skip
--     `ADD VERSION FROM` 은 live 가 있으면 거부되므로 반드시 먼저 처리한다.
-- ============================================================================
EXECUTE IMMEDIATE $$
DECLARE
  res STRING DEFAULT '';
BEGIN
  SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;
  LET m INT := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "name" IS NULL);
  IF (m > 0) THEN
    ALTER AGENT GN_DW.SERVING.AGENT_MEMBER COMMIT COMMENT = 'live 소진(버전업 직전 스냅샷)';
    res := res || 'AGENT_MEMBER=committed ';
  ELSE
    res := res || 'AGENT_MEMBER=no_live ';
  END IF;

  SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_OVERALL;
  LET o INT := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "name" IS NULL);
  IF (o > 0) THEN
    ALTER AGENT GN_DW.SERVING.AGENT_OVERALL COMMIT COMMENT = 'live 소진(버전업 직전 스냅샷)';
    res := res || 'AGENT_OVERALL=committed';
  ELSE
    res := res || 'AGENT_OVERALL=no_live';
  END IF;

  RETURN res;
END;
$$;


-- ============================================================================
-- [3] ★ 정본 yaml 로 새 버전 발행 — 이 파일의 본체
--     성공 시 새 VERSION$N 이 생성되고 자동으로 is_default=true 가 된다.
--     ※ 성공 메시지가 "Version nullsuccessfully created" 로 보이는 것은 표시 버그이며
--       실제 버전은 정상 생성된다(SHOW VERSIONS 로 확인 · 2026-07-31 실측).
-- ============================================================================
ALTER AGENT GN_DW.SERVING.AGENT_MEMBER
  ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/AGENT_MEMBER'
  COMMENT = 'agent_spec.yaml 실측근거 적용';

ALTER AGENT GN_DW.SERVING.AGENT_OVERALL
  ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/AGENT_OVERALL'
  COMMENT = 'agent_spec.yaml 실측근거 적용';


-- ============================================================================
-- [4] (선택) 개발 재개용 live 재생성
--     Snowsight UI 에서 편집하거나 `cortex_agent_save` 를 쓰려면 live 가 필요하다.
--     파일 기반 운영만 한다면 생성하지 않는 편이 낫다 — live 가 있으면 [3] 이 거부되므로
--     다음 버전업 때 [2] 가 한 번 더 COMMIT 하며 불필요한 버전이 늘어난다.
-- ============================================================================
-- ALTER AGENT GN_DW.SERVING.AGENT_MEMBER  ADD LIVE VERSION FROM LAST;
-- ALTER AGENT GN_DW.SERVING.AGENT_OVERALL ADD LIVE VERSION FROM LAST;


-- ============================================================================
-- [5] 검증
-- ============================================================================
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_OVERALL;
--   기대: 최신 VERSION$N 이 is_default=true · agent_spec 에 tools/instructions 반영 ·
--         이전 버전은 is_default=false 로 보존(롤백 가능)

DESCRIBE AGENT GN_DW.SERVING.AGENT_MEMBER;
DESCRIBE AGENT GN_DW.SERVING.AGENT_OVERALL;
--   기대: tools 배열에 analyst_* 가 존재. AGENT_OVERALL 은 analyst_ad 포함(SV_AD 반영본).

-- grant·SI 가 보존됐는지 (이 경로는 파괴하지 않아야 정상)
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MEMBER;   -- OWNERSHIP + USAGE×3 = 4행
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_OVERALL;  -- 동일 4행
--   판정: created_on 이 09_1 실행 시각 그대로면 보존된 것이다(재부여되지 않았다는 증거).
USE ROLE ACCOUNTADMIN;
SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;  -- 2행 유지
USE ROLE GN_DW_ADMIN;


-- ============================================================================
-- [6] 롤백 — 이전 버전으로 즉시 되돌리기
--     명명 버전은 불변 스냅샷이므로 DEFAULT 를 옮기는 것만으로 롤백이 끝난다.
-- ============================================================================
-- SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_OVERALL;   -- 되돌릴 VERSION$N 확인
-- ALTER AGENT GN_DW.SERVING.AGENT_OVERALL SET DEFAULT_VERSION = 'VERSION$1';
-- ALTER AGENT GN_DW.SERVING.AGENT_OVERALL SET DEFAULT_VERSION = LAST;   -- 최신으로 복귀


-- ============================================================================
-- [7] 트라이얼 제약
-- ============================================================================
-- ▶ 트라이얼 계정은 **에이전트 자연어 실행이 차단**된다:
--   `SNOWFLAKE.CORTEX.DATA_AGENT_RUN` → 'Access denied for trial accounts'.
--   → NL→SQL 라우팅 스모크·회귀는 CoWork UI(ai.snowflake.com)에서 수동 수행한다.
--   ↔ 버전 발행·검증(본 파일 전체)과 SV 데이터층 ground-truth 조회는 트라이얼에서도 가능하다.
--
-- ▶ 특정 버전만 지목해 실행(paid 이관 후)
--   SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN('GN_DW.SERVING.AGENT_MEMBER!VERSION$2',
--     $${"messages":[{"role":"user","content":[{"type":"text","text":"2024년 납부율은?"}]}]}$$);
--   버전 지목자: VERSION$N · 별칭 · 단축어(LIVE·FIRST·LAST·DEFAULT). 생략 시 DEFAULT.
-- ============================================================================
