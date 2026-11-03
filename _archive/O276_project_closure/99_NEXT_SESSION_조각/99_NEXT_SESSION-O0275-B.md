<!-- LLM-METADATA
doc_id: HANDOFF_O0275_B
doc_role: 인수인계 — 세션 `O275-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-11-01
created_by: O275-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0275-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## ▣ O275-B-0 현황

- O275-A 인수인계 작성 후 세션 종료 음성 테스트에서 4건 FAIL(경로) → 같은 세션에서 정정 · 재실행 **전건 PASS**.
- 🔴 다음 세션 착수 = **O275-A 의 ▣ O275-A-2 잔여표를 그대로 쓰되 ③ 은 아래로 대체**.

## ▣ O275-B-1 정정 내역

- 원인 ㉠ 4-C 치환 경계가 `/workspace/OLD` · `{ROOT}/OLD` · `W + '/OLD` · 셸 목록 끝 토큰을 놓쳤다 ㉡ 공백 제거된 파일명을 따옴표 단독으로 쓴 곳(`os.path.join(dir, '05_필드 인벤토리.md')`)을 놓쳤다.
- ㉢ 🔴 archive 오판 2건 = `08_SILVER_테이블DDL_20260714.sql`(게이트 입력) · `20260826_아키텍처_지도_요약본.html`(생성기 출력) → 원래 폴더로 되돌림 + `MOVE_MAP*.csv` 행 정정(action=move · reason 에 정정 표기). 남은 archive = 2건(ALTER · PAID 런북 · 바이트 동일).
- ㉣ 80 패키지 내부 옛 폴더명을 가리키던 후보 경로(`01_실행순서_배포SQL/05_SV-Agent_ai`)까지 치환된 2곳 복원(`sv_no_rollup_gate.py` · `sv_common_block_gate.py`) + `EXTRA` 를 재편 후 / 80 구조로 분기.
- 정정 = `scripts/` 42줄 + 13줄 · 스냅샷 `_archive/RESTRUCTURE_20261031-pre/4C/residual/` · 도구 `tmp/restructure/residual_scan.py` · `residual_fix.py` · `residual_fix2.py` · 잔존 목록 `tmp/restructure/RESIDUAL_PATHS.csv`.

## ▣ O275-B-2 ㉠ 이 작업의 잔여 (O275-A-2 ③ 대체)

| 순 | 작업 | 판정 |
|---|---|---|
| ③ | 잔존 재스캔 = `python3 tmp/restructure/residual_scan.py tmp/restructure/RESIDUAL_PATHS.csv` → 남은 건은 docstring·주석 표기인지 확인 · 선택 게이트(`sh scripts/optional_gates.sh`) 실행 | 다음 세션 |

_Co-authored with CoCo_
