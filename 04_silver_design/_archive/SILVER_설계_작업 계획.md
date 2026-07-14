# SILVER 설계 작업계획 (GN_DW)

> 굿네이버스 GN_DW **SILVER 레이어 설계 작업계획서(정본)**.
> **설계 2축(top-down)**: ① GOLD가 요구하는 SILVER(`03_top-down_gold/GOLD_SILVER 의존.md`, GOLD 18테이블 역산) · ② BRONZE 구성 가능 SILVER(`컬럼정의서 20260622.csv`, CRM 40테이블/882컬럼 — 권위 정의).
> **입력**: `GOLD_SILVER 의존.md`(역산 정본) · `GOLD_ddl 초안.sql`(GOLD 18=12 DIM+6 FACT) · `컬럼정의서 20260622.csv`(CRM 컬럼 권위 정의, 882컬럼) · `지표용어통합 20260623.csv`(지표 비즈니스 용어).
> **제외**: `02_GN_DW_building/02_DB_BRONZE_SILVER.md`의 PoC SILVER 23·PoC GOLD View 35는 본 설계 입력 아님.
> **위치**: `GN_DW.SILVER` 단일 스키마, 테이블명 소스 접두사(`CRM_*`·`GA4_*`·`ERP_*`·`AGENCY_*`·`GADS_*`·`ADMIN_*`)로 구분.
>
> **🆕 2026-06-24 GOLD 갱신 반영**: 회의 정의서 4종(`99_provided_definition/`)으로 GOLD가 **원천 6개로 확장**(+GADS·ADMIN). 변경 정본 = `03_top-down_gold/GOLD_정의서_업데이트 20260624.md`. 본 작업계획에 반영된 항목은 각 절의 `🆕` 표기 참조. **전 신규 항목은 미수령 → 입고 후 S-6**(정의 레벨 선반영, 골격 불변). ⚠️ **GADS·ADMIN은 AGENCY 또는 CRM으로 통합 예정(목적지 미정, delta §5)** → 독립 `GADS_*`/`ADMIN_*` 접두사·수량(3개)은 **잠정**, 통합 결정 시 변경(고정 단정 금지).

---

## 한눈에 (TL;DR)

- **목표**: BRONZE→SILVER 정제 레이어를 GOLD star schema 요구 기준 top-down 설계.
- **범위**: SILVER **28테이블** = CRM **15**(✅즉시) + GA4 5·ERP 2·AGENCY 3·**GADS 1·ADMIN 2**(⚠️입고 후 S-6, GADS·ADMIN 3개 잠정).
- **현재**: S-1(CRM 엔티티 설계서) 진행 중. 엔티티별 상세는 `S1_CRM_entity_design/`.
- **해소된 설계 결정(S-1)**: R7(약정→결연 분리, CRM 14→15) · R9(납입+청구 UNION ALL).
- **잔존 차단**: R2(발송 키 관계) · R10(후원사업 키 매핑 — ⑮ 결연 한정) · R5(GA4/ERP/AGENCY 입고). ✅ 정의서(2026-06-22)로 D2·D5·R1·R11·OPEN-51 해소. ✅ **R4 해소**: `memnum` = `member id` = `회원번호`(문자, URL 파라미터 용어) — 별도 키 아님(§2-1·R4 참조).
- **문서 지도**: §0 원칙 · §1 테이블 목록 · §2 BRONZE→SILVER 트리 · §2-1 개념↔물리 매핑 · §3 결정 D1~D11 · §3-1 리스크 R1~R11 · §3-3 BRONZE 컨트랙트 · §4 단계 S-1~S-7.

---

## 약어 · 표기 범례

> 본 문서 자기완결성용. 권위 정의는 `03_top-down_gold/GOLD_SILVER 의존.md`·`GOLD_ddl 초안.sql`.

**GOLD FACT 약어 (6)**
- `FMM` — 회원관리·모금 핵심 FACT(개발/중단/증액/감액/납입/청구/상태변경/월말 시점지표)
- `FTG-D` — `FACT_TARGET_DEV`, 개발목표 FACT
- `FTG-B` — 사업목표(예산) FACT (ERP 소스)
- `FSE` — 발송·참여 FACT(이메일/문자/우편/이벤트/캠페인)
- `FGA` — GA4 웹·앱 행동 FACT(세션·이벤트)
- `FAD` — 광고 성과·비용 FACT(매체×일)

**표기**
- `공N` / `신N` — `GOLD_SILVER 의존.md` 지표(metric) 번호(공=공통/기존, 신=신규).
- `#N` — `GOLD_SILVER 의존.md`/`GOLD_ddl 초안.sql`의 컬럼·행 번호.
- `MM###`·`CM###`·`PM###`·`MS###` — CRM 공통코드 그룹(코드→라벨, `CRM_CODE_MASTER`).
- `▶BRONZE 컨트랙트` — 원천 적재 시 요청할 raw 데이터 계약(§3-3).

---

## 0. 설계 원칙

1. **단일 SILVER 스키마 + 소스 접두사** — `GN_DW.SILVER.{소스}_{엔티티}`(예: `CRM_MEMBER_MASTER`). cross-schema JOIN 불필요·GRANT 단순·BRONZE와 동일 패턴.
2. **SILVER 소스 = GOLD 요구 6소스** — `CRM_*`(15, BRONZE CRM 40으로 즉시) · `GA4_*` · `ERP_*` · `AGENCY_*` · **`GADS_*` · `ADMIN_*`**(raw 입고 후). 소스 간 통합은 SILVER가 아닌 **GOLD FACT에서만**(GOLD_SILVER 의존 §3) — 광고비/노출/클릭의 AGENCY∪GADS 통합도 GOLD FAD에서 `_SOURCE_SYSTEM`으로(🆕 2026-06-24).
3. **GOLD 미요구 BRONZE는 SILVER 미생성** — 외부 집계 테이블(`FACT_GA_VISITS_*`·`FACT_AD_*` 등)은 일/월 집계라 raw grain FACT(FGA·FAD)를 못 채움(grain 위배) → 제외(§1-5).
4. **행(row) granularity 유지, 집계는 GOLD** — "통합"은 UNION ALL(행 추가)·속성 JOIN(행 불변)만 허용. 행 축소(GROUP BY)는 GOLD. 정기+일시 회원 = UNION ALL(번호 체계 상이, 유형 컬럼 구분).
5. **정제 범위** — 타입 캐스팅(문자→날짜/숫자) · NULL 표준화 · 코드→라벨 병행 보존 · PK 기준 중복 제거 · 동일 소스 내 JOIN.
6. **이력 보존(SCD2)** — 회원상태 변경이력을 SILVER에 행 보존(`CRM_MEMBER_STATUS_HIST`); GOLD DIM_MEMBER의 EFFECTIVE_FROM/TO는 여기서 파생. ⚠️ **실제 SCD2 가능 속성은 STATUS만**(이력 소스가 상태만 보유) — GENDER·REGION·신규기존은 마스터 현재값=SCD1. → D10·R6.
7. **BRONZE 기반 선행 설계** — CRM(40/882) 즉시 가능; GA4 raw·ERP·AGENCY 입고 후.
8. **GOLD 물리 형태** — GOLD는 `GOLD_ddl 초안.sql`의 **물리 테이블**(star schema)로 확정. SILVER→GOLD 적재(프로시저)는 별도 트랙.
9. **메달리온 단방향 참조(P2)** — `SERVING→GOLD→SILVER→BRONZE`, 각 계층은 **바로 아래만** 참조(05_ARCHITECTURE P1·P2·P7). **GOLD는 BRONZE 직참조 금지** — star schema 물리 테이블·레거시 호환 View 35 **모두 SILVER만** 참조하고, 변환 불필요한 외부 집계본도 `SILVER EXT_*`(1:1 pass-through) 경유. SERVING(SV·Agent·Streamlit)은 GOLD만(P7). 잔존 직참조는 R8로 검증.
10. **표준 감사/메타 컬럼**(전 테이블 공통, GOLD 적재 시 제외, S-2/S-4 반영)
    - `_SOURCE_SYSTEM` — 원천 시스템(CRM/GA4/ERP/AGENCY/**GADS/ADMIN**); GOLD FAD·FSE 통합키(🆕 2026-06-24 GADS·ADMIN 추가).
    - `_SOURCE_TABLE` — BRONZE 원천 테이블명(다중 원천 UNION/JOIN 시 행별 출처).
    - `_LOADED_AT` TIMESTAMP_NTZ — 정제 적재 시각(DEFAULT CURRENT_TIMESTAMP).
    - `_BATCH_ID` — 정제 배치 식별(멱등 재적재 추적).
    - SCD2 엔티티(`CRM_MEMBER_STATUS_HIST`)는 `EFFECTIVE_FROM/TO`·`IS_CURRENT` 추가(원칙6).
11. **정제 컨벤션** — NULL 표준화(빈문자·`'NULL'`·`'-'`·공백→NULL) · 날짜(`YYYYMMDD`/`YYYY-MM-DD`→DATE/TIMESTAMP, 무효값→NULL) · 숫자(금액 NUMBER 원단위 보존, /10000 환산은 GOLD, 콤마·통화기호 제거) · 문자(TRIM·전각→반각·UTF-8) · 코드+라벨(`*_CD`+`*_NM`) 병행(§6-4) · UPPER_SNAKE_CASE.

---

## 1. SILVER 테이블 전수 목록

> GOLD 18테이블(12 DIM+6 FACT)이 요구하는 SILVER 소스·엔티티(GOLD_SILVER 의존 §1·§2) 기준.

### 1-1. CRM 계열 (`CRM_*`) — ✅ 즉시 설계 가능

> 원천: `컬럼정의서 20260622.csv`(40테이블/882컬럼 전수, 권위 정의). GOLD 수요: **DIM 8 관여**(MEMBER·CAMPAIGN·SPONSORSHIP·ORG·SERVICE·PAYMENT·REASON **7개 완전** + `DIM_MEMBER_IDENTITY` **부분**, CRM측 MEMBER_NO만; GA측·MEMNUM은 입고/R4 후) + FACT 3(FMM·FTG-D·FSE). (§6·§7)

| # | SILVER 테이블 | BRONZE 원천 | GOLD 수요처 | grain |
|---|---|---|---|---|
| 1 | `CRM_MEMBER_MASTER` | TM_MM_FDRM_MBER_INFO(31) · TM_MM_ONCE_MBER_INFO(22) · TM_MM_FDRM_MBER_IRSD(17) | DIM_MEMBER, DIM_MEMBER_IDENTITY | 1행/회원(정기+일시 UNION ALL, 유형 컬럼 구분) ⚠️R3 |
| 2 | `CRM_MEMBER_STATUS_HIST` | TH_MM_FDRM_MBER_STNG_DTLS(8) · TM_MM_FDRM_MBER_SPNSR_DSCNTC(9) · TM_MM_FDRM_MBER_RE_SPNSR(7) | DIM_MEMBER(SCD2: STATUS), FMM | 1행/상태변경 이벤트 (D2 ✅해소: BF/CHN_STAT_CD) |
| 3 | `CRM_SPONSORSHIP_PLEDGE` | TM_MM_FDRM_MBER_DVLP_AMT(23) · TM_MM_FDRM_MBER_SPNSR_BSNS(9) | FMM(개발·중단·감액·증액), DIM_MEMBER | 1행/개발실적건 (DVLP_AMT 스파인 + SPNSR_BSNS 1:1) ★R7 |
| 4 | `CRM_PAYMENT_BILLING` | TM_PM_MBRFEE_ACMSLT(57) · TM_PM_DNTN_DTLS(30) | FMM(납입#69·청구#71), DIM_PAYMENT | 1행/과금건(회비+기부금 UNION ALL, PAYMENT_TYPE 구분; 상세 →D3·R9) ★R9 |
| 5 | `CRM_PAYMENT_METHOD` | TM_PM_SETLE_INFO(51) · TH_PM_SETLE_INFO_HIST(49) | DIM_PAYMENT | 1행/결제수단(HIST는 SCD1이라 적재 보류) |
| 6 | `CRM_CAMPAIGN_MASTER` | TM_CM_CMPGN_MNG(34) · TM_CM_BRND_MNG(11) · TM_CM_MKTNG_CMPGN_MNG(10) | DIM_CAMPAIGN | 1행/캠페인 |
| 7 | `CRM_SPONSORSHIP_MASTER` | TM_CM_SPNSR_BSNS_INFO(15) | DIM_SPONSORSHIP | 1행/후원사업 (D5 ✅해소: SPNSR_BSNS_ID/NM/ABRV) |
| 8 | `CRM_ORG_MASTER` | TM_CM_DEPT_INFO(14) | DIM_ORG, FTG-D | 1행/조직노드 |
| 9 | `CRM_DEV_TARGET` | TM_CM_MBER_DVLP_GOAL(11) | FACT_TARGET_DEV (FTG-D) | 1행/연·월·개발구분·부서 |
| 10 | `CRM_SEND_REQUEST` | SND_REQ_MST(54) · TM_MS_EMAIL_SNDNG(16) · TM_MS_MSG_AT_SNDNG(21) · TM_MS_PSTMTR_SNDNG(16) · TM_MS_CRMN(35) · TM_MS_EVENT(13) | FSE(발송마스터), DIM_SERVICE | 1행/발송요청건(마스터 grain) ⚠️R2 |
| 11 | `CRM_SEND_MEMBER` | SND_MEMBER_LIST(76) · TD_MS_EMAIL_SNDNG_DTLS(12) · TD_MS_MSG_AT_SNDNG_DTLS(15) · TD_MS_PSTMTR_SNDNG_DTL(14) | FSE(회원별 발송) | 1행/발송건×회원(상세 grain) |
| 12 | `CRM_SEND_RESULT` | TD_MS_EMAIL_LQY_SNDNG(26) · TD_MS_MSG_AT_LQY_SNDNG(20) · TD_MS_PSTMTR_LQY_SNDNG(11) | FSE(발송 성과 집계) | 1행/발송건×채널(성과 grain) |
| 13 | `CRM_PARTICIPATION_HIST` | TM_RM_RELATNSP_LETTER_INFO(16) · TM_RM_RELATNSP_GFTMNEY_INFO(20) · TD_MS_EVENT_PRTCPNT_DTL(17) · TD_MS_CRMN_PRTCPNT(21) | FSE(서신/선물금/이벤트/캠페인) | 1행/참여건 |
| 14 | `CRM_CODE_MASTER` | TC_CMMN_CD(12) · TC_CMMN_DTL_CD(17) | DIM_REASON, 전체(코드→라벨) | 1행/코드그룹×코드값 |
| 15 | `CRM_SPONSORSHIP_RELATION` | TM_RM_RELATNSP_MSTR_INFO(13) | DIM_SPONSORSHIP, 결연 lifecycle | 1행/결연(아동)건 ★R7 PLEDGE에서 분리 |

> **△ 미완**: ~~#2 STNG_DTLS(D2)·#7 SPONSORSHIP_MASTER(D5)~~ → **✅ 2026-06-22 컬럼정의서로 전부 해소**(CRM 40테이블/882컬럼 확정). 잔여는 값/관계 실측(R2·R10·OPEN-22 등).
> **테이블 분할/통합 근거**: `CRM_SEND_*` 3분할(원천 grain 상이, wide table 방지) = D4. `CRM_PAYMENT_BILLING` 통합(회비+기부금) = D3·R9.
> **착수 전 확인(상세는 §3-1)**: R2(#10~12 발송 키 이원화) · R3(#1 회원 UNION ALL 정합) · R7(#3 약정 grain·#15 결연 분리) · R9(#4 납입+청구 UNION ALL).

### 1-2. GA4 Raw 계열 (`GA4_*`) — ⚠️ 데이터 입고 후 설계

> BRONZE 원천 미수령(GA4 BigQuery export/내부 추출 형식 미확정). GOLD 수요: DIM 2(GA_SOURCE·GA_EVENT) + DIM_MEMBER_IDENTITY(GA_MEMBER_ID) + FACT 2(FGA raw·FAD의 GA 광고비/전환).

| # | SILVER 테이블 (예정) | 예상 내용 | GOLD 수요처 |
|---|---|---|---|
| 16 | `GA4_SESSION` | 세션 단위(session_id, member_id, start/end, duration) | FGA |
| 17 | `GA4_EVENT` | 이벤트 단위(event_name, category/label/action, params) | FGA, DIM_GA_EVENT |
| 18 | `GA4_USER` | 사용자(member_id, first_visit_date, **타겟그룹/잠재고객** 🆕) | DIM_MEMBER_IDENTITY(GA_MEMBER_ID #112), DIM_AD_CREATIVE(타겟그룹) |
| 19 | `GA4_TRAFFIC_SOURCE` | utm 파라미터(source/medium/content/keyword) 정제 | DIM_GA_SOURCE |
| 20 | `GA4_AD` | 광고 노출/클릭/광고비 + **전환수(명·건)** 🆕(원천 AGENCY∪GA4) | FAD(GA 광고비 #6, 전환수→공10 CVR) |

> ⚠️ 입고 후 확정: URL 파싱(결연아동코드 #122)·engagement_time(공98)·bounce(공108)·전환수(공10) 존재 여부 → ▶BRONZE 컨트랙트(§3-3).
> 🆕 **2026-06-24**: `GA 전환수`는 **명/건 2종**(마케팅§3, 원천표기 대행사/GA) → GOLD FAD `GA_CONVERSION_PERSON`·`GA_CONVERSION_CASE` 예약. `잠재고객(타겟그룹)`은 원천표기 **GA** → GA4_USER에서 정제(GOLD DIM_AD_CREATIVE.TARGET_GROUP).

### 1-3. ERP 계열 (`ERP_*`) — ⚠️ 데이터 입고 후 설계

> GOLD 수요: FACT 2(FTG-B 사업목표 · FAD reserved 모금성비용·예산).

| # | SILVER 테이블 (예정) | 예상 내용 | GOLD 수요처 |
|---|---|---|---|
| 21 | `ERP_BIZ_TARGET` | 사업목표(연사업·추경·누계, 후원사업×조직 grain) | FTG-B(#152~155) |
| 22 | `ERP_COST` | 모금성비용 세세목 + **편성예산(월/연/누계)·집행예산(ERP 마감값=확정)** 🆕 | FAD(reserved: 모금성비용·EXEC_BUDGET_ERP·PLANNED_BUDGET) |

> ⚠️ 입고 후 확정: 원천 형식(DB? 엑셀 사업계획시트?)·grain. 모금성비용 세세목·캠페인별 작성 기준 합의 = ▶BRONZE 컨트랙트(신10·신11).
> 🆕 **2026-06-24**: 집행예산은 **ERP 마감값(확정)** 과 **대행사 추정치**(§1-4) 2종 → GOLD FAD `EXEC_BUDGET_ERP`/`EXEC_BUDGET_EST` 분리. 편성/집행예산 grain(부서·세세목·월)이 FAD grain과 달라 적재 시 부서 grain 매핑 별도 검토(OPEN).

### 1-4. AGENCY 계열 (`AGENCY_*`) — ⚠️ 데이터 입고 후 설계

> GOLD 수요: DIM 1(AD_CREATIVE) + FACT 1(FAD 노출/클릭/인입콜·편성비).

| # | SILVER 테이블 (예정) | 예상 내용 | GOLD 수요처 |
|---|---|---|---|
| 23 | `AGENCY_AD_CREATIVE` | 광고소재마스터(매체·플랫폼·기기·소재·CM위치·초수) + **시간속성(요일/주차/시간대/광고시작시간/RT유형)** 🆕 | DIM_AD_CREATIVE, FAD degenerate |
| 24 | `AGENCY_PERFORMANCE` | 매체별 노출/클릭/인입콜 + **GA전환수(명·건)·집행예산 추정치** 🆕 | FAD(#23·24·25, 전환수, EXEC_BUDGET_EST) |
| 25 | `AGENCY_BUDGET` | 편성비 | FAD(reserved, 신9 개발단가) |

> ⚠️ 입고 후 확정: 대행사 리포트 형식(API? CSV?). 편성비 raw = ▶BRONZE 컨트랙트.
> 🆕 **2026-06-24**: 광고 **송출일(BROADCAST_DATE)≠실적일(PERF_DATE)** 가능(DRTV 심야/주말/휴일) → 2일자 분리 정제 검토. GA전환수 명/건은 AGENCY·GA4 복수원천(§1-2와 동일 measure, GOLD에서 `_SOURCE_SYSTEM` 통합).

### 1-6. GADS 계열 (`GADS_*`) — 🆕 신규원천(2026-06-24) · ⚠️ 데이터 입고 후 설계

> GOLD 수요: FACT 1(FAD 광고비·노출·클릭, AGENCY와 복수원천). 인덱스 §4 표준코드 `GADS`. **AGENCY와 별개 SILVER 소스**(통합은 GOLD FAD `_SOURCE_SYSTEM`에서, 원칙2).

| # | SILVER 테이블 (예정) | 예상 내용 | GOLD 수요처 |
|---|---|---|---|
| 26 | `GADS_AD_PERFORMANCE` | Google Ads 광고비·노출·클릭(일×캠페인 grain) | FAD(#6·23·24, `_SOURCE_SYSTEM='GADS'`) |

> ⚠️ 입고 후 확정: 원천 형식(Google Ads API/내부 추출)·AGENCY 리포트와 중복/정합. 단가/통화 단위.

### 1-7. ADMIN 계열 (`ADMIN_*`) — 🆕 신규원천(2026-06-24) · ⚠️ 데이터 입고 후 설계 (잠정 2개)

> GOLD 수요: FSE 보조(앱 푸시 발송/성공 = FSE 채널 `APP_PUSH`) + 참여 보조(이벤트 조회수). 원천 = 어드민 화면 수집(`어드민>모바일앱>푸시발송목록`, `어드민>이벤트목록`).

| # | SILVER 테이블 (예정) | 예상 내용 | GOLD 수요처 |
|---|---|---|---|
| 27 | `ADMIN_APP_PUSH` | 앱 푸시 발송건수·성공건수(회원§3-7) | FSE(`SEND_CHANNEL='APP_PUSH'`, `_SOURCE_SYSTEM='ADMIN'`) |
| 28 | `ADMIN_EVENT_STATS` | 이벤트목록 조회수(회원§3-6) | FSE/참여 보조 measure |

> ⚠️ 입고 후 확정: 어드민 추출 방식(수기/배치)·grain. 두 테이블 1~2개로 병합 가능(잠정). CRM(UMS) 발송과 채널 구분 필수.

### 1-5. SILVER 미포함 — BRONZE 외부 집계 테이블 (제외)

> 대상: `FACT_GA_VISITS_TOTAL/PC/MOBILE/APP`·`FACT_GA_FEEDBACK_PAGE`·`FACT_AD_GA_AUDIENCE`·`FACT_AD_META`·`FACT_AD_GOOGLE_DEMANDGEN`·`FACT_AD_GOOGLE_PMAX`·`FACT_DIGITAL_AD_DETAIL`·`FACT_DIGITAL_MONTHLY_DEV`·`FACT_DRTV_BROADCAST_EFF`·`FACT_DRTV_MONTHLY_DEV`·`FACT_RETRANSMIT_BROADCAST_CONV`·`FACT_RETRANSMIT_MONTHLY_DEV`.

- 이들은 **일/월 집계 리포트**다. GOLD FGA(세션·이벤트 raw grain)·FAD(매체×일 raw grain)는 집계본으로 못 채운다 — **참조하는 GOLD FACT 컬럼 0건**(원칙4 grain 위배). FGA/FAD는 raw GA4/AGENCY 입고(§1-2·§1-4)로만 채운다.
- 이들이 공급하던 **레거시 PoC GOLD View 35**는 본 top-down 설계 입력에서 제외(02-series에서 star schema와 병존). P2(원칙9)상 이 View도 BRONZE 직참조 금지 → `SILVER EXT_*` pass-through 경유. EXT_* 생성/폐기는 **02-series 레거시 트랙 소관**(본 25개 목록 비대상), 직참조 잔존은 **R8** 검증.

→ **결론**: 신규 GOLD star schema 소스에 외부 집계 미포함 + GOLD·SERVING 어느 계층도 BRONZE 직참조 없음.

---

## 2. BRONZE → SILVER 통합 트리 (CRM 41개)

```
BRONZE CRM (41 tables / 876 cols) → SILVER CRM_* (15 tables)

  ├── 회원계 (6 tables → 2 SILVER)
  │   ├─ TM_MM_FDRM_MBER_INFO(31)        ─┐
  │   ├─ TM_MM_ONCE_MBER_INFO(22)         ─┼→ CRM_MEMBER_MASTER (정기+일시 UNION ALL; IRSD 증감액은 grain·컬럼 미확정 → S-1 보류)
  │   ├─ TM_MM_FDRM_MBER_IRSD(17)        ─┘
  │   ├─ TH_MM_FDRM_MBER_STNG_DTLS(8)    ─┐
  │   ├─ TM_MM_FDRM_MBER_SPNSR_DSCNTC(9) ─┼→ CRM_MEMBER_STATUS_HIST
  │   └─ TM_MM_FDRM_MBER_RE_SPNSR(7)     ─┘   (상태변경+중단+재후원 이력)
  │
  ├── 후원·약정계 (3 tables → 2 SILVER)
  │   ├─ TM_MM_FDRM_MBER_DVLP_AMT(23)    ─┐
  │   ├─ TM_MM_FDRM_MBER_SPNSR_BSNS(9)   ─┴→ CRM_SPONSORSHIP_PLEDGE (개발실적 스파인+사업매핑, FMM)
  │   └─ TM_RM_RELATNSP_MSTR_INFO(13)     ─→ CRM_SPONSORSHIP_RELATION (결연/아동, DIM_SPONSORSHIP) ★R7 분리
  │
  ├── 납입·결제계 (4 tables → 2 SILVER)
  │   ├─ TM_PM_MBRFEE_ACMSLT(57, PAY_*+RQEST_*) ─┐
  │   ├─ TM_PM_DNTN_DTLS(30, PAY_*만)    ─────────┴→ CRM_PAYMENT_BILLING (회비+기부금 UNION ALL; 회비행 납입+청구 동일행, 기부금행 청구 NULL) ★R9
  │   ├─ TM_PM_SETLE_INFO(51)             ─┐
  │   └─ TH_PM_SETLE_INFO_HIST(49)        ─┴→ CRM_PAYMENT_METHOD (결제수단+변경이력)
  │
  ├── 마스터계 (6 tables → 4 SILVER)
  │   ├─ TM_CM_CMPGN_MNG(34)              ─┐
  │   ├─ TM_CM_BRND_MNG(11)               ─┤
  │   ├─ TM_CM_MKTNG_CMPGN_MNG(10)        ─┴→ CRM_CAMPAIGN_MASTER
  │   ├─ TM_CM_SPNSR_BSNS_INFO(15)       ─→ CRM_SPONSORSHIP_MASTER
  │   ├─ TM_CM_DEPT_INFO(14)              ─→ CRM_ORG_MASTER
  │   └─ TM_CM_MBER_DVLP_GOAL(11)        ─→ CRM_DEV_TARGET
  │
  ├── 발송·참여계 (17 tables → 4 SILVER)
  │   ├─ SND_REQ_MST(54)                  ─┐
  │   ├─ TM_MS_EMAIL_SNDNG(16)            ─┤
  │   ├─ TM_MS_MSG_AT_SNDNG(21)           ─┼→ CRM_SEND_REQUEST (발송요청 마스터) ⚠️키 이원화 R2
  │   ├─ TM_MS_PSTMTR_SNDNG(16)           ─┤
  │   ├─ TM_MS_CRMN(35)                   ─┤
  │   ├─ TM_MS_EVENT(13)                  ─┘
  │   ├─ SND_MEMBER_LIST(76)              ─┐
  │   ├─ TD_MS_EMAIL_SNDNG_DTLS(12)       ─┼→ CRM_SEND_MEMBER (발송×회원 상세)
  │   ├─ TD_MS_MSG_AT_SNDNG_DTLS(15)      ─┤
  │   ├─ TD_MS_PSTMTR_SNDNG_DTL(14)       ─┘
  │   ├─ TD_MS_EMAIL_LQY_SNDNG(26)        ─┐
  │   ├─ TD_MS_MSG_AT_LQY_SNDNG(20)       ─┼→ CRM_SEND_RESULT (발송×채널 성과)
  │   └─ TD_MS_PSTMTR_LQY_SNDNG(11)      ─┘
  │   ├─ TM_RM_RELATNSP_LETTER_INFO(16)   ─┐
  │   ├─ TM_RM_RELATNSP_GFTMNEY_INFO(20)  ─┼→ CRM_PARTICIPATION_HIST
  │   ├─ TD_MS_EVENT_PRTCPNT_DTL(17)      ─┤
  │   └─ TD_MS_CRMN_PRTCPNT(21)           ─┘
  │
  ├── 기타 결연 (3 tables → 미포함)
  │   ├─ TM_RM_BPLC_MNG(20)              ─→ (미포함, 현재 GOLD 미참조)
  │   ├─ TM_RM_CHILD_MSTR_INFO(15)       ─→ (미포함, 향후 DIM_CHILD 확장 시 추가)
  │   └─ TM_RM_RELATNSP_CHG_INFO(9)      ─→ (미포함, 결연교체 — 현재 미참조)
  │
  └── 코드계 (2 tables → 1 SILVER)
      ├─ TC_CMMN_CD(12)                   ─┐
      └─ TC_CMMN_DTL_CD(17)               ─┴→ CRM_CODE_MASTER

  합계: 회원 2 + 약정 2(개발실적+결연) + 납입결제 2 + 마스터 4 + 발송참여 4 + 코드 1 = 15 SILVER
        (사용 BRONZE 38개 + 미포함 3개 = 41개)
```

**SILVER 미포함 BRONZE CRM 테이블 (3개)**: `TM_RM_BPLC_MNG`(사업장) · `TM_RM_CHILD_MSTR_INFO`(아동마스터, 향후 결연 분석 확장 시) · `TM_RM_RELATNSP_CHG_INFO`(결연교체) — 모두 현재 GOLD 미참조.

---

## 2-1. GOLD_SILVER 의존 개념명 ↔ 신규 SILVER 물리명 매핑

> `GOLD_SILVER 의존.md`는 SILVER를 **개념명**(예: `SILVER_CRM.납입이력`)으로, 본 문서는 **물리명**(예: `CRM_PAYMENT_BILLING`)으로 표기. S-5(GOLD 역산 검증) 시 아래 매핑으로 대조.

| GOLD_SILVER 의존 개념명 | 신규 SILVER 물리명 | 비고 |
|---|---|---|
| `SILVER_CRM.회원마스터` | `CRM_MEMBER_MASTER` | |
| `SILVER_CRM.회원상태이력` | `CRM_MEMBER_STATUS_HIST` | SCD2 가능 속성 = STATUS만 |
| `SILVER_CRM.후원약정` | `CRM_SPONSORSHIP_PLEDGE` | 개발/결연 grain 검증(R7) |
| `SILVER_CRM.납입이력` | `CRM_PAYMENT_BILLING`(PAY_* 컬럼) | 회비+기부금 UNION ALL(PAYMENT_TYPE 구분), 납입은 양쪽 보유 |
| `SILVER_CRM.청구이력` | `CRM_PAYMENT_BILLING`(RQEST_* 컬럼) | **회비행만 청구 보유, 기부금행 NULL**(R9) |
| `SILVER_CRM.납입방식` | `CRM_PAYMENT_METHOD` | |
| `SILVER_CRM.캠페인마스터` | `CRM_CAMPAIGN_MASTER` | |
| `SILVER_CRM.후원사업마스터` | `CRM_SPONSORSHIP_MASTER` | |
| `SILVER_CRM.조직마스터` | `CRM_ORG_MASTER` | ORG_BK=DEPT_ID (FTG-D/B·CAMPAIGN 조인키) |
| `SILVER_CRM.TM_CM_MBER_DVLP_GOAL` (회원개발목표) | `CRM_DEV_TARGET` | FTG-D ✅CRM 확정 |
| `SILVER_CRM.발송이력` | `CRM_SEND_REQUEST` + `CRM_SEND_MEMBER` + `CRM_SEND_RESULT` | grain별 3분할. GOLD FSE 적재 시 3테이블 JOIN |
| `SILVER_CRM.참여매칭이력` | `CRM_PARTICIPATION_HIST` | |
| `SILVER_CRM.사유코드` | `CRM_CODE_MASTER`(MM002·MM005·MM010 등) | |
| `SILVER_GA4.*` | `GA4_SESSION`·`GA4_EVENT`·`GA4_USER`·`GA4_TRAFFIC_SOURCE`·`GA4_AD` | 입고 후(§1-2). 🆕 타겟그룹·전환수(명/건) 포함 |
| `SILVER_ERP.*` | `ERP_BIZ_TARGET`·`ERP_COST` | 입고 후(§1-3). 🆕 편성/집행예산(확정)은 `ERP_COST` |
| `SILVER_AGENCY.*` | `AGENCY_AD_CREATIVE`·`AGENCY_PERFORMANCE`·`AGENCY_BUDGET` | 입고 후(§1-4). 🆕 집행예산 추정치·전환수 |
| `SILVER_GADS.*` 🆕 | `GADS_AD_PERFORMANCE` | 입고 후(§1-6). 광고비/노출/클릭, AGENCY와 복수원천 |
| `SILVER_ADMIN.*` 🆕 | `ADMIN_APP_PUSH`·`ADMIN_EVENT_STATS` | 입고 후(§1-7). 앱푸시·이벤트조회 |
| `SILVER_CRM.회원마스터(링크키 memnum)` | `CRM_MEMBER_MASTER`(회원번호) | ✅ `memnum` = `member id` = `회원번호`. R4 참조 |

> ✅ **memnum 해소(R4)**: `memnum`은 별도 키가 아니라 **`member id`와 동일한 `회원번호`(문자) 지표**이며, URL 등에서 쓰는 용어다(예: `?memnum=1831636`). 따라서 `DIM_MEMBER_IDENTITY.MEMNUM`(#111)의 원천은 **회원번호 컬럼**(=`member id` #112)을 그대로 보면 된다 — 별도 컬럼/별칭/매핑 테이블 불필요. (URL 파라미터명 `memnum` ↔ 컬럼 `회원번호` 매핑만 명시.) GA↔CRM 신원 매핑(공81·신32·신33) 차단 해제. (✅ `지표용어통합 20260623.csv`도 `memnum`·`member id`를 모두 `회원번호`로 정의 — 뒷받침.)

---

## 3. 핵심 설계 결정

| # | 결정 사항 | 현재 상태 | 근거 |
|---|---|---|---|
| D1 | 정기+일시 회원 통합 (CRM_MEMBER_MASTER) | ✅ UNION ALL | GOLD DIM_MEMBER가 유형 불문 단일 DK 요구. 번호 체계 상이 → UNION ALL + MEMBER_TYPE 구분 |
| D2 | TH_MM_FDRM_MBER_STNG_DTLS 컬럼 정의 | ✅ **해소(2026-06-22 정의서)** | `BF_STAT_CD`(이전)·`CHN_STAT_CD`(변경후)·`SER_NO`·`FRST_REGIST_DT`(변경시점) 확정 → FMM 시점지표·SCD2 차단 해제(R1 해소) |
| D3 | 납입+청구 단일 테이블 (CRM_PAYMENT_BILLING) | ✅ 단일(회비+기부금 UNION ALL) | 회비(`MBRFEE_ACMSLT`)는 동일 행에 PAY_*·RQEST_* 공존 → 행 분리 금지. 기부금(`DNTN_DTLS`)은 청구 부재(납입만). 키·회원체계 상이 → PAYMENT_TYPE 구분(R9). GOLD에서 measure 분리 |
| D4 | 발송 3분할 (REQUEST/MEMBER/RESULT) | ✅ 3분할 | 원천 grain 상이(마스터/회원상세/성과). wide table 방지 |
| D5 | CRM_SPONSORSHIP_MASTER 컬럼 | ✅ **해소(2026-06-22 정의서)** | `SPNSR_BSNS_ID`(PK)·`SPNSR_BSNS_NM`·`SPNSR_BSNS_ABRV_CD` 확정 |
| D6 | 코드→라벨: SILVER에서 조인 | ✅ 양쪽 보존 | 원본 코드(조인키) + 라벨(표시) 병행 |
| D7 | 결연마스터 배치 | ✅ PLEDGE에 JOIN(단 R7로 별도 분리) | 결연 시작/중단일·아동코드 = 약정 속성. grain 검증 결과 #15로 분리(R7) |
| D8 | GOLD 물리 형태 | ✅ 물리 테이블 | star schema DDL(18). SILVER→GOLD 적재는 별도 트랙 |
| D9 | BRONZE 외부 집계 테이블 | ✅ 신규 star schema 소스 제외 | raw grain 요구 → 집계본 비참조(§1-5). 레거시 PoC View는 `SILVER EXT_*` 경유(GOLD 직참조 없음) |
| D10 | DIM_MEMBER SCD2 적용 범위 | ✅ STATUS만 SCD2 | 이력 소스가 상태만 보유. GENDER·REGION·신규기존은 SCD1(원칙6·R6) |
| D11 | 계층 참조 방향 | ✅ 단방향 strict layering | `SERVING→GOLD→SILVER→BRONZE`(원칙9 / P2) |

---

## 3-1. 실행 리스크 / 검증 필요 (S-1 착수 전 확인)

| ID | 리스크 | 영향 | 조치 |
|---|---|---|---|
| ~~R1~~ | ~~FMM 시점지표가 D2에 차단~~ | — | ✅ **해소(2026-06-22 정의서)** — `STNG_DTLS` `CHN_STAT_CD`+`FRST_REGIST_DT`로 월말 시점상태 산출 가능. `EFFECTIVE_FROM/TO` 자리 확보(②) |
| **R2** | **발송 키 이원화** — `SND_*`(SEQ_NO) vs `TM_MS_*/TD_MS_*`(SNDNG_KEY)가 별개 발송 시스템 가능성. 단순 통합 시 키 충돌·sparse NULL. ⚠️ **`SND_*` 스키마는 LLM생성(미검증)**. | CRM_SEND_REQUEST/MEMBER/RESULT 구조 흔들림 | 두 계열 관계(미러/병렬/마이그레이션) BRONZE 실측 + `SND_*` 원본 정의서 확보(⑩ OPEN-36·37) → 시스템별 분리 또는 공통키 통일 |
| **R3** | **회원 UNION ALL 스키마 불일치** — 정기(31)·일시(22) 컬럼셋 다름, 동일의미 컬럼 형식 상이(수신동의: 정기 코드 MS027/MS028 vs 일시 Y/N). | CRM_MEMBER_MASTER 적재 컬럼 정렬 오류 | S-1: 공통 교집합+NULL 패딩·MEMBER_TYPE·수신동의 표준화(상세 `S1_CRM_entity_design/01_CRM_MEMBER_MASTER.md` §3) |
| ~~R4~~ | ~~memnum 원천 미확인~~ — `memnum`은 별도 키가 아니라 **`member id`와 동일한 `회원번호`(문자) 지표**(URL 파라미터 용어, 예 `?memnum=1831636`). | — | ✅ **해소** — `DIM_MEMBER_IDENTITY.MEMNUM`(#111)은 회원번호(=member id #112) 컬럼을 그대로 사용. 신원 매핑(공81·신32·신33) 차단 해제(§2-1). 지표용어통합 CSV가 둘 다 `회원번호`로 정의 |
| **R5** | **GA4/ERP/AGENCY/🆕GADS/🆕ADMIN 미입고** — FGA·FAD·FTG-B·DIM_AD_CREATIVE·DIM_GA_* raw 소스 + GADS 광고·ADMIN 앱푸시/이벤트 미수령(의도된 대기). | 해당 GOLD DIM/FACT·예약컬럼 비어있음 | 입고 후 S-6 |
| **R6** | **DIM_MEMBER SCD2 부분 한계** — GOLD는 상태·지역·신규기존을 SCD2 선언하나 이력 소스는 상태만. 지역·신규기존 이력 복원 불가. | 과거 시점 지역/신규기존 정확도 저하 | D10 확정(STATUS만 SCD2). 나머지 SCD1, 한계는 GOLD 적재 트랙 전달 |
| **R7** | **약정 3중 grain 병합** — CRM_SPONSORSHIP_PLEDGE가 개발(DVLP_AMT)·사업(SPNSR_BSNS)·결연(RELATNSP_KEY) 키 상이 원천 병합. 단순 JOIN 시 카디널리티 폭발. | FMM measure 정합 위험 | **해소(S-1)**: DVLP_AMT 스파인 + SPNSR_BSNS 1:1 JOIN + **결연 별도 엔티티 분리**(A안, CRM 14→15). 상세 `S1_CRM_entity_design/03_CRM_SPONSORSHIP_PLEDGE.md` §1·OPEN-11 |
| **R8** | **레거시 View의 BRONZE/RAW 직참조 잔존** — P2(원칙9)상 GOLD 레거시 View 35(특히 03_GOLD_SERVING §3.6 redesign B군 9)는 `SILVER EXT_*` 경유여야 하나 PoC 잔재 가능. | P2 위반, lineage·Owner's Rights 격리 깨짐 | `02_GN_DW_building/03_GOLD_SERVING.md` §3.6 대조 → BRONZE/RAW 직참조 View를 `SILVER EXT_*` pass-through로 치환 확인 |
| **R9** | **납입+청구 이질 UNION ALL** — `CRM_PAYMENT_BILLING`이 회비(`MBRFEE_ACMSLT`, 청구+납입)·기부금(`DNTN_DTLS`, 납입만) 통합. 키·회원체계·컬럼셋 상이. 회비차수(`MBRFEE_SQNC`)·청구차수(`RQEST_SQNC`)로 행 증식 → `SUM()` 중복 위험. | 구조·FMM 납입(#69·70)/청구(#71) measure 정합 | **해소(S-1)**: PAYMENT_TYPE 구분 + 타입접두 PK(`PAY_KEY`) + 기부금 청구 NULL 패딩. 카디널리티·키 유일성 BRONZE 실측. 상세 `S1_CRM_entity_design/04_CRM_PAYMENT_BILLING.md` §1·OPEN-14·OPEN-19 |
| **R10** | **후원사업 키 이원화 (범위 축소)** — 마스터 PK `SPNSR_BSNS_ID`(TEXT). 정의서(2026-06-22) 확인 결과 ③ `DVLP_AMT`·`SPNSR_BSNS`·회비 `MBRFEE_ACMSLT`는 `SPNSR_BSNS_ID`(TEXT)+`SPNSR_BSNS_NO`(NUMBER) **양쪽 보유** → 마스터에 `SPNSR_BSNS_ID` 직조인 가능. ⑥ CMPGN·`DNTN_DTLS`·⑦ 마스터는 `SPNSR_BSNS_ID` 보유. **⑮ `RELATNSP_MSTR_INFO`만 `SPNSR_BSNS_NO`(NUMBER) 단독 보유**. | ⑮ 결연 ↔ DIM_SPONSORSHIP 조인만 무결성 확인 필요(나머지는 ID 직조인) | BRONZE 실측 = `SPNSR_BSNS_NO`↔`SPNSR_BSNS_ID` 1:1 매핑(**⑮ 한정**). 상세 `07_…md` OPEN-31 |
| ~~R11~~ | ~~BRONZE 스키마 LLM생성(미검증)~~ | — | ✅ **해소(2026-06-22 컬럼정의서)** — `SND_REQ_MST`·`SND_MEMBER_LIST`·`TM_MS_CRMN/EVENT`·참여 4원천 전 컬럼 확정(기존 추론명과 일치). ⑩⑪⑫⑬ 반영 완료 |

> **분류**: ✅ **해소(2026-06-22 정의서)**: D2·D5·R1·R11·OPEN-51. ✅ **R4 해소**: `memnum` = `member id` = `회원번호`(문자, URL 용어) — 별도 원천 불필요. **잔존** — R2·R3·R7·R9·R10 = 설계 확인(R7·R9는 S-1 해소; R2는 SND↔TM_MS 관계 실측; R10은 후원사업 키 매핑 실측 **⑮ 결연 한정**). R5 = 입고 대기. R6 = 한계 명시 후 GOLD 트랙. R8 = 계층 규칙(P2) 검증(레거시 트랙).

---

## 3-2. SILVER 의존 없는 GOLD 객체

| GOLD 객체 | 비고 |
|---|---|
| `DIM_DATE` | ETL 생성 캘린더(SILVER 소스 없음). 팩트 일자 범위로 채움. §6 커버리지 대상 제외 |

---

## 3-3. ▶BRONZE 컨트랙트 요청 (SILVER 역산 시 raw 부재 — 7건)

> `GOLD_SILVER 의존.md` §4와 동일. GOLD 구조상 **자리(예약 컬럼/SV metric)는 확보**돼 있으나, 아래 raw가 BRONZE에 입고돼야 값이 채워진다(구조 변경 불필요). 상세 컨트랙트는 `03_top-down_gold/BRONZE_컨트랙트 요청서.md`.

| # | 지표 | GOLD 위치 | 부재 raw → 요청 BRONZE | 소스 | SILVER 영향 |
|---|---|---|---|---|---|
| 1 | 공7 CRM 개발단가 | SV(FMM÷FAD) | 광고비 raw(캠페인 귀속) | AGENCY/ERP | 입고 후(S-6) |
| 2 | 공10 GA CVR | SV(FGA) | 전환수 raw | GA4 | 입고 후(S-6) |
| 3 | 공98 평균세션시간 | SV(FGA) | 세션 engagement_time raw | GA4 | 입고 후(S-6) |
| 4 | 공108 이탈율(GA) | SV(FGA) | bounce/engaged_session raw | GA4 | 입고 후(S-6) |
| 5 | 신9 캠페인별 개발단가 | FAD.편성비 | 편성비 raw | AGENCY | 입고 후(S-6) |
| 6 | 신10 매체별 개발단가 | FAD.모금성비용 | 모금성비용 세세목 | ERP | 입고 후(S-6) |
| 7 | 신11 캠페인별 ROI | SV(FAD) | 비용 raw + 캠페인별 ERP 기준 합의 | ERP/복합 | 입고+합의 후 |

> 7건 모두 **CRM 외 소스(GA4·ERP·AGENCY) 입고 의존** → CRM_* 15(S-1) 범위 밖, S-6 충족. (신8 LTV는 회비 21년~ 확보로 해소.)

---

## 4. 작업 단계

| 단계 | 산출물 | 대상 | 설명 |
|---|---|---|---|
| **S-1** | 엔티티 설계서 | CRM_* 15개 | grain·PK·컬럼 선별·타입·정제 규칙 상세. R1~R9 선결 확인 |
| **S-2** | DDL 초안 | CRM_* 15개 | CREATE TABLE (Snowflake 컴파일 검증) |
| **S-3** | 정제 매핑표 | CRM_* 15개 | BRONZE 컬럼 → SILVER 컬럼 1:1 매핑(ETL 명세) |
| **S-4** | 정제 프로시저 | SP_REFINE_CRM_* | CREATE OR REPLACE TABLE 멱등 방식 |
| **S-5** | GOLD 역산 검증 | — | GOLD_SILVER 의존 §1~§3 대비 누락/불일치 점검(§2-1 매핑 대조) |
| **S-6** | GA4/ERP/AGENCY/🆕GADS/🆕ADMIN | 입고 후 | S-1~S-5 반복(GA4_* 5 + ERP_* 2 + AGENCY_* 3 + GADS_* 1 + ADMIN_* 2 = 13, GADS·ADMIN 잠정) |
| **S-7** | 신원 브리지 설계 | `DIM_MEMBER_IDENTITY` 매핑 알고리즘 | GA↔CRM 1:N 신원해소 + `MATCH_METHOD`/`MATCH_CONFIDENCE` 산출(SILVER 트랙 책임). 입력: CRM측 MEMBER_NO·MEMNUM(=회원번호=member id, R4 해소) + GA측 GA_MEMBER_ID(#112)·SPONSORED_CHILD_CODE(#122 URL 파싱). cross-source 지표(공81·신32·신33) 선결. GA4 입고(S-6) 후 |

> **S-7 위상**: cross-source 신원 매핑이라 S-6과 분리. `DIM_MEMBER_IDENTITY`의 GA측·MEMNUM 잔여분 충족. 선결: GA4 raw 입고(MEMNUM=회원번호=member id로 R4 해소).
> **범위 명시**: SILVER→GOLD 적재 프로시저(SP_LOAD_GOLD_*)는 본 문서 범위 밖(별도 트랙 `03_top-down_gold/` 또는 `05_gold_etl/`).

---

## 5. 미착수 소스 코멘트

> GA4·ERP·AGENCY = **데이터 입고 후(S-6)** 설계. 예상 테이블·수요처는 §1-2~§1-4, 부재 raw는 §3-3.
> 원천 형식 미확정: GA4(BigQuery export raw — event_params·session_id·member_id) · ERP(DB? 엑셀 사업계획시트?) · AGENCY(API? CSV? — 광고소재·편성비·매체별 성과).

---

## 6. 정합성 기준

1. **CRM_* 15개**가 `GOLD_SILVER 의존.md` §1~§2의 모든 **SILVER_CRM** 참조를 커버(DIM 7 완전 + DIM_MEMBER_IDENTITY는 CRM측 MEMBER_NO만 부분 + FACT 3: FMM·FTG-D·FSE). DIM_MEMBER_IDENTITY의 GA_MEMBER_ID(#112)·SPONSORED_CHILD_CODE(#122)는 GA4 입고 후. MEMNUM(#111)은 회원번호(=member id)와 동일 지표이므로 CRM 회원번호로 충족(R4 해소). GA4/ERP/AGENCY raw 참조는 입고 후(S-6).
2. SILVER 컬럼 타입 ↔ GOLD DDL 타입 호환(NUMBER↔NUMBER, VARCHAR↔VARCHAR, DATE↔DATE).
3. SILVER grain ≥ GOLD grain(SILVER raw, GOLD 집계 후). → 외부 집계본은 위배로 제외(§1-5).
4. 코드 컬럼: 원본 코드값(`*_CD`) + 라벨(`*_NM`) 병행 보존.
5. PK 유일성: 모든 SILVER 테이블 PK 기준 중복 0건.
6. SILVER 테이블은 **GOLD star schema가 요구하는 소스**여야 함(원칙3). GOLD 비참조 BRONZE는 미생성.

---

## 7. 수치 요약

| 항목 | 수량 |
|---|---|
| SILVER 스키마 | 1개 (`GN_DW.SILVER`) |
| 즉시 설계 가능 (CRM_*) | **15개** |
| 데이터 입고 후 (GA4_* 5 + ERP_* 2 + AGENCY_* 3 + 🆕GADS_* 1 + 🆕ADMIN_* 2) | **13개** (GADS·ADMIN 3개 잠정) |
| 예상 총 SILVER 테이블 | **28개** |
| BRONZE CRM 원천 | 40테이블 / **882컬럼** (`컬럼정의서 20260622.csv`) |
| BRONZE CRM 미포함 | 3개 (사업장·아동·결연교체, GOLD 미참조) |
| BRONZE 외부 집계 제외 | 전체 (GOLD 비참조, 레거시 PoC View 전용 — §1-5) |

> GOLD 18(12 DIM+6 FACT) 커버: CRM_* 15가 **DIM 7 완전 + DIM_MEMBER_IDENTITY CRM측 충족(MEMBER_NO·MEMNUM=회원번호=member id)** + FACT 3(FMM·FTG-D·FSE) 충족(즉시). 잔여 **DIM 5**(DATE는 ETL 생성; GA_SOURCE·GA_EVENT·AD_CREATIVE는 입고 후; DIM_MEMBER_IDENTITY의 GA측) + FACT 3(FTG-B·FGA·FAD)은 GA4/ERP/AGENCY 입고로 충족
