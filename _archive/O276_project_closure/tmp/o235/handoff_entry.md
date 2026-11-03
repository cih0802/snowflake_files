### ▣ O235-A-0 🔴 먼저 알아라

- 작성 = ua91864(문서 계정 · 코퍼스·검색 서비스 부재) · 반영 = jw08094(사용자 실행) · 2026-10-15 · ㉡ 적용(사용자 승인).
- 🔴 **Agent 배포 정본 = `cortex_project/agents/*/agent_spec.yaml`** → `05_SV-Agent_ai/09_2_AGENT_버전업.sql`([0-B] COPY FILES).
  루트 `*.agent.yaml` 은 `_archive/` 로 옮겼다 — 되살려 고치지 마라.
- 🔴 순서 = 26 DDL(`HAS_FORMULA` 생성) → 09_2. 역순이면 도구가 없는 컬럼을 참조한다.
- 확정위반 2 = R1-4-3 라벨 선점 지연 · R1-7-8 원장 행 앵커(복구 · 유실 0).

### ▣ O235-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 원인 | 검색 도구 컬럼 미지정(multi-index 서비스 호출 오류 2종) + 산식 없는 용어 행 상위 노출 · CSV 결함 아님 |
| ② 코퍼스 | RT-30 신설 · `HAS_FORMULA`(Y/N) · 산식 공란 본문 명시 · 2,156행 · 26 DDL 갱신 |
| ③ Agent 3종 | `columns_and_descriptions`(HAS_FORMULA 필터) + [O235 산식 질문] · EXEC $14 · MKT $17 · MEMBER $21(jw08094) |
| ④ 탐침 | 26문항 hit@1 85% · hit@3 92%(jw08094) |
| ⑤ 정리 | cortex_project 루트 17파일 `_archive` · `cortex-project.yaml` 정본 3 항목 |

### ▣ O235-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 Agent 스모크 = 「누계중단비중 산식이 어떻게 들어갔는지」 질문에 오류 2줄 소멸 · 첫 답 = 캠페인별 누계중단율 산식 확인 | Agent |

㉡ 워크스페이스 백로그 = O234-D-2 승계(eval · 탐침 miss · CoWork 스모크 · advisory) · 🔴 브리핑 FAIL 기존 2종(`agent_object_ref_gate` · `sv_identifier_gate`)은 이 단위 범위 밖(미조사).

### ▣ O235-A-4 ⚪ 결정 완료(재론 금지)

- 벡터 컬럼 신설 불요 — 서비스는 이미 VECTOR INDEXES SEARCH_TEXT(검색 결과 cosine 점수로 실증).
- 산식 없는 행은 검색에서 빼지 않는다(정의 질문 답 유지) — 필터·규칙으로만 거른다(사용자 B안).
- 「유사 산식」 제시 시 동일 지표 근거가 없으면 그 사실을 밝힌다(누계중단율1·2 ≠ 캠페인별 누계중단율 단정 금지).
