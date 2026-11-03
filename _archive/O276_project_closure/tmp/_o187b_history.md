
> #### 🟢 [2026-09-28 O187-B] `--vars` 판별 실험 판정 — 실행 경로에 따라 갈린다(종전 「동작 안 함」 일반화 기각)

- 사용자 실험 A(JSON)·B(YAML) = 두 컴파일 모두 창 `EVENT_DATE between '20240103' and '99991231'` ·
  20240103 = 2026-09-28 − 999일(실패면 20260925) ⇒ **`EXECUTE DBT PROJECT` ARGS 경로에서 `--vars` 는 전달된다**
- 종전 실패(2026-09-22 · 3형태) = **Workspaces dbt 클라이언트 경로**(공백 절단·인용부호 제거 · `dbt_project.yml:97~105`) ⇒ 경로 한정 사실
- 정정 4곳 = `02_dbt_parse_compile_build.sql` Step3 · `11_…/00_개요_및_실행순서.md:82` · `macros/bigquery_range_predicate.sql` 헤더 · `dbt_project.yml` vars 주석
- 🟠 잔여 = 리스트 var(`bigquery_dt_ranges`) 의 `--vars` 전달 미실측(백필 정본은 여전히 주석 슬롯 + 재배포)
- 문서20 판정줄 56 중 기록 20 · 미회신 36(**신규 회신 0**)
