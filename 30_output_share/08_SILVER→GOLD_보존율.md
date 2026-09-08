<!-- LLM-METADATA
doc_id: SILVER_GOLD_RETENTION
doc_role: SILVER→GOLD 컬럼 보존율 측정 (기계 측정 + 사람 판정군 승계)
project: GN_DW (굿네이버스)
measured: 2026-09-07
generator: scripts/gen_silver_gold_retention.py
generated: auto (do-not-edit)
principle: P27(도메인 부분적재는 자동검증을 통과한다) · P36(짝짓기를 이름 유사성으로 하지 않는다) · P78(의미는 이름이 아니라 grain 으로 판정)
END-METADATA -->

# SILVER → GOLD 컬럼 보존율

> ⚙️ **자동 생성물** — 생성기 `scripts/gen_silver_gold_retention.py`. 직접 편집 금지.
> **측정일** 2026-09-07 · 모집단 = SILVER 물리 DATA 컬럼(감사 `DW_*` 5종 제외)
> **한계(P13)**: 컬럼명 토큰 스캔이므로 **개명 전파는 미탐**이다 — `DROPPED` 는 부재 확정이 아니다.
> `판정군` 은 사람 판정이며 이전 판본에서 키 단위 승계했다. 기계 STATUS 가 뒤집힌 행은 마지막 열에 표시된다.

## 1. 요약

| 구분 | 건수 |
|---|---:|
| SILVER DATA 컬럼 총계 | **754** |
| GOLD 직접소비 테이블의 컬럼(=보존율 분모) | **434** |
| └ REFERENCED (보존) | **294** |
| └ DROPPED (탈락) | **140** |
| SILVER_ONLY_CHAIN (SILVER 내부만 소비) | 292 |
| NO_CONSUMER (소비처 0) | 28 |

**보존율 = 294/434 = 67.7%**

## 2. 이전 판본 대비 STATUS 변동

변동 0건 — 기계 측정 결과가 이전 판본과 일치한다.

## 3. 테이블별 보존율

| SILVER 테이블 | DATA 컬럼 | REFERENCED | DROPPED | 내부체인 | 소비처0 | 보존율 | 소비 GOLD 모델 |
|---|---:|---:|---:|---:|---:|---:|---|
| `AGENCY_AD_BROADCAST` | 22 | 22 | 0 | 0 | 0 | 100% | `FACT_AD_BROADCAST` |
| `AGENCY_AD_BROADCAST_CASE` | 6 | 6 | 0 | 0 | 0 | 100% | `FACT_AD_BROADCAST_CASE` |
| `AGENCY_AD_CREATIVE` | 7 | 6 | 1 | 0 | 0 | 86% | `DIM_AD_CREATIVE` |
| `AGENCY_AD_DIGITAL` | 16 | 16 | 0 | 0 | 0 | 100% | `FACT_AD_DIGITAL` |
| `AGENCY_AD_PERFORMANCE` | 21 | 11 | 10 | 0 | 0 | 52% | `FACT_AD_PERFORMANCE` |
| `AGENCY_AD_ROW_DGT` | 40 | 0 | 0 | 40 | 0 | — | — |
| `AGENCY_AD_ROW_REBRDC` | 38 | 0 | 0 | 38 | 0 | — | — |
| `AGENCY_AD_ROW_VIDEO` | 36 | 0 | 0 | 36 | 0 | — | — |
| `BIGQUERY_BASIC` | 46 | 0 | 0 | 46 | 0 | — | — |
| `BIGQUERY_DEVICE` | 6 | 1 | 5 | 0 | 0 | 17% | `DIM_DEVICE` |
| `BIGQUERY_EVENT` | 39 | 15 | 24 | 0 | 0 | 38% | `FACT_BIGQUERY_BEHAVIOR` |
| `BIGQUERY_EVENT_DIM` | 4 | 3 | 1 | 0 | 0 | 75% | `DIM_BIGQUERY_EVENT` |
| `BIGQUERY_IDENTITY` | 7 | 0 | 0 | 7 | 0 | — | — |
| `BIGQUERY_REFINED_DATA` | 118 | 0 | 0 | 118 | 0 | — | — |
| `BIGQUERY_TRAFFIC_SOURCE` | 10 | 6 | 4 | 0 | 0 | 60% | `DIM_BIGQUERY_SOURCE` |
| `CRM_BIZ_TARGET` | 10 | 6 | 4 | 0 | 0 | 60% | `FACT_TARGET_BIZ` |
| `CRM_CAMPAIGN` | 30 | 27 | 3 | 0 | 0 | 90% | `DIM_CAMPAIGN`, `DIM_MARKETING_CAMPAIGN`, `FACT_MEMBER_EVENT` |
| `CRM_CODE` | 6 | 3 | 3 | 0 | 0 | 50% | `DIM_MEMBER`, `DIM_REASON`, `DIM_SPONSORSHIP`, `FACT_DEV_ACHIEVEMENT`, `FACT_MEMBER_EVENT`, `FACT_MEMBER_FEE` |
| `CRM_DEV_TARGET` | 5 | 5 | 0 | 0 | 0 | 100% | `FACT_TARGET_DEV` |
| `CRM_EVENT` | 10 | 9 | 1 | 0 | 0 | 90% | `DIM_EVENT` |
| `CRM_EVENT_PARTICIPATION` | 15 | 15 | 0 | 0 | 0 | 100% | `FACT_EVENT_PARTICIPATION` |
| `CRM_MARKETING_CAMPAIGN` | 4 | 3 | 1 | 0 | 0 | 75% | `DIM_MARKETING_CAMPAIGN` |
| `CRM_MEMBER` | 27 | 10 | 17 | 0 | 0 | 37% | `DIM_MEMBER`, `DIM_MEMBER_IDENTITY`, `FACT_MEMBER_MONTHLY` |
| `CRM_MEMBER_AMT_CHANGE` | 14 | 5 | 9 | 0 | 0 | 36% | `FACT_MEMBER_MONTHLY` |
| `CRM_MEMBER_DEV` | 42 | 37 | 5 | 0 | 0 | 88% | `DIM_MEMBER`, `FACT_MEMBER_EVENT`, `FACT_MEMBER_SPONSOR_BIZ` |
| `CRM_MEMBER_DISCONTINUE` | 8 | 7 | 1 | 0 | 0 | 88% | `DIM_MEMBER`, `FACT_MEMBER_EVENT` |
| `CRM_MEMBER_RESPONSOR` | 4 | 0 | 0 | 0 | 4 | — | — |
| `CRM_MEMBER_SPONSOR_BIZ` | 7 | 0 | 0 | 7 | 0 | — | — |
| `CRM_MEMBER_SPONSOR_SPAN` | 9 | 7 | 2 | 0 | 0 | 78% | `FACT_MEMBER_MONTHLY`, `FACT_MEMBER_SPONSOR_BIZ` |
| `CRM_MEMBER_STATUS_HIST` | 9 | 7 | 2 | 0 | 0 | 78% | `DIM_MEMBER` |
| `CRM_ORG` | 8 | 5 | 3 | 0 | 0 | 62% | `DIM_ORG` |
| `CRM_PAYMENT_BILLING` | 23 | 13 | 10 | 0 | 0 | 57% | `FACT_MEMBER_FEE`, `FACT_MEMBER_MONTHLY` |
| `CRM_PAYMENT_METHOD` | 14 | 2 | 12 | 0 | 0 | 14% | `DIM_PAYMENT` |
| `CRM_RELATION_ACTIVITY` | 8 | 0 | 0 | 0 | 8 | — | — |
| `CRM_SEND_MEMBER` | 12 | 11 | 1 | 0 | 0 | 92% | `FACT_SERVICE_EVENT` |
| `CRM_SEND_REQUEST` | 15 | 10 | 5 | 0 | 0 | 67% | `DIM_SEND_TYPE`, `DIM_SERVICE`, `FACT_SERVICE_EVENT` |
| `CRM_SEND_RESULT` | 6 | 0 | 0 | 0 | 6 | — | — |
| `CRM_SPONSORSHIP` | 6 | 4 | 2 | 0 | 0 | 67% | `DIM_SPONSORSHIP` |
| `CRM_SPONSOR_RELATION` | 10 | 0 | 0 | 0 | 10 | — | — |
| `ERP_BUDGET` | 9 | 6 | 3 | 0 | 0 | 67% | `FACT_BUDGET` |
| `ERP_BUDGET_ITEM` | 11 | 5 | 6 | 0 | 0 | 45% | `DIM_BUDGET_ITEM` |
| `ERP_BUDGET_YEARLY` | 7 | 7 | 0 | 0 | 0 | 100% | `FACT_BUDGET_YEARLY` |
| `IDENTITY_MEMBER_XREF` | 9 | 4 | 5 | 0 | 0 | 44% | `DIM_MEMBER_IDENTITY`, `FACT_BIGQUERY_BEHAVIOR` |

## 4. 탈락(DROPPED) 전량 — 판정군별

### (미판정 — 신규 또는 승계 실패) — 140건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `AGENCY_AD_CREATIVE` | `AD_SEC_NM` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `AD_CNT` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `AD_MONTH` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `AD_YEAR` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `CONV_CALL_CNT` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `COST_TYPE` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `CREATIVE_NM` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `MEDIA_CHANNEL_NM` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `PROGRAM_NM` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `SOURCE_SYSTEM` | 0 | 0 | 0 |
| `AGENCY_AD_PERFORMANCE` | `UPPER_CAMPAIGN_NM` | 0 | 0 | 0 |
| `BIGQUERY_DEVICE` | `BROWSER` | 0 | 0 | 0 |
| `BIGQUERY_DEVICE` | `DEVICE_CATEGORY` | 0 | 0 | 0 |
| `BIGQUERY_DEVICE` | `LANGUAGE` | 0 | 0 | 0 |
| `BIGQUERY_DEVICE` | `OS` | 0 | 0 | 0 |
| `BIGQUERY_DEVICE` | `PLATFORM` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `BATCH_ORDERING_ID` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `DEFAULT_CHANNEL_GROUP` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `DEVICE_CATEGORY` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `EVENT_DATE` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `EVENT_SEQ` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `EVENT_TIMESTAMP` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `EVENT_TS` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `GA_SESSION_KEY` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `GA_SESSION_NUMBER` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `GEO_CITY` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `GEO_COUNTRY` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `ID_RESOLUTION` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `ID_SCHEME` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `LINK_TEXT` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `LINK_URL` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `OS` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `PAGE_REFERRER` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `PAGE_TITLE` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `PLATFORM` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `SRC_FILE_NAME` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `SRC_TABLE` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `USER_ID` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `USER_ID_FILLED` | 0 | 0 | 0 |
| `BIGQUERY_EVENT` | `UTM_CAMPAIGN` | 0 | 0 | 0 |
| `BIGQUERY_EVENT_DIM` | `EVENT_NAME` | 0 | 0 | 0 |
| `BIGQUERY_TRAFFIC_SOURCE` | `UTM_CAMPAIGN` | 0 | 0 | 0 |
| `BIGQUERY_TRAFFIC_SOURCE` | `XCHAN_CAMPAIGN` | 0 | 0 | 0 |
| `BIGQUERY_TRAFFIC_SOURCE` | `XCHAN_MEDIUM` | 0 | 0 | 0 |
| `BIGQUERY_TRAFFIC_SOURCE` | `XCHAN_SOURCE` | 0 | 0 | 0 |
| `CRM_BIZ_TARGET` | `BIZ_TARGET_DK` | 0 | 0 | 0 |
| `CRM_BIZ_TARGET` | `MONTH_NO` | 0 | 0 | 0 |
| `CRM_BIZ_TARGET` | `ORG_CD` | 0 | 0 | 0 |
| `CRM_BIZ_TARGET` | `TARGET_YEAR` | 0 | 0 | 0 |
| `CRM_CAMPAIGN` | `BRND_ID` | 0 | 0 | 0 |
| `CRM_CAMPAIGN` | `CMPGN_TRGET_CD` | 0 | 0 | 0 |
| `CRM_CAMPAIGN` | `UPPER_CMPGN_YN` | 0 | 0 | 0 |
| `CRM_CODE` | `SORT_ORDR` | 0 | 0 | 0 |
| `CRM_CODE` | `UPPER_CD_ID` | 0 | 0 | 0 |
| `CRM_CODE` | `USE_YN` | 0 | 0 | 0 |
| `CRM_EVENT` | `BRNCH_DEPT_ID` | 0 | 0 | 0 |
| `CRM_MARKETING_CAMPAIGN` | `RM` | 0 | 0 | 0 |
| `CRM_MEMBER` | `ACT_DEPT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `CPR_DIV_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `EMAIL_RECPTN` | 0 | 0 | 0 |
| `CRM_MEMBER` | `EMAIL_STAT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `ENTRPS_NM` | 0 | 0 | 0 |
| `CRM_MEMBER` | `ETC_CTTPC_REL_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `ETC_CTTPC_STAT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `ETC_TSTM_DIV_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `MBER_DIV_NM` | 0 | 0 | 0 |
| `CRM_MEMBER` | `MBER_STAT_NM` | 0 | 0 | 0 |
| `CRM_MEMBER` | `MOBLPHON_STAT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `PSTMTR_RECPTN` | 0 | 0 | 0 |
| `CRM_MEMBER` | `REGIST_DEPT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `RELATNSP_DIV_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `REL_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `SLRCLD_LRR_CD` | 0 | 0 | 0 |
| `CRM_MEMBER` | `TSTM_DIV_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `ACMSLT_DEPT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `AGE` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `AREA_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `AREA_NM` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `CMPGN_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `MBER_DIV_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `SER_NO` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `SEX` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `SPNSR_AMT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_DEV` | `ACT_DEPT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_DEV` | `CANCL_RDCAMT_RSN_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_DEV` | `SETLE_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_DEV` | `SPNSR_AMT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_DEV` | `SRC_LOAD_DT` | 0 | 0 | 0 |
| `CRM_MEMBER_DISCONTINUE` | `REGIST_DEPT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_SPONSOR_SPAN` | `SPNSR_DSCNTC_DE` | 0 | 0 | 0 |
| `CRM_MEMBER_SPONSOR_SPAN` | `SPNSR_DSCNTC_YN` | 0 | 0 | 0 |
| `CRM_MEMBER_STATUS_HIST` | `BF_STAT_NM` | 0 | 0 | 0 |
| `CRM_MEMBER_STATUS_HIST` | `CHN_STAT_NM` | 0 | 0 | 0 |
| `CRM_ORG` | `SORT_ORDR` | 0 | 0 | 0 |
| `CRM_ORG` | `STATS_DEPT_LVL` | 0 | 0 | 0 |
| `CRM_ORG` | `UPPER_DEPT_ID` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `CPR_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `GFT_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `MBER_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `MBRFEE_PRCS_STAT_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `OPERT_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `PAY_KEY` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `PRCS_RST_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `RELATNSP_KEY` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `RETUN_RSN_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_BILLING` | `RQEST_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `APPLCNT_MBER_REL_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `CARD_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `CPR_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `CRTFC_MTH_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `FNLT_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `FNLT_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `MBER_NO` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `RCEPT_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `RQST_DIV_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `SETLE_KEY` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `SETLE_STAT_CD` | 0 | 0 | 0 |
| `CRM_PAYMENT_METHOD` | `WTDRW_STRT_DE` | 0 | 0 | 0 |
| `CRM_SEND_MEMBER` | `SNDNG_DTL_KEY` | 0 | 0 | 0 |
| `CRM_SEND_REQUEST` | `MSG_DIV_CD` | 0 | 0 | 0 |
| `CRM_SEND_REQUEST` | `PSTMTR_PRCS_STAT_CD` | 0 | 0 | 0 |
| `CRM_SEND_REQUEST` | `REQ_SEQ_NO` | 0 | 0 | 0 |
| `CRM_SEND_REQUEST` | `SNDNG_STDR_DE` | 0 | 0 | 0 |
| `CRM_SEND_REQUEST` | `SNDNG_TIME_DIV_CD` | 0 | 0 | 0 |
| `CRM_SPONSORSHIP` | `CPR_DIV_CD` | 0 | 0 | 0 |
| `CRM_SPONSORSHIP` | `DNTN_TY_CD` | 0 | 0 | 0 |
| `ERP_BUDGET` | `ADJ_BUDGET_AMT` | 0 | 0 | 0 |
| `ERP_BUDGET` | `CHN_BUDGET_AMT` | 0 | 0 | 0 |
| `ERP_BUDGET` | `MONTH_NO` | 0 | 0 | 0 |
| `ERP_BUDGET_ITEM` | `BDGT_UNIT_NM` | 0 | 0 | 0 |
| `ERP_BUDGET_ITEM` | `BUDGET_YEAR` | 0 | 0 | 0 |
| `ERP_BUDGET_ITEM` | `FUND_SOURCE_NM` | 0 | 0 | 0 |
| `ERP_BUDGET_ITEM` | `HANG_NM` | 0 | 0 | 0 |
| `ERP_BUDGET_ITEM` | `JANG_NM` | 0 | 0 | 0 |
| `ERP_BUDGET_ITEM` | `KWAN_NM` | 0 | 0 | 0 |
| `IDENTITY_MEMBER_XREF` | `ID_RESOLUTION` | 0 | 0 | 0 |
| `IDENTITY_MEMBER_XREF` | `ID_SCHEME` | 0 | 0 | 0 |
| `IDENTITY_MEMBER_XREF` | `MATCH_CONFIDENCE` | 0 | 0 | 0 |
| `IDENTITY_MEMBER_XREF` | `MATCH_METHOD` | 0 | 0 | 0 |
| `IDENTITY_MEMBER_XREF` | `MEMBER_TYPE` | 0 | 0 | 0 |

## 5. 소비처 0 (NO_CONSUMER) 전량

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `CRM_MEMBER_RESPONSOR` | `MBER_NO` | 0 | 0 | 0 |
| `CRM_MEMBER_RESPONSOR` | `REGIST_DEPT_CD` | 0 | 0 | 0 |
| `CRM_MEMBER_RESPONSOR` | `RE_SPNSR_DE` | 0 | 0 | 0 |
| `CRM_MEMBER_RESPONSOR` | `SER_NO` | 0 | 0 | 0 |
| `CRM_RELATION_ACTIVITY` | `ACTIVITY_KEY` | 0 | 0 | 0 |
| `CRM_RELATION_ACTIVITY` | `ACTIVITY_TYPE` | 0 | 0 | 0 |
| `CRM_RELATION_ACTIVITY` | `GFTMNEY` | 0 | 0 | 0 |
| `CRM_RELATION_ACTIVITY` | `LETTER_DIV_CD` | 0 | 0 | 0 |
| `CRM_RELATION_ACTIVITY` | `MNG_NO` | 0 | 0 | 0 |
| `CRM_RELATION_ACTIVITY` | `RCEPT_DE` | 0 | 0 | 0 |
| `CRM_RELATION_ACTIVITY` | `RELATNSP_KEY` | 0 | 0 | 0 |
| `CRM_RELATION_ACTIVITY` | `SNDNG_DE` | 0 | 0 | 0 |
| `CRM_SEND_RESULT` | `FAILR_CNT` | 0 | 0 | 0 |
| `CRM_SEND_RESULT` | `SEND_CHANNEL` | 0 | 0 | 0 |
| `CRM_SEND_RESULT` | `SNDNG_CNT` | 0 | 0 | 0 |
| `CRM_SEND_RESULT` | `SNDNG_KEY` | 0 | 0 | 0 |
| `CRM_SEND_RESULT` | `SUCCES_CNT` | 0 | 0 | 0 |
| `CRM_SEND_RESULT` | `TOT_CLICK_CNT` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `CHILD_CD` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `MBER_NO` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_DSCNTC_DE` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_DSCNTC_RSN_CD` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_DSCNTC_YN` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_KEY` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_STRT_DE` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `SPNSR_BSNS_ID` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `SPNSR_BSNS_NO` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `SPNSR_NO` | 0 | 0 | 0 |

---
_Co-authored with CoCo_
