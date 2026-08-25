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
--              `cortex_project/agents/AGENT_MARKETING/agent_spec.yaml`   🆕 2026-08-18 O84
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
--   05_1~05_9_SV_DDL_*.sql(실적 SV) · 21_ML_SERVING_뷰_DDL.sql · 22_ML_SV_DDL.sql(ML SV)
--   → `cortex_project/agents/*/agent_spec.yaml` **정본 갱신** → **본 파일**
--   → (필요 시) 09_1 [5] 로 COMMENT 동기화 → (필요 시) 08_AGENT_spec.md 서술 동기화
--   ⚠ SV 를 바꿨는데 스펙을 안 바꿨더라도, instruction 이 SV 규칙을 사실로 안내하므로
--     SV 재배포 후에는 정본 yaml 의 서술이 여전히 맞는지 확인할 것.
--
-- ▶ 대안 경로 (동등하지 않다 — 이 프로젝트에서는 쓰지 않는다)
--   CoCo/Snowsight 의 `cortex_agent_save`/`cortex_agent_deploy` 는 **live 버전**을 만든다.
--   🔴 이 프로젝트는 **명명 버전(VERSION$n)** 방식이고 `ADD VERSION FROM` 은 live 가 있으면
--     거부되므로, save/deploy 를 섞어 쓰면 다음 버전업 때 [2] 가 매번 COMMIT 하며
--     의미 없는 버전이 누적된다. ⇒ **파일이 단일 진실원천인 본 파일 경로를 정본으로 한다.**
--     조회·검증 목적의 `cortex_agent_read` 는 무해하므로 자유롭게 쓴다.
-- ============================================================================

-- 🔴 [2026-08-18 O85 · ㉔ ⑥ 시정] `09_1` 과 웨어하우스를 통일한다(DDL 전용이라 XS 로 충분).
--   종전 `GN_DW_ANALYTICS_WH`(Medium)는 분석가 질의용이고, 워크스페이스 기본값 `GN_DW_DEV_WH` 와
--   이원화돼 실행 주체마다 청구 대상이 달라졌다. Agent **소비** 질의는 여전히 ANALYTICS_WH 다.
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;


-- ============================================================================
-- [0] ★★ 사전검증 — 참조 SV 가 라이브에 전건 실재하는가 (2026-08-18 O84 신설)
--     🔴🔴 **왜 필요한가(실측 사고)**: 파일 스펙이 `SV_ML_*` **7종**을 참조하고 있었는데
--        계정 이관 후 그 SV 가 **라이브에 0종**이었다. 그런데도 `ADD VERSION FROM` 은
--        **성공한다** — Agent 배포는 tool_resources 의 SV 실재를 검사하지 않는다.
--        결과는 **죽은 도구**이고, 사용자가 그 주제를 물을 때까지 아무도 모른다(무증상 오답 계열).
--     ⇒ 배포 **전에** 여기서 막는다. 한 건이라도 부재면 아래 SELECT 가 행을 반환한다.
--
--     ⚠ 이 블록은 **정적 목록**이라 스펙을 고치면 함께 고쳐야 한다(사본 = drift 위험).
--       스펙을 파싱해 자동 대조하는 정본 게이트는 `scripts/sv_identifier_gate.py` 이며
--       **그것이 우선한다**. 이 SQL 은 SQL 세션만으로 돌릴 때의 최소 안전장치다.
--       ⇒ 권장 절차 = `python3 scripts/sv_identifier_gate.py` (exit 0) → 본 파일 실행.
-- ============================================================================
WITH required AS (
  SELECT * FROM VALUES
    ('AGENT_MEMBER',    'SV_MEMBER_MONTHLY'),
    ('AGENT_MEMBER',    'SV_MEMBER_EVENT'),
    ('AGENT_MEMBER',    'SV_SERVICE'),
    ('AGENT_MEMBER',    'SV_EVENT_PARTICIPATION'),
    ('AGENT_MEMBER',    'SV_MEMBER_COHORT'),
    ('AGENT_MEMBER',    'SV_DEV_ACHIEVEMENT'),
    ('AGENT_MEMBER',    'SV_MEMBER_FEE'),
    ('AGENT_MEMBER',    'SV_ML_MEMBER_RISK'),
    ('AGENT_MEMBER',    'SV_ML_SPONSOR_RISK'),
    ('AGENT_MEMBER',    'SV_ML_FEE_FORECAST'),
    ('AGENT_MEMBER',    'SV_MEMBER_SPONSOR_BIZ'),   -- 🆕 2026-08-21 신설 (활동회원 캠페인/후원사업 분해)
    ('AGENT_OVERALL',   'SV_BUDGET'),
    ('AGENT_OVERALL',   'SV_AD'),
    ('AGENT_OVERALL',   'SV_MEMBER_MONTHLY'),
    ('AGENT_OVERALL',   'SV_SERVICE'),
    ('AGENT_OVERALL',   'SV_ML_DVLP_FORECAST'),
    ('AGENT_OVERALL',   'SV_ML_LTV_FORECAST'),
    ('AGENT_OVERALL',   'SV_ML_LTV_SCORE'),
    ('AGENT_OVERALL',   'SV_ML_FEATURE_IMPORTANCE'),
    ('AGENT_MARKETING', 'SV_AD'),
    ('AGENT_MARKETING', 'SV_DEV_ACHIEVEMENT'),
    ('AGENT_MARKETING', 'SV_BUDGET'),
    ('AGENT_MARKETING', 'SV_MEMBER_EVENT'),
    ('AGENT_MARKETING', 'SV_MEMBER_COHORT'),
    ('AGENT_MARKETING', 'SV_MEMBER_FEE'),
    ('AGENT_MARKETING', 'SV_MEMBER_SPONSOR_BIZ')   -- 🆕 2026-08-21 신설 (활동회원 캠페인/후원사업 분해)
  AS t(AGENT_NAME, SV_NAME)
)
SELECT r.AGENT_NAME, r.SV_NAME, '🔴 라이브 부재 — 배포하면 죽은 도구가 된다' AS VERDICT
FROM required r
LEFT JOIN GN_DW.INFORMATION_SCHEMA.SEMANTIC_VIEWS v
       ON v."SCHEMA" = 'SERVING' AND v."NAME" = r.SV_NAME
WHERE v."NAME" IS NULL
ORDER BY r.AGENT_NAME, r.SV_NAME;
--   🔴 컬럼명 주의 — `INFORMATION_SCHEMA.SEMANTIC_VIEWS` 의 컬럼은 `CATALOG`·`SCHEMA`·`NAME` 이다
--      (`TABLE_SCHEMA`/`SEMANTIC_VIEW_NAME` 이 아니다 · 2026-08-18 실측).
--      `SCHEMA`·`NAME` 은 예약어라 **큰따옴표가 필수**다. 빼면 `invalid identifier` 로 실패한다.
--   🟢 2026-08-18 실행 검증: 24건 검사 → **1행 반환**(아래 실측과 일치) · 나머지 23건 통과.
--   🔴 [2026-08-21] SV_MEMBER_SPONSOR_BIZ 2건(MEMBER·MARKETING) 추가로 검사 대상 **26건**으로 변경 —
--      위 24건 실측 수치는 이 시점 이후 stale 이다. 재실행해 새 총건수로 판정할 것.
--   🟢 기대 = **0행**.
--   🔴 2026-08-18 현재 실측 = **1행** → `AGENT_MEMBER / SV_ML_MEMBER_RISK`
--      원인: base `SERVING.ML_MEMBER_RISK_V` 미배포. 그 뷰의 dedup CTE 가
--            `GN_DW.ML.MBER_MONTHLY_INFO` 를 읽는데, 그 테이블은 사용자가 확정한
--            「예측결과 16종만」 이관 범위에서 제외된 학습·중간 37종에 속하고 계정 전역에 부재다
--            (`SNOWFLAKE.ACCOUNT_USAGE.TABLES` 조회 0건으로 확정).
--      ⇒ **AGENT_MEMBER 는 [3-A] 를 실행하기 전에 아래 둘 중 하나를 택해야 한다.**
--         ㉮ `MBER_MONTHLY_INFO` 를 추가 이관 → 21/22 DDL 의 해당 블록 실행 → 그 뒤 [3-A]
--         ㉯ 정본 yaml 에서 `analyst_ml_member_risk` 도구·리소스를 제거(도구 9종) → 그 뒤 [3-A]
--      🔴 대체 dedup 규칙을 임의로 만들지 말 것 — O74 가 **dedup 이 지표를 움직인다**고
--         실측했다(확률평균 0.3829→0.4418 · ≥0.5 건수 29,690→29,121). 규칙을 바꾸면 발행 설계와 값이 갈린다.


-- ============================================================================
-- [0-B] 🆕 정본 yaml 을 OPS 배포 스테이지로 동기화 (2026-08-18 O85-C 신설 · 착수표 ㉔ ⑦ 처방)
--     🔴 **왜 필요한가**: [3] 이 읽던 경로는 `USER$.PUBLIC."snowflake_files"` =
--        **TRIALADMIN 개인 워크스페이스**였다. `USER$` 는 **실행하는 사용자의 개인 DB 별칭**이라
--        다른 사용자·다른 계정에서는 그 경로가 존재하지 않아 **재현이 불가능**했다.
--        ⇒ 배포 원본을 `GN_DW.OPS.AGENT_SPEC_STAGE` 로 옮겨 사람 의존을 끊는다.
--     🔴 **왜 OPS 이고 SERVING 이 아닌가** = `07_ENVIRONMENT_RBAC_setup.sql` 스테이지 생성 절 주석 참조
--        (권한 · 선례 · 정렬 3축). 요지 = SERVING 은 소비 3역할에 USAGE 가 있고 OPS 는 없다.
--     🟢 **`PUT` 이 필요 없다** — `COPY FILES` 는 **서버측 복사**라 Snowsight 워크시트에서 그대로 돈다.
--     ⚠️ `PATTERN` 을 반드시 준다 — 없이 복사하면 워크스페이스의 `.folder` placeholder 까지
--        함께 복사된다(2026-08-18 O85-C 실측 · 복사 후 `REMOVE` 로 제거했다).
-- ============================================================================
USE ROLE GN_DW_ADMIN;

COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MEMBER/
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/AGENT_MEMBER/'
  PATTERN = '.*agent_spec[.]yaml';
COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_OVERALL/
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/AGENT_OVERALL/'
  PATTERN = '.*agent_spec[.]yaml';
COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MARKETING/
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/AGENT_MARKETING/'
  PATTERN = '.*agent_spec[.]yaml';


-- ============================================================================
-- [0-C] 🆕 ★ 동기화 대조 (blocking) — 스테이지가 stale 이면 여기서 막는다
--     🔴 **이 블록이 [0-B] 의 유일한 약점을 막는다** = 「파일을 고쳤는데 복사를 잊었다」.
--        복사 누락은 **에러가 아니라 조용한 구버전 배포**이므로 기계로 잡아야 한다.
--
--     🔴🔴 **[2026-08-18 O85-C 실측] MD5 로 대조하면 안 된다 — 스테이지 간 비교가 불가능하다.**
--        같은 파일을 `COPY FILES` 로 복사한 직후에도 두 스테이지의 `md5` 가 **다르게 나온다**:
--          워크스페이스 `AGENT_MEMBER` md5 = 1c99a361db6716a078a2bc7f9ad26dbc
--          OPS 스테이지  `AGENT_MEMBER` md5 = 344254073f3391715a32fff09bf2f563
--          ↔ **`size` 는 40,256 로 완전히 동일**했다(3종 전건 동일).
--        원인 = 내부 스테이지는 암호화 저장이고 `LIST` 의 `md5` 는 **암호화된 blob 의 해시**다
--        ⇒ 스테이지가 다르면 키가 달라 해시도 달라진다. **내용 동일성의 지표가 아니다.**
--        🔴 만약 이 대조를 md5 로 만들었다면 **항상 FAIL 하는 게이트**가 됐을 것이다.
--     ⚠️ **로컬 파일 바이트와도 비교하지 마라** — 로컬 `wc -c` 는 40,246B 인데 스테이지는 40,256B 다
--        (블록 패딩). **스테이지 ↔ 스테이지**만 비교한다(양쪽 모두 같은 방식으로 패딩된다).
--     ⇒ 판정축 = ① `size` 동일 ② 스테이지 `last_modified` ≥ 워크스페이스 `last_modified`.
--        ②가 「복사를 잊었다」를 잡는다(크기가 같은 수정도 시각 역전으로 걸린다).
-- ============================================================================
EXECUTE IMMEDIATE $$
DECLARE
  q_src STRING;
  q_dst STRING;
BEGIN
  LIST 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/'
       PATTERN = '.*agent_spec[.]yaml';
  q_src := SQLID;
  LIST @GN_DW.OPS.AGENT_SPEC_STAGE PATTERN = '.*agent_spec[.]yaml';
  q_dst := SQLID;

  LET rs RESULTSET := (
    WITH src AS (
      SELECT REGEXP_SUBSTR("name", 'AGENT_[A-Z]+') AS agent, "size" AS sz,
             TO_TIMESTAMP_NTZ(REPLACE("last_modified", ' GMT', ''),
                              'DY, DD MON YYYY HH24:MI:SS') AS lm
        FROM TABLE(RESULT_SCAN(:q_src))
    ), dst AS (
      SELECT REGEXP_SUBSTR("name", 'AGENT_[A-Z]+') AS agent, "size" AS sz,
             TO_TIMESTAMP_NTZ(REPLACE("last_modified", ' GMT', ''),
                              'DY, DD MON YYYY HH24:MI:SS') AS lm
        FROM TABLE(RESULT_SCAN(:q_dst))
    )
    SELECT COALESCE(s.agent, d.agent) AS agent,
           s.sz AS ws_size, d.sz AS stage_size,
           s.lm AS ws_modified, d.lm AS stage_modified,
           CASE WHEN d.agent IS NULL THEN 'MISSING_IN_STAGE'
                WHEN s.agent IS NULL THEN 'ORPHAN_IN_STAGE'
                WHEN s.sz <> d.sz    THEN 'SIZE_MISMATCH'
                WHEN d.lm < s.lm     THEN 'STAGE_STALE'
                ELSE 'OK' END AS verdict
      FROM src s FULL OUTER JOIN dst d ON s.agent = d.agent
     ORDER BY 1
  );
  RETURN TABLE(rs);
END;
$$;
--   🔴 **`verdict` 가 전건 `OK` 가 아니면 [2]·[3] 으로 내려가지 마라.**
--      · `STAGE_STALE`·`SIZE_MISMATCH` ⇒ [0-B] 를 다시 돌린다.
--      · `MISSING_IN_STAGE`   ⇒ [0-B] 의 해당 COPY FILES 가 실패했다.
--      · `ORPHAN_IN_STAGE`    ⇒ 워크스페이스에서 지운 Agent 가 스테이지에 남았다 ⇒ `REMOVE` 로 정리.
--   🟢 [2026-08-18 O85-C 최초 실행 결과] 3종 전건 `OK`
--      (MARKETING 32,256 · MEMBER 40,256 · OVERALL 31,248 · 계정 `UA93987`).
--   🔴 이 수치는 스펙을 고치면 바뀐다 — **판정은 `verdict` 로 하고 수치를 인용하지 마라**(`R2-8-4-a`).


-- ============================================================================
-- [1] 갱신 전 상태 확인 — 어느 버전이 서비스 중이고 live 가 있는지
--     live 존재 판별 = spec_file_path 가 `…/versions/live/` 인 행("name" IS NULL)
-- ============================================================================
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_OVERALL;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MARKETING;
--   2026-08-18 실측: MEMBER=VERSION$3(도구 7) · OVERALL=VERSION$3(도구 4) · MARKETING=VERSION$1(빈 스펙)
--   🔴 라이브 도구 수가 정본 yaml(10·8·6)보다 적다 = **O74 의 버전업이 이 계정에 미이행**이다.
--      본 파일 [3] 이 그 격차를 해소한다.

--   🔴 [2026-08-18 O85-C2 정정] 위 「2026-08-18 실측」은 계정 `DV07626` 시점이다(`P169`).
--      현 계정(`UA93987`)에는 **Agent 0종**이라 이 세 SHOW 는 모두 객체 부재로 실패한다.
--      ⇒ **`09_1` 을 먼저 돌려 Agent 3종을 만든 뒤** 이 파일을 실행한다(`09_1 [0-E]` 로 확인).

-- 정본 파일이 stage 에 실제로 있는지 확인 (파일명 `agent_spec.yaml` 필수)
--   🟠 [2026-08-18 O85-C2] 이 LIST 는 이제 **`[0-C]` 대조와 중복**이다(참고용으로 남긴다).
--      배포 판정은 `[0-C]` 의 `verdict` 로 한다 — 이 LIST 결과를 근거로 쓰지 말 것.
LIST 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/';
--   기대: AGENT_MEMBER/agent_spec.yaml · AGENT_OVERALL/agent_spec.yaml · AGENT_MARKETING/agent_spec.yaml
--   ※ 워크스페이스에 방금 추가·수정한 파일도 versions/live 에 즉시 반영된다(실측).
--   🟢 **[2026-08-18 O85-C2 실측] `versions/head` 와 `versions/live` 는 구별되지 않는다.**
--      같은 파일을 두 경로로 `LIST` 하면 **size·md5·시각이 완전히 동일**하고, `head` 로 조회해도
--      반환 `name` 이 **`/versions/live/…` 로 정규화**돼 나온다(`USER$` 개인 워크스페이스 · 25,680B 실측).
--      ⇒ **`ALTER WORKSPACE … COMMIT` 은 이 파일의 선행조건이 아니다.** 저장만 하면 곧 반영된다.
--      ⚠️ Git 연동 워크스페이스·공유 워크스페이스에서는 다를 수 있다 — 그때는 다시 실측하라.
--   ⚠ 단 **스테이지 동기화에는 짧은 지연이 있다** — 방금 저장했다면 파일 크기가
--     로컬과 일치하는지 확인한 뒤 진행할 것(동기화 중 읽으면 잘린 내용이 보인다 · O84 실측).


-- ============================================================================
-- [2] live 선소진 (멱등) — live 가 있으면 COMMIT, 없으면 skip
--     `ADD VERSION FROM` 은 live 가 있으면 거부되므로 반드시 먼저 처리한다.
--     🔴 [2026-08-18 O84] AGENT_MARKETING 분기 추가. 09_1 [1-C] 가 방금 생성한 Agent 는
--        VERSION$1 + **live 가 자동 생성**된 상태이므로 이 블록이 반드시 COMMIT 해야 한다.
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
    res := res || 'AGENT_OVERALL=committed ';
  ELSE
    res := res || 'AGENT_OVERALL=no_live ';
  END IF;

  SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MARKETING;
  LET k INT := (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "name" IS NULL);
  IF (k > 0) THEN
    ALTER AGENT GN_DW.SERVING.AGENT_MARKETING COMMIT COMMENT = 'live 소진(버전업 직전 스냅샷)';
    res := res || 'AGENT_MARKETING=committed';
  ELSE
    res := res || 'AGENT_MARKETING=no_live';
  END IF;

  RETURN res;
END;
$$;


-- ============================================================================
-- [3] ★ 정본 yaml 로 새 버전 발행 — 이 파일의 본체
--     성공 시 새 VERSION$N 이 생성되고 자동으로 is_default=true 가 된다.
--     🔴🔴 **[2026-08-18 O85-C 모순 적발 · 미해소] 바로 위 한 줄이 정본과 충돌한다.**
--        `cortex_project/cortex-project.yaml` 24행 = *"④ `ALTER AGENT … SET DEFAULT_VERSION = 'VERSION$n'`
--        (**발행만으로 default 가 되지 않는다** — P66)"*.
--        ⇒ 「자동 is_default」 ↔ 「자동이 아니다(P66)」 가 정면으로 어긋난다.
--        🔴 **O85-C 는 어느 쪽도 확정하지 못했다** — 이 계정에 Agent 가 0종이라 실측이 불가능하다.
--        ⇒ **배포 직후 `[5]` 의 `SHOW VERSIONS` 로 `is_default` 를 반드시 눈으로 확인**하고,
--          false 면 아래를 실행한 뒤 **둘 중 틀린 기재를 그때 철회**하라(둘 다 남겨두지 마라).
--          `ALTER AGENT GN_DW.SERVING.<AGENT> SET DEFAULT_VERSION = 'VERSION$n';`
--     ※ 성공 메시지가 "Version nullsuccessfully created" 로 보이는 것은 표시 버그이며
--       실제 버전은 정상 생성된다(SHOW VERSIONS 로 확인 · 2026-07-31 실측).
--     🔴 **[0] 이 0행이 아닌 Agent 는 그 블록을 실행하지 말 것.** 죽은 도구가 생긴다.
-- ============================================================================

-- ---- [3-A] AGENT_MEMBER ---- 🟢 [2026-08-21 재검증] [0] 26건 검사 → **0행**(전건 통과, SV_ML_MEMBER_RISK
--   포함). 종전 차단 사유("AGENT_MEMBER / SV_ML_MEMBER_RISK 라이브 부재")는 이 계정에서 해소됐다.
--   실행 전 반드시 이 세션에서 [0] 을 다시 돌려 0행을 직접 확인할 것(계정 상태는 재이관 시 달라진다).
ALTER AGENT GN_DW.SERVING.AGENT_MEMBER
  ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MEMBER'
  COMMENT = 'agent_spec.yaml 정본 적용 — 도구 11종(ML 3 포함, SV_MEMBER_SPONSOR_BIZ 신설) · 추천질문 31';

-- ---- [3-B] AGENT_OVERALL ---- 🟢 [0] 통과(ML SV 4종 2026-08-18 배포 완료) ⇒ 실행 가능
ALTER AGENT GN_DW.SERVING.AGENT_OVERALL
  ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_OVERALL'
  COMMENT = 'agent_spec.yaml 정본 적용 — 도구 8종(ML 4 포함) · 추천질문 10';

-- ---- [3-C] AGENT_MARKETING ---- 🟢 [0] 통과(참조 SV 7종 전건 라이브, SV_MEMBER_SPONSOR_BIZ 포함) ⇒ 실행 가능
ALTER AGENT GN_DW.SERVING.AGENT_MARKETING
  ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MARKETING'
  COMMENT = 'agent_spec.yaml 정본 적용 — 도구 7종(SV_MEMBER_SPONSOR_BIZ 신설) · 추천질문 11 · 마케팅 보고서 5분석구분';

--   🆕 🔴 **[2026-08-18 O85-C] 경로가 개인 워크스페이스 → OPS 스테이지로 바뀌었다**(착수표 ㉔ ⑦).
--      종전 = `snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/<AGENT>`
--      현행 = `@GN_DW.OPS.AGENT_SPEC_STAGE/<AGENT>`
--      🟢 문법 검증 = `ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MEMBER'` 컴파일 통과
--         (2026-08-18 O85-C · only_compile · 객체 부재 단계까지 진행 = 경로 문법 정상).
--      🔴 **[0-B] 동기화와 [0-C] 대조를 건너뛰고 이 블록을 돌리지 마라** — 스테이지가 stale 이면
--         **구버전 스펙이 조용히 배포**된다(에러가 나지 않는다).


-- ============================================================================
-- [4] (선택) 개발 재개용 live 재생성
--     Snowsight UI 에서 편집하려면 live 가 필요하다.
--     파일 기반 운영만 한다면 생성하지 않는 편이 낫다 — live 가 있으면 [3] 이 거부되므로
--     다음 버전업 때 [2] 가 한 번 더 COMMIT 하며 불필요한 버전이 늘어난다.
-- ============================================================================
-- ALTER AGENT GN_DW.SERVING.AGENT_MEMBER    ADD LIVE VERSION FROM LAST;
-- ALTER AGENT GN_DW.SERVING.AGENT_OVERALL   ADD LIVE VERSION FROM LAST;
-- ALTER AGENT GN_DW.SERVING.AGENT_MARKETING ADD LIVE VERSION FROM LAST;


-- ============================================================================
-- [5] 검증
-- ============================================================================
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_OVERALL;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MARKETING;
--   기대: 최신 VERSION$N 이 is_default=true · agent_spec 에 tools/instructions 반영 ·
--         이전 버전은 is_default=false 로 보존(롤백 가능)

-- 🟢 [2026-08-18 O84 신설] **도구·문항 수를 눈으로 세지 말고 기계로 센다.**
--    종전 검증은 `DESCRIBE AGENT` 출력을 사람이 훑는 방식이었고, 그래서 라이브 7종 ↔ 정본 10종
--    격차가 오래 발견되지 않았다. 아래는 SHOW 직후 RESULT_SCAN 으로 세는 방식이다.
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_OVERALL;
SELECT "name" AS VER, "is_default" AS IS_DEF,
       REGEXP_COUNT("agent_spec", 'tool_spec')  AS TOOLS,
       REGEXP_COUNT("agent_spec", '"question"') AS QUESTIONS,
       REGEXP_COUNT("agent_spec", 'SV_ML_')     AS ML_REFS
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY VER;
--   기대(AGENT_OVERALL 버전업 후): 최신 버전 TOOLS=8 · QUESTIONS=10 · ML_REFS≥4
--   같은 패턴으로 MEMBER(11·31) · MARKETING(7·11 · ML_REFS=0) 를 확인한다.
--   🔴 [2026-08-21] MEMBER·MARKETING 값은 SV_MEMBER_SPONSOR_BIZ 신설분 반영(종전 10·10 · 6·10 은 stale).

-- grant·SI 가 보존됐는지 (이 경로는 파괴하지 않아야 정상)
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MEMBER;    -- OWNERSHIP + USAGE×3 = 4행
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_OVERALL;   -- 동일 4행
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MARKETING; -- 동일 4행
--   판정: created_on 이 09_1 실행 시각 그대로면 보존된 것이다(재부여되지 않았다는 증거).
USE ROLE ACCOUNTADMIN;
SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;  -- **3행** 유지
--   🔴 [2026-08-18 O85-C2] **SI 객체가 없으면 이 한 줄이 컴파일 단계에서 죽는다**
--      (실측 = 계정 `UA93987` 에 부재 · `09_1 [0-D]`·`[4]` 와 같은 축).
--      ⇒ `09_1 [4-㉠]` 을 돌리지 않았다면 이 줄을 건너뛰고 **CoWork UI 에서 눈으로 확인**한다.
--      🔴 그 경우 판정은 「미확인」이다 — 「노출됨」으로 적지 마라.
USE ROLE GN_DW_ADMIN;

-- 🔴 마지막으로 COMMENT 동기화가 필요한지 확인한다 — 도구 수를 늘렸다면 09_1 [5] 를 실행한다.
SHOW AGENTS IN SCHEMA GN_DW.SERVING;
--   comment 의 "SV N종" 이 위 TOOLS 값과 일치해야 한다. 어긋나면 09_1 [5] 실행.


-- ============================================================================
-- [6] 롤백 — 이전 버전으로 즉시 되돌리기
--     명명 버전은 불변 스냅샷이므로 DEFAULT 를 옮기는 것만으로 롤백이 끝난다.
--     🔴 `ADD VERSION FROM` 이 자동으로 default 를 옮기므로, 문제가 생기면 즉시 되돌릴
--        직전 버전 번호를 **버전업 전에 적어 둘 것**(2026-08-18 기준 3종 모두 VERSION$3·$3·$1).
-- ============================================================================
-- SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_OVERALL;   -- 되돌릴 VERSION$N 확인
-- ALTER AGENT GN_DW.SERVING.AGENT_OVERALL   SET DEFAULT_VERSION = 'VERSION$3';
-- ALTER AGENT GN_DW.SERVING.AGENT_MARKETING SET DEFAULT_VERSION = 'VERSION$1';
-- ALTER AGENT GN_DW.SERVING.AGENT_OVERALL   SET DEFAULT_VERSION = LAST;   -- 최신으로 복귀


-- ============================================================================
-- [7] 트라이얼 제약
-- ============================================================================
-- ▶ 트라이얼 계정은 **에이전트 자연어 실행이 차단**된다:
--   `SNOWFLAKE.CORTEX.DATA_AGENT_RUN` → 'Access denied for trial accounts'.
--   → NL→SQL 라우팅 스모크·회귀는 CoWork UI(ai.snowflake.com)에서 수동 수행한다.
--   ↔ 버전 발행·검증(본 파일 전체)과 SV 데이터층 ground-truth 조회는 트라이얼에서도 가능하다.
--   🔴 그래서 **「배포 완료」가 「라우팅 검증 완료」를 뜻하지 않는다** — 각 Agent 의
--     추천질문 10개를 CoWork UI 에서 1회씩 눌러 도구 라우팅을 확인하는 것이 최소 스모크다.
--
-- ▶ 특정 버전만 지목해 실행(paid 이관 후)
--   SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN('GN_DW.SERVING.AGENT_MEMBER!VERSION$3',
--     $${"messages":[{"role":"user","content":[{"type":"text","text":"2024년 납부율은?"}]}]}$$);
--   버전 지목자: VERSION$N · 별칭 · 단축어(LIVE·FIRST·LAST·DEFAULT). 생략 시 DEFAULT.
-- ============================================================================
