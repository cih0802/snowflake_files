### ▣ O201-D-0 🔴 먼저 알아라 (2026-10-03 · JU93656 · ㉡ 적용 · 확정위반 0)

- 근거철 = `20_issue/_o201_inspection_evidence.md` §E16.
- 🟢 MSTR 운영계 적재 = 2026-01~최신월만 · `06_MSTR_적재_실행.sql` [2] 루프 블록 · 개발계 실행 10개월 OK(≈ 29초/월).
  · 전제 = 수정된 `04_sp_script.sql` 배포(후원금액대2 조회를 원천 직접 조회로 변경 · 결과 동일 실측).
- 🟢 누계개발 확정 → 공45~47 = dbt 뷰 `WIDE_MEMBER_MONTHLY_KPI` + SV `05_14_SV_DDL_MEMBER_MONTHLY_KPI.sql` 작성(사전 검증 끝 · 배포는 dbt 후).
- 🟠 dbt 전까지 `test_verify_wide_doc` 은 FAIL 이 정상(dbt 모델 18 ↔ 라이브 17).

### ▣ O201-D-1 🟠 남은 작업

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 👤 dbt build | `dbt build --project-dir 10_dbt_pipeline --select WIDE_MEMBER_MONTHLY_KPI WIDE_SPNSR_CLS_AGGR` |
| 2 | KPI SV 배포 | build 후 `05_14` 실행 → `python3 scripts/build_wide_doc.py` 재생성 → `test_verify_wide_doc` 확인 → MEMBER Agent 에 `analyst_member_monthly_kpi` 도구 추가(09_2) |
| 3 | 현업 확인 | 요청서 41번 = MSTR 반영안 · 개발(건) 단위 · 공46 방향 · 공54 정의 |
| 4 | FN B3 동점 | `03_function_script.sql:180` `ORDER BY SPNSR_NO DESC` 에 동점 해소키 추가 여부(원 MSTR 결과와 대조 후) |
| 5 | 운영계 이관 | 00~04 배포 → 06 [0]~[3] 실행 → `mstr_verify --ym 202601` |
| 6 | FMM 미래월 행 | MONTH_KEY 202911 1행 원인 |
| 7 | ML 질문 개선 후보 · D6 게이트 · MSTR 월 Task | O201-C ▣1 승계 |

### ▣ O201-D-2 ⚪ 결정 완료(재론 금지)

- 누계개발(건) = 당해년도 1월 ~ 조회월의 개발(건) 합계(사용자).
- 운영계 MSTR 적재 범위 = 2026-01 ~ 최신월(사용자).
