<!-- LLM-METADATA
doc_id: HANDOFF_O0275_D
doc_role: 인수인계 — 세션 `O275-D` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-11-01
created_by: O275-D
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0275-D -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## ▣ O275-D-0 현황

- O275-C 직후 사용자 결정(2026-11-01) 반영 단위 · 🔴 다음 세션은 O275-C ▣ C-2 표 대신 **아래 ㉠** 을 쓴다(C-2 ①②③ 은 이 단위가 닫았다).

## ▣ O275-D-1 결과

- ① 실행순서 4종 본문 경로 → 새 배치 치환 233건(`tmp/restructure/o275c_execorder_fix.py` · 스냅샷 `_archive/*.O275-C-pre-bodypath` 4건) · 잔존 = 고정 `10_dbt_pipeline` · 폴더 없는 파일명뿐.
- 진입점 README · `00_WORKSPACE_MAP.md` §5 안내문 갱신.
- ② `01_세션이력` O275-C 항목 rollover PASS.
- ③ 선택 게이트 실행(결과 = 이 세션 응답 · FAIL 은 보고만).

## ▣ O275-D-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 80·85 패키지 안 옛 경로 수정 — **재배치 대상 문서가 전부 재배치 완료된 뒤**(사용자 결정) · 대상 예 = `80_…/00_INDEX.csv` · `01_실행순서_배포SQL/` 사본 · `scripts/sv_no_rollup_gate.py`·`sv_common_block_gate.py` 의 80 분기 | 👤 조건 대기 |
| ② | 🔴 하지 마라 = `scripts/golden/*.json` 경로 치환 · tmp 삭제(후보 0 · 승인 전) | 금지 |

## ▣ O275-D-3 ㉡ 워크스페이스 백로그

- O275-A-3 표 그대로 승계.

_Co-authored with CoCo_
