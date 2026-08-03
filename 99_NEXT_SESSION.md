<!-- LLM-METADATA
doc_id: NEXT_SESSION_HANDOFF
doc_role: 다음 세션 인수인계 — 착수 순서·필독 문서·미결 목록
project: GN_DW (굿네이버스)
written: 2026-08-03 (O27 세션 종료 시점 · 선행 O25·O26·DEC-27 갱신)
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 99. 다음 세션 인수인계

> **선행 세션(2026-08-03 후반) 요약**: **O27** = `99_NEXT_SESSION` §2-1 "SILVER→GOLD 컬럼 보존율" **최초 측정** 완료 → **DEC-28** 결정(A군 15 배선 · B군 6 DROP · `AGE_BAND` 판정 정정).
> 그 앞 세션: O25(코드체계 보존율) → O26(성별축 정본 위반) → DEC-26(컬럼정의서 코드 위상 강등) → DEC-27(분석가 GOLD 직접조회).
> **코드 변경은 아직 없다** — O27 은 **측정·판정·문서화까지**이며 `ALTER`/모델 수정/`dbt build` 는 미실행이다. 최종 빌드는 여전히 `PASS=312 WARN=25 ERROR=0 SKIP=0 TOTAL=337`.

> 🔴 **환경 주의 (2026-08-03 실측)**: 선행 세션 중 **워크스페이스 로컬 마운트(`/workspace`)가 I/O 오류로 사망**했다(복구 실패). 파일 읽기·쓰기는 **스테이지 경유**로 수행했다:
> `cortex ws ls|cp 'USER$.PUBLIC."snowflake_files":/<경로>'`. 마운트가 여전히 죽어 있으면 같은 경로를 쓰고, `cp` 는 **폴더 대상 업로드로 전체 파일 교체**임을 유의한다(부분 편집 불가 → 다운로드 → 로컬 수정 → 업로드).

---

## 0. 시작 전 필독 (읽지 않고 인용 금지)

| 문서 | 왜 |
|---|---|
| `20_issue/00_INDEX_이슈원장.md` §1 **거버넌스 변경 블록** | 🔴 **가장 먼저.** 작업 방식 자체가 바뀌었다(8항) |
| `20_issue/10_진단_원인분석.md` **§14** | 🔴 **O27 진단 정본** · 보존율 4원 대조 · A~E 판정군 · 교훈 **P34~P37** · 잔여 §14-F |
| `20_issue/10_진단_원인분석.md` **§13** | O25·O26·DEC-27 진단 정본 · 관문측정 G1~G5(⚠️2차 인용) · 교훈 P29~P33 |
| `20_issue/30_설계_의사결정.md` **§15~§18** | DEC-25(명명 2계층) · DEC-26(컬럼정의서 강등) · DEC-27(분석가 대응) · **DEC-28**(O27 결정·§18-D 판정 순서) |
| `20_issue/20_현업확인_요청.md` **§H** | CM017 성별축 — 회신 대기(차단 아님) |

> 📌 **문서가 길다고 끊지 말 것.** 잘리면 이어서 끝까지 읽는다.
> 📌 **추론으로 채우지 말 것.** 모르면 측정하거나 "모른다"고 쓴다. **비율은 분모를 병기**한다.
> 📌 **2차 인용 주의** — §13-A G1~G5 는 선행 세션 측정치의 인용이며 재측정된 바 없다. 반면 **§14 는 전 항목 본 세션 실측**이다.

---

## 1. 지금 이 순간의 상태 (실측, 2026-08-03)

| 대상 | 값 |
|---|---|
| `GOLD.DIM_MEMBER` | 7,925,716행 / 회원 1,763,065명 (SCD2 · 평균 4.50버전 · 최대 218) |
| `MEMBER_TYPE` | **100% 채움** — FDRM 1,587,343 / ONCE 175,722 |
| `GOLD.DIM_MEMBER_CURRENT` | dbt 뷰 · 1,763,065행 = 회원수 **1:1** · GRANT 자동(future grant) |
| `'미상'` 라벨 | 회원 차원 **0건**(상태·성별). **잔존은 `DIM_EVENT.EVENT_KIND_NAME` 1행뿐**(O27 재측정) |
| **SILVER→GOLD 보존율** | **54.7%** (199/364) · 탈락 165 = A15·B6·C1·D13·**E130 미판정** |
| **GOLD 물리 미주입** | **125 / 454 (27.5%)** = ALL_NULL 59 + ALL_ZERO 66 |
| WARN 25 | 전부 기존 고아키·not_null 계열 (⚠️ 집합 대조는 미실시 — 개수 일치 근거뿐) |

**분석가 안내 문구(그대로 전달 가능)** — 변경 없음
- 회원 속성은 **`GOLD.DIM_MEMBER_CURRENT`** 를 쓴다(1인 1행). `DIM_MEMBER` 직접 조인 금지 — 실측 3.60배 팬아웃(납입회비 171.3억→507.5억).
- 과거 시점 상태·예측 피처는 `DIM_MEMBER` 를 `EFFECTIVE_FROM`/`EFFECTIVE_TO` 로 **시점조인**.
- 상태 기반 모집단은 **`MEMBER_TYPE='FDRM'`** 한정(ONCE 는 상태 개념 부재).
- 회원상태(MM010)와 개발구분(MM015)은 **다른 축** — 둘 다 `후원중단` 을 갖지만 값이 다르다(958,668행 vs 1,010,680건).

---

## 2. 🔴 착수 순서

### 2-1. ✅ **완료** — SILVER→GOLD 보존율 측정 (O27)
정본 = **문서10 §14** · 판정표 = `30_output_share/08_SILVER→GOLD_보존율.csv`(519행). **재측정 불요.**
남은 것은 아래 2-2 의 **실행**과 **E군 130 판정**(2-5)이다.

### 2-2. 🔴 [최우선] A군 15 + DEC-27 7컬럼 통합 실행 [판정 완료 · 실행만 남음]
판정 정본 = **30 DEC-28 §18-A/§18-E** + **DEC-27 §17-C**. 두 목록은 겹치므로 **한 번에 처리**한다.

**판정 순서 규칙(DEC-28 §18-D — ② 신설)**: ①같은 역할 컬럼 有→DROP → **②대상 grain 에 함수종속하는가→아니면 DROP** → ③BRONZE/SILVER 근거 有→채움(커버리지 병기) → ④대표값 규칙 필요·확정 여부 → ⑤DROP

| 컬럼 | 판정 | 근거/제약 |
|---|---|---|
| `DIM_MEMBER.REGION` | **채움** | `CRM_MEMBER_DEV.AREA_NM` 99.4% · **CM018 18/18** · 다중 지역 3.2%(최대 7) → 대표값 규칙 필요 · sentinel `'0'` 20,624행 → `(미매핑)` |
| `DIM_MEMBER.AGE_BAND` | 🔴 **채움 (DEC-28 정정)** | `AGE` 는 raw 나이가 아니라 **CM014 12종 코드** · 100% · 12/12 일치 → **구간 창작 불요.** 종전 "보류" 판정은 전제가 틀렸다 |
| `DIM_MEMBER.LAST_STOP_DATE` | **채움** | `CRM_MEMBER_DISCONTINUE.SPNSR_DSCNTC_DE` 100%(1,038,262) `max` — 규칙 불요. LTV·유지기간(신4·6~8) 해금 |
| `DIM_MEMBER.FIRST_SPONSORSHIP` | **채움** | `CRM_MEMBER_DEV.SPNSR_BSNS_ID` 100%·29종 최소 발생일 |
| `DIM_MEMBER.NEW_EXISTING_FLAG` | **DROP** | 시점귀속(#113) → 차원 grain 부적합(②). 정소재지 = FMM |
| `DIM_MEMBER.LAST_CAMPAIGN` | **DROP** | 다중 캠페인 19.0%·최대 690 → 대표 규칙이 **O8 현업 미결**(④) · 소비처 0 |
| `DIM_MEMBER.CURRENT_SPONSORSHIP` | **DROP** | 동시 다중 후원 정상(14.2%·최대 14) → 단일값 불성립(②) |
| `DIM_SERVICE.SEND_TYPE_L/M/S` | 🔴 **결정 대기 (DROP 금지)** | **정본 지표 #133~135**(발송구분 대/중/소) — DROP 하면 지표 3개 소멸. `SEND_GBN_TOP` 값은 **`CRM_CODE.CD_ID` 자체**(MS046~MS055 12종)·MID 16·BOT 42·조합 65. 그러나 grain 10→74 함수종속 불성립(②)·커버리지 0.106% → **차원 재설계 결정 필요**(①grain확장 ②DIM_SEND_TYPE 분리, 둘 다 `SERVICE_SK` 파괴). 정본 30 §18-C |
| `DIM_AD_CREATIVE.DURATION_SEC` | **채움** | `AGENCY_AD_CREATIVE.AD_SEC_NM` 1,217/8,715=**14.0%**(VIDEO 전용) → 커버리지 병기(P18). 주석 *"원천 부재"* 는 **오진 → 회수**(P14) |
| `FEP.RECRUIT_CNT` | **채움** | `CRM_EVENT.RCRIT_PSNNL_CO` 88.8%·74종 (⚠️행사 속성이므로 `DIM_EVENT` 배속이 맞는지 먼저 판정) |
| `FMM.REGULAR_FEE` 외 2 · `DIM_PAYMENT.FEE_TYPE` | **채움 후보** | `CRM_PAYMENT_BILLING.MBRFEE_DIV_CD` 97.6%·4종 = **회비 정기/일시 분해의 원천**. ⚠️`FEE_TYPE` 이중표현은 설계 §8 결정 대기(④) |
| GOLD 상태전이 축 | **신설 후보** | `CRM_MEMBER_STATUS_HIST.BF_STAT_CD`/`BF_STAT_NM`/`CHN_STAT_NM` **100%·7,501,761·12종(MM010)** — 이탈·전이 분석이 현재 **불가** |
| `FACT_BUDGET` 추경·조정 | **결정 대기** | `ERP_BUDGET.CHN_BUDGET_AMT`·`ADJ_BUDGET_AMT` 99.3% 실재 → 원천은 있다. 슬롯 설계 = **문서30 §7** |
| `DIM_ORG.CORP/DIVISION/TEAM` | **기결정** | `CRM_ORG.UPPER_DEPT_ID` 100%·321종·6단 재귀. DEC-5 확정(TEAM=5th). 잔여 = 6레벨→4컬럼 매핑(설계 O16) |

🔴 **동시 수정 필수 — WIDE 소비처**: `REGION`·`AGE_BAND` 각 **4개**(MEMBER_MONTHLY·MEMBER_EVENT·EVENT_PARTICIPATION·SERVICE_EVENT) · `NEW_EXISTING_FLAG` **2개** · `FIRST/CURRENT_SPONSORSHIP` MEMBER_MONTHLY · `LAST_CAMPAIGN` **0개**.
🔴 **순서**: `ALTER TABLE ADD/DROP COLUMN` → 모델 수정(**CTE 컬럼열거 누락이 본 결손의 근본원인**) → WIDE → `06_DDL.sql`·`08_SILVER_테이블DDL` → **COMMENT DoD 3종(P33)** → `accepted_values` 가드 → build. **`CREATE OR REPLACE TABLE` 금지**(FK·GRANT 파괴).
🔴 **라벨은 `CRM_CODE` 조인**(하드코딩 `CASE` 금지 — P31/DEC-25) + **코드 컬럼 병설**(`AGE`·`AREA_CD`).

### 2-3. SV 갱신 + 재배포 [P19 결손 · 미해소]
- `member.MEMBER_STATUS_NAME` COMMENT 가 새 값 **`(해당없음)` 을 열거하지 않는다** → Analyst 가 `='미상'` 을 생성하면 **0행 무증상 오답**
- 신규 `MEMBER_TYPE` 을 **SV 차원으로 신설** 권장 → "정기회원만" 같은 모집단 한정이 자연어로 가능해진다
- 2-2 를 먼저 하면 `REGION`·`AGE_BAND` 차원도 함께 노출할 수 있다 → **SV 재배포를 2-2 뒤로 두는 것이 효율적**
- 실행: `05_SV-Agent_ai/05_SV_DDL.sql` 수정 후 **`GN_DW_ADMIN` 역할로 전체 실행**. §7 GRANT 가 같은 파일에 있어 자기완결적(522~539행)

### 2-4. P27/P29 대조 스캔 정례화 [🔴 필수 · 미착수]
컬럼정의서가 코드 정본이 아니게 되어(DEC-26) **대조가 코드 정본을 확정하는 유일한 수단**이다.
- 전 GOLD·SILVER 코드성 컬럼 ↔ `CRM_CODE` × 실적재 distinct 대조 스캔
- ⚠️ `USE_YN='Y'` 를 **필터로 쓰지 말 것** — 폐지코드가 실적재에 남아 라벨이 조용히 사라진다. 관측 축으로만 쓴다
- 🟢 **O27 이 이 스캔의 유용성을 실증했다** — `AGE`→CM014 · `AREA_CD`→CM018 확정이 전부 이 방식이었다. **CM014 는 컬럼정의서 미지정 그룹**이며 CM017 과 같은 유형이다

### 2-5. 🔴 E군 130 컬럼 개별 수요 판정 [O27 이 판정하지 않은 유일한 군]
정본 = `30_output_share/08_SILVER→GOLD_보존율.csv` 의 `판정군='E_미판정잔여'`.
분포: `GA4_EVENT` 20 · `CRM_MEMBER` 17 · `CRM_PAYMENT_METHOD` 12 · `CRM_CAMPAIGN` 11 · `CRM_MEMBER_AMT_CHANGE` 10 · `CRM_PAYMENT_BILLING` 10 · `AGENCY_AD_PERFORMANCE` 10 · 기타.
⚠️ **"좁은 팩트라 정당하다"고 근거 없이 적으면 P14 위반**이다. 각 컬럼에 대해 ①GOLD 대응 컬럼 존재 ②지표사전 수요 ③grain 적합성 3축으로 판정한다.

### 2-6. 이후 (문서10 §13-I · §14-F)
G3 라벨 미배선 잔여 **재계수 후** 배선("21"은 자기집계 인용값) · `SVL-1`·`SVL-2` 대조 확정 · 감사 정본 `06_BRONZE노출감사` 재생성(2026-07-28 이후 배선분 미반영) · 센티넬 표기 통일(`GENDER_NAME` NULL 421 + **`DIM_EVENT.EVENT_KIND_NAME` `'미상'` 1행 + `ELSE` 제거**) · **소비처 0 테이블 4종(28컬럼) 수요 확인**(§13-I #5 의 "3테이블"은 재계수 결과 **4테이블**)

---

## 3. 사용자(현업) 소관 — 코드로 해결 불가

| # | 항목 | 상태 |
|---|---|---|
| 1 | **CM017 성별축 확정** (공#130 값 일치하나 컬럼정의서 미지정) | 문서20 §H · 이미 적용·배포됨(차단 아님) |
| 2 | **O8 다중 캠페인 귀속 규칙** | 🔴 `FMM.CAMPAIGN_SK`·`LAST_CAMPAIGN` 배선을 직접 차단 |
| 3 | **O24 중단 이중원천** (동일 사건 이중기록인가) | 합산 금지 가드 배포됨 |
| 4 | **증액·감액 정의** (사건 기준 vs 월말 스냅샷) | 정본 공#150·#151·#38 |
| 5 | **`(건)` 단위** = 금액÷10,000 인가 행수인가 | P6 · 공#4 vs #149 |
| 6 | **생년월일(`MBER_BIRTHDAY`) 입고 요청** | ⚠️ **[DEC-28 사유 축소]** `AGE_BAND` 의 선행조건이 **아니다**(`AGE`=CM014 코드로 해결). 여전히 필요한 것은 **시점정확 연령** — SCD2 과거 버전의 당시 나이·LTV 연령 코호트 |
| 7 | **`DIM_PAYMENT.FEE_TYPE` 정기/일시 이중표현** | 🆕 원천(`MBRFEE_DIV_CD` 4종·97.6%)은 실재. 설계 §8 결정 필요 |
| 8 | **`DIM_SPONSORSHIP` 6종↔4그룹↔11개 매핑** | O19 · 문서20 §F-2 |

⚠️ **컬럼정의서 갱신 요청은 하지 않는다** — 갱신 의지 없음이 확인되어 코드 관련 위상을 참고본으로 강등했다(DEC-26). 문서를 기다리는 대신 **대조로 확정**한다.

---

## 4. 지뢰 (선행 세션에서 실제로 밟은 것)

| 함정 | 실측 |
|---|---|
| **컬럼명·주석·타입이 의미를 보증하지 않는다** | 🆕 `AGE` 는 이름·COMMENT("연령")·타입(NUMBER) **3개가 모두 연속형을 가리켰으나 12종 코드**였다. 그 오독 위에 판정 2건 + 외부 입고요청 1건이 서 있었다(**P36**) |
| **원천이 있어도 채우면 안 되는 경우가 있다** | 🆕 `SEND_TYPE_L/M/S` — grain 함수종속 불성립(10→74)·커버리지 0.106%. **grain 판정이 채움 판정보다 앞선다**(**P37**) |
| 🆕 **grain 부적합 ≠ DROP** | 같은 `SEND_TYPE_L/M/S` 를 처음 "DROP" 으로 판정했는데 **정본 지표 #133~135** 였다. grain 이 못 담는다는 것은 *컬럼을 버려라*가 아니라 *grain 을 다시 설계하라*는 뜻이다. DROP 전에 **지표사전·WIDE 노출을 반드시 역추적**할 것 |
| 🆕 **도메인이 작으면 대조가 무력하다** | `SNDNG_TY_CD` 는 값이 0/1/2/3 4종뿐이라 227개 코드그룹에 spurious 매칭 → **P29 3원 대조로도 확정 불가**. 대조의 판별력은 도메인 크기에 의존한다 |
| **계층별 보존율은 곱해진다** | 🆕 BRONZE→SILVER 37.6% 를 통과한 컬럼이 SILVER→GOLD 에서 **다시 45.3% 탈락**(**P34**) |
| **미주입 판정은 정적+동적 둘 다 필요** | 🆕 정적 스캔은 조인실패 NULL 을 놓치고, 동적 실측은 원천이 빈 정당한 NULL 과 구별 못 한다(**P35**) |
| `COUNT(col)` 로 적재 판정 | 0 상수 주입군을 "적재됨"으로 오판 → **`COUNT_IF(col<>0)` 병행 필수** |
| `DIM_MEMBER` 직접 조인 | 3.60배 팬아웃 · 금액 2.96배 과대 · **에러 없음** |
| `ALTER TABLE RENAME COLUMN` | **구 COMMENT 를 승계**한다 → 물리 16컬럼이 낡아 있었다(P33) |
| DDL 정본 수정 | `CREATE OR REPLACE` 금지라 **물리에 전파되지 않는다** → 별도 `ALTER … COMMENT` 필요 |
| 뷰 COMMENT | 물리만 고치면 **다음 빌드가 되돌린다**(소유주 = 모델 `post_hook`) |
| `COALESCE(라벨,'미상')` | **개념 부재를 결측으로 뭉갠다**(DEC-17-B 창작금지 위반) |
| `ERROR=0` | 의도한 대상이 실행됐음을 뜻하지 않는다(`--select` 오지정 시 TOTAL=15 인데도 ERROR=0) |
| 계층별 소유주 혼동 | GOLD **테이블**=`06_DDL.sql` / GOLD **뷰**=dbt 모델 / SERVING 헬퍼뷰=`02_SERVING_setup`·`08_After_Deploy_DBT` |
| GOLD 뷰 GRANT | **수동 부여 불요** — GOLD 스키마 VIEW future grant 로 매 build 자동 |
| 🆕 워크스페이스 마운트 사망 | `/workspace` I/O 오류 → **`cortex ws cp` 스테이지 경유**로 우회. `cp` 는 전체 파일 교체 |

---

## 5. 세션 시작 시 붙여넣을 프롬프트

```
GN_DW 프로젝트를 이어서 진행한다. 먼저 99_NEXT_SESSION.md 를 끝까지 정독하고,
§0 필독 문서(이슈원장 §1 거버넌스 블록 · 문서10 §14 → §13 · 문서30 §15~18 · 문서20 §H)를
읽은 뒤 §2 착수 순서대로 진행해줘.

§2-1(SILVER→GOLD 보존율 측정)은 완료됐다 — 정본은 문서10 §14, 판정표는
30_output_share/08_SILVER→GOLD_보존율.csv 다. 재측정하지 말고 인용해라.

최우선은 §2-2 "A군 15 + DEC-27 7컬럼 통합 실행"이다. 판정은 이미 끝났고
실행(ALTER → 모델 → WIDE → DDL 정본 → COMMENT → 가드)만 남았다.
DEC-28 §18-D 의 판정 순서(grain 판정이 채움 판정보다 앞선다)를 반드시 적용해라.

작업 원칙:
- 문서가 길다고 끊지 말고 끝까지 읽어라. 추론으로 채우지 말고 모르면 측정하거나
  모른다고 말해라. 수치를 인용할 때는 재측정했는지 밝히고 분모를 함께 적어라.
- 컬럼 의미는 이름·주석·타입으로 판단하지 말고 count(distinct)+값 열거로 확정하고,
  해석이 맞는지 독립 축과 교차검증해라(P36).
- 코드그룹은 문서를 믿지 말고 CRM_CODE × 실적재 distinct × 지표사전 3원 대조로
  확정하고, 판정 근거를 COMMENT 에 남겨라(DEC-26/P29).
- 컬럼 개명·값체계 변경은 ① 물리 ALTER COMMENT ② 소유 산출물(뷰=모델 post_hook,
  테이블=DDL 정본) ③ 거짓이 된 기존 경고문 회수 3종을 모두 하고, 완료 판정은
  INFORMATION_SCHEMA 스캔으로 해라(P33).
- CREATE OR REPLACE TABLE/SEMANTIC VIEW 는 FK·GRANT 를 파괴한다. ALTER 를 써라.
- /workspace 마운트가 죽어 있으면 cortex ws cp 로 스테이지 경유해라(§0 환경 주의).
- dbt build 와 05_SV_DDL.sql 실행은 내가 직접 한다. 그 전까지의 작업만 하고,
  실행이 필요하면 무엇을 왜 실행해야 하는지 알려줘.
- 작업 후 반드시 자기검토해라. 선행 세션들은 자기 규칙을 스스로 위반한 오류를
  매번 만들었고 검토에서 잡았다.
```

---
_Co-authored with CoCo_
