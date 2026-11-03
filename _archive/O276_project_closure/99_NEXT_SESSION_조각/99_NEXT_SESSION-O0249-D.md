<!-- LLM-METADATA
doc_id: HANDOFF_O0249_D
doc_role: 인수인계 — 세션 `O249-D` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-20
created_by: O249-D
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0249-D -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.** (`O172` 규격 · 현행 판정식 = 라벨 최대값)
> 다음 세션은 **이 파일 1개만** 읽으면 된다. `O0249-C` 의 ㉠ 잔여는 전부 종결됐다.

### ▣ O249-D-1 이번 단위 결과(O249-C ㉠ 잔여 ①②③ + ㉡ 도구 안전성)

| 순 | 작업 | 결과 |
|---|---|---|
| ① | 👤 dbt build(PASS=11 · ERROR 0) 후 에이전트 확인 | 🟢 `DIM_SEND_REQUEST` `SEND_REQUEST_SK=0` 1행 · 전체 1,924,137행 · SK 중복 0 · `FACT_MESSAGE_DISPATCH` 고아 3,001 → **0**(3,001건 = SK 0 귀속) |
| ② | 👤 승인 → 80 패키지 옛 사본 `01_실행순서_배포SQL/dbt_build_fact_ad_performance_budget.sql` 삭제 | 🟢 삭제(원본·`01_…/10_dbt_pipeline/` 사본과 md5 동일 확인 후) · `build_handoff.py` 재생성 경로 아님 확인 |
| ③ | `build_handoff.py --apply` | 🟢 RC 0 · 파일 511 · MISSING 0 · 패키지 `DIM_SEND_REQUEST.sql` = 원본 md5 일치(센티넬 `select 0, 0`) |
| ㉡ | `scripts/n01_dmf_apply.py` 에 dry-run 기본 + `--apply` 게이트 | 🟢 dry-run = 136문장 목록만(접속 없음) · `test_mutating_tool_safety` 19건 **PASS** |

### ▣ O249-D-2 ㉡ 남은 백로그(후속 작업자·현업 결정 — 에이전트 단독 집행 불가)

- 후속 작업자 결정 = DMF 적용(N01 §6 · 이제 `n01_dmf_apply.py --apply`) · A3 [2] 롤 동기화 채택.
- 현업 = 미연결 캠페인 1,608건 · VIDEO 허용 인입경로 · SND 결과 라벨(문서20 기등재) · 공11·공147·W5·W6.
- 운영계 이관 = `문서실행순서.md` 「기존 환경 갱신」 20~25 + 체크리스트 ⑤(DMF 제외).

### ▣ O249-D-3 ⚪ 결정 완료(재론 금지)

- O249-A·B·C 결정 그대로. unknown 센티넬은 키 타입을 따른다(NUMBER = 0 · 문자 = '(미매핑)').

_Co-authored with CoCo_
