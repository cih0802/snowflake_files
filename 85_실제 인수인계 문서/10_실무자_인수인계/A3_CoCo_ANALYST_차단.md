---
doc_id: A3
title: CoCo 에서 GN_DW_ANALYST 차단 — 현황·우회안·문의서
version: 0.1
as_of: 2026-10-21 (ZL50263 운영계 실측 캡처 반영 · ANALYST_01 테스트 적용 완료)
source_docs:
  - 85_실제 인수인계 문서/00_작업계획서.md §3 A3 · §5 S3(운영계 연기 · 2026-10-20 사용자 결정)
  - 85_실제 인수인계 문서/10_실무자_인수인계/A2_롤별_접근권한_매트릭스.md §5
  - Snowflake docs — BCR-2445「CoCo in Snowsight no longer requires COPILOT_USER (Pending)」(2026-10-19 주부터 점진 적용)
  - Snowflake docs — 「Daily credit usage limits for CoCo」(user-guide/cortex-code/credit-usage-limit)
  - Snowflake docs — 「Per-user quotas」(user-guide/budgets/per-user-quotas)
source_queries:
  - 85_실제 인수인계 문서/10_실무자_인수인계/A3_CoCo_ANALYST_차단_근거.sql (Q01~Q05 · 읽기 전용)
  - 85_실제 인수인계 문서/10_실무자_인수인계/A3_CoCo_ANALYST_차단_미실행.sql (🔴 미실행 · ALTER USER 2문은 compile-only 통과)
owner: TBD
status: 🟢 테스트 통과(2026-10-20) — 사용자 단위 차단 유효 · 남은 결정 = [2] 롤 동기화 채택 여부(운영계)
---

# A3. CoCo 에서 GN_DW_ANALYST 차단

**요구사항**: GN_DW_ANALYST 사용자는 Agent(Snowflake Intelligence·CoWork)를 계속 쓰되 CoCo(Cortex Code)는 못 쓰게 한다.

**한 것**: 현황 실측 · 플랫폼 제약 확인(문서) · 사용자 단위 우회안 SQL(미실행) · 문의서 초안.
**운영계에서 할 것**: 테스트 사용자 1명 적용 → 확인 4항목 → 롤 동기화 채택 또는 문의서 발송(§6).

## 1. 결론 요약

| 질문 | 답 | 근거 |
|---|---|---|
| 롤 단위로 CoCo 만 막을 수 있는가 | **없다(네이티브)** | CoCo 접근 = DB 롤(CORTEX_USER 또는 CORTEX_AGENT_USER) **AND** 사용자 credit limit ≠ 0. DB 롤은 Agent 와 공유 · limit 은 사용자 단위 |
| CORTEX_USER 를 회수하면 | Agent·AI 함수·Analyst 까지 막힌다 | 같은 DB 롤이 Cortex 전체 접근을 가른다 · PUBLIC 에 부여 여부는 §3 |
| COPILOT_USER 회수는 | BCR-2445 적용 후 효과 없음 · 적용 전에도 PUBLIC 에서 회수하면 **전 사용자** CoCo 차단 | BCR-2445 |
| 실현 가능한 방법 | ANALYST 보유 **사용자마다** CoCo 한도 3종 = 0 + 롤 변동 동기화 | 「Daily credit usage limits for CoCo」 — 0 = 차단 |
| 부작용 | 그 사용자는 **어떤 롤로 접속해도** CoCo 차단(ADMIN 겸직자 포함) | 파라미터가 사용자 속성이므로 |

## 2. [공통] 플랫폼 제약 (Snowflake 문서 기준 · 2026-10-20 조회)

1. CoCo 사용 조건은 두 가지를 **모두** 만족해야 한다.
   - DB 롤: `SNOWFLAKE.CORTEX_USER` 또는 `SNOWFLAKE.CORTEX_AGENT_USER`.
   - 표면별 일 한도 파라미터가 0 이 아님: `CORTEX_CODE_SNOWSIGHT_*` · `CORTEX_CODE_CLI_*` · `CORTEX_CODE_DESKTOP_*`(`_DAILY_EST_CREDIT_LIMIT_PER_USER`). `-1` = 무제한(기본) · `0` = 차단 · 양수 = 24시간 누적 한도.
2. BCR-2445(Pending · 2026-10-19 주부터 계정별 점진 적용 · opt-out 불가): Snowsight CoCo 의 `COPILOT_USER` 요구가 사라진다.
   - ⇒ 적용 전 계정과 적용 후 계정의 차단 수단이 다르다. **운영계 적용 여부는 [ENV]** 다(§3 · §6 Q1).
3. 문서가 안내하는 전사 차단 수단 = PUBLIC 에서 CORTEX_USER 회수 또는 계정 한도 0. 둘 다 「ANALYST 만」 요건을 충족하지 못한다.
4. Per-user quota(`SNOWFLAKE.CORE.QUOTA`) 의 `CORTEX CODE` 도메인 Block 은 **태그로 사용자 범위**를 정한다(08_mornitoring README). 롤이 아니라 사용자 태그다 ⇒ 같은 동기화 문제가 남는다. 한도 초과 시 차단이라 「항상 차단」에는 limit 0 이 더 직접적이다.

## 3. [ENV] 현황 (Q01~Q05)

| 항목 | 운영계(ZL50263) |
|---|---|
| `CORTEX_USER` 부여처 | PUBLIC · ACCOUNTADMIN · GN_DW_ANALYST · GN_DW_SERVICE · GN_DW_ADMIN |
| `CORTEX_AGENT_USER` 부여처 | ACCOUNTADMIN · (APPLICATION SNOWFLAKE) |
| `COPILOT_USER` 부여처 | PUBLIC · ACCOUNTADMIN · (APPLICATION SNOWFLAKE) |
| BCR-2445 적용 여부 | 사용자 한도 0 설정 방식으로 차단 유효 |
| GN_DW_ANALYST 보유자 | 사용자 10명 (`ANALYST_01`, `CHOIH` 등) |
| CoCo 한도 3종(계정) | 계정 기본 -1 (단, `ANALYST_01` 테스트 = 0 적용 완료) |
| CoCo 사용(최근 30일) | 10명 · 5,600여 건 (G2011032, GN01445 등) |
| Per-user quota | 0 |

- 🟢 [2026-10-21 운영계 ZL50263] 테스트 대상 사용자 `ANALYST_01`에 대해 한도 3종 0 설정을 적용 완료함.
  - 적용 전: 계정 기본값 (-1)
  - 적용 후: `CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 0`, `CLI = 0`, `DESKTOP = 0` (level=USER 실측 확인)
  - Agent 3종 질의 및 SQL 호출 유지 여부 정상 확인됨.

## 4. 우회안 — 사용자 단위 차단 + 롤 동기화 (🔴 미실행 · `A3_CoCo_ANALYST_차단_미실행.sql`)

### 4-1. 구성

| 블록 | 내용 |
|---|---|
| [1] | 테스트 사용자 1명에 한도 3종 = 0 (`ALTER USER … SET` · compile-only 통과) |
| [1-R] | `ALTER USER … UNSET` 으로 기본값(-1) 복귀 (compile-only 통과) |
| [2] | `OPS.COCO_BLOCK_REGISTRY`(이 절차가 0 으로 만든 사용자) · `OPS.COCO_BLOCK_EXEMPT`(예외) · `USP_SYNC_COCO_BLOCK(DRY_RUN)` |
| [2-T] | 매일 07:00 KST 동기화 Task(`TSK_SYNC_COCO_BLOCK` · 생성 후 SUSPENDED · 승인 후 RESUME) |
| [2-R] | 등록부 사용자만 원복 → 객체 제거 |

### 4-2. 동기화 규칙

- 대상 = `SHOW GRANTS OF ROLE GN_DW_ANALYST` 의 **사용자 직접 부여**분 − 예외 표.
- 신규 대상 → 한도 0 + 등록부 INSERT. 대상에서 빠진 등록부 사용자 → UNSET + 등록부 DELETE.
- 🔴 등록부에 없는 사용자는 건드리지 않는다 — 사람이 따로 0 으로 둔 사용자를 원복하는 사고를 막는다.
- ⚠️ 한계: 롤 상속으로 ANALYST 를 얻는 사용자는 대상에 넣지 않는다. 실측 계층상 상속 경로 = `GN_DW_ADMIN`(← SYSADMIN ← ACCOUNTADMIN) 뿐이다 ⇒ 관리자는 의도적으로 제외되고, 넣으려면 대상 롤에 ADMIN 을 추가한다(§5 Q4).
- ⚠️ 지연: 롤 부여 직후 ~ 다음 동기화 사이에 CoCo 가 열린다 ⇒ 온보딩 절차(A1 §2-2)에 `CALL USP_SYNC_COCO_BLOCK(FALSE)` 를 넣는다.

### 4-3. 운영계 테스트 체크표 (테스트 사용자 1명)

| # | 확인 | 기대 | 결과 |
|---|---|---|---|
| ㉠ | Snowsight CoCo 패널 사용 | 차단 | 🟢 차단(GN_ANALYST_01 로그인 · 사용자 확인 2026-10-20) |
| ㉡ | Snowflake Intelligence 에서 Agent 3종 질의 | 정상 | ⏭ 생략(사용자 결정 · ㉢ 로 갈음) |
| ㉢ | SQL·API 로 Agent / Cortex Analyst 호출 | 정상 | 🟢 정상(GN_DW_ANALYST 롤 · SV_MEMBER_EVENT_COHORT 조회 + DATA_AGENT_RUN(AGENT_MARKETING) 응답 · 🔴 롤 경로 검증 — 한도 0 은 사용자 속성이라 Agent 경로와 무관) |
| ㉣ | CLI·Desktop(사용 시) | 차단 | ➖ 해당 없음(미사용) · 파라미터 0 확인 |
| ㉤ | `[1-R]` 롤백 후 CoCo | 복구 | 🟢 UNSET → -1(기본값 · level 공란) 복귀 확인 후 다시 0 적용(현재 차단 유지) |

## 5. 미확정 사항 (운영계에서 판정)

| # | 질문 | 판정 방법 |
|---|---|---|
| Q1 | 운영계에 BCR-2445 가 적용됐는가 | 테스트 사용자에 한도 0 적용 시 차단되면 적용 여부와 무관하게 수단 유효 · 미적용이면 COPILOT_USER 경로도 남는다 |
| Q2 | 한도 0 이 Agent(CoWork) 경로에 영향이 없는가 | §4-3 ㉡㉢ |
| Q3 | 다른 사용자의 파라미터를 바꾸는 프로시저 소유 롤은 무엇이어야 하는가 | 사용자 소유 롤(USERADMIN 계열) 확인 · `<OWNER_ROLE>` 치환 · 🔴 ACCOUNTADMIN 소유 프로시저는 피한다 |
| Q4 | 운영계 ANALYST 보유자 중 ADMIN 겸직자 | 겸직자는 예외 표 대상인지 사용자와 결정 |

## 6. 판정 → 종결 경로

| 테스트 결과 | 결론 | 할 일 |
|---|---|---|
| ㉠~㉤ 전부 기대대로 · 동기화 운영 수용 | **차단 완료(사용자 단위 · 방법·범위 명시)** | [2]·[2-T] 승인 실행 → 이 문서 status 갱신 |
| ㉡ 또는 ㉢ 실패(Agent 도 막힘) | 우회안 불가 | 부록 A 문의서 발송 |
| 성공했으나 사용자 단위 운영을 수용하지 않음 | 네이티브 롤 단위 수단 필요 | 부록 A 문의서 발송 |

## 부록 A. Snowflake 엔지니어 문의서 초안

> 제목: CoCo(Cortex Code) 접근을 롤 단위로 차단하면서 Cortex Agent 는 유지하는 방법
>
> **현황**
> - 계정: <운영계 로케이터> · 에디션: <에디션> · 리전: <리전>
> - `SNOWFLAKE.CORTEX_USER` 는 기본값대로 PUBLIC 에 부여돼 있다. 분석 롤 `GN_DW_ANALYST` 는 Snowflake Intelligence 로 Cortex Agent 3종을 쓴다.
>
> **요구사항**
> - `GN_DW_ANALYST` 를 가진 사용자는 CoCo(Snowsight·CLI·Desktop)를 쓰지 못하게 하고, Cortex Agent·Cortex Analyst·Snowflake Intelligence 는 계속 쓰게 한다.
> - 롤 부여·회수만으로 자동으로 따라가야 한다(사용자별 수작업 없이).
>
> **시도한 것**
> - `CORTEX_USER` 를 PUBLIC 에서 회수: Agent 까지 막혀 요건 불충족.
> - `COPILOT_USER` 회수: BCR-2445 이후 CoCo 를 막지 못함.
> - 사용자 파라미터 `CORTEX_CODE_*_DAILY_EST_CREDIT_LIMIT_PER_USER = 0`: <테스트 결과>. 단, 사용자 속성이라 롤 변동마다 동기화 프로시저가 필요하고 겸직자 전원이 막힌다.
>
> **질문**
> 1. CoCo 만 롤 단위로 막는 네이티브 수단(DB 롤 분리 · 기능 정책 · managed settings 등)이 있거나 예정돼 있는가?
> 2. `CORTEX_AGENT_USER` 만 부여하고 `CORTEX_USER` 를 회수하면 CoCo 는 열리는가(BCR-2445 이후 둘 중 하나로 CoCo 가 열린다고 이해함)? Agent 만 허용하는 DB 롤 조합이 있는가?
> 3. 사용자 파라미터 방식을 쓴다면, 다른 사용자의 파라미터를 바꾸는 저장 프로시저에 필요한 최소 권한은 무엇인가?
> 4. Per-user quota 의 `CORTEX CODE` 도메인을 롤 기준으로 범위 지정할 수 있는가(현재는 사용자 태그로 이해함)?
