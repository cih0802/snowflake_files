### ▣ O196-D-0 🔴 먼저 알아라 (2026-10-01 · 개발계 pw69582)

- 🟢 DEC-59(사용자 결정 7건) 집행 · DEC-58 구현 = GOLD `DIM_SEND_REQUEST`(40컬럼) · `FACT_RELATION_ACTIVITY`(27컬럼) **라이브 CREATE 완료(빈 테이블)** + `FACT_MESSAGE_DISPATCH.SEND_REQUEST_SK` 추가.
- 🔴 **dbt build 전이다** — 새 2종은 0행 · FME STOP 귀속 규칙(DEC-59 #3·#4)은 라이브 미반영 · FMD `SEND_REQUEST_SK` 는 NULL.
- 🔴 D-4(ML 다중 예측행 최신 1행)는 **집행 불가** — 원천 5컬럼에 시각·순번 대체 후보 0 · 사용자 재결정 대기(DEC-59 #1).
- 🟢 Agent 3종 = 각주 「차원 원천 생략」 규칙 · MEMBER V5 · EXECUTIVE V6 · MARKETING V6 default.

### ▣ O196-D-1 🟠 남은 작업 — ㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | dbt build(사용자) | `ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';` → `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select DIM_SEND_REQUEST FACT_RELATION_ACTIVITY FACT_MEMBER_EVENT+';` (FME+ 에 FMD·WIDE·코호트 하류 포함) |
| 2 | build 후 판정 | FME STOP 배선률(기대 ≈99.7% · 팬아웃 0 · STOP 행수 불변) · `DIM_SEND_REQUEST` 1,722,090 · `FACT_RELATION_ACTIVITY` 398,630 · FMD `SEND_REQUEST_SK` 0 비율 · `table_ddl_column_gate` · `gold_erd_coverage_gate` |
| 3 | DEC-58 후속 | SV 노출 여부(SV_SERVICE 에 요청 차원 · 결연활동 SV 신설) 결정 → Agent |
| 4 | 산출물 골든 · 원장 002 재분할 | O196-B ▣1(사용자: 다음 프롬프트) · 원장 002 39.x KB |

### ▣ O196-D-2 🟠 남은 작업 — ㉡ 결정·외부 대기

| 순 | 작업 | 대기 대상 |
|---|---|---|
| 1 | D-4 ML 다중 예측행 | 사용자 재결정(ⓐ ML 담당 실행순번 요청 · ⓑ 현행 유지) |
| 2 | lineage ③ 잔여 6건(TM_MM_FDRM_MBER_SPNSR · TM_PM_DNTN_DTLS · TM_PM_MBRFEE_ACMSLT) | DEC-59 #7 = 수용(조치 없음) |
