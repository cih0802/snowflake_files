<!-- LLM-METADATA
doc_id: GN_DW_SOURCE_GAP_ANALYSIS
doc_role: 원천 결손(Gap) 분석 — 무엇이 왜 안 되는가 · 누가 풀어야 하는가 (현업/IT 공유)
project: GN_DW (굿네이버스)
created: 2026-07-16
rewritten: 2026-08-06 (구 판본은 30_output_share/_archive/202607/ 로 이관)
companion: 30_output_share/04_컬럼계보매핑.md · 06_BRONZE노출감사.md · 20_issue/00_INDEX_이슈원장.md (이슈 정본)
grounded_on: GOLD 386 DATA 컬럼 census(COUNT/COUNT_IF) 실측 2026-08-06 + BRONZE 1,162 컬럼 노출감사 + 20_issue/{00,40,50}.md
updated: 2026-08-06 (O45 조립축 신설 반영 — 회비 팩트·획득 귀속축·마케팅캠페인축 · 수기 문서이므로 구조 변경 시 함께 갱신 필요)
END-METADATA -->

# GN_DW 원천 결손(Gap) 분석

> **목적**: GOLD 표준 지표를 채우려면 **무엇이 더 필요한지**, 그리고 그것이 **누가 풀 문제인지**를 구분한다.
> **읽는 법**: 결손을 「원인」별로 나눈다 — 같은 「값이 없다」라도 *원천에 항목이 없는 것*과
> *원천은 있는데 배선이 안 된 것*은 해소 주체와 난이도가 완전히 다르다.
> **상태**: 🔴 하드블로커(외부 입고 필수) · 🟠 결정·회신 대기 · 🟡 내부 구현 가능 · ⚫ 제외

> 🔴 **이 문서의 결손 규모는 추정이 아니라 실측입니다** — GOLD 386개 DATA 컬럼 전수에
> `COUNT`/`COUNT_IF(<>0)` 를 돌려 판정했습니다(2026-08-06). 컬럼 COMMENT 나 설계 문서를 근거로
> "값이 있다/없다"를 단정한 항목은 없습니다.

---

## 0. 한눈에 (결손 대시보드)

### 실측 규모

| 구분 | 건수 | 비중 |
|---|---:|---:|
| GOLD DATA 컬럼 (감사컬럼 `DW_*` 제외) | **411** | 100% |
| 값이 들어온 컬럼 | **306** | 74.5% |
| **전건 `0`** (설계O · 값 미주입) | **61** | 14.8% |
| **전건 `NULL`** | **36** | 8.8% |
| 0행 테이블(`FACT_TARGET_BIZ`)의 컬럼 | **8** | 1.9% |
| **미주입 합계** | **105** | **25.5%** |

> 🔴 **종전 판본은 `106/386 = 27.5%` 였다.** 분모가 커진 것은 O45 신규 객체(`FACT_MEMBER_FEE`·
> `DIM_MARKETING_CAMPAIGN`) 때문이고, **그 신규 컬럼에는 미주입이 0** 이다(census 실측).
> 미주입이 1건 줄어든 이유는 아래 D 절 참조 — `FACT_MEMBER_EVENT.SPONSORSHIP_SK` 가 실배선됐다.

### 원인별 분류

> 🔴 **합계 검산**: A 18 + B 51 + C 11 + D **13** + E 4 + F 8 = **105** = 위 미주입 합계와 일치한다.
> (P67 — 합계 일치만으로 내역이 옳다고 볼 수는 없으나, **어긋나면 배정이 틀린 것은 확실하다**.)

| 결손 유형 | GOLD 컬럼 | 대표 항목 | 해소 주체 |
|---|---:|---|---|
| **A. 원천에 항목 자체가 없음** | **18** | 사업목표 8종(E-6)·모금성비용/광고비/연편성/집행추정 4종(E-1/E-4)·오픈율(C-9-R)·공휴일(HOL-1)·전환콜(AD-5)·인바운드/TS콜(C-8) | 🔴 **외부 입고** |
| **B. 원천은 있으나 산출 로직 미구현** | **51** | 활동회원 8종·미납 카운트 3종·증액/감액/이탈 4종·발송 성공/실패·서신·선물금·+5일 코호트 8종·회원 구간·플래그 | 🟡 **내부 구현**(일부 규칙 확정 선행) |
| **C. 코드체계 미확정으로 확정 불가** | **11** | 행사 참여 상태별 카운트·횟수·플래그(O28) | 🟠 **현업 확인** |
| **D. 연결키 부재(조인 불가)** | **13** | `CAMPAIGN_SK` 6종·`SPONSORSHIP_SK` **3종**·`ORG_SK` 2종·`PAYMENT_SK`·`AD_CREATIVE_SK` | 🔴 **연결키 회신(Q10·O8)** |
| **E. 산출규칙 미확정** | **4** | `DIM_ORG.CORP`·`DIVISION`·`TEAM`(CONF-4) · `DIM_PAYMENT.FEE_TYPE` | 🟠 **현업 확정** |
| **F. 적재 범위·시점 결손** | **8** | GA4 세션시간·이탈율(G-5) · 신원브리지 2종 · 광고소재 속성 3종 · 행사 신청채널 | 🔴 **입고 범위 확대** |

> 위 6개 버킷의 합은 **18+51+11+13+4+8 = 105** 으로 실측 미주입 건수와 정확히 일치한다(전량 배정 · 누락 0).
> 🔴 **[2026-08-07 정정] 종전 이 줄은 `D 14 · 합 106` 이었다** — 같은 문서 §0 이 이미 `D 13 · 105` 로
> 갱신됐는데 이 검산 줄만 구판이 남아 **문서 내부가 서로 어긋났다**. 재실측으로 105 확정
> (census 2026-08-07: DATA 컬럼 411 · 값있음 306 · 전건0 61 · 전건NULL 36 · 0행테이블 8 → 미주입 **105**).
> ⚠️ 검산 줄은 **분류 표와 같은 값을 다시 쓰는 곳**이라 갱신을 빠뜨리기 쉽다(P67 계열).
> 컬럼 단위 배정 결과는 **§부록** 에 전량 열거한다.

> **핵심**: 외부 입고 없이는 못 채우는 하드블로커는 여전히 **① 사업목표(E-6) · ② 모금성비용·광고비(E-1/E-4) ·
> ③ GA4 전기간(G-5) · ④ 캠페인 연결키(Q10)** 4건으로 수렴한다.
> 여기에 ML 요건 대조에서 추가된 **⑤ 오픈율(C-9-R) · ⑥ 공휴일(HOL-1) · ⑦ VIDEO 개발실적(AD-5)** 3건이 있다.

---

## A. 원천에 항목 자체가 없음 🔴

> 설계·실행으로 앞당길 수 없다. 현업/IT/대행사 입고가 유일한 해소책이다.

| ID | 필요 데이터 | GOLD 타깃 | 실측 상태 | 필요 조치 |
|---|---|---|---|---|
| **E-6** | **CRM** 사업목표(연사업·추경, 단위=건) | `FACT_TARGET_BIZ` 8컬럼 · `WIDE_TARGET_BIZ` | **테이블 0행** | 신규 입고 — 입고요청서 `20_issue/41_*.md` 발행·**회신 대기**. 🔴 원천은 **ERP 가 아니라 CRM** 이다(2026-07-20 정정) |
| **E-1** | 모금성비용(원) | `FACT_BUDGET.FUNDRAISING_COST` | **전건 NULL** | ERP 예산원장에 컬럼이 없음 → 대행사 비용 보강 입고 |
| **E-4** | 광고비(원, 캠페인/매체 단위) | `FACT_BUDGET.AD_COST`·`EXEC_BUDGET_EST` | **전건 NULL** | 대행사 원천 연동. ⚠️ 광고비 자체는 `FACT_AD_*` 에 실적재돼 있다 — 결손은 **예산 팩트 쪽 슬롯**이다 |
| **C-9-R** | 발송 **오픈 여부·오픈율** | `FACT_SERVICE_EVENT.OPEN_MEMBERS` | **전건 0** (38,470,780행) | 🔴 BRONZE `TD_MS_EMAIL_LQY_SNDNG.URL_OTHBC_*` **전건 NULL** = 원천에 값이 없다. **ML 예측 3종(증액·충성·중단)이 이 Feature 에 의존** → 발송 시스템에 오픈 로깅 요청 |
| **HOL-1** | 한국 공휴일 일자 목록(대체공휴일 포함) | `DIM_DATE.IS_HOLIDAY` | **전건 `FALSE`** (16,437행) | 전 스키마에 원천 0. 외부 API(한국천문연구원 특일정보) 또는 사내 근무 캘린더 입고. ⚠️ WIDE 7종이 이 컬럼을 상속 → **「휴일 아님」으로 오독 위험** |
| **AD-5** | VIDEO 광고 **개발실적**(개발건수·개발회원수) | `FACT_AD_BROADCAST.CONV_CALL_CNT` 등 | **전건 NULL** | ⚠️ **미적재가 아니라 구조적 부재** — 대행사 비디오 리포트가 개발 항목을 보고하지 않는다. 재방송분은 산출 중. 미해소 시 방송 광고비의 **29%** 구간은 개발 효율 측정 불가 |
| **C-8** | 인바운드콜·TS콜 월간 수치 | `FACT_MEMBER_MONTHLY.INBOUND_CALL_CNT`·`TS_CALL_CNT` | **전건 0** | CRM 에 없는 비-시스템 지표 → 현업 별도 파일 입고(컬럼 자리만 존재) |

---

## B. 원천은 있으나 산출 로직 미구현 🟡

> **가장 큰 결손군이고, 외부 의존이 없다.** 「원천 부재」로 오해되기 쉬운데 실측하면 원천은 입고돼 있다.

| 지표군 | 미주입 컬럼 | 원천 실측 | 선행 조건 |
|---|---|---|---|
| **활동회원 카운트** | `FACT_MEMBER_MONTHLY` 의 `ACTIVE_CNT`·`ACTIVE_MEMBERS`·`ACTIVE_CUM_CNT`·`ACTIVE_CUM_MEMBERS`·`MONTH_END_ACTIVE_CNT`·`YEAR_START_ACTIVE_CNT`·`YEAR_END_ACTIVE_CNT`·`PREV_MONTH_END_ACTIVE_CNT` **8종 전건 0** | 🟢 `SILVER.CRM_MEMBER_STATUS_HIST` **7,501,761행** SCD2 완비 | 🟠 **CONF-3** — 정본 #51 월말활동회원 판정 조건이 내부 모순(중단 우세 vs 재후원 우세로 방향 상반) → **현업 확인 선행**. 확정 후 구현 가능 |
| **미납 카운트** | `UNPAID_CNT`·`CAMPAIGN_UNPAID_CNT`·`STATUS_UNPAID_CNT` **3종 전건 0** | 🟢 `UNPAID_FLAG_EOM` 은 **실적재**(TRUE 존재) · 미납 **금액**·**회원수**도 산출됨 | 🟠 **CONF-2** — 정본 `(건)` 은 건수가 아니라 **약정금액 ÷ 10,000** 이다. 기존 컬럼 재사용 시 정의 파괴 → 신규 컬럼 필요 |
| **증액·감액·이탈 카운트** | `INCREASE_CNT`·`INCREASE_MEMBERS`·`DECREASE_CNT`·`CHURN_CNT` **4종 전건 0** | 🟢 `SILVER.CRM_MEMBER_AMT_CHANGE` **324,947행** · `FACT_MEMBER_EVENT` 에 개발구분 5종 실적재 | 🟡 월 롤업 배선만 남음. ⚠️ 원천 `RDCAMT_YN` 은 현업이 직접 불신을 명시했으므로 **`DVLP_DIV_CD`(MM015)를 권위 원천으로** 쓸 것 |
| **발송 성공·실패** | `SUCCESS_MEMBERS`·`FAIL_MEMBERS` **전건 0** | 🟢 `SNDNG_RST_CD` 실적재(값 존재) | 🟠 **채널별 성공/실패 코드 매핑 업무 확정** 선행 |
| **서신·선물금 참여 / +5일 코호트** | `LETTER_PART_CNT/MEMBERS`·`GIFT_PART_MEMBERS/AMT`·`SERVICE_CNT/MEMBERS`·`D5_*` 8종 **전건 0** | 🟢 `SILVER.CRM_RELATION_ACTIVITY` **388,153행** | 🟡 코호트 조인 로직 구현 |
| **미납중단** | `FACT_MEMBER_EVENT.UNPAID_STOP_CNT`·`UNPAID_STOP_MEMBERS` **전건 0** | 🟢 중단사유(MM005) 실적재 | 🟡 사유 기반 분류 배선 |
| **회비 정기/일시 분해** | `REGULAR_FEE`·`SPONSOR_MONTHS`·`SPONSOR_YEARS`·`PAID_MONTHS` **전건 0** | 🟢 `MBRFEE_DIV_CD` SILVER 보존 완료 | 🟡 분해 배선 |
| **회원 구간·플래그** | `DEV_TYPE`·`NEW_FLAG`·`INCREASE_FLAG`·`REDONATE_FLAG`·`AMOUNT_BAND1/2`·`PERIOD_BAND1/2`·`NEW_EXISTING_FLAG`·`JOIN_DATE`·`STOP_DATE` **11종 전건 NULL** | 🟢 원천 실재 | 🟡 구간 정의 확정 후 배선 |

> 🔴 **이 표가 이 문서의 핵심입니다.** 미주입 106건 중 **51건이 외부 의존 없이 해소 가능**합니다.
> 종전 판본은 이 구분 없이 「원천 결손」으로 묶어 **외부 대기로 보이게** 했습니다.
> 실제로는 미주입 106건 중 **51건(48.1%)** 이 외부 의존 없이 해소 가능합니다.

---

## C. 코드체계 미확정으로 확정 불가 🟠

| ID | 결손 | 실측 | 왜 자동 검증에 안 걸리나 | 조치 |
|---|---|---|---|---|
| **O28** | `FACT_EVENT_PARTICIPATION` 상태별 카운트 **7종 전건 0**(`CONFIRM_CNT`·`WAIT_CNT`·`CANCEL_CNT`·`ABSENT_CNT`·`TOTAL_CNT`·`WAIT_TIMES`·`ABSENT_TIMES`) + `PARTICIPATION_TIMES`·`CUM_APPLY_TIMES`·`RECRUIT_CNT` | `SILVER.CRM_EVENT_PARTICIPATION.PARTCPT_STAT_CD` **1,134,126행**에 **두 코드체계가 혼입** — 캠페인행사는 소정수 `1~6`, 일반행사는 MS304 영문 퍼널(`Success`·`N_step_right`·`N_step_fail`) | 🔴 같은 테이블·같은 컬럼 안에서 갈린 형태다. **개명으로 해소 불가**하고 `accepted_values` 는 합집합을 통과시킨다 | 🟠 소정수 `1~6` 의 코드그룹 특정 = **현업 확인**. 판별자는 `EVENT_KEY` 접두(`EVENT_`/`CRMN_`)로 확정됨. 현재는 COMMENT 가드 배포 상태 |

> ⚠️ **무증상 오답 경로 2개**: ① `WHERE PART_STATUS='참여'` 가 **0행** 반환 ② 두 체계를 합산·GROUP BY 하면 집계가 조용히 틀린다.

---

## D. 연결키 부재 — 데이터는 있으나 조인 불가 🔴🟠

| ID | 결손 | 미주입 GOLD 컬럼(실측) | 원인 | 조치 |
|---|---|---|---|---|
| **Q10** | 예산 세세목 ↔ 캠페인 연결키 | `FACT_BUDGET.CAMPAIGN_SK` 전건 0 | 연결키 없음 | 🔴 현업 매핑키 회신. 부서 grain 까지는 진행 가능 |
| **Q10 파생** | 광고 소재 부분키 | `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` **전건 센티넬**(243,545/243,545) · `CAMPAIGN_SK` 전건 0 | 소재 연결키 미확보 | 🔴 이 때문에 `DIM_AD_CREATIVE`(8,716행, `MEDIA_NAME` 106종 실재)가 **도달 불가**하다 — 차원은 있는데 팩트에서 갈 수 없다.<br>🟢 **[2026-08-06 O45] 「캠페인 분해 불가」는 이제 과잉 서술이다** — `FACT_AD_PERFORMANCE.MKTG_CAMPAIGN_SK` 신설로 **마케팅캠페인 grain 분해가 된다**(비영 218,402/243,545 = 89.7%). 실측 개발단가 **73,842원**(79캠페인·광고비 34,209,625,719원·개발 463,279건).<br>🔴 **불가한 것은 두 가지로 좁혀졌다**: ① **소재**(연결키 부재) ② **개발캠페인 grain**(광고비 배분 규칙 부재 — naive 조인 시 광고비가 **181.6배** 복제된다). ②는 원천 입고가 아니라 **현업 배분 규칙 1건**이면 열린다 → Q10 재정의 대상 |
| **O8** | 회원 다중후원 캠페인 귀속 규칙 | `FACT_MEMBER_MONTHLY.CAMPAIGN_SK`·`SPONSORSHIP_SK`·`PAYMENT_SK` 전건 0 · `FACT_SERVICE_EVENT.CAMPAIGN_SK` 전건 0 · `FACT_EVENT_PARTICIPATION.CAMPAIGN_SK`·`SPONSORSHIP_SK` 전건 0 | 회원-월 다중캠페인 **7.98%** · 단일 회원-월 최대 **60개** → 규칙 없이 조인하면 fan-out 으로 기준선이 붕괴한다 | 🔴 **현업 귀속 규칙 회신**(대표후원/최빈 등). ⚠️ 캠페인 분해가 **전면 불가한 것은 아니다** — 개발/중단 건수는 `FACT_MEMBER_EVENT`, 캠페인별 이탈률은 `FACT_MEMBER_COHORT` 에서 산출된다.<br>🟢 **[2026-08-06 O45 회수] `FACT_MEMBER_EVENT.SPONSORSHIP_SK` 는 O8 문제가 아니었다** — **사건 grain 에서는 후원사업이 하나로 확정**되므로 귀속 규칙이 불요하다. 원천 `SPNSR_BSNS_ID` 채움 100% · `DIM_SPONSORSHIP` 고아 0 → 실배선(비영 **3,594,843**).<br>🟢 **후원사업별 회비 분해도 열렸다** — 회원-월에 붙일 수 없던 이유는 grain 이지 연결키가 아니었다 → `FACT_MEMBER_FEE`(회원×회비월×후원사업×…) 신설로 산출된다.<br>🔴 **잔여는 「회원-월 grain 에 하나로 귀속」 뿐**이다. 이슈를 grain 없이 서술하면 과잉 차단이 된다(P87) |
| **이름 크로스워크** | ERP 조직/후원사업/캠페인이 **이름만** 보유(코드 부재) | `FACT_TARGET_BIZ` 전 FK · `FACT_BUDGET.ORG_SK` 전건 0 | 조직명(본부/지부) grain ↔ `DIM_ORG.DEPARTMENT`(부서) grain 불일치 | 🟠 조직명↔코드 크로스워크 확보 |
| **A-8** | 대행사 실적일(송출일 ≠ 실적일) | — | 실적일 별도 컬럼 없음 | 🟠 단일날짜 근사(잠정) |

---

## E. 산출규칙 미확정 🟠

| ID | 결손 | 실측 | 미결 |
|---|---|---|---|
| **CONF-4 / ORG-H** | `DIM_ORG.CORP`·`DIVISION`·`TEAM` **전건 NULL** (`DEPARTMENT` 만 1,315행 채움) | 🟢 원천 `SILVER.CRM_ORG.UPPER_DEPT_ID` **1,314행/321종** 실재 · 재귀 트리 **6단** 검증 완료(고아·순환 0) | 🟠 ① 6레벨 → 4컬럼 매핑 ② 정본이 말하는 **「실적지부」** 산출규칙(명칭 기반 도달 91.9%·미도달 37 → 명칭 판정은 범주오류 위험) ③ 본부/지부 구별축 부재 → **현업 회신** |
| **SPB-G** | `DIM_SPONSORSHIP.SPONSORSHIP_ABBR` — 값은 있으나(`1`~`6`) **라벨 없음** | 6종 실측 | 🟠 코드사전 미특정. ML 정본이 요구하는 4그룹·11개와의 대응 전부 미확정 → **현업 매핑표** |
| **DIM_PAYMENT.FEE_TYPE** | 전건 NULL | 🟢 원천 `MBRFEE_DIV_CD` SILVER 보존 | 🟡 배선(내부) |
| **SVL-1~4** | 발송소분류·발송상태·발송채널·행사구분 라벨 | 코드는 실재 | 🟠 라벨 회신 대기 |

---

## F. 적재 범위·시점 결손 🔴

| ID | 결손 | 실측 규모 | GOLD 영향 | 조치 |
|---|---|---|---|---|
| **G-5** | GA4 전체기간 샤드 | 🔴 **2일 샤드만** — `events_20260501`(287,025) + `events_20260719`(289,416) → `SILVER.GA4_EVENT` 538,565행 · **날짜 2개** | `FACT_GA_BEHAVIOR` 68,836행 · `AVG_SESSION_DURATION`·`BOUNCE_RATE` 전건 NULL · `CAMPAIGN_SK` 전건 0 · 추세 분석 불가 | 🔴 전기간 샤드 입고(외부 커넥터) → **identity 재검증 필수** |
| **BLOCKING-1** | 회원 마스터 전량 | 고아 소수 존재 → 참조무결성 테스트 **`warn` 강등 15건** | Unknown(`SK=0`) 라우팅 | 🔴 마스터 전량입고 후 `warn`→`error` 복귀 |
| **이슈 E** | 행사 마스터(`CRM_EVENT`) 추출 완전성 | 고아 **263,611**(참여의 23%) | 참여 23% 가 Unknown 행사로 집계 → 행사명별 집계는 **부분집합** | 🔴 행사 마스터 전량입고(키체계 문제 아님 — 추출범위 문제로 진단 확정) |
| **AD-3** | 대행사 개발건수 재제공 | 2026-06 부터 원천이 개발건수 대신 **단가**를 직접 제공(완전 상호배타) | 개발단가(공7) **2026-05 까지만** 산출 | 🔴 대행사에 개발건수 재제공 요청(또는 대행사 단가 채택 — 정의 상이로 이전 기간과 비교 불가) |
| **E-5·A-9** | ERP/AGENCY/GA4 적재 시작시점·보유범위 | — | 기간요건(2025~) 충족 확인 필요 | 🟠 보유 범위 회신 |

### ⚠️ 신규 관측 (2026-08-06) — GA4 샤드 스키마 불일치

`events_20260719` 에 `event_original_occurrence_timestamp` 컬럼이 **1개 추가**돼 있다
(`events_20260501` 30컬럼 → `events_20260719` 31컬럼).
전기간 입고 시 **샤드별 스키마 차이**가 UNION 에서 문제를 일으킬 수 있으므로 G-5 착수 시 확인이 필요하다.

---

## G. CDC(변경 데이터 캡처) 필요성 식별

> GOLD 차원의 **시점 정확도**를 위해 원천의 변경이력이 필요한지 판정.

| 대상 | CDC 필요 | 현 원천 | 판정 |
|---|---|---|---|
| **회원 상태**(`DIM_MEMBER` SCD2) | ✅ 필요 | `TH_MM_FDRM_MBER_STNG_DTLS` 7,501,761행 | 🟢 **충족** — SCD2 시점조인으로 7,925,716 버전 재구성(손실 0). 별도 CDC 요청 불요 |
| **조직**(`DIM_ORG`) | 현재 불요 | 변경이력 소스 없음 | 🟢 SCD1 확정. 향후 as-was 조직분석이 필요하면 조직 변경이력 CDC 입고 필요 |
| **GA identity**(pseudo→member) | ✅ 필요(G-5 시) | `IDENTITY_MEMBER_XREF` 2,009행 | 🔴 전기간 전환 시 매핑에 `VALID_FROM/VALID_TO`(SCD2) 부여 필요(공용기기 재매핑·NULL→DIRECT 시점). 현재 2일 기반이라 보류 |
| **회원 연령·주소** | ✅ 필요 | 🔴 **BRONZE 전체에 생년월일·현주소 컬럼이 없다**(전수 스캔) | 🔴 현재 연령·현주소는 **원천적으로 산출 불가**. 지금 노출되는 값은 **약정 시점 스냅샷**이다(O34) |
| 예산 추경/조정 | 스냅샷이면 불요 | `CHN/ADJ_BUDGET_AMT` 실재 | 🟡 데이터는 있으나 GOLD 슬롯 부재 → CDC 아닌 **스키마 확장** 이슈 |

---

## H. 데이터 품질 결손 — 내부 라우팅으로 흡수 🟢

| ID | 항목 | 규모 | 현 처리 | 회신 후 조치 |
|---|---|---|---|---|
| A | `MONTH_KEY` 비-YYYYMM | ~2,043행 | 무효 → 납입월/0 라우팅(월키 클램프) | 유효 판정 시 클램프 완화 |
| C | 캘린더 범위밖 날짜 | ~140행 | `DATE_SK=0` | 유효 시 캘린더 확장 |
| O22 | BRONZE 회비원천 **논리적 중복** | 업무 속성 전건 동일 행 **1,831,286행(3.947%)** | 🔴 **미해소** — dedup 미적용 | 🟠 원천 시스템의 정상 발행인가 중복 결함인가 **현업 확인 선행**. 확인 전 dedup 금지 |
| O29 | `DURATION_SEC` 단위 오류 | HH:MM:SS 표기 **32,739행(96.6%) 무성 소실** | COMMENT 가드 배포 | 🟡 파싱 복구(HH:MM:SS 즉시 가능 · 숫자 3종은 현업 확인 후) |

> **센티넬 규약(정본)**: 미매칭·범위밖·NULL 차원키는 **Unknown 멤버 `SK=0`** 으로 라우팅한다
> (GOLD DIM 전량 `(미매핑)` 시드 + `COALESCE(...,0)`). 분석 파손은 없으나
> **Unknown 버킷이 큰 축은 집계가 부분집합**이므로 확정치로 단정하면 안 된다.
> ⚠️ 이 프로젝트에 `-1 UNKNOWN` 은 존재하지 않는다(구 설계초안 표기는 폐기됨).

---

## I. 🆕 「보고서 조립 불가」는 이 결손 목록과 다른 축이다 (2026-08-07 O47)

> 🔴 **혼동 주의**: 이 문서(02)는 **GOLD 컬럼에 값이 없는 것**을 센다. `09_보고서필드_조립가능성.md` 는
> **값이 있어도 한 표에 못 놓는 것**을 센다. 두 목록은 **겹치지 않는 별개의 축**이며 더하면 안 된다.

| | 02(이 문서) | 09 |
|---|---|---|
| 세는 대상 | GOLD **컬럼** | 보고서 **필드** |
| 모집단 | 411 (DATA 컬럼) | 507 (보고서 필드) |
| 결손 정의 | 값이 없다(전건 0/NULL) | 값은 있으나 **grain 이 안 맞는다** |
| 실측 | 미주입 **105** | ⛔불가 **137** · ◐집계필요 **6** |

### O47 이 09 의 「불가」를 4가지로 쪼갠 결과 — 02 와의 대응

| 09 판정 | 건수 | 02 의 어느 절에 대응하나 |
|---|---:|---|
| ◐ **집계필요** | 6 | **대응 없음 — 결손이 아니다.** 쿼리 패턴 문제이며 컬럼은 다 있다 |
| ⛔ **배분규칙필요** | 7 | **§E 산출규칙 미확정**과 같은 성격(현업 규칙 1건) — 단 02 의 E 4건과는 **다른 항목**이다 |
| ⛔ **형제팩트중복** | 6 | **대응 없음 — 결손이 아니다.** 표를 하나 고르면 된다 |
| ⛔ **축 부재**(원천부재) | 10 | **§A 원천에 항목 자체가 없음**과 동일 성격(예: 매체별 목표) |
| ⛔ **값없음** | 85 | 🟢 **여기가 유일한 교집합** — 02 의 미주입 105 가 보고서 필드로 드러난 것이다 |

> 🟢 **읽는 법**: *"이 필드 왜 안 나오나"* 는 질문에 답할 때 **먼저 09 로 사유를 보고**,
> 사유가 「값없음」이면 그때 02 에서 그 컬럼의 결손 유형(A~F)을 찾습니다. 순서를 거꾸로 하면 헛짚습니다.

---

## 종합 · 우선순위

### 1. 외부 입고 요청 (하드블로커 — 우리가 못 푼다)

| 순위 | 항목 | 막히는 것 | 요청 대상 |
|---|---|---|---|
| 1 | **E-6** CRM 사업목표 | 연/추경 사업목표 달성률 전량(공152~155) | 현업 (요청서 발행·회신 대기) |
| 2 | **C-9-R** 발송 오픈 로깅 | 오픈율 + **ML 예측 3종(증액·충성·중단)** | CRM 발송 시스템 |
| 3 | **G-5** GA4 전기간 샤드 | GA 행동·전환·ROAS 전량 | 외부 커넥터 |
| 4 | **Q10** 캠페인·소재 연결키 | 캠페인별 ROI·광고 소재 분해 | 현업 매핑 |
| 5 | **E-1/E-4** 모금성비용·광고비 | 예산 대비 모금 효율 | ERP/대행사 |
| 6 | **HOL-1** 공휴일 캘린더 | 개발가능일수 기반 예측(ML A안 3종) | 외부 API 또는 사내 캘린더 |
| 7 | **AD-5** VIDEO 개발실적 | 방송 광고비 29% 구간 효율 | 대행사(리포트 항목 신설) |
| 8 | 회원·행사 마스터 전량 | 참조무결성 `error` 복귀 · 행사명별 집계 완전성 | 입고팀 |

### 2. 현업 회신 대기 (결정만 되면 우리가 만든다)

| 항목 | 막히는 것 |
|---|---|
| **CONF-3** 월말활동회원 판정 조건(정본 내부 모순) | 활동회원 카운트 **8종** |
| **CONF-2** `(건)` 의 의미(건수 vs 금액÷10,000) | 미납·활동 카운트 컬럼 재사용 가능 여부 |
| **O28** 행사 참여상태 소정수 `1~6` 코드그룹 | 행사 상태별 카운트 **7종** |
| **O8** 다중후원 캠페인 귀속 규칙 | FMM·FSE·FEP 의 캠페인·후원사업 FK **9종** |
| **CONF-4** 「실적지부」 산출규칙 | 상위 조직별 분해 전량 |
| **O38-D** 개발목표 편성 방침(`GOAL_CNT=0` 의 의미) | 증액·재후원 달성율 |
| **O22** 회비원천 중복이 정상인가 | `PAID_FEE`·`BILLED_AMT` 정확도 |
| **SPB-G / SVL-1~4** 라벨 매핑표 | 후원사업 그룹·발송 소분류/상태/채널·행사구분 라벨 |
| 발송 채널별 성공/실패 코드매핑 | 발송 성공·실패율 |

### 3. 내부 구현 가능 (외부 의존 0)

- 증액·감액·이탈 월 롤업 배선 (`DVLP_DIV_CD` 권위 원천 사용)
- 서신·선물금 참여 및 +5일 코호트 로직
- 미납중단 사유 기반 분류
- 회비 정기/일시 분해
- `DIM_PAYMENT.FEE_TYPE` 배선
- `DIM_ORG` 계층 **구조** 전개(재귀 CTE — 레벨→컬럼 매핑 확정 후)
- `DURATION_SEC` HH:MM:SS 파싱 복구
- 🔴 **O39-B 전건 0 컬럼군 영향범위 조사** — `ACTIVE_CNT` 는 활동회원 지표의 **분모** 축이라 조사가 선결

### 4. 조치 불요 (내부 완결)

- 회원상태 SCD2 (상태이력 원천 충족 — CDC 요청 불요)
- 품질결손 A/C (Unknown `SK=0` 라우팅으로 흡수)
- `DIM_DATE` 등 ETL 생성 차원 (SILVER 원천이 없는 것이 정상)

---

## 부록. 미주입 GOLD 컬럼 **105건** 전량 (실측 2026-08-07 재확인 · 구 표기 106)

> 재현 방법: `SELECT COUNT(<col>), COUNT_IF(<col> <> 0) FROM GN_DW.GOLD.<table>` 전수.
> `전건 0` 은 `COUNT()` 로는 「적재됨」으로 오판된다 — 반드시 `COUNT_IF(<>0)` 로 판정할 것.

### A. 원천에 항목 자체가 없음 🔴 — 18건

| GOLD 테이블 | 컬럼 | 실측 |
|---|---|---|
| `DIM_DATE` | `IS_HOLIDAY` | 전건 0 |
| `FACT_AD_BROADCAST` | `CONV_CALL_CNT` | 전건 NULL |
| `FACT_AD_DIGITAL` | `MEDIA_POTENTIAL_CUST_CNT` | 전건 NULL |
| `FACT_BUDGET` | `AD_COST` | 전건 NULL |
| `FACT_BUDGET` | `EXEC_BUDGET_EST` | 전건 NULL |
| `FACT_BUDGET` | `FUNDRAISING_COST` | 전건 NULL |
| `FACT_BUDGET` | `PLAN_BUDGET_YEAR` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `INBOUND_CALL_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `TS_CALL_CNT` | 전건 0 |
| `FACT_SERVICE_EVENT` | `OPEN_MEMBERS` | 전건 0 |
| `FACT_TARGET_BIZ` | `ANNUAL_CUM_GOAL_CNT` | 0행 테이블 |
| `FACT_TARGET_BIZ` | `ANNUAL_GOAL_CNT` | 0행 테이블 |
| `FACT_TARGET_BIZ` | `CAMPAIGN_SK` | 0행 테이블 |
| `FACT_TARGET_BIZ` | `MONTH_KEY` | 0행 테이블 |
| `FACT_TARGET_BIZ` | `ORG_SK` | 0행 테이블 |
| `FACT_TARGET_BIZ` | `SPONSORSHIP_SK` | 0행 테이블 |
| `FACT_TARGET_BIZ` | `SUPP_CUM_GOAL_CNT` | 0행 테이블 |
| `FACT_TARGET_BIZ` | `SUPP_GOAL_CNT` | 0행 테이블 |

### B. 원천은 있으나 산출 로직 미구현 🟡 — 51건

| GOLD 테이블 | 컬럼 | 실측 |
|---|---|---|
| `FACT_MEMBER_EVENT` | `NEW_EXISTING_FLAG` | 전건 NULL |
| `FACT_MEMBER_EVENT` | `UNPAID_STOP_CNT` | 전건 0 |
| `FACT_MEMBER_EVENT` | `UNPAID_STOP_MEMBERS` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `ACTIVE_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `ACTIVE_CUM_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `ACTIVE_CUM_MEMBERS` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `ACTIVE_MEMBERS` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `AMOUNT_BAND1` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `AMOUNT_BAND2` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `CAMPAIGN_UNPAID_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `CHURN_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `DECREASE_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `DEV_TYPE` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `INCREASE_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `INCREASE_FLAG` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `INCREASE_MEMBERS` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `JOIN_DATE` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `MONTH_END_ACTIVE_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `NEW_EXISTING_FLAG` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `NEW_FLAG` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `PAID_MONTHS` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `PERIOD_BAND1` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `PERIOD_BAND2` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `PREV_MONTH_END_ACTIVE_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `REDONATE_FLAG` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `SPONSOR_MONTHS` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `SPONSOR_YEARS` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `STATUS_UNPAID_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `STOP_DATE` | 전건 NULL |
| `FACT_MEMBER_MONTHLY` | `UNPAID_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `YEAR_END_ACTIVE_CNT` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `YEAR_START_ACTIVE_CNT` | 전건 0 |
| `FACT_SERVICE_EVENT` | `D5_GIFT_PART_CNT` | 전건 0 |
| `FACT_SERVICE_EVENT` | `D5_GIFT_PART_MEMBERS` | 전건 0 |
| `FACT_SERVICE_EVENT` | `D5_INCREASE_PART_CNT` | 전건 0 |
| `FACT_SERVICE_EVENT` | `D5_INCREASE_PART_MEMBERS` | 전건 0 |
| `FACT_SERVICE_EVENT` | `D5_LETTER_PART_CNT` | 전건 0 |
| `FACT_SERVICE_EVENT` | `D5_LETTER_PART_MEMBERS` | 전건 0 |
| `FACT_SERVICE_EVENT` | `D5_STOP_CNT` | 전건 0 |
| `FACT_SERVICE_EVENT` | `D5_STOP_MEMBERS` | 전건 0 |
| `FACT_SERVICE_EVENT` | `FAIL_MEMBERS` | 전건 0 |
| `FACT_SERVICE_EVENT` | `GIFT_PART_AMT` | 전건 0 |
| `FACT_SERVICE_EVENT` | `GIFT_PART_MEMBERS` | 전건 0 |
| `FACT_SERVICE_EVENT` | `LETTER_PART_CNT` | 전건 0 |
| `FACT_SERVICE_EVENT` | `LETTER_PART_MEMBERS` | 전건 0 |
| `FACT_SERVICE_EVENT` | `MAIL_RECEIVE_FLAG` | 전건 NULL |
| `FACT_SERVICE_EVENT` | `MEMBER_STOP_FLAG` | 전건 NULL |
| `FACT_SERVICE_EVENT` | `SEND_STATUS2` | 전건 NULL |
| `FACT_SERVICE_EVENT` | `SERVICE_CNT` | 전건 0 |
| `FACT_SERVICE_EVENT` | `SERVICE_MEMBERS` | 전건 0 |
| `FACT_SERVICE_EVENT` | `SUCCESS_MEMBERS` | 전건 0 |

### C. 코드체계 미확정 🟠 — 11건

| GOLD 테이블 | 컬럼 | 실측 |
|---|---|---|
| `FACT_EVENT_PARTICIPATION` | `ABSENT_CNT` | 전건 0 |
| `FACT_EVENT_PARTICIPATION` | `ABSENT_TIMES` | 전건 0 |
| `FACT_EVENT_PARTICIPATION` | `CANCEL_CNT` | 전건 0 |
| `FACT_EVENT_PARTICIPATION` | `CONFIRM_CNT` | 전건 0 |
| `FACT_EVENT_PARTICIPATION` | `CUM_APPLY_TIMES` | 전건 0 |
| `FACT_EVENT_PARTICIPATION` | `INCREASE_FLAG` | 전건 NULL |
| `FACT_EVENT_PARTICIPATION` | `PARTICIPATION_TIMES` | 전건 0 |
| `FACT_EVENT_PARTICIPATION` | `SELF_PART_FLAG` | 전건 NULL |
| `FACT_EVENT_PARTICIPATION` | `TOTAL_CNT` | 전건 0 |
| `FACT_EVENT_PARTICIPATION` | `WAIT_CNT` | 전건 0 |
| `FACT_EVENT_PARTICIPATION` | `WAIT_TIMES` | 전건 0 |

### D. 연결키 부재 🔴 — 13건

| GOLD 테이블 | 컬럼 | 실측 |
|---|---|---|
| `DIM_CAMPAIGN` | `ORG_SK` | 전건 0 |
| `FACT_AD_PERFORMANCE` | `AD_CREATIVE_SK` | 전건 0 |
| `FACT_AD_PERFORMANCE` | `CAMPAIGN_SK` | 전건 0 |
| `FACT_BUDGET` | `CAMPAIGN_SK` | 전건 0 |
| `FACT_BUDGET` | `ORG_SK` | 전건 0 |
| `FACT_BUDGET` | `SPONSORSHIP_SK` | 전건 NULL |
| `FACT_EVENT_PARTICIPATION` | `CAMPAIGN_SK` | 전건 0 |
| `FACT_EVENT_PARTICIPATION` | `SPONSORSHIP_SK` | 전건 0 |
| `FACT_GA_BEHAVIOR` | `CAMPAIGN_SK` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `CAMPAIGN_SK` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `PAYMENT_SK` | 전건 0 |
| `FACT_MEMBER_MONTHLY` | `SPONSORSHIP_SK` | 전건 0 |
| `FACT_SERVICE_EVENT` | `CAMPAIGN_SK` | 전건 0 |

### E. 산출규칙 미확정 🟠 — 4건

| GOLD 테이블 | 컬럼 | 실측 |
|---|---|---|
| `DIM_ORG` | `CORP` | 전건 NULL |
| `DIM_ORG` | `DIVISION` | 전건 NULL |
| `DIM_ORG` | `TEAM` | 전건 NULL |
| `DIM_PAYMENT` | `FEE_TYPE` | 전건 NULL |

### F. 적재 범위·시점 결손 🔴 — 8건

| GOLD 테이블 | 컬럼 | 실측 |
|---|---|---|
| `DIM_AD_CREATIVE` | `PLATFORM_TYPE` | 전건 NULL |
| `DIM_AD_CREATIVE` | `RT_TYPE` | 전건 NULL |
| `DIM_AD_CREATIVE` | `TARGET_GROUP` | 전건 NULL |
| `DIM_EVENT` | `APPLY_CHANNEL` | 전건 NULL |
| `DIM_MEMBER_IDENTITY` | `CHILD_CODE` | 전건 NULL |
| `DIM_MEMBER_IDENTITY` | `MEMNUM` | 전건 NULL |
| `FACT_GA_BEHAVIOR` | `AVG_SESSION_DURATION` | 전건 NULL |
| `FACT_GA_BEHAVIOR` | `BOUNCE_RATE` | 전건 NULL |

---
_Co-authored with CoCo_
