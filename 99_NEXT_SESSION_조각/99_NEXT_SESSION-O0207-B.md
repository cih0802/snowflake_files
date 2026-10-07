<!-- LLM-METADATA
doc_id: HANDOFF_O0207_B
doc_role: 인수인계 — 세션 `O207-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-07
created_by: O207-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0207-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O207-B 인수인계 (O207-C 사용자 지시 처리 · 자기검토 마감)

### ▣ O207-B-0 🔴 먼저 알아라 (2026-10-07 · ㉡ 적용 · 확정위반 누계 1 = O207 R1-7-2)

- 🟢 이 파일이 O207 계열 최신이다 — O207-A 의 잔여는 여기로 옮겼다(O207-A 는 형제 · 읽되 잔여 판단은 이 파일).
- 🟢 라이브 = AGENT_MEMBER VERSION$10 · AGENT_MARKETING·AGENT_EXECUTIVE VERSION$9 · **AGENT_MSTR 없음(DROP)** · SV_MSTR_SPNSR_DVLP(md·gl·ye·yb).
- 🔴 MSTR 도구는 3개 Agent 의 `analyst_mstr_spnsr_dvlp` 다 — AGENT_MSTR 를 다시 만들거나 09_2 [3-D] 를 실행하지 마라.
- 🔴 미정의 지표(추경 회비예측 · 회비 시나리오)는 계산 전 「계산할까요?」로 묻는다 · 유지율·증액율은 `03_지표사전 신규.md` #34·#36 산식이 있다.
- 정본 = `12_agent개선과제/00_작업계획.md` §10-8(지시 처리 · 자기검토 S1~S11).

### ▣ O207-B-1 🟠 남은 작업

㉠ 이 작업의 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | 👤 운영계 MSTR 일일 적재 Task 생성 | `15_MSTR 이관 PoC/snowflake 적용 ddl/07_MSTR_일일적재_TASK.sql` [0] dbt Task FQN 확인 → [1] → [3] RESUME · 개발계엔 dbt Task 없음 |
| 2 | W6 GOLD 개발 지표 은퇴 판단 | 1 가동 후 · 그 전 제거 금지 |
| 3 | 음성 테스트 3종 작성(S9) | `live_change_gate` Agent 버전·SV DDL 이력 축 · `session_brief` 최대 접미 단위 · `agent_answer_judge` 변이 실증 |
| 4 | 유지율·증액율 사전 산식 그대로의 지표화 | N개월 시점 유지 판정 컬럼(수신일 기준 중단일 비교) 필요 · dbt 변경 · 증액율 분모 = 발송 **성공** 회원 |
| 5 | 스모크 판정식 보강(S11) | 「계산할까요」 외 「진행할까요」 등 확인 문형 |

㉡ 워크스페이스 백로그

| # | 할 일 | 비고 |
|---|---|---|
| 6 | `live_change_gate` 경보 23건 | O206 SV 28종 일괄 배포가 원장 행에 객체명 없이 기록됨 · 처리안 = O206 행 객체명 보강 또는 수용 결정 · 🔴 게이트를 느슨하게 고치지 마라 |
| 7 | 👤 기획실 3 · 나눔마케팅 21 판정 회신 · 현 버전 재확인 | 회신 오면 `scripts/agent_answer_judge.py` |
| 8 | 06 재생성 시 `SESSION_LABEL` 지정 · 기존 `06_BRONZE노출감사.csv.UNLABELED-regen` 사본 처리 결정 | 경고 출처는 미규명(S10) |

### ▣ O207-B-2 ⚪ 결정 완료(재론 금지)

- MSTR 일일 적재 = 확정 · 방식 = dbt 일 배치 Task 의 `AFTER`(불가하면 07:30 KST 고정) · 전월 + 당월 · I_HIST = FALSE.
- AGENT_MSTR 은퇴(3개 Agent 가 MSTR 도구로 대체).
- 연도말 개발 예측 = 추세 참고치(별도 예측 테이블 없음 · ML 은 금액만).
- 지표사전에 산식이 없는 지표 = 「정해진 지표 없음」 → 계산 여부를 묻고 고정값 아님을 경고.

_Co-authored with CoCo_
