# S-1 엔티티 설계서 ⑭ `CRM_CODE_MASTER`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_CODE_MASTER` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` / 상위: `SILVER_설계_작업 계획.md` §1-1(#14), §0 원칙 5·10·11.
> GOLD 수요처: `DIM_REASON`(사유코드 MM002·MM005 등) + **전 엔티티 코드→라벨 병행(OPEN-3 일괄 해소처)**.
> 원천: `TC_CMMN_CD`(10, 코드그룹) + `TC_CMMN_DTL_CD`(15, 코드값) — 전 컬럼 정의 ✅.

---

## 1. 핵심 — 코드→라벨 단일 해소처 (전 엔티티 OPEN-3)

본 엔티티는 CRM 공통코드 마스터로, **①~⑮ 전 엔티티의 `*_CD` 컬럼 라벨(`*_NM`)을 해소**하는 단일 lookup(원칙 5). `TC_CMMN_CD`(그룹) 1:N `TC_CMMN_DTL_CD`(값) 구조.

- **OPEN-3 일괄 해소**: 각 엔티티가 미룬 코드 라벨(MM002·MM005·MM010·MM015·MM018·CM009·CM013·CM019·PM003·PM004·PM050·PM052·MS281 등)을 본 마스터로 조인.
- **DIM_REASON**: `CD_ID IN ('MM002'(미납사유)·'MM005'(중단사유)…)` 부분집합 → GOLD가 필터(원칙 4, SILVER는 전 코드 보존).
- 깔끔한 ✅ 엔티티(차단 없음).

---

## 2. grain / PK

- **grain**: 1행 / 코드그룹(`CD_ID`) × 코드값(`DTL_CD_ID`).
- **PK**: `CODE_KEY` = `CD_ID || '-' || DTL_CD_ID`.
  - PK 유일성 BRONZE 실측(OPEN-46).
- **자기참조**: `UPPER_CD_ID`(DTL #15) → 코드 계층(상위 코드값).
- **그룹 속성**: `TC_CMMN_CD`(그룹명 `CD_NM`)를 `CD_ID`로 JOIN(N:1, denormalize).

---

## 3. 컬럼 명세 (`TC_CMMN_DTL_CD` 본체 + `TC_CMMN_CD` 그룹 JOIN)

> 정제 표준 §0 원칙 11. 타입 캐스팅 잠정(OPEN-5).

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `CODE_KEY` (PK) | VARCHAR | 파생 | `CD_ID-DTL_CD_ID` |
| 2 | `CODE_GROUP_ID` | VARCHAR | `DTL.CD_ID`(#1) | 코드그룹ID(예: MM002) |
| 3 | `CODE_GROUP_NM` | VARCHAR | `CMMN_CD.CD_NM`(#2) | 코드그룹명(JOIN, N:1) |
| 4 | `CODE_VALUE` | VARCHAR | `DTL_CD_ID`(#2) | 상세코드값 |
| 5 | `CODE_NM` | VARCHAR | `DTL_CD_NM`(#3) | 상세코드명(라벨) |
| 6 | `CODE_DC` | VARCHAR | `DTL_CD_DC`(#4) | 상세코드설명 |
| 7 | `UPPER_CODE_VALUE` | VARCHAR | `UPPER_CD_ID`(#15) | 상위코드값(계층) |
| 8 | `CODE_ATRB1` | VARCHAR | `CD_ATRB1`(#8) | 코드속성1(보존) |
| 9 | `CODE_ATRB2` | VARCHAR | `CD_ATRB2`(#9) | 코드속성2 |
| 10 | `CODE_ATRB3` | VARCHAR | `CD_ATRB3`(#10) | 코드속성3 |
| 11 | `SORT_ORDR` | NUMBER | `DTL.SORT_ORDR`(#5) | 정렬순서 |
| 12 | `USE_YN` | VARCHAR(1) | `DTL.USE_YN`(#7) | 사용여부(필터 금지) |
| 13 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | `DTL.LAST_UPDT_DT`(#14) | 최종수정일시 |

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`('TC_CMMN_DTL_CD'/'TC_CMMN_CD') · `_LOADED_AT` · `_BATCH_ID`

---

## 4. GOLD 정합

- **DIM_REASON**: `CODE_GROUP_ID IN (미납·중단 사유그룹)` 부분집합. grain 1/사유코드. GOLD가 필터·SK 부여.
- **전 엔티티 라벨 조인**: GOLD/SILVER 정제 시 `{엔티티}.{*_CD}` = `CRM_CODE_MASTER.CODE_VALUE` (동일 `CODE_GROUP_ID` 조건) → `CODE_NM` 라벨. 각 엔티티 `*_NM` 컬럼은 본 마스터 조인으로 채움(원칙 5).
- **코드그룹 매핑 확인**: 각 엔티티 코드그룹ID(MM/CM/PM/MS 접두)가 `CD_ID`와 정확히 일치하는지 OPEN-47.

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| **OPEN-46** | `CD_ID`+`DTL_CD_ID` PK 유일성 | PK | BRONZE 실측 |
| **OPEN-47** | 엔티티 코드그룹ID ↔ `CD_ID` 일치(MM002 등 그룹 존재) | 라벨 조인 정합 | BRONZE 실측(전 코드그룹 커버 확인) |
| **OPEN-5(공통)** | 물리타입 미제공 | 캐스팅 잠정 | S-2 전 확인 |

---

## 6. 다음

- **즉시 완전 설계 가능** — 원천 정의됨, 차단 없음. **①~⑮의 OPEN-3 라벨 해소가 본 엔티티에 의존** → 우선 적재 권고.
- **S-2**: `CREATE TABLE GN_DW.SILVER.CRM_CODE_MASTER` DDL.
- **S-3**: `TC_CMMN_DTL_CD`+`TC_CMMN_CD` → SILVER 매핑. 전 엔티티 라벨 조인 패턴 명시.
