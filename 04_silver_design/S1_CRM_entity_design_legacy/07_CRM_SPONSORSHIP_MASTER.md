# S-1 엔티티 설계서 ⑦ `CRM_SPONSORSHIP_MASTER`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_SPONSORSHIP_MASTER` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` + **`컬럼정의서 20260622.csv`(권위 원천)** / 상위: `SILVER_설계_작업 계획.md` §1-1(#7), §0 원칙 4·5·10·11.
> GOLD 수요처: `DIM_SPONSORSHIP`(SCD1, GOLD_차원 설계 §5). 팩트 `FMM`·`FSE`·`FTG-B`가 `SPONSORSHIP_SK` 보유.
> 원천: `TM_CM_SPNSR_BSNS_INFO`(15) — **전 컬럼 정의됨 ✅ (D5 해소, 2026-06-22 정의서)**.

---

## 1. 핵심 — D5 해소 (깔끔한 SCD1 차원) + 캠페인 분리

**D5 차단 해소**: 2026-06-22 정의서로 `TM_CM_SPNSR_BSNS_INFO` 15컬럼이 확정됨 → 후원사업 코드·명·약칭 확보, **즉시 완전 설계 가능**.

- **확정 키 컬럼**: `SPNSR_BSNS_ID`(PK) · `SPNSR_BSNS_NM`(후원사업명) · `SPNSR_BSNS_ABRV_CD`(약칭) · `SPNSR_DIV_CD`(후원구분) · `DNTN_TY_CD`(기부유형).
- **이전 키-only DIM 대안 폐기**(라벨 확보됨).

> ⚠️ 캠페인↔후원사업 관계 불확실(결정 C) → GOLD `DIM_CAMPAIGN`/`DIM_SPONSORSHIP` 분리. 병합 금지.
> ⚠️ **R10 잔존**: 마스터 PK는 `SPNSR_BSNS_ID`이나 개발(③)·결연(⑮)은 `SPNSR_BSNS_NO`(NUMBER) 참조 → **`SPNSR_BSNS_ID` ↔ `SPNSR_BSNS_NO` 관계는 데이터 실측 필요**(OPEN-31).

---

## 2. grain / PK

- **grain**: 1행 / 후원사업.
- **PK**: `SPONSORSHIP_KEY` = `SPNSR_BSNS_ID`. GOLD `DIM_SPONSORSHIP.SPONSORSHIP_BK`(#123)와 동일.
  - PK 유일성 BRONZE 실측(OPEN-53).
- **회원 FK 없음**: 후원사업 마스터.

---

## 3. 컬럼 명세 (`TM_CM_SPNSR_BSNS_INFO`, 2026-06-22 정의서)

> 정제 표준 §0 원칙 11. 코드+라벨 병행(원칙 5, OPEN-3). 타입은 정의서 기준(일부 미기재).

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `SPONSORSHIP_KEY` (PK) | VARCHAR | `SPNSR_BSNS_ID` | 후원사업ID TRIM |
| 2 | `SPONSORSHIP_NM` | VARCHAR | `SPNSR_BSNS_NM` | 후원사업명 TRIM |
| 3 | `SPONSORSHIP_ABBR_CD` | VARCHAR | `SPNSR_BSNS_ABRV_CD` | 약칭코드(라벨 OPEN-3) |
| 4 | `SPONSOR_DIV_CD` | VARCHAR | `SPNSR_DIV_CD` | 후원구분(정기/일시, CM035 추정) |
| 5 | `DONATION_TYPE_CD` | VARCHAR | `DNTN_TY_CD` | 기부유형코드 |
| 6 | `CORP_DIV_CD` | VARCHAR | `CPR_DIV_CD` | 법인구분 CM019 |
| 7 | `SORT_ORDR` | NUMBER | `SORT_ORDR` | 정렬순서 |
| 8 | `USE_YN` | VARCHAR(1) | `USE_YN` | 사용여부(소프트삭제, 필터 금지) |
| 9 | `RM` | VARCHAR | `RM` | 비고(보존 선택) |
| 10 | `FIRST_RGSTR_ID` | VARCHAR | `FRST_RGSTR_ID` | TRIM |
| 11 | `FIRST_REGIST_DT` | TIMESTAMP_NTZ | `FRST_REGIST_DT` | 최초등록일시 |
| 12 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | `LAST_UPDT_DT` | 최종수정일시 |

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`('TM_CM_SPNSR_BSNS_INFO') · `_LOADED_AT` · `_BATCH_ID`
> 원천 `_LOAD_DT`·`_BATCH_ID`(BRONZE 적재 메타)는 SILVER `_LOADED_AT`/`_BATCH_ID`로 대체·계승.

---

## 4. GOLD 정합 (`DIM_SPONSORSHIP`, SCD1)

| GOLD DIM_SPONSORSHIP 컬럼 | 소스# | 본 엔티티 매핑 |
|---|---|---|
| SPONSORSHIP_BK | #123 | `SPONSORSHIP_KEY`(=SPNSR_BSNS_ID) ✅ |
| 후원사업명 | #123 | `SPONSORSHIP_NM` ✅ |
| 후원사업_약칭 | #124 | `SPONSORSHIP_ABBR_CD`(→라벨 OPEN-3) ✅ |

- **분리설계(결정 C)**: 팩트(FMM·FSE 양 SK / FTG-B는 ORG+SPONSORSHIP[+CAMPAIGN])가 `SPONSORSHIP_SK` 보유. FTG-D는 미보유.
- **키 연결**: ⑥(`SPNSR_BSNS_ID`)는 직접 일치. ③·⑮(`SPNSR_BSNS_NO`)는 R10(OPEN-31) 관계 확정 후 조인.

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| ~~D5~~ | ~~SPNSR_BSNS_INFO 컬럼 미정의~~ | — | **✅ 해소(2026-06-22 정의서)** |
| **OPEN-31 (R10)** | 후원사업 키 — 마스터 `SPNSR_BSNS_ID`(PK) ↔ 개발/결연 `SPNSR_BSNS_NO`(NUMBER) 관계 | ③⑥⑮ 조인 정합 | BRONZE 실측(두 키 매핑·1:1 여부) |
| **OPEN-53** | `SPNSR_BSNS_ID` PK 유일성 | PK | BRONZE 실측 |
| **OPEN-32** | 캠페인↔후원사업 카디널리티(결정 C) | 분리차원 검증 | BRONZE 실측 |
| **OPEN-3(공통)** | 라벨(SPNSR_DIV_CD·DNTN_TY_CD·SPNSR_BSNS_ABRV_CD·CPR_DIV_CD) | 라벨 | `CRM_CODE_MASTER`(#14) 후 |

---

## 6. 다음

- **즉시 완전 설계 가능** — D5 해소로 차단 없음. PK·명·약칭 확보.
- **선결(품질)**: OPEN-31(후원사업 키 관계 — ③⑮ 조인) · OPEN-53(PK 유일성).
- **S-2**: `CREATE TABLE GN_DW.SILVER.CRM_SPONSORSHIP_MASTER` DDL.
- **S-3**: `TM_CM_SPNSR_BSNS_INFO`(15) → SILVER 1:1 매핑.
