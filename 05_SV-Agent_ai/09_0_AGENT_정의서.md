<!-- LLM-METADATA
doc_id: AGENT_DEFINITION_BRIEF
doc_role: Agent 4종 정의서(간략) — 이름·역할·소관·정본 경로·배포 경로의 단일 색인 · 09_1/09_2/24 SQL 의 서술 정본
project: GN_DW (굿네이버스)
created: 2026-10-03
created_by: O200-D
depends_on: cortex_project/agents/*/agent_spec.yaml(도구·지시문 정본) · 08_AGENT_spec.md(상세 설계·평가)
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 09_0 — Agent 정의서 (간략)

> 🔴 **도구 목록·지시문의 정본은 `cortex_project/agents/<AGENT>/agent_spec.yaml` 이다.**
> 이 문서는 「어느 Agent 가 무엇을 맡는가」만 적는다 — 도구 수·SV 개수를 여기 적지 않는다(적으면 stale 이 된다 · `R3-9 ㉦`).
> 수는 아래 「실측 방법」으로 센다.
>
> 🟢 SQL 파일(`09_1`·`09_2`·`24`)의 Agent 설명은 이 문서를 가리킨다.
> `09_1` 의 `CREATE AGENT … COMMENT` 문안은 **yaml 연결 전 초기 샘플**이라 실제 도구와 다를 수 있다(사용자 결정 2026-10-03).

## 1. Agent 4종

| Agent | 화면 이름 | 역할 | 소관(질문 범위) | 기준 |
|---|---|---|---|---|
| `AGENT_MEMBER` | 회원 분석 | 회원 도메인 실적·예측 | 회원 월실적·상태전이·발송·행사·코호트·결연활동·개발목표달성·회비·후원약정 + ML 회원/후원건/회비/일시전환 예측 + 회원실·기획실 부서 자체 수식 집계 | GN_DW |
| `AGENT_EXECUTIVE` | 경영·전사 분석 | 전사 경영·재무 요약 | 사업목표·예산·광고·회원월실적·발송 + ML 개발금액·LTV·기여요인 | GN_DW |
| `AGENT_MARKETING` | 마케팅 분석 | 마케팅·광고 성과 | 사업목표·광고·개발목표달성·예산·전환회원·코호트·캠페인회비·후원약정 + ML 개발금액·회원위험 | GN_DW |
| `AGENT_MSTR` | MSTR 리포트 | MSTR 이관 결과 조회 | MSTR 정기회원 후원개발 리포트(1차 이관 범위) | 🔴 **MSTR** |

- 🔴 **기준이 다른 Agent 끼리 수치를 합산하지 않는다** — MSTR 기준과 GN_DW 기준은 같은 지표명이라도 정의가 다르다.
  · 근거 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0199-A.md` ▣O199-A-3 · 각 스펙 `orchestration` 절.
- 🟢 같은 SV 를 여러 Agent 가 도구로 쓸 수 있다(SV 를 복사하지 않는다) — 예: `SV_MEMBER_MONTHLY` = MEMBER·EXECUTIVE.
- 🟢 MSTR SV 는 현업 승인 후 기존 Agent 에 **같은 SV 를 도구로 추가**한다(O199-A-3).

## 2. 정본 경로

| 대상 | 경로 |
|---|---|
| 스펙(도구·지시문·추천질문) | `cortex_project/agents/<AGENT>/agent_spec.yaml` |
| 상세 설계·평가 | `05_SV-Agent_ai/08_AGENT_spec.md` · `30_마케팅_AGENT_설계.md`(MARKETING) |
| SV DDL | `05_1`~`05_13_SV_DDL_*.sql` · `22_ML_SV_DDL.sql` · `23_MSTR_SV_DDL.sql` |
| 배포 스테이지 | `@GN_DW.OPS.AGENT_SPEC_STAGE/<AGENT>/agent_spec.yaml` |

## 3. 배포 경로

| 단계 | 파일 | 대상 |
|---|---|---|
| 최초 생성(껍데기·grant·CoWork) | `09_1_AGENT_생성.sql` | MEMBER · EXECUTIVE · MARKETING |
| 최초 생성 + 첫 버전(단독) | `24_MSTR_AGENT_배포.sql` | MSTR |
| 스펙 버전업(이후 전부) | `09_2_AGENT_버전업.sql` | 4종 전부 |
| 운영 중단·보존 | `09_3_AGENT_중단보존.sql` | — |
| (폐기 스텁) | `09_0_AGENT_spec_구현.sql` | 실행 대상 아님 · 2026-07-31 분해 |

- 🔴 owner = **GN_DW_ADMIN**(`02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql:38`) — ACCOUNTADMIN 세션으로 만들면 이후 버전업이 막힌다
  (`20_issue/10_진단_원인분석_조각/10_진단_원인분석-015.md:57`).
- 🔴 COMMENT·PROFILE 은 스펙이 아니라 DDL 속성이다 ⇒ `09_2` 버전업으로는 바뀌지 않는다.

## 4. 실측 방법 (수는 여기서 센다)

```sql
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;   -- <AGENT> 를 바꿔 4종 반복
SELECT "name", "is_default", REGEXP_COUNT("agent_spec", 'tool_spec') AS TOOLS
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "is_default" = 'true';
```

- 파일 쪽 = `python3 scripts/sv_identifier_gate.py`(스펙 폴더 자동 탐색 · 참조 SV 실재 대조).
- 🟢 2026-10-03 O200-D 대조 = 4종 전부 **스펙 도구 수 = 라이브 기본 버전 도구 수**(계정 pw69582). 수치는 위 방법으로 다시 잰다.

_Co-authored with CoCo_
