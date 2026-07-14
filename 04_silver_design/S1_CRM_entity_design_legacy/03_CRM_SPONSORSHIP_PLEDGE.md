# S-1 엔티티 설계서 ③ `CRM_SPONSORSHIP_PLEDGE`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_SPONSORSHIP_PLEDGE` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` / 상위: `SILVER_설계_작업 계획.md` §1-1(#3), §0 원칙 4·10·11, **R7(약정 3중 grain)**.
> GOLD 수요처: `FMM`(개발·중단·감액·증액 measure), `DIM_MEMBER`, (간접)`DIM_SPONSORSHIP`.

---

## 1. R7 핵심 — 3원천 grain 분석 (단순 병합 불가)

| 원천 | 컬럼 | 자연키(추정) | grain | 성격 |
|---|---|---|---|---|
| `TM_MM_FDRM_MBER_DVLP_AMT` | 20 | `SPNSR_NO`+`OCCRRNC_DE`+`SER_NO` | **1행/개발실적 발생건** | 이벤트(발생일별 개발·중단·증감액 금액) |
| `TM_MM_FDRM_MBER_SPNSR_BSNS` | 7 | `SPNSR_NO`+`SPNSR_BSNS_NO` | 1행/후원-사업 매핑 | 후원↔사업 관계 |
| `TM_RM_RELATNSP_MSTR_INFO` | 11 | `RELATNSP_KEY` | 1행/결연(아동)건 | 결연 lifecycle(시작·중단·아동) |

> 세 grain이 **서로 다름**. 1 후원(`SPNSR_NO`) : N 개발실적, : N 사업, : N 결연(아동). 단순 JOIN 시 **카디널리티 폭발**(R7 위험 실재).

### 1-1. R7 해소 결정 (분리)
GOLD 수요처가 **FMM measure(개발·중단·감액·증액 금액)**임에 주목 → 그 소스는 `DVLP_AMT`(금액·개발구분·취소감액사유 보유)다. 따라서:

- **`CRM_SPONSORSHIP_PLEDGE` 스파인 = `DVLP_AMT`** (개발실적 이벤트 grain). FMM의 직접 소스.
- `SPNSR_BSNS`(7) → `(SPNSR_NO, SPNSR_BSNS_NO)` 기준 **속성 JOIN**(1:1 검증 시, 사업·중단 속성 보강).
- `RELATNSP_MSTR_INFO`(11, 결연/아동) → grain이 다르고 GOLD `DIM_SPONSORSHIP`/결연 lifecycle 용도 → **별도 엔티티 `CRM_SPONSORSHIP_RELATION`으로 분리** 권고(작업계획 R7 조치 "약정/결연 분리").

> ⚠️ 이는 작업계획 §1-1이 3원천을 단일 `CRM_SPONSORSHIP_PLEDGE`로 묶은 것과 **부분 상이** → §6 OPEN-11 + 작업계획 정합 정정 필요.

---

## 2. grain / PK (스파인 = DVLP_AMT)

- **grain**: 1행 / 개발실적 발생건.
- **PK**: `PLEDGE_KEY` = `SPNSR_NO || '-' || OCCRRNC_DE || '-' || SER_NO` (동일 후원·동일자 다건 구분).
  - SER_NO 단독 유일성·`OCCRRNC_DE` 입도(일/시) 확인 필요(OPEN-12).
- **회원 FK**: `MEMBER_KEY = 'FDRM-' || MBER_NO` → `CRM_MEMBER_MASTER` 참조(엔티티① 정합).

---

## 3. 컬럼 명세 (DVLP_AMT 스파인 + SPNSR_BSNS 속성)

> 타입 캐스팅 잠정(OPEN-5 공통). 코드 컬럼 `*_CD` + `*_NM` 라벨 병행(원칙 5, OPEN-3).

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `PLEDGE_KEY` (PK) | VARCHAR | 파생 | `SPNSR_NO-OCCRRNC_DE-SER_NO` |
| 2 | `MEMBER_KEY` (FK) | VARCHAR | 파생 | `'FDRM-'||MBER_NO` |
| 3 | `SPNSR_NO` | NUMBER | `SPNSR_NO` | 후원번호 |
| 4 | `SPNSR_BSNS_NO` | NUMBER | `SPNSR_BSNS_NO` | 후원사업번호 |
| 5 | `SPNSR_BSNS_ID` | VARCHAR | `SPNSR_BSNS_ID` | 후원사업ID |
| 6 | `OCCUR_DE` | DATE | `OCCRRNC_DE` | YYYYMMDD→DATE |
| 7 | `EVENT_SEQ` | NUMBER | `SER_NO` | 일련번호 |
| 8 | `DEVELOP_DIV_CD` | VARCHAR | `DVLP_DIV_CD` | 개발구분 MM015 (개발/중단/증액/감액 구분) |
| 9 | `SPNSR_AMT` | NUMBER | `SPNSR_AMT` | 후원금액(원 단위 보존, 원칙 11) |
| 10 | `SPNSR_AMT_CD` | VARCHAR | `SPNSR_AMT_CD` | 후원금액코드 CM012 |
| 11 | `SPNSR_TIME_CO` | NUMBER | `SPNSR_TIME_CO` | 후원시간수 |
| 12 | `CANCEL_REDUCE_RSN_CD` | VARCHAR | `CANCL_RDCAMT_RSN_CD` | 취소감액사유 MM002 |
| 13 | `CAMPAIGN_CD` | VARCHAR | `CMPGN_CD` | 캠페인(DIM_CAMPAIGN FK) |
| 14 | `ACT_DEPT_CD` | VARCHAR | `ACT_DEPT_CD` | 활동부서 |
| 15 | `ACMSLT_DEPT_CD` | VARCHAR | `ACMSLT_DEPT_CD` | 실적부서 |
| 16 | `AREA_CD` | VARCHAR | `AREA_CD` | 지역 CM018 |
| 17 | `MEMBER_DIV_CD` | VARCHAR | `MBER_DIV_CD` | 회원구분 MM018(이벤트시점 스냅샷) |
| 18 | `FIRST_RGSTR_ID` | VARCHAR | `FRST_RGSTR_ID` | TRIM |
| — | *(SPNSR_BSNS JOIN, 1:1 검증 후)* | | | |
| 19 | `BSNS_SPNSR_AMT` | NUMBER | `SPNSR_BSNS.SPNSR_AMT` | 사업기준 후원금액 |
| 20 | `BSNS_STOP_DE` | DATE | `SPNSR_BSNS.SPNSR_DSCNTC_DE` | 사업 후원중단일 |
| 21 | `BSNS_STOP_YN` | VARCHAR(1) | `SPNSR_BSNS.SPNSR_DSCNTC_YN` | Y=중단/N=후원중 |
| 22 | `BSNS_STOP_RSN_CD` | VARCHAR | `SPNSR_BSNS.SPNSR_DSCNTC_RSN_CD` | 사업취소사유 MM002 |

> `SEX`·`AGE`(DVLP_AMT 내 인구통계)는 이벤트 시점 스냅샷 — 마스터와 중복·신뢰도 낮음(SEX 단독 불가, 마스터 §4 동일) → GOLD 비요구 시 보존 선택. PII 아님.

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE` · `_LOADED_AT` · `_BATCH_ID`

---

## 4. 분리 엔티티 권고 — `CRM_SPONSORSHIP_RELATION` (결연)

`TM_RM_RELATNSP_MSTR_INFO`(11)는 별도 엔티티로 분리(R7):
- **grain**: 1행/결연(`RELATNSP_KEY`).
- 주요 컬럼: `RELATNSP_KEY`(PK)·`SPNSR_NO`·`SPNSR_BSNS_NO`·`CHILD_CD`(아동코드, →`TM_RM_CHILD_MSTR_INFO`)·`RELATNSP_STRT_DE`·`RELATNSP_DSCNTC_DE`·`RELATNSP_DSCNTC_YN`(0=후원중/1=중단)·`RELATNSP_DSCNTC_RSN_CD`(MM002)·`MBER_NO`(→MEMBER_KEY).
- GOLD: `DIM_SPONSORSHIP`/결연 lifecycle. 별도 엔티티(CRM 15개째)로 분리(A안 채택: CRM_SPONSORSHIP_RELATION으로 분리 확정).

> ⚠️ 아동코드(`CHILD_CD`) → `TM_RM_CHILD_MSTR_INFO`는 작업계획 §1-1 "BRONZE 미포함 3(아동)"에 해당 — 결연-아동 라벨 조인은 아동마스터 미설계로 제한(코드만 보존).

---

## 5. GOLD 정합

- `FMM`(개발·중단·감액·증액): `DEVELOP_DIV_CD`로 measure 분기, `SPNSR_AMT` 금액. 본 엔티티(PLEDGE)가 직접 소스.
- `DIM_MEMBER`: `MEMBER_KEY` FK.
- `DIM_CAMPAIGN`: `CAMPAIGN_CD` FK.
- `DIM_SPONSORSHIP`: 분리 엔티티 `CRM_SPONSORSHIP_RELATION` 경유(§4).

---

## 6. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| **R7(해소방향)** | 3중 grain 병합 | 카디널리티 폭발 | 본 §1-1: DVLP_AMT 스파인 + SPNSR_BSNS 1:1 JOIN + RELATNSP **분리**로 해소 |
| **OPEN-11** | 작업계획 §1-1은 3원천을 단일 PLEDGE로 표기 vs 본 설계 분리(PLEDGE/RELATION) | (해소됨) | **A안 채택: 결연 분리 → CRM 15개. 작업계획 §1-1(#15)·통합트리·수치요약 25개 반영 완료** |
| **OPEN-12** | `SPNSR_BSNS` ↔ DVLP_AMT 1:1 여부 / `OCCRRNC_DE` 입도 / SER_NO 유일성 | JOIN 카디널리티·PK | BRONZE 실측(중복·관계 카운트) |
| **OPEN-5(공통)** | BRONZE 물리타입 미제공 | 캐스팅 잠정 | S-2 전 실제 타입 확인 |
| **OPEN-3(공통)** | 코드→라벨 병행(MM015/CM012/MM002/CM018…) | 라벨 컬럼 | `CRM_CODE_MASTER`(#14) 후 일괄 |

---

## 7. 다음

- **즉시 설계 가능**(3원천 모두 컬럼 정의됨 — 마스터/상태이력과 달리 차단 적음).
- **선결**: OPEN-11(작업계획 분리 정정)·OPEN-12(grain 실측)이 S-2 전 확인 대상.
- **S-2**: `CRM_SPONSORSHIP_PLEDGE` + (분리 시) `CRM_SPONSORSHIP_RELATION` DDL.
- **S-3**: DVLP_AMT(20)+SPNSR_BSNS(7) → PLEDGE, RELATNSP(11) → RELATION 매핑.
