<!-- LLM-METADATA
doc_id: HANDOFF_O0256_A
doc_role: 인수인계 — 세션 `O256-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-21
created_by: O256-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0256-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
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
| ~~①~~ | ~~80 헤더 통일 재빌드~~ ➔ 🟢 [O256-A] 종결 — 실행 코드 무변경이라 dbt build·재배포 불요 | 종결 |
| ② | (승계 O255-D ①) 안내문 v3 + 검토 xlsx 현업 전달 · §8(분모)·§9(A/B/C) 회신 | 👤 사용자 |
| ③ | (승계 O255-D ②) 회신 B·C = 해당 SV 의 DEC-63-E/D 표지 줄 제거 후 재실행 · DEC-63-D/E 갱신 | 회신 후 |
| ④ | (승계 O255-D ③) 운영계 = 문서실행순서 29 → 30(dbt) → 31 → 32 | 👤 운영계 |
| ~~⑤~~ | ~~05_10 SV COMMENT 규칙7 위반 2건 판정~~ ➔ 🟢 [O256-B] 문구 수정 · 개발계 재배포(`99_NEXT_SESSION-O0256-B.md`) | 종결 |

- 🔴 앞으로 80 사본을 **손으로 고치지 마라** — 원본을 고치고 `build_handoff.py --apply` 로 다시 만든다(훅이 정제를 매번 다시 한다).
- 🔴 `build_handoff.py` 는 `95_작업기록_인수인계정제/tools/`(clean80 · clean80b · scrub254 · scrub_acct)를 import 한다 — 그 폴더를 옮기거나 지우지 마라.
- 새 SQL 원본에 헤더를 붙이려면 `o256_header.py <측정 csv> --apply`(측정 csv = `o256_measure.py` 산출 · 헤더가 있는 파일은 건너뛴다).

### ▣ O256-A-3 ㉡ 워크스페이스 백로그

- O255-D-2 ①~③(안내문 v3 + 검토 xlsx 현업 전달 · 회신 반영 · 운영계 29→30→31→32) 그대로 승계.
- O255-B-2 ②·③ 그대로 승계 · ① = 이 단위에서 종결.
- 🆕 🟠 `scripts/test_sv_rule7_scan.py` rc=1 = `05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql` COMMENT(라이브 도달) 규칙7 위반 2건 — **O256 이전 백업본에서도 동일 2건**(O255 05_10 변경분 · 이번 작업 무관 · 주석 제외 코드 = 백업과 동일) ⇒ 토큰이 실측치면 COMMENT 에서 제거 후 SV 재배포 · 정의·관례면 `sv_unit_gate.NUM_EXEMPT` 예외 추가(사람 판단 · 상세 = `python3 scripts/sv_rule7_scan.py`).

_Co-authored with CoCo_
