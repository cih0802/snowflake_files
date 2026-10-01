<!-- LLM-METADATA
doc_id: HANDOFF_O0196_A
doc_role: 인수인계 — 세션 `O196-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-01
created_by: O196-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0196-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O196-A-0 🔴 먼저 알아라 (2026-10-01 · 개발계 pw69582)

- 🟢 NL 스모크 재측정 완료 — 39/39 PASS(중간 오류 1 · 새 계정 기준선 = 1) · 가드 5/5 · 트라이얼 차단 없음. 기록 = `60_repeat_어카운트시작/10_NL스모크_재실행_절차.md` §4-2.
- 🔴 O193-B · O195 · O196 의 **세션이력 항목이 없다** — 원장 행만 있다. `--rollover` 는 R4-4-3 승인 대상이다.
- 🟠 `scripts/_scratch_o196_guard_smoke.py`(이 세션 소관)가 남아 있다 — 삭제는 승인 후(R4-4-3).

### ▣ O196-A-1 🟠 남은 작업 (우선순)

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 세션이력 롤오버 | O193-B(`tmp/_o193b_history.md` 재사용) · O195 · O196 항목 작성 → 승인 후 `split_doc.py 20_issue/01_세션이력.md --rollover` |
| 2 | 원장 미기록 | O191-G · O192-A · O192-B 원장 행·이력(각 라벨 파일 근거) |
| 3 | O192-A ④⑤ | 신규 발견 처리 · 산출물 03~09 재생성 + 골든(프롬프트 시 착수) |
| 4 | 결정 대기 | O192-A ▣3 D-1·D-2·D-4~D-7 · D-3 은 O195 DROP 으로 종결 후보(사용자 확인) · EXECUTIVE/MARKETING 원천 괄호 |
| 5 | 스모크 개선(선택) | `AGENT_MEMBER_16` = SV metric `MODEL_CHURN_MEMBERS` 를 `mr.` 컬럼으로 참조(`22_ML_SV_DDL.sql:81`) · SV AI_SQL_GENERATION 에 metric 사용법 1줄 |
| 6 | 임시 계측기 | `_scratch_o191*` 6 · `_scratch_o194_devlog` 1 · `_scratch_o196_guard_smoke` 1 — `gate_census --final` 전 정리 |

_Co-authored with CoCo_
