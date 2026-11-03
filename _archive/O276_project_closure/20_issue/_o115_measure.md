# O115 실측 근거 (판정 전 기록 · `R1-3-7-c`)

> 세션 = `O115` (2026-08-29) · 라벨 선점 = 원장 §1 상태 대시보드
> 목적 = `99_NEXT §0-UUU ▣UUU3` 「재측정 대기 6건」의 근거를 **판정보다 먼저** 파일에 남긴다.
> 🔴 이 파일은 임시 근거철이다. 정본은 원장 §1 · `01_세션이력` · `99_NEXT` 다.

---

## 0. 컴퓨트 생존 판정 (선행조건)

🔴 판정법 = **스캔 강제 쿼리**(`SUM(<숫자컬럼>)`).
`COUNT(*)` · `CURRENT_TIMESTAMP()` 성공은 근거로 쓰지 않는다(`▣UUU8 ㉡` 실사고).

```sql
SELECT SUM(YEAR_BDGT_TOT_AMT) AS YEAR_SUM,
       SUM(EXEC_TOT_AMT)      AS EXEC_SUM,
       COUNT(DISTINCT BDGT_PRCD_NM) AS PRCD_N
FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER;
```

| 항목 | 값 |
|---|---|
| `YEAR_SUM` | 106,085,664,326 |
| `EXEC_SUM` | 99,006,005,048 |
| `PRCD_N` | 2 |

🟢 **판정 = 컴퓨트 살아 있다.** 근거 = 스캔 강제 집계가 값을 돌려주었고
`YEAR_SUM` 이 `▣UUU6 ①` 기재 「전체 ₩106,085,664,326」과 **일치**한다(교차 검증).
⚠️ `SUM(1)` 은 메타데이터로 최적화될 수 있어 판정에 쓰지 않았다(1차 시도 폐기).

---

## 1. ㉠ `SILVER.BIGQUERY_REFINED_DATA` — `not_null`(error) 3컬럼 NULL 수

```sql
SELECT COUNT(*) AS TOTAL_ROWS,
       COUNT_IF(USER_PSEUDO_ID  IS NULL) AS NULL_USER_PSEUDO_ID,
       COUNT_IF(EVENT_TIMESTAMP IS NULL) AS NULL_EVENT_TIMESTAMP,
       COUNT_IF(EVENT_NAME      IS NULL) AS NULL_EVENT_NAME,
       COUNT_IF(EVENT_DATE      IS NULL) AS NULL_EVENT_DATE,
       MIN(EVENT_DATE) AS MIN_EVENT_DATE,
       MAX(EVENT_DATE) AS MAX_EVENT_DATE,
       COUNT(DISTINCT EVENT_DATE) AS DISTINCT_EVENT_DATE
FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA;
```

| 항목 | 값 |
|---|---|
| `TOTAL_ROWS` | 285,387,172 |
| `NULL_USER_PSEUDO_ID` | **111** |
| `NULL_EVENT_TIMESTAMP` | **0** |
| `NULL_EVENT_NAME` | **0** |
| `NULL_EVENT_DATE` | 0 |
| `MIN_EVENT_DATE` | 20240101 |
| `MAX_EVENT_DATE` | 20260630 |
| `DISTINCT_EVENT_DATE` | 910 |

🟢 `TOTAL_ROWS` 가 `▣UUU3` 표의 `SILVER` 285,387,172 와 **일치**(적재 정합 교차 검증).

### 1-1. 그 111건이 기지 창 안인가 (판정의 핵심)

```sql
SELECT EVENT_DATE, COUNT(*) AS NULL_ROWS
FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
WHERE USER_PSEUDO_ID IS NULL
GROUP BY EVENT_DATE ORDER BY EVENT_DATE;
```

| `EVENT_DATE` | `NULL_ROWS` |
|---|---|
| 20240605 | 12 |
| 20240606 | 30 |
| 20240607 | 41 |
| 20240608 | 11 |
| 20240609 | 6 |
| 20240610 | 11 |
| **합** | **111** |

🟢 **반환 행 6건 = 전부 `20240605`~`20240610`.** 창 밖 날짜는 **0건**이다
(그룹 결과에 창 밖 값이 존재하지 않는다 = 분모 전체를 본 판정이다).
⇒ ㉠ 의 질문(「창 밖 NULL 이 있는가」)에 대한 답 = **없다**.

🔴 그러나 이것이 「build 가 통과한다」를 뜻하지 않는다 — 판정은
**그 `not_null` 이 걸린 대상이 원천이냐 파생이냐**에 달렸다(§4 에서 dbt 정본으로 확인한다).

---

## 2. ㉢ 3키 중복률

```sql
WITH K AS (
  SELECT USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, COUNT(*) AS N
  FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA GROUP BY 1,2,3
)
SELECT SUM(N), COUNT(*), SUM(N)-COUNT(*),
       ROUND(100.0*(SUM(N)-COUNT(*))/SUM(N),4), COUNT_IF(N>1), MAX(N)
FROM K;
```

| 항목 | 값 |
|---|---|
| 총 행수 | 285,387,172 |
| 고유 3키 | 261,506,057 |
| 초과 행 | 23,881,115 |
| **중복률** | **8.3680 %** |
| 중복 보유 키 | 17,252,545 |
| 키당 최대 행수 | **48** |

🔴 기재 **8.66 %** 는 구 계정·2025-06 값이다 ⇒ **인용 금지**(`▣UUU3 ㉢`).
🟢 이 계정 현행값 = **8.3680 %**.

---

## 3. ㉣ `ML.ML_RST_DATA_*` 의 `DISTINCT STDR_MT`

컬럼 실재 = `INFORMATION_SCHEMA.COLUMNS` 로 확인 — **16테이블 전부 `STDR_MT` 보유**
(추가로 `ML_RST_DATA_SPNSR_CHURN_12M` 만 `STDR_MT_SPNSR_AMT`(NUMBER)를 별도 보유).

| 테이블 | `N_MT` | `MIN_MT` | `MAX_MT` | 행수 |
|---|---|---|---|---|
| `ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION` | 1 | 202606 | 202606 | 11 |
| `ML_RST_DATA_CMPGN_CTGR_AMT` | 1 | 202606 | 202606 | 660 |
| `ML_RST_DATA_CMPGN_LTV` | 1 | 202606 | 202606 | 600 |
| `ML_RST_DATA_CMPGN_LTV_SCORE` | 1 | 202606 | 202606 | 50 |
| `ML_RST_DATA_DVLP_INC_CONTRIBUTION` | 1 | 202606 | 202606 | 11 |
| `ML_RST_DATA_LOYAL_MBER` | 1 | 202606 | 202606 | 29,471 |
| `ML_RST_DATA_MBER_CHURN_12M` | 1 | 202606 | 202606 | 91,423 |
| `ML_RST_DATA_MBER_INC_12M` | 1 | 202606 | 202606 | 91,423 |
| `ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT` | 1 | 202606 | 202606 | 1,200 |
| `ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT` | 1 | 202606 | 202606 | 360 |
| `ML_RST_DATA_MONTHLY_DVLP_AMT` | 1 | 202606 | 202606 | 12 |
| `ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT` | 1 | 202606 | 202606 | 24 |
| `ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT` | 1 | 202606 | 202606 | 228 |
| `ML_RST_DATA_SPNSR_CHURN_12M` | 1 | 202606 | 202606 | 829,609 |
| `ML_RST_DATA_UCMPGN_LTV` | 1 | 202606 | 202606 | 600 |
| `ML_RST_DATA_UCMPGN_LTV_SCORE` | 1 | 202606 | 202606 | 50 |

🟢 **16/16 이 단일 기준월 `202606`** ⇒ SV·Agent 에서 **기준월 고정이 현재는 불필요**하다.
🔴 그러나 이것은 **「지금 1개월치만 들어와 있다」는 뜻**이다 —
2개월째가 입고되면 `▣UUU3 ㉣` 의 우려(같은 미래월 중복 계상)가 **그때 발생한다**
⇒ 🟢 처방 = 「단일이므로 불요」로 닫지 말고 **「입고 월수 = 1 인 동안만 불요」로 조건부 기록**한다.
행수 합 = 1,045,732 로 `▣UUU3` `ML` 총계와 **일치**.

---

## 4. ㉤ 테이블 단위 행수 (스키마 단위 → 테이블 단위 승격)

정본 대조 대상 = `50_handoff/01` §6.2. 아래는 `INFORMATION_SCHEMA.TABLES` 실측
(`TABLE_TYPE='BASE TABLE'` · 반환 148행 = AGENCY 4 + CRM 46 + ERP 2 + GOLD 37 + ML 16 + SILVER 43).

### 4-1. `BRONZE_AGENCY` (4 · 합 255,434)

| 테이블 | 행수 |
|---|---|
| `DGT_AD_CMPGN_DTLS` | 216,085 |
| `REBRDC_AD_CMPGN_DTLS` | 2,113 |
| `SYNC_ERR_INFO` | 17 |
| `VIDEO_AD_CMPGN_DTLS` | 37,219 |

### 4-2. `BRONZE_ERP` (2 · 합 25,180)

| 테이블 | 행수 |
|---|---|
| `BDGT_ACMSLT_LEDGER` | 247 |
| `EXPENSE_RESOLUTION` | 24,933 |

### 4-3. `BRONZE_CRM` (46 · 합 115,871,773)

| 테이블 | 행수 |
|---|---|
| `SND_MEMBER_LIST` | 8,296,794 |
| `SND_REQ_MST` | 1,707 |
| `TC_CMMN_CD` | 339 |
| `TC_CMMN_DTL_CD` | 5,853 |
| `TD_MS_AT_TMPLAT_BTN_LIST` | 5,551 |
| `TD_MS_CRMN_PRTCPNT` | 152,132 |
| `TD_MS_EMAIL_LQY_SNDNG` | 497,777 |
| `TD_MS_EMAIL_SNDNG_DTLS` | 7,811,125 |
| `TD_MS_EVENT_PRTCPNT_DTL` | 983,971 |
| `TD_MS_MSG_AT_LQY_SNDNG` | 1,113,284 |
| `TD_MS_MSG_AT_SNDNG_DTLS` | 20,561,448 |
| `TD_MS_PSTMTR_LQY_SNDNG` | 2,022 |
| `TD_MS_PSTMTR_SNDNG_DTL` | 1,798,680 |
| `TH_MM_FDRM_MBER_STNG_DTLS` | 7,501,761 |
| `TH_PM_SETLE_INFO_HIST` | 1,065,053 |
| `TM_CM_BRND_MNG` | 103 |
| `TM_CM_CMPGN_MNG` | 36,163 |
| `TM_CM_DEPT_INFO` | 1,314 |
| `TM_CM_MBER_DVLP_GOAL` | 25,344 |
| `TM_CM_MKTNG_CMPGN_MNG` | 394 |
| `TM_CM_MKTNG_UTM` | **191** (신규) |
| `TM_CM_SPNSR_BSNS_INFO` | 50 |
| `TM_MM_FDRM_MBER_DVLP_AMT` | 3,594,843 |
| `TM_MM_FDRM_MBER_INFO` | 1,587,343 |
| `TM_MM_FDRM_MBER_IRSD` | 324,947 |
| `TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT` | 1,134,848 |
| `TM_MM_FDRM_MBER_RE_SPNSR` | 115,254 |
| `TM_MM_FDRM_MBER_SPNSR` | 2,228,064 |
| `TM_MM_FDRM_MBER_SPNSR_BSNS` | 2,170,572 |
| `TM_MM_FDRM_MBER_SPNSR_DSCNTC` | 1,038,262 |
| `TM_MM_ONCE_MBER_INFO` | 175,722 |
| `TM_MS_CRMN` | 3,410 |
| `TM_MS_EMAIL_SNDNG` | 498,639 |
| `TM_MS_EMAIL_TMPLAT_MNG` | 446 |
| `TM_MS_EVENT` | 376 |
| `TM_MS_MSG_AT_SNDNG` | 1,110,250 |
| `TM_MS_PSTMTR_SNDNG` | 3,801 |
| `TM_PM_DNTN_DTLS` | 1,130,252 |
| `TM_PM_MBRFEE_ACMSLT` | 46,391,620 |
| `TM_PM_SETLE_INFO` | 2,545,696 |
| `TM_RM_BPLC_MNG` | 377 |
| `TM_RM_CHILD_MSTR_INFO` | 508,051 |
| `TM_RM_RELATNSP_CHG_INFO` | 197,061 |
| `TM_RM_RELATNSP_GFTMNEY_INFO` | 180,664 |
| `TM_RM_RELATNSP_LETTER_INFO` | 207,609 |
| `TM_RM_RELATNSP_MSTR_INFO` | 862,610 |

🟢 `TM_MM_ONCE_MBER_INFO` **175,722** 는 `R2-7-2` 의 일시회원 175,722행과 **일치**
(그 조문의 분모가 이 계정에서도 성립한다는 교차 검증).

### 4-4. `ML` (16) · `SILVER` (43) · `GOLD` (37)

`ML` 테이블 단위 = §3 표와 동일(행수 열).

| 스키마 | 행 있는 테이블 | 비고 |
|---|---|---|
| `SILVER` | **1** = `BIGQUERY_REFINED_DATA` 285,387,172 (25,508,568,576 B) | 파생 **42 테이블 전부 0행** |
| `GOLD` | **0** | 37 테이블 전부 0행 |

🔴 ⇒ **dbt 는 아직 한 번도 성공 실행되지 않았다**(`▣UUU3` 판정과 일치).

---

## 5. ㉥ `EXPENSE_RESOLUTION` ↔ 예산 원장 관계 재확인

공유 축 실측 = `INFORMATION_SCHEMA.COLUMNS` 전수 대조.
· 공유 6키 = `BDGT_UNIT_NM`·`MOK_NM`·`DTL_ITEM_NM`·`SUBDTL_ITEM_NM`·`FUND_SOURCE_NM`·`BDGT_ITEM_NM`
· 🔴 지출결의에 **없는** 원장 축 = `INCOME_EXPS_DIV_NM`·`BDGT_PRCD_NM`·`JANG_NM`·`KWAN_NM`·`HANG_NM`·`DVLP_INBOUND_PATH`

| 항목 | O115 실측 | `▣UUU7` 기재 | 대조 |
|---|---|---|---|
| 지출결의 행수 | 24,933 | 24,933 | 🟢 일치 |
| 지출결의 `SUM_AMT` | 110,291,190,623 | 110,291,190,623 | 🟢 일치 |
| 원장 2026 `EXEC_TOT_AMT` | 11,183,088,258 | 11,183,088,258 | 🟢 일치 |
| 배수 | 9.86배 | 약 9.9배 | 🟢 일치 |
| 과목 6키 고유 — 지출결의 / 원장 2026 | 2,272 / 69 | 2,272 / 69 | 🟢 일치 |
| 일치 행 / 금액 | 5행 / ₩52,500 (0.02%) | 5행 / ₩52,500 (0.02%) | 🟢 일치 |
| `RESOLUTION_DEPT_NM` 고유 | 52 | 52 | 🟢 일치 |
| `RESOLUTION_NO` 고유 | 18,063 | 18,063 | 🟢 일치 |
| `WRITE_DATE` 범위 | 2026-01-01 ~ 2026-07-22 | 동일 | 🟢 일치 |
| 지출결의 `YEAR` 고유 | **1** (2026만) | 미기재 | 🆕 신규 |

🟢 **판정 = `▣UUU7` 결론 유지.** 조인 근거 0.02% ⇒ **별도 팩트로 두고 관계 정의는 현업 회신 후.**
🔴 관계를 창작해 조인·합산하면 재무 오귀속이다. **이 세션도 조인하지 않았다.**
🆕 신규 사실 = 지출결의는 **2026 단일 연도**다(원장은 3개 연도) ⇒ 기간 범위 상이가
`▣UUU7` 의 원인 후보 `㉢` 를 **강화**한다(단 `㉠`·`㉡` 를 배제하지는 못한다).

---

## 6. 🔴🔴 `DEC-44` 선행조건에 직결하는 신규 실측 — 「추가경정은 증분인가 재작성인가」

> 🔴 이 절은 **결정을 내리지 않는다**(`DEC-44 §30-B` 는 현업 소관).
> 🟢 다만 **답을 강하게 제약하는 데이터 근거**를 기록한다. 키는 고치지 않았다.

### 6-1. 원장은 3개 연도다 (신규 발견 — 종전 기재에 없던 축)

```sql
SELECT YEAR, BDGT_PRCD_NM, INCOME_EXPS_DIV_NM, COUNT(*) ROWS_N,
       SUM(YEAR_BDGT_TOT_AMT), SUM(EXEC_TOT_AMT),
       SUM(CHN_BDGT_TOT_AMT), SUM(ADJ_BDGT_TOT_AMT)
FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER GROUP BY 1,2,3;
```

| `YEAR` | 차수 | 수입지출 | 행수 | `YEAR_BDGT_TOT_AMT` | `EXEC_TOT_AMT` | `CHN` | `ADJ` |
|---|---|---|---|---|---|---|---|
| 2024 | 연사업 | 지출 | 75 | 18,619,714,000 | **20,305,865,222** | 0 | 0 |
| 2024 | 추가경정 | 지출 | 33 | 20,494,617,158 | **20,305,865,222** | 0 | 0 |
| 2025 | 연사업 | 지출 | 54 | 22,263,342,000 | **23,605,593,173** | 0 | 0 |
| 2025 | 추가경정 | 지출 | 16 | 23,490,801,247 | **23,605,593,173** | 0 | 0 |
| 2026 | 연사업 | 지출 | 69 | 21,217,189,921 | 11,183,088,258 | 0 | 0 |

🟢 교차 검증 = 행수 합 247 · 연사업 198 · 추가경정 49 · 연사업 편성 62,100,245,921 ·
추가경정 편성 43,985,418,405 — **`▣UUU6` 기재와 전건 일치**.
🟢 `CHN`·`ADJ` 는 5개 군 **전건 0** — `▣UUU6 ②` 확인.
🆕 **`INCOME_EXPS_DIV_NM` 은 `지출` 단일값**이다(수입 편성 행이 원장에 없다).
🆕 **2026 에는 추가경정 행이 아직 없다.**

### 6-2. 🔴🔴 집행액이 차수 간 완전히 중복된다 (판정의 핵심)

같은 연도에서 `EXEC_TOT_AMT` **합계가 연사업 = 추가경정으로 완전 동일**하다(위 표).
과목 그리드는 서로 다르다(10키 완전일치 쌍 = 2025 **1건** · 2024 **0건** · `MOK_NM` 고유 11→6).
⇒ 「같은 과목을 다시 쓴 것」이 아니라 **「같은 실적을 다른 과목 그리드로 다시 쓴 것」**이다.

비영 집행액을 **다중집합**으로 비교했다(값 + 중복도):

```sql
WITH NZ AS (SELECT YEAR, BDGT_PRCD_NM, EXEC_TOT_AMT, COUNT(*) C
            FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER
            WHERE EXEC_TOT_AMT <> 0 AND YEAR IN ('2024','2025') GROUP BY 1,2,3)
-- 연사업(A) FULL OUTER JOIN 추가경정(B) ON (YEAR, EXEC_TOT_AMT)
```

| `YEAR` | 합집합 금액종 | 추가경정에만 | 연사업에만 | 중복도 동일 | 중복도 상이 |
|---|---|---|---|---|---|
| 2024 | 29 | **0** | **0** | **29** | **0** |
| 2025 | 15 | **0** | **0** | **15** | **0** |

🔴🔴 **비영 집행액 다중집합이 차수 간 완전 동일하다**(편차 0). 보조 근거 =
비영 행수도 같다(2024 = 75−46 = 29 ↔ 33−4 = 29 · 2025 = 54−39 = 15 ↔ 16−1 = 15).

⇒ 🔴🔴 **`추가경정` 행은 같은 연도의 집행 실적을 「재작성」한 것이고 「증분」이 아니다.**
증분이라면 집행액이 중복될 이유가 없다(증분의 집행은 증분분만이어야 한다).
⇒ 🔴🔴 **`SUM(EXEC_TOT_AMT)` 을 차수에 걸쳐 하면 2024·2025 집행이 정확히 2배 계상된다.**
실측 = 원장 전체 `SUM(EXEC_TOT_AMT)` **99,006,005,048** ↔
연도별 중복 제거 시 **55,094,546,653**(= 20,305,865,222 + 23,605,593,173 + 11,183,088,258).
🟢 그 **55,094,546,653** 이 `▣UUU6 ③` 의 「집행 `연사업` 55,094,546,653」과 **일치**하고,
`43,911,458,395`(같은 절의 「추가경정」)은 **2026 을 뺀 값**(55,094,546,653 − 11,183,088,258)이다
⇒ ③ 의 두 수치는 **서로 다른 집행이 아니라 같은 집행의 부분집합**이었다.

🟢 **편성 축도 같은 방향을 가리킨다** — 2024 편성이 18,619,714,000 → 20,494,617,158 로
**소폭 증가**했다(차액 1,874,903,158). 증분이라면 추가경정 행의 값이 **차액**이어야 하는데
실제 값은 **연 총액 규모**다 ⇒ 「추경 반영 후 연 편성 총액의 재작성」으로 읽힌다.

### 6-3. 🔴 이 실측이 `DEC-44` 에 주는 함의 (결정은 하지 않는다)

* 🔴 **키에 `BDGT_PRCD_NM` 을 넣는 것만으로는 부족하다.** 키를 넣으면 247행이 유일해져
  `unique` 는 통과하지만, **차수를 걸쳐 `SUM` 하는 소비 질의가 여전히 2배를 낸다.**
  ⇒ 필요한 것은 키 확장 **+ 「어느 차수를 정본으로 볼 것인가」 규칙**이다.
* 🟢 **데이터가 지지하는 방향** = 연도별 **최신 차수 1건만 유효**(재작성 스냅샷) ·
  또는 차수를 **명시적 축으로 노출**하고 기본 집계에서 **최신 차수로 한정**.
* 🔴 **그러나 이것은 현업 회신 사항이다**(`DEC-44 §30-B`) — 위는 **데이터 근거**이고
  회계 정책이 아니다. 🔴 **키를 고치지 않았다**(사용자 지시 이행).
* 🟢 **`▣UUU6 ③` 의 「37% 미배분」 판정은 이 발견으로 재해석이 필요하다** —
  월합 66,971,333,168 이 어느 차수 집합의 월합인지에 따라 분모가 달라진다(§7 에서 다룬다).

---

## 7. 🔴🔴 dbt 정본 대조에서 나온 신규 결함 2건 (`▣UUU6 ③` 재작성 대상)

### 7-1. 「집행은 연=월 정합」은 **행 단위로만 참**이고 **합계는 안전하지 않다**

정본 인용(원문 그대로) — `models/gold/_gold_ready_schema.yml:674`:
> `- name: EXEC_BUDGET_YEAR`
> `description: "연 집행. 🟢 원천에서 연 총액 = 월 12컬럼 합계로 **정합**이 확인된 유일한 측정치다."`

같은 파일 `:667` (`PLAN_BUDGET_YEAR` 설명):
> `🟢 반면 **집행은 연=월 정합**이다(EXEC_BUDGET_YEAR ↔ FACT_BUDGET.EXEC_BUDGET_ERP 월합).`

🟢 **그 「연=월 정합」 자체는 참이다** — 실측 `ROWS_YEAR_NE_MONTH_EXEC` = **0**
(247행 전건에서 `EXEC_TOT_AMT` = 월 12컬럼 합).

🔴🔴 **그러나 그 문구는 「그러므로 이 측정치는 안전하다」로 읽힌다 — 그것이 틀렸다.**
정합은 **행 축**의 성질이고, 위험은 **행 집합 축**(차수 중복)에 있다.
⇒ 이것이 `R3-9 ㉢`(「판정 문구가 세는 것과 사람이 읽는 뜻이 다르다」)의 실물이다.

| 측정 | as-is 합계 | 차수 중복 제거(연사업만) | 과대 |
|---|---|---|---|
| `FACT_BUDGET_YEARLY.EXEC_BUDGET_YEAR` | 99,006,005,048 | 55,094,546,653 | **+79.7 %** |
| `FACT_BUDGET` 월 집행 12컬럼 합 | 99,006,005,048 | 55,094,546,653 | **+79.7 %** |
| `FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR` | 106,085,664,326 | 62,100,245,921 | **+70.8 %** |

🔴 두 팩트가 **같은 값으로 같이 틀린다**(99,006,005,048 동일) ⇒
「월 팩트로 교차검증했다」가 **오류를 잡지 못한다**(둘의 오류 원인이 동일하다).
🔴 **가장 「안전하다」고 표시된 측정치가 가장 크게 부푼다**(+79.7%) — 문안이 경계를 낮춘다.

### 7-2. 「월 편성 37% 미배분」은 **연도 국소 결손**이었다 (분모 오해)

```sql
SELECT YEAR, BDGT_PRCD_NM,
       SUM(YEAR_BDGT_TOT_AMT) PLAN_YEAR_TOT,
       SUM(COALESCE(YEAR_BDGT_AMT_1,0)+…+COALESCE(YEAR_BDGT_AMT_12,0)) PLAN_MONTH_SUM,
       SUM(EXEC_TOT_AMT) EXEC_YEAR_TOT,
       SUM(COALESCE(EXEC_AMT_1,0)+…+COALESCE(EXEC_AMT_12,0)) EXEC_MONTH_SUM
FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER
WHERE INCOME_EXPS_DIV_NM <> 'TOTAL' GROUP BY 1,2;
```

| `YEAR` | 차수 | `PLAN_YEAR_TOT` | `PLAN_MONTH_SUM` | 편성 정합 | `EXEC_YEAR_TOT` | `EXEC_MONTH_SUM` | 집행 정합 |
|---|---|---|---|---|---|---|---|
| 2024 | 연사업 | 18,619,714,000 | **0** | 🔴 **0 %** | 20,305,865,222 | 20,305,865,222 | 🟢 |
| 2024 | 추가경정 | 20,494,617,158 | **0** | 🔴 **0 %** | 20,305,865,222 | 20,305,865,222 | 🟢 |
| 2025 | 연사업 | 22,263,342,000 | 22,263,342,000 | 🟢 **100 %** | 23,605,593,173 | 23,605,593,173 | 🟢 |
| 2025 | 추가경정 | 23,490,801,247 | 23,490,801,247 | 🟢 **100 %** | 23,605,593,173 | 23,605,593,173 | 🟢 |
| 2026 | 연사업 | 21,217,189,921 | 21,217,189,921 | 🟢 **100 %** | 11,183,088,258 | 11,183,088,258 | 🟢 |

🔴🔴 **정확한 진단 = 「2024 연도 행에 월 편성 배분이 전무하고 2025·2026 은 완전 정합」이다.**
🔴 **「37 % 미배분」은 진단이 아니라 평균의 산물이다** — 0 %(2024)와 100 %(2025·2026)를
**차수 중복이 남은 분모**에서 평균한 값이다. 교차 검증 =
미배분 연사업 62,100,245,921 − 43,480,531,921 = **18,619,714,000 = 2024 연사업 연총액 그 자체** ·
추가경정 43,985,418,405 − 23,490,801,247 = **20,494,617,158 = 2024 추가경정 연총액 그 자체**.
⇒ 잔차가 **2024 총액과 정확히 같다** = 2024 의 월 배분이 **부분적이 아니라 전무**하다는 뜻이다.

🟢 **소비 안내가 달라진다** — 종전 문안(「원천 월 배분이 부분적」)은 「어느 연도든 월합을 믿지 마라」로
읽히지만, 실제로는 **2025·2026 에서는 월 팩트와 연 팩트가 편성에서 정확히 일치**한다.
⇒ 🟢 처방 = 「연도로 스코프를 좁히면 월 팩트를 편성에도 쓸 수 있다(2025·2026)」 ·
🔴 「2024 는 월 편성이 0 이므로 월 팩트로 2024 편성을 물으면 0 이 돌아온다」.
🔴 후자가 **더 위험한 실패 양태**다 — NULL 이 아니라 **0** 이라 오류로 보이지 않는다.

---

## 8. 브론즈 델타 ↔ SILVER·GOLD·dbt 배선 대조 (사용자 지시 1·2번)

델타 정본 = `99_NEXT §0-TTT ▣TTT1`(브론즈 50 → 52 · `BDGT_ACMSLT_LEDGER` 65 → 67).

| # | 브론즈 변화 | SILVER 설계 | GOLD 설계 | dbt 구성 | 판정 |
|---|---|---|---|---|---|
| ① | `TM_CM_MKTNG_UTM` **신설**(12컬럼 · 191행) | `CRM_CAMPAIGN` 에 `MKTG_UTM`·`MKTG_UTM_NM` | `DIM_CAMPAIGN.MKTG_UTM` · `WIDE_MEMBER_EVENT.CAMPAIGN_MKTG_UTM` | `_sources.yml:84` 선언 + `CRM_CAMPAIGN.sql:83` LEFT JOIN + `_crm_schema.yml:199` + `_wide_schema.yml:322` | 🟢 **정합** |
| ② | `TM_CM_CMPGN_MNG` 34 → **36**(`CMMN_BRND`·`MKTG_UTM`) | `CRM_CAMPAIGN.sql:56~59` 4컬럼(코드+라벨) | `DIM_CAMPAIGN` 전파 | MM297 코드조인 `CRM_CAMPAIGN.sql:77` | 🟢 **정합** |
| ③ | `BDGT_ACMSLT_LEDGER` **`BDGT_PRCD_NM` 신설** | 🔴 **미배선**(3모델 MD5 10컬럼에 없음) | 🔴 **차수 축 없음** | 🟠 yml **3곳에 경고 기재** + singular 3종(`warn`) | 🟠 **의도된 보류**(`DEC-44` 회신 대기) |
| ④ | 같은 표 `DIRECT_MNYRS_YN_1/2` 신설 | 🔴 미배선 | 🔴 미배선 | 참조 **0건** | 🟠 **보류 타당**(원천 문서 미확인 · 창작 금지) |
| ⑤ | 같은 표 `MNYRS_COST_DIV_YN` **삭제** | — | — | 참조 **0건** | 🟢 **파손 없음** |
| ⑥ | `EXPENSE_RESOLUTION` **신설**(16컬럼 · 24,933행) | 🔴 소비 모델 0 | 🔴 팩트 없음 | 🟠 `_sources.yml:143` **선언만** | 🟠 **의도된 보류**(조인 근거 0.02%) |

🟢 **①②⑤ = 설계·dbt 가 모두 갱신됐다.** ③④⑥ = **미배선이지만 그 사실과 이유가 정본에 기재돼 있다**
⇒ 「빠뜨린 것」이 아니라 **「대기로 등재된 것」**이다(구별해서 보고한다 · `▣UUU8 ㉠`).

🔴 **다만 갱신에 실제 누락 2건이 있었다**(§7 · 아래 8-1).

### 8-1. 갱신 누락 실측 2건

| # | 어디 | 무엇이 낡았나 |
|---|---|---|
| `가` | `models/gold/fact/FACT_BUDGET_YEARLY.sql:7` | 🔴 **「🟢 이 팩트는 SUM 이 항상 안전하다 — 1행 = 1(연 × 예산과목)」이 그대로 있다.** yml 3곳(`_gold_ready_schema.yml:639` · `_wide_schema.yml:1071` · `_silver_bridge_schema.yml:110`)은 갱신됐는데 **모델 헤더만 안 됐다** ⇒ 같은 주장을 **두 곳에서 다르게 적는** 상태(`R3-9 ㉡`) |
| `나` | `_gold_ready_schema.yml:667`·`:674` | 🔴 **집행 축을 🟢 로 표시했다** — 행 단위 정합은 참이나 **합계는 +79.7% 과대**다(§7-1). 가장 안전하다고 적힌 측정치가 가장 크게 부푼다 |

🔴 원인은 「게이트가 없어서」가 아니다 — **O114-B 가 편성 축(`PLAN`)만 보고 집행 축(`EXEC`)을
「정합」 신호로 통과시켰다.** `▣UUU8 ㉡`(「성공 신호도 판정식을 의심하라」)의 재발이다.

---

## 9. dbt build 차단 위험 사전 판정 (dbt 미실행 · `R2-1`)

🔴 **에이전트는 dbt 를 실행하지 않는다**(`R4-1`) ⇒ 아래는 **정본 + 라이브 실측으로 계산한 예측**이다.

### 9-1. GA4 축 — `▣UUU3 ㉠㉡` 의 답

정본 인용(원문 그대로) — `models/silver/_sources.yml:64~66`:
> `- not_null:`
> `    config:`
> `      where: "NOT (EVENT_DATE BETWEEN '20240605' AND '20240610')"`

| 테스트 | 대상 | severity | 위반 예측 | 판정 |
|---|---|---|---|---|
| `not_null` | `USER_PSEUDO_ID` | error | **0** | 🟢 통과 — NULL 111건이 **전부 `where` 제외 창 안**(§1-1) |
| `not_null` | `EVENT_TIMESTAMP` | error | **0** | 🟢 통과 — NULL 0 |
| `not_null` | `EVENT_NAME` | error | **0** | 🟢 통과 — NULL 0 |

🔴🔴 **`▣UUU3 ㉠` 의 전제가 낡아 있었다** — 그 항목은 「`not_null` 이 `severity` 미지정(=error)이라
1건이라도 있으면 build 가 멈춘다」고 적었으나, **그 테스트에는 `DEC-40`(2026-08-20)이 붙인
`where` 절이 이미 있다.** ⇒ 🟢 **차단 위험은 처음부터 없었다.**
🟢 그래도 재측정은 헛되지 않았다 — **창 밖 0건**이라는 확증이 그 `where` 의 타당성을 실증한다.
🔴 만약 창 밖에 1건이라도 있었다면 `where` 가 그것을 **감지**했을 것이다(설계 의도대로).

### 9-2. 예산 축 — error 테스트 시뮬레이션 전건

| 시뮬레이션 대상 | 결과 | 판정 |
|---|---|---|
| `ERP_BUDGET_ITEM.BUDGET_ITEM_DK` `unique` | 행 179 · 고유 179 ⇒ 위반 **0** | 🟢 통과 |
| `ERP_BUDGET_ITEM.BUDGET_ITEM_DK` `not_null` | NULL **0** | 🟢 통과 |
| `ERP_BUDGET.BUDGET_ITEM_DK` `not_null` | NULL **0** | 🟢 통과 |
| `ERP_BUDGET.BUDGET_ITEM_DK` `relationships`→`ERP_BUDGET_ITEM` | 고아 **0** | 🟢 통과 |
| `ERP_BUDGET.MONTH_NO` `not_null` + `accepted_values 1~12` | 구성상 1~12 리터럴 | 🟢 통과 |
| `ERP_BUDGET_YEARLY.BUDGET_ITEM_DK` `not_null` + `relationships` | NULL 0 · 고아 0 | 🟢 통과 |
| `ERP_BUDGET_YEARLY.BUDGET_YEAR` `not_null` | `YEAR` = 2024/2025/2026 전건 수치 ⇒ NULL **0** | 🟢 통과 |
| `FACT_BUDGET_YEARLY.BUDGET_ITEM_SK` `relationships`→`DIM_BUDGET_ITEM` | `DIM` = 179 + 센티넬 1 ⇒ 고아 **0** | 🟢 통과 |

🟢 예상 산출 행수 = `ERP_BUDGET` **2,964**(247 × 12) · `ERP_BUDGET_YEARLY` **247** ·
`ERP_BUDGET_ITEM` **179** · `DIM_BUDGET_ITEM` **180**(센티넬 포함) · `FACT_BUDGET_YEARLY` **247**.

🟠 **singular 3종은 WARN 을 낸다 — 그것이 정상이고 진단이다**(`▣UUU6 ④`):
`warn_erp_budget_procedure_merge`(차수 병합 · 예상 위반 키 **44**) ·
`warn_erp_budget_month_grain` · `warn_erp_budget_yearly_grain`(초과 행 **68**).
🔴 **WARN 을 없애려고 테스트를 지우거나 조건을 좁히지 마라.**

### 9-3. 🔴 이 세션이 판정하지 **않은** 축 (범위를 좁힌 사실을 먼저 적는다 · `▣UUU8 ㉠`)

아래는 **측정하지 않았다** ⇒ 「통과한다」고 쓰지 않는다.

| 축 | 왜 판정하지 않았나 |
|---|---|
| CRM 파생 21모델의 error 테스트 전건 | `_crm_schema.yml` 657줄 · 모델 21종 ⇒ 이 세션 예산 밖. 🔴 **브론즈 델타와 무관한 축**이라 우선순위를 낮췄다 |
| AGENCY 8모델 · GA4 파생 6모델 | 같은 사유. 🟠 단 AGENCY 는 `unique` 3종이 error 다 |
| GOLD 37 팩트·차원의 `relationships` 전건 | SILVER 가 0행이라 **현재 상태로는 시뮬레이션이 불가**(하류는 상류 산출에 의존) |
| `assert_ga4_pk_unique.sql` 등 singular 7종 | 🔴 **`assert_*` 접두는 warn 선언이 없으면 error 다** ⇒ 실행 전 검토 대상으로 남긴다 |

🔴 ⇒ **「dbt build 가 통과한다」고 단정하지 않는다.** 이 세션이 단정하는 것은
**「브론즈 델타가 만든 축(GA4 3종 · 예산 8종)에서는 차단이 없다」**로 한정된다.

---

## 10. ⑦ 검증 (07번 A.6 + A.5-B.4) — `▣UUU3 ⑦` 종결

판정 기준(정본 = `▣UUU3` 표 ⑦) = `ITEMS` `PTYPE=ARRAY` · `PREDICTION` `PTYPE=OBJECT` · 거부행 0.
🔴 **선언 타입(`INFORMATION_SCHEMA`)과 런타임 타입(`TYPEOF`)을 둘 다 봤다** — 선언만 보면
「ARRAY 컬럼이니 ARRAY다」라는 순환 검증이 된다(`R3-9 ㉢` 회피).

### 10-1. 선언 타입 (DDL 축)

| 스키마 | 테이블 | 컬럼 | 선언 타입 |
|---|---|---|---|
| `SILVER` | `BIGQUERY_REFINED_DATA` | `ITEMS` | `ARRAY` |
| `ML` | `ML_RST_DATA_LOYAL_MBER` | `PREDICTION` | `VARIANT` |
| `ML` | `ML_RST_DATA_MBER_CHURN_12M` | `PREDICTION` | `VARIANT` |
| `ML` | `ML_RST_DATA_MBER_INC_12M` | `PREDICTION` | `VARIANT` |
| `ML` | `ML_RST_DATA_SPNSR_CHURN_12M` | `PREDICTION` | `VARIANT` |

🟢 반정형 컬럼은 **이 5개가 전부**다(`DATA_TYPE IN ('ARRAY','OBJECT','VARIANT')` 전수 스캔 ·
`INFORMATION_SCHEMA` 자체 컬럼 19건은 시스템 뷰라 대상 밖).

### 10-2. 런타임 타입 (`TYPEOF`) — 판정

| 대상 | `PTYPE` | 행수 | 판정 |
|---|---|---|---|
| `PREDICTION` `ML_RST_DATA_LOYAL_MBER` | `OBJECT` | 29,471 | 🟢 |
| `PREDICTION` `ML_RST_DATA_MBER_CHURN_12M` | `OBJECT` | 91,423 | 🟢 |
| `PREDICTION` `ML_RST_DATA_MBER_INC_12M` | `OBJECT` | 91,423 | 🟢 |
| `PREDICTION` `ML_RST_DATA_SPNSR_CHURN_12M` | `OBJECT` | 829,609 | 🟢 |
| `ITEMS` `BIGQUERY_REFINED_DATA` | `ARRAY` | 13,058,893 | 🟢 |
| `ITEMS` 같은 표 | `None`(SQL NULL) | 272,328,279 | 🟢 정상 |

🟢 **판정 = ⑦ 통과.**
· `PREDICTION` = 4테이블 **전건 `OBJECT`** · **비-OBJECT 0** (그룹 결과에 다른 값이 없다)
· `ITEMS` = 비NULL **전건 `ARRAY`** · **비-ARRAY 비NULL 0** (그룹 결과가 `ARRAY`·`None` 둘뿐)
· **거부행 0** — 스칼라·객체로 잘못 적재된 행이 하나도 없다.
🟢 교차 검증 = `ITEMS` 두 그룹 합 13,058,893 + 272,328,279 = **285,387,172** = 표 총 행수와 일치.

🆕 **신규 사실 = `ITEMS` 는 95.4 % 가 NULL** 이다(272,328,279 / 285,387,172).
🟢 이는 결함이 아니다 — GA4 에서 `items` 는 **전자상거래 이벤트에만** 실린다.
🔴 그러나 **「`ITEMS` 로 상품 분해」 요구가 오면 분모가 4.6 %(13,058,893행)임을 먼저 밝혀야 한다**
⇒ 그 사실을 밝히지 않으면 「전체 대비」로 읽혀 **과소 추정**이 된다.

🔴 **`▣UUU4 ㉣`(`SANDBOX.TOOLS.MIG_LOAD_STAGE` 정리 = `A.7 REMOVE`)의 전제가 이제 충족됐다.**
⚠️ 그러나 `REMOVE` 는 **되돌릴 수 없는 삭제**이므로 `R4-4-3` **별도 승인 대상**이다
⇒ 🔴 **이 세션은 실행하지 않았다.** 승인 시 실행할 것으로 남긴다.



