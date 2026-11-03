## O216-A 신규 계정 CK24285 점검 + 8차 Agent · 마감(2026-10-12 · CK24285 · ㉡ 적용 · 확정위반 1)

- 전반부(라이브) = 인수인계 `99_NEXT_SESSION-O0216-A.md` ▣ O216-A-1 이 정본이다(수치 재기재 안 함).
- 🔴 확정위반 1 = `R1-7-8` 계열 — 05_18 장문 행 분할 스크립트 후반 누락 → 라이브 `GET_DDL` 원문으로 복원 · 유실 0.
- 세션 말미 `/workspace` 마운트 분리 → 다음 세션(같은 날)에 아래를 집행했다.

### 마감 집행(마운트 복구 후)

- 라벨 파일 발행 = `handoff_write.py --label O216-A --entry-file tmp/o216a_handoff_entry.md` · 5,222 B · 도달 재검사 3/3.
  · 허브 `99_NEXT_SESSION.md` 는 이미 색인을 가리킴(grep rc=0) ⇒ `--republish` 불요.
- 원장 §1 O216 행 🟡 → 🟢(행 키 보존 · 내용 대체) · `index_row_gate` rc=0 · 허브 `--republish` PASS.
- 재구축 런북 `60_repeat_어카운트시작/12_GN_DW_재구축_실행순서.md` §2-1 신설(O216 반영분 6행).
  · BIGQUERY_SESSION COMMENT = GOLD `06_DDL.sql:1161~1202` · SILVER `08_SILVER_테이블DDL_20260714.sql:1547~1589` 에 이미 반영(실측).
  · SV O216 규칙 미반영 파일 0(`grep -L` rc=1) · Agent 스펙 O216 블록 = EXEC 1 · MEMBER 1 · MKT 2.
- 운영계 문서 `13_운영계_반영_20261005이후.md` §12 신설(P0~P4).
  · SV = `CREATE OR ALTER` · Agent = `ADD VERSION` + 롤백 `SET DEFAULT_VERSION` · 스테이지·테이블 = `IF NOT EXISTS`.
  · 실행 롤 판정 = GN_DW_ADMIN(CK24285 실측) — CORTEX_USER·USE AI FUNCTIONS = PUBLIC · EXECUTE TASK = GN_DW_DBT 상속 · SERVING·Agent owner.
  · 🟠 관측 = CK24285 eval 테이블 6종 owner = ACCOUNTADMIN(규약 불일치 · 기능 영향 없음 · 미시정).

### 독해 기록(`R1-3-7-b`)

- `00_guides/00_작업지침_세션운영규칙.md` 1~304 · 도착 · `R0-8-4` · `R4-4-4`.
- `tmp/o216a_handoff_entry.md` 1~45 · 도착 · `VERSION$4` · `0.9050`.
- `20_issue/00_BRIEF.md` 1~126 · 도착 · `O215-A` · `3,184,534`.
- `12_GN_DW_재구축_실행순서.md` 1~88 · 도착 · `JU93656` · `안 B`.
- `13_운영계_반영_20261005이후.md` 1~266 · 도착 · `SEND_STATUS2` · `S8`.
- `tmp/o216_*.py` 4종 전량 · 도착 · `o216_eval.py:21` · `o216_eval_ds.py:20`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_
