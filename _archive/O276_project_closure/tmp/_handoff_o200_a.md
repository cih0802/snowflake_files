### ▣ O200-A-0 🔴 먼저 알아라 (2026-10-02 · pw69582 · ㉡ 적용 · 확정위반 0)

- 🟢 SILVER 회원실 집계 3종 적재 확인 = 96 · 924 · 495행 · grain 중복 0 · 키 NULL 0.
- 🟢 GOLD dbt 뷰 3종 파일 작성 완료 · 🔴 **dbt 미실행**(라이브 GOLD 에 아직 없다).
  · `WIDE_DVLP_GOAL_ACMSLT` = M01~M12 언피벗 · 목표/실적 열 분리(예상 576행).
  · `WIDE_MBRFEE_PRDT_ACTL` = 예측/실측 행 유지 + `IS_FORECAST` · 율 컬럼 [비가산] 표기.
  · `WIDE_SPNSR_CLS_AGGR` = VALUE1·VALUE2 잠정 COMMENT 「후원분류집계 예측값1/2」.
- 🟢 O199-A 임시 스크립트 3 삭제 완료.

### ▣ O200-A-1 🟠 남은 작업

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 🔴 dbt build(사용자) | `dbt build --select WIDE_DVLP_GOAL_ACMSLT WIDE_MBRFEE_PRDT_ACTL WIDE_SPNSR_CLS_AGGR assert_dept_aggr_grain_unique` |
| 2 | build 후 실측 | GOLD 뷰 3 실재 · 행수(576 · 924 · 495) · 컬럼 COMMENT 반영 |
| 3 | SV 배선 | `SERVING.SV_*` 신설 → Agent 도구 추가(EXEC/MEMBER 중 소관 결정) |
| 4 | 현업 확인 | VALUE1·VALUE2 집계 유형별 의미 → COMMENT 확정(문서20 등재 후보) |
| 5 | O199-A 승계 | ▣O199-A-1 1~5 · ▣O199-A-2 3~6(MSTR 재배포·07 C_CONSUMER·LOADER·현업 회신) 그대로 |

### ▣ O200-A-2 ⚪ 결정 완료(재론 금지)

- SILVER 3종 = GOLD(ML 아님) · dbt view(`gn_view_commented`) · VALUE1/2 잠정 문안.
