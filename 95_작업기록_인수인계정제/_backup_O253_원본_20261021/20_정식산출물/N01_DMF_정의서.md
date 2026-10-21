---
doc_id: N01
title: 데이터 품질(DMF) 정의서
version: 1.0
as_of: 2026-10-20 (운영계 미캡처 · 계정 값 TBD)
source_docs:
  - 20_정식산출물/D05_FK관계.csv (GOLD→GOLD FK 71) · N04_배치SLA_스케줄정의서.md §3 (DMF 시각 근거)
  - 02_GN_DW_building/06_RUNBOOK.md §3.3 (CREATE OR REPLACE 금지)
source_queries:
  - SHOW DATA METRIC FUNCTIONS IN SNOWFLAKE.CORE · SHOW PRIMARY KEYS IN SCHEMA GN_DW.GOLD · ACCOUNT_USAGE.DATA_METRIC_FUNCTION_REFERENCES (2026-10-20)
  - 85_실제 인수인계 문서/_근거쿼리/N01_DMF_사전점검.sql (Q01~Q03 · 읽기 전용 · "[ENV] = _ENV/<계정>/N01_*.csv")
  - 적용 SQL = 20_정식산출물/N01_DMF_적용완료.sql (🔴 미실행 · 136문장 compile 검증)
owner: TBD
status: review
---

# N01. 데이터 품질(DMF) 정의서

적용 = `N01_DMF_적용완료.sql`(🔴 미실행). 이 문서는 무엇을 왜 붙이는지와, 붙이면 바로 어디서 위반이 나는지를 적는다.

## 1. [ENV] 현황

| 항목 | 운영계 |
|---|---|
| GN_DW 에 부착된 DMF | TBD(미검증) |
| 품질 검사의 실제 수단 | TBD(미검증) |
| 필요한 시스템 DMF 5종 | TBD(미검증) |

- 🔴 FRESHNESS 에 **TIMESTAMP_NTZ 오버로드가 없다**(DATE · TIMESTAMP_LTZ · TIMESTAMP_TZ 만). GOLD 감사 컬럼 `DW_UPDATE_TS` 는 NTZ 라 컬럼 지정 FRESHNESS 를 못 건다 ⇒ 테이블 단위(`ON ()`) 로 건다.

## 2. 설계 (GOLD 스키마)

| 규칙 | DMF | 대상 | 기대값 | 범위 |
|---|---|---|---|---|
| 행수 변동 | `ROW_COUNT` + 이상 탐지 | 스키마 단위(뷰 제외) | 이상 탐지가 학습한 범위 | 1문장 |
| 신선도 | `FRESHNESS` + 이상 탐지 | 스키마 단위(뷰는 자동 제외) | 이상 탐지가 학습한 범위 | 1문장 |
| PK 유일성 | `DUPLICATE_COUNT` | 단일 컬럼 PK 31 테이블 | `VALUE = 0` | 31문장 |
| PK NULL | `NULL_COUNT` | 같은 31 | `VALUE = 0` | 31문장 |
| FK 정합 | `REFERENTIAL_INTEGRITY_COUNT` | GOLD→GOLD FK 71 간선(D05) | `VALUE = 0` | 71문장 |

- 복합 PK 3(`FACT_AD_BROADCAST_CASE`·`FACT_MEMBER_COHORT_SURVIVAL`·`FACT_MEMBER_DEV_ACHIEVEMENT`)은 DMF 로 걸지 않는다 — dbt `unique` 테스트가 이미 잡는다.
- 스케줄 = 매일 08:00 KST(스키마 단위 DMF 는 `TRIGGER_ON_CHANGES` 를 지원하지 않는다). dbt 06:01 · MSTR 07:30 이 끝난 뒤다(N04 §3).
- 범위를 GOLD 로 한정했다 — SV·Agent 가 읽는 계약면이다. SILVER 는 dbt 테스트(관계·NOT NULL 13 WARN · N05 §2)가 담당한다.
- dbt 테스트를 대체하지 않는다. DMF 는 **build 사이(외부 적재·수동 수정)에도** 상태를 본다는 점이 추가 가치다.

## 3. 사전 점검 — 붙이면 바로 위반이 날 곳 (Q01·Q02)

| 검사 | 대상 | 위반 |
|---|---|---|
| PK 중복·NULL | 31 테이블 | **0** |
| FK 고아 행 | 71 간선 | **2 간선** — `FACT_MESSAGE_DISPATCH.SEND_REQUEST_SK → DIM_SEND_REQUEST` **3,001 행** · `DIM_MSG_TEMPLATE_BUTTON.TEMPLATE_SK → DIM_MSG_TEMPLATE` **21 행** |

- 두 간선은 SK=0 Unknown 라우팅이 적용되지 않은 FK 다(고아 = NULL 이 아니면서 부모에 없는 값). 붙이는 즉시 기대값 위반으로 뜬다 ⇒ 붙이기 전에 원인을 보거나, 그 2문장만 기대값 없이(관측용) 붙인다. 🟠 원인은 이번에 확인하지 않았다(A8-29).

## 4. 권한 · 실행 (🔴 미실행)

- 실행 롤 = GN_DW_ADMIN(GOLD 테이블 소유). 🔴 지금은 권한이 없어 **전부 실패한다**(2026-10-20 compile 실측): 테이블 단위 = `EXECUTE DATA METRIC FUNCTION` 부족 · 스키마 단위 = `MANAGE DATA QUALITY` 부족 ⇒ SQL [0] 을 ACCOUNTADMIN 으로 먼저 실행한다.
- ACCOUNTADMIN 으로 compile 하면 136 중 134 통과 · 실패 2 = 스키마 단위 2문장(스키마 소유 롤 GN_DW_ADMIN 에 `MANAGE DATA QUALITY` 가 없다는 같은 사유) ⇒ 구문·식별자 오류 0.
- 비용 = 서버리스 · 실행 횟수 과금. 하루 1회 × 135 연결이다. 금액은 TBD(미검증) — 붙인 뒤 `SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_USAGE_HISTORY` 로 잰다(N06 비용 산정에 포함 예정).
- 확인 = SQL [5] · 결과 = `SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS()` · 기대값 위반 = `SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS`.
- 롤백 = SQL [9](DROP DATA METRIC FUNCTION). 🔴 DMF 를 붙이려고 테이블을 `CREATE OR REPLACE` 하지 않는다(RUNBOOK §3.3).

## 5. 드리프트

| # | 기대 | 실측 | 처리 |
|---|---|---|---|
| DR-31 | GOLD fact 의 미상·범위밖 값은 SK=0 Unknown 멤버로 라우팅한다(`06_DDL.sql` 규약 · `models/gold/dim/DIM_DATE.sql` 주석) | 2 간선 고아 3,022 행(§3) | A8-29 등재 · 기록만 |

## 6. 🆕 적용 여부 = 후속 작업자 결정 (2026-10-20 사용자 결정 · O249)

- **현재 상태**: 운영계 **미적용**이다(`N01_DMF_적용완료.sql` 136문장 실행 대기).
- **할 수 있는 것**: 이 문서 §2 설계 그대로 `N01_DMF_적용완료.sql` [0](권한) → [1]~[4](부착) → [5](확인)를 블록 단위로 실행하면 된다. 롤백 = [9].
- **결정에 필요한 판단 근거**
  - 비용 = 서버리스 과금(사용자 Task·웨어하우스 아님) · 하루 1회 × 135 연결 · 금액 미실측 ⇒ 붙이면 하루 뒤 `ACCOUNT_USAGE.DATA_QUALITY_MONITORING_USAGE_HISTORY` 로 잰다.
  - 대안 = dbt 테스트(현재 relationships 107 · not_null 157 · unique 9). DMF 와 1:1 로 맞추려면 복합 PK 유일성·신선도(recency) 테스트를 추가해야 한다.
  - DMF 만의 가치 = dbt build 사이(외부 적재·수동 수정)에도 상태를 본다.
  - 붙이면 바로 위반 2 간선(§3 · DR-31)이 뜬다 ⇒ 그 2문장은 관측용으로만 붙이거나 원인부터 본다.
- 🔴 결정 전에는 실행하지 않는다(서버리스 과금 발생).
