import io
def sub(p, a, b):
    t = io.open(p, encoding='utf-8').read(); assert t.count(a) == 1, (p, a[:50])
    io.open(p, 'w', encoding='utf-8', newline='').write(t.replace(a, b)); print('ok', p)
R = '10_dbt_pipeline/02_dbt_parse_compile_build.sql'
sub(R, "--    복구 경로는 **ⓐ 수동 백필 하나뿐**이다(롤링 윈도우는 창 밖을 건드리지 않고,\n",
"--    🟢🟢 [2026-09-28 O187-C] **백필 정본 = ARGS 1줄**(재배포·주석 편집 불요 · 리스트 var 전달 실측 xf98254):\n"
"--      ① EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile --select BIGQUERY_BASIC --vars ''{\"bigquery_dt_ranges\": [[\"YYYY-MM-DD\", \"YYYY-MM-DD\"]]}''';\n"
"--         → 컴파일 SQL 의 `EVENT_DATE between '…' and '…'` 가 지정 구간인지 **먼저 확인**한다(판정식 = 렌더된 창)\n"
"--      ② 같은 ARGS 에서 compile → build 로, --select 를 BIGQUERY_BASIC+ 로 바꿔 실행 · ③ [3-3-a]·[3-3-b] 대사\n"
"--      🔴 **EXECUTE DBT PROJECT 경로 + JSON 표기만** — Workspaces dbt 클라이언트에서는 여전히 전달되지 않는다.\n"
"--      🟢 파일을 건드리지 않으므로 종전 ㉣(재잠금 누락 → 매일 전 기간 재적재) 위험이 **구조적으로 사라진다**.\n"
"--    ⬇ 아래 ㉠~㉤ 는 **대체 경로**(ARGS 전달이 안 되는 실행 환경용)로 강등한다.\n"
"--    복구 경로는 **ⓐ 수동 백필 하나뿐**이다(롤링 윈도우는 창 밖을 건드리지 않고,\n")
sub(R, "--       🟠 단 `bigquery_dt_ranges`(리스트) 전달은 **미실측** — 백필에 쓰기 전 `compile` 로 렌더된 창을 확인하라.\n--          확인 전까지 백필 정본 경로는 위 ㉠~㉤(주석 슬롯 + 재배포)이다.\n",
"--       🟢 [O187-C] 리스트 var(`bigquery_dt_ranges`)도 전달 확인 — 창 `between '20250601' and '20250630'` 렌더 ⇒ 위 ARGS 1줄이 정본.\n")
M = '10_dbt_pipeline/macros/bigquery_range_predicate.sql'
sub(M, "             🟠 `bigquery_dt_ranges`(리스트) 를 `--vars` 로 주는 것은 **아직 실측하지 않았다** — 쓰기 전에 `compile` 로\n                렌더된 창을 먼저 확인하라(판정식은 아래 그대로다). 확인 전까지는 주석 슬롯 경로가 정본이다.\n",
"             🟢 [O187-C] 리스트 var 도 전달된다 — `--vars '{\"bigquery_dt_ranges\": [[\"2025-06-01\", \"2025-06-30\"]]}'` 가\n"
"                `EVENT_DATE between '20250601' and '20250630'` 로 렌더됐다 ⇒ **백필 정본 = EXECUTE DBT PROJECT ARGS**(런북 02 Step 3).\n"
"                🔴 그래도 `compile` 로 렌더된 창을 먼저 확인하라(판정식은 아래 그대로다) · 주석 슬롯은 대체 경로다.\n")
Y = '10_dbt_pipeline/dbt_project.yml'
sub(Y, "(창 하한 20240103 = 실행일 − 999일 · xf98254). 리스트 var 는 미실측.\n",
"(창 하한 20240103 = 실행일 − 999일 · xf98254). 🟢 [O187-C] 리스트 var `bigquery_dt_ranges` 도 전달됨\n  #      ⇒ 백필은 이 파일을 고치지 않고 ARGS 1줄로 한다(정본 = `02_dbt_parse_compile_build.sql` Step 3).\n")
D = '11_일적재pipeline 구성/00_개요_및_실행순서.md'
sub(D, ">   ⚠️ 리스트 var(`bigquery_dt_ranges`) 전달은 미실측 · 정본 = `10_dbt_pipeline/02_dbt_parse_compile_build.sql` Step 3\n",
">   🟢 [O187-C] 리스트 var(`bigquery_dt_ranges`)도 전달 확인 ⇒ 백필 = ARGS 1줄 · 정본 = `10_dbt_pipeline/02_dbt_parse_compile_build.sql` Step 3\n")
