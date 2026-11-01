---
doc_id: A4
title: dbt 파이프라인 개발자 가이드
version: 0.1
as_of: 2026-10-20 (80번 사본 해시 대조 포함)
source_docs:
  - 80_인수인계_프로젝트완료 및 유지보수용/02_dbt_pipeline/10_dbt_pipeline/README.md (142행 전량)
  - 80_인수인계_프로젝트완료 및 유지보수용/02_dbt_pipeline/10_dbt_pipeline/dbt_project.yml (387행 전량)
  - 80_인수인계_프로젝트완료 및 유지보수용/01_실행순서_배포SQL/10_dbt_pipeline/01_deploy_dbt_project.sql (61행 전량)
  - 80_인수인계_프로젝트완료 및 유지보수용/01_실행순서_배포SQL/10_dbt_pipeline/02_dbt_parse_compile_build.sql (179행 전량)
  - 80_인수인계_프로젝트완료 및 유지보수용/01_실행순서_배포SQL/문서실행순서.md (87행 전량)
  - 80_인수인계_프로젝트완료 및 유지보수용/06_일배치_모니터링/11_일적재pipeline 구성/00_개요_및_실행순서.md (123행 전량)
  - 워크스페이스 10_dbt_pipeline/profiles.yml (40행) · macros/generate_schema_name.sql (11행) — 80번 패키지에 profiles 부재(DR-18)
  - 85_실제 인수인계 문서/_드리프트/드리프트_통합.md (DR-01·05·06·13·18·19·21)
source_queries:
  - A6_일배치_장애대응_런북.sql Q01·Q02·Q04·Q08 · A0_환경실사_baseline.sql Q10
owner: TBD
status: draft (S4 게이트 확인 대기)
---

# A4. dbt 파이프라인 개발자 가이드

🔴 **dbt 명령(parse·compile·build·run·test)은 사람이 실행한다.** 이 문서는 명령과 판정 기준만 준다.

## 1. [공통] 한눈에 보기

| 항목 | 값 | 근거 |
|---|---|---|
| 프로젝트 객체 | `GN_DW.OPS.DW_PIPELINE` (DBT PROJECT · 소유 GN_DW_ADMIN · dbt 1.9.4) | A0 §4-1 |
| 소스 위치 | 워크스페이스 `10_dbt_pipeline/` (80번 `02_dbt_pipeline/10_dbt_pipeline` 과 210/210 해시 일치 · profiles 제외) | DR-18 |
| 실행 롤 · WH | **GN_DW_DBT** · GN_DW_ETL_WH (profiles.yml 3 target 공통) | profiles.yml :14·:27·:36 |
| target | `dev`(기본 · SILVER/GOLD) · `dev2`(BRONZE_CRM_2 → `_2` 스키마 · 테스트) · `prod` | profiles.yml |
| 운영 명령 | `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build'` (`run` 금지 · `build` = run + test 게이트) | README :22 |
| 스냅샷 | 🔴 **영구 미가동**(DEC-61) — `+enabled: false` 를 바꾸지 않는다 · SNAPSHOT 스키마를 만들지 않는다 | dbt_project.yml :381~388 |

- 문서에 `GN_DW_ENGINEER 로 build` 라고 적힌 곳(01_deploy :20~21·:48 · 03_일배치 :6)은 낡았다 — 실행 롤은 GN_DW_DBT 다(DR-19).
- 배포(ADD VERSION) 때 GN_DW_ADMIN 으로 compile 이 자동으로 한 번 돈다. 이것은 정상이다(DR-13).

## 2. [공통] 레이어 규약 — 「구조는 DDL, 데이터는 dbt」

| 레이어 | 구조 정본 | dbt 전략(dbt_project.yml) | 핵심 규칙 |
|---|---|---|---|
| SILVER | `04_silver_design/08_SILVER_테이블DDL_*.sql` | incremental + **append** + pre-hook `silver_purge` + `full_refresh: false` + `append_new_columns` | 매 run TRUNCATE 후 전량 재적재(멱등) · `merge` 모델 0(CRM_MEMBER_DEV 도 append · DR-05) |
| GOLD dim | `03_top-down_gold/06_DDL.sql` | incremental(기본 merge · `unique_key`) + `append_new_columns` | UPSERT · DDL 구조 보존 |
| GOLD fact | `03_top-down_gold/06_DDL.sql` | incremental + append + pre-hook `gold_fact_purge` + `append_new_columns` | 범위 팩트는 `RANGED_FACTS` 만 창 DELETE |
| GOLD wide | dbt 소유(`models/gold/wide/` · `_wide_schema.yml`) | view · `gn_view_commented` | 뷰 COMMENT 는 yml 이 정본 · GOLD 뷰 19 전부 GN_DW_DBT 소유(실측) |

규칙(어기면 에러 없이 데이터가 줄어든다):
1. 🔴 **모델 파일에 `pre_hook` 을 쓰지 않는다.** dbt 는 hook 을 누적한다 — 프로젝트 TRUNCATE + 모델 DELETE 가 둘 다 돌아 창 크기로 쪼그라든다(:210~219 · :264~273).
2. 🔴 **`--full-refresh` 는 막혀 있다**(`full_refresh: false`). CTAS 가 DDL·FK·COMMENT 를 파괴하기 때문이다. 전량 재적재 경로는 §5 백필뿐이다.
3. 🔴 **CAST 로 DDL 타입을 맞춘다.** 타입이 다르면 dbt 가 `ALTER … SET DATA TYPE` 을 내고 DBT 롤에는 OWNERSHIP 이 없어 `003001` 로 실패한다(:232~238).
4. 뷰는 SQL 스크립트로 만들지 않는다 — `ref()` 위상정렬·리니지가 필요하다(:309~317). GOLD `FUTURE VIEWS` grant 가 재생성 뷰에 권한을 자동으로 준다 ⇒ 그 grant 를 지우지 않는다.

## 3. [공통] 모델 추가·수정 절차

### 3-1. 컬럼 추가 (SILVER·GOLD 테이블 공통 · README :131~137)

1. 구조 정본 DDL 파일 수정(SILVER = 08 DDL · GOLD = 06_DDL).
2. `ALTER TABLE … ADD COLUMN …` 실행(GN_DW_ADMIN).
3. `INFORMATION_SCHEMA.COLUMNS` 로 컬럼 존재 확인 — 🔴 건너뛰면 4~5 가 무증상 실패한다.
4. dbt 모델 수정(CAST 로 DDL 타입 일치).
5. `build --select <모델>+`(사람 실행).
6. 🔴 **신규 컬럼 비NULL 건수 검증** — 행수만 보면 통과해 버린다(「ERROR=0 은 성공 신호가 아니다」).

### 3-2. 새 모델 추가

1. 테이블 모델이면 구조 DDL 을 먼저 만든다(없으면 incremental 첫 run 이 CTAS 로 구조 없이 만든다 · :208).
2. 새 스키마가 필요하면 07 §D 패턴(USAGE + ALL + FUTURE) + DBT 롤 부여를 먼저 한다(A1 §3-1 · A2).
3. 범위 증분 모델이면 `macros/silver_purge.sql` `RANGED_MODELS` 또는 `macros/gold_fact_purge.sql` `RANGED_FACTS` 에 등재한다.
4. 뷰 모델이면 `_wide_schema.yml` 에 description/columns 를 쓴다(`warn_gold_view_comment_coverage` 가 본다).

### 3-3. 기존 환경 증분 갱신 (문서실행순서.md 「기존 환경 갱신」)

- 신규 구축은 문서실행순서 1~51 을 위에서부터 실행한다. 이미 구축된 환경만 「기존 환경 갱신」 목록을 **위에서부터** 실행한다.
- 🔴 함정(문서실행순서 :67): O241 `32_…배포순서.sql` 의 **D1-a(소유자 열 선추가)를 건너뛰면 dbt 가 `003001`(MODIFY 권한 없음)로 실패한다**. 원인 = §2 규칙 3 과 같다(테이블 구조 변경은 ADMIN 몫).
- 운영계 주의: `billing_coverage_start_month: 202201` 은 운영계도 같다 · GA 수치만 BigQuery 범위 때문에 다르다(문서실행순서 :85~87 · DR-14).

## 4. [공통] 배포 → 검증 → 실행 (🔴 사람이 실행)

```sql
-- ① 재배포 (GN_DW_ADMIN) — 코드 수정 후 새 버전
USE ROLE GN_DW_ADMIN;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION <버전라벨>
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;

-- ② 검증 → 실행 (GN_DW_DBT)
USE ROLE GN_DW_DBT;
USE WAREHOUSE GN_DW_ETL_WH;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';            -- 부분 = 'build --select <모델>+'
-- 실패 지점부터 이어서: EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='retry';
```

- 🔴 **재배포 + build 직후 매번** BIGQUERY 체인 일자 수를 대조한다(A6 SQL Q04 · `02_dbt_parse_compile_build.sql` [3-3]). 4계층 일자 수가 같고 WARN 감시 테이블이 0행이어야 한다.
  - 이유 = BIGQUERY 계열은 **롤링 윈도우 증분**(`bigquery_lookback_days: 3`)이라, 재배포로 비어도 창 밖은 다시 채워지지 않는다(O178 실사고 · ERROR 0).
- 재배포 원천 경로 `USER$.PUBLIC."snowflake_files"` 는 **배포하는 사람의 개인 워크스페이스**다. 운영계는 그 사람의 워크스페이스로 바꾼다.
- 운영계 이관 시 `10_dbt_pipeline/profiles.yml` 을 반드시 함께 옮긴다(80번 패키지에 없다 · DR-18).

## 5. [공통] 백필 (BIGQUERY 계열 · 정본 = `02_dbt_parse_compile_build.sql` Step 3 [3-3])

```sql
USE ROLE GN_DW_DBT;
-- ① 창 렌더 확인
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ARGS='compile --select BIGQUERY_BASIC --vars ''{"bigquery_dt_ranges": [["YYYY-MM-DD", "YYYY-MM-DD"]]}''';
-- ② 실행
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ARGS='build --select BIGQUERY_BASIC+ --vars ''{"bigquery_dt_ranges": [["YYYY-MM-DD", "YYYY-MM-DD"]]}''';
-- ③ A6 SQL Q03·Q04 대사
```

- 🔴 `--vars` 는 **`EXECUTE DBT PROJECT` 경로 + JSON 표기에서만** 전달된다. Workspaces dbt 클라이언트에서는 조용히 무시된다(:97~108).
- 하한은 원천 최소일과 대조한다(A0 Q09).
- `dbt_project.yml` 의 `bigquery_dt_ranges` 주석 슬롯을 여는 방법은 대체 경로다. 열었다면 반드시 다시 잠그고 재배포한다(상주 시 이중 샘플링).

## 6. [ENV] 정기 실행 실체

| 항목 | 운영계 |
|---|---|
| dbt 정기 Task | `GN_DW.OPS."daily"` 06:01 KST · 소유 GN_DW_DBT(MSTR 07 :11~17 기재 · 미검증) |
| dev2 테스트(`_2` 스키마 · `TASK_DBT_DAILY_DEV2`) | TBD(미검증) |
| 최근 build | TBD(미검증) |

- 🔴 `02_dbt_parse_compile_build.sql` Step 4 의 `TASK_DW_SNAPSHOT_DAILY → TASK_DW_BUILD_DAILY` DAG 안은 쓰지 않는다 — 루트가 snapshot 이라 DEC-61 과 충돌한다(DR-01). 정기화가 필요하면 build 단일 Task 로 만든다(A6 §5).

## 7. [공통] 자주 만나는 오류

| 오류 | 원인 | 처치 |
|---|---|---|
| `003001 … must have MODIFY granted on TABLE` | 모델이 DDL 과 다른 타입·컬럼을 내서 dbt 가 ALTER 시도 | 모델 CAST 로 DDL 타입 맞춤 · 컬럼 추가면 §3-1 ① ② 먼저 |
| `002003 … does not exist or not authorized` | 대개 **권한** 문제(스키마 USAGE·SELECT 부재) | 객체를 다시 만들기 전에 `SHOW GRANTS TO ROLE GN_DW_DBT` · A2 재생성 |
| build SUCCESS 인데 행수 급감 | 롤링 윈도우 · pre_hook 누적 · 재배포 순서 | A6 Q04 일자 대조 → §5 백필 |
| 신규 컬럼이 생기지 않음 | §3-1 ③ 생략 | INFORMATION_SCHEMA 확인 후 재실행 · 비NULL 건수 검증 |
| `Failed to use role GN_DW_DBT: 002043` | DBT 롤이 없는 계정에서 CREATE DBT PROJECT | 07 §D.9 를 프로젝트 생성 **전**에 실행 |
