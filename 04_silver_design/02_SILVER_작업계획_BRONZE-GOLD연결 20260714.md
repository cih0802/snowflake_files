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
inputs(gold): 03_top-down_gold/03_설계.md(24테이블 정본) · 08_silver의존.md(lineage)
END-METADATA -->

# SILVER 작업계획 — BRONZE → SILVER → GOLD (마스터 인덱스)

> **목적**: BRONZE 원천을 GOLD star schema(**24테이블 = 15 DIM + 9 FACT**, 정본 `03_top-down_gold/03_설계.md`)로
> 적재하기 위한 **SILVER 정제 레이어**의 설계·작업 계획.
>
> 📁 **본 문서 = 매핑 인덱스**. 원천별 상세 작업은 아래 4개 실행문서로 분리(2026-07-14).
> 여기에는 **공통 원칙 · GOLD 커버리지 요약 · 교차소스 항목 · 작업 단계**만 둔다.

---

## 1. 문서 구성 (원천 → 실행문서 매핑)

| 원천 | 실행문서 | SILVER 객체 | 트랙 | 상태 (2026-07-14) |
|---|---|---|---|---|
| **CRM** | `03_SILVER_작업계획_CRM전용 20260714.md` | 21 | A | ✅ 적재완료 + S-5 검증완료(G1·G2 해소) |
| **GA4** | `04_SILVER_작업계획_GA4전용 20260714.md` | 5 | B **(착수 1차)** | 🟢 BRONZE 적재(1일 샤드)·SILVER 미생성 |
| **ERP** | `05_SILVER_작업계획_ERP전용 20260714.md` | 3 | C **(착수 2차)** | 🟢 BRONZE 적재·SILVER 미생성 |
| **AGENCY**(∪GADS∪ADMIN) | `06_SILVER_작업계획_AGENCY전용 20260714.md` | 3 | D **(착수 3차)** | 🟢 BRONZE 적재·SILVER 미생성 |
| 교차소스 신원브리지 | 본 문서 **§6**(S-7) | 1 `IDENTITY_MEMBER_XREF` | — | 🟡 GA4 입고 후 |
| **합계** | | **33** (+ `DIM_DATE` 생성) | | |

**공유 산출물·참조**
- **DDL/적재 정본**: `08_SILVER_테이블DDL_20260714.sql`(STEP 1·2 CREATE TABLE ×21) + `09_SILVER_적재쿼리_20260714.sql`(STEP 3 INSERT·발송 PK ALTER). 실행순서 **08 → 09**. (구 `silver_stepbystep_ddl.sql`은 `_archive` 이관.)
- **이슈 해소 상세**: `10_SILVER_이슈해결 핸드오버.md`
- **CRM 엔티티 설계서**: `S1_CRM_entity_design/`
- **GOLD 정본·의존**: `03_top-down_gold/03_설계.md`(24테이블) · `08_silver의존.md`(역산 lineage)

---

## 2. 실측 상태 (2026-07-14) — BRONZE 4소스 전부 입고

| BRONZE 스키마 | 테이블 | 행수 | SILVER |
|---|---|---|---|
| `BRONZE_CRM` | 43 | 112,512,161 | ✅ 21테이블 적재(110,731,312) |
| `BRONZE_GA4` | 1 | 287,025 | 미생성 (트랙 B — 1일 샤드 `events_20260501`, 전기간 대기) |
| `BRONZE_ERP` | 1 | 2,041 | 미생성 (트랙 C — `BDGT_ACMSLT_LEDGER`) |
| `BRONZE_AGENCY` | 3 | 235,572 | 미생성 (트랙 D — DGT 197,686 / REBRDC 2,064 / VIDEO 35,822) |

> **S-5 GOLD 역산 검증(CRM)**: CRM 유래 GOLD 15테이블 **전건 적재 가능**. 갭 2건(G1 `DIM_MEMBER.REGION/AGE_BAND` · G2 `DIM_SERVICE.SEND_TYPE 대/중/소`) **2026-07-14 해소·실측 검증 완료** → 상세는 CRM 문서(03).

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
| **ERP** | DIM_BUDGET_ITEM | FTG-B · FBD(편성/집행) | ⛔/◐ 입고 후(트랙 C) |
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

- **`IDENTITY_MEMBER_XREF` (신원 브리지, S-7)**: SILVER "동일소스 only" 원칙의 **유일한 교차소스 예외**. GA↔CRM 신원해소(매칭 로직 무거움)를 전용 브리지로 격리(`MATCH_METHOD`/`MATCH_CONFIDENCE`). 입력 = CRM 회원번호(=memnum=member id) + GA `user_id` + 결연아동코드. **GA4 입고 후** 착수, 위치(SILVER vs GOLD)는 S-7에서 확정. → `DIM_MEMBER_IDENTITY` 완성. (CRM측은 CRM 문서(03)에서 이미 충족.)
- **`DIM_DATE` (생성 차원)**: 원천 없는 conform 차원 → SILVER 정제 대상 아님. GOLD(또는 util)에서 생성 → SILVER 객체 수 제외.
- **ADMIN 피드**(앱푸시→FSE, 행사 조회수→FEP): AGENCY로 흡수 또는 CRM 서비스에 합류 — 목적지 미정(AGENCY 문서 06 참조).

---

## 7. 작업 단계 (S-1 ~ S-7) 및 진행 현황

| 단계 | 산출물 | 대상 | 상태 |
|---|---|---|---|
| **S-1** | 엔티티 설계서 | CRM 21 | ✅ (`S1_CRM_entity_design/`) |
| **S-2** | DDL (`CREATE TABLE`) | CRM 21 | ✅ (`08_...테이블DDL`) |
| **S-3** | 정제 매핑표 | CRM 21 | ✅ |
| **S-4** | 정제 적재(멱등 INSERT OVERWRITE) | CRM 21 | ✅ (`09_...적재쿼리`) |
| **S-5** | GOLD 역산 검증 | CRM→GOLD 15 | ✅ **2026-07-14 완료** (13 충족 + G1·G2 해소, 상세=CRM 문서 03) |
| **S-6** | GA4/ERP/AGENCY 설계·적재 | 트랙 B/C/D | ⏳ 입고분 실측 후 — GA4(04)·ERP(05)·AGENCY(06) 각 문서 |
| **S-7** | 신원 브리지 | `IDENTITY_MEMBER_XREF` | ⏳ GA4 입고 후 (본 문서 §6) |

**다음 순서 (실행 방법론 — 데이터 아키텍처 검토 반영 2026-07-14)**

> **원칙 A — 스키마 단위 반복(iterative)**: 원천별로 `08 DDL 생성 → 09 적재쿼리 생성 → 실행 → 검증`을 1사이클로 반복. GA4·ERP·AGENCY 각각 08/09에 append(구 `_archive/09` 초안 이관).
> **원칙 B — 블로커는 DDL 작성 前 triage**: 실행으로 해소 불가한 이슈(원천 부재·현업/타원천 의존)는 착수 前에 분류하여 **descope(스키마-only) 또는 대기**로 확정. 실행으로 발견되는 이슈(타입 불일치·fan-out·PK 중복)만 `실행 → 이슈해결` 루프로 처리.
> **원칙 C — 파이프라인은 2계층 분리**: dbt **모델**(테이블 정의·적재 로직)은 스키마별 반복 OK. 그러나 **오케스트레이션/스케줄링**(Task·dbt job·증분 트리거)은 S-7 브리지 cross-reference 정합 때문에 **전체 SILVER 안정화 후 일괄** 구성.

| 순서 | 작업 | 산출물/게이트 | 근거 |
|---|---|---|---|
| 0 | ✅ 트랙 A(CRM) S-1~S-5 완료 | 03 문서 | 완료 |
| 1 | **블로커 질문 스키마별 triage** | Q1~Q16을 블로커/비블로커로 분류 | 재작업 방지(원칙 B) |
| 2 | **트랙 B(GA4) 1차** — 전기간 샤드 입고 → 08 DDL → 09 적재 → 실행·검증 | GA4 5객체 SILVER | S-7·GOLD critical path 확보 |
| 3 | **S-7 신원 브리지** (`IDENTITY_MEMBER_XREF`) | 브리지 1객체 (§6) | GA4 입고 직후 착수 |
| 4 | **트랙 C(ERP) 2차** — 실측·현업확인 게이트 → 08 DDL → 09 적재 → 검증 | ERP 3객체(가능분) | GA4와 부분 병렬 가능 |
| 5 | **트랙 D(AGENCY) 3차** — 정규화·이름매칭·`_SOURCE_SYSTEM` 확정 → 08 → 09 → 검증 | AGENCY 3객체 | 확정사항 가장 많음 → 후순위 |
| 6 | **전체 SILVER 통합 검증** | cross-reference·DQ 게이트(§5) 전수 | 파이프라인 前 정합 확정 |
| 7 | **파이프라인 일괄 구성** (Bronze→Silver 오케스트레이션·스케줄) | dbt job / Task | 원칙 C |
| 8 | **GOLD 배포** — `GN_DW.GOLD` 생성 → SILVER→GOLD 적재 → WIDE VIEW·COMMENT → Semantic View | GOLD 24 + SV | `08_silver의존.md` lineage |
