<!-- LLM-METADATA
doc_id: HANDOFF_O0235_B
doc_role: 인수인계 — 세션 `O235-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-15
created_by: O235-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0235-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O235-B-0 🔴 먼저 알아라

- O235-A 종료 절차 중 실측(ua91864 · 2026-10-15) · 이 단위는 기록만 한다(시정 없음).

### ▣ O235-B-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 종료 스크립트 | doc_census · gen_measure_backlog · decision_closure_gate rc=0 |
| ② 음성 테스트 | n=52 · 🔴 fail=3(아래 ②) · O234-D(jw08094) 52/52 와 계정·시점이 다르다 |

### ▣ O235-B-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | `test_generators` G.golden-match = `07_코드체계_관문측정.md` 측정일 골든 2026-10-07 ≠ 산출물 2026-10-15 · 갱신 주체 규명 후 `--update-golden --reason` | 문서 |
| ② | `test_gold_erd` 축7-a = CONFORM `FACT_MEMBER_COHORT.LAST_STOP_DATE_SK` LOGICAL_FK 대상 누락(O233-A·O234-D ② 계열) | GOLD |
| ③ | `test_verify_wide_doc` = View names mismatch(라이브 조회 · ua91864) ⇒ jw08094 에서 재측정 후 판정 | 라이브 |

㉡ 워크스페이스 백로그 = O235-A-2 ㉡ 승계.

### ▣ O235-B-4 ⚪ 결정 완료(재론 금지)

- 세 건 모두 O235 변경 파일(코퍼스·agent_spec·cortex_project·원장)과 무관 — 원인 미규명 상태로 골든을 덮지 않는다.

_Co-authored with CoCo_
