
> #### 🟢 [2026-09-28 O187-C] 리스트 var `--vars` 전달 확인 → 백필 런북을 ARGS 1줄로 단순화

- 사용자 실험 = `--vars '{"bigquery_dt_ranges": [["2025-06-01", "2025-06-30"]]}'` → 창 `EVENT_DATE between '20250601' and '20250630'` 렌더(xf98254)
- 백필 정본 = `EXECUTE DBT PROJECT … ARGS` 1줄(파일 편집·재배포 불요) · 종전 주석 슬롯 ㉠~㉤ 는 대체 경로로 강등 ⇒ 재잠금 누락 위험 소멸
- 정정 4곳 = `02_dbt_parse_compile_build.sql` Step3 · macro 헤더 · `dbt_project.yml` vars 주석 · `11_…/00_개요_및_실행순서.md`
- 문서20 판정줄 56 · 기록 20 · 미회신 36(신규 회신 0)
