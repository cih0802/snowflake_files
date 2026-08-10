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
| 신8 | 개발캠페인별 LTV(원) | AVG(PAID_FEE/member) × 평균 활동기간(신4) | FMM·FME | **부분** | N | 22년~ | P1 | 회비데이터 2022-01~ 전량(실측 46.4M·2021↓ 이관잔재 <650행/월). 납입회비=FMM cross. ⚠합의·Phase-2 |

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

## 5. SV_AD (base = **GOLD.WIDE_AD_COMBINED** [2026-08-10 O54] 재배선 · 종전 SERVING.FACT_AD_COMBINED, 일×광고실적) — 4 metric [**Phase 1** ✅ 2026-07-28 배포]

> overall Agent(2026-07-28 배정 변경: 마케팅 Agent → **AGENT_OVERALL** analyst_ad). §3 광고 CTR·개발단가(공7~10).
> **2026-07-28 정정**: FAD "스캐폴드" 전제 **부분 해제**. BRONZE→GOLD 확장으로 measure·degenerate 축 실적재 → **공7·9·10 P1 승격**.
> 핵심 반전 2건:
> 1. **개발단가 분모가 FMM이 아니다** — `FACT_AD_DIGITAL.CRM_DEV_CNT`(249,390)·`FACT_AD_BROADCAST.DVLP_CNT`(96,321)가 **광고 팩트 내부에 동반 적재** → FAD×FMM 크로스팩트 conform **불필요**. (Snowflake SV는 metric 식의 cross-table 참조를 금지하므로 크로스팩트 개발단가는 애초에 SV로 구현 불가였음 → `SERVING.FACT_AD_COMBINED` helper로 해소. 04 §6.0)
> 2. **공10 CVR 분자 실재** — `GA_CONV_MEMBERS` 122,551 적재 → placeholder 해제.
> 잔류 차단: **캠페인/소재별 분해**(CAMPAIGN_SK·AD_CREATIVE_SK 전건 0, Q10). ~~공8 방송 개발단가~~ → **2026-07-29 복원**(커버리지 5.2%·41% 왜곡은 VIDEO를 분모에 넣은 범주 오류. 재방송 단독 96.03%·왜곡 0.61%).
> ⚠ **추가 실측 정정(같은 날)**: 아래 2건은 초기 검토의 오판이었다.
>   (a) "2026-06 CRM_DEV_CNT NULL = 적재 지연" → **오진**. 2026-06부터 원천이 개발건수 대신 단가(`DEV_UNIT_PRICE_SRC` 8,401건)를 제공하는 **포맷 변경**이며, 두 컬럼은 **완전 상호배타**다(04 §6.4.2).
>   (b) "자체계산값 vs 대행사 산정값 교차검증 가능" → **불가**. 같은 행에 공존하지 않으므로 검증 대상이 아니라 **기간 보완 관계**다(§6-G 정정).

| # | derived | 분자 ÷ 분모 (SSOT 직역) | base FACT | 활성여부 | 가산성 | 시간 | Phase | 비고 |
|---|---|---|---|---|---|---|---|---|
| 공7 | CRM 개발단가(원) | **SUM(CASE WHEN CRM_DEV_CNT IS NOT NULL THEN AD_COST END)** ÷ CRM_DEV_CNT | **FACT_AD_COMBINED 단일** | **활성** | N | 디지털 **2024-01~2026-05** | **P1** ✅ | 배포명 `DEV_UNIT_PRICE`. 실측 2024 131,367원/2025 110,335원/2026(1~5월) 103,066원. ⚠**분자 정합 필수** — 미정합 시 2026 125,482원으로 과대계상(04 §6.4.1). ⚠2026-06~ 산출 불가(원천 포맷 변경, 04 §6.4.2). ⚠`CRM_DEV_CNT` 소수값 24,614/189,252행(13.0%) → 어의 확정 전 "건수" 단정 금지 |
| 공8 | 재방송 개발단가(원) | AD_COST ÷ DVLP_CNT(재방송) | FACT_AD_COMBINED | **활성** | N | 방송(재방송) | **P1** ✅ | **복원(2026-07-29)** — 2026-07-28 "커버리지 5.2%→41% 왜곡" 배포취소는 **오진**. `DVLP_CNT`는 `REBRDC_AD_CMPGN_DTLS` 전용이고 `VIDEO_AD_CMPGN_DTLS`에는 개발 컬럼이 **구조적으로 부재**(비디오 리포트=전환콜 보고) → VIDEO를 분모 모집단에 넣은 범주 오류였다. **REBROADCAST 단독 커버리지 96.03%**(1,982/2,064) · 정합 왜곡 **0.61%**(158,933→157,969원). metric명 `REBRDC_DEV_UNIT_PRICE`(방송 전체가 아닌 재방송 한정임을 명시). 원 정의의 "SRC=GA4"와 실현체(재방송 DVLP_CNT) 불일치는 잔여(§6-I) |
| 공9 | GA CTR(%) | CLICKS ÷ IMPRESSIONS ×100 | FACT_AD_COMBINED | **활성** | N | 디지털 전용 | **P1** ✅ | 실측 2024 0.199%/2025 0.286%/2026 0.345%. ⚠**디지털 전용** — AD_SOURCE_TYPE='DIGITAL' 필터 필수(방송행 노출·클릭 NULL이라 분모 왜곡) |
| 공10 | GA CVR(%) | GA_CONV_MEMBERS(명) ÷ CLICKS ×100 | FACT_AD_COMBINED | **활성** | N | 디지털 전용 | **P1** ✅ | placeholder→활성. ✅O5 분자=전환'명' 확정 + `GA_CONV_MEMBERS` 122,551 실적재 |

**SV_AD 소계 = 4** (공7·9·10 = **P1 승격**, 2026-07-28 / **공8 = P1 복원**, 2026-07-29 — 종전 커버리지 결함 판정은 오진) → **SV_AD 4건 전부 P1**

**▶ 배포 시 추가된 신규 measure (본 배속표 미등재 → 차기 개정 반영 대상)**
| measure | 실측 | 스코프 |
|---|---|---|
| TOTAL_AD_COST | 514.4억원(디지털 299억+재방송 153억+방송 62억) | 전체 합산 허용 |
| TOTAL_READ_CNT | 8.17M | 디지털 |
| TOTAL_MEDIA_POTENTIAL | — | 디지털 |
| TOTAL_AD_CNT(방송횟수) | 36,712 | 방송 |
| TOTAL_CONV_CALL_CNT | 49,093 | 방송 |
| TOTAL_INBOUND_CALL | 165,462 | 방송 |
| TOTAL_DVLP_MEMBER_CNT | — | 방송 |
> ⚠ **N(비가산) 클래스 추가 필요** — §0.3에 GA4 2건(공98·108)만 열거돼 있으나, 대행사 산정 `_SRC` **8종**(CTR_SRC·CVR_SRC·CPC_SRC·CPM_SRC·CPA_SRC·DEV_UNIT_PRICE_SRC·VTR_SRC·AD_VIEW_RT_SRC)이 동반 적재됨. 행 단위 참고값이며 **SUM/AVG 재집계 금지** → SV metric 미노출, instruction으로 차단.

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
| **P1** (즉시 배포) | **73** | MONTHLY 39(공81 제외) + EVENT 8 + SERVICE 22(신32·33 제외) + PARTICIPATION 0(base 전용) + **AD 4(공7·9·10 2026-07-28 승격 + 공8 2026-07-29 복원)** |
| **P2** (입고 후) | **8** | 공81 · 신32 · 신33 (GA cross) + SV_GA 2 + SV_BUDGET 3 |
> 합 81. P2 트리거: G-5(GA4 전기간)·E-6(FTG_B)·E-1/E-4(ERP·AGENCY 비용)·O3(ROI 비용배분). ~~방송 DVLP_CNT 적재 확대(공8)~~ → 트리거 해소(2026-07-29 복원). 단 **VIDEO 개발단가**는 원천에 개발 컬럼 자체가 없어 대행사 리포트 항목 신설 요청이 선행돼야 한다(별건).
> **2026-07-28 개정**: SV_AD 3건 P2→P1(69→72 / 12→9). 공8은 분모 커버리지 5.2% 결함으로 P2 잔류.
> **2026-07-29 개정**: 공8 P2→**P1 복원**(72→73 / 9→8). 5.2%는 VIDEO(개발 컬럼 구조적 부재)를 분모 모집단에 포함시킨 오산이며, 재방송 단독 커버리지는 96.03%다. **Q10(캠페인 연결키)은 P2 트리거에서 제외** — 공7·9·10은 Q10 없이 산출 가능하고, Q10은 이제 "캠페인/소재별 **분해**"(신#9·DIM_AD_CREATIVE CS)만 차단한다.

### 8.4 활성여부 분포 (capability 기준)
| 활성여부 | 수 | 지표 |
|---|---:|---|
| 활성 (즉시) | 59 | MONTHLY 36(공45~80·59·60·신12~29) + EVENT 7(공58·신2~7) + SERVICE 13(신30·31·34·39~42·44·47~49·52·53) + **AD 3(공7·9·10)** |
| 활성(브리지) | 15 | conformed 3(공1·2·3) + cross-source 3(공81·신32·신33) + 코호트 9(신35·36·37·38·43·45·46·50·51) |
| 부분 | 1 | 신8(LTV, 22년~) |
| placeholder | 2 | 공98 · 공108 |
| 보류 | 3 | 신9 · 신10 · 신11 *(공8은 2026-07-29 보류 해제 → 활성)* |
> 합 = 59 + 15 + 1 + 2 + 4 = **81** ✓. 브리지·placeholder·보류는 2단계에서 뷰/base 선행조건 명시.
> **2단계 실측 개선(2026-07-21)**: 공80 placeholder→**활성**(FMM.UNPAID_FLAG_BOM/EOM 실재)·§6-B(공56·57·77·78) 해소(FMM.NEW_EXISTING_FLAG 시점귀속) → placeholder 5→4·활성 57→58.
> **2026-07-28 개정**: 공7·공10 placeholder→**활성**(광고 팩트 내부 분모·GA_CONV_MEMBERS 실적재), 공8 활성→**보류**(커버리지 결함) → placeholder 4→2·활성 58→59·보류 3→4.
> **2026-07-29 개정**: 공8 보류→**활성 복원**(오진 교정) → 활성 59→60·보류 4→3.

### 8.5 미해결·합의 플래그 (04 §6 A~G, 임의수정 금지 — 정본 그대로 배속)
- **§6-A** 공46 활동율 분자/분모 역방향 (#45·47과 상충) → 현업 확인. *(잔여)*
- ~~**§6-B**~~ ✅**해소(2단계 실측)**: 공56·57·77·78 신규/기존 = `FMM.NEW_EXISTING_FLAG`(시점귀속 실재) → as-of 정합.
- ~~**§6-C**~~ ✅**해소(2단계 실측)**: 공80 = `FMM.UNPAID_FLAG_BOM`/`UNPAID_FLAG_EOM`(월초·월말 미납회원) 실재 → COUNT DISTINCT 차분.
- **§6-D** 공81·신32·신33 identity(DIM_MEMBER_IDENTITY) + 클릭=명(≠CLICKS 횟수) → 브리지·Phase 2. *(잔여, 커버리지 4.2%)*
- **§6-E** 신6 "이탈율" 명칭 vs 유지율 식 상충 → 정본 식 우선, 명칭 합의. *(잔여)*
- **§6-F** 신30 분모 "전체회원수"(활동/전체 universe) 미정 → 분모 확정 전 주의. *(잔여)*
- **§6-G** 공7·신9 광고비 출처 이원화(FAD AGENCY 실적 vs FBD ERP 편성/모금성) → 지표별 명시. *(부분 해소 2026-07-28: 공7은 **FAD AGENCY 실적 광고비**로 확정 배포. ⚠단, 대행사 산정 `DEV_UNIT_PRICE_SRC`(8,401건)로 **교차검증은 불가** — 자체 분모 `CRM_DEV_CNT`와 **완전 상호배타**(2026-05까지 자체 / 2026-06부터 대행사)라 같은 행에 공존하지 않는다. 검증 관계가 아니라 **기간 보완 관계**. 신9(예산 기반)는 FBD AD_COST=0으로 잔여.)*
- **§6-H** *(신규 2026-07-28)* `FACT_AD_DIGITAL.CRM_DEV_CNT` **소수값 24,614행/189,252행(13.0%)**, min 0.0·max 322.0 → 기여도 배분(fractional attribution)값인지 어의 확인 전 "개발건수" 단정 금지. 공7 개발단가 해석에 직접 영향. *(잔여, 현업 확인 필요)*
- **§6-I** *(신규 2026-07-28 · 2026-07-29 교정)* 공8 "GA 개발단가"가 실제로는 **재방송(REBROADCAST) `DVLP_CNT`** 기반으로 실현됨 — 원 정의의 "SRC=GA4"와 불일치. ~~분모 커버리지 5.2%로 41% 왜곡되어 미노출~~ → **오진 철회**: `DVLP_CNT`는 `REBRDC_AD_CMPGN_DTLS` 전용이고 VIDEO 원천에는 개발 컬럼이 없다(구조적 부재). 재방송 단독 커버리지 96.03%·왜곡 0.61% → `REBRDC_DEV_UNIT_PRICE`로 **노출**. **잔여 확인사항은 지표명·정의(SRC=GA4 표기)** 2건이며 적재범위는 해소. *(부분 잔여)*
- **§6-J** *(신규 2026-07-28)* **2026-06 원천 포맷 변경** — 디지털 광고 원천이 개발건수(`CRM_DEV_CNT`) 제공을 중단하고 단가(`DEV_UNIT_PRICE_SRC`)를 직접 제공. 개발단가(공7)는 **2026-05까지만 산출 가능**. 이후 기간 추적 방식(원천에 건수 재요청 vs 대행사 단가 채택 — 정의가 다름) 결정 필요. *(잔여, 파이프라인·현업 공동 확인)*

#### 8.5.1 §6-H·§6-I·§6-J 근거 쿼리 (구 13_SV_AD_배포_추가작업.sql §6 이관, 2026-07-31)

현업 합의를 받으러 갈 때 그대로 실행해 근거로 제시할 쿼리다. 실측값은 2026-07-28 cs94293 기준이며, 계정·적재시점이 다르면 절대값은 달라진다(판정 논리는 동일).

**(1) §6-H — `CRM_DEV_CNT` 소수값 실태**: "개발건수"인데 소수인 이유 확인용.
```sql
SELECT COUNT(*)                                    AS rows_with_val,
       COUNT_IF(CRM_DEV_CNT != FLOOR(CRM_DEV_CNT)) AS non_integer_rows,
       MIN(CRM_DEV_CNT) AS min_val, MAX(CRM_DEV_CNT) AS max_val, SUM(CRM_DEV_CNT) AS total_val
FROM GN_DW.GOLD.FACT_AD_DIGITAL
WHERE CRM_DEV_CNT IS NOT NULL;
```
실측: `rows_with_val=189,252` · **`non_integer_rows=24,614`(13.0%)** · min 0.0 · max 322.0 · total 249,390.45 → **소수값 실재 확정**. 기여도 배분(fractional attribution) 가능성 → 현업 확인 전 "건수" 단정 금지.

**(2) §6-G/§6-J — 자체계산 개발단가 vs 대행사 산정값**
```sql
SELECT d.YEAR,
       SUM(CASE WHEN c.CRM_DEV_CNT IS NOT NULL THEN c.AD_COST END)
         / NULLIF(SUM(c.CRM_DEV_CNT), 0) AS dev_unit_price_calc,
       AVG(c.DEV_UNIT_PRICE_SRC)         AS dev_unit_price_src_avg,
       COUNT(c.CRM_DEV_CNT)              AS rows_crm_dev,
       COUNT(c.DEV_UNIT_PRICE_SRC)       AS rows_src
FROM GN_DW.GOLD.WIDE_AD_COMBINED c
JOIN GN_DW.GOLD.DIM_DATE d ON c.PERF_DATE_SK = d.DATE_SK
WHERE c.AD_SOURCE_TYPE = 'DIGITAL'
GROUP BY 1 ORDER BY 1;
```
실측: 2024·2025 = calc만 존재(src 0행) / 2026 = calc 103,066원 + src_avg 29,018원(8,401행) → **교차검증 불가**. 두 컬럼은 완전 상호배타로 같은 행에 공존하지 않으므로 "자체값 vs 대행사값 검증"이 아니라 **기간 보완 관계**다(04 §6.4.2 · §6-G 정정 반영).
⚠ `DEV_UNIT_PRICE_SRC`는 행 단위 비율(N, 비가산) — AVG는 분포 확인용 참고일 뿐 정본 지표로 쓰지 말 것(SV metric 미노출 · Agent instruction으로 재집계 차단됨).

**(3) §6-J 근거 — 2026-06 은 적재 지연이 아니라 포맷 변경**
```sql
SELECT d.YEAR, d.MONTH, COUNT(*) AS rows_total,
       COUNT(c.CRM_DEV_CNT) AS rows_crm_dev, COUNT(c.DEV_UNIT_PRICE_SRC) AS rows_src
FROM GN_DW.GOLD.WIDE_AD_COMBINED c
JOIN GN_DW.GOLD.DIM_DATE d ON c.PERF_DATE_SK = d.DATE_SK
WHERE c.AD_SOURCE_TYPE = 'DIGITAL' AND d.YEAR = 2026
GROUP BY 1, 2 ORDER BY 1, 2;
```
실측: 2026-01~05 = crm_dev 전건 / src 0 ‖ 2026-06 = crm_dev **0** / src **8,401 전건** → 원천이 개발건수 제공을 중단하고 단가를 직접 제공하는 포맷으로 변경됨.
▶▶ **현업·파이프라인 결정 필요**: 2026-06 이후 개발단가를 계속 추적하려면 (a) 원천에 개발건수 재요청, 또는 (b) `DEV_UNIT_PRICE_SRC` 채택(정의가 다름 — 대행사 기준).

**(4) §6-I / 비율 metric 분자·분모 커버리지 정합 점검** — 신규 비율 metric 추가 시 필수 체크(04 §6.4.1)
```sql
SELECT AD_SOURCE_TYPE, COUNT(*) AS rows_total,
       COUNT(CRM_DEV_CNT) AS rows_denom_dig, COUNT(DVLP_CNT) AS rows_denom_brc,
       SUM(AD_COST)/NULLIF(SUM(CRM_DEV_CNT),0) AS dig_unaligned,
       SUM(CASE WHEN CRM_DEV_CNT IS NOT NULL THEN AD_COST END)
         /NULLIF(SUM(CRM_DEV_CNT),0)           AS dig_aligned,
       SUM(AD_COST)/NULLIF(SUM(DVLP_CNT),0)    AS brc_unaligned,
       SUM(CASE WHEN DVLP_CNT IS NOT NULL THEN AD_COST END)
         /NULLIF(SUM(DVLP_CNT),0)              AS brc_aligned
FROM GN_DW.GOLD.WIDE_AD_COMBINED
GROUP BY 1 ORDER BY 1;
```
실측 판정: 디지털 개발단가 = 분모 커버리지 95.7% · 미정합 119,951 vs 정합 114,870 = +4.4% → **분자 정합 후 노출** ✅ / 방송 개발단가 = AD_SOURCE_TYPE 전체를 분모로 본 커버리지 5.2% · +41% → 당초 미노출 결정. ⚠ 단 이 5.2%는 **VIDEO를 분모 모집단에 넣은 범주 오류**였고(§6-I 오진 철회), REBROADCAST 단독으로는 96.03%다.
▶ **규칙**: 신규 SUM/SUM 비율 metric 은 (1) 분모 커버리지가 90% 미만이면 정합해도 노출 재검토, (2) 분자는 항상 `CASE WHEN <분모> IS NOT NULL THEN <분자> END` 로 제한한다. (3) 분모 모집단을 **컬럼이 구조적으로 존재하는 세그먼트로 한정**한 뒤 커버리지를 재다.

---

## 9. 다음 단계(2단계) 입력
- SV별 base_table(GOLD 물리)·relationship(FACT↔DIM 조인키, `06_DDL.sql` 실컬럼)·노출 dimension·base measure를 본 배속표 기준으로 설계.
- **활성 metric 우선 설계**, placeholder는 정의만(비활성 주석), 보류 3건(신9~11)은 2단계 대상 제외(입고 트랙).
- **브리지 뷰 설계(R1)**: 목표대비(FME+FTG_D, MONTH×ORG×DEV_TYPE) · 코호트(FSE×FME/FMM, +5일차) · cross-source(공81·신32·신33, IDENTITY) — raw 다중 FACT relationship 금지, conformed grain 사전집계 뷰로만.
- **Cortex Search 백킹(R2)**: 캠페인명·후원사업명·세세목명·회원명 등 고카디널리티 텍스트 차원 식별.

---
_Co-authored with CoCo_

---

## 🔖 [2026-08-05 세션 반영] O38-E · O39 · O40 · O40-B

> 정본 = `20_issue/10_진단_원인분석.md` **§22-J(O38-E) · §23(O39) · §24(O40)** · 신규 원칙 **P77~P82**.

### `SV_MEMBER_MONTHLY` — 회비 지표 정본/결함 metric 분리 (O40)

| 구분 | metric | 정의 | 자연어(synonym) |
|---|---|---|---|
| 🟢 정본 | `TOTAL_PAID_FEE_BILLABLE` | `SUM(PAID_FEE_BILLABLE)` | 납입회비 |
| 🟢 정본 | `PAYMENT_RATE_FEE` | 회비 납입 ÷ 회비 청구 ×100 | **납부율**·수납율 |
| 🟢 정본 | `TOTAL_UNPAID_AMT_DEC3` | `SUM(UNPAID_BILLED_AMT)` (DEC-3) | **총미납금액**·미납액 |
| 🟢 정본 | `UNPAID_RATIO_DEC3` | 미납청구 ÷ 회비청구 ×100 | **미납비중**·미납율 |
| 🔴 결함(보존) | `TOTAL_PAID_FEE` | `SUM(PAID_FEE)` = 회비+기부금 | 총수납액(만) |
| 🔴 결함(보존) | `PAYMENT_RATE` | 분자에 기부금 혼입 → **과대**(전 기간 100.36%) | 수납율(총액기준) |
| 🔴 결함(보존) | `TOTAL_UNPAID_AMT`·`UNPAID_RATIO` | 차감식 → **과소**(전 기간 −32억) | (차감식) 표기 |

결함 metric 은 저장쿼리·문서 참조 보호를 위해 **삭제하지 않고** 「단독 인용 금지」 경고와 함께 남겼다.
**자연어 표현은 전부 정본으로 이전**했다(라이브 DDL 로 라우팅 확인). 2025 정본값 = 납부율 **85.65%** ·
미납 **29,251,314,636** · 미납비중 **14.29%**.
`AI_SQL_GENERATION` 에 **「마감·확정」 단정 금지 + 조회 시점 적재 기준 명시** 추가(2025년분이 2026-07-01
까지 납입된 실측 근거).

### `SV_SERVICE` — synonym 교차오염 교정 (O39)
`TOTAL_SEND_MEMBERS = SUM(SEND_MEMBERS)` 는 **건수**인데 synonym 에 `'발송 회원수'` 가 붙어 있었고,
정작 옳은 `DISTINCT_SEND_MEMBERS = COUNT(DISTINCT MEMBER_DK)` 에는 없었다 → 「발송 회원수」 질문에
**37.3배**(38,470,780 vs 1,031,971)를 답할 수 있었다. synonym 을 정본으로 이전했다.
🆕 **P79**: 정의가 옳아도 **라우팅이 틀리면 오답**이다 — 건/명·총계/고유처럼 **쌍을 이루는 metric** 이 있으면
synonym 교차오염을 반드시 점검한다(값이 그럴싸해 무증상).

### `SV_DEV_ACHIEVEMENT` — 규모 하한 가드 (O38-E)
`HAS_POSITIVE_GOAL` 차원을 **물리 컬럼 참조**로 전환(판정 규칙 정본을 뷰 하나로 집중 · 값 불변 확인).
`ORG_DEPARTMENT` COMMENT + `AI_SQL_GENERATION` 에 **달성율 순위 시 `TOTAL_GOAL_CNT` 동반 제시 필수 ·
극소 규모 부서 단독 1위 금지 · 하한 되묻기** 추가 — 목표가 월 5건인 센터가 **171.7% 로 1위**가 된 실측
때문이다(스코프 결함 아님 = **실제 초과 달성** · 목표 보유 203부서 중 1건 · 그 부서 목표는 전체의 0.0013%).
🆕 **P77**: `>100%` 불변식은 **grain 종속**이다 — 집계 grain 에서만 결함 신호이고 세부 grain 의 초과는 정상.
초과를 보면 base 행을 열어 스코프 결함인지 먼저 가른다.

### 전 SV 공통 점검 규약 (신설)
1. 비율·차액 metric → **①상한(>100%) ②부호(음수)** 스모크. 상한 검사에는 **적용 grain 을 명시**(P77·P80).
2. 순위 질문이 가능한 비율 → **분모 규모 동반 제시**를 서술로 심는다(소표본 1위 방지 · P76).
3. 쌍을 이루는 metric → **synonym 교차오염 점검**(P79).
4. 서로 다른 원천을 합산한 measure → 소비 계층에서 정화 불가 → **판별 축을 같은 grain 에 요구**(P81).
5. 「적재 대기」류 상태 문구는 적재 후 **반드시 제거**(사문화 주석이 정상 지표를 "대기 중"으로 답하게 만든다).

_Co-authored with CoCo_
