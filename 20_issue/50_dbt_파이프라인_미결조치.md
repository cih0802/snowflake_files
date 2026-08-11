<!-- LLM-METADATA
doc_id: ISSUE_50_DBT_OPEN_ITEMS
doc_role: dbt 파이프라인 미결 후속조치 — BLOCKING·결정대기·배포·DONE (실행/운영)
project: GN_DW (굿네이버스)
created: 2026-07-15
index: 20_issue/00_INDEX_이슈원장.md
priority: HIGH — 후속 세션 착수 시 먼저 확인
END-METADATA -->

# 50. dbt 파이프라인 미결 후속조치 (업무단계: 실행/운영)

> ⛔ **후속 세션은 이 문서를 먼저 읽고 시작.** 순서 9-B 검토에서 발견·보류된 파이프라인 미결을 모음. 완료 시 `[DONE]` 표기 후 `DEPLOY_RUNBOOK.md` 이관.
> 현업 판정이 필요한 데이터 이슈(A~E)는 문서20, 외부 입고는 문서40.
> 전체 인덱스: `00_INDEX_이슈원장.md`

---

## 🟢→🟡 O51-D-P1 — `DIM_PAYMENT` 를 PM040 사전 기준으로 재배선 (O45-B 해소에 따른 처방)

**[2026-08-07 O51-D BRONZE 전수 재스캔으로 신설]** O45-B 「결제수단 코드그룹 미특정 → 현업 확인」은 **오판이었고 해소됐다.**
현업 확인은 불요하며, 남은 것은 **차원 생성 소스 교체 1건**이다.

### 실측 근거

| 항목 | 값 |
|---|---|
| `SETLE_CD` 코드그룹 | **PM040(결제정보)** — 사전 13종 |
| 회비 원천 실적재 | **11종** · 11/11 전부 PM040 에 라벨 존재 |
| `TM_PM_SETLE_INFO`(결제수단 마스터) 에 **없는** 코드 | **5종** = `3`신용카드즉시 · `6`휴대폰즉시 · `7`MICR · `10`실시간계좌이체 · `13`가상계좌즉시 |
| 미라벨 규모(GOLD `WIDE_MEMBER_FEE`) | **192,106행 / 40,262,076 = 0.48%** (코드 보유 미라벨 172,686 + `SETLE_CD` NULL 19,420) |
| 종전 기재 225,855행 | **stale**(O45 시점 값) |

🔴 **원인**: `models/gold/dim/DIM_PAYMENT.sql` 이 `select distinct SETLE_CD, SETLE_NM from {{ ref('CRM_PAYMENT_METHOD') }}` 형태로
**결제수단 마스터에 존재하는 코드만** 차원에 담는다. 회비 원천(`TM_PM_MBRFEE_ACMSLT`)에만 나타나는 5종은 차원에 행이 없어 `PAYMENT_SK=0` 이 된다.
⚠️ `SILVER.CRM_PAYMENT_METHOD` 는 **이미 `CD_ID='PM040'` 으로 조인하고 있었다** — 사전은 처음부터 특정돼 있었고 O45 의 판정만 그것을 못 봤다.

### 처방 (택1 — 미결정)

- **(a) 사전 우선**: `DIM_PAYMENT` 를 `CRM_CODE where CD_ID='PM040'` 의 13종 전체로 생성하고 마스터를 좌조인해 부가속성만 붙인다.
  → 라벨 커버리지 100%. 사전에 있으나 실적재 0 인 2종(`9`타부서통장·`11`자동이체(사복))도 차원에 남는다(무해).
- **(b) 합집합**: 마스터 ∪ 회비원천 `distinct SETLE_CD` 를 키로 삼고 라벨은 PM040 좌조인.
  → 차원에 실사용 코드만 남는다. 다만 새 코드 등장 시 다시 누락될 수 있다.

🔷 **권고 = (a)** — 사전이 정본이면 실적재 변동에 차원이 흔들리지 않는다.

### ⚠️ 선행 확인 (착수 전 필수)

1. `DIM_PAYMENT.PAYMENT_SK` 는 `gold_sk(['SETLE_CD'])` 해시다 → **행이 늘면 기존 SK 는 그대로지만 SK=0 이던 팩트 행이 실 SK 로 바뀐다.**
   ⇒ `FACT_MEMBER_FEE`·`FACT_MEMBER_MONTHLY` 재빌드 필요. 🔴 `WIDE_MEMBER_MONTHLY.PAYMENT_METHOD` 는
   **현재 전건 `'(미매핑)'`**(FMM.PAYMENT_SK 전건 0)이므로 이 처방만으로는 바뀌지 않는다 — FMM 의 `PAYMENT_SK` 배선은 별건이다.
2. `DIM_PAYMENT.FEE_TYPE` 은 **0/7 전건 NULL**(O51-D 실측) → 이 처방과 무관한 별개 결손. 함께 판단할 것.
3. 완료 판정은 문장이 아니라 **스캔**이다(P33): `WIDE_MEMBER_FEE` 의 `PAYMENT_METHOD_NAME` 미라벨 행이 192,106 → 19,420
   (`SETLE_CD` 자체 NULL 분만 잔존)으로 줄어야 한다.

---

## 🔴 BLOCKING-1 — `severity: warn` 되돌리기 (회원 마스터 전량입고 후)

회원 마스터(`CRM_MEMBER`) 스냅샷 미완전 고아 때문에 참조무결성 테스트를 **임시 `warn` 강등**. 마스터 전량입고 시 **전부 `error` 복귀** 필요(무결성 게이트 복원).

| 파일 | 대상 테스트 | 건수 | 현재 |
|---|---|--:|---|
| `models/gold/_gold_ready_schema.yml` | FMM·FEP·FME·FSE 의 `MEMBER_DK→DIM_MEMBER` | 4 | warn |
| `models/silver/crm/_crm_schema.yml` | `MBER_NO/MEMBER_DK→CRM_MEMBER`(EVENT_PARTICIPATION·MEMBER_DEV·DISCONTINUE·AMT_CHANGE·RESPONSOR·STATUS_HIST·PAYMENT_BILLING·PAYMENT_METHOD·SEND_MEMBER·SPONSOR_RELATION) | 10 | warn |
| `models/silver/_silver_bridge_schema.yml` | `IDENTITY_MEMBER_XREF.MEMBER_DK→CRM_MEMBER` | 1 | warn |
| `models/silver/ga4/_ga4_schema.yml` | `GA4_IDENTITY.MBER_NO→CRM_MEMBER`(모델 disabled) | 1 | warn |

- **복귀 조건**: 현업이 "회원 마스터 추출 범위/시점 문제" 확인·수정 → 고아 해소 후(문서20-B·문서40 §3).
- **검증**: `dbt build --select path:models/silver path:models/gold` → ERROR=0 확인.

## 🔴 BLOCKING-2 — 현업 판정 대기 (데이터 이슈 A~E)
파이프라인이 무효/의심 처리했으나 **현업 회신 전 확정 불가**. 회신 오면 로직 반영. **상세 질문·규모는 문서20 §C.**

| # | 항목 | 현재 처리 | 회신 후 조치 |
|---|---|---|---|
| A | `MONTH_KEY` 비-YYYYMM(~2,043행) | 무효→납입월/0 라우팅 | 유효 판정 시 클램프 완화 |
| B | 회원번호 마스터 부재 9,248명+불량ID+NULL 750 | warn(보존) | 마스터 재추출 or 불량 폐기 |
| C | 캘린더 범위밖 날짜(~140행) | DATE_SK=0 | 유효 시 캘린더 확장 |
| D | 원천 값 전무 컬럼(5종) | NULL | 추출보완 or 정상NULL 확정 |
| **E** | **`EVENT_KEY→CRM_EVENT` 고아 263,611(참여 23%)** + `SNDNG_KEY` 11,313+9 | **warn 관측(순서9-C)** | 원인규명(마스터 누락 vs 키체계) 후 error 복귀 |

> ⚠️ **[순서9-C 개정]** 메달리온 베스트 프랙티스(Silver 참조무결성 = 알려진 원천 미완전이면 warn 관측, error 는 구조 불변식만)에 따라 **E 및 참조무결성 9건을 `severity:warn` 강등** → **full `dbt build` 는 이제 green**(ERROR=0). 마스터 전량입고·키체계 확정 시 `_crm_schema.yml`의 순서9-C warn 을 error 로 복귀. 대상 목록·복귀조건은 해당 yml 주석 참조.

## 🟢 [2026-08-06 O43] BLOCKING-5 전수 재측정 — 미주입 106/386(27.5%)을 컬럼 단위로 확정

> 종전 BLOCKING-5 표(아래)는 FACT 5종만 대상이었고 `0/NULL` 을 한 칸에 묶었다.
> O43 에서 **GOLD 전 기본 테이블 전 컬럼**에 `COUNT`/`COUNT_IF(<>0)` 를 돌려 전수 확정했다.
> ⚠️ `COUNT()` 만으로는 **0 상수 주입을 「적재됨」으로 오판**한다 — 반드시 `COUNT_IF(<>0)` 로 판정할 것.

| 구분 | 건수 | 비중 |
|---|---:|---:|
| GOLD DATA 컬럼(감사컬럼 `DW_*` 제외) | **386** | 100% |
| 값 주입됨 | **280** | 72.5% |
| 전건 `0` | **62** | 16.1% |
| 전건 `NULL` | **36** | 9.3% |
| 0행 테이블(`FACT_TARGET_BIZ`) | **8** | 2.1% |
| **미주입 합계** | **106** | **27.5%** |

**원인별 분류 (전량 배정 · 누락 0)**

| 버킷 | 건수 | 해소 주체 |
|---|---:|---|
| A 원천에 항목 자체가 없음 | 18 | 🔴 외부 입고(E-6·E-1/E-4·C-9-R·HOL-1·AD-5·C-8) |
| **B 원천은 있으나 산출 로직 미구현** | **51** | 🟡 **내부 구현 — 외부 의존 0** |
| C 코드체계 미확정 | 11 | 🟠 현업 확인(O28) |
| D 연결키 부재 | 14 | 🔴 연결키 회신(Q10·O8) |
| E 산출규칙 미확정 | 4 | 🟠 현업 확정(CONF-4) |
| F 적재 범위·시점 | 8 | 🔴 입고 범위 확대(G-5) |

🔴 **B 가 최대(48.1%)이고 외부 의존이 0 이다.** 종전 문서는 이 구분 없이 「원천 결손」으로 묶어 전부
외부 대기로 보이게 했다. B 착수의 선결조건은 대부분 **규칙 확정 1건**이다:
- 활동회원 8종 → **CONF-3**(정본 #51 판정 조건 내부 모순) 현업 확인
- 미납 카운트 3종 → **CONF-2**(`(건)` = 건수인가 금액÷10,000인가)
- 발송 성공/실패 → 채널별 성공/실패 코드매핑 업무 확정
- 증액·감액·이탈 4종 / 서신·선물금 8종 / 미납중단 2종 / 회비 분해 4종 → **선결조건 없음(즉시 착수 가능)**

**컬럼 단위 전량 목록** = `30_output_share/02_원천결손_Gap분석.md` §부록
**재현 방법** = `python3 scripts/dump_schema.py && python3 scripts/census_columns.py`

---

## 🔴→🟡 BLOCKING-5 — GOLD 팩트 measure·차원FK 대규모 미적재 (SV/Agent 착수 시 실측 발견 2026-07-21 · A1/A3 부분해소 진행중)
> SV 설계(05_SV-Agent_ai 2단계) 중 **배포된 GOLD 실데이터**를 컬럼별 실측(`COUNT_IF`)한 결과, 행수는 있으나 **대부분의 카운트 measure·차원 FK가 전건 0/NULL**. 기존 Item D("원천 값 전무 5종")·D1(스캐폴드)·E(고아)의 범위를 **초과**하는 미적재. Cortex Analyst SV가 이 위에 서면 0/오답을 자신 있게 반환 → **배포 전 원인규명 필수**.
> 🟡 **[2026-07-21 진행] A1·A3 착수** — 입고된 SILVER 데이터로 채울 수 있는 것부터 구현(아래 §BLOCKING-5 진행분).

| FACT | ✅ 적재(활성 가능) | ❌ 전건 0/NULL (미적재) |
|---|---|---|
| FMM 37.8M→40.05M | PAID_FEE(36.09M)·BILLED_AMT·UNPAID_FLAG_BOM/EOM · ✅**DEV/STOP 건·명(A1: FME 롤업)** · ✅**HAS_BILLING(A1 출처플래그)** | UNPAID/ACTIVE/CUM/MONTH_END/YEAR_*·INCREASE 건·명·CAMPAIGN_UNPAID·STATUS_UNPAID·INBOUND/TS_CALL·REGULAR_FEE·SPONSOR/PAID_MONTHS·DEV_TYPE·밴드·JOIN_DATE·NEW_FLAG·NEW_EXISTING_FLAG·**CAMPAIGN/PAYMENT/SPONSORSHIP/REASON_SK** |
| FME 4.6M | DEV_CNT/MEMBERS·JOIN_DATE(3.59M)·STOP_CNT/MEMBERS/STOP_DATE(1.04M) · ✅**CAMPAIGN_SK(DEV 한정, 2026-07-30 실측: DEV 3,594,825/3,594,843 · 16,318종)** | UNPAID_STOP·**ORG_SK**·**CAMPAIGN_SK(STOP 한정 — 원천 `CRM_MEMBER_DISCONTINUE`에 캠페인 컬럼 부재)**·**SPONSORSHIP_SK·REASON_SK·NEW_EXISTING_FLAG** |
| FSE 38.5M | SEND_MEMBERS(전행)·SEND_STATUS(35.75M) · ✅**SERVICE_SK(A3: 요청마스터 조인, 99.97%)** · ✅**SEND_TITLE(A3)** | SUCCESS/FAIL/OPEN/LETTER/GIFT·**D5_\*(증액·서신·선물·중단)**·**CAMPAIGN_SK**(원천 캠페인 컬럼 부재) |
| FEP 1.1M | MEMBER_DK·PARTICIPANT_CNT·EVENT_SK(76.8%) | TOTAL/RECRUIT_CNT·CAMPAIGN_SK·SPONSORSHIP_SK |
| FBD 24.5K | BUDGET_ITEM_SK(전행)·PLAN_BUDGET_MONTH(7,290)·EXEC_BUDGET_ERP(3,244) | PLAN_BUDGET_YEAR·FUNDRAISING_COST·AD_COST·CAMPAIGN_SK·ORG_SK |

- **영향**: 캠페인별/조직별/서비스구분별/납입방식별/신규기존별 지표, 활동·개발·중단 카운트 비율, 목표대비(공1~3), 서비스 수신/참여/증액/코호트(신31~53) = **전부 계산 불가**. Phase-1 실활성 = 납부율·미납회원감소·납입/청구/예산(세세목)·개발/중단 총건·유지기간·발송수·참여자수뿐.
- **원인 후보(규명 필요)**: ① dbt gold.fact 모델이 해당 measure/FK 매핑 미구현(스캐폴드 컬럼 잔존) ② SILVER 원천 컬럼 공란(=Item D 확장) ③ FK 조인 미결선(전건 센티넬 0). → **GOLD/ETL 담당 확인**: 의도된 NULL인가 vs 적재 로직 누락인가.
  - 🟡 **[2026-07-21 규명 결과]**: 원인은 대부분 **①(스캐폴드 컬럼 잔존, 로직 미구현)** — SILVER 원천은 입고돼 있음(FME dev/stop·CRM_SEND_REQUEST 등). 입고 대기(②/외부)는 소수(INBOUND/TS_CALL=C-8·FTG_BIZ=E-6·D5 코호트·FSE CAMPAIGN_SK[원천 캠페인 컬럼 부재]).
- **조치**: (a) 좁은 Phase-1 SV는 실적재 컬럼만으로 배포(진행), (b) 본 항목 원인규명 후 measure/FK 적재 → SV metric 순차 활성(구조 DDL 불변). 
- **검증 재현**: `SELECT COUNT_IF(<col><>0) FROM GN_DW.GOLD.<fact>` (상세 매트릭스 = `05_SV-Agent_ai/04_SV_설계.md §0.6`).

### 🟡 [2026-07-21 진행분] BLOCKING-5 A-계열 착수 (입고 데이터로 구현 가능분)
> "할 수 있는 것만" 원칙: 입고된 SILVER 데이터로 결정·외부의존 없이 채울 수 있는 항목을 우선 구현. build 는 사용자 실행.
- ✅ **A3 — FSE SERVICE_SK·SEND_TITLE** (`models/gold/fact/FACT_SERVICE_EVENT.sql`): `CRM_SEND_MEMBER × CRM_SEND_REQUEST`(SNDNG_KEY, unique) 조인 → `SERVICE_SK = gold_sk([SEND_CHANNEL, SNDNG_TY_CD])`(DIM_SERVICE 동일 산식)·`SEND_TITLE=TIT`. **시뮬 검증: 커버 99.97%(38.46M/38.47M)·DIM_SERVICE 미매칭 SK=0건**. 미매칭 → SERVICE_SK=0(Unknown).
- ✅ **A1 — FMM DEV/STOP 건·명 + HAS_BILLING** (`models/gold/fact/FACT_MEMBER_MONTHLY.sql` + `06_DDL.sql`): 스파인 = 회비(billing) ∪ 개발/중단(FME 월 롤업). `DEV_CNT/DEV_MEMBERS/STOP_CNT/STOP_MEMBERS` 실채움. **신규 컬럼 `HAS_BILLING BOOLEAN`**(출처 플래그)로 보수(billing-only)·정확(전체) 양립. **시뮬 검증: 40,054,883행=distinct grain(fan-out 0)·HAS_BILLING=TRUE 37,792,336(구 스파인과 정확 일치)·EVENT_ONLY 2,262,547·DEV 2.97M/STOP 0.97M 월×회원**.
  - ⚠️ **DDL 변경**: FMM에 `HAS_BILLING` 1컬럼 추가(06_DDL.sql). fact는 append+pre-hook TRUNCATE라 **build 전 06_DDL 재실행(ALTER/재생성) 필요** — 미실행 시 신컬럼 부재로 append 실패.
  - ⚠️ **DEV_CNT 의미**: FME 사건수(금액/10000 아님). 금액기반 "건"은 원천 금액컬럼+FME 변경 필요(별도트랙).
- 🔜 **잔여(B계열) — ⏸️ Agent 오픈(SV 배포) 후 진행 결정**: SV/Agent를 먼저 열어 실사용 피드백을 받은 뒤 우선순위대로 착수. 데이터·조인은 준비됨, 각 게이트만 남음.
  - **B1 FSE SUCCESS/FAIL_MEMBERS**: SNDNG_RST_CD 채워짐(2/1/Y/4/3/N/0) → **채널별 성공/실패 코드매핑 업무확정** 후 파생.
  - **B2 FMM SPONSORSHIP_SK·PAYMENT_SK**: 원천 컬럼(SPNSR_BSNS_ID·PAYMENT_TYPE 등) 존재 → **O8 다중후원(회원 9.9%·최대13) grain 규칙**(대표후원/최빈) 확정 후.
  - **B3 FMM/FSE CAMPAIGN_SK**: 발송/회비 원천에 캠페인 컬럼 부재 → **조인경로 확보 + O8 fan-out 검증**(§1-6 P3 패턴) 후.
  - **근거**: A1/A3로 Phase-1 SV 실활성 스코프(발송수·서비스구분·개발/중단 총건 등)는 충분 확보 → Agent 먼저 열고, B는 실사용 요구에 따라 순차.

### 🔴 [신규 2026-07-30] BLOCKING-5 범위 확장 — **DIM 계열 미적재 (기존 진단에서 누락)**

> **왜 지금 나왔나**: 위 BLOCKING-5 표는 FMM·FME·FSE·FEP·FBD **5개 FACT만** 진단했다. DIM 계열은 그 표의 대상이 아니었다. ML 요건 정본(`99_provided_definition/데이터플랫폼 ML 예측관련_취합_20260730.xlsx`) 대조 중 발견.
> ⚠️ **[정정 2026-07-30] "어느 문서에도 등록되지 않았다"는 최초 기술은 과장이었다.** 3건 모두 **설계 문서·모델 주석에는 기재돼 있었다** — `DIM_ORG` 계층전개는 **DEC-5(§6-1)** 에 반영 위치까지 명시 + `DIM_ORG.sql` 주석 / `IS_HOLIDAY`는 **D1 설계 컬럼** + `DIM_DATE.sql` 주석 / `SPONSORSHIP_ABBR`은 **D5 설계 컬럼**. 정확한 문제는 **"설계에는 있으나 (a) 값 미주입 상태가 dbt 미결조치 추적표에 올라오지 않았고 (b) 설계 문서에 구현현황이 역기록되지 않았다"** 는 것이다. 설계 소관 항목은 `03_테이블 설계.md` §5 **O16~O19** 로 정본화했고, 본 표는 미적재 추적만 담당한다.

| DIM | 컬럼 | 실측 (2026-07-30) | 원천 | 성격 |
|---|---|---|---|---|
| `DIM_ORG` (1,315행) | `CORP`·`DIVISION`·`TEAM` | **전건 NULL** (`DEPARTMENT`만 1,315/695종 채움) | 🟢 `SILVER.CRM_ORG.UPPER_DEPT_ID` **1,314행/321종 확보** · `ACMSLT_UPPER_DEPT_ID` 1,014행 | **내부 구현 가능** (재귀 CTE) |
| `DIM_DATE` (16,437행) | `IS_HOLIDAY` | **TRUE 0 / FALSE 16,437 / NULL 0** = 하드코딩 `FALSE` | 🔴 **전 스키마 전무** (`%HOLIDAY%`·`%HDAY%`·`%RESTDE%`·`%WORKDAY%` 검색 결과 GOLD 자기참조뿐) | **외부 입고 필요** → 문서40 |
| `DIM_SPONSORSHIP` (51행) | `SPONSORSHIP_ABBR` | 값은 채움(`1`~`6`, 6종) 그러나 **라벨 없음 · 컬럼명이 의미 은폐** | 🟢 `CRM_SPONSORSHIP.SPNSR_BSNS_ABRV_CD` | **라벨 컬럼 신설 + 현업 매핑** |

**(1) `DIM_ORG` 계층 미전개** — `DIM_ORG.sql` 주석에 자기문서화됨:
> *"⚠️ 계층전개(CORP/DIVISION/DEPARTMENT/TEAM)=`UPPER_DEPT_ID` 재귀 필요 → 입고 후 확장. 현재 DEPARTMENT=DEPT_NM만."*

- ⚠️ **설계 소관**: 계층 전개 방식·미결 3건은 **`03_top-down_gold/03_테이블 설계.md` §5 O16**(정본)에 기록. 본 문서는 "미적재 상태" 추적만 담당한다.
- **DEC-5(현업 C-7)가 이미 정한 것**: 트리 = **`UPPER_DEPT_ID`**(확정) · `STATS_DEPT_LVL` **미사용**(확정) · `TEAM` = **5th 레벨**.
  → 종전 본 세션에서 "어느 트리 기준인지 확정 불가"·"`STATS_DEPT_LVL`이 폐기인지 현업 확인 필요"로 올린 것은 **DEC-5를 읽지 않은 상태의 추론이었다 → 철회.**
- 재귀 실측(2026-07-30): `UPPER_DEPT_ID` 트리 **6단**, LVL별 9/38/351/672/238/6 = **1,314 = 원천 행수 정확 일치**(고아·순환 0).
- 🔴 잔여 미결(설계 O16): ① 6레벨 → 4컬럼 매핑(DEC-5는 `TEAM`=5th만 확정) ② 본부/지부가 D6에서 **동일 레벨(`DIVISION`)** 로 묶여 ML 요건 "신규본부/신규지부" 3분류 산출 불가 ③ DEC-5 부기 "5th=실적부서" 표현 확인(실측: `ACMSLT_DEPT_YN='Y'` = LVL1 1/LVL2 0/LVL3 219/LVL4 115/LVL5 118/LVL6 2 → LVL5의 49.6%만 실적부서·실적부서 455개 중 LVL5는 26%)
- ⚠️ **본 세션 자체 오판 기록**: `DEPT_NM LIKE '%본부%'` 명칭 패턴으로 "깊이 기반 매핑 성립 불가"라 판정했으나 설계·DEC-5는 **레벨 기반**이므로 **검증 기준을 잘못 잡은 범주 오류**(AD-1 오진과 동일 유형) → 판정 철회.
- **요건 영향**: 기획실 "**부서별** 개발예측"은 `DEPARTMENT`(695종)로 산출 가능 ✅ / 회비예측 "신규**본부**/신규**지부**/기존"은 `DIVISION` 부재로 불가 🔴

**(2) `DIM_DATE.IS_HOLIDAY`** — `DIM_DATE.sql`: `FALSE as IS_HOLIDAY,   -- ⚠️ 휴일 원천 없음(추후 보정)`
- 기획실 개발예측 **A안 3종 전부**가 *"연도말까지 **주말(휴일)** 제외한 나머지 개발가능일수 반영"* 을 요구.
- 주말은 `DAY_OF_WEEK`(Sat/Sun 정상 채움)로 산출 가능. **공휴일은 불가** → 문서40 신규 등록.
- ⚠️ WIDE 6종(`WIDE_MEMBER_EVENT`·`WIDE_SERVICE_EVENT`·`WIDE_GA_BEHAVIOR`·`WIDE_EVENT_PARTICIPATION`·`WIDE_AD_*`)이 이 컬럼을 **그대로 상속**한다 → 현재 전부 FALSE. 소비 측이 "휴일 아님"으로 오독할 위험.

**(3) `DIM_SPONSORSHIP.SPONSORSHIP_ABBR` 의미 은폐** — DDL·D5 주석은 `'약칭(#124)'`이나 실제 값은 `1`~`6` **6종 코드**다:

| `ABBR` | 사업수 | 소속 사업 (원문) | 🟡 그룹 의미 **(추정)** |
|---|---:|---|---|
| `1` | 17 | 국내아동후원·아동복지시설지원·아동학대예방·결식아동지원·장애시설지원·복지관후원·저소득가정지원·저금통·정회원·국내사례·국내사업후원·국내아동권리보호사업 등 | 국내 계열 |
| `2` | 1 | 해외아동결연 | 결연 |
| `3` | 6 | 해외지역개발사업·희망학교지원사업·식수위생지원사업·해외교육지원사업·보건의료지원사업·재난구호지원사업 | 해외 프로젝트 계열 |
| `4` | 3 | 대북지원사업·북한사업후원·북한아동후원 | 대북/북한 계열 |
| `5` | 21 | 일시후원·선물금회원·선물캠페인·긴급구호(법정/지정)·가족개별후원·재가복지개별후원·좋은이웃·혼합회원·특별후원회원·정기일시 등 | 기타 계열 |
| `6` | 2 | 해외사례·해외사업후원 | (귀속 불명) |
| NULL | 1 | (미매핑) | 센티넬 |

- 🔴 **위 "그룹 의미" 열은 사업명에서 읽어낸 추정이며 코드사전 근거가 아니다.** `SILVER.CRM_CODE`에서 해당 코드그룹(`CD_ID`)을 특정하지 못했다 → **라벨 확정 전 단정 금지.** (SVL-1~4와 동일 성격의 라벨 대기 항목)
- ML 정본은 *"후원사업(국내/결연/해외프로젝트/기타)별"* **4그룹**과 월 회비예측 *"후원사업 총 **11개**"* 를 요구. **6종↔4그룹↔11개 대응은 전부 미확정** → 현업 매핑표 필요(문서20 §F-2).
- ⚠️ 카디널리티 50↔29 불일치는 **신규가 아니다** — 기존 **O13**(설계 §5)로 이미 등록된 미확정 항목. 이번에 배포본 51행(=마스터 50 + unknown 1)·실사용 29종을 추가 실측했을 뿐 원인은 여전히 미확정.
- ⚠️ 2026-07-16 캠페인 유형1/유형2 의미혼입 교정과 **동일 패턴**(컬럼명·주석이 실제 의미를 가림).
- 설계 소관 정본 = `03_테이블 설계.md` §5 **O19**.

### 🔴 [신규 2026-07-30] `UNPAID_FLAG_BOM` LAG 전월 근사 — DEC-4가 "완료"로만 기록한 잠복 결함

`FACT_MEMBER_MONTHLY.sql:91`:
```sql
LAG(j.UNPAID_FLAG_EOM) OVER (PARTITION BY j.MEMBER_DK ORDER BY j.MONTH_KEY) as UNPAID_FLAG_BOM
-- 모델 주석: "회원별 월순 LAG(union 스파인 전체 월 기준; 결측월은 직전 존재월 근사)"
```
스파인 = 회비 ∪ 개발/중단이 **있는 월만** 존재 → 회원의 월이 연속이 아니다. `LAG`는 "전월"이 아니라 **"직전 존재월"** 을 가져온다.

**규모 실측 (2026-07-30, `MONTH_KEY` 199101~203512)**:
```
직전행이 있는 행                38,294,238
  gap = 1개월  (정확)           36,785,612   96.06%
  gap > 1개월  (근사=부정확)      1,508,626    3.94%   ← BOM 이 실제 전월 상태가 아님
  gap > 12개월                     980,037           ← "전월"이 1년 이상 전
최대 gap                              370개월  (30.8년)
```
최악 사례: 1991년 행이 2022년 행의 "전월"로 사용된다.

- 모델 주석에는 자기문서화돼 있으나 **문서30 DEC-4는 "`UNPAID_FLAG_BOM`(LAG) ✅완료"로만 기록**하고 근사 사실·규모를 남기지 않았다.
- 🔴 **§5 직접 영향**: `PREV_MONTH_END_ACTIVE_CNT`(#53)를 같은 `LAG` 패턴으로 구현하면 **동일 결함을 상속**한다. 이 컬럼은 `04_SV파생 매핑.md`상 중단율·활동율 계산의 **분모 입력**이다.
- **올바른 처리 후보**: ① 스파인을 `DIM_DATE` 월 축으로 **dense화**(회원×존재구간 전월 생성) 후 `LAG` ② `MONTH_KEY` 산술로 **명시적 전월 조인**(`ADD_MONTHS` 기준 self-join, 없으면 NULL) — ②가 dense화 비용 없이 정확하다.
- **결정 필요** → 문서30 신규 DEC. §5 착수의 선결조건(`YEAR_START` 적재규약과 동급).

### 🟡 [신규 2026-07-30] FMM 52컬럼 전수 census — 미적재를 3분류로 확정

BLOCKING-5 표는 "전건 0/NULL"을 한 칸에 묶었으나, **0 상수 주입과 전건 NULL은 조치 방식이 다르다.** 2026-07-29 재적재본 실측 결과:

| 분류 | 수 | 컬럼 |
|---|---:|---|
| **실적재** | 8 | `PAID_FEE`(36.09M nz) · `BILLED_AMT`(37.15M nz) · `HAS_BILLING`(TRUE 37,792,336) · `UNPAID_FLAG_EOM`(TRUE 3,302,535) · `UNPAID_FLAG_BOM`(TRUE 3,194,999) · `DEV_CNT`(2.97M nz) · `DEV_MEMBERS` · `STOP_CNT`(0.97M nz) |
| **0 상수 주입** | 27 | `ACTIVE*` 4종 · `MONTH_END`/`YEAR_START`/`YEAR_END`/`PREV_MONTH_END_ACTIVE_CNT` · `UNPAID_CNT`·`CAMPAIGN_UNPAID_CNT`·`STATUS_UNPAID_CNT` · `CHURN_CNT` · `INCREASE_CNT`·`INCREASE_MEMBERS`·`DECREASE_CNT` · `CAMPAIGN_SK`·`SPONSORSHIP_SK`·`PAYMENT_SK`·`REASON_SK` · `REGULAR_FEE`·`REGULAR_ONETIME_FEE`·`ONETIME_ONETIME_FEE` · `SPONSOR_MONTHS`·`SPONSOR_YEARS`·`PAID_MONTHS` · `INBOUND_CALL_CNT`·`TS_CALL_CNT` |
| **전건 NULL** | 11 | `DEV_TYPE`·`NEW_FLAG`·`INCREASE_FLAG`·`REDONATE_FLAG`·`AMOUNT_BAND1/2`·`PERIOD_BAND1/2`·`NEW_EXISTING_FLAG`·`JOIN_DATE`·`STOP_DATE` |
| grain·감사 | 6 | `MONTH_KEY`·`MEMBER_DK`·`DW_*` 4종 |

- 합계 52 = `06_DDL.sql` FMM 컬럼수 **1:1 일치** (DDL↔배포본 동기 확인).
- ⚠️ **측정 방법 주의**: `COUNT(col)`은 non-null만 세므로 0 상수 주입군을 "적재됨"으로 오판한다. **`COUNT_IF(col<>0)` 또는 `GROUP BY` 값 분포로 판정할 것.** (2026-07-30 이 오판 실제 발생 — `FSE.OPEN_MEMBERS`를 `COUNT()`로 "38,470,780행 전건 적재"로 오판, 실제는 전건 0)
- ✅ **부수 소득**: `UNPAID_FLAG_EOM`(TRUE 3,302,535)은 이미 실적재 → §5 `UNPAID_CNT` 배선 시 **독립 cross-check 기준**으로 사용 가능(P21). 또 ML 요건 "연속미납횟수"를 이 flag의 월 run-length로 산출 가능(단 위 LAG 결함 영향).
- ✅ `REGULAR_FEE`가 0인데 `PAID_FEE`는 실적재 → **회비 분해(정기/일시)가 미수행 상태**임이 확정.


## 🟡 결정 대기 — 누락/과잉 GOLD 6개
모델 작성 여부 결정 필요. **상세는 문서30 §6.** 요약: 소스 준비 4개(즉시 가능)·소스 입고대기 1개(FACT_TARGET_BIZ, 원천=**CRM** 확정·신규 목표 테이블 대기)·`DIM_MEMBER_IDENTITY`는 **2026-07-15 활성화 완료**(enabled=true·XREF dedup 조인, 1,274명 매칭).

## 🟢 [정정 2026-07-15 · 재생성 2026-07-21] BLOCKING-3 — dbt project 배포됨
**정정(2026-07-15)**: 앞선 "결과 공란"은 **조회 스키마 오류**(`SHOW DBT PROJECTS IN SCHEMA GN_DW.SILVER`)였음 — 프로젝트는 **`GN_DW.OPS`** 에 있음. dbt 버전관리·`build` 게이트·리니지 정상 작동.
- **[2026-07-21 계정이전 재생성]** 신 계정(cs94293)에 `GN_DW.OPS.DW_PIPELINE` **최초 재생성 완료** — `VERSION$1`(default=LAST, A1/A3 반영분). `CREATE DBT PROJECT` 권한을 GN_DW_ADMIN에 선부여 후 생성(`10_dbt_pipeline/deploy_dbt_project.sql`). source=`snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/`.
- **[2026-07-21 build 검증]** `build --target dev` (전체 232 노드) → **PASS=211 WARN=21 ERROR=0**. FMM 40,054,883·FSE 38,470,780 재적재. WARN 21 = 기존 참조무결성 warn(순서9-C 강등분).
- **후속**: 워크스페이스 편집분은 `ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE ADD VERSION` 으로 반영.
- **참고(구 계정 이력)**: 구 계정 default=VERSION$6 `IDENTITY_WIRED_20260715` — 신 계정은 versions/live 최신 코드가 곧 VERSION$1 이라 드리프트 무관.

## 🟢 [순서9-D 2026-07-15 배포·검증완료 / 2026-07-16 9/9 완결] BLOCKING-4 — GOLD WIDE VIEW: 9/9 배포완료(dbt view)
GOLD 스키마 COMMENT 는 "WIDE VIEW 9개 제공"이라 기재됐으나 실측 뷰 0개였음. **순서9-D 에서 dbt view 모델(`models/gold/wide/`, `ref()`·`materialized:view`)로 8종 저작→`ADD VERSION`→full `build` 배포 완료** — 미거버넌스 객체(BLOCKING-3) 재발 방지.
- ✅ **배포·검증완료 8종**: WIDE_MEMBER_MONTHLY·WIDE_MEMBER_EVENT·WIDE_TARGET_DEV·WIDE_SERVICE_EVENT·WIDE_GA_BEHAVIOR·WIDE_AD_PERFORMANCE·WIDE_EVENT_PARTICIPATION·WIDE_BUDGET. **full `dbt build` green(PASS=205 WARN=21 ERROR=0)**, 8 view models OK created.
- ✅ **COMMENT 적용 검증(실측)**: 각 모델 `post_hook`(`ALTER VIEW ... ALTER COLUMN` + `COMMENT ON VIEW`, 정본 `10_WIDE VIEW 코멘트.sql` verbatim)로 **뷰레벨 8/8 + 컬럼레벨 310/310(100%)** 적용 확인. (72+48+45+42+38+34+21+10=310. 330−310=보류된 WIDE_TARGET_BIZ 몫.)
- ⏳ **보류 1종 WIDE_TARGET_BIZ**: ✅ **[해소 2026-07-16]** `FACT_TARGET_BIZ`(스켈레톤)+`WIDE_TARGET_BIZ` dbt 모델 저작 → `build --select FACT_TARGET_BIZ WIDE_TARGET_BIZ` green(PASS=2, 0행). BLOCKING-4 이제 **9/9**. 단, 아래 §단위충돌·조인키 결함 처리분 참조.
- ✅ **WIDE_GA_BEHAVIOR IDENTITY 배선(2026-07-15 갱신)**: `DIM_MEMBER_IDENTITY` 활성화에 따라 IDENTITY_* 4컬럼 **NULL 플레이스홀더 → 실조인 복원**(`f.IDENTITY_SK = DIM_MEMBER_IDENTITY.IDENTITY_SK`). FACT_GA_BEHAVIOR.IDENTITY_SK 도 XREF(pseudo→회원)→DIM 매칭분으로 채움(미매칭=0 센티넬). ⚠️GA4 1일 기반·G-5 시 재검증(아래 §G-5 게이트).
- 🔜 **후속(저우선)**: GOLD 스키마 설명 "9개"→실 배포 9종 일치 확인 완료.
- ✅ **[순서9-I 2026-07-28] WIDE 9종 → 13종으로 확장**: AGENCY 광고 위성 팩트 분리(DEC-8)에 맞춰 `WIDE_AD_BROADCAST`·`WIDE_AD_DIGITAL`·`WIDE_AD_BROADCAST_CASE` **3종 신설** + `WIDE_AD_PERFORMANCE` 코어화 수정. `dbt build` green(**PASS=258 WARN=21 ERROR=0**, 12 view models OK). ⚠️**measure 노출 규칙(DEC-13)**: 1:1 위성(FAD_B·FAD_D)은 코어 measure 동반 노출(fan-out 없음), **1:N 위성(FAD_BC)은 미노출**(사례 수만큼 중복 합산). 상세 = 문서10 §8-I(11) · 문서30 §1-A DEC-13.
- 🔜 **후속(저우선)**: GOLD 스키마 COMMENT 의 "WIDE VIEW 9개" 문구 → **13개**로 갱신 필요(미반영).

### ⚠️ [2026-07-16 비판적 검토] FACT_TARGET_BIZ 스켈레톤 — 잠복 결함 2건 처리
0행 스켈레톤이라 build 는 통과하나, 데이터 입고 시 **조용히 오작동**할 구조 2건을 사전 발견·교정.
- 🔴→✅**해소** **단위충돌(금액 vs 건)**: (구)SILVER `ERP_BIZ_TARGET.TARGET_AMT`=목표 **금액(원)** vs GOLD measure `ANNUAL/SUPP_GOAL_CNT`(#152~155)=목표 **건(件)**. 최초안은 `TARGET_AMT→ANNUAL_GOAL_CNT` 매핑 = 금액을 건 슬롯에 강제투입(`FACT_BUDGET` "재무 오귀속 방지" 원칙 위배). **[2026-07-20 해소] SILVER 테이블을 `CRM_BIZ_TARGET`(`TARGET_CNT` 건 + `TARGET_TYPE` 당초/추경)로 재구축 완료** → GOLD FACT는 TARGET_TYPE 피벗(당초→ANNUAL·추경→SUPP)으로 배선. ①금액 measure 신설안 폐기. 잔여 = 현업 데이터 입고(E-6). (원천=CRM 확정, 문서30 §6)
- 🔴 **조인키 타입 불일치(이름 vs 코드)**: 최초안이 DIM 코드 BK(`ORG_DK`=hash(DEPT_ID)·`SPONSORSHIP_BK`=SPNSR_BSNS_ID·`CAMPAIGN_BK`=CMPGN_CD)에 SILVER **이름**(ORG_NM·SPONSOR_BIZ_NM·CAMPAIGN_NM)을 조인 → 입고 시 100% Unknown(0) 라우팅될 뻔. → **이름기반 조인으로 교정**(`o.DEPARTMENT`·`s.SPONSORSHIP_NAME`·`c.CAMPAIGN_NAME`). ⚠️잔여: ERP 조직명=본부/지부 grain vs `DIM_ORG.DEPARTMENT`=부서 grain 불일치 가능 → **조직 이름 크로스워크**(문서32) 확보 전까지 미매칭 시 Unknown(0).
- **결론**: 구조·리니지·거버넌스는 완결(9/9). 측정치 실채움은 E-6 입고 + 위 2개 해소조건 충족 시.

## 🟢 [순서9-D 2026-07-15] 내부 후속 TODO 처리 (bronze 데이터·설계로직 범위)
순서9-D 종료 시점, 현업 회신·데이터 입고 없이 진행 가능한 잔여 내부작업을 전수 점검·처리.
- ✅ **[DONE] #3 `AGENCY_AD_PERFORMANCE.AD_DATE` warn→error 승격**: 실측 널 0/235,572 → `_silver_bridge_schema.yml` severity 제거(구조 불변식). build green 재확인.
- 🟠 **[결정대기] #1 `FACT_BUDGET.PLAN_BUDGET_YEAR` (현재 NULL)**: 원천 `ERP_BUDGET`에 `CHN_BUDGET_AMT`(추경)·`ADJ_BUDGET_AMT`(조정) 실재하나 GOLD FACT_BUDGET 대응 슬롯 부재. **`PLAN_BUDGET_YEAR`(연 편성)에 추경/조정 주입은 의미론적 오류**(개정버전≠연편성) + FACT_BUDGET 헤더 "재무 오귀속 방지" 원칙 위배. → **임의 매핑 금지.** 올바른 처리 = ①GOLD DDL에 추경/조정 전용 슬롯 신설(시맨틱 계약 변경) 또는 ②소비 정의 확정. 설계결정 문서30 §6. **순수 내부 기계작업 아님(설계/시맨틱 결정 필요).**
- ⏳ **[Q10 게이트] #2 `FACT_AD_PERFORMANCE` 캠페인 이름매칭 PoC**: AGENCY.CAMPAIGN_NM ↔ CRM_CAMPAIGN.CMPGN_NM 실구현은 Q10(현업 연결키 회신) 대기. 진단 PoC만 가능 → 실구현 제외.
- **결론**: bronze 데이터·설계로직만으로 안전 진행 가능한 내부작업은 #3로 종료. #1(설계결정)·#2(Q10)는 외부/결정 의존.

## 🟡 [순서9-C] GOLD 완성 진행 요건 — 내부분 착수·검증 완료 / 잔여 외부의존
파이프라인 골격(SILVER 32 + GOLD 24 base + WIDE 9 + build green) 완성. **내부 가능분은 순서9-C에서 작성·build 검증 완료(PASS=27 WARN=1 ERROR=0)**:
- ✅ **작성완료**: `DIM_BUDGET_ITEM`(2,041) · `DIM_AD_CREATIVE`(8,474) · `FACT_BUDGET`(24,480, 편성/집행만) · `FACT_AD_PERFORMANCE`(235,572, 스캐폴드: measure/날짜만·차원FK=0) · **#80 `FACT_MEMBER_MONTHLY.UNPAID_FLAG_EOM/BOM`**(미납 EOM=true 3,302,535).
- ✅ **이슈 E 진단완료**: 고아 99.98% 참여상세·동일기간·동일형식 → **마스터 누락(외부)** 확정. 내부 수정 불가·warn 유지.
- ✅ **데이터기반 설계결정**: A-2 `_SOURCE_SYSTEM='AGENCY'` 상수(매체구분은 속성) · DEVICE_TYPE PC/M(APP 휴면).
- ⏳ **잔여 외부 원천 입고**: `FACT_BUDGET.FUNDRAISING_COST`(E-1)·`.AD_COST`(E-4) · `FACT_TARGET_BIZ`(E-6) · GA4 분석(G-5) · 회원 마스터 전량입고(BLOCKING-1).
- ⏳ **잔여 현업 회신**: `FACT_AD_PERFORMANCE` CAMPAIGN_SK(Q10)·AD_CREATIVE_SK(소재 부분키) · 이슈 A/C/D.
  - ✅ **[해소 순서9-I 2026-07-28] DEVICE_SK 매핑**: 현업 회신 불요 — 실측으로 AGENCY device 도메인이 `DIM_DEVICE` 와 **네이티브 동일**(M/PC) 확인, 방송 NULL 37,886은 기기 개념 부재로 `(해당없음)` 멤버 신설(DEC-10). 실배선 후 `DEVICE_SK=0` **0건** → 지표 공14 사용 가능.
  - 🟡 **GA_CONV(O5) 부분해소**: `GA_CONV_MEMBERS`(명) 분자 확정분은 유지. 단 **O16 발견으로 재방송 개발실적 혼입을 분리**(코어=디지털 전용) → 합계가 GA_CONV_MEMBERS 171,645→122,551 · GA_CONV_CNT 159,693.9→63,372.9 로 **감소**. `GA_CONV_CNT` 어의(건/VU) 현업 확인은 **여전히 잔여**.
- 🔜 **다음 세션(내부 가능)**: WIDE VIEW 9종 dbt view화 + COMMENT(`03_top-down_gold/10_...sql`) → BLOCKING-4 해소.
- **요건 총괄표(정본)**: `10_dbt_pipeline/00_배포운영_통합_20260715.md` **§7**.

## 🟢 배포 미반영 (하위: 위 BLOCKING-3 로 격상)
순서 9·9-B 편집은 **워크스페이스 직접실행 검증만** 완료. ~~배포객체 `ALTER DBT PROJECT ... ADD VERSION` 미반영~~ → **실측 결과 객체 자체 부재로 BLOCKING-3 로 통합.** 최초 `CREATE` 후 이후 편집분은 `ADD VERSION` 으로 반영.

## ✅ [DONE 순서9-C 2026-07-15] dbt project 배포 + full build green 달성
**배포**: `CREATE DBT PROJECT GN_DW.OPS.DW_PIPELINE` (운영 전용 스키마 — 데이터 레이어 SILVER/GOLD와 분리, 접두어 중복·스코프 오칭 제거). 50 models(SILVER 32+GOLD 18, 07-15 시점)·153 data tests. *(이후 GOLD 확장: dim15+fact9+WIDE9 → 전체 65 models, 2026-07-16)*

**첫 build 에서 드러난 17 ERROR 처리** (153-test ERD suite가 배포 전 한 번도 실행 안 됨 → 잠재버그 일괄 표면화):
| 분류 | 건수 | 조치 |
|---|---|---|
| ① 테스트 정의 버그 (존재하지 않는 컬럼 not_null) | 7 | GA4_DEVICE→`DEVICE_TYPE`, GA4_TRAFFIC_SOURCE→테스트 제거, AGENCY/ERP→실제 `*_DK`/`AD_DATE` 로 교정 |
| ② `unique_GA4_EVENT_DIM_EVENT_NAME` 오탐(35) | 1 | **잘못된 unique 테스트 제거**(EVENT_NAME 은 브리지 grain상 다중행 정상). ※ 최초 시도한 "모델 EVENT_NAME 축약"은 GOLD DIM_GA_EVENT 의 (cat,label,action) 조합 커버리지를 파괴해 **원복** |
| ③ 참조무결성 실패 (E 263,611 포함) | 9 | `severity:warn` 강등 (메달리온 BP: 알려진 원천 미완전은 warn 관측, error 는 구조 불변식만) |

**결과**: full `dbt build` → **PASS=181 WARN=21 ERROR=0 SKIP=0** (2026-07-15 실측 검증). 50 models 전량 SUCCESS. ⚠️ ②원복분 재배포·DIM_GA_EVENT 정리는 아래 참조.

### ⚠️ 아키텍처 비평 · 보수적 주석 (누락 금지 후속검토)
- **E 23% warn 전환 리스크**: 참여 팩트의 23%가 이벤트 마스터 고아 = 단순 "known gap" 이상. GOLD `FACT_EVENT_PARTICIPATION` 이 `COALESCE(EVENT_SK,0)` 로 Unknown(SK=0) 라우팅하므로 **분석 파손은 없으나**, 23% 가 Unknown 이벤트로 집계됨 = 분석 한계. **근본원인(마스터 누락 vs 키체계) 진단 최우선.** warn→error 복귀 조건: 마스터 전량입고/키체계 확정.
- **`GA4_EVENT_DIM` = (event_name×cat×label×action) 브리지 grain 유지**: GOLD `DIM_GA_EVENT` 가 여기서 distinct (cat,label,action) 추출 → **조합 커버리지 필수**. `unique(EVENT_NAME)` 은 오탐이라 제거(모델 원복). **사고교훈**: 다운스트림(merge 차원) 추적 없이 상류 grain 변경 금지. **merge 차원(GOLD dim)은 pre-hook TRUNCATE 없어 상류 grain 변경 시 stale 행 잔존**(R1) → 중간빌드 잔재로 `GOLD.DIM_GA_EVENT` 2,842→2,846. **✅ [2026-07-16 해소] 실측 `GOLD.DIM_GA_EVENT`=2,842(목표 복원 확인)** → 잔재 정리 완료. **R1 표준 대응(2026-07-16 확립)**: 완전 재산출 차원은 merge 대신 **append+pre-hook TRUNCATE**(fact 패턴)로 전환하면 grain 변경에도 잔존행 원천 차단 — `DIM_MEMBER`가 이 패턴으로 SCD2 활성화(D2). 나머지 merge 차원도 grain 변경 이력 있으면 동일 검토 권장.
- **`AGENCY_AD_PERFORMANCE.AD_DATE` not_null**: ✅ **[DONE 순서9-D]** 실측 널 0/235,572 확인 → `severity:warn` 제거·error 승격(구조 불변식). (참고: CREATIVE_DK·BUDGET_ITEM_DK 는 COALESCE-해시 생성이라 구조상 non-null → error 유지 안전.)
- **프로세스 교훈**: 테스트는 저작만으로 검증된 게 아님 — 반드시 `build`(run+test)로 실행해야 잠재버그가 드러남(`run` 단독 금지, 통합 문서 R2).

### warn→error 복귀 추적표 (마스터 전량입고/확정 시)
| 대상 | 파일 | 현 severity | 복귀 트리거 |
|---|---|---|---|
| EVENT_KEY→CRM_EVENT (이슈 E) | `_crm_schema.yml` | warn | 마스터/키체계 확정 |
| SNDNG_KEY→CRM_SEND_REQUEST ×2 | `_crm_schema.yml` | warn | 발송요청 마스터 전량입고 |
| SPNSR_BSNS_ID→CRM_SPONSORSHIP ×2 | `_crm_schema.yml` | warn | 후원사업 마스터 전량입고 |
| CMPGN_CD→CRM_CAMPAIGN ×2 | `_crm_schema.yml` | warn | 캠페인 마스터 확정 |
| not_null MBER_NO ×2 (SEND_MEMBER 745·PAYMENT_BILLING 5) | `_crm_schema.yml` | warn | 이슈 B/D 판정·마스터 재추출 |
| MBER_NO/MEMBER_DK→CRM_MEMBER 다수 (BLOCKING-1) | `_crm_schema.yml`·`_gold_ready_schema.yml`·bridge·ga4 | warn | 회원 마스터 전량입고 |
| ~~AGENCY_AD_PERFORMANCE.AD_DATE not_null~~ | `_silver_bridge_schema.yml` | ✅ **error (순서9-D 승격완료)** | ~~널 여부 실데이터 검증~~ 완료(0/235,572) |

### 🟢 WARN 27건 전량 목록 (2026-08-07 실측 · `PASS=375 WARN=27 ERROR=0 SKIP=0 TOTAL=402`)

> 🔴 **이 표가 없어서 같은 질문이 두 번 나왔다.** 위 추적표는 **그룹 단위**(「다수」·「×2」)라
> 「WARN 이 27인데 그 27이 무엇인가」에 답하지 못했다. 전량 목록을 정본으로 고정한다.
> 분류 근거·근본원인은 `00_INDEX_이슈원장.md` **O41 §잔여①**(SILVER 21 + GOLD 6 = 27 · 고아 회원 **9,247명** 단일 원인).
> ⚠️ **WARN 값을 해석하기 전에 그 테스트의 `where` 필터를 먼저 읽을 것** — 분모를 모르면 값의 의미를 모른다(P85 계열).

| # | 테스트 | WARN | 계열 | 복귀 트리거 |
|---:|---|---:|---|---|
| 1 | `relationships CRM_EVENT_PARTICIPATION.EVENT_KEY → CRM_EVENT` | 263,611 | 이슈 E | 이벤트 마스터/키체계 확정 |
| 2 | `relationships CRM_SEND_MEMBER.SNDNG_KEY → CRM_SEND_REQUEST` | 11,313 | 발송요청 | 발송요청 마스터 전량입고 |
| 3 | `relationships CRM_SEND_RESULT.SNDNG_KEY → CRM_SEND_REQUEST` | 9 | 발송요청 | 〃 |
| 4 | `relationships CRM_CAMPAIGN.SPNSR_BSNS_ID → CRM_SPONSORSHIP` | 18,091 | 후원사업 | 후원사업 마스터 전량입고 |
| 5 | `relationships CRM_PAYMENT_BILLING.SPNSR_BSNS_ID → CRM_SPONSORSHIP` | 1 | 후원사업 | 〃 |
| 6 | `relationships CRM_MEMBER.CMPGN_CD → CRM_CAMPAIGN` | 4 | 캠페인 | 캠페인 마스터 확정 |
| 7 | `relationships CRM_MEMBER_DEV.CMPGN_CD → CRM_CAMPAIGN` | 18 | 캠페인 | 〃 |
| 8 | `not_null CRM_SEND_MEMBER.MBER_NO` | 745 | 이슈 B/D | 마스터 재추출·불량ID 판정 |
| 9 | `not_null CRM_PAYMENT_BILLING.MBER_NO` | 5 | 이슈 B/D | 〃 |
| 10 | `not_null CRM_PAYMENT_BILLING.RQEST_RST_CD` ⚠️`where PAY_STAT_CD='F'` | 1,096 | O17 W1 사유 커버리지 | 사유 커버리지 회귀 감지용(0.018%) |
| 11 | `not_null CRM_CAMPAIGN.CMPGN_TYPE1_NM` ⚠️`where CMPGN_TYPE1_BSN IS NOT NULL` | 740 | 순서9-C 캠페인축 | 기지 고아(코드 4종) |
| 12 | `not_null CRM_CAMPAIGN.CMPGN_CTGR_NM` | 23 | 순서9-C 캠페인축 | 기지 고아 |
| 13 | `accepted_values FACT_EVENT_PARTICIPATION.PART_STATUS` | 1 | 🟡 **실결함 — 2026-08-07 행 특정 완료** | 오염값 **`)` 2행**(distinct 1로 보고). 🔴 **[2026-08-11 O59-G 정정] 「4행 전량」은 2/9 표본이었다 — 실제 사고는 18행**(TEXT 6컬럼 `)` 12행 + 같은 사고 빈값 6행 · 전량 표는 문서20 §I-2 #4). 🔴 **`MBER_NO=')'` 2행은 GOLD 까지 라이브이고 `DIM_MEMBER` 매칭 0 = 고아 참조**(신규 · O59-G). 아래는 그 중 `PART_STATUS` 축 4행이다: ✅ **BRONZE 원본까지 4행 식별**: `TD_MS_EVENT_PRTCPNT_DTL` — 회원 `0526424`×행사 `118`(SEQ 1087 NULL·1138 `)`) · 회원 `1377663`×행사 `153`(SEQ 3787 NULL·3839 `)`). **4행 전부 2024-02-14 · `FRST_RGSTR_ID='HomePage'` · `DIV/CHNL/PATH` = 100/100/200 동일** → 단일 입력 사고. 🟢 **정정값 후보 = `110`** — 두 행사의 정상값이 `110` **단일**(118: 2,598행 · 153: 5,174행 = **7,772/7,772 = 100%**). 🔴 인접 컬럼 전건 정상이라 **필드 밀림 아님**(O28 재분류 재확인). ⇒ **원천 정정 요청**(우리가 원천을 못 고친다) vs 센티넬 라우팅 결정 · 상세 = 00 §O28 |
| 14~22 | `relationships *.MBER_NO → CRM_MEMBER` **SILVER 9건** — `CRM_SEND_MEMBER` 31,486 · `CRM_EVENT_PARTICIPATION` 9,480 · `CRM_PAYMENT_BILLING` 309 · `CRM_MEMBER_DEV` 270 · `GA4_IDENTITY` 172 · `CRM_MEMBER_STATUS_HIST` 85 · `CRM_PAYMENT_METHOD` 37 · `CRM_MEMBER_DISCONTINUE` 1 · `CRM_MEMBER_RESPONSOR` 1 | 41,841 | **BLOCKING-1** | 회원 마스터 전량입고 |
| 23~27 | `relationships *.MEMBER_DK → DIM_MEMBER` **GOLD 5건** — `FACT_SERVICE_EVENT` 31,486 · `FACT_EVENT_PARTICIPATION` 9,480 · `FACT_MEMBER_EVENT` 271 · `FACT_MEMBER_MONTHLY` 199 · `FACT_MEMBER_COHORT` 16 | 41,452 | **BLOCKING-1 하류 전파** | 〃 |

**해석**
- 🟢 **27건 중 26건이 「알려진 외부 원천 미완전」**이고, 그중 **14건(SILVER 9 + GOLD 5)이 단일 원인** — 고아 회원 **9,247명**이 BRONZE 회원 마스터에 부재(O41 실측: 존재 0명·부재 9,247명, BRONZE 키 1,763,065 = SILVER `CRM_MEMBER` 1,763,065 완전 일치 → SILVER 로직 결함 아님).
- 🟡 **실결함은 1건뿐** = #13 `PART_STATUS` 오염값 `)` 2행(O28 잔여 · **테스트가 보는 축 기준**이며 원천 사고 규모는 **18행** = O59-G). 🔴 이 테스트는 STAT 축만 보므로 **나머지 16행은 dbt 로 드러나지 않는다.**
- 🟢 **2026-08-07 재확인 — 회귀 0**: 오늘 build 의 WARN 27 을 로그에서 전량 추출해 O41 기재 기지값과 대조, **항목·건수 전량 일치**. ⚠️ 구 실행분 로그는 `dbt.log.1` 로 로테이션돼 로그 대 로그 대조는 불가 — 문서 기재값 대조로 검증했다.
- 🔴 **추적표 미등재였던 것 4건**(#10·#11·#12·#13) 과 **누락 1건**(#27 `FACT_MEMBER_COHORT` — O37 신설 팩트라 추적표가 「FMM·FEP·FME·FSE 4건」으로 굳어 있었다) 을 이 표로 흡수했다.

## ✅ [DONE 2026-07-15] 검토 항목 4 — 정제규칙 drift 없음
SILVER 32모델 ↔ `04_silver_design/09_SILVER_적재쿼리_20260714.sql`(912줄) 정밀 대조 완료. **drift 0건 → 수정 없음.**
- CRM 21/21·ERP 3/3·AGENCY 2/2·GA4 5/5·bridge 1/1 일치.
- GA4는 정본 주석대로 단일샤드→`ga4_union_shards` 매크로(전기간 UNION)로 업그레이드(의도된 설계).
- 결론: 09 정본 이후 SILVER drift 없음. 순서 9-B 검토 전 항목 완료.

## 🔜 [G-5 게이트] SILVER identity 2모델 — merge 전략 전환 (전기간 샤드 입고 시)
> 트리거: **G-5(GA4 전기간 샤드 입고) 확정 시점.** 그 전까지는 현행 유지(착수 불요).

**배경(아키텍처 검토 2026-07-15)**: `GA4_IDENTITY`·`IDENTITY_MEMBER_XREF`는 grain=`user_pseudo_id`. 활성 회원은 기기·쿠키이탈(ITP 7일 만료·시크릿 등)로 pseudo가 지속 증가 → 두 모델은 계속 성장. 현재는 프로젝트 SILVER 설정(`incremental_strategy: append` + `pre-hook: TRUNCATE` + `ga4_union_shards(var)` 윈도우)이 **매 실행 TRUNCATE 후 윈도우 전량 재계산**이라 크기에 상한은 걸리나, 전기간·상시운영 전환 시 **매 실행 전기간 재스캔 = 비용 급증**.
> GOLD `DIM_MEMBER_IDENTITY`·FACT(`IDENTITY_SK`)는 **회원 grain이라 pseudo 증가와 무관·bounded**(안전). 조치 대상은 SILVER pseudo-grain 2모델뿐.

**조치(G-5 시)**:
1. `GA4_IDENTITY`·`IDENTITY_MEMBER_XREF` → `incremental_strategy: merge`, `unique_key='USER_PSEUDO_ID'`(XREF는 동일), `pre-hook: TRUNCATE` 제거 → 신규 pseudo만 upsert(전량 재스캔 회피).
2. **보존/시점 정책** 결정: pseudo→member 매핑에 `VALID_FROM/VALID_TO`(SCD2) 부여 or 롤링 보존(예: 24개월).
3. **충돌·지연도착 규칙** 명문화: pseudo가 나중에 user_id 획득(NULL→DIRECT)·타회원 재매핑(공용기기, n_id≥2=CONFLICT) 시 last-wins/신뢰도 우선.
4. 성장 시 `CLUSTER BY`(member 또는 event_date)로 조인 프루닝 검토.
- **주의**: 이 전환은 프로젝트 SILVER 공통설정(append+TRUNCATE)과 다르므로 **모델별 config 오버라이드**로 격리(다른 SILVER 모델 영향 금지).
- **검증**: 전환 후 `dbt build --select GA4_IDENTITY IDENTITY_MEMBER_XREF` green + 행수 단조증가(재계산 아님) 확인.

> 참고: `DIM_MEMBER_IDENTITY`는 2026-07-15 세션에서 `enabled=true` 전환·XREF dedup 조인 배선 완료(문서40 E-6 인접). 위 §"결정 대기 GOLD 6"의 "disabled 유지 권고"는 이로써 갱신됨.
>
> **⚠️ [G-5 재확인·재실행 필수] identity 결선 다운스트림 3모델** — `DIM_MEMBER_IDENTITY`·`FACT_GA_BEHAVIOR`(IDENTITY_SK)·`WIDE_GA_BEHAVIOR`(IDENTITY_* 4컬럼)는 **GA4 1일 샤드(커버리지 4.22%, 매칭 1,274명) 기반으로 배선**된 상태. GA4 전기간 입고(G-5) 시 반드시: ① `GA4_IDENTITY`·`IDENTITY_MEMBER_XREF` 재적재 → ② `DIM_MEMBER_IDENTITY`·`FACT_GA_BEHAVIOR`·`WIDE_GA_BEHAVIOR` 재빌드 → ③ 매칭 커버리지·fan-out(IDENTITY_SK 유일성)·FK 무결성 재검증. 커버리지 급증으로 매칭수·grain이 크게 변동하므로 **1일 기반 수치를 확정치로 오인 금지**.

---
_생성: 순서 9-B 세션. 갱신 시 항목별 `[DONE]`·날짜 표기._
_Co-authored with CoCo_
