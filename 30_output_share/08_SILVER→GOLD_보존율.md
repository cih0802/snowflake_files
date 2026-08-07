<!-- LLM-METADATA
doc_id: SILVER_GOLD_RETENTION
doc_role: SILVER→GOLD 컬럼 보존율 측정 (기계 측정 + 사람 판정군 승계)
project: GN_DW (굿네이버스)
measured: 2026-08-07
generator: scripts/gen_silver_gold_retention.py
generated: auto (do-not-edit)
principle: P27(도메인 부분적재는 자동검증을 통과한다) · P36(짝짓기를 이름 유사성으로 하지 않는다) · P78(의미는 이름이 아니라 grain 으로 판정)
END-METADATA -->

# SILVER → GOLD 컬럼 보존율

> ⚙️ **자동 생성물** — 생성기 `scripts/gen_silver_gold_retention.py`. 직접 편집 금지.
> **측정일** 2026-08-07 · 모집단 = SILVER 물리 DATA 컬럼(감사 `DW_*` 5종 제외)
> **한계(P13)**: 컬럼명 토큰 스캔이므로 **개명 전파는 미탐**이다 — `DROPPED` 는 부재 확정이 아니다.
> `판정군` 은 사람 판정이며 이전 판본에서 키 단위 승계했다. 기계 STATUS 가 뒤집힌 행은 마지막 열에 표시된다.

## 1. 요약

| 구분 | 건수 |
|---|---:|
| SILVER DATA 컬럼 총계 | **523** |
| GOLD 직접소비 테이블의 컬럼(=보존율 분모) | **368** |
| └ REFERENCED (보존) | **225** |
| └ DROPPED (탈락) | **143** |
| SILVER_ONLY_CHAIN (SILVER 내부만 소비) | 127 |
| NO_CONSUMER (소비처 0) | 28 |

**보존율 = 225/368 = 61.1%**

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
| `CRM_BIZ_TARGET` | 10 | 6 | 4 | 0 | 0 | 60% | `FACT_TARGET_BIZ` |
| `CRM_CAMPAIGN` | 22 | 13 | 9 | 0 | 0 | 59% | `DIM_CAMPAIGN`, `DIM_MARKETING_CAMPAIGN`, `FACT_MEMBER_EVENT` |
| `CRM_CODE` | 6 | 3 | 3 | 0 | 0 | 50% | `DIM_CAMPAIGN`, `DIM_MEMBER`, `DIM_REASON`, `FACT_MEMBER_EVENT`, `FACT_MEMBER_FEE`, `WIDE_DEV_ACHIEVEMENT` |
| `CRM_DEV_TARGET` | 5 | 5 | 0 | 0 | 0 | 100% | `FACT_TARGET_DEV` |
| `CRM_EVENT` | 8 | 7 | 1 | 0 | 0 | 88% | `DIM_EVENT` |
| `CRM_EVENT_PARTICIPATION` | 9 | 9 | 0 | 0 | 0 | 100% | `FACT_EVENT_PARTICIPATION` |
| `CRM_MARKETING_CAMPAIGN` | 4 | 3 | 1 | 0 | 0 | 75% | `DIM_MARKETING_CAMPAIGN` |
| `CRM_MEMBER` | 27 | 10 | 17 | 0 | 0 | 37% | `DIM_MEMBER`, `DIM_MEMBER_IDENTITY`, `FACT_MEMBER_MONTHLY` |
| `CRM_MEMBER_AMT_CHANGE` | 14 | 4 | 10 | 0 | 0 | 29% | `FACT_MEMBER_MONTHLY` |
| `CRM_MEMBER_DEV` | 20 | 14 | 6 | 0 | 0 | 70% | `DIM_MEMBER`, `FACT_MEMBER_EVENT` |
| `CRM_MEMBER_DISCONTINUE` | 8 | 7 | 1 | 0 | 0 | 88% | `DIM_MEMBER`, `FACT_MEMBER_EVENT` |
| `CRM_MEMBER_RESPONSOR` | 4 | 0 | 0 | 0 | 4 | — | — |
| `CRM_MEMBER_SPONSOR_BIZ` | 7 | 0 | 0 | 7 | 0 | — | — |
| `CRM_MEMBER_STATUS_HIST` | 9 | 7 | 2 | 0 | 0 | 78% | `DIM_MEMBER` |
| `CRM_ORG` | 8 | 5 | 3 | 0 | 0 | 62% | `DIM_ORG` |
| `CRM_PAYMENT_BILLING` | 23 | 13 | 10 | 0 | 0 | 57% | `FACT_MEMBER_FEE`, `FACT_MEMBER_MONTHLY` |
| `CRM_PAYMENT_METHOD` | 14 | 2 | 12 | 0 | 0 | 14% | `DIM_PAYMENT` |
| `CRM_RELATION_ACTIVITY` | 8 | 0 | 0 | 0 | 8 | — | — |
| `CRM_SEND_MEMBER` | 6 | 5 | 1 | 0 | 0 | 83% | `FACT_SERVICE_EVENT` |
| `CRM_SEND_REQUEST` | 15 | 10 | 5 | 0 | 0 | 67% | `DIM_SEND_TYPE`, `DIM_SERVICE`, `FACT_SERVICE_EVENT` |
| `CRM_SEND_RESULT` | 6 | 0 | 0 | 0 | 6 | — | — |
| `CRM_SPONSORSHIP` | 6 | 3 | 3 | 0 | 0 | 50% | `DIM_SPONSORSHIP` |
| `CRM_SPONSOR_RELATION` | 10 | 0 | 0 | 0 | 10 | — | — |
| `ERP_BUDGET` | 8 | 4 | 4 | 0 | 0 | 50% | `FACT_BUDGET` |
| `ERP_BUDGET_ITEM` | 11 | 5 | 6 | 0 | 0 | 45% | `DIM_BUDGET_ITEM` |
| `GA4_DEVICE` | 6 | 1 | 5 | 0 | 0 | 17% | `DIM_DEVICE` |
| `GA4_EVENT` | 35 | 15 | 20 | 0 | 0 | 43% | `FACT_GA_BEHAVIOR` |
| `GA4_EVENT_DIM` | 4 | 3 | 1 | 0 | 0 | 75% | `DIM_GA_EVENT` |
| `GA4_IDENTITY` | 6 | 0 | 0 | 6 | 0 | — | — |
| `GA4_TRAFFIC_SOURCE` | 10 | 6 | 4 | 0 | 0 | 60% | `DIM_GA_SOURCE` |
| `IDENTITY_MEMBER_XREF` | 8 | 4 | 4 | 0 | 0 | 50% | `DIM_MEMBER_IDENTITY`, `FACT_GA_BEHAVIOR` |

## 4. 탈락(DROPPED) 전량 — 판정군별

### E_잔여_코드축개별판정 — 57건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `AGENCY_AD_PERFORMANCE` | `COST_TYPE` | 243,545 | 243,545 | 3 |
| `CRM_BIZ_TARGET` | `ORG_CD` | 0 | 0 | 0 |
| `CRM_CAMPAIGN` | `BRND_ID` | 34,686 | 34,686 | 84 |
| `CRM_CAMPAIGN` | `CMPGN_CTGR_CD` | 33,915 | 33,915 | 57 |
| `CRM_CAMPAIGN` | `CMPGN_TRGET_CD` | 34,686 | 34,686 | 10 |
| `CRM_CAMPAIGN` | `CMPGN_TYPE1_BSN` | 33,915 | 33,915 | 4 |
| `CRM_CAMPAIGN` | `CMPGN_TYPE2_BSN` | 33,915 | 33,915 | 4 |
| `CRM_CAMPAIGN` | `CPR_DIV_CD` | 34,686 | 34,686 | 3 |
| `CRM_CAMPAIGN` | `MBER_INFLOW_PATH_CD` | 33,915 | 33,915 | 16 |
| `CRM_CAMPAIGN` | `SPNSR_DIV_CD` | 34,686 | 34,686 | 2 |
| `CRM_CAMPAIGN` | `UPPER_CMPGN_YN` | 36,143 | 36,143 | 2 |
| `CRM_EVENT` | `BRNCH_DEPT_ID` | 19 | 19 | 19 |
| `CRM_MEMBER` | `ACT_DEPT_CD` | 1,583,316 | 1,583,316 | 281 |
| `CRM_MEMBER` | `CPR_DIV_CD` | 1,763,064 | 1,763,064 | 3 |
| `CRM_MEMBER` | `EMAIL_RECPTN` | 1,701,633 | 1,701,633 | 20 |
| `CRM_MEMBER` | `EMAIL_STAT_CD` | 733,452 | 733,452 | 4 |
| `CRM_MEMBER` | `ENTRPS_NM` | 34 | 34 | 30 |
| `CRM_MEMBER` | `ETC_CTTPC_REL_CD` | 127,432 | 127,432 | 14 |
| `CRM_MEMBER` | `ETC_CTTPC_STAT_CD` | 332,398 | 332,398 | 3 |
| `CRM_MEMBER` | `ETC_TSTM_DIV_CD` | 1,081,533 | 1,081,533 | 4 |
| `CRM_MEMBER` | `MOBLPHON_STAT_CD` | 1,578,320 | 1,578,320 | 3 |
| `CRM_MEMBER` | `PSTMTR_RECPTN` | 1,701,877 | 1,701,877 | 16 |
| `CRM_MEMBER` | `REGIST_DEPT_CD` | 1,758,140 | 1,758,140 | 370 |
| `CRM_MEMBER` | `RELATNSP_DIV_CD` | 1,587,293 | 1,587,293 | 4 |
| `CRM_MEMBER` | `REL_CD` | 9,769 | 9,769 | 12 |
| `CRM_MEMBER` | `SLRCLD_LRR_CD` | 1,284,714 | 1,284,714 | 4 |
| `CRM_MEMBER` | `TSTM_DIV_CD` | 1,154,557 | 1,154,557 | 4 |
| `CRM_MEMBER_AMT_CHANGE` | `ACMSLT_DEPT_CD` | 318,793 | 318,793 | 305 |
| `CRM_MEMBER_AMT_CHANGE` | `CMPGN_CD` | 318,916 | 318,916 | 10776 |
| `CRM_MEMBER_AMT_CHANGE` | `SPNSR_AMT_CD` | 318,814 | 318,814 | 5 |
| `CRM_MEMBER_DEV` | `ACT_DEPT_CD` | 3,594,829 | 3,594,829 | 372 |
| `CRM_MEMBER_DEV` | `CANCL_RDCAMT_RSN_CD` | 1,306,901 | 1,306,901 | 31 |
| `CRM_MEMBER_DEV` | `SPNSR_AMT_CD` | 3,594,843 | 3,594,843 | 5 |
| `CRM_MEMBER_DISCONTINUE` | `REGIST_DEPT_CD` | 925,948 | 925,948 | 54 |
| `CRM_PAYMENT_BILLING` | `CPR_DIV_CD` | 47,521,717 | 47,521,717 | 3 |
| `CRM_PAYMENT_BILLING` | `GFT_DIV_CD` | 83,104 | 83,104 | 7 |
| `CRM_PAYMENT_BILLING` | `MBRFEE_PRCS_STAT_CD` | 46,391,620 | 46,391,620 | 3 |
| `CRM_PAYMENT_BILLING` | `OPERT_DIV_CD` | 46,388,209 | 46,388,209 | 6 |
| `CRM_PAYMENT_BILLING` | `PRCS_RST_CD` | 46,068,766 | 46,068,766 | 7 |
| `CRM_PAYMENT_BILLING` | `RETUN_RSN_CD` | 15,217 | 15,217 | 11 |
| `CRM_PAYMENT_BILLING` | `RQEST_DIV_CD` | 46,384,703 | 46,384,703 | 4 |
| `CRM_PAYMENT_METHOD` | `APPLCNT_MBER_REL_CD` | 2,501,411 | 2,501,411 | 14 |
| `CRM_PAYMENT_METHOD` | `CARD_DIV_CD` | 690,943 | 690,943 | 3 |
| `CRM_PAYMENT_METHOD` | `CPR_DIV_CD` | 2,545,696 | 2,545,696 | 2 |
| `CRM_PAYMENT_METHOD` | `CRTFC_MTH_CD` | 1,935,325 | 1,935,325 | 5 |
| `CRM_PAYMENT_METHOD` | `FNLT_CD` | 716,068 | 716,068 | 107 |
| `CRM_PAYMENT_METHOD` | `FNLT_DIV_CD` | 2,456,268 | 2,456,268 | 3 |
| `CRM_PAYMENT_METHOD` | `RCEPT_DIV_CD` | 1,729,609 | 1,729,609 | 6 |
| `CRM_PAYMENT_METHOD` | `RQST_DIV_CD` | 1,729,610 | 1,729,610 | 6 |
| `CRM_PAYMENT_METHOD` | `SETLE_STAT_CD` | 2,545,696 | 2,545,696 | 9 |
| `CRM_PAYMENT_METHOD` | `WTDRW_STRT_DE` | 2,545,696 | 2,545,696 | 9779 |
| `CRM_SEND_REQUEST` | `MSG_DIV_CD` | 1,110,248 | 1,110,248 | 4 |
| `CRM_SEND_REQUEST` | `PSTMTR_PRCS_STAT_CD` | 3,801 | 3,801 | 2 |
| `CRM_SEND_REQUEST` | `SNDNG_TIME_DIV_CD` | 1,076,975 | 1,076,975 | 3 |
| `CRM_SPONSORSHIP` | `CPR_DIV_CD` | 50 | 50 | 2 |
| `CRM_SPONSORSHIP` | `DNTN_TY_CD` | 50 | 50 | 2 |
| `CRM_SPONSORSHIP` | `SPNSR_DIV_CD` | 50 | 50 | 2 |

### E→DROP_중복축 — 20건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `AGENCY_AD_PERFORMANCE` | `AD_CNT` | 37,295 | 37,295 | 1 |
| `AGENCY_AD_PERFORMANCE` | `PROGRAM_NM` | 36,097 | 36,097 | 1851 |
| `AGENCY_AD_PERFORMANCE` | `SOURCE_SYSTEM` | 243,545 | 243,545 | 3 |
| `CRM_MEMBER` | `MBER_DIV_NM` | 1,763,065 | 1,763,065 | 3 |
| `CRM_MEMBER` | `MBER_STAT_NM` | 1,587,342 | 1,587,342 | 12 |
| `CRM_MEMBER_AMT_CHANGE` | `AGE` | 318,814 | 318,814 | 12 |
| `CRM_MEMBER_AMT_CHANGE` | `AREA_CD` | 318,814 | 318,814 | 19 |
| `CRM_MEMBER_AMT_CHANGE` | `AREA_NM` | 317,473 | 317,473 | 18 |
| `CRM_MEMBER_AMT_CHANGE` | `MBER_DIV_CD` | 318,815 | 318,815 | 3 |
| `CRM_MEMBER_AMT_CHANGE` | `SEX` | 318,814 | 318,814 | 9 |
| `CRM_MEMBER_AMT_CHANGE` | `SPNSR_AMT` | 324,947 | 324,686 | 694 |
| `CRM_PAYMENT_BILLING` | `MBER_DIV_CD` | 46,391,620 | 46,391,620 | 3 |
| `GA4_EVENT` | `DEVICE_CATEGORY` | 538,565 | 538,565 | 3 |
| `GA4_EVENT` | `ID_RESOLUTION` | 538,565 | 538,565 | 4 |
| `GA4_EVENT` | `OS` | 538,544 | 538,544 | 7 |
| `GA4_EVENT` | `PLATFORM` | 538,565 | 538,565 | 1 |
| `GA4_EVENT` | `USER_ID` | 17,793 | 17,793 | 1874 |
| `GA4_EVENT` | `USER_ID_FILLED` | 122,241 | 122,241 | 1874 |
| `GA4_EVENT_DIM` | `EVENT_NAME` | 5,155 | 5,155 | 49 |
| `GA4_TRAFFIC_SOURCE` | `UTM_CAMPAIGN` | 2,150 | 2,150 | 243 |

### D_문서화된미전파 — 12건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `ERP_BUDGET` | `ADJ_BUDGET_AMT` | 75,469 | 8,670 | 3548 |
| `ERP_BUDGET` | `CHN_BUDGET_AMT` | 75,455 | 2,818 | 1589 |
| `ERP_BUDGET_ITEM` | `BUDGET_UNIT_NM` | 6,317 | 6,317 | 148 |
| `ERP_BUDGET_ITEM` | `BUDGET_YEAR` | 6,317 | 6,317 | 3 |
| `ERP_BUDGET_ITEM` | `FUND_SOURCE_NM` | 6,317 | 6,317 | 34 |
| `ERP_BUDGET_ITEM` | `HANG_NM` | 6,317 | 6,317 | 34 |
| `ERP_BUDGET_ITEM` | `JANG_NM` | 6,317 | 6,317 | 10 |
| `ERP_BUDGET_ITEM` | `KWAN_NM` | 6,317 | 6,317 | 16 |
| `GA4_DEVICE` | `BROWSER` | 0 | 0 | 0 |
| `GA4_DEVICE` | `DEVICE_CATEGORY` | 101 | 101 | 3 |
| `GA4_DEVICE` | `LANGUAGE` | 101 | 101 | 42 |
| `GA4_DEVICE` | `OS` | 100 | 100 | 7 |

### E→DROP_기술키 — 12건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `CRM_BIZ_TARGET` | `BIZ_TARGET_DK` | 0 | 0 | 0 |
| `CRM_MEMBER_AMT_CHANGE` | `SER_NO` | 324,947 | 324,947 | 322929 |
| `CRM_MEMBER_DEV` | `SPNSR_BSNS_NO` | 3,594,843 | 3,594,843 | 2213866 |
| `CRM_MEMBER_DEV` | `SPNSR_NO` | 3,594,843 | 3,594,843 | 2094758 |
| `CRM_PAYMENT_BILLING` | `PAY_KEY` | 47,521,872 | 47,521,872 | 48036177 |
| `CRM_PAYMENT_BILLING` | `RELATNSP_KEY` | 12,661,580 | 12,608,391 | 412240 |
| `CRM_PAYMENT_METHOD` | `MBER_NO` | 2,545,696 | 2,545,696 | 1572654 |
| `CRM_PAYMENT_METHOD` | `SETLE_KEY` | 2,545,696 | 2,545,696 | 2571607 |
| `CRM_SEND_MEMBER` | `SNDNG_DTL_KEY` | 38,471,525 | 38,471,525 | 31021146 |
| `CRM_SEND_REQUEST` | `REQ_SEQ_NO` | 1,707 | 1,707 | 1665 |
| `GA4_EVENT` | `BATCH_ORDERING_ID` | 538,565 | 538,565 | 92 |
| `GA4_EVENT` | `GA_SESSION_KEY` | 538,565 | 538,565 | 77444 |

### E→DROP_날짜파생 — 10건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `AGENCY_AD_PERFORMANCE` | `AD_MONTH` | 243,545 | 243,545 | 12 |
| `AGENCY_AD_PERFORMANCE` | `AD_YEAR` | 243,545 | 243,545 | 4 |
| `CRM_BIZ_TARGET` | `MONTH_NO` | 0 | 0 | 0 |
| `CRM_BIZ_TARGET` | `TARGET_YEAR` | 0 | 0 | 0 |
| `CRM_SEND_REQUEST` | `SNDNG_STDR_DE` | 1,614,397 | 1,614,397 | 1643858 |
| `ERP_BUDGET` | `BUDGET_YEAR` | 75,996 | 75,996 | 3 |
| `ERP_BUDGET` | `MONTH_NO` | 75,996 | 75,996 | 12 |
| `GA4_EVENT` | `EVENT_DATE` | 538,565 | 538,565 | 2 |
| `GA4_EVENT` | `EVENT_TIMESTAMP` | 538,565 | 538,565 | 361556 |
| `GA4_EVENT` | `EVENT_TS` | 538,565 | 538,565 | 350212 |

### E→DROP_기각 — 5건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `CRM_CODE` | `SORT_ORDR` | 5,272 | 5,253 | 278 |
| `CRM_CODE` | `USE_YN` | 5,837 | 5,837 | 2 |
| `CRM_ORG` | `SORT_ORDR` | 3 | 0 | 1 |
| `CRM_ORG` | `STATS_DEPT_LVL` | 8 | 5 | 2 |
| `IDENTITY_MEMBER_XREF` | `MEMBER_TYPE` | 2,009 | 2,009 | 2 |

### E→판정정정_도달불가 — 4건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `AGENCY_AD_PERFORMANCE` | `CREATIVE_NM` | 243,512 | 243,512 | 6305 |
| `AGENCY_AD_PERFORMANCE` | `MEDIA_CHANNEL_NM` | 243,545 | 243,545 | 106 |
| `AGENCY_AD_PERFORMANCE` | `UPPER_CAMPAIGN_NM` | 48,707 | 48,707 | 23 |
| `CRM_MEMBER_DEV` | `SETLE_CD` | 3,594,843 | 3,594,843 | 7 |

### E→잔여_원자grain팩트필요 — 3건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `GA4_EVENT` | `GA_SESSION_NUMBER` | 538,565 | 538,565 | 245 |
| `GA4_EVENT` | `LINK_TEXT` | 57,653 | 57,653 | 1898 |
| `GA4_EVENT` | `LINK_URL` | 51,118 | 51,118 | 3069 |

### (미판정 — 신규 또는 승계 실패) — 2건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `CRM_MARKETING_CAMPAIGN` | `RM` | 0 | 0 | 0 |
| `GA4_DEVICE` | `PLATFORM` | 101 | 101 | 1 |

### A_해소_사전조인대체 — 2건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `CRM_MEMBER_STATUS_HIST` | `BF_STAT_NM` | 7,501,761 | 7,501,761 | 12 |
| `CRM_MEMBER_STATUS_HIST` | `CHN_STAT_NM` | 7,501,761 | 7,501,761 | 12 |

### E→DROP_파생 — 2건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `IDENTITY_MEMBER_XREF` | `MATCH_CONFIDENCE` | 2,009 | 2,009 | 2 |
| `IDENTITY_MEMBER_XREF` | `MATCH_METHOD` | 2,009 | 2,009 | 2 |

### E→귀속확정_DIM_GA_SOURCE — 2건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `GA4_TRAFFIC_SOURCE` | `XCHAN_MEDIUM` | 2,167 | 2,167 | 28 |
| `GA4_TRAFFIC_SOURCE` | `XCHAN_SOURCE` | 2,167 | 2,167 | 113 |

### E→귀속확정_DIM_GEO신설 — 2건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `GA4_EVENT` | `GEO_CITY` | 538,565 | 537,430 | 435 |
| `GA4_EVENT` | `GEO_COUNTRY` | 538,565 | 538,545 | 85 |

### E→귀속확정_FACT_degen — 2건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `GA4_EVENT` | `UTM_CAMPAIGN` | 473,886 | 473,886 | 243 |
| `GA4_TRAFFIC_SOURCE` | `XCHAN_CAMPAIGN` | 2,167 | 2,167 | 276 |

### A_잔여_현업차단 — 1건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `CRM_ORG` | `UPPER_DEPT_ID` | 1,314 | 1,314 | 321 |

### A_해소_중복축DROP — 1건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `AGENCY_AD_CREATIVE` | `AD_SEC_NM` | 1,217 | 1,217 | 8 |

### C_원천값없음 — 1건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `AGENCY_AD_PERFORMANCE` | `CONV_CALL_CNT` | 0 | 0 | 0 |

### E→귀속확정_DIM_GA_PAGE신설 — 1건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `GA4_EVENT` | `PAGE_TITLE` | 537,087 | 537,087 | 443 |

### E→귀속확정_DIM_GA_REFERRER신설 — 1건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `GA4_EVENT` | `PAGE_REFERRER` | 427,957 | 427,957 | 10878 |

### E→배선후보 — 1건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `GA4_EVENT` | `DEFAULT_CHANNEL_GROUP` | 538,565 | 538,565 | 14 |

### E→보류_G5게이트 — 1건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `IDENTITY_MEMBER_XREF` | `ID_RESOLUTION` | 2,009 | 2,009 | 1 |

### E→선결배선 — 1건

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `CRM_CODE` | `UPPER_CD_ID` | 661 | 661 | 59 |

## 5. 소비처 0 (NO_CONSUMER) 전량

| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |
|---|---|---:|---:|---:|
| `CRM_MEMBER_RESPONSOR` | `MBER_NO` | 115,254 | 115,254 | 97823 |
| `CRM_MEMBER_RESPONSOR` | `REGIST_DEPT_CD` | 86,738 | 86,738 | 313 |
| `CRM_MEMBER_RESPONSOR` | `RE_SPNSR_DE` | 115,254 | 115,254 | 6560 |
| `CRM_MEMBER_RESPONSOR` | `SER_NO` | 115,254 | 115,254 | 114190 |
| `CRM_RELATION_ACTIVITY` | `ACTIVITY_KEY` | 388,153 | 388,153 | 388539 |
| `CRM_RELATION_ACTIVITY` | `ACTIVITY_TYPE` | 388,153 | 388,153 | 2 |
| `CRM_RELATION_ACTIVITY` | `GFTMNEY` | 180,544 | 180,544 | 54 |
| `CRM_RELATION_ACTIVITY` | `LETTER_DIV_CD` | 207,609 | 207,609 | 3 |
| `CRM_RELATION_ACTIVITY` | `MNG_NO` | 388,153 | 388,153 | 429 |
| `CRM_RELATION_ACTIVITY` | `RCEPT_DE` | 207,609 | 207,609 | 4457 |
| `CRM_RELATION_ACTIVITY` | `RELATNSP_KEY` | 388,153 | 388,153 | 138667 |
| `CRM_RELATION_ACTIVITY` | `SNDNG_DE` | 385,549 | 385,549 | 608 |
| `CRM_SEND_RESULT` | `FAILR_CNT` | 1,503,783 | 33,033 | 685 |
| `CRM_SEND_RESULT` | `SEND_CHANNEL` | 1,611,758 | 1,611,758 | 4 |
| `CRM_SEND_RESULT` | `SNDNG_CNT` | 1,611,758 | 1,611,748 | 2885 |
| `CRM_SEND_RESULT` | `SNDNG_KEY` | 1,611,758 | 1,611,758 | 1529288 |
| `CRM_SEND_RESULT` | `SUCCES_CNT` | 1,608,535 | 1,553,223 | 2561 |
| `CRM_SEND_RESULT` | `TOT_CLICK_CNT` | 0 | 0 | 0 |
| `CRM_SPONSOR_RELATION` | `CHILD_CD` | 862,610 | 862,608 | 471770 |
| `CRM_SPONSOR_RELATION` | `MBER_NO` | 862,610 | 862,610 | 544313 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_DSCNTC_DE` | 667,278 | 667,278 | 6602 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_DSCNTC_RSN_CD` | 667,214 | 667,214 | 30 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_DSCNTC_YN` | 862,610 | 862,610 | 2 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_KEY` | 862,610 | 862,610 | 856719 |
| `CRM_SPONSOR_RELATION` | `RELATNSP_STRT_DE` | 862,610 | 862,610 | 8411 |
| `CRM_SPONSOR_RELATION` | `SPNSR_BSNS_ID` | 862,610 | 862,610 | 3 |
| `CRM_SPONSOR_RELATION` | `SPNSR_BSNS_NO` | 862,610 | 862,610 | 667819 |
| `CRM_SPONSOR_RELATION` | `SPNSR_NO` | 862,610 | 862,610 | 636122 |

---
_Co-authored with CoCo_
