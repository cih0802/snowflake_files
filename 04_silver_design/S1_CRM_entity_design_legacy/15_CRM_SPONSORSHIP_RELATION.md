# S-1 엔티티 설계서 ⑮ `CRM_SPONSORSHIP_RELATION`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_SPONSORSHIP_RELATION` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` + **`컬럼정의서 20260622.csv`(권위 원천)** / 상위: `SILVER_설계_작업 계획.md` §1-1(#15), §0 원칙 4·5·10·11, **R7**.
> GOLD 수요처: 결연 lifecycle(시작·중단), `DIM_SPONSORSHIP`(후원사업 경유). 간접: `FMM` 중단·`FSE`(서신/선물금 회원해소 ⑬).
> 원천: `TM_RM_RELATNSP_MSTR_INFO`(13) — **전 컬럼 정의됨 ✅ (OPEN-51 해소, 2026-06-22 정의서)**.

---

## 1. 핵심 — R7 분리 엔티티 (OPEN-51 해소)

본 엔티티는 R7(약정 3중 grain) 해소로 `CRM_SPONSORSHIP_PLEDGE`(③)에서 **분리된 결연(아동 후원) 마스터**(A안, CRM 14→15). 2026-06-22 정의서로 13컬럼 확정(인벤토리 절단 해소).

- **grain 분리 근거**: ③(DVLP_AMT 개발실적) vs ⑮(RELATNSP_KEY 결연 lifecycle) — 키 상이(R7).
- **⑬ 의존처**: `CRM_PARTICIPATION_HIST`(⑬) 서신/선물금이 `RELATNSP_KEY`로 본 엔티티 경유해 `MBER_NO` 해소.
- **아동 링크**: `CHILD_CD`(NUMBER) → `TM_RM_CHILD_MSTR_INFO`(BRONZE 미포함 3, 미설계) → 코드만 보존.

---

## 2. grain / PK

- **grain**: 1행 / 결연(아동 후원)건.
- **PK**: `RELATION_KEY` = `RELATNSP_KEY`(NUMBER). ⑬·⑪(우편)의 `RELATNSP_KEY` 참조 대상.
  - PK 유일성 BRONZE 실측(OPEN-54).
- **회원 FK**: `MEMBER_KEY` = `'FDRM-' || MBER_NO`(TEXT) → ① 정합.
- **후원사업 FK**: `SPNSR_BSNS_NO`(NUMBER) → ⑦ `CRM_SPONSORSHIP_MASTER`. ⚠️ **R10/OPEN-31**: ⑦ PK는 `SPNSR_BSNS_ID` → `_NO`↔`_ID` 관계 실측 필요.
- **후원번호**: `SPNSR_NO`(TEXT) → ③ 정합(동일 후원).

---

## 3. 컬럼 명세 (`TM_RM_RELATNSP_MSTR_INFO`, 2026-06-22 정의서)

> 정제 표준 §0 원칙 11. 타입은 정의서 기준.

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `RELATION_KEY` (PK) | NUMBER | `RELATNSP_KEY` | 결연KEY |
| 2 | `MEMBER_KEY` (FK) | VARCHAR | 파생 | `'FDRM-'||MBER_NO` → ① |
| 3 | `SOURCE_MEMBER_NO` | VARCHAR | `MBER_NO`(TEXT) | 회원번호 |
| 4 | `SPNSR_NO` | VARCHAR | `SPNSR_NO`(TEXT) | 후원번호(→③ 정합) |
| 5 | `SPNSR_BSNS_NO` (FK) | NUMBER | `SPNSR_BSNS_NO` | 후원사업(→⑦, ⚠️OPEN-31) |
| 6 | `CHILD_CD` | NUMBER | `CHILD_CD` | 아동코드(라벨 조인 불가, 코드 보존) |
| 7 | `RELATION_START_DE` | DATE | `RELATNSP_STRT_DE` | 결연시작일 →DATE |
| 8 | `RELATION_STOP_DE` | DATE | `RELATNSP_DSCNTC_DE` | 결연중단일 |
| 9 | `RELATION_STOP_YN` | VARCHAR(1) | `RELATNSP_DSCNTC_YN` | 0=후원중/1=중단 |
| 10 | `RELATION_STOP_RSN_CD` | VARCHAR | `RELATNSP_DSCNTC_RSN_CD` (MM002) | 중단사유(→⑭ 라벨) |
| 11 | `FIRST_RGSTR_ID` | VARCHAR | `FRST_RGSTR_ID` | TRIM |
| 12 | `FIRST_REGIST_DE` | DATE | `FRST_REGIST_DE` | 최초등록일 |

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`('TM_RM_RELATNSP_MSTR_INFO') · `_LOADED_AT` · `_BATCH_ID`(원천 `_LOAD_DT`/`_BATCH_ID` 계승)
> 정의서상 `LAST_UPDT_DT` 없음 — 변경시점은 `FRST_REGIST_DE`만(결연 갱신 추적 한계).

---

## 4. GOLD 정합

- **결연 lifecycle**: `RELATION_START_DE`·`RELATION_STOP_DE`·`RELATION_STOP_YN`(0/1)·중단사유(MM002) → 결연 시작/중단 분석. FMM 중단 measure 보강.
- **DIM_SPONSORSHIP**: 본 엔티티는 결연(member-child), DIM_SPONSORSHIP는 후원사업(⑦) → `SPNSR_BSNS_NO`로 ⑦에 링크(R10 후).
- **아동 차원**: `CHILD_CD` 보존, `TM_RM_CHILD_MSTR_INFO` 미설계 → 향후 DIM_CHILD 확장.
- **⑬ 회원해소**: 서신/선물금(⑬) `RELATNSP_KEY` → 본 PK → `MEMBER_KEY`.

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| ~~OPEN-51~~ | ~~RELATNSP_MSTR 인벤토리 절단~~ | — | **✅ 해소(2026-06-22 정의서, 13컬럼)** |
| **OPEN-31 (R10)** | `SPNSR_BSNS_NO`(NUMBER, 본 엔티티) ↔ ⑦ `SPNSR_BSNS_ID` 관계 | 후원사업 조인 | ⑦ OPEN-31(키 매핑 실측) |
| **OPEN-54** | `RELATNSP_KEY` PK 유일성 | PK | BRONZE 실측 |
| **OPEN-52** | 아동마스터 미설계 → `CHILD_CD` 라벨 불가 | 아동 차원 제한 | 현재 GOLD 미참조(코드 보존) |
| **OPEN-3(공통)** | 중단사유 라벨(MM002) | 라벨 | `CRM_CODE_MASTER`(#14) 후 |

---

## 6. 다음

- **즉시 완전 설계 가능** — OPEN-51 해소. 후원사업 키(OPEN-31)는 조인용 실측.
- **⑬ 선행 의존**: 본 엔티티가 ⑬ LETTER/GIFT 회원해소 전제 → 우선 적재 권고.
- **S-2**: `CREATE TABLE GN_DW.SILVER.CRM_SPONSORSHIP_RELATION` DDL.
- **S-3**: `TM_RM_RELATNSP_MSTR_INFO`(13) → SILVER 1:1 매핑.
