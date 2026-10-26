---
doc_id: R02
title: "[현업 D02] DB와 데이터 구조"
version: 0.2
as_of: 2026-10-26 (운영계 ZL50263 점검 · `_ENV/ZL50263/R00_Q01~Q13` · `R90_Q09`)
source_docs:
  - 85_실제 인수인계 문서/20_정식산출물/D04_테이블컬럼정의서.md · D04_테이블목록.csv · D04_컬럼정의.csv · .xlsx (v1.0)
  - 85_실제 인수인계 문서/20_정식산출물/D05_ERD.md · D05_FK관계.csv · D06_원천타깃매핑_계보.md · D06_테이블계보.csv (v1.0)
  - 85_실제 인수인계 문서/20_정식산출물/N03_통합데이터사전.md · .csv · .xlsx · .html (v1.0)
  - 85_실제 인수인계 문서/20_정식산출물/D07_ETL_파이프라인설계서.md §3 (v1.0)
source_queries:
  - 30_현업요청대응/_근거쿼리/R00_라이브대조.sql (Q01~Q13) → _ENV/ZL50263/R00_*
  - _ENV/ZL50263/A0_Q02_1 · A0_Q04_* · A0_Q05_* · B1_Q01_1 · B1_Q10_1
owner: TBD
status: review
---

# R02. DB와 데이터 구조 (현업 자료 ID D02)

## 0. 별첨 요구 → 제출 위치

| 별첨에 포함할 내용 | 제출 위치 | 판정 |
|---|---|---|
| Database·Schema·테이블·View 목록 | `85:D04` §1 + `D04_테이블목록.csv` · 검색용 = `85:N03`(xlsx·html) | 충족 |
| Procedure·Task 등 비테이블 객체 | 이 문서 §2 (`85:D07` §3 · A0 §4 를 한 표로 통합) | 부분 → 보완 |
| DDL | 이 문서 §3 (80번 정본 경로) | 충족 |
| 컬럼·키·업무 정의 | `D04_컬럼정의.csv` · `85:D05` §2·§3 · `D05_FK관계.csv` · `85:N03` | 충족 |
| 원천 매핑·계층별 흐름 | `85:D06` §1~§3 · `D06_테이블계보.csv` · 컬럼 단위 = `80/08_현업공유_산출물/30_output_share/04_컬럼계보매핑.xlsx` | 충족 |
| 생성·변경 절차 | 이 문서 §3 (A4 §2·§3 · `85:D10` §5 · `85:D14` §5 요약) | 충족 |
| 미사용·임시 객체 구분 | 이 문서 §4 | 신규 |

## 1. 스키마 구성 [운영계 ZL50263 · 2026-10-26 · `_ENV/ZL50263/R00_Q01_1.csv` · `R00_Q04_1.csv`]

| 스키마 | 레이어/역할 | 테이블 | 뷰 | 소유 · 관리접근 |
|---|---|---|---|---|
| BRONZE_AGENCY · _CRM · _ERP · _GA4 · _GSC | 원천 사본(외부 LOADER 적재) | 4 · 54 · 3 · 2 · 2 | 0 | GN_DW_ADMIN · managed(AGENCY·CRM·ERP) · 일반(GA4·GSC) |
| BRONZE_BIGQUERY | GA4 export 원천 | 1,056 (일자 샤드 다수) | 0 | GN_DW_ADMIN · managed |
| SILVER | 정제 · 표준화 | 77 | 1 | GN_DW_ADMIN · managed |
| GOLD | dim · fact(테이블) · wide(뷰) | 64 | 19 | GN_DW_ADMIN(뷰 = GN_DW_DBT) · managed |
| SERVING | AI 소비(SV · Agent · Search · ML/MSTR 서빙 뷰) | 1 | 25 | GN_DW_ADMIN |
| ML | 예측 결과 · 학습 데이터셋 | 39 | 5 | GN_DW_ADMIN |
| MSTR | MSTR 이관 리포트 마트 | 10 | 13 | GN_DW_ADMIN |
| OPS | dbt 프로젝트 · 실패 저장 · 알림 설정 | 16 | 2 | GN_DW_ADMIN · managed |
| SECURITY · DBT_TEST__AUDIT · PUBLIC · LAB | 태그/정책 · dbt 감사 · 기본 · 셀프서비스(Streamlit 12) | 0 | 0 | GN_DW_ADMIN (SECURITY = managed) |
| 백업 사본(§4) | `BRONZE_CRM_2` · `SILVER_2` · `SILVER_OLD` · `GOLD_2` · `GOLD_OLD` · `OPS_2` | 52 · 61 · 57 · 46 · 46 · 10 | 0 · 0 · 0 · 17 · 14 · 1 | GN_DW_ADMIN |

- 테이블·컬럼 상세는 `85:D04`(ZL50263 기준)를 정본으로 쓴다. 전수 목록 = `_ENV/ZL50263/R00_Q02_1.csv`(1,697행) · 보존기간 전부 1일.
- 레이어 규칙(키·감사 컬럼 `DW_*` · BRONZE `_LOAD_DT`·`_BATCH_ID`·`_STDR_YM`) = `85:D04` §2.

## 2. 비테이블 객체 목록

| 종류 | 위치 | 운영계 ZL50263 (2026-10-26) | 목록 정본 |
|---|---|---|---|
| 프로시저 · 함수 | BRONZE_*(원천 적재 10) · BRONZE_CRM(월마감 1) · SILVER(수기·연간 집계 8) · MSTR(13 + 함수 2) · OPS(알림 5) · ML(23) | 프로시저 63 (+ 백업 `SILVER_2` 8) · 함수 2 | `85:D07` §3 · `_ENV/ZL50263/R00_Q03_1.csv` |
| Task | BRONZE_AGENCY `AGENCY_TASK_MASTER`(01:10) → `TASK_DGT`·`TASK_REBRDC`·`TASK_VIDEO` · BRONZE_BIGQUERY `TASK_LOAD_BIGQUERY`(01:40) · BRONZE_GA4 `TASK_GA_USER_DEMOGRAPHIC`(01:20) · BRONZE_GSC `TASK_GOOGLE_SEARCH`(01:30) · OPS `"daily"`(dbt · 06:01) · MSTR `TSK_RUN_MSTR_DAILY`(07:30) · 시각 KST | 9 (🔴 `TASK_VIDEO` suspended · 나머지 started · 90 가이드 §4 #9) | `_ENV/ZL50263/R00_Q08_1.csv` · `85:N04` |
| Alert | OPS `ALERT_DBT_WARN_SPNSR_CLS_DUP` 09:00 KST | 1 | `_ENV/ZL50263/R00_Q09_1.csv` |
| Semantic View | SERVING `SV_*` | 45 | `85:D08` · `D08_SV요약.csv` · R00_Q05_1 |
| Cortex Agent | SERVING `AGENT_EXECUTIVE`·`AGENT_MARKETING`·`AGENT_MEMBER` (+ 서비스 외 4 · §4) | 7 | `85:D09` · R00_Q06_1 |
| Cortex Search | SERVING `SEARCH_BIZ_DEFINITION` (lag 1 day · WH ANALYTICS) | 1 | R00_Q10_1 |
| DBT PROJECT | OPS `DW_PIPELINE` (+ `DW2_PIPELINE` · §4) | 2 | R04 · R00_Q07_1 |
| Stage | OPS `AGENT_SPEC_STAGE` · `BIZ_DEFINITION_STAGE` · `AD_CREATIVE_MAP_STAGE` (+ BRONZE 적재용 · ZL 14) | 14 (BRONZE 9 · OPS 3 · LAB 1 · SILVER 1) | R00_Q03_1 |
| Sequence | BRONZE_AGENCY·BIGQUERY·ERP·GA4·GSC `SEQ_SYNC_ERR_INFO` | 5 | R00_Q03_1 |
| Streamlit | LAB 12(GN_DW_ANALYST 11 · GN_DW_ADMIN 1) · 개인 `USER$CHOIH` 2 | 14 | R00_Q11_1 · R90_Q09_1 |
| 동적 테이블 · 구체화 뷰 | — | 0 | A0 §3 |

## 3. DDL 정본과 생성·변경 절차

| 대상 | DDL 정본(80번 패키지 `01_실행순서_배포SQL/`) | 변경 규칙 |
|---|---|---|
| 롤 · WH · 스키마 · FUTURE GRANT | `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` · `08_After_Deploy_DBT.sql` | 신규 계정만 전체 실행 |
| GOLD 테이블 | `03_top-down_gold/06_DDL.sql` | 🔴 기존 환경 전체 실행 금지(데이터·FK·GRANT 파괴) · 컬럼 추가 = `ALTER` + 정본 동시 수정(A4 §3-1) |
| SILVER 테이블 | `04_silver_design/08_SILVER_테이블DDL_20260714.sql` | 같음 · 신규 테이블 = `CREATE TABLE IF NOT EXISTS` 블록 |
| GOLD wide 뷰 · SILVER 뷰 | dbt 모델(`02_dbt_pipeline/10_dbt_pipeline/models/gold/wide/`) | SQL 스크립트로 만들지 않는다(A4 §2 규칙 4) |
| Semantic View | `05_SV-Agent_ai/05_01 ~ 05_30_SV_DDL_*.sql` · `22_ML_SV_DDL.sql` 등 | `CREATE OR REPLACE` 후 파일 끝 GRANT 블록 재실행(A6 F8) |
| Agent | `05_SV-Agent_ai/09_1_AGENT_생성.sql` · `09_2_AGENT_버전업.sql` + `04_SV_Agent_스펙/` YAML | 버전 추가만 · 재생성 금지(`85:D14` §5) |
| MSTR | `15_MSTR 이관 PoC/snowflake 적용 ddl/` | R05 §2 |
| 실행 순서 | `문서실행순서.md` (신규 1~51 · 기존 환경 갱신) | `85:D14` §2 · `D14_실행순서_대조.csv` |

## 4. 미사용 · 임시 · 백업 객체 구분 [신규]

운영 경로가 아닌 객체를 구분한다. 🔴 **이 문서는 목록만 제시한다.** 삭제는 인수자가 결정하고, 삭제 전 `SHOW GRANTS ON` 과 의존성(`85:D06`)을 확인한다.

| 구분 | 객체 | 위치 계정 | 상태 · 근거 | 권고 |
|---|---|---|---|---|
| 백업 사본 스키마 | `BRONZE_CRM_2` · `SILVER_2` · `SILVER_OLD` · `GOLD_2` · `GOLD_OLD` · `OPS_2` (테이블 272 · 뷰 32 · 프로시저 8) | ZL50263 | 이관 전 사본 · dbt `dev2` target 이 `_2` 를 쓴다(A4 §1) | `_2` = 시험용 유지 여부 결정 · `_OLD` = 삭제 후보 |
| 일자 접미 백업 테이블 | SILVER `ANNUAL_MBRFEE_PRDT_ACTL_DATA_261019` · `ANNUAL_MBRFEE_PRDT_ACTL_DATA_BACK` · `MM_SPNSR_CLS_AGGR_DATA_261019` | ZL50263 | 수기 업로드 재적재 전 사본(2026-10-19) | 삭제 후보 |
| 시험 테이블 | ML `TEST_COUNT` | ZL50263 | 이름상 시험용 | 삭제 후보(ML 담당 확인) |
| 서비스 외 Agent | SERVING `AGENT_MSTR` · `AGENT_OVERALL` · `ASDF` · BRONZE_CRM `AGENT_MSTR_TEST` | ZL50263 | 서비스 대상 아님(A0 §4-1) | 삭제 후보 |
| 두 번째 dbt 프로젝트 | OPS `DW2_PIPELINE` | ZL50263 | 시험용(dev2) | 유지 여부 결정 |
| 예시 프로시저 | OPS `SAMPLE_ETL_PIPELINE_PROC` · `SEND_EMAIL_ON_ERROR_SAMPLE`(소유 ACCOUNTADMIN) | ZL50263 | 알림 표준 예시(`85:D07` §3) | 참고용 유지 또는 삭제 |
| 1회성 초기화 프로시저 | MSTR `USP_F_MM_SPNSR_DVLP_SUM_INIT` | 공통 | 🔴 전체 DELETE · 일 배치 금지(A6 F5) | 유지(호출 금지 표시) |
| 행 0 테이블 | GOLD `FACT_AD_BROADCAST_CASE` · `ORG_SUCCESSION_MANUAL` · SILVER `AGENCY_AD_BROADCAST_CASE` · BRONZE_GA4/GSC `SYNC_ERR_INFO` | ZL50263(R00_Q02_1) | 원천 미발생 또는 수기 입력 대기 · 오류 기록 테이블은 0행이 정상. 🟠 `SYNC_ERR_INFO` 는 AGENCY 45 · ERP 16 · BIGQUERY 3 행(AGENCY 최종 기록 2026-10-26 17:19) ⇒ 원천 시트 숫자 열의 `-`·`%`·공란 등(90 가이드 §4-1 T10) | 유지 |
| dbt 실패 저장 테이블 | OPS `NOT_NULL_*` · `ACCEPTED_VALUES_*` · `WARN_*` (12) | 공통 | dbt `store_failures` 결과 · 다음 build 에서 재생성 | 유지 · 행 있으면 A6 F3 |
| 비활성 스냅샷 | dbt `snapshots/` 11 | 공통 | 🔴 영구 미가동(DEC-61) · SNAPSHOT 스키마 없음 | 유지(가동 금지) |
| 개인 Streamlit | `USER$CHOIH` 2 · LAB 의 이름 없는 앱(자동 ID) | ZL50263(R90_Q09_1) | 개인 워크스페이스 앱은 사용자 삭제 시 함께 사라진다(A1 §2-3) | 필요한 앱만 SERVICE 롤 소유로 이관 |

## 5. 인수자 확인 절차 (현업 확인 기준: 「대표 데이터의 원천부터 최종 테이블까지 추적 · 시험 환경에서 DDL 로 대표 객체 생성」)

1. **추적**: 대표 경로 1개를 `D06_테이블계보.csv` 로 따라간다. 예) `BRONZE_CRM.TM_PM_MBRFEE_ACMSLT → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_MEMBER_FEE → GOLD.WIDE_MEMBER_FEE → SERVING.SV_MEMBER_FEE`. 같은 경로의 건수·금액 대사는 R10 Q01·Q02.
2. **생성 시험**(시험 계정 또는 사본 스키마 · 운영 스키마 금지):
```sql
USE ROLE GN_DW_ADMIN;
CREATE SCHEMA IF NOT EXISTS GN_DW.ZZ_HANDOVER_TEST;
-- 06_DDL.sql 에서 대표 테이블 1개(예: DIM_SPONSORSHIP) 블록만 복사 · 스키마명을 ZZ_HANDOVER_TEST 로 바꿔 실행
SHOW COLUMNS IN TABLE GN_DW.ZZ_HANDOVER_TEST.DIM_SPONSORSHIP;   -- D04_컬럼정의.csv 와 컬럼·타입 대조
DROP SCHEMA GN_DW.ZZ_HANDOVER_TEST;                              -- 시험 후 정리
```
3. §4 목록을 보고 삭제·유지 결정을 `특이사항`에 기록한다.
