# O114-B 브론즈 적재 후 SILVER·GOLD 영향 검토 — 라이브 실측 근거

> 🔴 판정 근거 원문 보관용(`R1-3-7-c`). 계정 = 맥락 · 근거 = 조회 결과(`R3-9 ㉤`).
> 측정 시각대 = 2026-08-29 (UTC) · 역할 `ACCOUNTADMIN` · WH `COMPUTE_WH`

## A. 적재 상태 (INFORMATION_SCHEMA)

| 스키마 | 테이블 | 행 있는 테이블 | 총 행수 |
|---|---|---|---|
| `BRONZE_AGENCY` | 4 | 4 | 255,434 |
| `BRONZE_CRM` | 46 | 46 | 115,871,773 |
| `BRONZE_ERP` | 2 | 2 | 25,180 |
| `ML` | 16 | 16 | 1,045,732 |
| `SILVER` | 43 | 1 | 285,387,172 |
| `GOLD` | 37 | 0 | 0 |

⇒ 🟢 브론즈·ML·`SILVER.BIGQUERY_REFINED_DATA` 적재 완료 · 🔴 **dbt 미실행**(SILVER 파생 42 + GOLD 37 = 0행).

신규·변경 테이블 실측 =
`TM_CM_MKTNG_UTM` **191** · `EXPENSE_RESOLUTION` **24,933** ·
`TM_CM_CMPGN_MNG` **36,163** · `BDGT_ACMSLT_LEDGER` **247** ·
`TM_CM_BRND_MNG` 103 · `TM_CM_MKTNG_CMPGN_MNG` 394.

⚠️ **`BDGT_ACMSLT_LEDGER` 는 4,301행(2026-08-12 실측) → 247행**이다.
구조만 바뀐 것이 아니라 **내용 집합 자체가 교체**됐다. 🔴 과거 행수와 대조하지 말 것.

## B. 🔴🔴 결정적 발견 — `BUDGET_ITEM_DK` 가 예산 편성 차수를 뭉갠다

`ERP_BUDGET_ITEM`·`ERP_BUDGET`·`ERP_BUDGET_YEARLY` **3모델이 같은 MD5 10컬럼 키**를 쓴다
(`YEAR`·`INCOME_EXPS_DIV_NM`·`BDGT_UNIT_NM`·`JANG_NM`·`KWAN_NM`·`HANG_NM`·`MOK_NM`·
`DTL_ITEM_NM`·`SUBDTL_ITEM_NM`·`FUND_SOURCE_NM`). 신규 `BDGT_PRCD_NM` 은 **키에 없다**.

키 카디널리티 실측(NULL-safe 연결) =

| 키 구성 | 고유값 |
|---|---|
| 원장 행수 | **247** |
| 현행 10컬럼 | **179** |
| + `BDGT_PRCD_NM` | 221 |
| + `BDGT_ITEM_NM` | 223 |
| + `DVLP_INBOUND_PATH` | **247 (유일)** |

⇒ 🔴 유일 그레인은 **13컬럼**이고 현행 키는 **68행을 뭉갠다**.

충돌 구조 =
`179` 키 중 **44 키가 중복** · 초과 **68행** · **42 키가 `연사업`+`추가경정`을 한 키에 섞는다** ·
섞인 키의 연 편성액 = **₩84,838,474,405** · 키당 최대 **6행**.

차수별 =

| `BDGT_PRCD_NM` | 행 | 연 편성 | 연 집행 | 연도 |
|---|---|---|---|---|
| `연사업` | 198 | 62,100,245,921 | 55,094,546,653 | 2024~2026 |
| `추가경정` | 49 | 43,985,418,405 | 43,911,458,395 | 2024~2025 |

전체 연 편성 = ₩106,085,664,326 ⇒ **섞인 키가 80%(84.8B/106.1B)** 를 차지한다.

🔴 그 결과 `DIM_BUDGET_ITEM` 은 `COALESCE(SUBDTL_ITEM_NM, DTL_ITEM_NM, MOK_NM)` 와
`INCOME_EXPENSE_DIV` **2속성만** 노출하므로 **차수 축이 GOLD 에 존재하지 않는다** ⇒
「추경 얼마?」·「본예산 대비 추경 비율」을 물을 수 없고, 물으면 **합산된 총계 1행**이 돌아온다.
⚠️ 이는 `_wide_schema.yml` 이 `ORG`·`CAMPAIGN` 축에 대해 이미 경고한 것과 **같은 유형의 사고**다
(「조용히 총계 1행」).

## C. 🔴🔴 추경 표현 방식이 「컬럼」에서 「행」으로 바뀌었다

`CHN_BDGT_TOT_AMT`(추경) · `ADJ_BDGT_TOT_AMT`(조정) 실측 =
**247행 전건 `0`**(NULL 0건) · 월 12컬럼 합계도 **`CHN` 0 · `ADJ` 0**.

⇒ 🔴 `FACT_BUDGET_YEARLY.CHN_BUDGET_YEAR`·`ADJ_BUDGET_YEAR` 는 **전건 0 이 된다**.
⇒ 🔴 실제 추경 **₩43,985,418,405** 는 그 컬럼이 아니라
**`BDGT_PRCD_NM='추가경정'` 별도 행의 `YEAR_BDGT_TOT_AMT`** 에 들어 있다.
⇒ 현행 배선은 그것을 `PLAN_BUDGET_YEAR`(연 편성)에 **본예산과 합산**해 넣는다.

🔴 `FACT_BUDGET_YEARLY` 헤더 주석은 **「🟢 이 팩트는 SUM 이 항상 안전하다 — 1행 = 1(연 × 예산과목)」**
이라고 선언한다. **그 불변식이 이 데이터에서 깨졌다**(42 키 × 최대 6행).

## D. ⚠️ 월 편성 합 ≠ 연 편성 총액 (집행은 정합)

| 축 | 연 총액 | 월 12컬럼 합 | 판정 |
|---|---|---|---|
| 편성 `연사업` | 62,100,245,921 | 43,480,531,921 | 🔴 불일치 |
| 편성 `추가경정` | 43,985,418,405 | 23,490,801,247 | 🔴 불일치 |
| 편성 합계 | **106,085,664,326** | **66,971,333,168** | 🔴 **₩39.1B(37%) 미배분** |
| 집행 `연사업` | 55,094,546,653 | 55,094,546,653 | 🟢 일치 |
| 집행 `추가경정` | 43,911,458,395 | 43,911,458,395 | 🟢 일치 |

⇒ `FACT_BUDGET.PLAN_BUDGET_MONTH` 를 12개월 합산해도
`FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR` 와 **맞지 않는다**(원천 특성 · 모델 결함 아님).
🔴 두 팩트가 같은 「편성예산」 개념에 다른 답을 주므로 **소비 안내가 필요**하다.
🟢 집행은 두 축이 정합하므로 `EXEC_BUDGET_ERP` 월합 = `EXEC_BUDGET_YEAR` 이다.

## E. 🟠 그레인 위반을 잡을 테스트가 없다

* `_silver_bridge_schema.yml` = `ERP_BUDGET.BUDGET_ITEM_DK` **`not_null` 만** ·
  `ERP_BUDGET_ITEM.BUDGET_ITEM_DK` **`not_null` 만** ⇒ **`unique` 테스트 부재**.
* `ERP_BUDGET_YEARLY` 는 **스키마 yml 에 항목 자체가 없다** ⇒ 테스트 0건.
* `_gold_ready_schema.yml` 에 **`FACT_BUDGET_YEARLY` 항목이 없다** ⇒ 테스트·COMMENT 0건
  (`FACT_BUDGET` 은 line 619 에 있고 `BUDGET_ITEM_SK` relationships 테스트 보유).

⇒ 🔴 **B·C 의 사고는 dbt build 를 통과한다**(조용한 실패 · `R3-9` 「게이트가 보지 않는 축」).

## F. 🟢 CRM 신규 2컬럼은 이미 배선돼 있다 — 커버리지만 미검증이었다

`CRM_CAMPAIGN.sql` 실측 확인 =
`CMMN_BRND` → `CRM_CODE` **MM297** 조인(line 77) · `CMMN_BRND_NM` 산출(line 57) ·
`MKTG_UTM` → `TM_CM_MKTNG_UTM` 조인(line 83) · `MKTG_UTM_NM` 산출(line 59).
`TM_CM_MKTNG_UTM` 은 `_sources.yml` line 84 에 **선언돼 있다**.

라이브 실측 =

| 항목 | 값 | 판정 |
|---|---|---|
| `TM_CM_CMPGN_MNG` 행 / `CMPGN_CD` 고유 | 36,163 / **36,163** | 🟢 유일 — fan-out 없음 |
| UTM 사전 행 / `TRY_TO_NUMBER(MK_UTM)` 고유 / 비숫자 | 191 / **191** / **0** | 🟢 fan-out 없음 |
| 캠페인 중 `MKTG_UTM` 보유 | 33,978 | — |
| 🔴 **UTM 고아 행 / 고아 코드** | **21,682 / 1종 = `192`** | 🔴 `MKTG_UTM_NM` 63.8% NULL |
| `CMMN_BRND` 고유 / 범위(1~14) 밖 | 14 / **0** | 🟢 `accepted_values` 통과 |
| `TC_CMMN_DTL_CD` MM297 사전 행 | 14 | 🟢 |

⇒ 🟢 **O101 이 「커버리지 미검증」으로 남긴 항목이 실측됐다** — 고아 코드는 정확히 `192` 다
(`20_현업확인_요청.md §N-8` 소관 · 센티넬인지 등재 누락인지 **미확정**).
⇒ 🔴 **`192` 를 NULL 로 정규화하거나 라벨을 창작하지 않는다**(`R2-7-1` · 모델 주석 line 82 와 동일).
⇒ 🟢 테스트 영향 = `MKTG_UTM_NM` `not_null` 은 **`severity: warn`** 이라 **build 를 막지 않는다**
  (21,682행 warn 예상). `CMMN_BRND` `accepted_values` 는 error 기본값이지만 **위반 0** 이다.

## G. 🔴🔴 `EXPENSE_RESOLUTION` — 신규 원천이 아무 모델에도 연결돼 있지 않다

`_sources.yml` `bronze_erp` 는 **`BDGT_ACMSLT_LEDGER` 1개만** 선언한다(line 124)
⇒ `EXPENSE_RESOLUTION` 은 **source 미선언 · 소비 모델 0 · dbt 계보 밖**이다.

구조(16컬럼 · COMMENT 전건 보유) = `YEAR` · `WRITE_DATE`(작성일자) · `RESOLUTION_NO`(결의번호) ·
**`RESOLUTION_DEPT_NM`(결의부서)** · `EXPS_RESOLUTION_NM` · `SOURCE_DIV_NM` · `SOURCE_NO` ·
`BDGT_UNIT_NM` · `MOK_NM` · `DTL_ITEM_NM` · `SUBDTL_ITEM_NM` · `FUND_SOURCE_NM` ·
`BDGT_ITEM_NM` · `DESCRIPTIONVARCHAR`(적요) · `SUM_AMT` · `CONTENTS_DELIMITER`.

라이브 실측 = 24,933행 · `RESOLUTION_NO` 고유 **18,063**(⇒ 결의번호 **유일 아님** · 1결의 다명세) ·
`RESOLUTION_DEPT_NM` **52종** · `YEAR` **2026 단일** · `WRITE_DATE` **2026-01-01 ~ 2026-07-22** ·
`SOURCE_DIV_NM` 6종 · `SUM_AMT` NULL 0 · 합계 **₩110,291,190,623**.

🟢 **가치** = GOLD 가 「불가능」으로 문서화한 축을 이 원천이 가지고 있다:
`_wide_schema.yml` line 1090 = **「예산 원장은 부서별 분해가 현재 불가능하다 — 「부서별 예산·집행」
요구에 총계 1행이 돌아온다」**(`FACT_BUDGET.ORG_SK` 전건 센티넬 · O51-F).
⇒ `RESOLUTION_DEPT_NM` 52종 + `WRITE_DATE` 일자 + 적요 = **부서별·일자별·건별 집행 분해**가 가능해진다.

🔴🔴 **그러나 예산 원장과 합산하면 안 된다 — 두 원천은 같은 축이 아니다.** 실측 =

| 대조 | 값 |
|---|---|
| 원장 2026 집행(`EXEC_TOT_AMT`) | **11,183,088,258** |
| 지출결의 2026 합계(`SUM_AMT`) | **110,291,190,623** (원장의 **약 9.9배**) |
| 과목 6키 고유 — 지출결의 | **2,272** |
| 과목 6키 고유 — 원장 2026 | **69** |
| 지출결의 24,933행 중 원장 2026 과목키와 일치 | **5행 / ₩52,500** |

⇒ 🔴 **조인 근거가 없다**(24,933 중 5행 = 0.02%). 원장은 69 과목의 좁은 부분집합이고
지출결의는 2,272 과목의 넓은 집합이다. 원인 후보(㉠ 원장이 특정 사업 부분집합 ㉡ 표기 불일치
㉢ 대상 기간·범위 상이)는 **구별되지 않는다** ⇒ **현업 확인 선행**이다.
🔴 **관계를 창작해 조인·합산하지 마라 — 재무 오귀속이다**(`R2-7-1`·`R2-7-3` 축).
🟢 선례 = `_wide_schema.yml` line 1049 「광고비는 예산 원장에 항목이 없다 …
**예산과 같은 표에 합산하지 말 것**(원천이 다르다)」 — 같은 처방을 적용한다.
⚠️ 원장에도 `BDGT_ITEM_NM`·`DVLP_INBOUND_PATH` 가 있으나 지출결의에는
`INCOME_EXPS_DIV_NM`·`BDGT_PRCD_NM`·`JANG_NM`·`KWAN_NM`·`HANG_NM` 가 **없다**
⇒ 13컬럼 그레인으로는 **원리적으로 조인 불가**(부분 키만 공유).

## H. 참고 — 원장 필터·차원값 실측

* `INCOME_EXPS_DIV_NM` = **`지출` 1종** · NULL **0** · `'TOTAL'` 행 **0건**
  ⇒ `WHERE INCOME_EXPS_DIV_NM <> 'TOTAL'` 는 현재 **무작동**(247행 전건 통과).
  🟢 NULL 이 없으므로 그 필터의 **NULL 탈락 위험은 현재 없다**(NULL 이 생기면 조용히 행이 사라진다).
  ⇒ `DIM_BUDGET_ITEM.BUDGET_CATEGORY` 는 **전건 `지출`** — 수입 예산은 원천에 없다.
* `SUBDTL_ITEM_NM`·`DTL_ITEM_NM`·`MOK_NM` **전건 NULL 인 행 0** ⇒ `BUDGET_ITEM_NAME` NULL 0.
* `TRY_TO_NUMBER(YEAR)` 실패 행 **0** ⇒ `FACT_BUDGET_YEARLY` 의 `BUDGET_YEAR IS NOT NULL` 필터 탈락 0.
* `BDGT_PRCD_NM` 2종 · `BDGT_ITEM_NM` 5종 · `DVLP_INBOUND_PATH` 8종 ·
  `DIRECT_MNYRS_YN_1` 2종 · `DIRECT_MNYRS_YN_2` 2종.
* 🟢 삭제된 `MNYRS_COST_DIV_YN` 은 **dbt 모델 참조 0건**(`10_dbt_pipeline` 전수 grep) ⇒ **파손 없음**.
* 🟠 신규 `BDGT_PRCD_NM`·`DIRECT_MNYRS_YN_1`·`DIRECT_MNYRS_YN_2` 도 **참조 0건** ⇒ 미배선.
  ⚠️ `DIRECT_MNYRS_YN_1/2` 는 삭제된 `MNYRS_COST_DIV_YN`(모금비구분)의 **대체 후보**로 보이나
  🔴 **그 대응 관계는 원천 문서로 확인되지 않았다** — 창작하지 않는다.
* 🟠 `ERP_BUDGET.sql` line 9 는 `SELECT …, *` 로 원장 전체를 CTE 에 담는다(67컬럼).
  이름 지정 참조만 하므로 **파손은 없으나** 컬럼 추가에 조용히 노출되는 형태다.

## I. 참고 — source 미선언 BRONZE (이번 델타와 무관 · 기존 상태)

`BRONZE_CRM` 라이브 46 ↔ `_sources.yml` 선언 38 ⇒ **8종 미선언** =
`TC_CMMN_CD` · `TH_PM_SETLE_INFO_HIST` · `TM_MS_EMAIL_TMPLAT_MNG` ·
`TD_MS_AT_TMPLAT_BTN_LIST` · `TM_RM_CHILD_MSTR_INFO` ·
`TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT` · `TM_RM_RELATNSP_CHG_INFO` · `TM_RM_BPLC_MNG`.
`BRONZE_AGENCY` 라이브 4 ↔ 선언 3 (`SYNC_ERR_INFO` = 운영 로그 · 정상 제외).
⇒ 🟠 이번 변경으로 생긴 것이 **아니다**(「미사용 BRONZE」 기존 주제) — 델타 판정과 분리해 둔다.
