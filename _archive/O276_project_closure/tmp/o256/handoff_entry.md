### ▣ O256-A-0 🔴 먼저 알아라

- `O256-A` = 80 헤더 통일 재빌드(O254-B-2 순서 그대로 · O255-B 승인) (2026-10-21 · TRIALADMIN(SR61467) · ㉡ · 사용자 지시·승인 · 확정위반 0).
- 🔴 사용자 결정 = 이번 세션은 **dbt `parse`·`compile` 을 에이전트가 실행**(승인) · `build`·`run` 은 사용자 확인 유지(R4-1).
- 직전 단위 = `99_NEXT_SESSION-O0255-D.md`(현업 회신·운영계 잔여는 그대로 유효).

### ▣ O256-A-1 결과

| 항목 | 결과 |
|---|---|
| 사전 실측 | 80 대상 530 = same 187 · repro 307(2층 처방 재현) · new 15 · diff 21(전부 원본이 최신) ⇒ 80 전용 정제 유실 0 |
| 원본 헤더 | SQL 285(`mstr DDL 원본/` 제외)에 표준 헤더(Purpose · Target · Run order · Depends on · Issue) 덧붙임 · 기존 주석 보존 |
| 원본 정제 | clean80 규칙(서명 · 이모지 → WARN:/NOTE: · 「개발계」→「개발 환경」) · 🔴 계정 값은 원본에 남김(개발 실측 근거) |
| 불변식 | 주석 제거 후 코드 동일 assert 285/285 · 백업 = `95_작업기록_인수인계정제/_backup_O256_원본_20261021/` · 재실행 285 skip(멱등) |
| dbt | 현재본 vs 기준선(백업 복원) parse·compile rc=0 · 노드 729 동일 · 의존성·config 불일치 0 · compiled 728 불일치 0(invocation_id 정규화) |
| 빌드 훅 | `build_handoff.py` `hook()` = .sql clean80(+헤더 정렬 복원) · .yml 주석 · 텍스트 scrub254 + init_ihcho 일반 치환 |
| 80 재빌드 | 530 · MISSING 0 · 80 == hook(원본) 530/530 · SQL 헤더 298/298 · `_archive` 밖 계정 0 · init_ihcho 0 · README 문구 1줄 |

### ▣ O256-A-2 ㉠ 잔여(이 작업)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 없음 — 실행 코드 무변경이라 dbt build·재배포 불요 | 종결 |

- 🔴 앞으로 80 사본을 **손으로 고치지 마라** — 원본을 고치고 `build_handoff.py --apply` 로 다시 만든다(훅이 정제를 매번 다시 한다).
- 🔴 `build_handoff.py` 는 `95_작업기록_인수인계정제/tools/`(clean80 · clean80b · scrub254 · scrub_acct)를 import 한다 — 그 폴더를 옮기거나 지우지 마라.
- 새 SQL 원본에 헤더를 붙이려면 `o256_header.py <측정 csv> --apply`(측정 csv = `o256_measure.py` 산출 · 헤더가 있는 파일은 건너뛴다).

### ▣ O256-A-3 ㉡ 워크스페이스 백로그

- O255-D-2 ①~③(안내문 v3 + 검토 xlsx 현업 전달 · 회신 반영 · 운영계 29→30→31→32) 그대로 승계.
- O255-B-2 ②·③ 그대로 승계 · ① = 이 단위에서 종결.
