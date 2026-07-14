# S-1 엔티티 설계서 ⑨ `CRM_DEV_TARGET`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_DEV_TARGET` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` / 상위: `SILVER_설계_작업 계획.md` §1-1(#9), §0 원칙 4·5·10·11.
> GOLD 수요처: `FACT_TARGET_DEV`(FTG-D, GOLD_팩트 설계 §2-D). 파생 #1~3(목표대비개발율)의 분모.
> 원천: `TM_CM_MBER_DVLP_GOAL`(9) — 전 컬럼 정의 ✅, CRM 수령·확정(결정 9).

---

## 1. 핵심 — FACT 소스 (DIM 아님), 소스 grain = FTG-D grain

본 엔티티는 **회원개발목표**로, GOLD `FTG-D`(FACT)에 1:1 공급한다. FTG-D grain = **(조회년월 × 조직 × 개발구분)**이 곧 원천 1행과 동일 → SILVER는 raw 그대로 보존(집계 불필요, 원칙 4).

- **conform**: `DEV_TYPE`(개발구분 MM015)은 FMM `#121 DEV_TYPE`과 conform → #1~3 목표대비개발율 비교축. `ORG`·`MONTH_KEY`는 FMM·FTG-B와 conformed.
- **후원사업 축 없음**: CRM goal 테이블에 후원사업·연사업/추경 축 부재(개발구분 보유) → FTG-D는 `SPONSORSHIP_SK` 미보유(degenerate 개발구분). FTG-B(ERP)와 별도 팩트(결정 9).

---

## 2. grain / PK

- **grain**: 1행 / (기준연 × 기준월 × 개발구분 × 부서). 원천 1행과 1:1.
- **PK**: `TARGET_KEY` = `MONTH_KEY || '-' || DEV_TYPE_CD || '-' || ORG_KEY`. GOLD FTG-D PK (MONTH_KEY, ORG_SK, DEV_TYPE)와 정합.
  - PK 유일성(연·월·개발구분·부서 중복 0건) BRONZE 실측(OPEN-35).
- **조직 FK**: `ORG_KEY` = `DEPT_ID`(#4) → `CRM_ORG_MASTER`(⑧) 참조. 회원 비종속.

---

## 3. 컬럼 명세 (`TM_CM_MBER_DVLP_GOAL`)

> 정제 표준 §0 원칙 11. 타입 캐스팅 잠정(OPEN-5). 코드+라벨 병행(원칙 5, OPEN-3).

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `TARGET_KEY` (PK) | VARCHAR | 파생 | `MONTH_KEY-DEV_TYPE_CD-ORG_KEY` |
| 2 | `MONTH_KEY` | NUMBER(6) | `STDYY`(#1)+`STDR_MT`(#2) | `STDYY*100 + STDR_MT` → YYYYMM. STDR_MT zero-pad(OPEN-35) |
| 3 | `STD_YEAR` | NUMBER(4) | `STDYY`(#1) | 기준연 |
| 4 | `STD_MONTH` | NUMBER(2) | `STDR_MT`(#2) | 기준월 |
| 5 | `DEV_TYPE_CD` | VARCHAR | `MBER_DVLP_DIV_CD`(#3, MM015) | 개발구분 → GOLD DEV_TYPE(FMM #121 conform) |
| 6 | `ORG_KEY` (FK) | VARCHAR | `DEPT_ID`(#4) | 부서 → ⑧ CRM_ORG_MASTER |
| 7 | `GOAL_CNT` | NUMBER | `GOAL_CNT`(#5) | 개발목표수(measure, 원단위 보존) |
| 8 | `FIRST_RGSTR_ID` | VARCHAR | `FRST_RGSTR_ID`(#6) | TRIM |
| 9 | `FIRST_REGIST_DT` | TIMESTAMP_NTZ | `FRST_REGIST_DT`(#7) | 최초등록일시 |
| 10 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | `LAST_UPDT_DT`(#9) | 최종수정일시 |

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`('TM_CM_MBER_DVLP_GOAL') · `_LOADED_AT` · `_BATCH_ID`

---

## 4. GOLD 정합 (`FACT_TARGET_DEV`, FTG-D)

| GOLD FTG-D 요소 | 소스 | 본 엔티티 매핑 |
|---|---|---|
| MONTH_KEY (PK) | STDYY+STDR_MT | `MONTH_KEY` ✅ |
| ORG_SK (PK) | DEPT_ID | `ORG_KEY` → ⑧ ✅ |
| DEV_TYPE (PK, degenerate) | MBER_DVLP_DIV_CD(MM015) | `DEV_TYPE_CD` ✅ (FMM #121 conform) |
| GOAL_CNT (measure, base) | GOAL_CNT | `GOAL_CNT` ✅ |

- **가산성**: 월 grain → 월·조직·개발구분 SUM 가능. 연 누계 = 월 SUM(가산 A).
- **#1~3 목표대비개발율**: GOLD 4단계에서 FMM 개발건 ÷ FTG-D `GOAL_CNT`를 (MONTH_KEY·ORG·DEV_TYPE) conformed 조인으로 SV metric화. 본 엔티티가 분모 제공.
- **FTG-B(ERP)와 분리**: 별도 팩트(grain·소스·conform 상이, 결정 9). 직접 합산 금지(차원 정렬만).

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| **OPEN-35** | `STDR_MT` 형식(1~12 vs 01~12)·MONTH_KEY YYYYMM 생성 + PK 유일성(연·월·개발구분·부서 중복) | MONTH_KEY·PK | BRONZE 실측(`LPAD(STDR_MT,2,'0')` 필요 여부, 중복 카운트) |
| **OPEN-5(공통)** | BRONZE 물리타입 미제공 | 캐스팅 잠정 | S-2 전 실제 타입 확인 |
| **OPEN-3(공통)** | 개발구분 라벨(MM015) | 라벨 컬럼 | `CRM_CODE_MASTER`(#14) 후. FMM #121과 동일 코드 |

---

## 6. 다음

- **즉시 완전 설계 가능** — 원천 전 컬럼 정의·CRM 수령 확정. 차단 없음.
- **S-2**: `CREATE TABLE GN_DW.SILVER.CRM_DEV_TARGET` DDL.
- **S-3**: `TM_CM_MBER_DVLP_GOAL`(9) → SILVER 1:1 매핑(MONTH_KEY 파생 규칙 명시).
