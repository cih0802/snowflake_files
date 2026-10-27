---
doc_id: R05
title: "[현업 D05] dbt 실행과 배포"
version: 0.2
as_of: 2026-10-26 (운영계 ZL50263 점검 `_ENV/ZL50263/R00_Q07~Q09` · `R90_Q10` + 워크스페이스 소스)
source_docs:
  - 85_실제 인수인계 문서/10_실무자_인수인계/A4_dbt_파이프라인_개발자가이드.md §4·§5 (v0.1)
  - 85_실제 인수인계 문서/10_실무자_인수인계/A6_일배치_장애대응_런북.md §1~§6 (v0.1)
  - 85_실제 인수인계 문서/20_정식산출물/N04_배치SLA_스케줄정의서.md (v1.0) · D07_ETL_파이프라인설계서.md §4 (v1.0) · D14_인수인계서.md §2 (v1.0)
  - Snowflake 문서 ALTER DBT PROJECT · EXECUTE DBT PROJECT (2026-10-25 조회)
source_queries:
  - _ENV/ZL50263/A0_Q05_1.csv (Task) · A0_Q05_2.csv (Alert) · A0_Q04_4.csv (dbt project)
  - _ENV/ZL50263/R00_Q07_1.csv · R00_Q08_1.csv · R00_Q09_1.csv · R90_Q10_1.csv (최근 7일 Task 결과)
owner: TBD
status: review
---

# R05. dbt 실행과 배포 (현업 자료 ID D05)

## 0. 별첨 요구 → 제출 위치

| 별첨에 포함할 내용 | 제출 위치 | 판정 |
|---|---|---|
| 실행 위치 · 서비스 계정 · 환경변수 참조 | 이 문서 §1 · A4 §1 | 충족 |
| 실행 명령/Job · 스케줄 · 시간대 · 선후행 | 이 문서 §2 · A6 §1·§2 · `85:N04` §1·§2 | 충족 |
| 외부 오케스트레이터 | 이 문서 §2 | 부분 → 보완 |
| 로그 · 실행 결과 · 알림 | 이 문서 §3 · A6 §3 F1·F3·F4 · A1 §5 · `85:D11` §1 | 충족 |
| 변경 검토 · 테스트 · 배포 · 되돌리기 | 이 문서 §4 | 부분 → 보완(계정별 버전 방식 차이) |
| 실패 구간 재실행 · 과거 구간 재처리 · 전체 재생성 조건 | 이 문서 §5 · A6 §4 · A4 §5 | 부분 → 보완 |

## 1. 실행 위치 · 계정 · 변수

| 항목 | 값 |
|---|---|
| 실행 위치 | Snowflake 내부(`EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE`) · 별도 서버 없음 |
| 실행 주체 | 롤 **GN_DW_DBT**(dbt 전용 최소권한) · WH GN_DW_ETL_WH · 정기 실행은 Task 소유 롤 권한으로 돈다(사람 계정 비의존) |
| 서비스 사용자 | 별도 dbt 서비스 사용자 없음 — Task 가 소유 롤로 실행한다. 수동 실행은 GN_DW_DBT 를 받은 사람 계정 |
| 환경변수 · 비밀 | `env.yml` · `ENV_VARS` · Snowflake secret **미사용**. 계정·사용자 정보는 profiles 에 없음(세션 인증). 실행 파라미터는 `dbt_project.yml` vars 와 `--vars` JSON 뿐(A4 §5) |

## 2. 스케줄 · 선후행 · 운영계 ZL50263 (시각 = Asia/Seoul · 2026-10-26 확인)

| 시각 | 단계 | 객체 | 소유 | 선후행 |
|---|---|---|---|---|
| 01:10 | 대행사 광고 적재 | `BRONZE_AGENCY.AGENCY_TASK_MASTER` → `TASK_DGT` · `TASK_REBRDC` · `TASK_VIDEO` | GN_DW_ADMIN | DAG(루트 → 자식 3) |
| 01:20 | GA4 인구통계 | `BRONZE_GA4.TASK_GA_USER_DEMOGRAPHIC` | GN_DW_ADMIN | 독립 |
| 01:30 | 서치콘솔 | `BRONZE_GSC.TASK_GOOGLE_SEARCH` | GN_DW_ADMIN | 독립 |
| 01:40 | BigQuery(GA4 이벤트) | `BRONZE_BIGQUERY.TASK_LOAD_BIGQUERY` | GN_DW_ADMIN | 독립 |
| (외부) | CRM·ERP 원천 | 외부팀 LOADER 적재 · `SILVER.BIGQUERY_REFINED_DATA` 외부 Python 적재 | GN_DW_LOADER | 🔴 Snowflake 가 완료 신호를 받지 않는다 — 시각으로만 맞춘다 |
| 06:01 | **dbt build** | `OPS."daily"` → `EXECUTE DBT PROJECT … ARGS='build'` | GN_DW_DBT | 고정 시각 |
| 07:30 | MSTR 일 적재 | `MSTR.TSK_RUN_MSTR_DAILY` → `USP_RUN_MSTR_1ST`(전월+당월) | GN_DW_ADMIN | 🔴 dbt 의 `AFTER` 로 걸 수 없음(스키마·소유 롤이 다름) ⇒ 고정 시각 |
| 09:00 | dbt WARN 메일 | `OPS.ALERT_DBT_WARN_SPNSR_CLS_DUP` | GN_DW_ADMIN | 조건 충족 시 메일 |
| 월 1회 | 월마감 | `BRONZE_CRM.SP_EXEC_MONTH_END(YYYYMM)`(SILVER 집계 · ML 예측 연쇄) | GN_DW_LOADER | 🔴 dbt build 와 동시 실행 금지 |

- 외부 오케스트레이터(Airflow 등) **없음**. 스케줄러 = Snowflake Task 뿐이다. 외부 의존은 CRM·ERP 원천 적재(LOADER 팀)와 외부 Python 적재 1개다(D03 범위).
- SLA(제안 · 미확정) = `85:N04` §3. 시각 근거 = `_ENV/ZL50263/R00_Q08_1.csv` · Alert `R00_Q09_1.csv`(started · 2026-10-26 19:15 재생성).

### 2-1. 최근 7일 실행 결과 (2026-10-20~26 · `_ENV/ZL50263/R90_Q10_1.csv`)

| 객체 | 결과 | 판정 |
|---|---|---|
| `AGENCY_TASK_MASTER` · `TASK_DGT` · `TASK_REBRDC` · GA4 · GSC · BIGQUERY · `TSK_RUN_MSTR_DAILY` | SUCCEEDED 7/7 | 🟢 |
| `TASK_VIDEO` | SUCCEEDED 4 (마지막 2026-10-23 01:10) · 🟠 **suspended**(10-23 11:59 생성자 LEESH 재생성) · 10-26 21:23 작업자가 resume 했다가 원상복구 | 🟠 생성자 결정 대기 → 90 가이드 §4 #9 · T1 |
| `OPS."daily"`(dbt build) | FAILED 5 · SUCCEEDED 2 (마지막 성공 10-21) · 실패 모델 `AGENCY_AD_ROW_VIDEO` · `AGENCY_AD_ROW_REBRDC`(10-23~26 · 원천 컬럼 개명 O260 미반영 버전 · 수정본 반영 후 정상) · `CRM_HOLIDAY`(10-22 · SILVER CREATE TABLE 권한 · 해소) | 🟢 2026-10-26 수동 build 정상 · 10-27 06:01 정기 실행 확인 남음(90 가이드 T2) |

- 🆕 [재검측 2026-10-27 00:45 KST · `_ENV/ZL50263/R91_Q01_1.csv` · `R91_Q02_1.csv`]
  - `TASK_VIDEO` = 여전히 `suspended`(USER_SUSPENDED · 10-26 22:21) ⇒ T1 그대로.
  - `daily` = 10-26 06:01 FAILED(운영계 반영 전) · 다음 = 10-27 06:01 SCHEDULED ⇒ T2 판정 보류. 원천 Task 7종 10-26 전부 SUCCEEDED.
  - dbt 기본 버전 = `VERSION$29`(2026-10-26 18:42 KST · `R91_Q06_1.csv`).

- 🔴 dbt build 는 모델 일부가 실패해도 나머지는 갱신된다. 실패 모델과 그 하위만 갱신이 멈춘다 ⇒ 실패가 이어지면 영상·재송출 광고 · 휴일 달력 기반 지표가 낡는다.

## 3. 로그 · 실행 결과 · 알림

| 확인 대상 | 방법 | 근거 |
|---|---|---|
| dbt 실행 결과(성공/실패 · 오류 메시지) | A6 SQL Q01 (`QUERY_HISTORY` 의 EXECUTE DBT PROJECT) · Snowsight » Projects » dbt projects » 실행 이력 | A6 §3 F1 |
| Task 실행 이력 · 상태 | A6 SQL Q05 (`TASK_HISTORY` · `SHOW TASKS`) | A6 F6 |
| 데이터 품질 경고 | OPS 실패 저장 테이블(A6 Q03) · 메일 = Alert | A6 F3 |
| MSTR 적재 로그 | `GN_DW.MSTR.BCHLOG`(오류 = `ERRMSG`) | A6 F5 |
| 알림 수신자 | `OPS.ALERT_RECIPIENT_CONFIG`(`IS_DBT_ALERT_YN`) · PIPELINE_ADMIN 1명(운영 CHOIH) · 🟢 `"daily"` 실패 → `ALERT_DAILY_TASK_FAILED`(09 §7 · A8-10 해소 10-27) | A1 §5 |
| dbt 산출물(manifest · run_results · 로그 zip) | `SYSTEM$LOCATE_DBT_ARTIFACTS('<query_id>')` · `SYSTEM$LOCATE_DBT_ARCHIVE` | Snowflake 문서 |

## 4. 변경 → 검토 → 테스트 → 배포 → 되돌리기

| 단계 | 방법 |
|---|---|
| ① 변경 | 워크스페이스 `10_dbt_pipeline/` 수정. 테이블 구조 변경이면 DDL 정본 + `ALTER` 먼저(A4 §3-1) |
| ② 검토 | 🟠 현재 코드 리뷰 체계(PR) 없음 — R11 §1 Git 전환 후 PR 리뷰를 권고. 그전까지는 변경 전후 파일 사본 + 이슈 원장(`80/07_운영런북_이슈/20_issue/`) 기록 |
| ③ 테스트 | `EXECUTE DBT PROJECT FROM WORKSPACE USER$.PUBLIC."<워크스페이스>" ARGS='build --select <모델>+ --target dev2'`(배포 전 · 사본 스키마) 또는 시험 계정 |
| ④ 배포 | **버전형(운영계 · 현재 기본 `VERSION$29`)**: `ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE ADD VERSION FROM '<워크스페이스>/versions/live/10_dbt_pipeline'` → 새 `VERSION$n` 이 기본(A4 §4). 참고: 새로 만든 프로젝트는 live 형(`DEPLOY FROM`)이 될 수 있다(`DW2_PIPELINE` = LIVE) |
| ⑤ 배포 후 검증 | `parse` → `compile` → `build` · BIGQUERY 일자 수 대조(A6 Q04) · 실패 저장 0행(A6 Q03) |
| ⑥ 되돌리기 | **버전형(운영계)**: 직전 정상 버전을 확인(`SHOW VERSIONS IN DBT PROJECT …`)하고 그 버전 소스로 다시 배포한다. **live형**: 이전 버전이 남지 않는다 ⇒ 🔴 배포 전에 소스 사본(Git tag 또는 `80_…/02_dbt_pipeline` 같은 폴더 사본)을 남기고, 되돌릴 때 그 사본을 `DEPLOY FROM` 한다 |
| ⑦ 데이터 되돌리기 | 코드를 되돌린 뒤 영향 모델만 `build --select <모델>+` 로 재적재(멱등 · §5). 테이블 손상은 R09 §2(Time Travel 1일) |

- 🔴 `CREATE OR REPLACE DBT PROJECT` 는 실행 이력을 지울 수 있다 — 배포는 `ADD VERSION`/`DEPLOY FROM` 만 쓴다(Snowflake 문서 경고).
- Agent·SV 배포·롤백은 R06 §1 · `85:D09` §4.

## 5. 재실행 · 재처리 · 전체 재생성 조건

| 상황 | 방법 | 조건 · 주의 |
|---|---|---|
| 실패 지점부터 재개 | `ARGS='retry'` | 직전 실행의 `run_results` 기준 · 원인 수정 후 |
| 특정 모델·하위만 | `ARGS='build --select <모델>+'` | SILVER·GOLD 는 TRUNCATE/창 DELETE + append 라 재실행해도 중복이 생기지 않는다 |
| 과거 구간(GA 계열 · 롤링 창 밖) | `build --select BIGQUERY_BASIC+ --vars '{"bigquery_dt_ranges": [["YYYY-MM-DD","YYYY-MM-DD"]]}'` | 🔴 `EXECUTE DBT PROJECT` 경로 + JSON 표기에서만 동작(A4 §5) · 하한 = 원천 최소일 |
| 과거 월(MSTR) | `CALL GN_DW.MSTR.USP_RUN_MSTR_1ST('<YYYYMM>','OPER',FALSE)` 해당 월만 | 🔴 `USP_F_MM_SPNSR_DVLP_SUM_INIT` 호출 금지(전체 DELETE) |
| 월마감 재처리 | `CALL GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END('<YYYYMM>')`(LOADER) | dbt build 와 겹치지 않게 |
| 전체 재생성 | `--full-refresh` 는 **막혀 있다**(`full_refresh: false` · DDL·FK·COMMENT 파괴 방지). 전량은 일반 `build` 가 SILVER 를 매번 전량 재적재하므로 따로 필요 없다 | 예외 = 테이블 자체가 손상됐을 때만: DDL 정본으로 테이블 1개 재생성(신규 환경 규칙 · GRANT 재실행) → `build --select <모델>` |
| 신규 계정 재구축 | `문서실행순서.md` 1~51 | `85:D14` §2 · A6 §7(RUNBOOK §11) |

## 6. 인수자 확인 절차 (현업 확인 기준: 「정상 실행과 실패 후 재실행 · 시험 변경의 배포·되돌리기 실습 · 운영 스케줄과 원천 적재 순서 대조」)

1. **정상 실행**: 운영계에서 최근 `"daily"` 실행이 SUCCEEDED 인지 A6 SQL Q05 로 확인.
2. **실패 후 재실행**(시험 계정 또는 `dev2`): 존재하지 않는 모델을 고의로 참조해 build 실패 → 원복 → `ARGS='retry'` 성공 확인.
3. **배포·되돌리기 실습**: 모델 COMMENT 한 줄 변경 → §4 ④ 배포 → `SHOW VERSIONS` 로 버전 증가(버전형) 확인 → §4 ⑥ 으로 되돌리고 COMMENT 원복 확인.
4. **스케줄 대조**: `SHOW TASKS IN DATABASE GN_DW;` 결과의 schedule·state 를 §2 표와 대조 · 원천(LOADER) 적재 완료 시각이 06:01 보다 앞서는지 LOADER 팀과 확인.
