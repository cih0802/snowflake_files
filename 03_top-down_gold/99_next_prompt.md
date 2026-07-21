# GN_DW 다음 스텝 인수인계 (2026-07-20 기준)

---

## 현재 상태 요약

| 영역 | 상태 |
|---|---|
| GOLD 설계 1~10단계 | **완료** (DDL·FK·메타·SILVER lineage·WIDE VIEW 전부 확정) |
| GOLD 스키마 실배포·적재 | ✅ **배포·적재 완료** — [2026-07-20 실측] `GN_DW.GOLD` **24테이블 + WIDE VIEW 9개** 생성·데이터 적재. FACT 행수: FMM 37.79M·FSE 38.47M·FME 4.63M·FEP 1.13M·FAD 235K·FGA 44.9K·FBD 24.5K·FTG_D 7.3K. **`FACT_TARGET_BIZ`만 0행**(=`CRM_BIZ_TARGET` 입고 대기) |
| BRONZE CRM | ✅ **전량 적재** — `GN_DW.BRONZE_CRM` **43테이블 / 927컬럼**(원천정의 41/876 + 템플릿 2테이블 `TD_MS_AT_TMPLAT_BTN_LIST`·`TM_MS_EMAIL_TMPLAT_MNG`). 수백만 행(예 TM_PM_MBRFEE_ACMSLT 46.4M·SND_MEMBER_LIST 8.3M) |
| BRONZE GA4 | ✅ 적재 — `GN_DW.BRONZE_GA4."events_20260501"` **287,025행**(1일 샤드, 소문자 샤드명). **추가 입고 예정 없음 → 이 1일 데이터를 전체로 간주하고 작업**. user_id 채움 12,120=**4.22%**. ※추후 GA4 데이터가 추가 입고되면 GA4 SILVER/GOLD(FGA·DIM_GA_*·IDENTITY) 재적재·재검증 재작업 예정 |
| BRONZE AGENCY | ✅ 3테이블 적재 — DGT 197,686 / REBRDC 2,064 / VIDEO 35,822행 |
| BRONZE ERP | ✅ 적재됨 — `BDGT_ACMSLT_LEDGER` **2,041행**. 컬럼=예산과목(장/관/항/목/세목/세세목)·예산단위**명**·재원 + 월별 편성/추경/조정/집행 금액. **캠페인·매체 연결키 없음**(조직도 코드 아닌 이름) → 결론7(캠페인 ROI 불가) 확정 |
| SILVER 설계 | 완료 (`08_SILVER_테이블DDL_20260714.sql`, GA4 샤드 통합 설계 포함) |
| SILVER 구축(ETL/dbt) | ✅ **적재 완료** — `GN_DW.SILVER` **32테이블**(CRM 22 + GA4 5 + AGENCY 2 + ERP 2 + `IDENTITY_MEMBER_XREF` 1). `CRM_BIZ_TARGET`만 0행(입고 대기) |

---

## GOLD 작업 — 완료(배포·적재)

설계·배포·적재 완료. 잔여 항목만 정리:

1. **✅ ADMIN 분류 확정 — 제외 확정(2026-07-09)**
   - 어드민(앱푸시 A-5·이벤트 조회수 A-6·행사기간/참여경로/채널 A-10)은 **원천 미채택 = ❌제외 확정**. 대행사/별도 여부 논의 종결.
   - 반영 완료: `08_silver의존.md`(§0·§4·§5-A)·`01_작업 계획.md`(P9)·`03_테이블 설계.md`(`_SOURCE_SYSTEM` 태그·의존 컬럼 미채움 주석).

2. **⛔ 사업목표(FTG_B) — `CRM_BIZ_TARGET` 데이터 입고 대기(유일 잔여)**
   - 원천=CRM 신규 목표 테이블 `CRM_BIZ_TARGET`(현업 수동입력)로 확정(2026-07-20). SILVER·GOLD 테이블·적재 로직 완료, 데이터만 0행. 현업 입력분 입고 시 적재.

3. **§5-A 잔여 4건 현업 확인** (정밀화 항목)
   - `DIM_CAMPAIGN.ORG_SK` — 캠페인↔주관조직 연결원천 (활동 vs 실적 부서)
   - `DIM_SERVICE` 발송 대/중/소 코드체계 + SUBTYPE 정의
   - `DIM_EVENT` EVENT_CATEGORY·APPLY_CHANNEL 파생 규칙
   - `DIM_PAYMENT` 회비유형(FEE_TYPE) 정기/일시 이중표현 결정
   → 상세: `08_silver의존.md §5-A`

---

## 다음 스텝 (우선순위 순)

### ✅ 완료 (2026-07-20)
- **SILVER 구축** — `GN_DW.SILVER` 32테이블 적재(CRM 22 + GA4 5 + AGENCY 2 + ERP 2 + `IDENTITY_MEMBER_XREF` 1).
- **GOLD 배포·적재** — `06_DDL.sql` 실행 → 24테이블 + WIDE VIEW 9개 생성, SILVER→GOLD INSERT 완료.
- **WIDE VIEW COMMENT 적용** — `10_WIDE VIEW 코멘트.sql` 실행(배포 후).

### 1. Semantic View 매핑 (현재 핵심 트랙)
- derived 81개 → SV metric 정의
- 입력: `04_SV파생 매핑.md`
- 산출: SV YAML (Cortex Analyst/Agent 연결)

### 2. GOLD 타입 정밀화
- 정본: `99_provided_definition/06_지표용어사전 20260624.md`
- VARCHAR 길이, NUMBER precision → ALTER TABLE 적용

### 3. 사업목표(FTG_B) 데이터 입고
- 현업 `CRM_BIZ_TARGET` 수동입력분 입고 시 SILVER→`FACT_TARGET_BIZ` 적재(현재 0행). 로직은 완비.

### 4. §5-A 잔여 4건 현업 확인 후 DIM 정밀 적재
- `08_silver의존.md §5-A` (DIM_CAMPAIGN.ORG_SK·DIM_SERVICE·DIM_EVENT·DIM_PAYMENT)

### 참고 — GA4 데이터 관련
- GA4 원천은 `events_20260501` 1일 샤드(287,025행)뿐이며 **추가 입고 예정 없음 → 전체로 간주하고 적재·검증 완료**.
- 추후 GA4가 추가 입고되면: `ga4_union_shards` 매크로(명시적 컬럼 30개 나열 유지)·72시간 소급 보정(incremental+merge+D-3~D-1)로 **GA4 SILVER/GOLD 재적재·재검증 재작업** 예정.
- 참고: `04_silver_design/GA4_파이프라인_dbt로 작업전_주의사항.md` + `07_GA4_SILVER_샤드통합 설계결정.md`

---

## 핵심 문서 색인

| 문서 | 위치 | 역할 |
|---|---|---|
| 설계 정본 | `03_top-down_gold/03_테이블 설계.md` | 15 DIM + 9 FACT 스키마·open 항목 |
| GOLD DDL | `03_top-down_gold/06_DDL.sql` | 24테이블 CREATE + FK 35 (**배포·적재 완료** — 2026-07-20 `GN_DW.GOLD` 생성·적재) |
| GOLD 메타 | `03_top-down_gold/07_메타.md` | FK 정책·재실행 규칙·PENDING (인수인계용) |
| SILVER lineage | `03_top-down_gold/08_silver의존.md` | GOLD컬럼→SILVER 전체 매핑·4레이어·§5-A |
| SILVER DDL | `04_silver_design/08_SILVER_테이블DDL_20260714.sql` | 32테이블 CREATE (CRM 22 + GA4 5 + AGENCY 2 + ERP 2 + IDENTITY_MEMBER_XREF 1) |
| GA4 샤드 설계 | `04_silver_design/07_GA4_SILVER_샤드통합 설계결정.md` | SELECT * 수정·GOLD 계약 검증 |
| GA4 dbt 가이드 | `04_silver_design/GA4_파이프라인_dbt로 작업전_주의사항.md` | 매크로·incremental·ERD |
| BRONZE 적재 SQL | `02_GN_DW_building/BRONZE_RAW_load_20260703.sql` | 4파일 COPY INTO 완성본 |
| BRONZE 원천 정의 | `99_provided_definition/BRONZE_CRM 테이블 정보.MD` | 41테이블·컬럼 정본 |

---

## 주의사항

- **적재 전** DDL 전체 재실행은 안전(`CREATE OR REPLACE`)했으나, **적재 완료 후에는 재실행 금지**(아래 주의). **FK 섹션만 따로 재실행 금지**(전체 일괄만).
- GA4 dbt `SELECT *` → 컬럼명 명시로 반드시 교체 (GOLD 계약 오염 방지)
- ⚠️ **GOLD 스키마 배포·적재 완료**(2026-07-20). `06_DDL.sql`은 `CREATE OR REPLACE`라 **재실행 시 적재 데이터 소실** — 배포·적재 후 재실행 금지(필요 시 백업 확보 후 부분 `ALTER`). WIDE VIEW COMMENT는 idempotent(재실행 안전).
