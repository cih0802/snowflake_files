<!-- LLM-METADATA
doc_id: SV_METRIC_ASSIGNMENT_V4
doc_role: 1단계 산출물 — derived 81 → v4 7-SV 전수 재배속 (2단계 SV 구조설계 입력)
project: GN_DW (굿네이버스)
created: 2026-07-21
supersedes: _archive/1_SV_metric 배속.md (4-SV 기준)
inputs(SSOT):
  - 03_top-down_gold/04_SV파생 매핑.md   (분자/분모·소속 FACT·conform 축 — grain 권위)
  - 05_SV-Agent_ai/01_SV-Agent 작업계획.md §1.1·§2 (7-SV 매핑·Phase 게이트)
  - _archive/1_SV_metric 배속.md          (가산성·시간가용성·활성여부 태그 재사용)
END-METADATA -->

# 1단계 — derived 81 → v4 7-SV metric 재배속

> 레거시 4-SV(`SV_MEMBER`48·`SV_SERVICE`24·`SV_AD`4·`SV_GA`2 + 보류3)를 **v4 7-SV**로 재분해.
> 핵심 변경: 레거시 `SV_MEMBER`(FMM 단일 48) → **grain 분리** = `SV_MEMBER_MONTHLY`(FMM 40) + `SV_MEMBER_EVENT`(FME 8). `SV_BUDGET` 신설(신9~11). `SV_EVENT_PARTICIPATION`은 파생 0·base measure만.
> **직역 원칙(P2·원칙4)**: 분자/분모·소속 FACT는 `04_SV파생 매핑.md` 원문 그대로. 재정의·창작 없음. 불확실=⚠ 플래그(추정 금지).

## 0. 태그 범례

> **물리화 정책 (P7 · 04매핑 §P2 · GOLD설계 line28~29·156) — 본 표 81개 전건 적용**
> 이 문서의 **derived 81개는 전부 GOLD 물리 비적재 → SV metric expression으로만 구현**한다(새 물리컬럼 신설 없음).
> - **비율(율·구성비·단가·ROI·CTR/CVR)** = 분자·분모를 각각 집계 후 division → SV metric. (base measure 아님, 가산성 N)
> - **누계(YTD/누적)** = base measure의 **YTD 윈도우**로 SV에서 계산(새 컬럼 아님). ※단 `ACTIVE_CUM_CNT`(누계활동건, 공159)는 derived가 아닌 **물리 base measure** — 예외.
> - **증감/증감율(공59·60)** = SV time-intelligence(당기−전기), 물리 저장 금지.
> - **유일 예외(적재)**: GA4 사전집계 비가산(공98·108)은 재계산 불가 → FGA 물리컬럼 직접 노출, SV에서 SUM/AVG 금지.
> - base 갭 재검토(2단계 실측): 공80은 FMM `UNPAID_FLAG_BOM/EOM` 실재로 **해소(활성)**. 잔여 갭은 공81 전환명(GA identity, §6-D)뿐 → cross-source 브리지·P2.

- **활성여부**: `활성`(즉시 산출) · `활성(브리지)`(conformed/코호트 브리지 뷰 선행 필요 — 2단계) · `부분`(시간한정) · `placeholder`(base raw 부재, 정의만) · `보류`(base+grain 미확정, 입고 후).
- **Phase**(배포 게이트, 계획 §2): `P1`(즉시 배포) · `P2`(데이터 입고 후). cross-source GA 의존(공81·신32·신33)은 capability 활성이라도 **P2**(FGA 1일 샤드 4.22%).
- **가산성**: derived 비율은 전부 **N**(metric SUM 금지 — 분자·분모 각각 집계 후 division). `base S`=분자/분모 base가 준가산(시점값→기간 SUM 금지). `차분`=시계열. `part/total`=구성비. `코호트`=시점 유지회원.
- **시간가용성**(07_메타 enum): `전체가능`·`24년~`·`24.2~`·`25년~`·`2개년`·`적용불가`.
- **base FACT 표기**: 단일 `FMM`; 비율 grain 상이 `A·B`(04 표기 계승); 코호트 조인 `A×B`; cross-source(IDENTITY 브리지) `A×B`.

> ⚠️ **데이터 적재 완결성 경고 (실측 2026-07-21) — 아래 "활성/P1" 태그는 지표 정의 기준이며 실적재와 별개다.**
> GOLD 실측 결과 **차원 FK(CAMPAIGN_SK·PAYMENT_SK·SPONSORSHIP_SK·SERVICE_SK·ORG_SK)가 거의 전건 0 센티넬**이고, **FMM 카운트 measure(DEV/STOP/UNPAID/ACTIVE/INCREASE 건·명)·NEW_EXISTING_FLAG가 전건 공란**이다.
> → 현재 **실계산 가능**: 공64(납부율)·공80(미납회원 감소율)·납입/청구/예산 총액·FME 개발/중단 총건·유지기간(신2~8)·FSE 발송/코호트 총량·FEP 참여. **캠페인별/조직별/서비스구분별/신규기존별·활동/개발/중단 카운트 지표는 데이터 적재 후 활성**(적재 완결성 매트릭스 = `04_SV_설계.md §0.6`). 3단계 배포는 이 매트릭스 기준으로 스코프 확정.
> **⚠ 2026-07-22 정정 (A1/A3 적재 후 재실측)**: 위 "FMM 카운트 measure 전건 공란"은 **무효** — `DEV_CNT`(2,970,417)·`STOP_CNT`(972,376)는 **A1 적재로 활성**(SV_MEMBER_MONTHLY 개발/중단 총건), `FSE.SERVICE_SK`(99.97%)·`SEND_TITLE`(36.6M)는 **A3 적재로 서비스구분 분해 활성**(SV_SERVICE). 잔여 0(비활성 유지): UNPAID_CNT·ACTIVE·INCREASE 카운트·NEW_EXISTING_FLAG·FK(CAMPAIGN/PAYMENT/SPONSORSHIP/REASON_SK). **실배포 활성 정본 = `05_SV_DDL.sql` + `04_SV_설계.md §0.6 정정본`**.

---

## 1. SV_MEMBER_MONTHLY (base FACT = FMM, 월×회원) — 40 metric

> 회원 Agent. §1 목표대비(공1~3) + §2 활동/중단/미납/납입(공45~80, 공58 제외) + §9 시계열(공59·60) + §5 cross(공81) + §6 캠페인성과(신12~29). 소비 SV에 FTG_D(목표)·FGA(공81) conformed 폴딩.

### 1.1 목표대비 (FMM/FME × FTG_D conformed) — 3
| # | derived | 분자 ÷ 분모 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 공1 | 월 목표대비 개발(%) | DEV_CNT(당월) ÷ GOAL_CNT(당월) | FME·FTG_D | 활성(브리지) | N | 전체가능 | P1 | ⚠개발건 ORG축=**FME**(FMM엔 ORG_SK 없음, 04-61). MONTH×ORG×DEV_TYPE conformed 브리지 필요 |
| 공2 | 누계 목표대비 개발(%) | DEV_CNT(YTD) ÷ GOAL_CNT(YTD) | FME·FTG_D | 활성(브리지) | N | 전체가능 | P1 | +YTD 윈도우 |
| 공3 | 연 목표대비 개발(%) | DEV_CNT(연) ÷ GOAL_CNT(연) | FME·FTG_D | 활성(브리지) | N | 전체가능 | P1 | +YEAR |

### 1.2 활동/중단/미납/납입/1명당 (FMM 내부) — 20
| # | derived | 분자 ÷ 분모 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 공45 | 활동율(%) | MONTH_END_ACTIVE_CNT ÷ (YEAR_START_ACTIVE_CNT + DEV_CNT(YTD)) | FMM | 활성 | N·base S | 전체가능 | P1 | 시점값 |
| 공46 | 신규 활동율(%) | DEV_CNT(YTD) ÷ ACTIVE_CNT | FMM | 활성 | N·base S | 전체가능 | P1 | ⚠#45·47과 분자/분모 역방향(§6-A) — 정본 그대로, 합의 전 확정금지 |
| 공47 | 기존 활동율(%) | ACTIVE_CNT ÷ (DEV_CNT(YTD) + YEAR_START_ACTIVE_CNT) | FMM | 활성 | N·base S | 전체가능 | P1 | 신규/기존 필터 |
| 공54 | 중단율1(%) | STOP_CNT ÷ (DEV_CNT + YEAR_START_ACTIVE_CNT) | FMM | 활성 | N·base S | 전체가능 | P1 | |
| 공55 | 중단율2(%) | STOP_CNT ÷ DEV_CNT | FMM | 활성 | N | 전체가능 | P1 | |
| 공56 | 신규 중단율(%) | STOP_CNT[신규] ÷ (DEV_CNT[신규] + PREV_MONTH_END_ACTIVE_CNT[신규]) | FME·FMM | 보류(데이터) | N·base S | 전체가능 | P1→보류 | ❌실측: NEW_EXISTING_FLAG·STOP_CNT/ACTIVE 카운트 FMM 전건 공란 → 적재 대기 |
| 공57 | 기존 중단율(%) | STOP_CNT[기존] ÷ (DEV_CNT[기존] + PREV_MONTH_END_ACTIVE_CNT[기존]) | FME·FMM | 보류(데이터) | N·base S | 전체가능 | P1→보류 | ❌실측: 동상(NEW_EXISTING_FLAG·카운트 공란) |
| 공61 | 1명당 건수 | ACTIVE_CNT ÷ ACTIVE_MEMBERS | FMM | 활성 | N·base S | 전체가능 | P1 | |
| 공62 | 납입율(%) | PAID_FEE ÷ (ACTIVE_CNT ×10000) | FMM | 활성 | N·base S | 전체가능 | P1 | ×10000 상수 |
| 공63 | 누계 납입율(%) | PAID_FEE(YTD) ÷ (ACTIVE_CUM_CNT ×10000) | FMM | 활성 | N | 전체가능 | P1 | |
| 공64 | 납부율(%) | PAID_FEE ÷ BILLED_AMT | FMM | 활성 | N | 전체가능 | P1 | 청구=재청구 중복포함 |
| 공65 | 누계 납부율(%) | PAID_FEE(YTD) ÷ BILLED_AMT(YTD) | FMM | 활성 | N | 전체가능 | P1 | ⚠#69↔#70 중복정의(07_메타) |
| 공76 | 미납율(%) | UNPAID_CNT ÷ ACTIVE_CNT | FMM | 활성 | N·base S | 전체가능 | P1 | |
| 공77 | 신규 미납율(%) | UNPAID_CNT[신규] ÷ ACTIVE_CNT[신규] | FMM | 보류(데이터) | N·base S | 전체가능 | P1→보류 | ❌실측: NEW_EXISTING_FLAG·UNPAID_CNT/ACTIVE 카운트 FMM 전건 공란 |
| 공78 | 기존 미납율(%) | UNPAID_CNT[기존] ÷ ACTIVE_CNT[기존] | FMM | 보류(데이터) | N·base S | 전체가능 | P1→보류 | ❌실측: 동상 |
| 공79 | 후원사업별 미납율(%) | UNPAID_CNT(사업) ÷ ACTIVE_CNT(사업) | FMM | 활성 | N·base S | 전체가능 | P1 | SPONSORSHIP_SK 필터 |
| 공80 | 미납회원 감소율(%) | (월초 미납회원 − 월말 미납회원) ÷ 월초 미납회원 | FMM | 활성 | N(2시점) | 전체가능 | P1 | ✅실측 개선: FMM에 `UNPAID_FLAG_BOM`·`UNPAID_FLAG_EOM` 실재 → 월초·월말 미납회원 COUNT DISTINCT 차분(§6-C 해소) |

### 1.3 시계열 (time-intelligence, P7 저장금지·SV 계산) — 2
| # | derived | 정의 | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 공59 | 증감(건) | 당기 − 전기 | FMM | 활성 | N(차분) | 전체가능 | P1 | 개발·중단·미납·활동건 대상 |
| 공60 | 증감율(%) | (당기 − 전기) / 전기 ×100 | FMM | 활성 | N(차분) | 전체가능 | P1 | |

### 1.4 cross-source (IDENTITY 브리지) — 1
| # | derived | 분자 ÷ 분모 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 공81 | 미납서비스 전환율(%) | 납입전환 회원(명) ÷ GA 미납서비스 클릭회원(명) ×100 | FMM×FGA | 활성(브리지) | N | 전체가능 | **P2** | DIM_MEMBER_IDENTITY 브리지. ⚠분모=FGA 의존(GA4 1일 샤드) + 분자 identity 정의 부재(§6-D) → Phase 2 |

### 1.5 캠페인 성과 (FMM, CAMPAIGN/PAYMENT/YEAR 필터) — 17
| # | derived | 분자 ÷ 분모 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 신12 | 캠페인별 활동율(%) | ACTIVE_CNT ÷ (DEV_CNT(YTD) + YEAR_START_ACTIVE_CNT) | FMM ×CAMPAIGN | 활성 | N·base S | 25년~ | P1 | |
| 신13 | 연도별 캠페인 활동율(%) | 〃 | FMM ×CAMPAIGN×YEAR | 활성 | N·base S | 25년~ | P1 | |
| 신14 | 납입방식 활동율(%) | ACTIVE_CNT ÷ (DEV_CNT(YTD) + YEAR_START_ACTIVE_CNT) | FMM ×PAYMENT | 활성 | N·base S | 25년~ | P1 | |
| 신15 | 캠페인별 중단율(%) | STOP_CNT ÷ (DEV_CNT + YEAR_START_ACTIVE_CNT) | FMM ×CAMPAIGN | 활성 | N·base S | 25년~ | P1 | |
| 신16 | 연도별 캠페인 중단율(%) | STOP_CNT ÷ (DEV_CNT + PREV_MONTH_END_ACTIVE_CNT) | FMM ×CAMPAIGN×YEAR | 활성 | N·base S | 24.2~ | P1 | |
| 신17 | 캠페인별 누계 중단율(%) | STOP_CNT(YTD) ÷ (DEV_CNT(YTD) + YEAR_START_ACTIVE_CNT) | FMM ×CAMPAIGN | 활성 | N·base S | 25년~ | P1 | |
| 신18 | 연도별 캠페인 신규 중단율(%) | STOP_CNT(YTD) ÷ DEV_CNT(YTD) | FMM ×CAMPAIGN×YEAR | 활성 | N | 24년~ | P1 | |
| 신19 | 납입방식 중단율(%) | STOP_CNT ÷ (DEV_CNT + YEAR_START_ACTIVE_CNT) | FMM ×PAYMENT | 활성 | N·base S | 25년~ | P1 | |
| 신21 | 캠페인별 이탈율(%) | CHURN_CNT ÷ DEV_CNT | FMM ×CAMPAIGN | 활성 | N | 전체가능 | P1 | ⚠신20 이탈 정의 불일치(07_메타) |
| 신22 | 캠페인별 납입율(%) | PAID_FEE ÷ (MONTH_END_ACTIVE_CNT ×10000) | FMM ×CAMPAIGN | 활성 | N·base S | 24년~ | P1 | |
| 신23 | 연도별 캠페인별 납입율(%) | 〃 | FMM ×CAMPAIGN×YEAR | 활성 | N·base S | 24년~ | P1 | |
| 신24 | 캠페인별 누계 납입율(%) | PAID_FEE(YTD) ÷ (MONTH_END_ACTIVE_CNT ×10000) | FMM ×CAMPAIGN | 활성 | N | 24년~ | P1 | |
| 신25 | 연도별 캠페인 누계납입율(%) | 〃 | FMM ×CAMPAIGN×YEAR | 활성 | N | 24년~ | P1 | |
| 신26 | 캠페인별 납입회비 구성비(%) | PAID_FEE(캠페인) ÷ PAID_FEE(전체) ×100 | FMM ratio-of-total | 활성 | N(part/total) | 24년~ | P1 | |
| 신27 | 캠페인별 미납율(%) | (CAMPAIGN_UNPAID_CNT ×10000) ÷ (MONTH_END_ACTIVE_CNT ×10000) | FMM ×CAMPAIGN | 활성 | N·base S | 24년~ | P1 | ×10000 상쇄 |
| 신28 | 연도별 캠페인 미납율(%) | 〃 | FMM ×CAMPAIGN×YEAR | 활성 | N·base S | 24년~ | P1 | |
| 신29 | 캠페인별 미납회비 구성비(%) | CAMPAIGN_UNPAID_CNT(캠페인) ÷ CAMPAIGN_UNPAID_CNT(전체) ×100 | FMM ratio-of-total | 활성 | N(part/total) | 24년~ | P1 | |

**SV_MEMBER_MONTHLY 소계 = 40** (목표대비3 + FMM내부20 + 시계열2 + cross1 + 캠페인17)

---

## 2. SV_MEMBER_EVENT (base FACT = FME, 일×회원×상태전이) — 8 metric

> 회원 Agent. 유지기간·LTV(신2~8) + 주간/일 grain 중단(공58). **일 grain·JOIN_DATE degen·cohort(가입↔중단 간격) 필수 → FME**(FMM 월롤업 불가). 레거시가 FMM에 뒀던 항목을 grain 근거로 EVENT로 이관.

| # | derived | 분자 ÷ 분모 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 공58 | 주간 평균 1일 중단(건) | STOP_CNT(주합) ÷ 주간 일수(DIM_DATE) | FME·DIM_DATE | 활성 | N | 전체가능 | P1 | **일 grain 필수 → FME**(04-75). 레거시 FMM→EVENT 이관 |
| 신2 | 개발캠페인별 유지기간(개월) | DATEDIFF(조회일, JOIN_DATE) 개월 | FME(degen)·DIM_DATE | 활성 | N | 전체가능 | P1 | 고유ID=회원×가입일×후원사업×캠페인. 측정성 파생 |
| 신3 | 개발캠페인별 유지기간(년) | DATEDIFF(조회일, JOIN_DATE) 년 | FME·DIM_DATE | 활성 | N | 전체가능 | P1 | |
| 신4 | 평균 유지기간(개월) | Σ(유지개월 × DEV_MEMBERS) ÷ DEV_MEMBERS(총) | FME | 활성 | N(가중평균) | 전체가능 | P1 | |
| 신5 | 평균 유지기간(년) | Σ(유지년 × DEV_MEMBERS) ÷ DEV_MEMBERS(총) | FME | 활성 | N(가중평균) | 전체가능 | P1 | |
| 신6 | 개발캠페인별 이탈율(%) | N개월 유지중 회원수 ÷ N개월까지 가입회원수 | FME | 활성 | N(코호트) | 전체가능 | P1 | ⚠정본 식이 **유지율 형태**(명칭 이탈율과 상충, §6-E) — 정본 그대로 |
| 신7 | n개월 유지율(%) | (유지중 회원수 ÷ 가입회원수) ×100 | FME | 활성 | N(코호트) | 전체가능 | P1 | cohort=가입↔중단 간격 |
| 신8 | 개발캠페인별 LTV(원) | AVG(PAID_FEE/member) × 평균 활동기간(신4) | FMM·FME | **부분** | N | 24년~ | P1 | ⚠24년 이전 평균납입회비 부재 → 24년~ 한정. 납입회비=FMM cross |

**SV_MEMBER_EVENT 소계 = 8** (유지·LTV 7 + 주간중단 1)

---

## 3. SV_SERVICE (base FACT = FSE, +FMM/FME 코호트) — 24 metric

> 회원 Agent. §7 서비스 효과(신30~53). 발송/참여 모집단(FSE) × 이후 회원상태(FME/FMM 코호트 조인, +5일차 매칭). 명=COUNT DISTINCT.

| # | derived | 분자 ÷ 분모 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 신30 | 서비스별 발송율(%) | SEND_MEMBERS ÷ 전체회원수(명) ×100 | FSE·DIM_MEMBER | 활성 | N | 전체가능 | P1 | ⚠분모 "전체회원"=활동/전체 미정(§6-F) |
| 신31 | 발송대비 수신율(%) | SUCCESS_MEMBERS ÷ SEND_MEMBERS ×100 | FSE | 활성 | N | 25년~ | P1 | 단일 FACT |
| 신32 | 발송대비 클릭율(%) | GA 클릭회원(명, distinct) ÷ SEND_MEMBERS ×100 | FGA×FSE | 활성(브리지) | N | 25년~ | **P2** | ⚠클릭=명(≠FAD CLICKS 횟수)·GA 의존·identity(§6-D) |
| 신33 | 클릭대비 전환율(%) | DEV_MEMBERS(명) ÷ GA 클릭회원(명) ×100 | FME×FGA | 활성(브리지) | N | 25년~ | **P2** | ⚠cross-source identity·GA 의존 |
| 신34 | 서비스별 증액율(%) | D5_INCREASE_PART_(MEMBERS/CNT) ÷ SUCCESS_MEMBERS | FSE | 활성 | N | 전체가능 | P1 | 단일 FACT |
| 신35 | 증액회원 N개월 유지율(%) | 증액코호트 유지 회원수 ÷ D5_INCREASE_PART_MEMBERS | FSE×FME | 활성(브리지) | N(코호트) | 전체가능 | P1 | 코호트 브리지 |
| 신36 | 참여회원 N개월 유지율(%) | 참여코호트 유지 회원수 ÷ 참여회원수 | FSE×FME | 활성(브리지) | N(코호트) | 전체가능 | P1 | ⚠참여 정의 서비스별 상이(O4) |
| 신37 | 증액회원 납입율(%) | 증액코호트 중 납입회원 ÷ D5_INCREASE_PART_MEMBERS | FSE×FMM | 활성(브리지) | N | 전체가능 | P1 | 코호트 브리지 |
| 신38 | 참여회원 납입율(%) | 참여코호트 중 납입회원 ÷ 참여회원수 | FSE×FMM | 활성(브리지) | N | 전체가능 | P1 | ⚠참여 정의 |
| 신39 | 증액회원 중단율(%) | D5_STOP_(MEMBERS/CNT) ÷ SEND_MEMBERS | FSE | 활성 | N | 전체가능 | P1 | +5일내 중단 |
| 신40 | 참여회원 중단율(%) | D5_STOP_(MEMBERS/CNT) ÷ 참여회원수 | FSE | 활성 | N | 전체가능 | P1 | ⚠참여 정의 |
| 신41 | 증액회원 가입캠페인 구성비(%) | D5_INCREASE_PART(캠페인) ÷ D5_INCREASE_PART(전체) | FSE ×CAMPAIGN | 활성 | N(part/total) | 전체가능 | P1 | |
| 신42 | 참여회원 가입캠페인 구성비(%) | 참여(캠페인) ÷ 참여(전체) | FSE ×CAMPAIGN | 활성 | N(part/total) | 전체가능 | P1 | ⚠참여 정의 |
| 신43 | 서비스×캠페인 N개월 유지율(%) | 코호트 유지 회원수 ÷ 캠페인 가입회원수 | FSE×FME ×CAMPAIGN | 활성(브리지) | N(코호트) | 전체가능 | P1 | 코호트 브리지 |
| 신44 | 서비스별 서신 참여율(%) | LETTER_PART_MEMBERS ÷ 참여회원수 | FSE | 활성 | N | 전체가능 | P1 | |
| 신45 | 서신참여회원 N개월 유지율(%) | D5_LETTER_PART 유지 회원수 ÷ LETTER_PART_MEMBERS | FSE×FME | 활성(브리지) | N(코호트) | 전체가능 | P1 | 코호트 브리지 |
| 신46 | 서신참여회원 납입율(%) | 서신코호트 중 납입회원 ÷ LETTER_PART_MEMBERS | FSE×FMM | 활성(브리지) | N | 전체가능 | P1 | 코호트 브리지 |
| 신47 | 서신참여회원 중단율(%) | D5_STOP(서신코호트) ÷ LETTER_PART_MEMBERS | FSE | 활성 | N | 전체가능 | P1 | |
| 신48 | 서신참여회원 가입캠페인 구성비(%) | 서신(캠페인) ÷ 서신(전체) | FSE ×CAMPAIGN | 활성 | N(part/total) | 전체가능 | P1 | |
| 신49 | 서비스별 선물금 참여율(%) | GIFT_PART_MEMBERS ÷ 참여회원수 | FSE | 활성 | N | 전체가능 | P1 | |
| 신50 | 선물금참여회원 N개월 유지율(%) | D5_GIFT_PART 유지 회원수 ÷ GIFT_PART_MEMBERS | FSE×FME | 활성(브리지) | N(코호트) | 전체가능 | P1 | 코호트 브리지 |
| 신51 | 선물금참여회원 납입율(%) | 선물금코호트 중 납입회원 ÷ GIFT_PART_MEMBERS | FSE×FMM | 활성(브리지) | N | 전체가능 | P1 | 코호트 브리지 |
| 신52 | 선물금참여회원 중단율(%) | D5_STOP(선물금코호트) ÷ GIFT_PART_MEMBERS | FSE | 활성 | N | 전체가능 | P1 | |
| 신53 | 선물금참여회원 가입캠페인 구성비(%) | 선물금(캠페인) ÷ 선물금(전체) | FSE ×CAMPAIGN | 활성 | N(part/total) | 전체가능 | P1 | |

**SV_SERVICE 소계 = 24** (P1 22 · P2 2[신32·33 GA 의존])

---

## 4. SV_EVENT_PARTICIPATION (base FACT = FEP, 일×회원×행사) — 0 derived

> 회원 Agent. **derived 파생 지표 없음**(04 매핑 81건 중 FEP 소속 0). base measure(총참여수·참여회원 등, O11)만 노출하는 순수 집계 SV.
> ⚠ EVENT_KEY→DIM_EVENT 고아 23%(이슈 E, R4) → 2단계 SV instruction에 커버리지 고지·Unknown(0) 라우팅. **Phase 1**(FEP 1.1M 실적재).

**SV_EVENT_PARTICIPATION 소계 = 0** (derived 없음 — base 집계 전용)

---

## 5. SV_AD (base FACT = FAD, 일×캠페인×소재) — 4 metric [Phase 2]

> 마케팅 Agent. §3 광고 CTR·개발단가(공7~10). FAD가 **스캐폴드**(measure/날짜만·CAMPAIGN/CREATIVE/DEVICE FK=0) → 개발단가 conform 조인 불가. 전건 Phase 2(Q10 캠페인 연결키 보강 후).

| # | derived | 분자 ÷ 분모 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 공7 | CRM 개발단가(원) | AD_COST(AGENCY 편성비) ÷ DEV_CNT | FAD·FMM | placeholder | N | 전체가능 | **P2** | ⚠CRM채널 광고비 raw 부재(§6-G) + 차원FK=0 |
| 공8 | GA 개발단가(원) | AD_COST(SRC=GA4) ÷ DEV_CNT(SRC=GA4) | FAD·FMM | 활성 | N | 전체가능 | **P2** | 산식 산출가능하나 FAD 스캐폴드·GA 의존 |
| 공9 | GA CTR(%) | CLICKS ÷ IMPRESSIONS ×100 | FAD | 활성 | N | 전체가능 | **P2** | 단일 FACT(부분 가능하나 스캐폴드) |
| 공10 | GA CVR(%) | GA_CONV_MEMBERS(명) ÷ CLICKS ×100 | FAD | placeholder | N | 전체가능 | **P2** | ✅O5: 분자=전환'명' 확정(04§5). 전환수 raw 부재 |

**SV_AD 소계 = 4** (전건 P2)

---

## 6. SV_GA (base FACT = FGA, 일×identity×이벤트×소스) — 2 metric [Phase 2]

> 마케팅 Agent. §4 GA 행동(공98·108). GA4 사전집계 **비가산 → 재계산 불가·적재컬럼 직접 노출**(분자/분모 없음). FGA는 GA4 1일 샤드만(G-5 전기간 입고 대기).

| # | derived | 노출 컬럼 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 공98 | 평균세션시간 | 적재컬럼 AVG_SESSION_DURATION | FGA | placeholder | **N 비가산** | 전체가능 | **P2** | SV에서 SUM/AVG 재집계 금지. GA4 raw 입고 후 활성 |
| 공108 | 이탈율(GA)(%) | 적재컬럼 BOUNCE_RATE | FGA | placeholder | **N 비가산** | 전체가능 | **P2** | 〃 |

**SV_GA 소계 = 2** (전건 P2 placeholder)

---

## 7. SV_BUDGET (base FACT = FBD, 월×ORG×세세목) — 3 metric [Phase 2]

> overall Agent. 개발단가·ROI(신9~11). 비용 base=FBD(ERP 편성/집행)/FAD. **모금성비용 원천 부재·FTG_B 0행·캠페인 연결키 부재(O3)** → 전건 보류→Phase 2.

| # | derived | 분자 ÷ 분모 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 신9 | 캠페인별 개발단가 | AD_COST/PLAN_BUDGET(편성비) ÷ DEV_CNT[신규] | FBD/FAD·FMM | 보류 | N | 2개년 | **P2** | AGENCY 편성비 입고 대기(E-1/E-4) |
| 신10 | 매체별 개발단가 | FUNDRAISING_COST ÷ DEV_CNT[신규] | FBD·FMM | 보류 | N | 2개년 | **P2** | ERP 모금성비용 세세목 원천 부재 |
| 신11 | 캠페인별 ROI(%) | (PAID_FEE 또는 LTV − 비용) ÷ 비용 ×100 | FMM·FBD | 보류 | N | 적용불가 | **P2** | 캠페인별 비용배분 합의 부재(O3) |

**SV_BUDGET 소계 = 3** (전건 P2 보류)

---

## 8. 정합성 점검 (DoD)

### 8.1 전수·중복·누락
| 검증 | 결과 |
|---|---|
| derived 전수 = 공통 30 + 신규 51 | **81** ✓ |
| SV별 합 = MONTHLY 40 + EVENT 8 + SERVICE 24 + PARTICIPATION 0 + AD 4 + GA 2 + BUDGET 3 | **81** ✓ (중복 0 · 누락 0) |
| 공통 30 전수 배속 | 1,2,3,7,8,9,10,45,46,47,54,55,56,57,58,59,60,61,62,63,64,65,76,77,78,79,80,81,98,108 = 30 ✓ |
| 신규 51 전수 배속 | 2~8(7)·9~11(3)·12~19(8)·21~29(9)·30~33(4)·34~53(20) = 51 ✓ |
| 각 행 SV·base FACT·활성여부·가산성·시간·Phase 명기 | 81행 전수 ✓ |

### 8.2 레거시(4-SV) 대비 이동
| 이동 | 지표 | 근거 |
|---|---|---|
| SV_MEMBER → **SV_MEMBER_EVENT** | 공58·신2·신3·신4·신5·신6·신7·신8 (8건) | 일 grain·JOIN_DATE degen·cohort → FME(04 §3-1·04-75). 레거시는 FMM 단일이라 미분리 |
| SV_MEMBER → **SV_MEMBER_MONTHLY** | 나머지 40건 | FMM 월 스냅샷 grain |
| SV_GA(보류) → **SV_BUDGET** | 신9·신10·신11 | 소속 FACT=FBD/FAD·FMM(비용)로 GA행동(FGA)과 grain 불일치 → 예산 SV로 재배속(계획 §1.1) |
| 유지 | SV_SERVICE 24 · SV_AD 4 · SV_GA 2 | grain 동일 |

### 8.3 Phase 분포 (배포 게이트)
| Phase | 수 | 구성 |
|---|---:|---|
| **P1** (즉시 배포) | **69** | MONTHLY 39(공81 제외) + EVENT 8 + SERVICE 22(신32·33 제외) + PARTICIPATION 0(base 전용) |
| **P2** (입고 후) | **12** | 공81 · 신32 · 신33 (GA cross) + SV_AD 4 + SV_GA 2 + SV_BUDGET 3 |
> 합 81. P2 트리거: G-5(GA4 전기간)·E-6(FTG_B)·E-1/E-4(ERP·AGENCY 비용)·Q10(캠페인 연결키)·O3(ROI 비용배분).

### 8.4 활성여부 분포 (capability 기준)
| 활성여부 | 수 | 지표 |
|---|---:|---|
| 활성 (즉시) | 58 | MONTHLY 36(공45~80·59·60·신12~29) + EVENT 7(공58·신2~7) + SERVICE 13(신30·31·34·39~42·44·47~49·52·53) + AD 2(공8·9) |
| 활성(브리지) | 15 | conformed 3(공1·2·3) + cross-source 3(공81·신32·신33) + 코호트 9(신35·36·37·38·43·45·46·50·51) |
| 부분 | 1 | 신8(LTV, 24년~) |
| placeholder | 4 | 공7 · 공10 · 공98 · 공108 |
| 보류 | 3 | 신9 · 신10 · 신11 |
> 합 = 58 + 15 + 1 + 4 + 3 = **81** ✓. 브리지·placeholder·보류는 2단계에서 뷰/base 선행조건 명시.
> **2단계 실측 개선(2026-07-21)**: 공80 placeholder→**활성**(FMM.UNPAID_FLAG_BOM/EOM 실재)·§6-B(공56·57·77·78) 해소(FMM.NEW_EXISTING_FLAG 시점귀속) → placeholder 5→4·활성 57→58.

### 8.5 미해결·합의 플래그 (04 §6 A~G, 임의수정 금지 — 정본 그대로 배속)
- **§6-A** 공46 활동율 분자/분모 역방향 (#45·47과 상충) → 현업 확인. *(잔여)*
- ~~**§6-B**~~ ✅**해소(2단계 실측)**: 공56·57·77·78 신규/기존 = `FMM.NEW_EXISTING_FLAG`(시점귀속 실재) → as-of 정합.
- ~~**§6-C**~~ ✅**해소(2단계 실측)**: 공80 = `FMM.UNPAID_FLAG_BOM`/`UNPAID_FLAG_EOM`(월초·월말 미납회원) 실재 → COUNT DISTINCT 차분.
- **§6-D** 공81·신32·신33 identity(DIM_MEMBER_IDENTITY) + 클릭=명(≠CLICKS 횟수) → 브리지·Phase 2. *(잔여, 커버리지 4.2%)*
- **§6-E** 신6 "이탈율" 명칭 vs 유지율 식 상충 → 정본 식 우선, 명칭 합의. *(잔여)*
- **§6-F** 신30 분모 "전체회원수"(활동/전체 universe) 미정 → 분모 확정 전 주의. *(잔여)*
- **§6-G** 공7·신9 광고비 출처 이원화(FAD AGENCY 실적 vs FBD ERP 편성/모금성) → 지표별 명시. *(잔여)*

---

## 9. 다음 단계(2단계) 입력
- SV별 base_table(GOLD 물리)·relationship(FACT↔DIM 조인키, `06_DDL.sql` 실컬럼)·노출 dimension·base measure를 본 배속표 기준으로 설계.
- **활성 metric 우선 설계**, placeholder는 정의만(비활성 주석), 보류 3건(신9~11)은 2단계 대상 제외(입고 트랙).
- **브리지 뷰 설계(R1)**: 목표대비(FME+FTG_D, MONTH×ORG×DEV_TYPE) · 코호트(FSE×FME/FMM, +5일차) · cross-source(공81·신32·신33, IDENTITY) — raw 다중 FACT relationship 금지, conformed grain 사전집계 뷰로만.
- **Cortex Search 백킹(R2)**: 캠페인명·후원사업명·세세목명·회원명 등 고카디널리티 텍스트 차원 식별.

---
_Co-authored with CoCo_
