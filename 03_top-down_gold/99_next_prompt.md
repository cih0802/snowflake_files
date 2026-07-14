# GN_DW 다음 스텝 인수인계 (2026-07-03 기준)

---

## 현재 상태 요약

| 영역 | 상태 |
|---|---|
| GOLD 설계 1~8단계 | **완료** (DDL·FK·메타·SILVER lineage 전부 확정) |
| GOLD 스키마 실배포 | ⛔ **미배포** — [2026-07-13 실측] `GN_DW`에 **GOLD·SILVER 스키마 없음**(BRONZE_*·OPS·SECURITY만). DDL 작성 완료이나 실제 CREATE 미실행. 문서 "배포 완료 ✅"는 정정됨 |
| BRONZE CRM | ✅ **전량 적재** — [2026-07-13 실측] `GN_DW.BRONZE_CRM` **43테이블 / 927컬럼**(원천정의 41/876 + 템플릿 2테이블 `TD_MS_AT_TMPLAT_BTN_LIST`·`TM_MS_EMAIL_TMPLAT_MNG`). 수백만 행(예 TM_PM_MBRFEE_ACMSLT 46.4M·SND_MEMBER_LIST 8.3M). ※구 "각 1,000행 샘플"은 폐기 |
| BRONZE GA4 | ✅ 적재 — [2026-07-13 실측] `GN_DW.BRONZE_GA4."events_20260501"` **287,025행**(전체 1일 샤드, 소문자 샤드명). ※"1,000행 표본"은 정정됨. user_id 채움 12,120=**4.22%** |
| BRONZE AGENCY | 🟢 3테이블 적재 — DGT 197,686 / REBRDC 2,064 / VIDEO 35,822행 |
| BRONZE ERP | 🟢 적재됨 — `BDGT_ACMSLT_LEDGER` **2,041행** (문서 "미수령"과 상충). [실측] 컬럼=예산과목(장/관/항/목/세목/세세목)·예산단위**명**·재원 + 월별 편성/추경/조정/집행 금액. **캠페인·매체 연결키 없음**(조직도 코드 아닌 이름) → 결론7(캠페인 ROI 불가) 확정 |
| SILVER 설계 | 완료 (`SILVER_DDL_20260702.sql`, GA4 샤드 통합 설계 포함) |
| SILVER 구축(ETL/dbt) | **미착수** (SILVER 스키마 미생성 실측 확인) |

---

## GOLD 작업 — 중지

설계 완료. 이하 두 가지만 남아 있으며 **현업 회신 대기 또는 SILVER 완료 후 처리**:

1. **✅ ADMIN 분류 확정 — 제외 확정(2026-07-09)**
   - 어드민(앱푸시 A-5·이벤트 조회수 A-6·행사기간/참여경로/채널 A-10)은 **원천 미채택 = ❌제외 확정**. 대행사/별도 여부 논의 종결.
   - 반영 완료: `33_오픈액션…md`(§0·§A), `30_BRONZE 컨트랙트.md`(§4), `08_silver의존.md`(§0·§4·§5-A). 잔여 동기화: `01_작업 계획.md`(P9), `03_테이블 설계.md`(`_SOURCE_SYSTEM` 태그·의존 컬럼 미채움 주석)

2. **§5-A 잔여 4건 현업 확인** (SILVER 구축 전 해소 권장)
   - `DIM_CAMPAIGN.ORG_SK` — 캠페인↔주관조직 연결원천 (활동 vs 실적 부서)
   - `DIM_SERVICE` 발송 대/중/소 코드체계 + SUBTYPE 정의
   - `DIM_EVENT` EVENT_CATEGORY·APPLY_CHANNEL 파생 규칙
   - `DIM_PAYMENT` 회비유형(FEE_TYPE) 정기/일시 이중표현 결정
   → 상세: `08_silver의존.md §5-A`

---

## 다음 스텝 (우선순위 순)

### 1. GA4 BigQuery 전체 적재
- 현재 BRONZE_GA4에는 20260501 샘플만 있음
- BigQuery에서 전체 기간 CSV 내려받아 `@SANDBOX.TOOLS.BRONZE_RAW` 업로드 → COPY INTO
- 적재 방식: `PARSE_HEADER=TRUE` + `MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE` (경로: `@SANDBOX.TOOLS.BRONZE_RAW/파일명.csv`, `bronze_raw/` prefix 없음)
- 참고: `02_GN_DW_building/BRONZE_RAW_load_20260703.sql`

### 2. SILVER 구축 — CRM 21 테이블
- dbt C-2 방식 (커스텀 매크로, 외부 패키지 없음 — trial EAI 불가)
- 참고: `04_silver_design/SILVER_작업계획_BRONZE-GOLD연결 20260630.md`
- 선결: `GN_DW.SILVER` 스키마 생성, `profiles.yml` 확인

### 3. SILVER 구축 — GA4 5 테이블 (dbt incremental)
- `ga4_union_shards` 매크로 `SELECT *` → **명시적 컬럼 30개 나열**로 반드시 수정 (SELECT * 유지 시 GOLD 계약 오염)
- 72시간 GA4 소급 보정: `incremental + merge + D-3~D-1`
- 모델: ① GA4_TRAFFIC_SOURCE ② GA4_EVENT_DIM ③ GA4_DEVICE (table) ④ GA4_EVENT (incremental) ⑤ GA4_IDENTITY (조건부)
- `GA4_IDENTITY`는 CRM 행매칭 실증 완료 전 비활성
- 참고: `04_silver_design/GA4_파이프라인_dbt로 작업전_주의사항.md` + `GA4_SILVER_샤드통합_설계결정.md`

### 4. ERP · 대행사 SILVER — 데이터 입고 대기 (어드민 ❌제외 확정)
- BRONZE frame 완료. 데이터 입고 즉시 SILVER 신설.
- 참고: `08_silver의존.md §4` (미적재 원천·필요 SILVER 테이블 명세)

### 5. (현업 확인 완료 후) gold 폴더 문서 동기화
- `01_작업 계획.md` P9, `03_테이블 설계.md`, `00_README.md` 원천 표기

### 6. SILVER → GOLD INSERT 구현
- `08_silver의존.md §1·§2` lineage 기반으로 FACT·DIM 적재 SQL/dbt 작성
- GOLD 스키마(`GN_DW.GOLD`) 생성 + `06_DDL.sql` 실행 후 진행

### 7. GOLD 타입 정밀화
- 정본: `99_provided_definition/06_지표용어사전 20260624.md`
- VARCHAR 길이, NUMBER precision → ALTER TABLE 적용

### 8. Semantic View 매핑
- derived 81개 → SV metric 정의
- 입력: `04_SV파생 매핑.md`
- 산출: SV YAML (Cortex Analyst/Agent 연결)

---

## 핵심 문서 색인

| 문서 | 위치 | 역할 |
|---|---|---|
| 설계 정본 | `03_top-down_gold/03_테이블 설계.md` | 15 DIM + 9 FACT 스키마·open 항목 |
| GOLD DDL | `03_top-down_gold/06_DDL.sql` | 24테이블 CREATE + FK 35 (**작성·compile 검증 완료, 미배포** — 2026-07-13 실측 GN_DW.GOLD 미생성) |
| GOLD 메타 | `03_top-down_gold/07_메타.md` | FK 정책·재실행 규칙·PENDING (인수인계용) |
| SILVER lineage | `03_top-down_gold/08_silver의존.md` | GOLD컬럼→SILVER 전체 매핑·4레이어·§5-A |
| SILVER DDL | `04_silver_design/SILVER_DDL_20260702.sql` | 26테이블 CREATE |
| GA4 샤드 설계 | `04_silver_design/GA4_SILVER_샤드통합_설계결정.md` | SELECT * 수정·GOLD 계약 검증 |
| GA4 dbt 가이드 | `04_silver_design/GA4_파이프라인_dbt로 작업전_주의사항.md` | 매크로·incremental·ERD |
| BRONZE 적재 SQL | `02_GN_DW_building/BRONZE_RAW_load_20260703.sql` | 4파일 COPY INTO 완성본 |
| BRONZE 원천 정의 | `99_provided_definition/BRONZE_CRM 테이블 정보.MD` | 41테이블·컬럼 정본 |

---

## 주의사항

- DDL 전체 재실행 안전(`CREATE OR REPLACE`). **FK 섹션만 따로 재실행 금지.**
- GA4 dbt `SELECT *` → 컬럼명 명시로 반드시 교체 (GOLD 계약 오염 방지)
- ⚠️ **GOLD 스키마 미배포**(2026-07-13 실측). `06_DDL.sql` 최초 배포 시 `CREATE OR REPLACE`로 안전하나, **적재 이후** 재실행 시 데이터 소실 주의(적재 후 백업 확보).
