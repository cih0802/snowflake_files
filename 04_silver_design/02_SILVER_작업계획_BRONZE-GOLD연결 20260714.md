<!-- LLM-METADATA
doc_id: SILVER_BRIDGE_PLAN
doc_role: silver_work_plan MASTER INDEX (원천별 실행문서 매핑)
project: GN_DW (굿네이버스)
created: 2026-06-29
updated: 2026-07-14 (원천별 4개 실행문서로 분할 · 본 문서는 매핑 인덱스로 축소 · §7 실행 방법론 재정비: 착수순서 GA4→S7→ERP→AGENCY, 블로커 事前 triage, 파이프라인 2계층 분리)
fragments:
  - 03_SILVER_작업계획_CRM전용 20260714.md      # CRM 21객체 · 트랙 A · S-1~S-5
  - 04_SILVER_작업계획_GA4전용 20260714.md       # GA4 5객체 · 트랙 B
  - 05_SILVER_작업계획_ERP전용 20260714.md       # ERP 3객체 · 트랙 C
  - 06_SILVER_작업계획_AGENCY전용 20260714.md    # AGENCY 3객체 · 트랙 D
ddl(정본): 08_SILVER_테이블DDL_20260714.sql + 09_SILVER_적재쿼리_20260714.sql
inputs(gold): 03_top-down_gold/03_테이블 설계.md(24테이블 정본) · 08_silver의존.md(lineage)
END-METADATA -->

# SILVER 작업계획 — BRONZE → SILVER → GOLD (마스터 인덱스)

> **목적**: BRONZE 원천을 GOLD star schema(**24테이블 = 15 DIM + 9 FACT**, 정본 `03_top-down_gold/03_테이블 설계.md`)로
> 적재하기 위한 **SILVER 정제 레이어**의 설계·작업 계획.
>
> 📁 **본 문서 = 매핑 인덱스**. 원천별 상세 작업은 아래 4개 실행문서로 분리(2026-07-14).
> 여기에는 **공통 원칙 · GOLD 커버리지 요약 · 교차소스 항목 · 작업 단계**만 둔다.

---

## 1. 문서 구성 (원천 → 실행문서 매핑)

| 원천 | 실행문서 | SILVER 객체 | 트랙 | 상태 (2026-07-14) |
|---|---|---|---|---|
| **CRM** | `03_SILVER_작업계획_CRM전용 20260714.md` | 21 (+1 신규) | A | ✅ 21 적재완료 + S-5 검증완료(G1·G2 해소). +신규 `CRM_BIZ_TARGET`(사업목표, 원천=CRM 확정 2026-07-20) 입고 대기(E-6·스키마-only) |
| **GA4** | `04_SILVER_작업계획_GA4전용 20260714.md` | 5 | B **(착수 1차)** | ✅ 5객체 PoC 적재(1일샤드 271,544행·DQ 통과) — 전기간 입고 시 멱등 재적재 |
| **ERP** | `05_SILVER_작업계획_ERP전용 20260714.md` | 2 | C **(착수 2차)** | ✅ 2객체 적재(BUDGET 24,480·BUDGET_ITEM 2,040). ※사업목표(구 ERP_BIZ_TARGET)는 CRM 트랙 재분류(2026-07-20) |
| **AGENCY**(∪GADS∪ADMIN) | `06_SILVER_작업계획_AGENCY전용 20260714.md` | 2 | D **(착수 3차)** | ✅ 2객체 적재(AGENCY_COST는 리뷰 후 GOLD 이관) |
| 교차소스 신원브리지 | 본 문서 **§6**(S-7) | 1 `IDENTITY_MEMBER_XREF` | — | ✅ 적재완료(1,348행·DQ 통과·PoC 샤드) |
| **합계** | | **32** (+ `DIM_DATE` 생성) | | |

**공유 산출물·참조**
- **DDL/적재 정본**: `08_SILVER_테이블DDL_20260714.sql`(STEP 1·2 CRM 21 + STEP 6 GA4 5 + STEP 7 신원브리지 CREATE) + `09_SILVER_적재쿼리_20260714.sql`(STEP 3 CRM INSERT·발송 PK ALTER + STEP 6 GA4 + STEP 7 브리지+7-DQ + STEP 8 통합검증 DQ-1/2/3). 실행순서 **08 → 09**. (구 `silver_stepbystep_ddl.sql`은 `_archive` 이관.)
- **이슈 해소 상세**: 원천별 실행문서 `03_SILVER_작업계획_CRM전용`·`04~06`(트랙별 Q 해소) + `09_SILVER_적재쿼리_20260714.sql` STEP별 정제 주석.
- **CRM 엔티티 설계서**: `S1_CRM_entity_design_legacy/`
- **GOLD 정본·의존**: `03_top-down_gold/03_테이블 설계.md`(24테이블) · `08_silver의존.md`(역산 lineage)

---

## 2. 실측 상태 (2026-07-14) — BRONZE 4소스 전부 입고

| BRONZE 스키마 | 테이블 | 행수 | SILVER |
|---|---|---|---|
| `BRONZE_CRM` | 43 | 112,512,161 | ✅ 21테이블 적재(110,731,312) |
| `BRONZE_BIGQUERY` | 1 | 287,025 | ✅ 5객체 PoC 적재(GA4_EVENT 265,312·GA4_TRAFFIC_SOURCE 1,175·GA4_EVENT_DIM 3,633·GA4_IDENTITY 1,348·GA4_DEVICE 76) — 1일 샤드 `events_20260501`, 전기간 입고 후 멱등 재적재 |
| `BRONZE_ERP` | 1 | 2,041 | ✅ 2테이블 적재(ERP_BUDGET_ITEM 2,040·ERP_BUDGET 24,480) · ※사업목표(CRM_BIZ_TARGET)는 BRONZE_CRM으로 재분류 |
| `BRONZE_AGENCY` | 3 | 235,572 | ✅ 2테이블 적재(AD_PERFORMANCE 235,572·AD_CREATIVE 8,473) · AGENCY_COST 리뷰 후 제거→GOLD |

> **S-5 GOLD 역산 검증(CRM)**: CRM 유래 GOLD 15테이블 **전건 적재 가능**. 갭 2건(G1 `DIM_MEMBER.REGION/AGE_BAND` · G2 `DIM_SERVICE.SEND_TYPE 대/중/소`) **2026-07-14 해소·실측 검증 완료** → 상세는 CRM 문서(03).

> **🔎 아키텍처 리뷰 이력(2026-07-14)** — 적재 완료 트랙 전수 비판적 점검(PK유일성·PK-NULL·집계·단방향·행수/총액 대사):
> - **CRM(21)**: 결함 0. 집계 1건(`CRM_SEND_RESULT`)은 원천내 엔티티-grain 통합으로 검토 후 유지(대사 정확). → 문서 03 §6.
> - **ERP(2)**: 결함 0. wide→long은 reshape(집계 아님)·총액 대사 0. → 문서 05 §5.
> - **AGENCY**: 결함 **2건 발견·수정** — ① 연·월 텍스트 파싱 96% NULL → **DATE 파생**(NULL 0) · ② `AGENCY_COST` 월 롤업 §3 위반 → **제거→GOLD**(3객체→2). → 문서 06 §5.
> - **GA4(5, PoC 1일 샤드)**: DQ 4종 전부 통과 — 행수 대사(GA4_EVENT 265,312 = 원천 distinct PK, 원천 287,025 중 PK중복 21,713행 GROUP BY dedup·GA-1)·PK유일 0·EVENT_DT 파생 NULL 0·fan-out 0. session-fill(07 §5-A)로 회원귀속 **4.44%(SILVER dedup 265,312 기준; BRONZE raw 287,025 기준 4.22%)→30.23%**(SESSION_FILL 68,428·CONFLICT 1,648·UNRESOLVED 183,458, 추론값 경고 유지). **사후검토 수정 1건**: `GA4_TRAFFIC_SOURCE` first-touch/collected 혼재 그레인 오염(6,736)→last-click 한정(1,175). 리스크 2건(GA-2 event_label 카디널리티·GA-3 팩트↔DIM_GA_SOURCE 키정합) 문서화. → 문서 04 §5·§7.
> - 공통 교훈: 텍스트 연·월 컬럼 신뢰 금지(DATE 파생) · SILVER 월 롤업은 GOLD로 · 행수/총액 대사를 DQ 게이트 필수화.

---

## 3. SILVER 공통 원칙

- **스키마**: `GN_DW.SILVER` 단일. **테이블명 = 소스 접두사 + 엔티티**: `CRM_*`·`GA4_*`·`ERP_*`·`AGENCY_*`.
- **계층 단방향**: `SERVING → GOLD → SILVER → BRONZE`. GOLD는 BRONZE 직접참조 금지.
- **SILVER가 하는 일 (정제만)**: ① 물리 타입 캐스팅 ② NULL/빈값 표준화 ③ **코드→라벨 병행보존**(`CRM_CODE`=`TC_CMMN_DTL_CD` (CD_ID,DTL_CD_ID) 복합조인) ④ PK 중복제거·증분키 정의 ⑤ **동일 소스 내 JOIN까지만**.
- **SILVER가 안 하는 일**: 비율·증감·LTV·ROI 등 derived(81개) → GOLD/SV. 월 롤업·cohort 집계·**교차소스 conform 조인** → GOLD.
- **그레인 원칙**: SILVER 객체 = 원천 비즈니스 객체 1개. 채널(이메일/문자/우편)·정기/일시 분리는 **구조적 UNION**으로 통합, **상이한 비즈니스 사건**(개발·증감·중단·재후원·발송·행사참여)은 분리 유지.

**공통 정제 규칙 (전 원천 적용)**
1. **타입 정본** = 원천별 BRONZE DDL(CRM=`09_bronze_crm_ddl.sql`). 컬럼집합 불일치는 입고팀 확인.
2. **코드 변환**: 코드 컬럼 → `CRM_CODE` 조인으로 `_NM` 라벨 생성, 코드·라벨 병행보존. 하드코딩 코드는 CASE 매핑.
3. **증분 적재**: PK 후보·갱신패턴(테이블정의서). 누적형 vs `LAST_UPDT_DT` 머지.
4. **적재 메타 4컬럼**: `DW_SOURCE_SYSTEM`·`DW_SOURCE_TABLE`·`DW_LOAD_TS`·`DW_UPDATE_TS`(+`DW_BATCH_ID`).
5. **금액 단위**: 원금액 보존. `(건)=SUM(금액)/10000` 변환은 GOLD measure에서.
6. **표준화**: NULL(빈문자·`'NULL'`·`'-'`→NULL) · 날짜(→DATE/TIMESTAMP) · 숫자(콤마/통화기호 제거) · 문자(TRIM·전각→반각·UTF-8) · 컬럼명 UPPER_SNAKE_CASE.
7. **SCD2 한계**: 회원 SCD2 가능 속성 = **상태(STATUS)만**. 성별·지역·신규기존은 마스터 현재값=SCD1(과거 복원 불가).

---

## 4. GOLD 24 ← SILVER 소스별 커버리지 요약

> 상세 행별 매핑(BRONZE 원천·핵심 작업)은 각 원천 실행문서. 여기서는 GOLD 24테이블의 **소스 귀속·빌드 가능성**만 요약.

| 소스 | GOLD DIM | GOLD FACT | 상태 |
|---|---|---|---|
| **CRM** | DIM_MEMBER · DIM_MEMBER_IDENTITY(CRM측) · DIM_CAMPAIGN · DIM_SPONSORSHIP · DIM_ORG · DIM_SERVICE · DIM_PAYMENT · DIM_REASON · DIM_EVENT | FMM · FME · FTG-D · FSE(CRM분) · FEP(CRM분) | ✅ 빌드·적재 가능 |
| **GA4** | DIM_GA_SOURCE · DIM_GA_EVENT · DIM_DEVICE(GA분) · DIM_MEMBER_IDENTITY(GA측) | FGA · FAD(전환분) | 🟡 입고 후(트랙 B) |
| **ERP** | DIM_BUDGET_ITEM | FBD(편성/집행) | ◐ 입고 후(트랙 C). ※FTG-B(사업목표)는 CRM 트랙 재분류 |
| **CRM(신규)** | — | FTG-B(사업목표, `CRM_BIZ_TARGET`) | ⛔ CRM 신규 목표 테이블 입고 후(E-6·원천=CRM 확정 2026-07-20·단위 건) |
| **AGENCY** | DIM_AD_CREATIVE | FAD · FBD(모금성비용/광고비) | 🟢 입고·검토 후(트랙 D) |
| **생성/교차** | DIM_DATE(생성) | — | ✅ / S-7 |

→ **24/24 빌드 가능**(미생성 원천 SILVER 신설 전제). CRM 단독으로 GOLD 15테이블 착수·적재 완료. 잔여 9는 GA4·ERP·AGENCY 입고로 충족.

---

## 5. 정합성 기준 (완료 정의)

- **커버리지**: GOLD 24테이블 각 컬럼이 SILVER 객체로 역추적되거나 (생성/derived/미수령)으로 명시 분류.
- **물리화 대상** = measure 60 + dimension 74 = **134컬럼**. derived 81은 SILVER/GOLD 적재 제외(SV).
- **타입**: SILVER 컬럼타입 = DDL 정본과 일치 또는 의미타입 의도 캐스팅(매핑표 기록).
- **키 무결성**: `MEMBER_DK` 불변, conform 차원 키(MONTH_KEY·DATE_SK·ORG·CAMPAIGN) 소스 간 일치.
- **단방향**: SILVER가 BRONZE만 참조, GOLD가 SILVER만 참조(직참조 0건).
- **DQ 게이트**: 모든 SILVER 테이블에 **PK 유일성·UNION 컬럼정합·조인 fan-out 테스트**를 붙여 미검증 가정으로 인한 무결성 오류 차단.

---

## 6. 교차소스 객체

> 🔄 **[2026-07-29]** `08_SILVER_테이블DDL_20260714.sql` STEP 6 의 브리지 배치근거·grain 주의 주석을 축약하고 **본 절을 정본으로 참조**하도록 정리했다. 08 에는 GOLD 소비계약 요약 3줄(pseudo grain ≠ 회원 grain · `MEMBER_DK` DISTINCT + UNMATCHED 제외 · FACT 는 LEFT JOIN)만 남겼다. 전문은 아래 C1~C4.

- **`IDENTITY_MEMBER_XREF` (신원 브리지, S-7)**: SILVER "동일소스 only" 원칙의 **유일한 교차소스 예외**. GA↔CRM 신원해소를 전용 브리지로 격리(`MATCH_METHOD`/`MATCH_CONFIDENCE`). 입력 = CRM 회원번호(=memnum=member id) + GA `user_id`. **✅ 2026-07-14 적재완료** — 위치=**SILVER 확정**(보수적 근거: 확률적 신원해소(session-fill 추론 + match confidence)를 SILVER에 격리→GOLD 결정적 차원 유지 / SK·conform은 GOLD 소관이므로 브리지엔 IDENTITY_SK 없음). grain=1행/`USER_PSEUDO_ID`. 실측 매칭 `GA_MEMBER_ID=MEMBER_DK` **exact 100%**(1,348행·fan-out 0·type불일치 0·CONFIDENCE 전량 HIGH). **CHILD_CODE 제외**(CRM_SPONSOR_RELATION 회원×아동 fan-out 회피 — 결연아동은 GOLD URL파싱/결연팩트에서). **미매칭 GA 보존**(MATCH_METHOD='UNMATCHED', 전기간 샤드 커버리지 추적). → GOLD `DIM_MEMBER_IDENTITY`가 이 브리지를 소비하며 IDENTITY_SK 부여. (CRM측은 CRM 문서(03)에서 이미 충족.)
- **`DIM_DATE` (생성 차원)**: 원천 없는 conform 차원 → SILVER 정제 대상 아님. GOLD(또는 util)에서 생성 → SILVER 객체 수 제외.
- **★ S-7 브리지 GOLD 소비계약 (후속 오류방지 — 09 STEP 7 정본, 실측근거 2026-07-14)**:
  - **C1 (익명 95%)**: GA4_EVENT distinct pseudo 27,840 중 신원해소 1,348(**4.84%**). `FACT_GA_BEHAVIOR`는 XREF에 **LEFT JOIN 필수**(INNER 금지=이벤트 95% silent 소실). 익명/미매칭 → `DIM_MEMBER_IDENTITY` **Unknown 멤버(`SK=0`)** 귀속. *(2026-07-16 정정: 구현 확정값 `0`, 초안 `-1` 폐기)*
  - **C2 (grain)**: XREF=pseudo grain(1,348) ≠ `DIM_MEMBER_IDENTITY`=member grain(distinct 1,274). 회원차원 구축 시 **MEMBER_DK DISTINCT 필수**(중복계상 방지).
  - **C3 (UNMATCHED)**: `DIM_MEMBER_IDENTITY.MEMBER_DK`는 NOT NULL → 회원차원은 `MATCH_METHOD='MEMBER_ID_EXACT'` 필터로 UNMATCHED 제외. 팩트에서만 Unknown(`SK=0`) 흡수.
  - **C4 (조인키)**: MEMBER_DK 최대길이 9(≤VARCHAR10)·공백 0(PoC). 전기간 재적재 시 재검증.
  - **✅ GOLD 실행결과(2026-07-16 갱신, 순서8 완료)**: `DIM_MEMBER_IDENTITY`·`DIM_EVENT` 등 **13개 DIM 전량 `SK=0` Unknown 시드행** 생성 완료(`union all select 0 '(미매핑)'`) + GA/이벤트 팩트 LEFT JOIN 적용. **초안의 `-1 UNKNOWN` 표기는 구현 단계에서 `SK=0`으로 통일·폐기.** ⚠️ 잔여: `DIM_MEMBER` 자체에는 아직 Unknown 시드행 없음(EVENT_PARTICIPATION MBER_NO 9,480 orphan 흡수 게이트).
- **ADMIN 피드**(앱푸시→FSE, 행사 조회수→FEP): AGENCY로 흡수 또는 CRM 서비스에 합류 — 목적지 미정(AGENCY 문서 06 참조).

---

## 7. 작업 단계 (S-1 ~ S-7) 및 진행 현황

| 단계 | 산출물 | 대상 | 상태 |
|---|---|---|---|
| **S-1** | 엔티티 설계서 | CRM 21 | ✅ (`S1_CRM_entity_design_legacy/`) |
| **S-2** | DDL (`CREATE TABLE`) | CRM 21 | ✅ (`08_...테이블DDL`) |
| **S-3** | 정제 매핑표 | CRM 21 | ✅ |
| **S-4** | 정제 적재(멱등 INSERT OVERWRITE) | CRM 21 | ✅ (`09_...적재쿼리`) |
| **S-5** | GOLD 역산 검증 | CRM→GOLD 15 | ✅ **2026-07-14 완료** (13 충족 + G1·G2 해소, 상세=CRM 문서 03) |
| **S-6** | GA4/ERP/AGENCY 설계·적재 | 트랙 B/C/D | 🟢 GA4 5객체 PoC 적재·DQ 통과(1일 샤드)·ERP·AGENCY 완료 — 전기간 GA4 샤드 입고 후 멱등 재적재. GA4(04)·ERP(05)·AGENCY(06) |
| **S-7** | 신원 브리지 | `IDENTITY_MEMBER_XREF` | ✅ **2026-07-14 적재완료** (1,348행 · GA_MEMBER_ID=MEMBER_DK exact 매칭 100% · fan-out 0 · PK유일 · CONFIDENCE HIGH 1,348 · CHILD_CODE 제외 · 미매칭 보존 · SK없음→GOLD 소관, 본 문서 §6) |

**다음 순서 (실행 방법론 — 데이터 아키텍처 검토 반영 2026-07-14)**

> **원칙 A — 스키마 단위 반복(iterative)**: 원천별로 `08 DDL 생성 → 09 적재쿼리 생성 → 실행 → 검증`을 1사이클로 반복. GA4·ERP·AGENCY 각각 08/09에 append(구 `_archive/09` 초안 이관).
> **원칙 B — 블로커는 DDL 작성 前 triage**: 실행으로 해소 불가한 이슈(원천 부재·현업/타원천 의존)는 착수 前에 분류하여 **descope(스키마-only) 또는 대기**로 확정. 실행으로 발견되는 이슈(타입 불일치·fan-out·PK 중복)만 `실행 → 이슈해결` 루프로 처리.
> **원칙 C — 파이프라인은 2계층 분리**: dbt **모델**(테이블 정의·적재 로직)은 스키마별 반복 OK. 그러나 **오케스트레이션/스케줄링**(Task·dbt job·증분 트리거)은 S-7 브리지 cross-reference 정합 때문에 **전체 SILVER 안정화 후 일괄** 구성.

| 순서 | 작업 | 산출물/게이트 | 근거 |
|---|---|---|---|
| 0 | ✅ 트랙 A(CRM) S-1~S-5 완료 | 03 문서 | 완료 |
| 1 | ✅ **블로커 질문 스키마별 triage** | Q1~Q16 + 비-Q 분류·트랙 게이트 확정(완료) | 재작업 방지(원칙 B) |
| 2 | ✅ **트랙 B(GA4) 1차** — 08 DDL STEP 6 → 09 적재 STEP 6 → DQ 4종 통과 (PoC 1일샤드) | GA4 5객체 271,544행 | S-7·GOLD critical path 확보 — 전기간 입고 시 멱등 재적재 |
| 3 | ✅ **S-7 신원 브리지** (`IDENTITY_MEMBER_XREF`) — 08 DDL STEP 7 → 09 적재 STEP 7 → DQ 통과 | 브리지 1객체 1,348행 (§6) | GA4 입고 직후 착수·완료 |
| 4 | ✅ **트랙 C(ERP) 2차** — 08 DDL → 09 적재 → DQ 검증 완료 | ERP_BUDGET_ITEM 2,040 · ERP_BUDGET 24,480 · BIZ_TARGET 스키마-only | GA4와 병렬 실행(외부 의존 0) |
| 5 | ✅ **트랙 D(AGENCY) 3차** — 설계결정 6종 확정 → 08 DDL → 09 적재 → DQ 검증 완료 | AD_PERFORMANCE 235,572 · AD_CREATIVE 8,473 · (COST 823행은 §3 위반으로 GOLD 이관 — SILVER 미생성) | 외부 의존 0(설계결정 내부 해소) |
| 6 | ✅ **전체 SILVER 통합 검증** (2026-07-14 실행, 09 STEP 8) | DQ-1 PK 유일성 30객체 dup=0 ✅ · DQ-3 fan-out 논리충족 ✅ · DQ-2 통합앵커(identity·ERP·결연) orphan 0 ✅ / ⚠️ EVENT_PARTICIPATION 2건(EVENT_KEY 263,611=ADMIN행사 미입고 53건·MBER_NO 9,480=탈퇴/비CRM) → **결정: GOLD DIM Unknown 멤버(`SK=0`) + LEFT JOIN 으로 행 100% 보존, ADMIN 입고 시 소급 치환. SILVER 무변경** *(2026-07-16 정정: 구현 확정값 `0`, 초안 `-1` 폐기)* | SILVER 정합 확정 ✅ |
| 7 | ✅ **파이프라인 일괄 구성** (Bronze→Silver 오케스트레이션·스케줄) | dbt job / Task | 원칙 C |
| 8 | ✅ **GOLD 배포·적재 완료(2026-07-20)** — `GN_DW.GOLD` 24테이블 + WIDE VIEW 9개 생성·적재·COMMENT 적용 | GOLD 24T+9V (FACT_TARGET_BIZ만 0행) · 다음=Semantic View | `03_top-down_gold/08_silver의존.md` lineage |

---

## 8. DDL 설계 근거 (08_SILVER_테이블DDL에서 이관, 2026-07-29)

> 아래는 DDL 정본(`08_SILVER_테이블DDL_20260714.sql`)에서 분리한 **설계 근거·이슈 참조·의사결정 이력**.
> DDL 에는 필수 주석(구조 식별·COMMENT 절)만 잔존. 설계 배경이 궁금할 때 본 절 참조.

### 8-A. 파일 구조 규약
- 구 `silver_stepbystep_ddl.sql` 을 **08(구조 DDL) + 09(적재 쿼리)**로 분할 (2026-07-14).
- 08: STEP 1 스키마 생성 + CREATE OR REPLACE TABLE ×38 (멱등).
- 09: BRONZE→SILVER 정제 INSERT OVERWRITE + 발송키 PK ALTER.
- 실행 순서: 08 먼저(테이블 생성) → 09(적재).
- 실행 컨텍스트: `GN_DW_ADMIN` · `GN_DW_DEV_WH` (`01_환경 Role.md §2.2` 정합).

### 8-B. CRM 22테이블 설계 근거
- S-5 반영: [G1] CRM_MEMBER_DEV·CRM_MEMBER_AMT_CHANGE = AREA_CD·AREA_NM(CM018)·AGE — DIM_MEMBER REGION/AGE_BAND 스냅샷 소스.
- S-5 반영: [G2] CRM_SEND_REQUEST = SEND_GBN_TOP/MID/BOT(+_NM) 3계층 (SND 채널 한정, 타 채널 NULL) — DIM_SERVICE 대/중/소 소스.
- 발송 2테이블(CRM_SEND_REQUEST·CRM_SEND_MEMBER)의 복합 PK 전환은 09 상단 ALTER 로 수행(멱등 로드 흐름 유지).
- Q5: 발송키 이원화 — SND와 SMS/EMAIL 별도 키체계.
- Q6: 정기∪일시 UNION 스키마 정렬 잠정.
- Q13: 개발약정 3중 grain — 스파인 + N:1 LEFT JOIN 안전 확인.
- Q14: 납입 dedup · 청구 행기준 분리.
- Q15: SPNSR_BSNS_ID 크로스워크 파생 (후원번호 NO vs ID).
- Q16: 캠페인↔마케팅캠페인 조인키(무효화됐으나 컬럼 유지).

### 8-C. ERP 설계 근거
- 원장 실측(2026-07-14): 2,041행 = 지출1,875 + 수입165 + TOTAL 1(사전집계 요약행 → 제외).
- 원장 구조: 차원 10 + 총액 4 + 월별 48(편성YEAR_BDGT/추경CHN/조정ADJ/집행EXEC × 12개월).
- 설계: ITEM(마스터) + BUDGET(월 long 언피벗).
- 키: BUDGET_ITEM_DK = MD5(연도|수입지출|예산단위|장|관|항|목|세목|세세목|재원).
- CRM_BIZ_TARGET: 원천=CRM 확정(2026-07-20 정정, 트랙 ERP→CRM 재분류). 단위=건 확정(#152~155).

### 8-D. AGENCY 설계 근거
- 설계결정 6종 확정(2026-07-14):
  1. `_SOURCE_SYSTEM` = 테이블 기반(DIGITAL/REBROADCAST/VIDEO) — 행단위 출처 플래그 없음(A-2/Q9 해소).
  2. 인입콜: REBRDC=TEXT(비수치 2/2064) → TRY_TO_NUMBER · VIDEO=NUMBER.
  3. 전환 명/건: DGT GA_CONV_MBER_CNT(명)/CONV_VU_CNT(VU) · REBRDC DVLP_MBER_CNT/DVLP_CNT · VIDEO CONV_CALL_CNT.
  4. measure 불균일: 노출·클릭=DGT만 / 광고비=소스별 상이 → NULL 패딩.
  5. 캠페인명: DGT.CMPGN_NM(100%) · VIDEO.MKT_CMPGN_NM(98.4%) · REBRDC=컬럼부재.
  6. 파생(CPA/CTR/CVR/CPC/CPM/VTR): SILVER 미적재(원천 base만 보존) — 재계산은 GOLD/SV.
- [2026-07-28 순서9-I] 광고 팩트군 재설계(DEC-8~DEC-11):
  - DEC-8: 유형별 위성 팩트 분리 — 코어 + DIGITAL 위성 + BROADCAST 위성 + BROADCAST_CASE.
  - DEC-9: 대행사 파생값 `_SRC` 전량 보존(비가산 N, SUM 금지).
  - DEC-10: `DIM_DEVICE` `(해당없음)` 멤버 신설 — 방송광고 기기NULL 의미분리.
  - DEC-11: `AD_PERF_DK` 행 식별자 — MD5(AD_SOURCE_TYPE|ROW_HASH|DUP_SEQ). staging 이 발급 단일지점.
  - DEC-12: `AD_TYPE` → `AD_SOURCE_TYPE` 명명충돌 분리.
- staging 3종(AGENCY_AD_ROW_*) 규칙:
  - BRONZE 컬럼명 **그대로 보존**(개명·형변환 금지). 정제는 파생 계층 담당.
  - AD_PERF_DK 는 staging 이 발급 단일지점. 파생·GOLD 는 승계만(재계산 시 위성 조인 붕괴).
- O16(의미혼입 해소 2026-07-28): REBRDC 개발실적(DVLP_MBER_CNT·DVLP_CNT)이 코어 GA_CONV_* 로 혼입됐던 것을 위성 AGENCY_AD_BROADCAST 로 이관.
- AGENCY_COST 제거(2026-07-14): 월 롤업은 GOLD 소관 · AD_PERFORMANCE.AD_COST와 중복 · SILVER→SILVER 파생(단방향 위반).

### 8-E. GA4 설계 근거
- 근거: `07_GA4_SILVER_샤드통합 설계결정.md` · `14_GA4_작업지시 프롬프트_20260714.md`.
- 현재 1일 샤드 events_20260501(287,025행)만 입고 → PoC. 전기간 샤드 입고 후 동일 DDL로 멱등 재적재.
- 규칙: 명시 30컬럼(SELECT * 금지) · session_traffic_source_last_click(UI 일치) · 비가산 지표 raw 적재.
- GA4_TRAFFIC_SOURCE: session/last-click 한정. first-touch·collected 는 grain 상이로 제외.
- GA4_EVENT_DIM: event_label 혼합타입(고카디널리티) → GOLD 에서 event_name 키로 conform, label 은 팩트측 유지 권고.
- GA4_EVENT: 원천 샤드에 복합키 중복군(1일 16,187군) → 적재 PK GROUP BY dedup. session-fill(07 §5-A) 반영.

### 8-F. 신원 브리지(IDENTITY_MEMBER_XREF) 설계 근거
- 배치 근거: master §3 "교차소스 conform→GOLD" 원칙의 유일 예외. 확률적 신원해소를 SILVER 경계에 격리.
- 서러게이트키(IDENTITY_SK) 없음 — SK 부여·conform 은 GOLD 소관.
- grain = 1행/USER_PSEUDO_ID(GA 스파인). CHILD_CODE 제외(fan-out 회피).
- ★grain 주의: pseudo grain(1,348) ≠ member grain(distinct MEMBER_DK 1,274). GOLD 구축 시 MEMBER_DK DISTINCT 필수 + UNMATCHED 제외.
- 미매칭 GA 신원도 보존(MATCH_METHOD='UNMATCHED') — DQ 추적용.
- 단방향: SILVER(GA4_IDENTITY, CRM_MEMBER)만 참조. BRONZE/GOLD 직참조 없음.
