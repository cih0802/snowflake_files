---
doc_id: D03
title: 환경 구성서 + RBAC 권한 매트릭스
version: 1.0
as_of: 2026-10-21 (운영계 ZL50263 · A0·A2 캡처)
source_docs:
  - 85_실제 인수인계 문서/10_실무자_인수인계/A0_환경실사_baseline.md · A1_운영자가이드.md · A2_롤별_접근권한_매트릭스.md (원본 · 이 문서는 고객 제출용 재편집)
  - 80_인수인계_프로젝트완료 및 유지보수용/01_실행순서_배포SQL/02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql · 08_After_Deploy_DBT.sql
source_queries:
  - 85_실제 인수인계 문서/10_실무자_인수인계/A0_환경실사_baseline.sql · A2_롤별_접근권한_근거.sql
  - "권한 매트릭스 정본 = _ENV/<계정>/A2_매트릭스.csv · A2_롤별_권한매트릭스.xlsx (scripts/a2_matrix_build.py 생성)"
owner: TBD
status: review
---

# D03. 환경 구성서 + RBAC 권한 매트릭스

## 1. 환경 개요

| 항목 | 값 | 비고 |
|---|---|---|
| 데이터베이스 | `GN_DW` (소유 GN_DW_ADMIN) | 스키마 22 = 주 16 + 백업 사본 6(`BRONZE_CRM_2` · `SILVER_2` · `SILVER_OLD` · `GOLD_2` · `GOLD_OLD` · `OPS_2`) · 테이블 1,586 · 뷰 96(주 스키마 1,314 · 64) (A0 Q02) |
| 레이어 | BRONZE(원천 6 스키마) → SILVER → GOLD → SERVING(SV·Agent·Search) | ML · MSTR · OPS · SECURITY · DBT_TEST__AUDIT · LAB(Streamlit 9) 보조 |
| 계정 | 운영 = ZL50263(AWS_AP_NORTHEAST_2) | 계정 의존 값은 `[ENV]` 규약으로 재캡처 |
| 정책 | 마스킹·행 접근·네트워크 정책 0 · 정책 부착 0 · 사용자 정의 태그 1(`SECURITY.AI_COST_SCOPE` · 부착 0) · DMF 0 (A0 Q08 · D10 Q06 · N01 · 2026-10-21) | 신규 설계 = N01·N02 · 🔴 운영계 미적용(체크리스트 ⑤-5~7) |

## 2. 웨어하우스

| WH | 크기 | auto_suspend(s) | 용도 | 사용 롤 |
|---|---|---|---|---|
| GN_DW_ETL_WH | X-Small | 60 | 적재·프로시저·태스크·dbt | ADMIN · ENGINEER · LOADER · DBT |
| GN_DW_DEV_WH | X-Small | 60 | 개발·테스트 | ADMIN · ENGINEER |
| GN_DW_ANALYTICS_WH | X-Small | 60 | 분석 · SV/Agent 소비 · Search | ADMIN · ANALYST · VIEWER · SERVICE |
| GN_DW_ML_WH | Large | 60 | ML 프로시저(실행 중 크기 조정) | LOADER(USAGE+OPERATE+MODIFY) |

- 운영계 실측(2026-10-21 · A0 Q07) · 4종 모두 소유 ACCOUNTADMIN · Gen2 · 리소스 모니터 0 · 사용자 생성 예산 0(A0 Q07-2·3 · D11 · A8-11).

## 3. 롤 계층

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

| 롤 | 역할 |
|---|---|
| GN_DW_ADMIN | DB·스키마·SV·Agent·DBT PROJECT 소유 · DDL · 배포 |
| GN_DW_ENGINEER | ETL 개발(사람) |
| GN_DW_DBT | dbt 실행 전용 · GOLD WIDE 뷰·OPS 감사 테이블 소유 |
| GN_DW_LOADER | 외부팀 BRONZE 적재 · 월마감/ML 프로시저 실행 |
| GN_DW_SERVICE | 서비스 계정(API · Streamlit 앱 소유 예정) |
| GN_DW_ANALYST | 분석가 · 원천(BRONZE)~SERVING 조회 · Agent 사용 |
| GN_DW_VIEWER | 현업 조회 · GOLD/ML/MSTR + SV/Agent 소비 |

## 4. 권한 매트릭스 (요약)

| 스키마 | ADMIN | ENGINEER | DBT | LOADER | SERVICE | ANALYST | VIEWER |
|---|---|---|---|---|---|---|---|
| BRONZE_* (6) | 소유 | 읽기 | 읽기(BIGQUERY 제외) | 쓰기(INSERT/UPDATE · GA4·GSC 는 DELETE) | — | 읽기 | — |
| SILVER | 소유 | 개발+DML | DML(UPDATE 제외) | 프로시저 실행 | — | 읽기 | — |
| GOLD | 소유 | DML+뷰 생성 | DML+뷰 생성 | — | 읽기 | 읽기 | 읽기 |
| ML | 소유 | 시뮬레이터 SP | — | 프로시저·모델 생성 | 읽기 | 읽기+시뮬레이터 SP | 읽기 |
| MSTR | 소유 | 개발+DML | — | — | 읽기 | 읽기 | 읽기 |
| SERVING | 소유 | 일부 뷰·SV | — | — | SV·Agent·Search·뷰 | SV·Agent·Search·뷰 | SV·Agent·Search·뷰 |
| OPS | 소유 | dbt 프로젝트·알림 SP | 감사 테이블·Task 생성·dbt 실행 | (임시 권한만) | — | — (2026-10-20 결정) | — |

- 객체 단위 상세(117행 설계 · 운영계 346건 라이브 대조) = `A2_롤별_접근권한_설계.csv` · `_ENV/ZL50263/A2_롤별_권한매트릭스.xlsx`.
- SV·Agent·Streamlit 은 FUTURE grant 가 없어 객체마다 소비 3롤에 직접 부여한다.
- Cortex·Agent 접근은 모든 롤이 PUBLIC 의 `SNOWFLAKE.CORTEX_USER` 상속으로 얻는다(A3).

## 5. 라이브 대조 결과 (운영계 ZL50263 · 2026-10-21 · `_ENV/ZL50263/A2_설계대조.csv` 346건)

| 판정 | 건수 | 내용 |
|---|---|---|
| OK | 337 | 설계대로 |
| PARTIAL | 5 | ANALYST · VIEWER · SERVICE 의 SERVING Agent USAGE 3(일부 Agent 만 부여) · VIEWER · SERVICE 시뮬레이터 뷰 2(결정 A8-07 적용 대기) |
| MISSING | 1 | GN_DW_ADMIN 의 `APPLY MASKING POLICY`(A8-28 선행 · 체크리스트 ⑤-2) |
| NA | 3 | SILVER 뷰 대상 없음(설계상 뷰 미생성) |
| 설계 밖 부여 | 2 | ANALYST 의 OPS 스키마 `USAGE` · 테이블 1 `SELECT` — 결정 A8-08 회수 미적용 |

- 적용 SQL = `10_실무자_인수인계/A2_권한조정_적용완료.sql`(🔴 운영계 미적용). 적용 후 재캡처하면 시뮬레이터 PARTIAL 2 · 설계외부여 2 가 0 이 되어야 한다.
- 🔴 설계 원본 `07_OPS_알림…sql` 에서 ANALYST OPS GRANT 를 제거했다(사용자 결정 · 4개 사본).

## 6. 운영 절차 참조

| 절차 | 문서 |
|---|---|
| 사용자 온보딩·오프보딩 | A1 §2 |
| 노출 범위 3단계(RBAC → SV → 정책) | A1 §3 |
| 권한 재점검(월) | A7 M01 · `a2_matrix_build.py` |
| CoCo 사용 차단(ANALYST) | A3 (운영계 테스트 사용자 `ANALYST_01` 한도 0 적용 · 확인 완료) |

## 7. 드리프트

| # | 내용 | 처리 |
|---|---|---|
| DR-04 | 시뮬레이터 SV·뷰 권한 불일치 | 결정 = 뷰 개방(미실행) |
| DR-09 | ANALYST OPS 권한 ↔ OPS COMMENT | 결정 = 회수 + 원본 수정 |
| DR-05·06 | SILVER UPDATE · BRONZE_BIGQUERY 권한 기재 | 해소(문제 아님) |
| DR-15 | 07 :620 UTF-8 절단 | 기록만 |

전체 = `_드리프트/드리프트_통합.md`.
