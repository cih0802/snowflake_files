# S-1 엔티티 설계서 ⑧ `CRM_ORG_MASTER`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_ORG_MASTER` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` / 상위: `SILVER_설계_작업 계획.md` §1-1(#8), §0 원칙 4·5·10·11.
> GOLD 수요처: `DIM_ORG`(SCD2, GOLD_차원 설계 §6). 경로: 목표(FTG-D/B) 직접 참조 + 실적(FMM) 캠페인 경유(결정 G).
> 원천: `TM_CM_DEPT_INFO`(12) — 전 컬럼 정의 ✅.

---

## 1. 핵심 — 전 노드 적재 (계층 평탄화는 GOLD)

본 엔티티는 **1행/조직노드(DEPT_ID)**. `DIM_ORG`는 "전 노드 적재 + `ORG_BK`(DEPT_ID) 조인으로 레벨 무관 해소"(결정 F2) 전략 → **SILVER는 모든 부서 노드를 raw로 보존**하고, 법인>본부/지부>부서>팀 **계층 평탄화(비정규화)는 GOLD**가 `UPPER_DEPT_ID` 재귀로 수행(원칙 4: SILVER raw, 평탄화는 상위).

> ⚠️ **레벨 정책 미확정(F2/OPEN-33)**: `STATS_DEPT_LVL`·`UPPER_DEPT_ID` 자기참조 계층의 레벨 의미·롤업 규칙 미정. 전 노드 적재 + `ORG_LEVEL` 기록으로 방어(레벨 commit 회피). 상위 노드는 하위 컬럼 NULL 가능(ragged).

---

## 2. grain / PK

- **grain**: 1행 / 조직노드(`DEPT_ID`). 전 레벨 노드 적재.
- **PK**: `ORG_KEY` = `DEPT_ID`(#1). GOLD `DIM_ORG.ORG_BK`(#116)와 동일(조인 해소키).
- **계층(자기참조)**: `UPPER_DEPT_ID`(#3) → 조직 상위. `ACMSLT_UPPER_DEPT_ID`(#12) → **실적 상위(별도 계층)**. 두 계층 용도 구분 OPEN-34.
- **회원 FK 없음**: 조직 마스터.

---

## 3. 컬럼 명세 (`TM_CM_DEPT_INFO`)

> 정제 표준 §0 원칙 11. 타입 캐스팅 잠정(OPEN-5).

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `ORG_KEY` (PK) | VARCHAR | `DEPT_ID`(#1) | 부서ID TRIM |
| 2 | `ORG_NM` | VARCHAR | `DEPT_NM`(#2) | 부서명 TRIM |
| 3 | `UPPER_ORG_ID` | VARCHAR | `UPPER_DEPT_ID`(#3) | 조직 상위 부서ID(자기참조) |
| 4 | `ACMSLT_UPPER_ORG_ID` | VARCHAR | `ACMSLT_UPPER_DEPT_ID`(#12) | 실적 상위 부서ID(별도 계층) |
| 5 | `ORG_LEVEL` | VARCHAR | `STATS_DEPT_LVL`(#7) | 통계부서레벨 → GOLD ORG_LEVEL(⚠️OPEN-33) |
| 6 | `IS_ACMSLT_DEPT` | BOOLEAN | `ACMSLT_DEPT_YN`(#6) | 실적부서여부 Y→TRUE |
| 7 | `SORT_ORDR` | NUMBER | `SORT_ORDR`(#4) | 정렬순서 |
| 8 | `USE_YN` | VARCHAR(1) | `USE_YN`(#5) | 사용여부(소프트삭제, 필터 금지) |
| 9 | `FIRST_RGSTR_ID` | VARCHAR | `FRST_RGSTR_ID`(#8) | TRIM |
| 10 | `FIRST_REGIST_DT` | TIMESTAMP_NTZ | `FRST_REGIST_DT`(#9) | 최초등록일시 |
| 11 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | `LAST_UPDT_DT`(#11) | 최종수정일시 |

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`('TM_CM_DEPT_INFO') · `_LOADED_AT` · `_BATCH_ID`

> **계층 컬럼(법인/본부지부/부서/팀)은 SILVER 미생성** — GOLD가 `UPPER_DEPT_ID` 재귀 CTE로 평탄화(SCD2 차원 속성). SILVER는 raw 노드 + 자기참조 키만 제공.

---

## 4. GOLD 정합 (`DIM_ORG`, SCD2)

| GOLD DIM_ORG 컬럼 | 소스# | 본 엔티티 매핑 |
|---|---|---|
| ORG_BK | #116 | `ORG_KEY`(=DEPT_ID) ✅ |
| ORG_LEVEL | STATS_DEPT_LVL | `ORG_LEVEL` ⚠️OPEN-33 |
| 법인 / 본부_지부 / 부서 / 팀 | #114~116 | GOLD가 `UPPER_ORG_ID` 재귀 평탄화(SILVER 비제공) |

- **조직 귀속 경로(결정 G)**: 목표 FTG-D(⑨)·FTG-B는 `DEPT_ID` 직접 참조, 실적 FMM은 캠페인(⑥) 경유. 회원→ORG 직접 FK 금지.
- **SCD2**: GOLD 차원에서 조직 변경이력 관리. CRM `TM_CM_DEPT_INFO`는 현재값 스냅샷(이력 별도 없음) → SCD2는 적재 시점 기준 GOLD 책임(이력 소스 부재 한계, R6 유사).

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| **OPEN-33 (F2)** | 조직 계층 레벨 정책 — `STATS_DEPT_LVL` 레벨 의미·법인/본부지부/부서/팀 매핑·롤업 규칙 미정 | 계층 평탄화(GOLD) 정확도 | BRONZE 실데이터로 레벨 확정. 그 전 전노드+ORG_BK 방어 |
| **OPEN-34** | `UPPER_DEPT_ID`(조직상위) vs `ACMSLT_UPPER_DEPT_ID`(실적상위) 이중 계층 용도 | 실적 롤업 경로 | 현업 확인(실적 집계가 어느 계층 따르는지) |
| **OPEN-5(공통)** | BRONZE 물리타입 미제공 | 캐스팅 잠정 | S-2 전 실제 타입 확인 |

---

## 6. 다음

- **즉시 완전 설계 가능** — 원천 전 컬럼 정의됨, 차단 없음.
- **S-2**: `CREATE TABLE GN_DW.SILVER.CRM_ORG_MASTER` DDL(raw 노드 + 자기참조 키).
- **S-3**: `TM_CM_DEPT_INFO`(12) → SILVER 1:1 매핑. 계층 평탄화는 GOLD 적재 트랙으로 위임 명시.
