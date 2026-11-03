<!-- LLM-METADATA
doc_id: O262_CATEGORY_GAP_AUDIT
doc_role: BRONZE 카테고리성 컬럼 중 GOLD 미반영 점검(O262 · 사용자 지시 · 증거 산출물)
project: GN_DW (굿네이버스)
created: 2026-10-25
created_by: O262
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# O262 — BRONZE 카테고리성 컬럼 GOLD 미반영 점검

> 계정 = UM80684(개발계) · 2026-10-25 · TRIALADMIN / GN_DW_DBT.
> 입력 = `tmp/o262_audit/06_BRONZE노출감사.csv`(생성기 `scripts/run_bronze_audit_host.py` 재실행 · 공유본 30_output_share 는 덮지 않음).
> 분모 = 판정 「SILVER까지만」·「미노출(검토대상)」 611건 → BRONZE 라이브 실측(APPROX_COUNT_DISTINCT · 채움) 611/611 · 미측정 0.
> 카테고리 판정 = 금액·수·일자·ID·본문 이름 제외 후 고유값 ≤60 이고(고유 ≤20 또는 고유/채움 ≤5%) · 또는 고유 ≤200 이고 ≤1%.
> 결과 = **96건**(CATEGORY 90 · CATEGORY? 6). 🔴 APPROX 값이라 경계(60·200) 근처는 근사다.
> 대조 = ① GOLD 모델 SQL 토큰 참조 ② 이슈 문서(10·20·30·50·90 조각 · 31·32·40) 중 보류·결정 어휘가 있는 줄.

## A. GOLD 모델 SQL 이 원천 컬럼을 참조 + 이슈 기록 있음 — 개명 승격·조인키·보류 기재 중 하나(감사기 이름매칭 한계 · P13) — 21건

| 원천 | 테이블 | 컬럼 | 고유 | 채움/전체 | 감사 판정 | GOLD 참조 | 기록 좌표 |
|---|---|---|---|---|---|---|---|
| AGENCY | VIDEO_AD_CMPGN_DTLS | `AD_TY_NM` | 4 | 47673/47838 | SILVER까지만 | DIM_AD_CREATIVE.sql, FACT_AD_DIGITAL.sql | `20_issue/20_현업확인_요청_조각/20_현업확인_요청-008.md:74` · `20_issue/30_설계_의사결정_조각/30_설계_의사결정-002.md:173` |
| AGENCY | VIDEO_AD_CMPGN_DTLS | `DEVICE_NM` | 4 | 47673/47838 | SILVER까지만 | FACT_AD_PERFORMANCE.sql | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-002.md:79` |
| AGENCY | VIDEO_AD_CMPGN_DTLS | `UPPER_CMPGN_CD` | 42 | 6801/47838 | SILVER까지만 | DIM_CAMPAIGN.sql, FACT_AD_PERFORMANCE.sql | `20_issue/90_해소완료_로그_조각/90_해소완료_로그-016.md:297` |
| CRM | TD_MS_CRMN_PRTCPNT | `PARTCPT_STAT_CD` | 6 | 170883/170914 | SILVER까지만 | FACT_EVENT_ATTENDANCE.sql | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-008.md:119` · `20_issue/10_진단_원인분석_조각/10_진단_원인분석-008.md:133` |
| CRM | TD_MS_EMAIL_SNDNG_DTLS | `SNDNG_RST_CD` | 2 | 7863079/7863079 | SILVER까지만 | FACT_MESSAGE_DISPATCH.sql | `20_issue/20_현업확인_요청_조각/20_현업확인_요청-001.md:220` · `20_issue/30_설계_의사결정_조각/30_설계_의사결정-006.md:47` |
| CRM | TD_MS_EVENT_PRTCPNT_DTL | `PARTCPT_STAT_CD` | 13 | 1123661/1134870 | SILVER까지만 | FACT_EVENT_ATTENDANCE.sql | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-008.md:119` · `20_issue/10_진단_원인분석_조각/10_진단_원인분석-008.md:133` |
| CRM | TH_MM_FDRM_MBER_STNG_DTLS | `CHN_STAT_CD` | 12 | 7732788/7732788 | SILVER까지만 | DIM_MEMBER_STATUS_HISTORY.sql | `20_issue/30_설계_의사결정_조각/30_설계_의사결정-001.md:94` |
| CRM | TM_CM_MBER_DVLP_GOAL | `STDR_MT` | 12 | 25344/25344 | SILVER까지만 | FACT_TARGET_MEMBER_DEV.sql, WIDE_MBRFEE_PRDT_ACTL.sql | `20_issue/30_설계_의사결정_조각/30_설계_의사결정-017.md:98` |
| CRM | TM_CM_MBER_DVLP_GOAL_DIV | `BDGT_PRCD_NM` | 1 | 437/437 | SILVER까지만 | FACT_BUDGET_YEARLY.sql | `20_issue/30_설계_의사결정_조각/00_선택표.md:67` · `20_issue/30_설계_의사결정_조각/30_설계_의사결정-012.md:59` |
| CRM | TM_CM_SCHDUL_MNG | `SCHDUL_DIV_CD` | 2 | 4193/4193 | SILVER까지만 | DIM_DATE.sql | `20_issue/20_현업확인_요청_조각/20_현업확인_요청-002.md:112` |
| CRM | TM_CM_SPNSR_BSNS_INFO | `SPNSR_BSNS_ABRV_CD` | 6 | 50/50 | SILVER까지만 | DIM_SPONSORSHIP.sql | `20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-017.md:103` |
| CRM | TM_MM_ONCE_MBER_INFO | `REL_CD` | 12 | 9780/177921 | SILVER까지만 | DIM_MEMBER.sql | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-006.md:122` |
| CRM | TM_PM_DNTN_DTLS | `ACMSLT_DEPT_CD` | 32 | 1125317/1134403 | SILVER까지만 | FACT_MEMBER_EVENT.sql, FACT_MEMBER_SPONSORSHIP_SPAN.sql | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-014.md:146` |
| CRM | TM_PM_DNTN_DTLS | `PAY_STAT_CD` | 1 | 1134403/1134403 | SILVER까지만 | FACT_MEMBER_FEE.sql, FACT_MEMBER_MONTHLY.sql | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-001.md:171` · `20_issue/10_진단_원인분석_조각/10_진단_원인분석-019.md:91` |
| CRM | TM_PM_MBRFEE_ACMSLT | `MBRFEE_SQNC` | 52 | 49725908/50061988 | SILVER까지만 | FACT_MEMBER_MONTHLY.sql | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-019.md:91` · `20_issue/30_설계_의사결정_조각/00_선택표.md:35` |
| CRM | TM_PM_MBRFEE_ACMSLT | `PAY_STAT_CD` | 2 | 49090850/50061988 | SILVER까지만 | FACT_MEMBER_FEE.sql, FACT_MEMBER_MONTHLY.sql | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-001.md:171` · `20_issue/10_진단_원인분석_조각/10_진단_원인분석-019.md:91` |
| CRM | TM_PM_MBRFEE_ACMSLT | `PRCS_RST_CD` | 7 | 48904102/50061988 | SILVER까지만 | FACT_PAYMENT_BILLING_STATUS.sql | `20_issue/20_현업확인_요청_조각/20_현업확인_요청-010.md:259` · `20_issue/30_설계_의사결정_조각/30_설계_의사결정-001.md:96` |
| CRM | TM_PM_MBRFEE_ACMSLT | `RQEST_RST_CD` | 100 | 49082334/50061988 | SILVER까지만 | FACT_MEMBER_MONTHLY.sql, FACT_PAYMENT_BILLING_STATUS.sql | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-019.md:91` · `20_issue/20_현업확인_요청_조각/20_현업확인_요청-010.md:258` |
| ERP | BDGT_ACMSLT_LEDGER | `BDGT_PRCD_NM` | 2 | 405/405 | SILVER까지만 | FACT_BUDGET_YEARLY.sql | `20_issue/30_설계_의사결정_조각/00_선택표.md:67` · `20_issue/30_설계_의사결정_조각/30_설계_의사결정-012.md:59` |
| ERP | BDGT_ACMSLT_LEDGER | `DIRECT_MNYRS_YN_1` | 2 | 405/405 | SILVER까지만 | FACT_BUDGET.sql | `20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-018.md:40` · `20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-018.md:42` |
| ERP | BDGT_ACMSLT_LEDGER | `DIRECT_MNYRS_YN_2` | 2 | 405/405 | SILVER까지만 | FACT_BUDGET.sql | `20_issue/90_해소완료_로그_조각/90_해소완료_로그-016.md:293` |

## B. GOLD 모델 SQL 이 원천 컬럼을 참조 + 기록 없음 — 조인·필터·파생에만 쓰고 열로는 미노출 가능성 — 15건

| 원천 | 테이블 | 컬럼 | 고유 | 채움/전체 | 감사 판정 | GOLD 참조 | 기록 좌표 |
|---|---|---|---|---|---|---|---|
| CRM | SND_MEMBER_LIST | `SETLE_NM` | 6 | 468681/11997090 | SILVER까지만 | DIM_PAYMENT.sql | - |
| CRM | TD_MS_EVENT_PRTCPNT_DTL | `PARTCPT_CHNNL_CD` | 9 | 1134793/1134870 | SILVER까지만 | FACT_EVENT_ATTENDANCE.sql | - |
| CRM | TD_MS_EVENT_PRTCPNT_DTL | `PARTCPT_PATH_CD` | 7 | 1125413/1134870 | SILVER까지만 | FACT_EVENT_ATTENDANCE.sql | - |
| CRM | TD_MS_EVENT_PRTCPNT_DTL | `PRZWIN_CD` | 3 | 12989/1134870 | SILVER까지만 | FACT_EVENT_ATTENDANCE.sql | - |
| CRM | TM_CM_CMPGN_MNG | `CMPGN_TYPE1_BSN` | 4 | 35719/37345 | SILVER까지만 | DIM_CAMPAIGN.sql, FACT_MEMBER_EVENT.sql | - |
| CRM | TM_CM_CMPGN_MNG | `CMPGN_TYPE2_BSN` | 4 | 35719/37345 | SILVER까지만 | FACT_MEMBER_EVENT.sql, FACT_MEMBER_SPONSORSHIP_SPAN.sql | - |
| CRM | TM_CM_CMPGN_MNG | `MBER_INFLOW_PATH_CD` | 12 | 35719/37345 | SILVER까지만 | FACT_MEMBER_EVENT.sql, FACT_MEMBER_SPONSORSHIP_SPAN.sql | - |
| CRM | TM_CM_CMPGN_MNG | `PR_MTH_CD` | 95 | 35860/37345 | SILVER까지만 | DIM_CAMPAIGN.sql | - |
| CRM | TM_CM_CMPGN_MNG | `UPPER_CMPGN_YN` | 2 | 37345/37345 | SILVER까지만 | DIM_CAMPAIGN.sql | - |
| CRM | TM_CM_MBER_DVLP_GOAL | `MBER_DVLP_DIV_CD` | 3 | 25344/25344 | SILVER까지만 | FACT_TARGET_MEMBER_DEV.sql | - |
| CRM | TM_CM_MBER_DVLP_GOAL | `STDYY` | 15 | 25344/25344 | SILVER까지만 | FACT_TARGET_MEMBER_DEV.sql | - |
| CRM | TM_MM_FDRM_MBER_INFO | `SLRCLD_LRR_CD` | 4 | 1306864/1625974 | SILVER까지만 | DIM_MEMBER.sql | - |
| CRM | TM_MS_EVENT | `EVENT_DIV_CD` | 5 | 387/387 | SILVER까지만 | DIM_EVENT.sql | - |
| CRM | TM_PM_INSTT_ACNUT | `ACNUT_DIV_CD` | 2 | 239/239 | SILVER까지만 | DIM_PAYMENT_ACCOUNT.sql | - |
| ERP | BDGT_ACMSLT_LEDGER | `INCOME_EXPS_DIV_NM` | 1 | 405/405 | SILVER까지만 | DIM_BUDGET_ITEM.sql | - |

## C. GOLD 참조 없음 + 이슈 기록 있음 — 의도적 보류(현업 확인·코드군 미확정 등) — 13건

| 원천 | 테이블 | 컬럼 | 고유 | 채움/전체 | 감사 판정 | GOLD 참조 | 기록 좌표 |
|---|---|---|---|---|---|---|---|
| AGENCY | SYNC_ERR_INFO | `DATA_TYPE` | 2 | 16/16 | 미노출(검토대상) | - | `20_issue/30_설계_의사결정_조각/30_설계_의사결정-017.md:98` |
| CRM | SND_MEMBER_LIST | `SND_YN` | 2 | 11352213/11997090 | SILVER까지만 | - | `20_issue/30_설계_의사결정_조각/30_설계_의사결정-009.md:79` · `20_issue/31_코드군_매핑등재부.md:42` |
| CRM | SND_MEMBER_LIST | `SPNSR_TYPE` | 5 | 5277356/11997090 | 미노출(검토대상) | - | `20_issue/20_현업확인_요청_조각/20_현업확인_요청-010.md:260` |
| CRM | SND_MEMBER_MAIL_LINK_LOG | `AGENT` | 5 | 644/644 | SILVER까지만 | - | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-001.md:136` · `20_issue/10_진단_원인분석_조각/10_진단_원인분석-005.md:64` |
| CRM | TD_MS_MSG_AT_SNDNG_DTLS | `TRNSMS_STAT_CD` | 3 | 22467679/22764666 | SILVER까지만 | - | `20_issue/20_현업확인_요청_조각/20_현업확인_요청-005.md:183` |
| CRM | TM_CM_CMPGN_MNG | `CMPGN_TRGET_CD` | 10 | 35860/37345 | SILVER까지만 | - | `20_issue/20_현업확인_요청_조각/20_현업확인_요청-010.md:277` |
| CRM | TM_CM_DEPT_INFO | `STATS_DEPT_LVL` | 2 | 8/1314 | SILVER까지만 | - | `20_issue/20_현업확인_요청_조각/20_현업확인_요청-002.md:12` · `20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-017.md:109` |
| CRM | TM_MM_FDRM_MBER_SPNSR_DSCNTC | `REGIST_DEPT_CD` | 54 | 965527/1077841 | SILVER까지만 | - | `20_issue/30_설계_의사결정_조각/30_설계_의사결정-005.md:132` |
| CRM | TM_MM_ONCE_MBER_INFO | `REGIST_DEPT_CD` | 77 | 172997/177921 | SILVER까지만 | - | `20_issue/30_설계_의사결정_조각/30_설계_의사결정-005.md:132` |
| CRM | TM_MS_CRMN | `RM2` | 9 | 14/3686 | 미노출(검토대상) | - | `20_issue/10_진단_원인분석_조각/10_진단_원인분석-009.md:71` |
| CRM | TM_PM_MBRFEE_ACMSLT | `TRNSFER_RSN_CD` | 1 | 87750/50061988 | 미노출(검토대상) | - | `20_issue/30_설계_의사결정_조각/30_설계_의사결정-001.md:108` |
| CRM | TM_RM_RELATNSP_GFTMNEY_INFO | `EHGT` | 150 | 163468/185572 | SILVER까지만 | - | `20_issue/90_해소완료_로그_조각/90_해소완료_로그-002.md:11` |
| ERP | SYNC_ERR_INFO | `DATA_TYPE` | 2 | 16/16 | 미노출(검토대상) | - | `20_issue/30_설계_의사결정_조각/30_설계_의사결정-017.md:98` |

## D. GOLD 참조 없음 + 기록 없음 — 🔴 사유 미기재 누락 후보(승격 여부 결정 필요) — 47건

| 원천 | 테이블 | 컬럼 | 고유 | 채움/전체 | 감사 판정 | GOLD 참조 | 기록 좌표 |
|---|---|---|---|---|---|---|---|
| AGENCY | DGT_AD_CMPGN_DTLS | `CMPGN_TYPE1_BSN_NM` | 4 | 224242/224242 | SILVER까지만 | - | - |
| AGENCY | DGT_AD_CMPGN_DTLS | `CMPGN_TYPE2_BSN_NM` | 5 | 224242/224242 | SILVER까지만 | - | - |
| AGENCY | REBRDC_AD_CMPGN_DTLS | `CHNNL_NM` | 23 | 2190/2190 | SILVER까지만 | - | - |
| AGENCY | VIDEO_AD_CMPGN_DTLS | `CMPGN_TY_NM` | 6 | 14327/47838 | SILVER까지만 | - | - |
| CRM | SND_MEMBER_LIST | `BPLC_KOR_NM` | 187 | 727431/11997090 | 미노출(검토대상) | - | - |
| CRM | SND_MEMBER_LIST | `CHILD_DTL_CD` | 1 | 653771/11997090 | 미노출(검토대상) | - | - |
| CRM | SND_MEMBER_LIST | `CHILD_DTL_NM` | 11 | 726315/11997090 | 미노출(검토대상) | - | - |
| CRM | SND_MEMBER_LIST | `FRST_SPNSR` | 26 | 4808675/11997090 | 미노출(검토대상) | - | - |
| CRM | SND_MEMBER_LIST | `GENDER` | 18 | 5351009/11997090 | 미노출(검토대상) | - | - |
| CRM | SND_MEMBER_LIST | `NATION_NM` | 27 | 738107/11997090 | 미노출(검토대상) | - | - |
| CRM | SND_MEMBER_LIST | `NEW_CHILD_PROJECT_COUNTRY` | 24 | 4981/11997090 | SILVER까지만 | - | - |
| CRM | SND_MEMBER_LIST | `SND_HOUR` | 18 | 11997090/11997090 | 미노출(검토대상) | - | - |
| CRM | SND_MEMBER_LIST | `SND_MIN` | 60 | 11997090/11997090 | 미노출(검토대상) | - | - |
| CRM | SND_MEMBER_LIST | `SPNSR_CD` | 19 | 4808675/11997090 | 미노출(검토대상) | - | - |
| CRM | SND_MEMBER_LIST | `SPNSR_NM` | 57 | 5268903/11997090 | SILVER까지만 | - | - |
| CRM | SND_MEMBER_MAIL_LINK_LOG | `LINK_PAGE` | 25 | 644/644 | SILVER까지만 | - | - |
| CRM | SND_REQ_MST | `ALT_SMS_YN` | 2 | 1564/2329 | SILVER까지만 | - | - |
| CRM | SND_REQ_MST | `CALL_NUMBER` | 1 | 1644/2329 | 미노출(검토대상) | - | - |
| CRM | SND_REQ_MST | `DIVIDE` | 4 | 171/2329 | SILVER까지만 | - | - |
| CRM | SND_REQ_MST | `DIVIDE_UNIT` | 4 | 171/2329 | 미노출(검토대상) | - | - |
| CRM | SND_REQ_MST | `EXTRA` | 1 | 1399/2329 | 미노출(검토대상) | - | - |
| CRM | SND_REQ_MST | `PAPER_YEAR` | 6 | 540/2329 | 미노출(검토대상) | - | - |
| CRM | SND_REQ_MST | `PERIODIC` | 2 | 12/2329 | 미노출(검토대상) | - | - |
| CRM | SND_REQ_MST | `PERIODIC_WEEK` | 1 | 1/2329 | 미노출(검토대상) | - | - |
| CRM | SND_REQ_MST | `REG_NM` | 34 | 2152/2329 | 미노출(검토대상) | - | - |
| CRM | SND_REQ_MST | `SEND_MIN` | 60 | 2329/2329 | 미노출(검토대상) | - | - |
| CRM | TC_CMMN_DTL_CD | `CD_ATRB3` | 30 | 626/5916 | SILVER까지만 | - | - |
| CRM | TD_MS_CRMN_PRTCPNT | `RQST_PATH_CD` | 6 | 170686/170914 | SILVER까지만 | - | - |
| CRM | TD_MS_MSG_AT_LQY_SNDNG | `DIVS_DTL_KEY` | 45 | 1260208/1260208 | 미노출(검토대상) | - | - |
| CRM | TM_CM_MBER_DVLP_GOAL_DIV | `SPNSR_BSNS_DIV_NM` | 15 | 422/437 | SILVER까지만 | - | - |
| CRM | TM_CM_MBER_DVLP_GOAL_DIV | `TEAM_NM` | 10 | 290/437 | SILVER까지만 | - | - |
| CRM | TM_CM_SCHDUL_MNG | `SCHDUL_CD` | 34 | 3928/4193 | 미노출(검토대상) | - | - |
| CRM | TM_CM_SPNSR_BSNS_INFO | `DNTN_TY_CD` | 2 | 50/50 | SILVER까지만 | - | - |
| CRM | TM_MM_FDRM_MBER_INFO | `CTI_SYNCHRN_DIV_CD` | 2 | 1625973/1625974 | 미노출(검토대상) | - | - |
| CRM | TM_MM_FDRM_MBER_INFO | `EMAIL_RECPTN_CD` | 24 | 1625722/1625974 | SILVER까지만 | - | - |
| CRM | TM_MM_FDRM_MBER_INFO | `PSTMTR_RECPTN_CD` | 23 | 1625961/1625974 | SILVER까지만 | - | - |
| CRM | TM_MM_ONCE_MBER_INFO | `CTI_SYNCHRN_DIV_CD` | 2 | 177921/177921 | 미노출(검토대상) | - | - |
| CRM | TM_MM_ONCE_MBER_INFO | `EMAIL_RECPTN_YN` | 2 | 116664/177921 | SILVER까지만 | - | - |
| CRM | TM_MM_ONCE_MBER_INFO | `PSTMTR_RECPTN_YN` | 2 | 116664/177921 | SILVER까지만 | - | - |
| CRM | TM_MS_CRMN | `CRMN_DIV_CD` | 14 | 3686/3686 | SILVER까지만 | - | - |
| CRM | TM_MS_CRMN | `PROMO_CODE` | 11 | 13/3686 | 미노출(검토대상) | - | - |
| CRM | TM_MS_EMAIL_SNDNG | `EMAIL_RM` | 1 | 1/546420 | 미노출(검토대상) | - | - |
| CRM | TM_PM_MBRFEE_ACMSLT | `RQEST_SQNC` | 69 | 50061988/50061988 | SILVER까지만 | - | - |
| CRM | TM_PM_MBRFEE_ACMSLT | `TOGETH_WTDRW_YN` | 2 | 50061988/50061988 | SILVER까지만 | - | - |
| ERP | BDGT_ACMSLT_LEDGER | `BDGT_ITEM_NM` | 5 | 404/405 | SILVER까지만 | - | - |
| ERP | BDGT_ACMSLT_LEDGER | `VENDOR` | 7 | 404/405 | 미노출(검토대상) | - | - |
| ERP | EXPENSE_RESOLUTION | `BDGT_ITEM_NM` | 20 | 61785/111649 | SILVER까지만 | - | - |

_Co-authored with CoCo_
