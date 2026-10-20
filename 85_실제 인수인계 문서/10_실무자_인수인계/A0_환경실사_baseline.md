---
doc_id: A0
title: 환경 실사 baseline (트랙 A·B 공통 · 트랙 B Phase 0 겸용)
version: 0.1
as_of: 2026-10-20 (조회 시각 2026-10-19 18:53 PDT)
source_docs:
  - 85_실제 인수인계 문서/00_작업계획서.md §3 A0
  - 80_인수인계_프로젝트완료 및 유지보수용/ (드리프트 대조용 CREATE 문 스캔)
source_queries:
  - 85_실제 인수인계 문서/10_실무자_인수인계/A0_환경실사_baseline.sql (Q00~Q08)
  - "[ENV] 값 정본 = 85_실제 인수인계 문서/_ENV/<계정>/A0_*.csv (scripts/env_capture.py --id A0 생성)"
owner: TBD
status: draft (S1 게이트 확인 대기 · [ENV] 운영계 열 미캡처)
---

# A0. 환경 실사 baseline

조회는 읽기 전용이며 DDL/DML/GRANT 는 실행하지 않았다.

**[ENV] 분리 규약**(작업계획서 §1-10)을 따른다.
- `[공통]` 절 = GN_DW DB 객체 기준 값. 운영계에서는 같은 쿼리로 **재확인만** 한다.
- `[ENV]` 절 = 계정마다 다른 값. 정본은 `_ENV/<계정>/A0_<Qnn>_<k>.csv` 이고, 아래 표는 그 요약이다.
- 운영계 반영 = `python3 scripts/env_capture.py --id A0 "85_실제 인수인계 문서/10_실무자_인수인계/A0_환경실사_baseline.sql"`
  → `_ENV/<운영계 계정>/` 생성 → 각 표의 `운영계` 열과 `[ENV]` 판정을 채운다.

| 계정 | 구분 | 캡처 시각 | manifest |
|---|---|---|---|
| IW20760 | 개발 | 2026-10-19 19:06 PDT | `_ENV/IW20760/A0_manifest.csv` (26문장 · OK 26) |
| TBD | 운영 | TBD(미검증) | TBD(미검증) |

## 1. [ENV] 계정 컨텍스트 (Q00 → `A0_Q00_1.csv`)

| 항목 | IW20760(개발) | 운영계 |
|---|---|---|
| 계정 로케이터 | IW20760 | TBD(미검증) |
| 계정명 / 조직 | IQ36690 / THGVUIA | TBD(미검증) |
| 리전 | AWS_EU_CENTRAL_1 | TBD(미검증) |
| 조회 롤 / 사용자 | ACCOUNTADMIN / TRIALADMIN | TBD(미검증) |
| Snowflake 버전 | 10.37.102 | TBD(미검증) |

## 2. [ENV] 데이터베이스 (Q01 → `A0_Q01_1.csv`)

- `[공통]` GN_DW 는 양 계정에 있어야 한다(소유 GN_DW_ADMIN).
- 그 밖의 DB 는 계정 프로비저닝에 따라 다르다.

| DB | 종류 | IW20760(개발) | 운영계 |
|---|---|---|---|
| GN_DW | STANDARD | 있음 · 소유 GN_DW_ADMIN | TBD(미검증) |
| SANDBOX | STANDARD | 있음 · 소유 SYSADMIN | TBD(미검증) |
| SNOWFLAKE_LEARNING_DB | STANDARD | 있음(프로비저닝) | TBD(미검증) |
| SNOWFLAKE_SAMPLE_DATA | IMPORTED | 있음(프로비저닝) | TBD(미검증) |
| USER$&lt;사용자&gt; | PERSONAL | USER$TRIALADMIN 1건 | TBD(미검증) |

## 3. [공통] GN_DW 스키마별 객체 수 (Q02 · Q03 → `A0_Q02_1.csv` · `A0_Q03_1.csv`)

운영계는 DB 데이터가 같으므로 이 표는 그대로 유효해야 한다. 운영계 캡처 값과 다르면 `_드리프트/` 에 적는다.

| 스키마 | 테이블 | 뷰 | 합계 | 프로시저 | 함수 | 스테이지 |
|---|---|---|---|---|---|---|
| BRONZE_AGENCY | 4 | 0 | 4 | 0 | 0 | 0 |
| BRONZE_BIGQUERY | 0 | 0 | 0 | 0 | 0 | 0 |
| BRONZE_CRM | 53 | 0 | 53 | 0 | 0 | 0 |
| BRONZE_ERP | 3 | 0 | 3 | 0 | 0 | 0 |
| BRONZE_GA4 | 2 | 0 | 2 | 0 | 0 | 0 |
| BRONZE_GSC | 3 | 0 | 3 | 0 | 0 | 0 |
| DBT_TEST__AUDIT | 0 | 0 | 0 | 0 | 0 | 0 |
| GOLD | 60 | 19 | 79 | 0 | 0 | 0 |
| ML | 12 | 0 | 12 | 1 | 0 | 0 |
| MSTR | 10 | 13 | 23 | 13 | 2 | 0 |
| OPS | 14 | 1 | 15 | 4 | 0 | 3 |
| PUBLIC | 0 | 0 | 0 | 0 | 0 | 0 |
| SECURITY | 0 | 0 | 0 | 0 | 0 | 0 |
| SERVING | 13 | 19 | 32 | 0 | 0 | 1 |
| SILVER | 66 | 0 | 66 | 0 | 0 | 0 |
| **합계** | **240** | **52** | **292** | **18** | **2** | **4** |

- 동적 테이블·구체화 뷰는 0건이다.
- SV(40)·Agent(3)·Cortex Search(1)는 위 표에 포함되지 않는다(§4).

## 4. AI·파이프라인 객체

### 4-1. [공통] GN_DW 정의 객체 (Q04 → `A0_Q04_1~4.csv`)

| 종류 | 건수 | 내역 |
|---|---|---|
| Semantic View | 40 | 전부 GN_DW.SERVING · 소유 GN_DW_ADMIN · 목록 = `A0_Q04_1.csv` |
| Cortex Agent | 3 | AGENT_EXECUTIVE · AGENT_MARKETING · AGENT_MEMBER — SERVING · 기본 버전 VERSION$8 |
| Agent SV 배선(spec 실측) | 17 / 28 / 28 | EXECUTIVE / MARKETING / MEMBER · 각 Search 1 · 합집합 40 = SV 전수(미배선 0) |
| Cortex Search | 1 | SERVING.SEARCH_BIZ_DEFINITION · lag 1 day · ACTIVE |
| DBT PROJECT | 1 | OPS.DW_PIPELINE · dbt 1.9.4 · 버전 LIVE |

- 위 객체의 **정의**는 공통이다. 다음 속성은 `[ENV]` 로 본다.
  - Search 원천 행 수(개발 1,002) · 서비스 WH(개발 GN_DW_ANALYTICS_WH)
  - DBT PROJECT 배포 원천 경로(개발 = 워크스페이스 `10_dbt_pipeline/`) · 배포 버전
- 🟠 Agent COMMENT 의 「소관 SV 14·25·24종」은 spec 실측(17·28·28)과 다르다 ⇒ COMMENT 가 낡았다(`_드리프트/` DR-03).
  - SV base 분포: GOLD 기반 28종(논리테이블 82) · SERVING 뷰 기반 12종(21) — `INFORMATION_SCHEMA.SEMANTIC_TABLES` 실측.

### 4-2. [ENV] 배포·운영 객체 (Q04-5 · Q05 → `A0_Q04_5.csv` · `A0_Q05_1~4.csv`)

Task·Alert·Streamlit 은 GN_DW 안의 객체지만 **배포 상태가 계정마다 다르다**(운영계 설정 상이) ⇒ `[ENV]`.

| 종류 | IW20760(개발) | 운영계 |
|---|---|---|
| Task (GN_DW) | 0 (계정 전체 1건 = SNOWFLAKE.MODELS 시스템 Task) | TBD(미검증) |
| Alert | 1 · OPS.ALERT_DBT_WARN_SPNSR_CLS_DUP · 매일 09:00 KST · started | TBD(미검증) |
| Streamlit | 0 | TBD(미검증) |
| Git repository | 0 | TBD(미검증) |
| Integration | 3 · EMAIL_ALERT_INTEGRATION · git_integration · SNOWFLAKE$LOCAL_APPLICATION | TBD(미검증) |

## 5. 롤·사용자 (Q06 → `A0_Q06_1~3.csv`)

### 5-1. [ENV] 롤 계층 — 개발계 라이브 기준 · 설계(`07_ENVIRONMENT_RBAC_setup.sql`) 대조는 A2 소관

롤 계층(USAGE 부여 · 부모 → 자식):

```mermaid
graph TD
  ACCOUNTADMIN --> SECURITYADMIN --> USERADMIN
  ACCOUNTADMIN --> SYSADMIN --> GN_DW_ADMIN
  GN_DW_ADMIN --> GN_DW_ENGINEER
  GN_DW_ADMIN --> GN_DW_DBT
  GN_DW_ADMIN --> GN_DW_LOADER
  GN_DW_ADMIN --> GN_DW_SERVICE
  GN_DW_ADMIN --> GN_DW_ANALYST --> GN_DW_VIEWER
```

### 5-2. [ENV] 롤·사용자 현황

| 항목 | IW20760(개발) | 운영계 |
|---|---|---|
| GN_DW 롤 7종 실재 | 7/7 (소유 SECURITYADMIN) | TBD(미검증) |
| 롤 계층 | 위 그림과 같음 | TBD(미검증) |
| 사용자 수 | 1 (TRIALADMIN · 기본 롤 ACCOUNTADMIN · 기본 WH COMPUTE_WH) | TBD(미검증) |
| GN_DW 롤 사용자 할당(`assigned_to_users`) | 7종 전부 0 | TBD(미검증) |

## 6. [ENV] 웨어하우스·비용 가드 (Q07 → `A0_Q07_1~3.csv`)

| WH | 개발: 크기 · auto_suspend(s) · 소유 · 용도(COMMENT) | 운영계 |
|---|---|---|
| COMPUTE_WH | X-Small · 300 · ACCOUNTADMIN · — | TBD(미검증) |
| GN_DW_ANALYTICS_WH | Medium · 300 · SYSADMIN · 분석가 쿼리 / SV·Agent 소비 | TBD(미검증) |
| GN_DW_DEV_WH | X-Small · 60 · SYSADMIN · 개발/테스트 | TBD(미검증) |
| GN_DW_ETL_WH | Small · 60 · ACCOUNTADMIN · ETL / 데이터 적재 | TBD(미검증) |
| GN_DW_ML_WH | Small · 60 · SYSADMIN · ML 학습·예측 프로시저 전용 | TBD(미검증) |
| SNOWFLAKE_LEARNING_WH | X-Small · 300 · ACCOUNTADMIN · 프로비저닝 | TBD(미검증) |
| SYSTEM$STREAMLIT_NOTEBOOK_WH | X-Small(max 10) · 60 · ACCOUNTADMIN · 시스템 | TBD(미검증) |

| 항목 | IW20760(개발) | 운영계 |
|---|---|---|
| 리소스 모니터 | 0 | TBD(미검증) |
| 예산 | ACCOUNT_ROOT_BUDGET 1건(기본) | TBD(미검증) |
| WH 세대 | 전부 STANDARD_GEN_2 | TBD(미검증) |

## 7. [ENV] 거버넌스 (Q08 → `A0_Q08_1~7.csv`)

| 항목 | IW20760(개발) | 운영계 |
|---|---|---|
| 마스킹 정책 | 0(실사 시점) → 🟢 2026-10-20 1(`SECURITY.MP_PII_STRING`) | TBD(미검증) |
| 행 접근 정책 | 0 | TBD(미검증) |
| 네트워크 정책 | 0 | TBD(미검증) |
| 사용자 정의 태그 | 0 (계정의 12건은 전부 SNOWFLAKE.* 시스템 태그) | TBD(미검증) |
| GN_DW 정책 참조 | 0(실사 시점) → 🟢 2026-10-20 12(BRONZE_CRM 12 컬럼) | TBD(미검증) |
| GN_DW 태그 참조 | 0 | TBD(미검증) |
| GN_DW DMF 부착 | 0(실사 시점) → 🟢 2026-10-20 N01 적용(스키마 GOLD 단위 2 + 테이블 단위 133문장 = PK 62 · FK 71 · 스케줄 08:00 KST) | TBD(미검증) |

- ACCOUNT_USAGE 지연(최대 2시간)이 있으나 개발계는 SHOW 결과도 0건이므로 「없음」으로 판정한다.

## 8. [ENV] 드리프트 (설계 스크립트 ↔ 라이브)

80번 패키지 `.sql` 의 CREATE 문을 python 으로 전수 스캔해(rc=0) 라이브와 대조했다.
설계 객체 목록은 `[공통]`, 라이브 판정은 계정마다 다시 한다. S8 에서 `_드리프트/드리프트_통합.md` 로 옮긴다.

| # | 설계 객체 | 정의 파일(80번 기준) | IW20760(개발) | 운영계 |
|---|---|---|---|---|
| D-A0-1 | TASK GN_DW.OPS.TASK_DBT_DAILY_DEV2 | 06_일배치_모니터링/11_일적재pipeline 구성/03_일배치_TASK_스케줄.sql | 🟡 없음 — `--target dev2` **테스트** Task(운영 일배치 아님 · `_2` 스키마도 없음 · 드리프트 DR-01) | TBD(미검증) |
| D-A0-2 | TASK GN_DW.MSTR.TSK_RUN_MSTR_DAILY | 03_MSTR_이관/15_MSTR 이관 PoC/snowflake 적용 ddl/07_MSTR_일일적재_TASK.sql | 🔴 없음 | TBD(미검증) |
| D-A0-3 | TASK GN_DW.MSTR.TSK_RUN_MSTR_1ST | 01_실행순서_배포SQL/15_MSTR 이관 PoC/snowflake 적용 ddl/06_MSTR_적재_실행.sql | 🟠 없음 — 1회성 여부 확인 | TBD(미검증) |
| D-A0-4 | RESOURCE MONITOR ML_WH_MONITOR | 06_일배치_모니터링/08_mornitoring/06_웨어하우스비용가드_구축.sql | 🟠 없음 — 비용 가드 미배포 | TBD(미검증) |
| D-A0-5 | TAG GN_DW.SECURITY.WH_COST_SCOPE | 06_웨어하우스비용가드_구축.sql | 🟠 없음(SECURITY 스키마 비어 있음) | TBD(미검증) |
| D-A0-6 | TAG GN_DW.SECURITY.AI_COST_SCOPE | 06_일배치_모니터링/08_mornitoring/05_AI비용가드_구축.sql | 🟠 없음 | TBD(미검증) |
| D-A0-7 | STREAMLIT GN_DW.SERVING.* | 01_실행순서_배포SQL/02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql (권한 구문) | 🟡 Streamlit 0 · 권한 구문만 존재 | TBD(미검증) |
| D-A0-8 | GN_DW 롤 7종 사용자 할당 | 07_ENVIRONMENT_RBAC_setup.sql | 🟡 할당 0 — 단일 사용자 계정 | TBD(미검증) |

- 스캔 범위는 CREATE TASK/STREAMLIT/정책/리소스 모니터/태그/USER/BUDGET 이다.
- 테이블·SV 단위 정합 대조는 S2(A2) 이후 단계 소관이다.
- 개발계 판정 D-A0-1~8 은 **개발계 미배포**를 뜻할 뿐이다. 운영계에 있으면 운영계 열에 「있음」으로 적고 드리프트에서 제외한다.

## 9. [ENV] 후속 단계 영향

| 단계 | IW20760(개발) | 운영계 |
|---|---|---|
| S3(A3) CoCo 차단 | 테스트할 ANALYST 사용자가 없다 ⇒ 🔴 **운영계로 연기**(2026-10-20 사용자 결정). 개발계는 조회 SQL·우회안·문의서 초안만 | 적용·검증 수행 |
| A6 런북 | 라이브 Task 0 · 운영 계약 = 온디맨드 `build`(DR-01) ⇒ 수동 실행 기준으로 작성 · 정기화 Task 는 미실행 안으로만 | 운영계 Task 유무로 재확인 |
| N01·N02 정책 SQL | 정책 0건이 기준선 | TBD(미검증) |

## 10. [ENV] 데이터 차이 축 · 실행 이력 (Q09 · Q10 → `A0_Q09_1.csv` · `A0_Q10_1~2.csv`)

| 항목 | IW20760(개발) | 운영계 |
|---|---|---|
| `SILVER.BIGQUERY_REFINED_DATA` 행 / 기간 / 적재일 수 | 10,022,871 / 20240122 - 20261004 / 34일(듬성 적재) | TBD(미검증) |
| GN_DW Task 실행 이력 | AI Evals 일회성 Task 5종(2026-10-18)뿐 · 일배치 Task 는 존재한 적 없음 | TBD(미검증) |
| dbt 실행(최근 30일) | 수동 10회 성공 · GN_DW_ADMIN 4 · GN_DW_DBT 6 | TBD(미검증) |

- `BIGQUERY_REFINED_DATA` 는 외부 Python 이 직접 적재한다(dbt source `silver_external`). 운영계와 다른 유일한 데이터 축이므로 GA 계열 SV(SV_GA_*) 수치는 계정마다 다르다.
- 🟢 ADMIN 롤 4회는 build 가 아니라 **배포(ADD VERSION) 때 자동으로 도는 compile** 이다(A6 Q01 실측). build 는 전부 GN_DW_DBT.
  실측 = GOLD 뷰 19개 전부 GN_DW_DBT 소유 · OPS 감사 테이블 11개 DBT 소유 ⇒ 소유 혼입 없음(드리프트 DR-13 해소).
