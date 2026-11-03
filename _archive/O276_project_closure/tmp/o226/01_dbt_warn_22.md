# O226 ① dbt WARN 22건 원문 (build query_id 01c7b968-0104-f2c0-0005-844a0019e082 · xh20001 · 2026-10-14)

출처 = `system$get_dbt_log(<qid>, 1000000)` 의 `[warn ]` 결과 줄(전 39,419줄 중 WARN 22 · PASS warn_* 12 제외).
🔴 O225-D 「WARN 5건」은 부분 select build(118노드) 기준이다 — 전체 build(656) 에서는 22건이 정상 분모다.

| # | 노드 | 건수 | 판정 | 근거 |
|---|---|---|---|---|
| 41 | warn_erp_budget_procedure_merge | 89 | 기존 ERP 예산 경고 | 원인 미조사 |
| 86 | relationships CRM_SEND_RESULT.SNDNG_KEY → CRM_SEND_REQUEST | 8 | 원천 고아 | 원인 미조사 |
| 116 | not_null CRM_PAYMENT_BILLING.MBER_NO | 5 | 원천 결손 | 원인 미조사 |
| 117 | not_null CRM_PAYMENT_BILLING.RQEST_RST_CD | 1156 | 원천 결손 | 원인 미조사 |
| 118 | relationships CRM_PAYMENT_BILLING.SPNSR_BSNS_ID → CRM_SPONSORSHIP | 1 | 원천 고아 | 원인 미조사 |
| 156 | warn_erp_budget_month_grain | 1080 | 기존 ERP 예산 경고 | 원인 미조사 |
| 162 | warn_erp_budget_yearly_grain | 90 | 기존 ERP 예산 경고 | 원인 미조사 |
| 208 | relationships CRM_CAMPAIGN.SPNSR_BSNS_ID → CRM_SPONSORSHIP | 18353 | 원천 고아 | 원인 미조사 |
| 232 | relationships CRM_MEMBER.CMPGN_CD → CRM_CAMPAIGN | 4 | 원천 고아 | 원인 미조사 |
| 233 | relationships CRM_PAYMENT_BILLING.MBER_NO → CRM_MEMBER | 309 | 원천 고아 | 원인 미조사 |
| 316 | relationships BIGQUERY_IDENTITY.MBER_NO → CRM_MEMBER | 71 | 원천 고아 | 원인 미조사 |
| 345 | not_null CRM_EVENT_PARTICIPATION.PARTCPT_CHNNL_NM | 2 | 원천 오입력 | 실측 아래 ㉠ |
| 346 | not_null CRM_EVENT_PARTICIPATION.PARTCPT_PATH_NM | 2 | 원천 오입력(㉠ 동일 2행) | 실측 아래 ㉠ |
| 347 | not_null CRM_EVENT_PARTICIPATION.PARTCPT_STAT_NM | 2 | 원천 오입력(㉠ 동일 2행) | 실측 아래 ㉠ |
| 361 | relationships CRM_MEMBER.DEV_CMPGN_CD → CRM_CAMPAIGN | 18 | 원천 고아 | 원인 미조사 |
| 394 | not_null CRM_SEND_MEMBER.SEND_RESULT_NAME | 1725977 | 🟠 코드 마스터 미등재 결과코드 | 실측 아래 ㉡ |
| 398 | relationships CRM_SEND_MEMBER.SNDNG_KEY → CRM_SEND_REQUEST | 3001 | 원천 고아(O225-C 신규 모델) | 원인 미조사 |
| 437 | accepted_values FACT_EVENT_ATTENDANCE.PART_STATUS | 1 | ㉠ 전파 | `VALUE_FIELD = ')'` · N_RECORDS 2 |
| 562 | relationships FACT_MEMBER_FEE.MEMBER_DK → DIM_MEMBER | 184 | 회원 차원 고아 | 원인 미조사 |
| 634 | relationships FACT_MEMBER_MONTHLY.MEMBER_DK → DIM_MEMBER | 181 | 회원 차원 고아 | 원인 미조사 |
| 639 | warn_fmm_reason_unmapped_f_rows | 1 | 기존 경고 | 원인 미조사 |
| 656 | warn_gold_view_comment_coverage | 1 | ✅ 시정(O226) | 실측 아래 ㉢ |

## 실측

- ㉠ `OPS.NOT_NULL_CRM_EVENT_PARTICIPATION_*` 3테이블 = 같은 2행
  (EVENT_153 · MBER_NO 1377663 / EVENT_118 · MBER_NO 0526424 · PARTCPT_DT 2024-02-14).
  `PARTCPT_CHNNL_CD = ')'` 원천값 ⇒ 이름 조인 실패. 원천 = BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL.
- ㉡ `SILVER.CRM_SEND_MEMBER` 43,919,141행 중 SEND_RESULT_NAME NULL 14,475,536
  = 코드도 NULL 12,749,559 + **코드는 있고 이름 없음 1,725,977**(테스트 건수와 일치).
  미등재 결과코드 13종 = 9 · 7320 · 3 · 7319 · 5 · 0 · 4 · 6 · 8 · 9034 · 7321 · 7205 · 9035 → 👤 현업 확인 후보.
- ㉢ GOLD.WIDE_MEMBER_MONTHLY_KPI = `_wide_schema.yml` 미등재(뷰 COMMENT None · 컬럼 12/12 무주석)
  ⇒ O226 에서 yml 블록 등재(`_wide_schema.yml` 말미) · 다음 build 후 경고 해소 확인.

_Co-authored with CoCo_
