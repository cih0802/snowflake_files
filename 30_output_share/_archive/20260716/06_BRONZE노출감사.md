<!-- LLM-METADATA
doc_id: BRONZE_EXPOSURE_AUDIT
doc_role: BRONZE 전 원천 전면 노출감사 — GOLD 도달 여부 판정 정본
project: GN_DW
audit_date: 2026-07-28
generator: scripts/gen_bronze_exposure_audit.py
runner: scripts/run_bronze_audit_host.py
principle: P13(커버리지≠정확도)·P14(부재판정은 실측필수)
END-METADATA -->

# BRONZE 노출감사 (전 원천 전면)

> ⚙️ **자동 생성물** — 생성기 `scripts/gen_bronze_exposure_audit.py` / 러너 `scripts/run_bronze_audit_host.py`. 직접 편집 금지.
> **감사일** 2026-07-28 · **범위** BRONZE 전 원천 1121컬럼 (CRM·AGENCY·ERP·GA4)
> **목적** "보여줄 수 있는 BRONZE 데이터는 다 보여준다" 충족 여부 실측

## 0. 판정 기준 및 한계 (필독)

| 판정 | 의미 | 조치 |
|---|---|---|
| 노출됨(GOLD) | GOLD 컬럼으로 실적재 (동명 또는 계보 매핑 확인) | 없음 |
| 대체노출(파생) | BRONZE 원본 대신 타 컬럼 파생값 적재(의도된 설계) | 없음 |
| ⚠️설계O·값미주입 | **GOLD에 컬럼 자리는 있으나 `0`/`CAST(NULL)` 하드코딩** | **최우선 배선** |
| SILVER까지만 | SILVER 적재 완료·GOLD 미승격 | 지표 수요 확인 후 승격 |
| 판정보류(동명이의) | 일반명이 타 계보 GOLD 컬럼과 충돌 — 근거 불충분 | 실측 확인(P14) |
| 미노출(검토대상) | 어느 층에도 이름이 없음 | 개명·VARIANT 승격 여부 개별 확인 |
| 제외(PII·본문·메타) | PII·본문·감사메타 — 의도적 비노출 | 없음 |

**P13 한계 명시**: 본 감사는 *컬럼명 문자열 대조* 기반이다. 
개명 적재(예: `BRDC_DATE`→`BROADCAST_DATE`)는 `LINEAGE_MAP`에 등록된 건만 탐지된다. 
따라서 **'미노출' 판정은 부재 확정이 아니다** — 신뢰도 열이 `낮음(...)`인 행은 
개별 실측(P14) 없이 '원천 부재'로 단정해서는 안 된다.

**오탐 방지 설계**: 단순 전역 이름매칭은 무관한 동명 컬럼(예: AGENCY `YEAR` ↔ 
`DIM_DATE.YEAR`)을 '노출됨'으로 오판해 **실제 결손을 은폐**한다. 이를 막기 위해 
(a) 계보 매핑은 **GOLD 모델까지 특정**하고, (b) 일반명은 `판정보류(동명이의)`로 격리하며, 
(c) 동명 컬럼이 여러 모델에 있을 때 **모델별 하드코딩/실적재를 구분**한다. 
예: `AD_COST` 는 FACT_AD_PERFORMANCE 실적재·FACT_BUDGET 하드코딩으로 상태가 다르다.

## 1. 요약

| 판정 | 건수 | 비율 |
|---|---|---|
| 노출됨(GOLD) | 70 | 6.2% |
| 대체노출(파생) | 14 | 1.2% |
| ⚠️설계O·값미주입 | 1 | 0.1% |
| SILVER까지만 | 359 | 32.0% |
| 판정보류(동명이의) | 14 | 1.2% |
| 미노출(검토대상) | 612 | 54.6% |
| 제외(PII·본문·메타) | 51 | 4.5% |
| 제외(DW메타) | 0 | 0.0% |
| **합계** | **1121** | 100% |

### 원천별 교차

| 원천 | 노출됨(GOLD) | 대체노출(파생) | ⚠️설계O·값미주입 | SILVER까지만 | 판정보류(동명이의) | 미노출(검토대상) | 제외(PII·본문·메타) | 제외(DW메타) | 합계 |
|---|---|---|---|---|---|---|---|---|---|
| AGENCY | 63 | 13 | 1 | 18 | 7 | 0 | 0 | 0 | 102 |
| CRM | 3 | 0 | 0 | 275 | 7 | 591 | 51 | 0 | 927 |
| ERP | 0 | 1 | 0 | 57 | 0 | 4 | 0 | 0 | 62 |
| GA4 | 4 | 0 | 0 | 9 | 0 | 17 | 0 | 0 | 30 |

## 2. ⚠️ 최우선 조치군 — GOLD 설계O·값 미주입

dbt GOLD 모델에서 `0 as X_SK` 또는 `CAST(NULL AS ..) as X` 로 하드코딩된 컬럼 전량.
**GOLD 스키마에 자리가 이미 있으므로 DDL 변경 없이 SQL 배선만으로 해소 가능**한 군이다.

| GOLD 컬럼 | 모델:행 | 하드코딩 패턴 | 타 모델 실적재 |
|---|---|---|---|
| `AD_COST` | `FACT_BUDGET.sql:27` | `CAST(NULL AS NUMBER(18,2)) as AD_COST` | FACT_AD_PERFORMANCE.sql |
| `AD_CREATIVE_SK` | `FACT_AD_PERFORMANCE.sql:35` | `0 as AD_CREATIVE_SK` | DIM_AD_CREATIVE.sql |
| `AGE_BAND` | `DIM_MEMBER.sql:104` | `CAST(NULL AS VARCHAR) as AGE_BAND` | — |
| `AMOUNT_BAND1` | `FACT_MEMBER_MONTHLY.sql:75` | `CAST(NULL AS VARCHAR) as AMOUNT_BAND1` | — |
| `AMOUNT_BAND2` | `FACT_MEMBER_MONTHLY.sql:75` | `CAST(NULL AS VARCHAR) as AMOUNT_BAND2` | — |
| `ANNUAL_CUM_GOAL_CNT` | `FACT_TARGET_BIZ.sql:22` | `CAST(NULL AS NUMBER(18,4)) as ANNUAL_CUM_GOAL_CNT` | — |
| `APPLY_CHANNEL` | `DIM_EVENT.sql:23` | `CAST(NULL AS VARCHAR) as APPLY_CHANNEL` | — |
| `AVG_SESSION_DURATION` | `FACT_GA_BEHAVIOR.sql:74` | `CAST(NULL AS NUMBER) as AVG_SESSION_DURATION` | — |
| `BOUNCE_RATE` | `FACT_GA_BEHAVIOR.sql:75` | `CAST(NULL AS NUMBER) as BOUNCE_RATE` | — |
| `CAMPAIGN_SK` | `FACT_AD_PERFORMANCE.sql:34` | `0 as CAMPAIGN_SK` | DIM_CAMPAIGN.sql, FACT_TARGET_BIZ.sql |
| `CAMPAIGN_SK` | `FACT_BUDGET.sql:20` | `0 as CAMPAIGN_SK` | DIM_CAMPAIGN.sql, FACT_TARGET_BIZ.sql |
| `CAMPAIGN_SK` | `FACT_EVENT_PARTICIPATION.sql:17` | `0 as CAMPAIGN_SK` | DIM_CAMPAIGN.sql, FACT_TARGET_BIZ.sql |
| `CAMPAIGN_SK` | `FACT_GA_BEHAVIOR.sql:30` | `0 as CAMPAIGN_SK` | DIM_CAMPAIGN.sql, FACT_TARGET_BIZ.sql |
| `CAMPAIGN_SK` | `FACT_MEMBER_EVENT.sql:14` | `0 as CAMPAIGN_SK` | DIM_CAMPAIGN.sql, FACT_TARGET_BIZ.sql |
| `CAMPAIGN_SK` | `FACT_MEMBER_MONTHLY.sql:58` | `0 as CAMPAIGN_SK` | DIM_CAMPAIGN.sql, FACT_TARGET_BIZ.sql |
| `CAMPAIGN_SK` | `FACT_SERVICE_EVENT.sql:26` | `0 as CAMPAIGN_SK` | DIM_CAMPAIGN.sql, FACT_TARGET_BIZ.sql |
| `CHILD_CODE` | `DIM_MEMBER_IDENTITY.sql:30` | `CAST(NULL AS VARCHAR) as CHILD_CODE` | — |
| `CORP` | `DIM_ORG.sql:19` | `CAST(NULL AS VARCHAR) as CORP` | — |
| `CURRENT_SPONSORSHIP` | `DIM_MEMBER.sql:123` | `CAST(NULL AS VARCHAR) as CURRENT_SPONSORSHIP` | — |
| `DEVICE_SK` | `FACT_AD_PERFORMANCE.sql:8` | `0 as DEVICE_SK` | DIM_DEVICE.sql, FACT_GA_BEHAVIOR.sql |
| `DEV_TYPE` | `FACT_MEMBER_MONTHLY.sql:72` | `CAST(NULL AS VARCHAR) as DEV_TYPE` | FACT_TARGET_DEV.sql |
| `DIVISION` | `DIM_ORG.sql:20` | `CAST(NULL AS VARCHAR) as DIVISION` | — |
| `DOMESTIC_OVERSEAS` | `DIM_CAMPAIGN.sql:22` | `CAST(NULL AS VARCHAR) as DOMESTIC_OVERSEAS` | — |
| `DURATION_SEC` | `DIM_AD_CREATIVE.sql:25` | `CAST(NULL AS NUMBER(9,0)) as DURATION_SEC` | FACT_AD_BROADCAST.sql |
| `EFFECTIVE_TO` | `DIM_MEMBER.sql:74` | `CAST(NULL AS DATE) as EFFECTIVE_TO` | — |
| `EXEC_BUDGET_EST` | `FACT_BUDGET.sql:25` | `CAST(NULL AS NUMBER(18,2)) as EXEC_BUDGET_EST` | — |
| `FEE_TYPE` | `DIM_PAYMENT.sql:19` | `CAST(NULL AS VARCHAR) as FEE_TYPE` | — |
| `FIRST_SPONSORSHIP` | `DIM_MEMBER.sql:120` | `CAST(NULL AS VARCHAR) as FIRST_SPONSORSHIP` | — |
| `FUNDRAISING_COST` | `FACT_BUDGET.sql:26` | `CAST(NULL AS NUMBER(18,2)) as FUNDRAISING_COST` | — |
| `INCREASE_FLAG` | `FACT_EVENT_PARTICIPATION.sql:28` | `CAST(NULL AS BOOLEAN) as INCREASE_FLAG` | — |
| `INCREASE_FLAG` | `FACT_MEMBER_MONTHLY.sql:73` | `CAST(NULL AS BOOLEAN) as INCREASE_FLAG` | — |
| `JOIN_DATE` | `FACT_MEMBER_EVENT.sql:33` | `CAST(NULL AS DATE) as JOIN_DATE` | — |
| `JOIN_DATE` | `FACT_MEMBER_MONTHLY.sql:74` | `CAST(NULL AS DATE) as JOIN_DATE` | FACT_MEMBER_EVENT.sql |
| `LAST_CAMPAIGN` | `DIM_MEMBER.sql:122` | `CAST(NULL AS VARCHAR) as LAST_CAMPAIGN` | — |
| `LAST_STOP_DATE` | `DIM_MEMBER.sql:121` | `CAST(NULL AS DATE) as LAST_STOP_DATE` | — |
| `MAIL_RECEIVE_FLAG` | `FACT_SERVICE_EVENT.sql:37` | `CAST(NULL AS BOOLEAN) as MAIL_RECEIVE_FLAG` | — |
| `MEMBER_STOP_FLAG` | `FACT_SERVICE_EVENT.sql:38` | `CAST(NULL AS BOOLEAN) as MEMBER_STOP_FLAG` | — |
| `MEMNUM` | `DIM_MEMBER_IDENTITY.sql:27` | `CAST(NULL AS VARCHAR) as MEMNUM` | — |
| `NEW_EXISTING_FLAG` | `DIM_MEMBER.sql:115` | `CAST(NULL AS VARCHAR) as NEW_EXISTING_FLAG` | — |
| `NEW_EXISTING_FLAG` | `FACT_MEMBER_EVENT.sql:21` | `CAST(NULL AS VARCHAR) as NEW_EXISTING_FLAG` | — |
| `NEW_EXISTING_FLAG` | `FACT_MEMBER_MONTHLY.sql:78` | `CAST(NULL AS VARCHAR) as NEW_EXISTING_FLAG` | — |
| `NEW_FLAG` | `FACT_MEMBER_MONTHLY.sql:73` | `CAST(NULL AS BOOLEAN) as NEW_FLAG` | — |
| `ORG_SK` | `DIM_CAMPAIGN.sql:25` | `0 as ORG_SK` | DIM_ORG.sql, FACT_TARGET_BIZ.sql, FACT_TARGET_DEV.sql |
| `ORG_SK` | `FACT_BUDGET.sql:18` | `0 as ORG_SK` | DIM_ORG.sql, FACT_TARGET_BIZ.sql, FACT_TARGET_DEV.sql |
| `ORG_SK` | `FACT_MEMBER_EVENT.sql:14` | `0 as ORG_SK` | DIM_ORG.sql, FACT_TARGET_BIZ.sql, FACT_TARGET_DEV.sql |
| `PAYMENT_SK` | `FACT_MEMBER_MONTHLY.sql:58` | `0 as PAYMENT_SK` | DIM_PAYMENT.sql |
| `PERIOD_BAND1` | `FACT_MEMBER_MONTHLY.sql:76` | `CAST(NULL AS VARCHAR) as PERIOD_BAND1` | — |
| `PERIOD_BAND2` | `FACT_MEMBER_MONTHLY.sql:76` | `CAST(NULL AS VARCHAR) as PERIOD_BAND2` | — |
| `PLAN_BUDGET_YEAR` | `FACT_BUDGET.sql:23` | `CAST(NULL AS NUMBER(18,2)) as PLAN_BUDGET_YEAR` | — |
| `PLATFORM_TYPE` | `DIM_AD_CREATIVE.sql:22` | `CAST(NULL AS VARCHAR) as PLATFORM_TYPE` | — |
| `REASON_SK` | `FACT_MEMBER_EVENT.sql:14` | `0 as REASON_SK` | DIM_REASON.sql |
| `REASON_SK` | `FACT_MEMBER_MONTHLY.sql:58` | `0 as REASON_SK` | DIM_REASON.sql |
| `REDONATE_FLAG` | `FACT_MEMBER_MONTHLY.sql:73` | `CAST(NULL AS BOOLEAN) as REDONATE_FLAG` | — |
| `REGION` | `DIM_MEMBER.sql:103` | `CAST(NULL AS VARCHAR) as REGION` | — |
| `RT_TYPE` | `DIM_AD_CREATIVE.sql:26` | `CAST(NULL AS VARCHAR) as RT_TYPE` | FACT_AD_BROADCAST.sql |
| `SELF_PART_FLAG` | `FACT_EVENT_PARTICIPATION.sql:24` | `CAST(NULL AS BOOLEAN) as SELF_PART_FLAG` | — |
| `SEND_STATUS2` | `FACT_SERVICE_EVENT.sql:35` | `CAST(NULL AS VARCHAR) as SEND_STATUS2` | — |
| `SEND_TYPE_L` | `DIM_SERVICE.sql:17` | `CAST(NULL AS VARCHAR) as SEND_TYPE_L` | — |
| `SEND_TYPE_M` | `DIM_SERVICE.sql:18` | `CAST(NULL AS VARCHAR) as SEND_TYPE_M` | — |
| `SEND_TYPE_S` | `DIM_SERVICE.sql:19` | `CAST(NULL AS VARCHAR) as SEND_TYPE_S` | — |
| `SPONSORSHIP_SK` | `FACT_BUDGET.sql:21` | `CAST(NULL AS NUMBER(38,0)) as SPONSORSHIP_SK` | DIM_SPONSORSHIP.sql, FACT_TARGET_BIZ.sql |
| `SPONSORSHIP_SK` | `FACT_EVENT_PARTICIPATION.sql:18` | `0 as SPONSORSHIP_SK` | DIM_SPONSORSHIP.sql, FACT_TARGET_BIZ.sql |
| `SPONSORSHIP_SK` | `FACT_MEMBER_EVENT.sql:14` | `0 as SPONSORSHIP_SK` | DIM_SPONSORSHIP.sql, FACT_TARGET_BIZ.sql |
| `SPONSORSHIP_SK` | `FACT_MEMBER_MONTHLY.sql:58` | `0 as SPONSORSHIP_SK` | DIM_SPONSORSHIP.sql, FACT_TARGET_BIZ.sql |
| `STOP_CHANNEL` | `FACT_MEMBER_EVENT.sql:20` | `CAST(NULL AS VARCHAR) as STOP_CHANNEL` | — |
| `STOP_DATE` | `FACT_MEMBER_EVENT.sql:18` | `CAST(NULL AS DATE) as STOP_DATE` | — |
| `STOP_DATE` | `FACT_MEMBER_MONTHLY.sql:74` | `CAST(NULL AS DATE) as STOP_DATE` | FACT_MEMBER_EVENT.sql |
| `STOP_REASON` | `FACT_MEMBER_EVENT.sql:19` | `CAST(NULL AS VARCHAR) as STOP_REASON` | — |
| `SUPP_CUM_GOAL_CNT` | `FACT_TARGET_BIZ.sql:23` | `CAST(NULL AS NUMBER(18,4)) as SUPP_CUM_GOAL_CNT` | — |
| `TARGET_GROUP` | `DIM_AD_CREATIVE.sql:28` | `CAST(NULL AS VARCHAR) as TARGET_GROUP` | — |
| `TEAM` | `DIM_ORG.sql:22` | `CAST(NULL AS VARCHAR) as TEAM` | — |

> '타 모델 실적재'가 있는 행은 **해당 모델에서만** 결손이다. 
> 컬럼명만 보고 전역 해소로 오판하면 안 된다.

### 2-1. BRONZE 실존 확인된 하드코딩 (즉시 배선 대상)

`LINEAGE_MAP` 으로 BRONZE 원천이 확인된 건 — dbt 주석의 '원천 부재' 단정은 
**오류이며 정정 대상**이다(P14 위반 사례).

| BRONZE 테이블 | BRONZE 컬럼 | GOLD 컬럼 | GOLD 모델 | 상태 |
|---|---|---|---|---|
| `DGT_AD_CMPGN_DTLS` | `DEVICE` | `DEVICE_SK` | `FACT_AD_PERFORMANCE.sql` | ⚠️ 하드코딩 — 배선 필요 |

## 3. 원천별 컬럼 상세

### AGENCY (102컬럼)

<details><summary><b>DGT_AD_CMPGN_DTLS</b> — 36컬럼 (GOLD 20 · 하드코딩 1)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `TIME` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `YEAR` | TEXT | 대체노출(파생) | 높음 | DATE 파생(YEAR(AD_DATE)) 로 대체 — 텍스트 파싱 금지 원칙 |
| `CPR_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DMST_OVSEA_DIV_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `BSNS_CASE_DIV_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_TY_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `AD_TY_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `AD_TYPE_NM` (FACT_AD_DIGITAL.sql) |
| `MONTH` | TEXT | 대체노출(파생) | 높음 | DATE 파생(MONTH(AD_DATE)) 로 대체 |
| `DEVICE` | TEXT | ⚠️설계O·값미주입 | 높음 | GOLD `DEVICE_SK`(FACT_AD_PERFORMANCE.sql) 자리 존재하나 하드코딩 — FACT_AD_PERFORMANCE.sql:8 `0 as DEVICE_SK` |
| `MEDIA_NM` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `WEEK` | TEXT | 대체노출(파생) | 높음 | DATE 파생(WEEKOFYEAR) 로 대체 |
| `DAY` | TEXT | 대체노출(파생) | 높음 | DATE 파생(DAY) 로 대체 |
| `DOW` | TEXT | 대체노출(파생) | 높음 | DATE 파생(DAYNAME) 로 대체 |
| `CMPGN_NM` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `MATR` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MATR_TY_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CREATIVE_TYPE` (FACT_AD_DIGITAL.sql) |
| `EXPS_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `IMPRESSIONS` (FACT_AD_PERFORMANCE.sql) |
| `CLICK_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CLICKS` (FACT_AD_PERFORMANCE.sql) |
| `GA_AD_COST` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `AD_COST` (FACT_AD_PERFORMANCE.sql) |
| `GA_CONV_MBER_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `GA_CONV_MEMBERS` (FACT_AD_PERFORMANCE.sql) |
| `CONV_VU_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `GA_CONV_CNT` (FACT_AD_PERFORMANCE.sql) |
| `CPA` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CPA_SRC` (FACT_AD_DIGITAL.sql) |
| `DEV_UNIT_PRICE` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `DEV_UNIT_PRICE_SRC` (FACT_AD_DIGITAL.sql) |
| `CTR` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CTR_SRC` (FACT_AD_DIGITAL.sql) |
| `CVR` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CVR_SRC` (FACT_AD_DIGITAL.sql) |
| `CPC` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CPC_SRC` (FACT_AD_DIGITAL.sql) |
| `CPM` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CPM_SRC` (FACT_AD_DIGITAL.sql) |
| `UPPER_CMPGN_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `READ_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `READ_CNT` (FACT_AD_DIGITAL.sql) |
| `MEDIA_PTNT_CUST_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `MEDIA_POTENTIAL_CUST_CNT` (FACT_AD_DIGITAL.sql) |
| `DATE` | DATE | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `VTR` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `VTR_SRC` (FACT_AD_DIGITAL.sql) |
| `PAGE_TYPE_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `PAGE_TYPE` (FACT_AD_DIGITAL.sql) |
| `CRM_DVLP_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CRM_DEV_CNT` (FACT_AD_DIGITAL.sql) |
| `AD_GRP_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `AD_GROUP_NM` (FACT_AD_DIGITAL.sql) |
| `GRP_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `GROUP_DIV` (FACT_AD_DIGITAL.sql) |

</details>

<details><summary><b>REBRDC_AD_CMPGN_DTLS</b> — 34컬럼 (GOLD 24 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `RE_BRDC_TY_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `RT_TYPE` (FACT_AD_BROADCAST.sql) |
| `DIV_NM` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `YEAR` | TEXT | 대체노출(파생) | 높음 | DATE 파생(YEAR(AD_DATE)) 로 대체 — 텍스트 파싱 금지 원칙 |
| `BRDC_MT` | TEXT | 대체노출(파생) | 높음 | DATE 파생(MONTH) 로 대체 |
| `CHNNL_CMPNY` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CHANNEL_COMPANY` (FACT_AD_BROADCAST.sql) |
| `BRDC_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `PROGRAM_NM` (FACT_AD_BROADCAST.sql) |
| `BRDC_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `BRDC_DIV` (FACT_AD_BROADCAST.sql) |
| `DATE` | DATE | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `BROADCAST_DATE` (FACT_AD_BROADCAST.sql) |
| `DOW` | TEXT | 대체노출(파생) | 높음 | DATE 파생(DAYNAME) 로 대체 |
| `BRDC_TIME` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `TIME_BAND` (FACT_AD_BROADCAST.sql) |
| `INBOUND_CALL_CNT` | TEXT | 노출됨(GOLD) | 높음 | 동명 GOLD 컬럼 + 실적재 projection 확인 |
| `DVLP_MBER_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `DVLP_MEMBER_CNT` (FACT_AD_BROADCAST.sql) |
| `DVLP_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `DVLP_CNT` (FACT_AD_BROADCAST.sql) |
| `BRDC_SCHDL_COST` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `AD_COST` (FACT_AD_PERFORMANCE.sql) |
| `WEEK` | TEXT | 대체노출(파생) | 높음 | DATE 파생(WEEKOFYEAR) 로 대체 |
| `AD_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 동명 GOLD 컬럼 + 실적재 projection 확인 |
| `TIME_RNG_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `TIME_BAND` (FACT_AD_BROADCAST.sql) |
| `CELEB_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DMST_OVSEA_DIV_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CASE1_BSNS_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `BIZ_DIV` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE1_FAM_TY_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `FAMILY_TYPE` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE1_APPEAL_POINT_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `APPEAL_POINT` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE1_CHILD_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CASE1_CASE_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CASE_DIV` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE2_BSNS_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `BIZ_DIV` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE2_FAM_TY_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `FAMILY_TYPE` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE2_APPEAL_POINT_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `APPEAL_POINT` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE2_CHILD_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CASE2_CASE_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CASE_DIV` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE3_BSNS_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `BIZ_DIV` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE3_FAM_TY_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `FAMILY_TYPE` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE3_APPEAL_POINT_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `APPEAL_POINT` (FACT_AD_BROADCAST_CASE.sql) |
| `CASE3_CHILD_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CASE3_CASE_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CASE_DIV` (FACT_AD_BROADCAST_CASE.sql) |

</details>

<details><summary><b>VIDEO_AD_CMPGN_DTLS</b> — 32컬럼 (GOLD 19 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `CHNNL_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CHANNEL_COMPANY` (FACT_AD_BROADCAST.sql) |
| `DOW` | TEXT | 대체노출(파생) | 높음 | DATE 파생(DAYNAME) 로 대체 |
| `BRDC_DATE` | DATE | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `BROADCAST_DATE` (FACT_AD_BROADCAST.sql) |
| `TIME_RNG` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `TIME_BAND` (FACT_AD_BROADCAST.sql) |
| `DAY_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `DAY_DIV` (FACT_AD_BROADCAST.sql) |
| `PRG_STRT_TIME` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `PRG_START_TIME` (FACT_AD_BROADCAST.sql) |
| `SCHDL_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `PROGRAM_NM` (FACT_AD_BROADCAST.sql) |
| `CM` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `CM_AREA` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CM_POSITION` (FACT_AD_BROADCAST.sql) |
| `AD_STRT_TIME` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `AD_START_TIME` (FACT_AD_BROADCAST.sql) |
| `AD_END_TIME` | TEXT | 노출됨(GOLD) | 높음 | 동명 GOLD 컬럼 + 실적재 projection 확인 |
| `SPOT_TY` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `SPOT_TYPE` (FACT_AD_BROADCAST.sql) |
| `AD_VIEW_RT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `AD_VIEW_RT_SRC` (FACT_AD_BROADCAST.sql) |
| `AD_CNT` | NUMBER | 노출됨(GOLD) | 높음 | 동명 GOLD 컬럼 + 실적재 projection 확인 |
| `AD_SEC` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `DURATION_SEC` (FACT_AD_BROADCAST.sql) |
| `ACTL_PUR_AD_COST_KRW` | NUMBER | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `AD_COST` (FACT_AD_PERFORMANCE.sql) |
| `INBOUND_CALL_CNT` | NUMBER | 노출됨(GOLD) | 높음 | 동명 GOLD 컬럼 + 실적재 projection 확인 |
| `CPC` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CPC_SRC` (FACT_AD_BROADCAST.sql) |
| `UPPER_CMPGN_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MATR_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_TY_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DUR_PD_MATR_CHN` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CHNNL_CMPNY_TY_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CHANNEL_COMPANY_TYPE` (FACT_AD_BROADCAST.sql) |
| `WEEK` | TEXT | 대체노출(파생) | 높음 | DATE 파생(WEEKOFYEAR) 로 대체 |
| `CONV_CALL_CNT` | FLOAT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CONV_CALL_CNT` (FACT_AD_BROADCAST.sql) |
| `BRDC_MT` | TEXT | 대체노출(파생) | 높음 | DATE 파생(MONTH) 로 대체 |
| `YEAR` | TEXT | 대체노출(파생) | 높음 | DATE 파생(YEAR(AD_DATE)) 로 대체 — 텍스트 파싱 금지 원칙 |
| `CTV_DIV_NM` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `CTV_DIV` (FACT_AD_BROADCAST.sql) |
| `MKT_CMPGN_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_BSNS_NM` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `DMST_OVSEA_DIV_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `BSNS_CASE_DIV_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |

</details>

### CRM (927컬럼)

<details><summary><b>SND_MEMBER_LIST</b> — 76컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `REQ_SEQ_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `R_NUM` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CMPGN_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_NM` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `GENDER` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `AGE` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `SETLE_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DSCNTC_PATH` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DSCNTC_RSN_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DSCNTC_RSN_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CHILD_NO` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LST_BRND_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LST_BRND_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `MNG_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `LETTER_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CHILD_DTL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHILD_DTL_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RELATNSP_DSCNTC_YN` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `FRST_SPNSR` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_BRND_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_BRND_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RELATNSP_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `LST_REGIST_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PRIV_SUSP_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SND_YN` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `SND_MSG` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `REG_DATE` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `SND_DT` | TIMESTAMP_NTZ | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `SND_HOUR` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SND_MIN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `EMAIL_RECPTN_CD` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EMAIL_RECPTN_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `NATION_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `NATION_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BPLC_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BPLC_KOR_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `DISCHARGE_REPORT_KOR` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `PAST_NATION_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PAST_BPLC_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PAST_CHILD_NO` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FAMILY_DTL` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FINAL_CHILD_SPNSR_START_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `NEW_CHILD_NO` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `NEW_CHILD_PROJECT_COUNTRY` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `NEW_CHILD_WORKPLACE_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `NEW_CHILD_PIC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `NEW_CHILD_GENDER` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_AMOUNT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_STRT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_DSCNTC_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RELATNSP_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_TYPE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DEPT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CURRENT_BRND` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CURRENT_UPPER_CMPGN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CURRENT_CMPGN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FIRST_UPPER_CMPGN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FIRST_CMPGN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_TOP_CMPGN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_CMPGN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MSG_KEY` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CINFO` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RESPONSED_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RESPONSED_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SYNCED_AT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CALL_STATUS` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `REAL_SEND_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPPER_CMPGN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>SND_REQ_MST</b> — 54컬럼 (GOLD 2 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SEQ_NO` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `SEND_GBN_TOP` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SEND_GBN_MID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SEND_GBN_BOT` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SEND_TITLE` | TEXT | 노출됨(GOLD) | 높음 | 동명 GOLD 컬럼 + 실적재 projection 확인 |
| `MSG_TYPE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TMPL_CODE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `AUTHOR` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CREATE_DATE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CONDITION_TITLE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CALL_NUMBER` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ALT_SMS_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `REGULARLY` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PERIODIC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PERIODIC_WEEK` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PERIODIC_DAY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SEND_DATE` | DATE | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `SEND_TIME` | TIME | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SEND_MIN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SEND_SPLIT_TYPE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `DIVIDE` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `DIVIDE_UNIT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CORP_TYPE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `AUTO_TYPE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `REG_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MOD_DATE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `INIT_REG_DATE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_SEND_DATE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPR_STATUS` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CREATE_DEPT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SENDER_EMAIL` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RCPT_LIST` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SEND_STATUS` | TEXT | 노출됨(GOLD) | 높음 | 동명 GOLD 컬럼 + 실적재 projection 확인 |
| `SEND_CNT` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `FAIL_CNT` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `LAST_ERR` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `END_DATE` | DATE | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `PAPER_YEAR` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MENU_CODE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SEND_GBN_TOP_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SEND_GBN_MID_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SEND_GBN_BOT_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `TARGET_CNT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SEND_ROUND` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `EXTRA` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ASSIGN_TARGET_CNT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FIRST_SEQ_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `JOB_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SYNCED_AT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `REG_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SERVICE_MENU_CODE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TC_CMMN_CD</b> — 12컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `CD_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CD_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CD_DC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SORT_ORDR` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TC_CMMN_DTL_CD</b> — 17컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `CD_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DTL_CD_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DTL_CD_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DTL_CD_DC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SORT_ORDR` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `CD_ATRB1` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CD_ATRB2` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CD_ATRB3` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `UPPER_CD_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TD_MS_AT_TMPLAT_BTN_LIST</b> — 14컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `TMPLAT_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BTN_SEQ` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BTN_TY_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BTN_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ANDROID_URL` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `IOS_URL` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MOBILE_URL` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `PC_URL` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TD_MS_CRMN_PRTCPNT</b> — 21컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `CRMN_CD` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `PRTCPNT_KEY` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `RQST_PATH_CD` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `PARTCPT_TIME_CO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PARTCPT_STAT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SELF_PARTCPT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RCPMNY_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RCPMNY_DATE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `REFND_DATE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQST_DATE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PARTCPT_DATE` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `RCPMNY_AMT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `ACMPNY_PARTCPT_CO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TD_MS_EMAIL_LQY_SNDNG</b> — 26컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SNDNG_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `MSG_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MKT_TRGET_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_CNT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SUCCES_CNT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `FAILR_CNT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `RECPTN_CNT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_STRT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_END_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `INFLOW_PATH_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_YEAR_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_MT_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_TEAM_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SUCCES_FAILR_CNT_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `URL_OTHBC_CNT_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `URL_OTHBC_RT_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SESION_VU_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SESION_PGE_CNT_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `DVLP_ACMSLT_CNT_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CLOS_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TD_MS_EMAIL_SNDNG_DTLS</b> — 12컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SNDNG_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_DTL_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_DE` | TIMESTAMP_NTZ | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_RST_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `ATCHFL_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TD_MS_EVENT_PRTCPNT_DTL</b> — 17컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `EVENT_CD` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PARTCPT_SEQ` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `EVENT_PARTCPT_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PRZWIN_CD` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `PARTCPT_CHNNL_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PARTCPT_PATH_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PARTCPT_STAT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PARTCPT_DT` | TIMESTAMP_NTZ | SILVER까지만 | 높음 | GOLD 미승격 |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RM2` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TD_MS_MSG_AT_LQY_SNDNG</b> — 20컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SNDNG_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `DIVS_DTL_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_CNT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SUCCES_CNT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `AT_ALTRTV_SNDNG_CNT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `AT_FAILR_CNT` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `RESVE_SNDNG_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RESVE_HM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TOT_CLICK_CNT_CTNT` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CLICK_CNT_CTNT1` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CLICK_CNT_CTNT2` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CLICK_CNT_CTNT3` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CLICK_CNT_CTNT4` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RM_VU_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TD_MS_MSG_AT_SNDNG_DTLS</b> — 15컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SNDNG_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_DTL_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_DT` | TIMESTAMP_NTZ | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TRNSMS_STAT_CD` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `TRNSMS_FAILR_CD_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ALTRTV_MSG_SNDNG_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ATTACHED_FILE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TD_MS_PSTMTR_LQY_SNDNG</b> — 11컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SNDNG_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_CNT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_SQNC` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_TIT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_MEMO_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TD_MS_PSTMTR_SNDNG_DTL</b> — 14컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SNDNG_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_DTL_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_DE` | TIMESTAMP_NTZ | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `RELATNSP_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `MNG_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DTL_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BIZN_REQUST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TH_MM_FDRM_MBER_STNG_DTLS</b> — 8컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SER_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `BF_STAT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CHN_STAT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TH_PM_SETLE_INFO_HIST</b> — 49컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SETLE_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `UPDUSR_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `WTDRW_STRT_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `WTDRW_ASMT_SQNC` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FNLT_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FNLT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_ENTRPS_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CARD_TRMVT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ACNUT_SER_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PAYER_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CARD_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `ETC_CTTPC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ETC_CTTPC_REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PAYER_MBER_REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_MTH_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_FILE_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_DATA_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FILE_SIZE` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BILLKEY` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SETLE_STAT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `BF_SETLE_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQST_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RCEPT_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APRV_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APRV_REQUST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APRV_RST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_BEGIN_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_EXCL_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_EXCL_STRT_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_EXCL_END_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPLCNT_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPLCNT_ETC_CTTPC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPLCNT_ETC_CTTPC_REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPLCNT_MBER_REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BF_SETLE_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `OPERT_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_TY_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `RGSTR_ID` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `RGSTR_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `REGIST_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_CM_BRND_MNG</b> — 11컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `BRND_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `BRND_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `USE_DEPT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `PR_MTH_LIST` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_CM_CMPGN_MNG</b> — 34컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `CMPGN_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_NM` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `UPPER_CMPGN_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `UPPER_CMPGN_YN` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_TRGET_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_DEPT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_SCOPE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_ENTRPRS_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BRND_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PR_MTH_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_STRT_DE` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBRFEE_BNKB_LIST` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `INICIS_ACNT_NO` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `REFER_URL` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_BSNS_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_DC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `EMRGNCY_AID_BPLC_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CMPGN_PRPT_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ATCHFL_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MBER_INFLOW_PATH_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CMPGN_CTGR_CD` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_TYPE1_BSN` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_TYPE2_BSN` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `MKTG_CMPGN_NM` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_CM_DEPT_INFO</b> — 14컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `DEPT_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DEPT_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `UPPER_DEPT_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SORT_ORDR` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `ACMSLT_DEPT_YN` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `STATS_DEPT_LVL` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ACMSLT_UPPER_DEPT_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_CM_MBER_DVLP_GOAL</b> — 11컬럼 (GOLD 1 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `STDYY` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `STDR_MT` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_DVLP_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DEPT_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `GOAL_CNT` | NUMBER | 노출됨(GOLD) | 높음 | 동명 GOLD 컬럼 + 실적재 projection 확인 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_CM_MKTNG_CMPGN_MNG</b> — 10컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `MK_CMPGN_CD` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `MK_CMPGN_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_CM_SPNSR_BSNS_INFO</b> — 15컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SPNSR_BSNS_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_BSNS_NM` | TEXT | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `SPNSR_BSNS_ABRV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DNTN_TY_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SORT_ORDR` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MM_FDRM_MBER_DVLP_AMT</b> — 23컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SPNSR_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_BSNS_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `OCCRRNC_DE` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SER_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `ACT_DEPT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `ACMSLT_DEPT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SEX` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `AREA_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `AGE` | NUMBER | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `SPNSR_TIME_CO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_AMT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_BSNS_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CANCL_RDCAMT_RSN_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_AMT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `DVLP_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MM_FDRM_MBER_INFO</b> — 31컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SLRCLD_LRR_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MOBLPHON_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TSTM_DIV_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ETC_TSTM_DIV_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ETC_CTTPC_REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ETC_CTTPC_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `EMAIL_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PSTMTR_RECPTN_CD` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EMAIL_RECPTN_CD` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHRCTR_RECPTN_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BL_ENTRPS_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPECL_MNG_CD1` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPECL_MNG_CD2` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TNI_CU_BL_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CMPGN_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_STAT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `RELATNSP_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ACT_DEPT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `HMPG_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `JOIN_PATH_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CTI_SYNCHRN_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `STDR_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `REGIST_DEPT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SEX` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MM_FDRM_MBER_IRSD</b> — 17컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `OCCRRNC_DE` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SER_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `ACMSLT_DEPT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CMPGN_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_AMT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SEX` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `AREA_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `AGE` | NUMBER | 판정보류(동명이의) | 낮음(일반명 충돌) | 동명 GOLD/SILVER 컬럼이 있으나 계보 무관 가능 — 실측 필요(P14) |
| `SPNSR_TIME_CO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_AMT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RDCAMT_YN` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MM_FDRM_MBER_RE_SPNSR</b> — 7컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SER_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `RE_SPNSR_DE` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `REGIST_DEPT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MM_FDRM_MBER_SPNSR_BSNS</b> — 9컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SPNSR_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_BSNS_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_BSNS_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_AMT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_DSCNTC_DE` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_DSCNTC_YN` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_DSCNTC_RSN_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MM_FDRM_MBER_SPNSR_DSCNTC</b> — 9컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_DSCNTC_DE` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SER_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `DSCNTC_RSN_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DSCNTC_PATH` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `REGIST_DEPT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MM_ONCE_MBER_INFO</b> — 22컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `ONCE_MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SEX` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `TSTM_DIV_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ETC_TSTM_DIV_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ENTRPS_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `HMPG_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PSTMTR_RECPTN_YN` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EMAIL_RECPTN_YN` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHRCTR_RECPTN_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FDRM_MBER_TRNSFER_FG` | BOOLEAN | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPECL_MNG_CD1` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPECL_MNG_CD2` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TNI_CU_BL_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CTI_SYNCHRN_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `REGIST_DEPT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MS_CRMN</b> — 35컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `CRMN_CD` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CRMN_DIV_CD` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CRMN_TIT` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CRMN_PLACE_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BRNCH_DEPT_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `ATCHFL_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SITE_URL` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRMN_STRT_DE` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CRMN_END_DE` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CRMN_PART_STRT_DE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRMN_PART_END_DE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TAT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RCRIT_PSNNL_CO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `RESRCE_SRVC_FG` | BOOLEAN | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `ENTRPS_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRMN_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `PART_USE_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TMPLAT_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TMPLAT_TIT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TMPLAT_PART_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TMPLAT_PART_TIT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SRVY` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RM2` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PROMO_CODE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TMPLAT_WIN_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TMPLAT_WIN_TIT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MS_EMAIL_SNDNG</b> — 16컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SNDNG_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_CD_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_DTL_CD_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_STDR_DE` | TIMESTAMP_NTZ | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_TY_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `TIT` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `EMAIL_RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PRCS_DE` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PCPSN_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PRCS_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MS_EMAIL_TMPLAT_MNG</b> — 16컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `TMPLAT_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_CD_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_DTL_CD_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ATMC_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TIT` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `EMAIL_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `WRITNG_DEPT_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `WRITNG_DEPT_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHRG_DEPT_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MS_EVENT</b> — 13컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `EVENT_CD` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EVENT_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `EVENT_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `STRT_DATE` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `END_DATE` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `PRZWIN_PSNNL_CO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PRZWIN_GFT_SNDNG_DE` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MS_MSG_AT_SNDNG</b> — 21컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SNDNG_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_CD_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_DTL_CD_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_STDR_DE` | TIMESTAMP_NTZ | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_TY_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_TIME_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MSG_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TIT` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MSG_AT_RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PRCS_DE` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PCPSN_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ATCHFL_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TMPLAT_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ALTRTV_MSG_SNDNG_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ALTRTV_MSG_ATCHFL_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_MS_PSTMTR_SNDNG</b> — 16컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SNDNG_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_CD_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_DTL_CD_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_STDR_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_TY_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PRCS_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PCPSN_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PRCS_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LQY_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RE_SNDNG_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_PM_DNTN_DTLS</b> — 30컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `DNTN_KEY` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ONCE_MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `ONCE_CMPGN_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ELCTR_SETLE_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SETLE_ENTRPS_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SETLE_CMPNY_ACNT_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MBRFEE_BNKB_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ACNUT_SER_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FNLT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PAYER_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PAY_AMT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `PAY_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `PAY_STAT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PRCS_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `TRNSFER_MBRFEE_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TRNSFER_RSN_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RETUN_DNTN_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RETUN_RSN_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RETUN_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ACMSLT_DEPT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `REGIST_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RGSTR_ID` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `RGSTR_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SPNSR_BSNS_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_PM_MBRFEE_ACMSLT</b> — 57컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `MBRFEE_KEY` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `MBER_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_BSNS_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_BSNS_ID` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `RELATNSP_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `OVSEA_AID_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MBRFEE_MT` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBRFEE_SQNC` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `RQEST_MT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_SQNC` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MBRFEE_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `GFT_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `GFTMNEY_CHILD_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ONCE_CMPGN_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TOGETH_WTDRW_REQUST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TOGETH_WTDRW_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SETLE_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_ENTRPS_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PAYER_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_AMT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `RQEST_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `PAY_AMT` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `PAY_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `PAY_STAT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `PRCS_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ELCTR_SETLE_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SETLE_CMPNY_ACNT_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MBRFEE_BNKB_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ACNUT_SER_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FNLT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `BILLKEY` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_RST_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PRCS_RST_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TRNSFER_REQUST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TRNSFER_MBRFEE_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TRNSFER_DNTN_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TRNSFER_RSN_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RETUN_REQUST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RETUN_MBRFEE_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RETUN_RSN_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `OPERTOR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `OPERTOR_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `OPERT_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `OPERT_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `OPER_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `OPER_RST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_PM_SETLE_INFO</b> — 51컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `SETLE_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `CPR_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `WTDRW_STRT_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `WTDRW_ASMT_SQNC` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `WTDRW_ASMT_SQNC_UPDT_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FNLT_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FNLT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_ENTRPS_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CARD_TRMVT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ACNUT_SER_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PAYER_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CARD_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBTLNUM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ETC_CTTPC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ETC_CTTPC_REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `PAYER_MBER_REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_MTH_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_FILE_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_DATA_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FILE_SIZE` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BILLKEY` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SETLE_STAT_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `RQST_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RCEPT_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APRV_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APRV_REQUST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APRV_RST_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_BEGIN_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_EXCL_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_EXCL_STRT_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RQEST_EXCL_END_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPLCNT_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPLCNT_MBTLNUM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPLCNT_ETC_CTTPC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPLCNT_ETC_CTTPC_REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APPLCNT_MBER_REL_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BF_SETLE_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `OPERT_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CRTFC_TY_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `USE_YN` | TEXT | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDUSR_NM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_RM_BPLC_MNG</b> — 20컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `BPLC_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `NATION_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BPLC_KORNM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BPLC_ENGNM` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BSNS_STRT_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BSNS_END_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RELATNSP_BSNS_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RELATNSP_BSNS_DSCNTC_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `GFTMNEY_PSBL_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LETTER_PSBL_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BPLC_DC` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `WTWK_FROM_DSTNC` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CNCSN_RSN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BPLC_MTCHG_MNG_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_UPDUSR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LAST_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_RM_CHILD_MSTR_INFO</b> — 15컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `CHILD_CD` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `CHILD_NO` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `BPLC_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SEX` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `RELATNSP_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHILD_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHILD_DTL_STAT_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `REGIST_DIV_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DT` | TIMESTAMP_NTZ | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `LAST_REGIST_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RE_UPDT_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `MNYRS_NATION_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CMS_CHILD_NO` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_RM_RELATNSP_CHG_INFO</b> — 9컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `RELATNSP_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `CHG_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHG_RSN_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHG_RST_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHG_PERSON_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHG_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHG_RELATNSP_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_RM_RELATNSP_GFTMNEY_INFO</b> — 20컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `RELATNSP_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `MNG_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MBRFEE_KEY` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `SETLE_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SETLE_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SETLE_BANK_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `GFTMNEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `GFT_DIV_CD` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `KOREAN_RM_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ENGL_RM_CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `SNDNG_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `EHGT` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `GFTMNEY_DOLLAR_AMT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `APRV_DE` | DATE | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `UNREPLY_RSN_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TRNSFER_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TRNSFER_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `TRNSFER_AFTER_RELATNSP_KEY` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_RM_RELATNSP_LETTER_INFO</b> — 16컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `RELATNSP_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `MNG_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `LETTER_DIV_CD` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `CTNT` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `RCEPT_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `SNDNG_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `ONLINE_POST_WRITNG_YN` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DE` | DATE | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `EXCEL_SER_NO` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `UNREPLY_RSN_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LANG_CD` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ONLINE_INFLOW_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `LETTER_STAT_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

<details><summary><b>TM_RM_RELATNSP_MSTR_INFO</b> — 13컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `RELATNSP_KEY` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SPNSR_BSNS_NO` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `CHILD_CD` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `RELATNSP_STRT_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `RELATNSP_DSCNTC_DE` | DATE | SILVER까지만 | 높음 | GOLD 미승격 |
| `RELATNSP_DSCNTC_YN` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `RELATNSP_DSCNTC_RSN_CD` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_RGSTR_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `FRST_REGIST_DE` | DATE | 제외(PII·본문·메타) | — | 패턴 매칭 제외(감사 범위 외) |
| `MBER_NO` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `_LOAD_DT` | TIMESTAMP_NTZ | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `_BATCH_ID` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

### ERP (62컬럼)

<details><summary><b>BDGT_ACMSLT_LEDGER</b> — 62컬럼 (GOLD 0 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `YEAR` | TEXT | 대체노출(파생) | 높음 | DATE 파생(YEAR(AD_DATE)) 로 대체 — 텍스트 파싱 금지 원칙 |
| `INCOME_EXPS_DIV_NM` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `BDGT_UNIT_NM` | TEXT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `JANG_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `KWAN_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `HANG_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `MOK_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `DTL_ITEM_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `SUBDTL_ITEM_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `FUND_SOURCE_NM` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `YEAR_BDGT_TOT_AMT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `CHN_BDGT_TOT_AMT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ADJ_BDGT_TOT_AMT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `EXEC_TOT_AMT` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `YEAR_BDGT_AMT_1` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_1` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_1` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_1` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_2` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_2` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_2` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_2` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_3` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_3` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_3` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_3` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_4` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_4` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_4` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_4` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_5` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_5` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_5` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_5` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_6` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_6` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_6` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_6` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_7` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_7` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_7` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_7` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_8` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_8` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_8` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_8` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_9` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_9` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_9` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_9` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_10` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_10` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_10` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_10` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_11` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_11` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_11` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_11` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `YEAR_BDGT_AMT_12` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `CHN_BDGT_AMT_12` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `ADJ_BDGT_AMT_12` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `EXEC_AMT_12` | NUMBER | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |

</details>

### GA4 (30컬럼)

<details><summary><b>events_20260501</b> — 30컬럼 (GOLD 4 · 하드코딩 0)</summary>

| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |
|---|---|---|---|---|
| `event_date` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `event_timestamp` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `event_name` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `GA_EVENT_SK` (FACT_GA_BEHAVIOR.sql) |
| `event_params` | VARIANT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `event_previous_timestamp` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `event_value_in_usd` | FLOAT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `event_bundle_sequence_id` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `event_server_timestamp_offset` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `user_id` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `user_pseudo_id` | TEXT | SILVER까지만 | 높음 | GOLD 미승격 |
| `privacy_info` | VARIANT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `user_properties` | VARIANT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `user_first_touch_timestamp` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `user_ltv` | VARIANT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `device` | VARIANT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `DEVICE_SK` (FACT_GA_BEHAVIOR.sql) |
| `geo` | VARIANT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `app_info` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `traffic_source` | VARIANT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `GA_SOURCE_SK` (FACT_GA_BEHAVIOR.sql) |
| `stream_id` | TEXT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `platform` | TEXT | 노출됨(GOLD) | 높음 | 개명 적재 → GOLD `DEVICE_SK` (FACT_GA_BEHAVIOR.sql) |
| `event_dimensions` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `ecommerce` | VARIANT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `items` | VARIANT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `collected_traffic_source` | VARIANT | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `is_active_user` | BOOLEAN | SILVER까지만 | 높음 | GOLD 미승격 |
| `batch_event_index` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `batch_page_id` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |
| `batch_ordering_id` | NUMBER | SILVER까지만 | 높음 | GOLD 미승격 |
| `session_traffic_source_last_click` | VARIANT | SILVER까지만 | 중간(SQL참조) | SILVER SQL 토큰 참조 |
| `publisher` | NUMBER | 미노출(검토대상) | 낮음(이름기반·P13) | 개명·VARIANT param 승격 가능성 — 확정 아님 |

</details>

---

## 관련 문서

- `03_top-down_gold/05_필드 인벤토리.md` — 지표↔GOLD 필드 정본(P12)
- `03_top-down_gold/11_BRONZE적재 컬럼대조.md` — **CRM 전용·역방향**(원천요청서 대비 BRONZE 적재 확인). 본 감사는 **전 원천·순방향**(BRONZE→GOLD 노출)으로 범위·방향이 다르며 상호 보완 관계.
- `20_issue/10_진단_원인분석.md` §8-I — 본 감사 기반 진단

_감사일 2026-07-28 · Co-authored with CoCo_