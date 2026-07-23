---
project_id: GN_DW
doc_type: work_plan_chapter
chapter: "03_GOLD_SERVING"
sections: [3.5, 3.6, 3.7, 3.8, 3.9]
index: "00_INDEX.md"
depends_on: ["02_DB_BRONZE_SILVER.md"]   # SILVER 테이블 필요
provides: [gold_star_schema, gold_wide_views, semantic_views, agents, grants]
language: ko (설명) / en (구조 키)
gold_canonical_ref: "../03_top-down_gold/"      # ← GOLD 정본 설계 폴더
serving_canonical_ref: "../05_SV-Agent_ai/"     # ← SV/Agent 정본 설계 폴더
---

# 03. GOLD & SERVING — 정본 선언 및 구조 요약

> 인덱스: `00_INDEX.md` · 핵심 원칙(P1~P7)은 인덱스 참조.
> **GOLD 설계 정본**: `03_top-down_gold/` 폴더의 Top-down star schema(15 DIM + 9 FACT).
> **SERVING(SV·Agent) 정본**: `05_SV-Agent_ai/` 폴더.
> 본 문서는 라이브 배포(2026-07-22) 기준 GOLD·SERVING **구조 요약**이다. 상세 설계는 각 정본 폴더 참조.
>
> ⚠️ **[구설계 정정]** 구버전 본 문서의 "레거시 GOLD View 35개 병존"·"레거시 SV 7 / Agent 1 → star schema 전환 로드맵" 서술은 **폐기**한다. 라이브 실측 결과 GOLD에 레거시 PoC View는 없고 **평탄화 WIDE VIEW 9개**만 존재하며, SERVING에는 **star schema 기반 SV 5개 + Agent 2개 + 보조뷰 2개**가 배포되어 있다(전환 로드맵의 목표 상태가 이미 라이브).

---

## 3.5 GOLD 물리 구조 — Star Schema (정본)

> **상세 설계**: `03_top-down_gold/GOLD_차원 설계.md`, `GOLD_팩트 설계.md`, `06_DDL.sql`
> **SILVER 의존**: `03_top-down_gold/GOLD_SILVER 의존.md` · **적재**: dbt `GN_DW.OPS.DW_PIPELINE`(02 §4)

### 핵심 수치
- **15 DIM + 9 FACT** = star schema 24 물리 테이블 (라이브 실측)
- measure 60 + dimension 74 + derived 81 = 215개 지표 커버
- 물리 base measure = measure 60 + GOAL_CNT 1(비지표번호) = **61**
- measure 배속: FMM 28 · FSE 17 · FGA 7 · FTG-B 4 · FAD 4 = 60 (+ FTG-D GOAL_CNT 1)

### DIM 목록 (15)

> 명명: 대리키 `*_SK`(버전 단위) · durable key `*_DK`(불변) · 비즈니스키 `*_BK`(소스 원본키). SCD: **1**=덮어쓰기, **2**=이력보존, **정적**=불변.

| DIM | 설명 | SCD | 라이브 행수 |
|---|---|---|---|
| DIM_DATE | 날짜 캘린더(1행=1일, 팩트 공통 시간축) | 정적 | 16,437 |
| DIM_MEMBER | 회원 마스터(느린 범주형만; SK/DK 분리) | SCD2(상태·지역·신규기존·중단), SCD1(성별·가입일·캠페인) | 7,925,716 |
| DIM_MEMBER_IDENTITY | 회원 신원 브리지(MEMBER_DK↔ga_member_id, 1:N) | SCD1 | 1,763,066 |
| DIM_CAMPAIGN | 캠페인(ORG_SK 경유로 조직 귀속) | SCD1 | 36,144 |
| DIM_SPONSORSHIP | 후원사업(캠페인과 분리) | SCD1 | 51 |
| DIM_ORG | 조직·부서(전 노드 적재, ORG_BK=DEPT_ID 조인) | SCD1 | 1,315 |
| DIM_AD_CREATIVE | AGENCY 광고 소재/매체 | SCD1 | 8,474 |
| DIM_GA_SOURCE | GA 세션 트래픽 소스(utm) | SCD1 | 111 |
| DIM_SERVICE | 발송/참여 서비스(SERVICE_TYPE subtype) | SCD1 | 11 |
| DIM_PAYMENT | 납입방식(×회비유형 보류) | SCD1 | 7 |
| DIM_GA_EVENT | GA 이벤트 분류(category/label/action) | SCD1 | 2,842 |
| DIM_REASON | 사유(중단/미납) | SCD1 | 5,835 |
| DIM_DEVICE | 디바이스(PC/M/APP) | 정적 | 3 |
| DIM_EVENT | 행사/이벤트(온·오프라인, 행사기간·신청경로) | SCD1 | 3,787 |
| DIM_BUDGET_ITEM | 예산 세세목·예산구분 (ERP, `_SOURCE_SYSTEM`) | SCD1 | 2,041 |

### FACT 목록 (9)

> 회원 식별은 모두 **MEMBER_DK**(불변). 월 grain 팩트(FMM·FTG-D·FTG-B·FBD)는 **MONTH_KEY(YYYYMM)**, 일 grain 팩트(FME·FSE·FGA·FAD·FEP)는 **DATE_SK** 사용(시간 grain 혼재 차단).

| FACT | grain | 주요 measure | 라이브 행수 |
|---|---|---|---|
| FMM `FACT_MEMBER_MONTHLY` | 조회년월(MONTH_KEY)×회원(MEMBER_DK) | 납입회비·개발/중단/미납·증감액 등 28 (HAS_BILLING 필터) | 40,054,883 |
| FME `FACT_MEMBER_EVENT` | 사건일(DATE_SK)×회원×상태전이(EVENT_TYPE) | 개발·중단·증액·미납중단(건·명) | 4,633,105 |
| FTG-D `FACT_TARGET_DEV` | 조회년월×조직(ORG)×개발구분 | GOAL_CNT 회원개발목표수 ✅CRM 확정 | 7,272 |
| FTG-B `FACT_TARGET_BIZ` | 조회년월×조직×후원사업[×캠페인] | 연사업/추경목표(건) #152~155 | 0 (⛔E-6 CRM 입고 대기) |
| FSE `FACT_SERVICE_EVENT` | 발송일×회원×서비스×캠페인 | 발송/성공/실패·서신/선물금 참여 등 17 | 38,470,780 |
| FGA `FACT_GA_BEHAVIOR` | 일×IDENTITY×이벤트×세션소스×페이지 | 방문·활성/총사용자·세션·이벤트 등 7 | 44,905 |
| FAD `FACT_AD_PERFORMANCE` | 일×캠페인×광고소재/매체 | 광고비·노출·클릭·인입콜 4 | 235,572 |
| FEP `FACT_EVENT_PARTICIPATION` | 일×회원×행사(EVENT) | 참여/불참/대기 인원·횟수 | 1,134,126 |
| FBD `FACT_BUDGET` | 조회년월×조직×예산세세목[×캠페인] | 편성/집행예산·모금성비용·광고비 | 24,480 |

> **목표 팩트 2분할(결정 9)**: FTG-D=CRM 회원개발목표(`CRM_DEV_TARGET`, 확정), FTG-B=CRM 사업목표(`CRM_BIZ_TARGET`, E-6 입고 대기·0행). 둘 다 ORG·MONTH_KEY conformed, 회원 grain 아님 → FMM과 직접 합산 금지.
> ⚠️ **[결론7] ERP 예산원장 캠페인·매체 연결키 부재**: 캠페인별/매체별 예산 ROI 산출 불가(조직×월 grain의 목표 대비 실적까지만).
> ⚠️ **[결론4/5·A-2]** FAD 인입콜 타입 불일치(TRY_TO_NUMBER)·AGENCY 3소스 `_SOURCE_SYSTEM` 부여는 SILVER에서 처리(02 §3.4).

---

## 3.5-W GOLD 평탄화 뷰 — WIDE VIEW (9)

> **위치**: `GN_DW.GOLD` 스키마 내 VIEW (dbt view materialization).
> **역할**: 각 FACT에 관련 DIM을 조인·평탄화하여 BI/탐색·SV base로 제공. FACT 9개와 1:1 대응.
> ⚠️ 구설계의 "레거시 PoC View 35개(A/B/C 계열)"는 **존재하지 않음**. 아래 WIDE 9가 GOLD의 유일한 뷰 계층이다.

```yaml
gold_wide_views:   # 9 (FACT 1:1)
  - { id: WIDE_MEMBER_MONTHLY, base: FMM, note: "×MEMBER[현재]·CAMPAIGN·SPONSORSHIP·PAYMENT·REASON. 월 grain=MONTH_KEY" }
  - { id: WIDE_MEMBER_EVENT, base: FME, note: "×DATE·MEMBER[현재]·CAMPAIGN·SPONSORSHIP·ORG[as-was]·REASON" }
  - { id: WIDE_SERVICE_EVENT, base: FSE, note: "×DATE·MEMBER[현재]·SERVICE·CAMPAIGN" }
  - { id: WIDE_GA_BEHAVIOR, base: FGA, note: "×DATE·IDENTITY·GA_EVENT·GA_SOURCE·DEVICE·CAMPAIGN. 비가산 지표 상위 재합산 금지" }
  - { id: WIDE_AD_PERFORMANCE, base: FAD, note: "×DATE·CAMPAIGN·AD_CREATIVE·DEVICE. DIM_DATE 파생=PERF_ 접두" }
  - { id: WIDE_EVENT_PARTICIPATION, base: FEP, note: "×DATE·MEMBER[현재]·EVENT·CAMPAIGN·SPONSORSHIP" }
  - { id: WIDE_BUDGET, base: FBD, note: "×ORG[as-was]·BUDGET_ITEM·CAMPAIGN·SPONSORSHIP. 월 grain" }
  - { id: WIDE_TARGET_DEV, base: FTG-D, note: "×ORG[as-was]. 월 grain" }
  - { id: WIDE_TARGET_BIZ, base: FTG-B, note: "×ORG·SPONSORSHIP·CAMPAIGN. 월 grain. E-6 입고 대기·0행" }
```

---

## 3.6 Semantic View (semantic_views)

> `GN_DW.SERVING`에 배포(P7). base 객체는 **GOLD FACT/WIDE**(star schema). 라이브 실측 **5개 배포**(최종 목표 7 — FGA·FAD·FTG 계열은 Phase-2 확장).
> **정본**: `05_SV-Agent_ai/`. fan-out 0·SV=FACT 일치 검증 완료(순서9-E).

```yaml
semantic_views:   # 5 배포 (owner=GN_DW_ADMIN)
  - { id: SV_MEMBER_MONTHLY, base: FACT_MEMBER_MONTHLY, desc: "회원 월별 실적 — 납입/청구·납부율·개발/중단. 회비지표는 HAS_BILLING=TRUE 전제" }
  - { id: SV_MEMBER_EVENT, base: FACT_MEMBER_EVENT, desc: "회원 상태전이(일 grain) — 개발/중단 건·고유회원수. 유지율/LTV는 Phase-2" }
  - { id: SV_SERVICE, base: FACT_SERVICE_EVENT, desc: "서비스 발송 — 발송수·고유 발송회원수, 서비스구분/발송상태/발송일별" }
  - { id: SV_EVENT_PARTICIPATION, base: FACT_EVENT_PARTICIPATION, desc: "행사 참여 — 참여자수·참여건수·고유 참여회원수. 행사 미매칭 23%(EVENT_SK=0)" }
  - { id: SV_BUDGET, base: FACT_BUDGET, desc: "예산 — 편성/집행예산·집행율, 세세목/예산구분/월별. 조직/캠페인별은 적재 대기" }

deployment_notes:
  - "5 SV 모두 GOLD FACT를 base로 하는 star schema 기반(구설계 레거시 GOLD View 참조 아님)."
  - "BLOCKING-5 경계: 미적재 measure/FK(카운트·FK 전건 0 등)는 SV에서 비활성으로 표기, 입고 후 활성."
  - "최종 7 목표 대비 미배포 2 = GA(FGA)·광고(FAD)/목표(FTG) 계열 → Phase-2."
  - "synonyms(한글)·VQR·custom instruction(기간스코프 강제 P10)·평가셋으로 정확도 확보."

serving_helper_views:   # SERVING 내 보조 VIEW 2 (SV fan-out 차단용)
  - { id: DIM_MEMBER_CURRENT, base: "GOLD.DIM_MEMBER", desc: "SCD2 현재행(IS_CURRENT=TRUE)만 추출 — 1:1 회원조인. PK=MEMBER_DK" }
  - { id: DIM_MONTH, base: "GOLD.DIM_DATE", desc: "월 grain DISTINCT 추출 — 월팩트 시간차원. PK=MONTH_KEY" }
```

---

## 3.7 Cortex Agent (agents)

> `GN_DW.SERVING`에 배포. 라이브 실측 **2개**(최종 목표 3). owner=GN_DW_ADMIN. Snowflake Intelligence(CoWork) 연결 완료.
> **정본**: `05_SV-Agent_ai/08_AGENT_spec.md` · 배포 산출물(IaC): 루트 `cortex_project/`.

```yaml
agents:   # 2 배포
  - id: GN_DW.SERVING.AGENT_MEMBER
    spec: cortex_project/AGENT_MEMBER.agent.yaml
    domain: "회원 도메인 (4 SV): 월실적 SV_MEMBER_MONTHLY · 상태전이 SV_MEMBER_EVENT · 서비스발송 SV_SERVICE · 행사참여 SV_EVENT_PARTICIPATION"
  - id: GN_DW.SERVING.AGENT_OVERALL
    spec: cortex_project/AGENT_OVERALL.agent.yaml
    domain: "전사·재무 요약 (3 SV): 예산 SV_BUDGET(기본 도구) · 회원월실적 SV_MEMBER_MONTHLY · 발송 SV_SERVICE. ※행사 SV는 미포함"
access_roles: [GN_DW_ANALYST, GN_DW_VIEWER, GN_DW_SERVICE]
deployment_notes:
  - "배포 관리 = semantic_studio 툴 + cortex_project/cortex-project.yaml (artifact→FQN 매니페스트)."
  - "SI object ADD AGENT + 소비 3역할 USAGE 부여(CoWork 연결)."
  - "⚠️ [6-C] 트라이얼 계정 DATA_AGENT_RUN 차단 → NL 스모크 테스트는 paid 이관 대기."
  - "구버전 GN_DW_POC_AGENT / 구설계 GN_DW_AGENT(7 SV)는 폐기. 현행=AGENT_MEMBER·AGENT_OVERALL."
```

---

## 3.8 권한 부여 (grants)

```yaml
schema_grants:
  GN_DW_ADMIN:    { BRONZE_*: ALL, SILVER: ALL, GOLD: ALL, SERVING: ALL, OPS: ALL, SECURITY: ALL }
  GN_DW_ENGINEER: { BRONZE_*: SELECT, SILVER: "ALL (CREATE TABLE 포함)", GOLD: "ALL (dbt CREATE TABLE/VIEW)", SERVING: USAGE, OPS: "USAGE (dbt 실행)" }
  GN_DW_LOADER:   { BRONZE_*: "INSERT, UPDATE", SILVER: "-", GOLD: "-", SERVING: "-" }
  GN_DW_ANALYST:  { BRONZE_*: "-", SILVER: SELECT, GOLD: "USAGE, SELECT", SERVING: "USAGE + USAGE ON SV/AGENT" }
  GN_DW_VIEWER:   { BRONZE_*: "-", SILVER: "-", GOLD: "USAGE, SELECT", SERVING: "USAGE + USAGE ON SV/AGENT" }
  GN_DW_SERVICE:  { BRONZE_*: "-", SILVER: "-", GOLD: "USAGE, SELECT", SERVING: "USAGE + USAGE ON SV/AGENT" }
grant_notes:
  - "SV/Agent가 SERVING에 위치(P7) → USAGE ON SV/AGENT는 SERVING에서 부여."
  - "dbt가 GOLD/SILVER에 테이블 생성 → ENGINEER에 해당 스키마 CREATE TABLE 권한(구설계 CREATE VIEW만에서 확장)."
  - "CoWork Agent text-to-SQL은 호출자 세션에서 base(GOLD FACT/WIDE)에 직접 실행 → 소비역할 GOLD SELECT 필요."
  - "Streamlit 미배포 → STREAMLIT USAGE 부여 대상 없음(향후 배포 시 SERVING에서 부여)."
ops_security_grants:
  OPS: "GN_DW_ADMIN ALL; GN_DW_ENGINEER USAGE(dbt 실행)"
  SECURITY: "GN_DW_ADMIN만 관리 (MANAGED ACCESS)"
future_grants: "향후 생성 테이블/뷰 자동 권한 부여(FUTURE GRANTS) 설정 권장"
```

---

## 3.9 Streamlit 대시보드 (streamlit_apps)

> **라이브 실측: SERVING에 배포된 Streamlit 앱 없음(0개).** 구설계의 PoC 6종 이관 계획은 미실행 상태.
> 소비는 현재 **Cortex Agent(CoWork) + Semantic View** 중심. Streamlit은 향후 별도 트랙으로 배포 시 `GN_DW.SERVING`에 owner's rights 실행, query WH=`GN_DW_ANALYTICS_WH` 예정.

```yaml
streamlit_apps: []   # 라이브 미배포 (0)
future_plan:
  location: GN_DW.SERVING
  query_warehouse: GN_DW_ANALYTICS_WH
  note: "필요 시 GOLD WIDE VIEW 또는 SV 기반 리포트로 신규 저작"
```

---

> **이전 단계:** `02_DB_BRONZE_SILVER.md` · **다음 단계:** `04_운영 확인.md` (운영·테스트·보안·모니터링)
> **GOLD 정본:** `../03_top-down_gold/` · **SV/Agent 정본:** `../05_SV-Agent_ai/`
