### ▣ O266-E-0 🔴 먼저 알아라

- `O266-E` = O266 세션 종료 점검 결과(2026-10-28). 착수할 일은 **O266-D-1 착수표**(회신문 2통 · 요청 목록 등재 · 템플릿 정보 질문 확인)가 정본이다 — 이 단위는 백로그만 더한다.
- 종료 절차 = doc_census stale 0 · 92 재생성 0항목 · 원장 §1 O266 행 등재 · 이력 롤오버 · index_row PASS · 브리핑 BRIEF_RC=0(`sv_enum_newvalue_gate` 4조각 전부 ✅ · 종전 ⚪ 미판정 해소).

### ▣ O266-E-1 음성 테스트 전건 결과

| 테스트 | rc | 판정 | 처리 |
|---|---|---|---|
| `test_sv_rule7_scan.py` | 1 → **0** | O265-A 규칙 (라) 「30명 미만이면」 = 정의 임계값(실측 아님) | 🟢 `sv_unit_gate.NUM_EXEMPT` 에 「N명 미만이면」 면제 추가(조건 접속 한정 · 두 게이트 공유) |
| `test_verify_wide_doc.py` | 1 | `WIDE_AD_COMBINED` 라이브 75열 ↔ `03_top-down_gold/09_빅테이블 VIEW.md` 69열 — 6열 누락(O266 `LAST_STMT_AMT` 1 + O262·O262-B 이후 누락 5) | 🟠 ㉡ 백로그 ① |
| `test_mutating_tool_safety.py` | 1 | 기지 실패(O264-A 기록) — MUTATES `run_sql_file`(O261 신설) 무플래그 | 🟠 ㉡ 백로그 ② |
| `test_pipeline_erd.py` | 1 | 기지 실패(O264-A 기록) — HTML 수 38 하드코딩 ↔ 실측 64 | 🟠 ㉡ 백로그 ② |
| `test_rename_stale_gate.py` | 143 | 미판정(120초 timeout) | 🟠 ㉡ 백로그 ③ |

### ▣ O266-E-2 ㉡ 워크스페이스 백로그

| 순 | 작업 | 판정 |
|---|---|---|
| ① | `09_빅테이블 VIEW.md` §2.13 `WIDE_AD_COMBINED` 에 누락 6열 행 추가 → `verify_wide_doc.py` rc=0 | 미착수 |
| ② | 기지 실패 2종 결정 — `run_sql_file` 을 기지 목록에 등재할지 플래그를 둘지 · ERD 단정을 모델 수 기준으로 바꿀지 | 사용자 결정 |
| ③ | `test_rename_stale_gate.py` 를 timeout 600 으로 재실행해 판정 확보 | 미착수 |
