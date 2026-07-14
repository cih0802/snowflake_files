---
project_id: GN_DW
doc_type: work_plan_chapter
chapter: "03_GOLD_SERVING"
sections: [3.5, 3.6, 3.7, 3.8, 3.9]
index: "00_INDEX.md"
depends_on: ["02_DB_BRONZE_SILVER.md"]   # SILVER 테이블 필요
provides: [gold_star_schema, gold_legacy_views, semantic_views, agent, grants, streamlit_apps]
language: ko (설명) / en (구조 키)
gold_canonical_ref: "../03_top-down_gold/"   # ← GOLD 정본 설계 폴더
---

# 03. GOLD & SERVING — 정본 선언 및 구조 요약

> 인덱스: `00_INDEX.md` · 핵심 원칙(P1~P7)은 인덱스 참조.
> **GOLD 설계 정본**: `03_top-down_gold/` 폴더의 Top-down star schema(15 DIM + 9 FACT)가 GOLD 물리 구조의 **정본(canonical)**이다.
> 본 문서(02 계열)는 GOLD 구조 **요약 + SERVING(SV·Agent·Streamlit) + 레거시 View 호환 계층**을 기술한다. 상세 GOLD 설계(차원·팩트·DDL·의존)는 모두 `03_top-down_gold/` 참조.

---

## 3.5 GOLD 물리 구조 — Star Schema (정본)

> **상세 설계**: `03_top-down_gold/GOLD_차원 설계.md`, `GOLD_팩트 설계.md`, `GOLD_ddl 초안.sql`
> **SILVER 의존**: `03_top-down_gold/GOLD_SILVER 의존.md`

### 핵심 수치
- **15 DIM + 9 FACT** = star schema 24 물리 테이블
- measure 60 + dimension 74 + derived 81 = 215개 지표 커버
- 물리 base measure = measure 60 + GOAL_CNT 1(비지표번호) = **61**
- measure 배속: FMM 28 · FSE 17 · FGA 7 · FTG-B 4 · FAD 4 = 60 (+ FTG-D GOAL_CNT 1)
- DDL: `03_top-down_gold/GOLD_ddl 초안.sql` (컴파일 검증 완료)

### DIM 목록 (15)

> 명명: 대리키 `*_SK`(버전 단위) · durable key `*_DK`(불변) · 비즈니스키 `*_BK`(소스 원본키). SCD: **1**=덮어쓰기, **2**=이력보존, **정적**=불변.

| DIM | 설명 | SCD |
|---|---|---|
| DIM_DATE | 날짜 캘린더(1행=1일, 팩트 공통 시간축) | 정적 |
| DIM_MEMBER | 회원 마스터(느린 범주형만; SK/DK 분리) | SCD2(회원상태·지역·신규기존·중단), SCD1(성별·가입일·캠페인) |
| DIM_MEMBER_IDENTITY | 회원 신원 브리지(MEMBER_DK↔ga_member_id, 1:N) | SCD1 |
| DIM_CAMPAIGN | 캠페인(ORG_SK 경유로 조직 귀속) | SCD1 |
| DIM_SPONSORSHIP | 후원사업(캠페인과 분리) | SCD1 |
| DIM_ORG | 조직·부서(전 노드 적재, ORG_BK=DEPT_ID 조인) | SCD1 |
| DIM_AD_CREATIVE | AGENCY 광고 소재/매체 | SCD1 |
| DIM_GA_SOURCE | GA 세션 트래픽 소스(utm) | SCD1 |
| DIM_SERVICE | 발송/참여 서비스(SERVICE_TYPE subtype) | SCD1 |
| DIM_PAYMENT | 납입방식(×회비유형 보류) | SCD1 |
| DIM_GA_EVENT | GA 이벤트 분류(category/label/action) | SCD1 |
| DIM_REASON | 사유(중단/미납) | SCD1 |
| DIM_DEVICE | 디바이스(PC/M/APP) | 정적 |
| DIM_EVENT | 행사/이벤트(온·오프라인, 행사기간·신청경로) | SCD1 |
| DIM_BUDGET_ITEM | 예산 세세목·예산구분 (ERP, `_SOURCE_SYSTEM`) | SCD1 |

### FACT 목록 (9)

> 회원 식별은 모두 **MEMBER_DK**(불변). 월 grain 팩트(FMM·FTG-D·FTG-B·FBD)는 **MONTH_KEY(YYYYMM)**, 일 grain 팩트(FME·FSE·FGA·FAD·FEP)는 **DATE_SK** 사용(시간 grain 혼재 차단).

| FACT | grain | 주요 measure |
|---|---|---|
| FMM `FACT_MEMBER_MONTHLY` | 조회년월(MONTH_KEY)×회원(MEMBER_DK) | 납입회비, 개발/중단/미납/활동(건), 증감액 등 28 |
| FME `FACT_MEMBER_EVENT` | 사건일(DATE_SK)×회원×상태전이(EVENT_TYPE) | 개발·중단·증액·미납중단(건·명); LTV/유지율 cohort base |
| FTG-D `FACT_TARGET_DEV` | 조회년월×조직(ORG)×개발구분(DEV_TYPE) | GOAL_CNT 회원개발목표수(파생 #1~3 분모) ✅CRM 확정 |
| FTG-B `FACT_TARGET_BIZ` | 조회년월×조직(ORG)×후원사업[×캠페인] | 연사업/추경(누계)목표(건) #152~155 ⚠️ERP 미수령·적재예약 |
| FSE `FACT_SERVICE_EVENT` | 발송일×회원×서비스×캠페인 | 발송/성공/실패, 서신/선물금 참여, +5일차 참여/중단 등 17 |
| FGA `FACT_GA_BEHAVIOR` | 일×ga_member_id(IDENTITY)×이벤트×세션소스×페이지 | 방문·활성/총사용자·세션·이벤트·조회·스크롤 7 |
| FAD `FACT_AD_PERFORMANCE` | 일×캠페인×광고소재/매체(AD_CREATIVE) | 광고비·노출·클릭·인입콜 4 |
| FEP `FACT_EVENT_PARTICIPATION` | 일×회원×행사(EVENT) | 모집·참여·불참·대기 인원/횟수, 정기후원금, 조회수(ADMIN) |
| FBD `FACT_BUDGET` | 조회년월×조직(ORG)×예산세세목[×캠페인] | 편성/집행예산·모금성비용·광고비 (ERP 미수령) |

> **목표 팩트 2분할(결정 9)**: 소스·grain이 다른 두 목표를 분리. FTG-D=CRM 회원개발목표(`TM_CM_MBER_DVLP_GOAL`, 확정), FTG-B=ERP 사업목표(미수령·적재예약). 둘 다 ORG·MONTH_KEY conformed이며 회원 grain 아님 → FMM과 직접 합산 금지(공통 차원 정렬만).
>
> ⚠️ **[결론7] ERP 예산원장 캠페인·매체 연결키 부재**: FTG-B의 ERP 예산원장에는 캠페인·매체(AD_CREATIVE)로 이어지는 연결키가 없다. 따라서 **캠페인별/매체별 ROI(예산 대비 성과)는 현재 산출 불가**이며, 조직(ORG)×월 grain의 목표 대비 실적 비교까지만 가능. `V_CAMPAIGN_ROI`·`V_CHANNEL_ROI`·`V_BUDGET_EFFICIENCY`는 광고비(FAD) 기반 효율이며 **ERP 예산 기준 ROI가 아님**을 명시(연결키 확보 전까지 캠페인 예산 ROI 미지원).
> ⚠️ **[결론4] FAD 인입콜 타입 불일치**: 재송출(RETRANSMIT)=TEXT vs 영상(DRTV)=NUMBER → SILVER에서 TRY_TO_NUMBER 캐스팅 후 FAD 적재. 전환콜(CONV_CALL_CNT)은 인입콜과 별개 measure.
> ⚠️ **[결론5] FAD/DIM_AD_CREATIVE 출처 플래그**: 대행사 3원천(DRTV/RETRANSMIT/DIGITAL)은 행 단위 출처 구분이 없으므로 SILVER→FAD 적재 시 `_SOURCE_SYSTEM`(광고유형) 컬럼을 명시 부여.

---

## 3.5-L GOLD 레거시 호환 View (PoC 35개) — 병존

> **위치**: `GN_DW.GOLD` 스키마 내 VIEW.
> **역할**: PoC 시절 구축한 분석 View. **Semantic View·Agent·Streamlit이 현재 참조 중**이므로 폐기 불가, star schema와 **병존**.
> **소스**: SILVER `EXT_*`(외부 13개) + SILVER `CRM_*`계열(DIM/FACT 정형화 전 버전).
> **향후**: star schema 물리 테이블이 운영 안정화되면 레거시 View를 star schema 기반으로 점진 전환하거나, star schema 직접 참조하는 신규 SV로 대체.

```yaml
legacy_gold_views:
  총계: 35   # A(11) + B(9) + C(15)

  A_agent_consumed:   # Semantic View가 소비 (11)
    - V_PAYMENT_ANALYSIS
    - V_MEMBER_DEV_DETAIL
    - V_DISCONTINUATION_REPORT
    - V_RETENTION_BY_PERIOD
    - V_DISCONTINUED_DETAIL
    - V_DISCONTINUED_PAYMENT_ANALYSIS
    - V_TEMP_MEMBER_CONVERSION
    - V_ALIMTALK_INCREASE_CROSS
    - V_SEND_CONVERSION_ANALYSIS
    - V_APP_ENGAGEMENT
    - V_MEMBER_JOURNEY

  B_wrapping:   # BRONZE 직접참조 제거용 SILVER 기반 정형화 View (9)
    - V_SMS_ALIMTALK_SEND
    - V_DIGITAL_AD_DETAIL
    - V_AD_GA_AUDIENCE
    - V_AD_META
    - V_GA_VISITS_TOTAL
    - V_GA_VISITS_PC
    - V_GA_VISITS_MOBILE
    - V_GA_VISITS_APP
    - V_GA_FEEDBACK_PAGE

  C_streamlit_forecast:   # Agent 미사용, Streamlit 소비 (활성 11 + forecast 4 제외)
    media_efficiency: [V_MEDIA_EFFICIENCY_DETAIL, V_CHANNEL_ROI, V_BUDGET_EFFICIENCY, V_DRTV_SPOT_EFFICIENCY, V_TIME_SLOT_EFFICIENCY]
    campaign_perf: [V_CAMPAIGN_ROI, V_CAMPAIGN_LTV, V_MEMBER_DEV_STATUS, V_LOYAL_MEMBER_ANALYSIS, V_CONVERTED_MEMBER_PROFILE]
    messaging: [V_ALIMTALK_EFFECTIVENESS]
    forecast_ml_DEPRECATED: [V_CAMPAIGN_DEV_FORECAST, V_CAMPAIGN_FEE_FORECAST, V_FORECAST_DEV_COUNT, V_FORECAST_AVG_PAYMENT]  # ⛔ forecast 제외(2026-07-10) — 비활성

  D_forecast_tables_DEPRECATED:   # ⛔ forecast 제외 결정(2026-07-10) — 예측 물리 테이블 5종 비활성(생성/전환 안 함)
    - FORECAST_TRAINING_DATA
    - TRAIN_AVG_PAYMENT
    - TRAIN_DEV_COUNT
    - FORECAST_AVG_PAYMENT_RESULT
    - FORECAST_DEV_COUNT_RESULT

  전환_계획: |
    star schema 안정화 후 단계적 전환:
    1) A(11): star schema FACT/DIM 기반 신규 SV 생성 → 기존 SV tool_resource 교체
    2) B(9): EXT_* → raw 입고 시 star schema FGA/FAD가 직접 대체
    3) C(15): Streamlit에서 star schema 직접 참조로 쿼리 전환
```

---

## 3.6 Semantic View (semantic_views)

> `GN_DW.SERVING`에 생성(P7). 현재 base 객체는 **레거시 GOLD View(3.5-L)**. star schema 전환 후 base를 star schema 테이블로 교체 예정.
>
> ⚠️ **[SV/Agent 세대 정리]** 본 문서(3.6/3.7)의 **레거시 SV 7개 / Agent 1개**는 *현재(PoC 이관) 운영 상태*이다.
> `05_ARCHITECTURE.md`·`05_SV-Agent_ai/`(정본)에 기술된 **star schema 기반 SV 4개(SV_MEMBER/SERVICE/AD/GA) / Agent 3개**는 *목표(전환 후) 상태*이다.
> 두 수치는 상충이 아니라 **레거시(현재) → star schema(목표) 전환 로드맵의 양 끝단**이다. star schema 물리 테이블 안정화 시 아래 7 SV를 4 SV로 재편하고 Agent를 3개로 분리한다. SV/Agent 최종 정본은 `05_SV-Agent_ai/`를 따른다.

```yaml
semantic_views:
  - { id: SV_PAYMENT_ANALYSIS, refs: [V_PAYMENT_ANALYSIS], desc: 납입 분석 }
  - { id: SV_MEMBER_LIFECYCLE, refs: [V_DISCONTINUED_DETAIL, V_DISCONTINUED_PAYMENT_ANALYSIS, V_TEMP_MEMBER_CONVERSION], desc: "회원 생애주기(중단/미납/일시→정기)" }
  - { id: SV_MEMBER_DEVELOPMENT, refs: [V_MEMBER_DEV_DETAIL, V_DISCONTINUATION_REPORT, V_RETENTION_BY_PERIOD], desc: 회원 개발/유지율 }
  - { id: SV_MARKETING_MESSAGING, refs: [V_SMS_ALIMTALK_SEND, V_ALIMTALK_INCREASE_CROSS, V_SEND_CONVERSION_ANALYSIS], desc: 마케팅 발송/전환 }
  - { id: SV_AD_PLATFORM, refs: [V_DIGITAL_AD_DETAIL, V_AD_GA_AUDIENCE, V_AD_META], desc: 광고 플랫폼 }
  - { id: SV_WEB_APP_ANALYTICS, refs: [V_APP_ENGAGEMENT, V_GA_VISITS_TOTAL, V_GA_VISITS_PC, V_GA_VISITS_MOBILE, V_GA_VISITS_APP, V_GA_FEEDBACK_PAGE], desc: 웹/앱 분석 }
  - { id: SV_MEMBER_JOURNEY, refs: [V_MEMBER_JOURNEY], desc: 회원 여정 }
redesign_notes:
  - "PoC에서 SV_MARKETING_MESSAGING·SV_AD_PLATFORM·SV_WEB_APP_ANALYTICS가 RAW(BRONZE) 직접참조 -> 모두 SILVER 기반 GOLD View 경유로 변경"
  - "VQR 경로 치환 필수: ai_verified_queries의 GN_DW_POC.RAW.* / GN_DW_POC.ANALYTICS.* -> GN_DW.GOLD.* (R2)"
  - "star schema 전환 시: refs를 GOLD View → GOLD 물리 테이블(DIM/FACT)로 교체. 파생지표는 SV metric으로 이동(03_top-down_gold/GOLD_파생지표 매핑.md 참조)"
```

---

## 3.7 Agent (agent)

```yaml
agent:
  id: GN_DW.SERVING.GN_DW_AGENT
  orchestration_model: auto
  budget: { time_sec: 60, tokens: 32000 }
  tools: "Cortex Analyst text-to-SQL 7개 + data_to_chart"
  sample_questions: 6
  access_roles: [GN_DW_ANALYST, GN_DW_VIEWER, GN_DW_SERVICE]
  tool_resources:
    - { tool: payment_analyst, sv: SV_PAYMENT_ANALYSIS, routes: "납입회비, 미납, 청구금액" }
    - { tool: lifecycle_analyst, sv: SV_MEMBER_LIFECYCLE, routes: "중단회원, 유지기간, 일시→정기 전환" }
    - { tool: member_dev_analyst, sv: SV_MEMBER_DEVELOPMENT, routes: "회원개발, 개발건수, ROI, 유지율" }
    - { tool: messaging_analyst, sv: SV_MARKETING_MESSAGING, routes: "알림톡, 문자발송, 발송전환" }
    - { tool: ad_platform_analyst, sv: SV_AD_PLATFORM, routes: "디지털광고, 매체, 구글/메타, CTR/CPC" }
    - { tool: web_app_analyst, sv: SV_WEB_APP_ANALYTICS, routes: "웹/앱 방문" }
    - { tool: journey_analyst, sv: SV_MEMBER_JOURNEY, routes: "회원별 후원 전후 통합 여정" }
  migration_note: "PoC 구버전 GN_DW_POC_AGENT(4 SV)는 폐기. GN_DW_AGENT(7 SV)만 이관"
```

---

## 3.8 권한 부여 (grants)

```yaml
schema_grants:
  GN_DW_ADMIN:    { BRONZE: ALL, SILVER: ALL, GOLD: ALL, SERVING: ALL }
  GN_DW_ENGINEER: { BRONZE: SELECT, SILVER: "ALL (CREATE TABLE/PROCEDURE/TASK 포함)", GOLD: "USAGE, SELECT, CREATE VIEW", SERVING: USAGE }
  GN_DW_LOADER:   { BRONZE: "INSERT, UPDATE", SILVER: "-", GOLD: "-", SERVING: "-" }
  GN_DW_ANALYST:  { BRONZE: "-", SILVER: SELECT, GOLD: "USAGE, SELECT", SERVING: "USAGE + USAGE ON SV/AGENT/STREAMLIT" }
  GN_DW_VIEWER:   { BRONZE: "-", SILVER: "-", GOLD: "USAGE, SELECT(SV 참조 View)", SERVING: "USAGE + USAGE ON SV/AGENT/STREAMLIT" }
  GN_DW_SERVICE:  { BRONZE: "-", SILVER: "-", GOLD: "USAGE, SELECT", SERVING: "USAGE + USAGE ON SV/AGENT/STREAMLIT" }
grant_notes:
  - "SV/Agent/Streamlit이 SERVING에 위치(P7) -> USAGE ON SV/AGENT/STREAMLIT은 SERVING에서 부여"
  - "Viewer GOLD SELECT 필요 이유: Snowflake Intelligence(CoWork) Agent의 text-to-SQL은 호출자(Viewer) 세션에서 base 객체(GN_DW.GOLD.V_*)에 직접 실행. GOLD owner's rights라 SILVER/BRONZE 권한 불필요"
  - "Streamlit은 owner's rights 실행 -> Viewer는 USAGE ON STREAMLIT만으로 리포트 조회"
  - "star schema 물리 테이블(DIM/FACT)도 GOLD 스키마 내 → 기존 GOLD SELECT 권한으로 접근 가능"
ops_security_grants:
  OPS: "GN_DW_ADMIN ALL; GN_DW_ENGINEER·GN_DW_ANALYST SELECT(비용 가시성)"
  SECURITY: "GN_DW_ADMIN만 관리. (레거시 07 SQL의 GN_DW_MASKING_ADMIN 역할은 02에 미정의 -> 신규 작성 시 정리, R5)"
future_grants: "향후 생성 테이블/뷰에 자동 권한 부여 설정"
```

---

## 3.9 Streamlit 대시보드 (streamlit_apps)

> PoC 6종을 `GN_DW.SERVING`에 배포(P7). 현재 `GN_DW.GOLD.V_*`(레거시 View) 참조, owner's rights 실행.

```yaml
streamlit_apps:
  - { id: 1, name: "캠페인별 LTV/CAC 분석", refs: [V_CAMPAIGN_LTV, V_CAMPAIGN_ROI] }
  - { id: 2, name: "주요캠페인별 미납현황", refs: [V_PAYMENT_ANALYSIS] }
  - { id: 3, name: "개발회원 후원여정 현황", refs: [V_MEMBER_JOURNEY, V_MEMBER_DEV_DETAIL] }
  - { id: 4, name: "주간중단회원 보고", refs: [V_DISCONTINUED_DETAIL] }
  - { id: 5, name: "주요캠페인별 중단현황", refs: [V_DISCONTINUATION_REPORT, V_DISCONTINUED_DETAIL] }
  - { id: 6, name: "(테스트 앱)", refs: [], note: "운영 이관 시 정리" }
query_warehouse_change: "PoC COMPUTE_WH/POC_WH -> GN_DW_ANALYTICS_WH"
```

---

> **이전 단계:** `02_DB_BRONZE_SILVER.md` · **다음 단계:** `04_운영.md` (태스크 → 테스트 → 보안 → 모니터링)
> **GOLD 상세 설계:** `../03_top-down_gold/` (정본) — 차원·팩트·DDL·의존·파생지표·제약
