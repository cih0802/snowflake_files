---
doc_id: D07
title: ETL / 파이프라인 설계서
version: 1.0
as_of: 2026-10-20 (IW20760 실측 · 워크스페이스 10_dbt_pipeline 파일)
source_docs:
  - 85_실제 인수인계 문서/10_실무자_인수인계/A4_dbt_파이프라인_개발자가이드.md · A6_일배치_장애대응_런북.md (원본 · 이 문서는 고객 제출용 재편집)
  - 10_dbt_pipeline/dbt_project.yml (387행) · profiles.yml · 02_dbt_parse_compile_build.sql · 03_MSTR_이관/…/06·07 MSTR SQL
source_queries:
  - 85_실제 인수인계 문서/_근거쿼리/B1_구조_근거.sql (Q10 프로시저·함수)
  - 85_실제 인수인계 문서/10_실무자_인수인계/A6_일배치_장애대응_런북.sql (실행 이력 · Task · Alert · MSTR)
owner: TBD
status: review
---

# D07. ETL / 파이프라인 설계서

## 1. 파이프라인 구성 (4 경로)

| 경로 | 엔진 | 실행 롤 · WH | 입력 → 출력 | 일정 |
|---|---|---|---|---|
| ① 원천 적재 | 외부(원천 담당 · 외부 Python) | GN_DW_LOADER · ETL_WH | CRM·ERP·대행사·GSC → BRONZE_* · GA4 → `SILVER.BIGQUERY_REFINED_DATA` · 수기 → `SILVER.MM_*`·`ANNUAL_*` | 원천 담당 일정 |
| ② dbt DW_PIPELINE | Snowflake DBT PROJECT(dbt 1.9.4) | GN_DW_DBT · ETL_WH | BRONZE·외부 SILVER → SILVER 61 → GOLD 79 | [ENV] 개발 = 수동 · 운영 = `"daily"` 06:01 KST(기재 · 미검증) |
| ③ MSTR 적재 | 저장 프로시저(SQL) | GN_DW_ADMIN · ETL_WH | BRONZE_CRM → MSTR 23(테이블 10 · 뷰 13) | [ENV] 개발 = 수동 · 운영 = `TSK_RUN_MSTR_DAILY` 07:30 KST(기재 · 미검증) |
| ④ ML 예측 | 외부 ML 프로시저(이관 범위 밖) · 시뮬레이터 SP 1 | — | 예측 결과 → `GN_DW.ML` 12 테이블 → SERVING ML 뷰 | 월마감(`SP_EXEC_MONTH_END`) — 개발계 부재 |

```mermaid
graph LR
  E1[① 원천 적재] --> D[② dbt build]
  D --> M[③ MSTR 적재<br/>전월+당월]
  D --> W[dbt 실패 저장 테이블<br/>OPS 11]
  W --> AL[Alert 09:00 KST]
  ML[④ ML 결과] --> SV[SERVING 뷰 · SV · Agent]
  D --> SV
  M --> SV
```

## 2. dbt 설계 (② · 정본 = dbt_project.yml)

| 레이어 | 모델 | 전략 | pre-hook | 스키마 변경 |
|---|---|---|---|---|
| SILVER | 61 (crm 38 · bigquery 9 · agency 8 · erp 4 · bridge 2) | incremental + **append** + `full_refresh: false` | `silver_purge` — 전량 TRUNCATE · 범위 모델(`RANGED_MODELS`)은 창 DELETE | `append_new_columns` |
| GOLD dim | 28 | incremental(기본 merge · `unique_key`) + `full_refresh: false` | — | `append_new_columns` |
| GOLD fact | 32 | incremental + append + `full_refresh: false` | `gold_fact_purge` — 전량 TRUNCATE · 범위 팩트(`RANGED_FACTS`)는 창 DELETE | `append_new_columns` |
| GOLD wide | 19 | view(`gn_view_commented`) | — | `_wide_schema.yml` 이 COMMENT 정본 |

- 구조는 DDL 이 소유하고 dbt 는 데이터만 채운다(SILVER = `08_SILVER_테이블DDL` · GOLD 테이블 = `06_DDL.sql`).
- BIGQUERY 계열 = **롤링 윈도우 증분**(`bigquery_lookback_days: 3`). 재배포로 비면 창 밖이 자동으로 채워지지 않는다 ⇒ 재배포 후 일자 수 대조 필수(A6 Q04).
- 백필 = `EXECUTE DBT PROJECT … ARGS='build --select <모델>+ --vars ''{"bigquery_dt_ranges": [[…]]}'''`(A4 §5).
- 스냅샷 = 🔴 영구 미가동(DEC-61 · `+enabled: false` · `snapshots/` 11 파일은 기록용).
- dbt 테스트 실패 저장 = OPS(`store_failures` · 11 테이블 · GN_DW_DBT 소유). 🔴 개발계 현재 4종에 실패 행(원천 코드값 `')'` · DR-24).

## 3. 프로시저 · 함수 (Q10 실측 · 20)

| 스키마 | 종류 | 이름 | 언어 | 역할 |
|---|---|---|---|---|
| MSTR | 프로시저 13 | `USP_RUN_MSTR_1ST` (오케스트레이션) · `USP_D_*` 7(차원) · `USP_F_MM_SPNSR_DVLP` · `_SUM` · `_SUM_INIT`(🔴 전체 초기화 · 일 배치 금지) · `USP_BCHLOG` · `USP_BCHERR` | SQL | MSTR 적재(③) |
| MSTR | 함수 2 | `FN_MM_ACT_DATE` · `FN_MM_SPNSR_DVLP` | SQL | 기준월 활동회원 · 개발실적 |
| OPS | 프로시저 4 | `USP_SYNC_ALERT_RECIPIENTS` · `USP_SEND_PIPELINE_ERROR_ALERT` · `SAMPLE_ETL_PIPELINE_PROC`(Python) · `USP_SEND_DBT_WARN_SPNSR_CLS_DUP`(SQL) | Python 3 · SQL 1 | 알림(수신자 동기화 · 공통 발송 · 예시 · dbt 경고) |
| ML | 프로시저 1 | `SP_SIMULATE_CAMPAIGN_DVLP` | SQL | 광고비 변동 시뮬레이션(SV_ML_REALTIME_SIMULATOR 와 짝) |

- 전부 GN_DW_ADMIN 소유다. 월마감 `BRONZE_CRM.SP_EXEC_MONTH_END` 는 개발계에 없다(이관 범위 밖 · 운영계 확인 대상).

## 4. 스케줄 · 알림 [ENV]

| 객체 | IW20760(개발) | 운영계 |
|---|---|---|
| dbt 일배치 Task | 없음(존재 이력 없음) | `GN_DW.OPS."daily"` 06:01 KST — TBD(미검증) |
| MSTR 일 적재 Task | 없음 | `GN_DW.MSTR.TSK_RUN_MSTR_DAILY` 07:30 KST — TBD(미검증) |
| dbt 경고 Alert | `OPS.ALERT_DBT_WARN_SPNSR_CLS_DUP` 09:00 KST · started | TBD(미검증) |
| 2026-10-20 결정 | 개발계는 수동 실행 유지(A8-09) | — |

- MSTR Task 는 dbt Task 와 DAG 로 묶이지 않는다(다른 스키마·소유 롤) ⇒ 고정 시각 운영. dbt 가 07:30 을 넘기면 두 기준이 다른 BRONZE 를 볼 수 있다.

## 5. 운영 · 장애

- 배포·실행·백필 절차 = A4 §4~§5. 장애 유형 9종(F1~F9)·재처리 원칙 = A6 §3~§4. 정기 점검 = A7.

## 6. 드리프트

| # | 문서 기재 | 실측 | 처리 |
|---|---|---|---|
| DR-01 | Step 4 일일 DAG(snapshot → build) · `TASK_DBT_DAILY_DEV2` | 미배포 · 루트 snapshot 은 DEC-61 과 충돌 · dev2 는 테스트용 | 개발계 수동 유지(결정) |
| DR-19 | 01_deploy · 03_일배치「실행 롤 = ENGINEER」 | 실행 롤 = GN_DW_DBT | 기록만 |
| DR-21 | 운영계 Task 2종 기재 | 개발계 0 | 운영계 실측 대기 |
| DR-24 | dbt 경고 감시 = 1종 | 실패 저장 11종 · 4종에 실패 행 | A6 Q03 동적화 · 원천 정정 요청 |
| — | dbt README「65 models」 | 140 models | 기록만 |
