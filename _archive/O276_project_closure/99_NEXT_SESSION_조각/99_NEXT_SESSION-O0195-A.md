<!-- LLM-METADATA
doc_id: HANDOFF_O0195_A
doc_role: 인수인계 — 세션 `O195-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-01
created_by: O195-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0195-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O195-A-0 🔴 먼저 알아라 (2026-10-01 · 개발계 pw69582)

- 🟢 ML 예측 3종(부서·후원사업·신규기존 개발예측)을 **라이브에서 DROP** 했고 정본도 ⛔ 주석화했다 — ML 은 이제 14종이다.
- 🟢 `gate_census` 미분류 0 — `o192_*` 3종을 MUTATES 로 등재했다(실행 금지 · 승인 대상).
- 🔴 O193-B · O195 의 **세션이력 항목이 없다** — 원장 행만 있다. `--rollover` 는 R4-4-3 승인 대상이라 남겼다.

### ▣ O195-A-1 🟠 남은 작업 (우선순)

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | NL 스모크 재측정(사용자 승인 완료) | `60_repeat_어카운트시작/10_NL스모크_재실행_절차.md` 전량 독해 → 트라이얼 차단 여부 1회 확인 → `nl_routing_smoke.py --apply` · 가드 = ML 3(O192-A ③) + O193 2(원천 테이블명 · 예측 부재 시 실적 되묻기) |
| 2 | 세션이력 롤오버 | O193-B 항목 = `tmp/_o193b_history.md` 재사용 + O193-C 항목 작성 → 승인 후 `split_doc.py 20_issue/01_세션이력.md --rollover` |
| 3 | 원장 미기록 | O191-G · O192-A · O192-B 원장 행·이력 |
| 4 | O192-A ④⑤ | 신규 발견 처리 · 산출물 03~09 재생성 + 골든(프롬프트 시 착수) |
| 5 | 결정 대기 | O192-A ▣3 D-1·D-2·D-4~D-7(D-3 은 DROP 으로 종결 후보 · 사용자 확인) · EXECUTIVE/MARKETING 원천 괄호 |
| 6 | 임시 계측기 | `_scratch_o191*` 6 · `_scratch_o194_devlog` 1 — `gate_census --final` 전 정리(소관 세션 확인) |

_Co-authored with CoCo_
