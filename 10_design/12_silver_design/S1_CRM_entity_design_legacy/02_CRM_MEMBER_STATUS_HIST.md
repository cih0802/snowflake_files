# S-1 엔티티 설계서 ② `CRM_MEMBER_STATUS_HIST`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_MEMBER_STATUS_HIST` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` + **`컬럼정의서 20260622.csv`(권위 원천)** / 상위: `SILVER_설계_작업 계획.md` §1-1(#2), §0 원칙 4·6·10·11, D10·R6.
> GOLD 수요처: `DIM_MEMBER`(SCD2: STATUS), `FMM`(상태변경 measure·월말 시점지표).
> 원천: `TH_MM_FDRM_MBER_STNG_DTLS`(8) · `TM_MM_FDRM_MBER_SPNSR_DSCNTC`(9) · `TM_MM_FDRM_MBER_RE_SPNSR`(7) — **전 컬럼 정의됨 ✅ (D2 해소)**.

---

## 1. 핵심 — D2 해소 (STATUS_CHG 완전 설계 가능)

**D2/R1 차단 해소**: 2026-06-22 정의서로 `TH_MM_FDRM_MBER_STNG_DTLS` 컬럼이 확정됨 → 회원상태 변경이력 본체가 열렸다.

- **STNG_DTLS 실컬럼**: `MBER_NO`·`SER_NO`·**`BF_STAT_CD`(이전상태)**·**`CHN_STAT_CD`(변경후상태)**·`FRST_RGSTR_ID`·`FRST_REGIST_DT`(변경시점).
- **R1 시점지표 소스 확보**: 월말 회원상태(활동/미납1~5/중단)는 STATUS_CHG 타임라인(`CHN_STAT_CD` + `FRST_REGIST_DT`)으로 시점 확정 가능 → **FMM 시점지표 #49·50·52·53 차단 해제**.
- **OPEN-7 해소**: 세 원천 모두 `SER_NO`(일련번호) 보유 → EVENT_KEY 유일성 확보.

### 1-1. 3종 이벤트 UNION ALL (작업계획 §2 통합트리 회원계)

| EVENT_TYPE | 원천 | 키/시점 | 상태 |
|---|---|---|---|
| `STATUS_CHG` | `TH_MM_FDRM_MBER_STNG_DTLS`(8) | SER_NO / FRST_REGIST_DT | ✅ D2 해소 |
| `SPONSOR_STOP` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC`(9) | SER_NO / SPNSR_DSCNTC_DE | ✅ |
| `RE_SPONSOR` | `TM_MM_FDRM_MBER_RE_SPNSR`(7) | SER_NO / RE_SPNSR_DE | ✅ |

> 세 원천 모두 `FDRM`(정기) 전용 → 일시회원(ONCE) 상태이력 없음 → `MEMBER_TYPE='FDRM'`만.

---

## 2. grain / PK

- **grain**: 1행 / 회원 상태변경 이벤트 1건(회원당 N행).
- **PK**: `EVENT_KEY` = `MEMBER_KEY || '-' || EVENT_TYPE || '-' || EVENT_DE || '-' || EVENT_SEQ`.
  - `EVENT_SEQ` = `SER_NO`(3원천 공통) → 동일자 다건 구분. 유일성 BRONZE 실측(OPEN-8).
- **회원 FK**: `MEMBER_KEY` = `'FDRM-' || MBER_NO` → ① 참조.

---

## 3. 컬럼 명세 (UNION ALL 표준)

> 정제 표준 §0 원칙 11. 한쪽 전용 컬럼은 타 이벤트 NULL 패딩(원칙 4).

| # | SILVER 컬럼 | 타입 | STATUS_CHG | SPONSOR_STOP | RE_SPONSOR | 정제 |
|--:|---|---|---|---|---|---|
| 1 | `EVENT_KEY` (PK) | VARCHAR | 파생 | 파생 | 파생 | `MEMBER_KEY-EVENT_TYPE-EVENT_DE-EVENT_SEQ` |
| 2 | `MEMBER_KEY` (FK) | VARCHAR | `'FDRM-'||MBER_NO` | 동 | 동 | → ① |
| 3 | `SOURCE_MEMBER_NO` | VARCHAR | `MBER_NO` | `MBER_NO` | `MBER_NO` | 회원번호 |
| 4 | `MEMBER_TYPE` | VARCHAR | 'FDRM' | 'FDRM' | 'FDRM' | 리터럴 |
| 5 | `EVENT_TYPE` | VARCHAR | 'STATUS_CHG' | 'SPONSOR_STOP' | 'RE_SPONSOR' | 리터럴 |
| 6 | `EVENT_DT` | TIMESTAMP_NTZ | `FRST_REGIST_DT` | `SPNSR_DSCNTC_DE` | `RE_SPNSR_DE` | 변경/중단/재후원 시점 |
| 7 | `EVENT_SEQ` | NUMBER | `SER_NO` | `SER_NO` | `SER_NO` | 동일자 다건 정렬 |
| 8 | `STATUS_CD` | VARCHAR | `CHN_STAT_CD` | NULL | NULL | **변경후 상태**(MM010 추정 OPEN-7b) |
| 9 | `BF_STATUS_CD` | VARCHAR | `BF_STAT_CD` | NULL | NULL | **변경전 상태**(전이 추적) |
| 10 | `REASON_CD` | VARCHAR | NULL | `DSCNTC_RSN_CD`(MM005) | NULL | 중단사유 |
| 11 | `STOP_PATH_CD` | VARCHAR | NULL | `DSCNTC_PATH`(MM287) | NULL | 중단경로 |
| 12 | `REGIST_DEPT_CD` | VARCHAR | NULL | `REGIST_DEPT_CD` | `REGIST_DEPT_CD` | 등록부서 |
| 13 | `FIRST_RGSTR_ID` | VARCHAR | `FRST_RGSTR_ID` | `FRST_RGSTR_ID` | `FRST_RGSTR_ID` | TRIM |
| 14 | `EFFECTIVE_FROM` | TIMESTAMP_NTZ | 파생 | 파생 | 파생 | = `EVENT_DT` |
| 15 | `EFFECTIVE_TO` | TIMESTAMP_NTZ | 파생 | 파생 | 파생 | `LEAD(EFFECTIVE_FROM) OVER (PARTITION BY MEMBER_KEY ORDER BY EVENT_DT, EVENT_SEQ)` |
| 16 | `IS_CURRENT` | BOOLEAN | 파생 | 파생 | 파생 | `EFFECTIVE_TO IS NULL` |

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`(3원천 행별) · `_LOADED_AT` · `_BATCH_ID`(원천 `_LOAD_DT`/`_BATCH_ID` 계승)

> **계층 책임(OPEN-10)**: `EFFECTIVE_FROM/TO`·`IS_CURRENT`는 행 보존(LEAD)이라 SILVER 사전계산 **가능**하나 GOLD 파생도 타당 → 계산 위치 택일(설계 합의). D2 해소로 더는 **값 차단 아님**.

---

## 4. GOLD 정합 (SCD2)

- `DIM_MEMBER` SCD2 = **STATUS만**(원칙 6, D10/R6). 본 엔티티가 `EFFECTIVE_FROM/TO`로 상태 타임라인 제공. GENDER·REGION·신규기존은 마스터 현재값(SCD1).
- `FMM` 상태변경 measure(중단·재개 건수/시점)의 이벤트 소스. **월말 시점지표**(#49·50·52·53)는 `STATUS_CHG` 타임라인으로 산출(D2 해소).
- 현재상태(스냅샷 `CRM_MEMBER_MASTER.MEMBER_STAT_CD`) ↔ 이력 최신행 `STATUS_CD`(IS_CURRENT) 일치성 = §5 검증(OPEN-8).

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| ~~D2/R1~~ | ~~STNG_DTLS 컬럼 미정~~ | — | **✅ 해소(2026-06-22 정의서) — BF/CHN_STAT_CD·FRST_REGIST_DT** |
| ~~OPEN-7~~ | ~~RE_SPNSR/STNG_DTLS SEQ 미정~~ | — | **✅ 해소(3원천 SER_NO 보유)** |
| **OPEN-7b** | `BF_STAT_CD`·`CHN_STAT_CD` 코드그룹(정의서 코드그룹ID 공란) | 상태 라벨·미납단계 분류 | 코드그룹 확인(MM010 회원상태 추정) → ⑭ 라벨 |
| **OPEN-8** | EVENT_SEQ(SER_NO) 동일자 유일성 + 마스터 현재상태 ↔ 이력 최신행 정합 | PK·현재값 일치 | BRONZE 실측·교차검증 DMF |
| **OPEN-9** | SCD2 타임라인 범위 — 3종 전체 vs STATUS_CHG만 + 동일자 zero-length | 상태구간 정확도 | STATUS_CHG 기준 확정. STOP/RE 반영 여부 현업 |
| **OPEN-10** | EFFECTIVE_FROM/TO 계산 위치(SILVER vs GOLD) | 계층 책임 | 설계 합의(값 차단 아님) |
| **OPEN-5(공통)** | 일부 타입 미기재 | 캐스팅 | S-2 전 확인 |

---

## 6. 다음

- **즉시 완전 설계 가능** — D2 해소로 3종 이벤트 전부 적재 가능.
- **S-2**: `CREATE TABLE` DDL(EVENT_KEY PK, EFFECTIVE_FROM/TO 포함).
- **S-3**: 3원천 → SILVER UNION 매핑(STATUS_CHG = BF/CHN_STAT_CD 포함).
- **선결(품질)**: OPEN-7b(상태 코드그룹)·OPEN-8(현재값 정합)·OPEN-10(계산 위치).
