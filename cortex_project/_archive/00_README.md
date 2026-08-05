# cortex_project/_archive — 폐기된 Agent 스펙 사본

> **복원하지 말 것.** 이 폴더의 파일은 정본이 아니며, 이력 추적을 위해서만 보존한다.

## 왜 이관했는가 (2026-08-05 O38)

Agent 스펙 yaml 이 **두 경로에 존재하고 양쪽이 서로 「정본」이라 선언**돼 있었다.

| 경로 | 상태 |
|---|---|
| `cortex_project/AGENT_*.agent.yaml` (루트) | ⛔ **이 폴더로 이관** |
| `cortex_project/agents/<AGENT>/agent_spec.yaml` | 🟢 **정본** |

**정본 판정 근거는 「배포되는 파일이 정본」이다.** 실제 배포는
`05_SV-Agent_ai/09_2_AGENT_버전업.sql` 의

```sql
ALTER AGENT GN_DW.SERVING.AGENT_MEMBER
  ADD VERSION FROM 'snow://workspace/…/cortex_project/agents/AGENT_MEMBER'
```

로 **디렉터리**를 stage 에서 직접 읽는다. 즉 라이브 Agent 가 되는 파일은
`agents/<AGENT>/agent_spec.yaml` 이고, 루트 yaml 은 아무 데도 배포되지 않는 사본이었다.
(파일명은 반드시 `agent_spec.yaml` — 공식 문서의 `agent.yaml` 예시는 부정확하며
틀리면 `No spec file present for the agent` 로 실패한다. 2026-07-31 실측)

## 이관 파일

| 파일 | 실측 판정 |
|---|---|
| `AGENT_MEMBER.agent_STALE_20260804.yaml` | 🔴 **O33 이전 판본**. 도구 **4개**·샘플 **8개**·`system` 에 O33·O35·O38 흔적 없음. 정본은 도구 **6개**(`analyst_member_cohort`·`analyst_dev_achievement` 추가)·샘플 **19개**. **이 파일로 재배포하면 O33~O38 규칙과 도구 2개가 통째로 소실된다.** |
| `AGENT_OVERALL.agent_DUPLICATE_20260804.yaml` | 🟢 `agents/AGENT_OVERALL/agent_spec.yaml` 과 **byte-identical** 중복이었다 — 내용 손실 없음. |

## 함께 정리한 것

- `cortex-project.yaml`: 이관된 루트 경로 2건을 정본 경로로 교체 + **dangling 항목 1건 제거**
  (`agents/AGENT_MEMBER.agent.yaml` — 2026-08-05 세션 중 `cortex_agent_write` 가 자동 등록했으나
  해당 파일은 이미 삭제된 상태였다). 실존 검증 완료.
- **인용처 전수 회수(P62-B)**: 루트 yaml 을 「정본」이라 지목하던 4개 문서를 교정 —
  `02_GN_DW_building/03_GOLD_SERVING.md` · `05_SV-Agent_ai/08_AGENT_spec.md` ·
  `05_SV-Agent_ai/99_next_prompt.md` · `05_SV-Agent_ai/01_SV-Agent 작업계획.md`.
  `20_issue/*` 와 `05_SV-Agent_ai/_archive/*` 의 언급은 **이력 기록이므로 원문 보존**한다.

## 🔴 배포 경로 주의

`cortex_agent_save` / `cortex_agent_deploy`(semantic_studio) 는 **live 버전**을 만든다.
이 프로젝트는 **명명 버전 방식**(`VERSION$n`)이고 `ADD VERSION FROM` 은 **live 가 존재하면 거부**된다.

정상 절차:
1. `agents/<AGENT>/agent_spec.yaml` 갱신
2. `ALTER WORKSPACE USER$.PUBLIC."snowflake_files" COMMIT` — stage 에 노출
3. `09_2_AGENT_버전업.sql` 실행 (`ADD VERSION FROM <디렉터리>`)
4. `ALTER AGENT … SET DEFAULT_VERSION = 'VERSION$n'`
   — 🔴 **발행만으로 default 가 되지 않는다**(P66). `SHOW VERSIONS IN AGENT` 로 `is_default` 실측 확인.

---
_Co-authored with CoCo_
