-- GN_DW dbt PROJECT 최초 생성 (계정 이전 KD03246 후 재배포) — 정본 위치 GN_DW.OPS.DW_PIPELINE
-- Co-authored with CoCo

-- ============================================================================
-- 근거: 10_dbt_pipeline/00_배포운영_통합_20260715.md §1 (정본, 구 _archive/99 대체)
--   · 프로젝트 배치 = 운영/툴링 스키마 GN_DW.OPS (데이터레이어 SILVER/GOLD와 분리)
--   · 프로젝트명 = DW_PIPELINE (구 계정 동일: GN_DW.OPS.DW_PIPELINE)
--
-- ⚠️ 계정 이력: cs94293(구) → **KD03246(현재, TRIALADMIN)**. 문서 다수가 아직 cs94293 기준.
--    본 파일은 2026-07-29 KD03246 실측 기준으로 갱신됨.
--
-- ─── 사전조건 (2026-07-29 KD03246 실측) ─────────────────────────────────────
--   1. ✅ GN_DW.OPS 스키마 존재 (comment='ETL 운영 인프라 — dbt 프로젝트(DBT PROJECT DW_PIPELINE)')
--   2. ✅ 워크스페이스 10_dbt_pipeline/ 에 dbt_project.yml + models **77개** 존재
--         SILVER 38 + GOLD 39(dim 15 + fact 12 + wide 12)
--         ※ 구 문서의 "SILVER 32 + GOLD 33 = 65" 는 폐기 — 순서9 AGENCY 위성팩트 분리
--           (FAD_D·FAD_B·FAD_BC) + WIDE 12종 확장 반영분
--   3. ✅ RBAC 역할 6종 존재 — GN_DW_ADMIN·ENGINEER·ANALYST·VIEWER·LOADER·SERVICE
--   4. ✅ 웨어하우스 3종 존재 — GN_DW_ETL_WH(S)·GN_DW_DEV_WH(XS)·GN_DW_ANALYTICS_WH(M)
--   5. ✅ SERVING 스키마 존재
--   6. ❌ **SERVING helper 뷰 미생성 (객체 0개)** — DIM_MONTH·DIM_MEMBER_CURRENT·FACT_AD_COMBINED
--         → dbt 배포와 **무관**(dbt 는 SILVER/GOLD 만 소유). 단 SV/Agent 는 이 뷰 없이는 실패.
--         해소: 05_SV-Agent_ai/02_SERVING_setup.sql  또는
--               02_GN_DW_building/08_After_Deploy_DBT.sql §G  → 그 다음 05_1~05_7_SV_DDL_*.sql
--   7. ✅ SILVER 38 / GOLD 27테이블+WIDE 12뷰 **이미 배포·적재 완료**
--         (FACT_MEMBER_MONTHLY 40,054,883 · FACT_SERVICE_EVENT 38,470,780 · FACT_TARGET_BIZ 0행=입고대기)
--         → 즉 워크스페이스 dbt build 는 이미 성공. 본 파일은 **거버넌스 오브젝트 등록**이 목적.
--   8. ❌ **DBT PROJECT 오브젝트 미존재** (SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS → 0행) ← 본 파일이 해결
--
-- 주의: 신규 계정이므로 versions/live = 최신 워크스페이스 코드 → CREATE 시 VERSION$1 이 곧 최신.
--       구 계정의 VERSION 드리프트 이슈 무관.
--
-- 🔴🔴 [2026-08-18 O85-C · 사용자 결정] **dbt 는 워크스페이스 경로를 유지한다 — 의식적 선택이다.**
--   경위: 착수표 ㉔ ⑦ 로 「배포 원본이 `USER%24.PUBLIC."snowflake_files"` = **개인 워크스페이스**여서
--   다른 사용자·다른 계정에서 재현 불가」라는 결함을 적발했고, Agent 정본 yaml 은
--   **`GN_DW.OPS.AGENT_SPEC_STAGE` 로 이관**했다(`05_SV-Agent_ai/09_2` [0-B]·[0-C]).
--   🔴 **dbt 는 같은 결함을 갖고 있으나 같은 처방을 쓰지 않는다.** 아래 78·112·175행의
--   `snow://workspace/USER$.…/10_dbt_pipeline` 는 **오류가 아니라 결정**이다.
--   판단 근거(사용자):
--     · dbt 는 **모델이 많고 작업이 계속 이어진다**(models 88 · yml 6 실측) ⇒ 편집→스테이지 복사를
--       매 사이클 반복하면 **작업량과 누락 위험이 Agent 쪽보다 훨씬 크다.**
--     · Agent 정본은 **Agent 당 파일 1개**라 복사가 즉시 끝난다 ⇒ 스테이지 이관의 비용이 낮다.
--     · 배포 산출물인 **`DBT PROJECT` 객체 자체는 이미 `GN_DW.OPS` 에 있다** ⇒ 운영·스케줄
--       (`EXECUTE DBT PROJECT` · TASK)은 사람과 무관하게 돈다. 개인 경로 의존은 **배포 순간뿐**이다.
--   ⇒ **남는 리스크와 그 담당**: 「신규 계정·타 사용자 재구축 시 이 CREATE/ALTER 문이 실패한다」.
--     담당 = **dbt 작업자**. 재구축 시 아래 중 하나를 그 자리에서 택한다:
--       ㉠ 자신의 워크스페이스 경로로 이 파일의 URI 를 바꿔 실행(가장 단순 · 파일은 고치지 않고 세션에서만)
--       ㉡ Agent 와 같이 `COPY FILES` → `GN_DW.OPS` 내부 스테이지로 올린 뒤 그 경로로 배포
--          (일회성 재구축에는 이 편이 안전하다 — 이후 개발은 다시 워크스페이스로 돌아온다)
--   🔴 **이 결정을 「해소」로 적지 마라.** 상태 = **의식적 잔존 리스크(accepted risk)** 다.
--   🔴 **dbt 작업자가 바뀌면 이 절을 인수인계에 포함**한다 — 암묵지로 남기면 재구축에서 막힌다.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 참고 — Snowsight UI(Connect 메뉴) ↔ SQL 대응 (이 문서로 전부 대체 가능)
-- ─────────────────────────────────────────────────────────────────────────────
-- 워크스페이스 우측 상단 Connect 메뉴의 각 항목은 아래 SQL과 1:1 대응:
--   · Deploy dbt project(신규)      = CREATE DBT PROJECT ... FROM '.../versions/live'   → Step 1
--   · Existing dbt deployment(버전+) = ALTER DBT PROJECT ... ADD VERSION FROM '...'      → Step 3 하단
--   · Redeploy dbt project           = ALTER DBT PROJECT ... ADD VERSION (버튼형)         → Step 3 하단
--   · Create schedule                = CREATE TASK ... AS EXECUTE DBT PROJECT ...         → Step 4
--   · View project / View schedules  = SHOW DBT PROJECTS / SHOW TASKS + 오브젝트 탐색기   → Step 1 SHOW문
-- 차이(딱 하나): UI "Connect" 는 위 오브젝트 생성 외에 워크스페이스↔배포오브젝트 UI 연결(편의버튼)만
--   추가로 만든다. 이는 Snowflake 오브젝트가 아니라 UI 편의기능 → SQL 배포 후 UI를 붙이고 싶으면
--   Connect » Existing dbt deployment 에서 GN_DW.OPS.DW_PIPELINE 선택(중복 생성 아님).

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 0 — 사전조건 재확인 (읽기 전용, 안전)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT CURRENT_ACCOUNT() AS ACCOUNT, CURRENT_ROLE() AS ROLE;   -- 기대: <ACCOUNT>

-- 레이어별 객체 수 (기대: SILVER 38 BASE / GOLD 27 BASE + 12 VIEW / SERVING 0 ← helper뷰 미배포)
SELECT TABLE_SCHEMA, TABLE_TYPE, COUNT(*) AS CNT
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('SILVER', 'GOLD', 'SERVING')
GROUP BY 1, 2
ORDER BY 1, 2;

SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;   -- 기대: 0행(미존재) → Step 1 진행

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1-1 — CREATE (최초 배포) : VERSION$1 자동 default
-- ─────────────────────────────────────────────────────────────────────────────
-- OPS 스키마는 이미 존재(2026-07-28 생성) → 아래는 멱등 no-op.
--   ※ IF NOT EXISTS 이므로 기존 COMMENT('ETL 운영 인프라 — dbt 프로젝트…')는 덮이지 않음.
CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
  COMMENT = 'dbt project 등 운영/툴링 객체 전용 (데이터 레이어 아님)';

-- CREATE DBT PROJECT 권한 (신 계정 실측: GN_DW_ADMIN 에 미부여 → ACCOUNTADMIN 이 선부여)
GRANT CREATE DBT PROJECT ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ADMIN;

-- 소유자는 GN_DW_ADMIN 으로 통일(GOLD/SILVER·SERVING 소유자와 동일 → grant 파편화 방지).
--   ACCOUNTADMIN 으로 만들면 05_SV-Agent_ai/13 의 owner 불일치 이슈가 재현됨.
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/head/10_dbt_pipeline';

SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1-2 — 재배포 (버전이 남도록) : ALTER … ADD VERSION → VERSION$N+1
-- ─────────────────────────────────────────────────────────────────────────────
-- 언제: 워크스페이스의 models/·macros/·dbt_project.yml 을 수정한 뒤.
--   Snowsight UI 의 `Connect » Redeploy dbt project`(= Existing dbt deployment)와 동일 동작.
--
-- ⚠️ 왜 CREATE 를 다시 쓰지 않는가:
--   · `CREATE DBT PROJECT IF NOT EXISTS`(Step 1-1) → 이미 있으면 **아무 일도 안 함**(구버전 그대로 실행됨).
--   · `CREATE OR REPLACE DBT PROJECT`             → 버전 식별자가 1로 **리셋**되고 **기존 버전·alias·run history 전량 소실**.
--     (snow CLI 의 `snow dbt deploy --force` 도 내부적으로 이것 → docs 경고: 사용 금지)
--   → 재배포는 반드시 **ALTER … ADD VERSION**. 이력이 남아 감사·롤백이 가능하다.
--
-- ⚠️ 배포 객체 ≠ 워크스페이스: DBT PROJECT 는 워크스페이스의 **스냅샷**이다.
--    워크스페이스에서 dbt build 를 돌려도(= `EXECUTE DBT PROJECT FROM WORKSPACE` / Workspaces UI)
--    배포 객체는 바뀌지 않는다 → ADD VERSION 을 빼먹으면 배포본이 조용히 뒤처진다.
--    [실측 2026-07-29] `SHOW VERSIONS` 결과 **VERSION$1(2026-07-28) 뿐** — 그 사이 워크스페이스 변경분
--    (07-29 SV/Agent, 07-16 캠페인 4축 등)이 배포 객체에 **미반영** 상태였다. 00_배포운영_통합 §0 경고와 동일 사고.

-- (1) 현재 배포본 확인 — 최신 VERSION$N·is_default 를 먼저 본다.
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;
DESCRIBE DBT PROJECT GN_DW.OPS.DW_PIPELINE;   -- default_version / default_version_name 확인

-- (2) 새 버전 추가 = 재배포. VERSION$N+1 로 자동 증가하며 default 로 승격된다.
--     ⚠️ `ADD VERSION` 에는 COMMENT 절이 **없다**(문법: ADD VERSION [<version_name_alias>] FROM '<uri>').
--        변경 요약은 ① 선택적 **alias**(식별자 규칙: 공백·특수문자 불가) ② 프로젝트 COMMENT(아래 3)
--        ③ 본 문서/`00_배포운영_통합 §0` 이력에 남긴다.
--     🔴🔴 [2026-08-30 O121 실측] URI 의 `USER$` 를 **URL 인코딩(`USER%24`)하면 SQL 에서 실패한다**:
--          `Database '"USER%24"' does not exist or not authorized`
--        ⇒ SQL(`ALTER DBT PROJECT … FROM '…'`)에서는 **리터럴 `USER$`** 를 쓴다. `%24` 는 UI/URL 문맥 전용이다.
--        (종전 이 줄은 `USER%24` 로 적혀 있었고 그대로 실행하면 막힌다.)
--     ⚠️ 세션에 웨어하우스가 없으면 `No active warehouse selected` 로 막힌다 ⇒ `USE WAREHOUSE` 를 먼저.
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION SILVER_TBLNM_20260901
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';
-- ✅ [2026-08-30 실행완료] VERSION$2(alias=TYPEALTER_20260830) 생성 · is_default=true 승격 확인.
--    내용 = ① BRONZE_CRM/ERP/AGENCY grant 복구 ② SILVER.CRM_MEMBER_DEV UPDATE(merge) 부여
--           ③ `macros/gn_no_structural_alter.sql` 신설(dbt 자동 타입 ALTER 차단) ④ BIGQUERY_BASIC 12컬럼 CAST.
--    검증 = `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build'` → **PASS=425 WARN=36 ERROR=0 SKIP=0 / 461** (375초).
--    직전 상태(VERSION$1) = PASS=11 WARN=0 ERROR=17 SKIP=433.

-- (3) 변경 요약을 프로젝트 COMMENT 에 남긴다(버전별이 아니라 객체 단위 — 최신 상태 설명).
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE SET
  COMMENT = 'BRONZE→SILVER + SILVER→GOLD + WIDE VIEW. [20260901] SILVER스키마의 GA4_*에 현업이 혼동이 와 BIGQUERY로 교체함. 정본 09_SILVER_적재쿼리_20260714 / 03_top-down_gold/06_DDL.';

-- (4) 승격 확인 — 새 VERSION$N+1 이 is_default=true 인지, alias 가 붙었는지.
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;

-- (5) 문법 검증(테이블 불변, 안전) → 통과 후 Step 3 의 build 실행.
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';

-- ── 롤백 (직전 버전으로 되돌리기) ─────────────────────────────────────────────
-- ⚠️ `EXECUTE DBT PROJECT` 에는 VERSION 절이 **없다** — 실행은 항상 default 버전을 쓴다.
--    따라서 롤백 = default 버전을 되돌리는 것.
-- ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE SET DEFAULT_VERSION = 'VERSION$1';   -- 또는 alias
-- ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE UNSET DEFAULT_VERSION;               -- LAST(최신)로 복귀
--   ※ 현 계정 실측 default_version = 'LAST' (DESCRIBE 확인) → 새 버전 추가 시 자동으로 최신을 따라간다.
--
-- ── ⚠️ BCR-2362 (2026_06 bundle, Pending) — 이 절차의 유효기간 ────────────────
--   번들이 계정에 활성화되면 DBT PROJECT 가 **단일 mutable `live` 버전**으로 전환되고
--   `ADD VERSION`·`SHOW VERSIONS`·`SET DEFAULT_VERSION`·버전 경로(`versions/VERSION$N/`)가 **제거**된다
--   (기존 버전도 접근 불가). 경로는 `versions/live/` 로 통일되고 파일은 PUT/GET/COPY FILES 로 직접 수정된다.
--   대신 partial parsing·`dbt retry`·`--select state:modified`(Slim CI)·`source freshness` 가 열린다.
--   [실측 2026-07-29] 본 계정은 **아직 미적용**(`SHOW VERSIONS` → VERSION$1, is_live=false) → 위 절차 유효.
--   ▶▶ 번들 활성 후에는 Step 1-2 를 "workspace → live 동기화"로 재작성해야 한다(버전 이력 전략 폐기).
--
-- ── (참고) DDL 선행이 필요한 변경인지 확인 — R4: 구조 소유주는 dbt 가 아니다 ──
--   모델에 **신규 컬럼**을 추가했다면 ADD VERSION 전에 DDL 을 먼저 적용해야 한다
--   (미적용 시 SILVER/fact 는 append 실패, GOLD dim 은 merge 에서 신컬럼이 조용히 누락).
--     SILVER → 04_silver_design/08_SILVER_테이블DDL_20260714.sql
--     GOLD   → 03_top-down_gold/06_DDL.sql
--   ⚠️ 자식 FK 가 있는 GOLD DIM 에 컬럼만 추가할 때는 `CREATE OR REPLACE` 금지(FK 드롭) → `ALTER ADD COLUMN`.

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 2 — 검증 (테이블 불변, 안전 — 데이터 변경 없음)
-- ─────────────────────────────────────────────────────────────────────────────
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile';

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3 — 적재 (준비되면 주석 해제) : run 금지·build 사용(run+test 게이트, R2)
-- ─────────────────────────────────────────────────────────────────────────────
-- ⚠️ SILVER/GOLD 는 이미 적재 완료(사전조건 7) → 아래는 **재정제**용. 즉시 실행 불필요.
-- ⚠️ 구조 소유주는 dbt 가 아님: SILVER=08_SILVER_테이블DDL, GOLD=03_top-down_gold/06_DDL.
--    전 모델 full_refresh:false + pre-hook TRUNCATE(fact/silver) / merge(dim) → DDL·FK·주석 보존.
--    따라서 `--full-refresh` 플래그는 **사용 금지**(무시되지만 혼동 유발).

-- 전체 재정제:
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- 부분: GA4 샤드 입고 시(하류 XREF 포함) / CRM 도메인만:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.ga4+';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.crm';

-- GOLD만(SILVER 테스트 게이트 우회):
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select path:models/gold';

-- WIDE 소비뷰만 재생성(tag 기반, 물리저장 0):
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select tag:gold_wide';

-- 이후 워크스페이스 코드 수정 시 새 버전 고정(거버넌스·재현성):
-- ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
--   ADD VERSION FROM 'snow://workspace/USER%24.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
--   COMMENT = '<변경 요약>';

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 4 — 스케줄 자동화 (TASK) : 준비되면 주석 해제
-- ─────────────────────────────────────────────────────────────────────────────
-- 주의:
--   1. WAREHOUSE 필수 — serverless task 는 EXECUTE DBT PROJECT 미지원.
--   2. TASK 는 dbt project 와 동일 스키마(GN_DW.OPS)에 생성.
--   3. 생성 직후 SUSPENDED 상태 → RESUME 해야 스케줄 동작.
--   4. R2 규칙 유지: run 금지·build 사용(run+test 게이트).
--   5. CRON 타임존은 KST 기준(Asia/Seoul). UTC 필요 시 UTC 로 교체.
--   6. TASK 생성 권한: GN_DW_ADMIN 에 EXECUTE TASK(account-level) 필요 시 ACCOUNTADMIN 선부여.
--      GRANT EXECUTE TASK ON ACCOUNT TO ROLE GN_DW_ADMIN;

-- (a) 전체 재정제 — 매일 오전 6시 KST:
-- CREATE OR ALTER TASK GN_DW.OPS.RUN_DW_PIPELINE_DAILY
--   WAREHOUSE = GN_DW_ETL_WH
--   SCHEDULE = 'USING CRON 0 6 * * * Asia/Seoul'
--   COMMENT = 'DW_PIPELINE 일일 build(run+test) 자동 실행'
-- AS
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- (b) 활성화 (생성 후 SUSPENDED → RESUME):
-- ALTER TASK IF EXISTS GN_DW.OPS.RUN_DW_PIPELINE_DAILY RESUME;

-- (c) 상태 확인:
-- SHOW TASKS LIKE 'RUN_DW_PIPELINE_DAILY' IN SCHEMA GN_DW.OPS;

-- (d) 중지(일시 정지):
-- ALTER TASK IF EXISTS GN_DW.OPS.RUN_DW_PIPELINE_DAILY SUSPEND;

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 5 — SERVING 계층 (본 파일 범위 밖, 순서 참고용)
-- ─────────────────────────────────────────────────────────────────────────────
-- 🔴 [2026-08-04 전면 교정] 종전 이 절은 **세 곳이 틀렸다**. 실측으로 확인해 바로잡았다.
--    ① helper 뷰 정본을 `02_SERVING_setup.sql` / `07 §E+§G` 로 지목했는데 둘 다 아니다 —
--       `02_SERVING_setup.sql` 은 포인터 스텁이고, `07_ENVIRONMENT_RBAC_setup.sql` 에는
--       `DIM_MONTH`·`DIM_MEMBER_CURRENT` 가 **한 줄도 없다**(grep 확인).
--       실제 정본은 **`02_GN_DW_building/08_After_Deploy_DBT.sql` §G** 다(런북 §11.3-B 가 이미
--       같은 오류를 자기교정했는데 이 파일에 반영되지 않아 「닫힌 링크」로 남아 있었다).
--    ② `13_SV_AD_배포_추가작업.sql` 은 `[DEPRECATED 2026-07-31]` 이며 **실행 가능한 라인이 0개**다.
--       `FACT_AD_COMBINED` 는 **`05_7_SV_DDL_AD.sql` 이 만든다**(2026-08-05 O37 분할 · 종전 `05_SV_DDL.sql` 398행).
--    ③ Agent 단계가 아예 빠져 있었다 — 특히 `09_2` 누락은 Agent 를 껍데기로 남긴다.
--
-- dbt 는 SILVER/GOLD 까지만 소유. SV/Agent 를 쓰려면 아래를 **이 순서대로** 별도 실행:
--   1. 02_GN_DW_building/08_After_Deploy_DBT.sql   → DBT PROJECT GRANT + SERVING GRANT + CoWork
--        §G.1 SERVING.DIM_MONTH · §G.2 SERVING.DIM_MEMBER_CURRENT
--        ⛔ [2026-08-10 O54] 이 단계는 **실행 불요** — SV 9종 base 가 전부 GOLD 로 재배선됐다(08 §G 배너 참조).
--        ★ SV DDL 보다 반드시 먼저 (SV 가 논리테이블로 참조한다)
--   2. 05_SV-Agent_ai/05_1~05_9_SV_DDL_*.sql       → SEMANTIC VIEW 9종 (helper 동봉 폐지 · O54)
--      🔴 각 파일 독립 실행(순서 무관). `05_0_SV_DDL.sql` 은 인덱스·전체검증 전용(SV 정의 없음).
--        🔴 반드시 `USE ROLE GN_DW_ADMIN` (ACCOUNTADMIN 으로 만들면 이후 재배포가 막힌다)
--   3. 05_SV-Agent_ai/09_1_AGENT_생성.sql          → Agent **껍데기** + USAGE grant + CoWork SI
--   4. 05_SV-Agent_ai/09_2_AGENT_버전업.sql        → 🔴 **Agent 스펙 본문(도구·instruction)**
--
-- 미실행 시 증상:
--   1 누락 → (O54 이후 해당 증상 소멸 — base 가 GOLD 다. 대신 `dbt build` 누락 시
--             "Table 'GN_DW.GOLD.DIM_MEMBER_CURRENT' does not exist" 가 난다)
--   4 누락 → Agent 객체는 생기고 UI 에도 보이는데 스펙이 `{"models":{"orchestration":"auto"}}` —
--            **도구 0개·instruction 0개**로 질의에 전혀 답하지 못한다(2026-08-04 실측된 실제 상태).
--
-- 전체 재구축·신규 계정 순서 정본 = `02_GN_DW_building/06_RUNBOOK.md` §11.2-B(기존 계정 최소경로)
--                                  · **§11.2-C(신규 계정 · BRONZE 만 있는 계정)**
