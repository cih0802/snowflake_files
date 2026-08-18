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
-- ▶ 대상 Agent = **3종** (2026-08-18 O84 에서 AGENT_MARKETING 추가)
--   · AGENT_MEMBER    회원 도메인      정본 = cortex_project/agents/AGENT_MEMBER/agent_spec.yaml
--   · AGENT_OVERALL   전사·재무 요약    정본 = cortex_project/agents/AGENT_OVERALL/agent_spec.yaml
--   · AGENT_MARKETING 마케팅            정본 = cortex_project/agents/AGENT_MARKETING/agent_spec.yaml
--
-- ▶ 실행 순서
--   02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql → dbt(BRONZE→GOLD)
--   → 05_1~05_9_SV_DDL_*.sql(실적 SV 9종) → 21_ML_SERVING_뷰_DDL.sql → 22_ML_SV_DDL.sql(ML SV)
--   → **본 파일** → 09_2_AGENT_버전업.sql
--   ⚠ SV 가 없으면 Agent 는 만들어지지만 질의 시 도구가 깨진다(tool_resources 가 SV 를 참조).
--     ⇒ 09_2 [0] 이 **참조 SV 실재를 사전검증**하므로 SV 배포를 건너뛰면 그 단계에서 막힌다.
--     🆕 [2026-08-18 O85] 본 파일에도 `[0]` 전제검증 블록을 신설했다(㉔ ⑧ 시정) —
--        역할·웨어하우스·스키마·SV·SI 객체·기존 Agent 를 **한 번에 재고 조사**한다.
--   🔴🔴 **[2026-08-18 O85 · 선결조건 · ㉔ ⑦]** `09_2` 는 정본 yaml 을
--        `snow://workspace/USER$.PUBLIC."snowflake_files"/…` = **TRIALADMIN 개인 워크스페이스**에서 읽는다.
--        ⇒ **다른 사용자·다른 계정에서는 이 경로가 존재하지 않아 재현이 불가능하다.**
--        선택지 = ㉮ 공유 워크스페이스로 이관하고 `09_2` 경로를 교체
--                 ㉯ `GN_DW.OPS` 에 내부 스테이지를 만들고 `PUT` 으로 올린 뒤 그 경로를 쓴다
--                 ㉰ 현행 유지(실행자를 TRIALADMIN 으로 고정한다고 명문화).
--        🔴 **사용자 결정 사항이므로 이 파일에서 임의로 바꾸지 않았다.** 결정 전까지는
--        `[0]` 의 스테이지 가독 확인이 실패하면 그 자리에서 중단한다.
--
-- ▶ 언제 이 파일을 다시 실행하는가
--   · 신규 계정 재현 / Agent 를 실수로 DROP 한 경우 → 전체 실행
--   · COMMENT·PROFILE 만 바꿀 때 → [5] 만 실행(스펙 무관한 DDL 속성)
--   · 스펙(instructions·tools)을 바꿀 때 → **이 파일 아님** → 09_2 실행
--   🟢 **[2026-08-18 O85 · ㉔ ④ 시정] 이 파일은 이제 `CREATE AGENT IF NOT EXISTS` 를 쓴다.**
--      ⇒ 재실행해도 **기존 Agent 를 파괴하지 않는다**(버전 이력·USAGE grant·SI 등록 보존).
--      🔴 종전 주석은 `CREATE OR REPLACE` 기준의 파괴 경고를 담고 있었고 **코드와 정면 모순**이었다.
--         그 경고는 아래 한 줄로 대체한다:
--         **`CREATE OR REPLACE AGENT` 를 이 파일에 되살리지 마라** — 되살리면 버전 이력이
--         `VERSION$1` 로 초기화되고 USAGE grant·CoWork 등록이 파괴된다.
--   🔴🔴 **[2026-08-18 O85] `IF NOT EXISTS` 의 대가 = COMMENT·PROFILE 이 갱신되지 않는다(㉔ ②).**
--      Agent 가 이미 있으면 [1] 은 **아무 것도 하지 않고 통과**하므로, 이 파일이 선언한
--      「COMMENT 정본」이 라이브와 어긋난 채 조용히 남는다(O84 실측 = 라이브 comment "SV 7종"
--      ↔ 정본 yaml 도구 10종). ⇒ **[5] 를 선택 블록에서 상시 블록으로 승격**했다. [1] 뒤에 항상 돈다.
--   🔴 **[2026-08-18 O85] 계정이 바뀌면 아래 「실측」 주석은 전부 무효다**(`P169` · `R2-8-4`).
--      실측 = 계정 `UA93987`(2026-08-17 생성)에는 **Agent 0 · SV 0 · SI 객체 부재**다.
--      ⇒ 종전 주석의 *"기존 2종은 VERSION$3 로 운영 중"* 은 **`DV07626` 시점 사실**이고 지금은 아니다.
--      **`[0]` 을 돌려 실재를 먼저 확인하고, 그 결과로 실행할 블록을 고른다.**
--
-- ▶ 실측 근거 (2026-07-31 mq60369, AGENT_ZZ_PROBE 로 검증 후 DROP)
--   · `CREATE AGENT` 는 `FROM SPECIFICATION` 이 **필수**다(생략 불가). 다만 최소 스펙
--     `models: orchestration: auto` 만으로도 생성된다 → 껍데기 생성 성립.
--   · 생성 시 `VERSION$1` + live 가 자동 생성된다.
-- ============================================================================

-- 🔴 [2026-08-18 O85 · ㉔ ⑥ 시정] DDL 전용이므로 **개발 웨어하우스**를 쓴다.
--   종전 `GN_DW_ANALYTICS_WH`(Medium · 분석가 질의용)는 DDL 에 과대였고, 워크스페이스 기본값
--   `GN_DW_DEV_WH`(X-Small · Engineer·Admin 기본)와 **이원화**돼 실행 주체마다 청구 대상이 달라졌다.
--   ⇒ `09_1`·`09_2` 모두 `GN_DW_DEV_WH` 로 통일한다(Agent 소비 질의는 여전히 ANALYTICS_WH 다).
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;


-- ============================================================================
-- [0] 🆕 전제검증 — 신규 환경 최초 실행 대비 재고 조사 (2026-08-18 O85 신설 · ㉔ ⑧)
--     🔴 **왜 필요한가**: `09_2` 에는 `[0]` 사전검증이 있는데 `09_1` 에는 없어서, 신규 계정에서
--        역할·웨어하우스·SV·SI 객체 부재가 **블록 중간에서 처음 드러났다**(㉓ 가 그렇게 났다).
--     🔴 아래 한 문장을 먼저 읽어라 — **`ready` 열이 전부 `OK` 가 아니면 [1] 로 내려가지 마라.**
-- ============================================================================
SELECT CURRENT_ACCOUNT() AS account, CURRENT_ROLE() AS role,
       CURRENT_WAREHOUSE() AS warehouse, CURRENT_REGION() AS region;
--   🔴 여기서 얻은 account 를 **이 세션의 판정 문안에 함께 적는다**(`R2-8-4-a`).

-- [0-A] 역할·웨어하우스·스키마 실재
SHOW ROLES LIKE 'GN_DW%';                 -- 기대 6행(ADMIN·ENGINEER·ANALYST·VIEWER·LOADER·SERVICE)
SHOW WAREHOUSES LIKE 'GN_DW%';            -- 기대 3행(ETL·ANALYTICS·DEV)
SHOW SCHEMAS IN DATABASE GN_DW;           -- 기대 SERVING 포함
--   ⚠ 부족하면 `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` 을 먼저 돌린다.

-- [0-B] 참조 SV 실재 — Agent 는 SV 없이도 만들어지지만 도구가 죽는다
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;
--   기대 = 실적 9종 + ML 6종. 🔴 **0행이면 Agent 를 만들 이유가 없다** — SV DDL 을 먼저 돌린다.
--   ⚠ [1] 은 SV 없이도 성공하므로 **이 확인을 건너뛰면 죽은 도구가 조용히 생긴다**.

-- [0-C] 정본 yaml 스테이지 가독 — ㉔ ⑦ 선결조건의 기계 확인
LIST 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/';
--   기대 = AGENT_MEMBER · AGENT_OVERALL · AGENT_MARKETING 3폴더의 `agent_spec.yaml`.
--   🔴 실패하면 **여기서 중단**한다 — 위 「선결조건 ㉔ ⑦」의 ㉮/㉯/㉰ 중 하나를 먼저 정해야 한다.

-- [0-D] CoWork(Snowflake Intelligence) 객체 실재 — ㉔ ③ 의 판정 근거
--   🔴🔴 **[2026-08-18 O85 실측] 계정 `UA93987` 에는 이 객체가 없다.**
--      `SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT` 는
--      *"… does not exist or not authorized"* 로 **컴파일 단계에서 실패**한다
--      ⇒ 종전 `[4]` 는 **신규 계정 최초 실행에서 반드시 죽는 블록**이었다. `[4]` 를 분기형으로 고쳤다.
SHOW DATABASES LIKE 'SNOWFLAKE_INTELLIGENCE%';
--   결과가 0행이면 SI 객체 경로는 **레거시**로 보고 `[4]` 의 ㉠ 분기를 쓴다(생성 후 등록).

-- [0-E] 기존 Agent 재고 — 어느 블록을 실행할지 여기서 고른다
SHOW AGENTS IN SCHEMA GN_DW.SERVING;
--   🔴 **이 결과가 정본이다.** 아래 [1-A]~[1-C] 주석의 「운영 중」 기재는 과거 계정의 것이다.
--   · 0행 = 신규 환경 ⇒ [1-A][1-B][1-C] **전부** 실행
--   · 이미 있는 Agent = `IF NOT EXISTS` 로 무해 통과하되 **[5] 가 COMMENT 를 맞춘다**



-- ============================================================================
-- [1] Agent 껍데기 생성 — 최소 스펙
--     COMMENT·PROFILE 은 spec 이 아닌 DDL 속성이라 09_2 의 버전업으로는 바뀌지 않는다.
--     따라서 이 파일이 COMMENT·PROFILE 의 정본이다.
--     🔴 블록을 A/B/C 로 쪼갠 이유 = 기존 Agent 를 파괴하지 않고 신규만 만들 수 있게 하려는 것이다.
-- ============================================================================

-- ---- [1-A] AGENT_MEMBER ---- 🔴 실행 여부는 **[0-E] 결과로 판단**한다(0행이면 실행).
--   ⚠ [2026-08-18 O85] 종전 주석의 「운영 중(VERSION$3)」은 계정 `DV07626` 시점 사실이고
--     현 계정(`UA93987`)에는 Agent 가 **0종**이다 ⇒ 「운영 중」을 전제로 건너뛰지 마라(`P169`).
-- 🔴 [2026-08-10 O52] 종전 COMMENT 는 "SV 4종" 이었는데 `09_2` 가 도구를 **7종**으로 늘렸다.
--   즉 이 파일만 보면 도구 수를 오인한다 — `09_1` 은 껍데기이고 정본 도구 목록은 `09_2` 다.
-- 🔴 [2026-08-18 O84] 정본 yaml 이 **10종**(실적 7 + ML 예측 3)으로 늘었다. COMMENT 를 맞췄다.
--   ⚠ COMMENT 는 「정본 yaml 의 도구 수」를 적는 값이며 **라이브 버전의 도구 수가 아니다**.
--     09_2 를 돌리기 전까지 라이브는 7종이다 — 두 수를 혼동하지 말 것(O84 실측 격차).
--   🔴 [2026-08-18 O85] `IF NOT EXISTS` 이므로 **이미 있으면 이 COMMENT 는 적용되지 않는다** —
--     적용은 상시 블록 `[5]` 가 담당한다(㉔ ②). 두 곳의 문안을 **함께** 고쳐라.
CREATE AGENT IF NOT EXISTS GN_DW.SERVING.AGENT_MEMBER
  COMMENT = '굿네이버스 회원 도메인 분석 Agent. SV 10종: 월실적·상태전이·서비스발송·행사참여·획득코호트·개발목표달성·회비분해 + ML 예측 3종(회원중단·후원중단·회비예측).'
  PROFILE = '{"display_name":"회원 분석","color":"#29B5E8"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  $$;

-- ---- [1-B] AGENT_OVERALL ---- 🔴 실행 여부는 **[0-E] 결과로 판단**한다(0행이면 실행).
--   ⚠ [2026-08-18 O85] 「운영 중(VERSION$3)」은 계정 `DV07626` 시점 사실이다(`P169`).
-- 🔴 [2026-08-18 O84] 정본 yaml 이 **8종**(예산·광고·회원월실적·발송 + ML 예측 4)이다.
CREATE AGENT IF NOT EXISTS GN_DW.SERVING.AGENT_OVERALL
  COMMENT = '굿네이버스 전사·재무 요약 분석 Agent. SV 8종: 예산·광고실적·회원월실적·발송 + ML 예측 4종(개발금액·LTV예측·LTV스코어·기여요인).'
  PROFILE = '{"display_name":"전사·예산 분석","color":"#11567F"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  $$;

-- ---- [1-C] AGENT_MARKETING ---- 🆕 [2026-08-18 O84] 신규. 이 블록은 실행 대상이다.
--   정본 = `cortex_project/agents/AGENT_MARKETING/agent_spec.yaml`(도구 6 = 리소스 6 · 문항 10)
--   설계 정본 = `05_SV-Agent_ai/30_마케팅_AGENT_설계.md`
--   🔴 **[2026-08-18 O85 정정]** 종전 *"참조 SV 6종은 전건 라이브 실재다(2026-08-18 확인)"* 는
--     계정 `DV07626` 시점 판정이다. 현 계정(`UA93987`)은 **SV 0종**이므로 그대로 만들면
--     **도구 6종이 전부 죽는다** ⇒ `[0-B]` 를 먼저 통과시켜라(`R2-8-4-d`).
CREATE AGENT IF NOT EXISTS GN_DW.SERVING.AGENT_MARKETING
  COMMENT = '굿네이버스 마케팅 분석 Agent. SV 6종: 광고효율·개발목표달성·예산집행·전환회원·캠페인코호트·캠페인회비. 마케팅 보고서 5분석구분의 정본 Agent.'
  PROFILE = '{"display_name":"마케팅 분석","color":"#FF9F36"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  $$;


-- ============================================================================
-- [2] 소유권 — 🆕 [2026-08-18 O85 · ㉔ ① 시정] **주석이 아니라 검증 블록이다.**
--     🔴 **왜 바꿨나**: 종전 [2] 는 *"GN_DW_ADMIN 으로 실행했다면 불요(SKIP)"* 라고만 적고
--        **그 조건이 성립했는지 검사하지 않았다.** 그래서 실제 실행이 ACCOUNTADMIN 이었는데도
--        스크립트가 조용히 통과했고 `AGENT_MARKETING` owner 가 **ACCOUNTADMIN 으로 찍혔다**(㉓).
--        `GN_DW_ADMIN` 은 그 Agent 에 아무 권한이 없어 `09_2 [3-C]` 가 실패하는 상태가 됐다.
--     ⇒ 이제 **owner 를 기계로 판정하고, 불일치면 그 자리에서 실패**시킨다.
-- ============================================================================
USE ROLE GN_DW_ADMIN;

-- [2-A] owner 판정 (blocking) — 불일치가 1건이라도 있으면 예외를 던진다
EXECUTE IMMEDIATE $$
DECLARE
  bad STRING DEFAULT '';
BEGIN
  SHOW AGENTS IN SCHEMA GN_DW.SERVING;
  LET n INT := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
                 WHERE "owner" <> 'GN_DW_ADMIN');
  IF (n > 0) THEN
    SHOW AGENTS IN SCHEMA GN_DW.SERVING;
    bad := (SELECT LISTAGG("name" || '=' || "owner", ', ')
              FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
             WHERE "owner" <> 'GN_DW_ADMIN');
    RETURN 'OWNER_MISMATCH(' || n || '): ' || bad
        || ' >>> [2-B] 를 ACCOUNTADMIN 으로 실행해 이관하라(COPY CURRENT GRANTS 필수)';
  END IF;
  RETURN 'OWNER_OK: 전건 GN_DW_ADMIN';
END;
$$;
--   🔴 `OWNER_MISMATCH` 가 나오면 **아래 [2-B] 를 실행한 뒤 이 블록을 재실행**해 `OWNER_OK` 를 확인한다.
--      확인 없이 [3] 으로 내려가면 GRANT 가 소유자 아닌 역할로부터 나가 실패한다.

-- [2-B] 소유권 이관 — [2-A] 가 불일치를 보고했을 때만 실행
--   🔴 `COPY CURRENT GRANTS` 를 빼면 기존 USAGE 3건이 소실된다(㉓ 처방과 동일).
--   ⚠ 아래는 주석으로 둔다 — **[2-A] 결과를 보고 필요한 줄만** 해제해 돌린다.
-- USE ROLE ACCOUNTADMIN;
-- GRANT OWNERSHIP ON AGENT GN_DW.SERVING.AGENT_MEMBER    TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
-- GRANT OWNERSHIP ON AGENT GN_DW.SERVING.AGENT_OVERALL   TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
-- GRANT OWNERSHIP ON AGENT GN_DW.SERVING.AGENT_MARKETING TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
-- USE ROLE GN_DW_ADMIN;


-- ============================================================================
-- [3] 소비 USAGE grant (소유자 GN_DW_ADMIN 이 부여)
--     🟢 **[2026-08-18 O85 · ㉔ ④ 시정] `GRANT USAGE` 는 멱등이므로 3종 전부 그대로 돌린다.**
--     🔴 종전 주석 2건은 코드와 모순돼 삭제했다:
--        ㉠ *"`CREATE OR REPLACE AGENT` 로 소실되므로 …"* — [1] 은 이제 `IF NOT EXISTS` 라 소실되지 않는다.
--        ㉡ *"기존 2종은 grant 가 이미 살아 있다 ⇒ 신규만 실행 권장"* — 계정 `DV07626` 시점 사실이고
--           현 계정에는 Agent 가 0종이다(`P169`). **선별 실행은 오히려 누락을 만든다.**
--     ⚠ `created_on` 이 갱신되는 것은 사실이나, 그것을 「보존 판정 근거」로 쓰지 않는다
--        (보존 판정은 `[6]` 의 GRANT 행 수로 한다 — 타임스탬프는 판정축이 아니다).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_SERVICE;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_SERVICE;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MARKETING TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MARKETING TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MARKETING TO ROLE GN_DW_SERVICE;


-- ============================================================================
-- [4] CoWork(Snowflake Intelligence) 연결 — 🆕 [2026-08-18 O85 · ㉔ ③ 시정] **분기형으로 교체**
--     🔴🔴 **왜 바꿨나 — 종전 [4] 는 신규 계정 최초 실행에서 반드시 죽었다.**
--        실측(2026-08-18 O85 · 계정 `UA93987`):
--          `SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT`
--          → *"Snowflake Intelligence 'SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT' does not exist
--             or not authorized."* (**컴파일 단계 실패** — `IF` 로도 못 감싼다)
--        ⇒ 종전 블록은 **SI 객체가 이미 있는 계정에서만** 성립하는 코드였고,
--          「신규 환경 최초 실행」 시나리오를 **한 번도 통과한 적이 없다**.
--     🔴 컴파일 단계에서 죽으므로 **객체 실재를 먼저 만들거나(㉠) 블록을 건너뛰어야(㉡) 한다.**
--        스크립팅 `IF` 안에 넣어도 파싱 시점에 걸린다 ⇒ **분기를 사람이 고른다.**
--     · 제거는 `REMOVE AGENT` 가 아니라 **`DROP AGENT`**.
--     · SHOW 결과 컬럼명은 소문자 → RESULT_SCAN 에서 큰따옴표 필수.
--     · `FOR rec IN (…) DO` 커서 변수는 스크립팅 표현식에서 참조 불가 → 루프 대신 명시 분기.
--     근거·검증 상세 = 08 §4.4 · 20_issue/10_진단_원인분석.md §11-D (교훈 P26)
-- ============================================================================
USE ROLE ACCOUNTADMIN;

-- ---- [4-㉠] SI 객체가 **없을 때** — 먼저 만든다 (신규 계정 경로)
--   🟢 `CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS` 는 컴파일 검증 통과(2026-08-18 O85 · only_compile).
--   🔴 **O85 는 실행하지 않았다** — 계정 수준 객체 생성이라 재구축 실행 단계의 일이다.
--      `[0-D]` 가 0행을 냈으면 아래 한 줄을 먼저 돌린 뒤 `[4-㉡]` 로 내려간다.
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- ---- [4-㉡] 등록 — 멱등(기등록이면 skipped)
--   ⚠ 위 [4-㉠] 을 돌리지 않았고 `[0-D]` 도 0행이면 **이 블록은 컴파일에서 죽는다.**
--      그때는 ㉠ 을 먼저 실행하라. 「에러가 났으니 건너뛰자」로 넘기지 마라 —
--      건너뛰면 Agent 가 CoWork UI 에 노출되지 않고, 그 사실이 조용히 숨는다.
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
    res := res || 'AGENT_OVERALL=added ';
  ELSE
    res := res || 'AGENT_OVERALL=skipped ';
  END IF;

  SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
  LET c3 INT := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
                  WHERE "database_name" = 'GN_DW' AND "schema_name" = 'SERVING'
                    AND "name" = 'AGENT_MARKETING');
  IF (c3 = 0) THEN
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
      ADD AGENT GN_DW.SERVING.AGENT_MARKETING;
    res := res || 'AGENT_MARKETING=added';
  ELSE
    res := res || 'AGENT_MARKETING=skipped';
  END IF;

  RETURN res;
END;
$$;


-- ============================================================================
-- [5] COMMENT·PROFILE 갱신 — 🆕 [2026-08-18 O85 · ㉔ ② 시정] **선택 → 상시 블록으로 승격**
--     🔴🔴 **왜 승격했나**: [1] 이 `CREATE AGENT IF NOT EXISTS` 이므로 Agent 가 이미 있으면
--        **COMMENT·PROFILE 이 갱신되지 않고 조용히 통과**한다. 그러면 이 파일이 선언한
--        「COMMENT 정본」이 라이브와 어긋난 채 남는다.
--        실증(2026-08-18 O84) = 라이브 comment *"Phase-1 · SV 7종"* ↔ 정본 yaml 도구 **10종**.
--     ⇒ **주석을 해제해 항상 실행한다.** `ALTER AGENT … SET` 은 멱등이고 값이 같으면 무해하다.
--     ⚠ SET 절은 콤마 구분 필수.
--     🔴 **09_2 로 도구 수를 바꾸면 이 블록의 문안도 함께 고친다** — 두 곳이 정본이다
--        ([1] 의 CREATE 문 COMMENT = 신규 생성용 · [5] = 기존 갱신용).
--        🔴 이 이중 정본이 drift 원인이므로 **한 번에 둘 다 고쳐라**(`P23` 계열).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
ALTER AGENT GN_DW.SERVING.AGENT_MEMBER SET
  COMMENT = '굿네이버스 회원 도메인 분석 Agent. SV 10종: 월실적·상태전이·서비스발송·행사참여·획득코호트·개발목표달성·회비분해 + ML 예측 3종(회원중단·후원중단·회비예측).',
  PROFILE = '{"display_name":"회원 분석","color":"#29B5E8"}';
ALTER AGENT GN_DW.SERVING.AGENT_OVERALL SET
  COMMENT = '굿네이버스 전사·재무 요약 분석 Agent. SV 8종: 예산·광고실적·회원월실적·발송 + ML 예측 4종(개발금액·LTV예측·LTV스코어·기여요인).',
  PROFILE = '{"display_name":"전사·예산 분석","color":"#11567F"}';
ALTER AGENT GN_DW.SERVING.AGENT_MARKETING SET
  COMMENT = '굿네이버스 마케팅 분석 Agent. SV 6종: 광고효율·개발목표달성·예산집행·전환회원·캠페인코호트·캠페인회비. 마케팅 보고서 5분석구분의 정본 Agent.',
  PROFILE = '{"display_name":"마케팅 분석","color":"#FF9F36"}';


-- ============================================================================
-- [6] 검증 — 🆕 [2026-08-18 O85 · ㉔ ⑤ 시정] **owner 판정 쿼리를 추가**했다
--     🔴 종전 [6] 은 `SHOW AGENTS` 주석에 *"owner=GN_DW_ADMIN"* 이라고 **기대만 적어 놓고**
--        판정 쿼리가 없었다 ⇒ 사람이 눈으로 보지 않으면 ㉓ 같은 불일치가 통과한다.
--     🔴 **`R2-8-4-a`**: 아래 판정 결과를 인용할 때는 **계정명을 함께 적는다.**
-- ============================================================================
USE ROLE GN_DW_ADMIN;
SHOW AGENTS IN SCHEMA GN_DW.SERVING;                -- **3행** · comment/profile 최신
--   🆕 owner·comment 기계 판정 — 기대 = mismatch 0
--   🔴 `COALESCE` 필수: Agent 가 **0행이면 `COUNT_IF` 는 0 이 아니라 NULL** 을 낸다
--      (2026-08-18 O85 실측) ⇒ 감싸지 않으면 「미배포」가 「위반 없음」처럼 보인다.
SELECT CURRENT_ACCOUNT()                                              AS account,
       COUNT(*)                                                       AS agents,
       COALESCE(COUNT_IF("owner" <> 'GN_DW_ADMIN'), 0)                 AS owner_mismatch,
       COALESCE(COUNT_IF("comment" IS NULL OR "comment" = ''), 0)      AS comment_empty,
       COALESCE(COUNT_IF("profile" IS NULL OR "profile" = ''), 0)      AS profile_empty
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
--   🔴 `agents` = 3 AND `owner_mismatch` = 0 AND `comment_empty` = 0 이어야 통과다.
--      🔴 **`agents` 를 먼저 본다** — 0 이면 나머지가 전부 0 이어도 **아무것도 배포되지 않은 것**이다.
--      하나라도 어긋나면 [2-A] · [5] 로 돌아간다.

SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MEMBER;    -- OWNERSHIP + USAGE×3 = 4행
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_OVERALL;   -- 동일 4행
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MARKETING; -- 동일 4행
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MARKETING;
--   기대: VERSION$1(최소 스펙) + live. 스펙 본문은 아직 비어 있다 → 09_2 로 채운다.
--   🔴 [O85] 버전 **번호를 판정축으로 쓰지 마라** — 계정 이관 시 초기화된다(O73 실측 `$7`→`$3`).
--      판정은 **도구 수·스펙 길이**로 한다.

USE ROLE ACCOUNTADMIN;
SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;  -- **3행**(CoWork 노출)
--   🔴 [2026-08-18 O85] SI 객체가 없으면 이 줄도 **컴파일에서 죽는다**(`[4]` 와 같은 축) ⇒
--      `[4-㉠]` 을 돌리지 않았다면 이 줄을 건너뛰고 **CoWork UI 에서 눈으로 노출을 확인**한다.
--      🔴 그 경우 판정은 「미확인」이다 — 「노출됨」으로 적지 마라.

--   ▶ 다음 단계: `09_2_AGENT_버전업.sql` 로 정본 yaml 을 적용해야 도구가 붙는다.
--     이 파일만 실행한 상태의 Agent 는 tool 이 없어 데이터 질문에 답하지 못한다.
-- ============================================================================
