---
doc_id: R04
title: "[현업 D04] dbt 프로젝트"
version: 0.2
as_of: 2026-10-26 (운영계 ZL50263 점검 `_ENV/ZL50263/R00_Q07_1` · `R90_Q06_1` · `R90_Q08_1` + 워크스페이스 소스)
source_docs:
  - 85_실제 인수인계 문서/10_실무자_인수인계/A4_dbt_파이프라인_개발자가이드.md (v0.1)
  - 85_실제 인수인계 문서/20_정식산출물/D07_ETL_파이프라인설계서.md §2 (v1.0) · N05_테스트결과서.md §1·§2 (v1.0)
  - 80_인수인계_프로젝트완료 및 유지보수용/02_dbt_pipeline/10_dbt_pipeline/ (README.md · dbt_project.yml)
  - 워크스페이스 10_dbt_pipeline/ (profiles.yml · models · macros · seeds · snapshots · tests)
source_queries:
  - _ENV/ZL50263/R00_Q07_1.csv (SHOW DBT PROJECTS) · R90_Q06_1.csv (SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE)
  - _ENV/ZL50263/A0_Q04_4.csv
owner: TBD
status: review
---

# R04. dbt 프로젝트 (현업 자료 ID D04)

## 0. 별첨 요구 → 제출 위치

| 별첨에 포함할 내용 | 제출 위치 | 판정 |
|---|---|---|
| 실제 사용 형태와 버전 | 이 문서 §1 · A4 §1 | 충족 |
| adapter · package 버전 | 이 문서 §1 | 신규 |
| 저장소 · 최종 commit/tag | 이 문서 §2 · R11 §1 | 신규 |
| 프로젝트 · 환경 설정 | 이 문서 §1 · A4 §1·§4 · `dbt_project.yml` | 충족 |
| sources·models·macros·seeds·snapshots·tests 사용 항목 | 이 문서 §3 | 부분 → 보완 |
| 모델 의존관계 · 업무 변환 규칙 · 증분 키 · 테스트 · 문서 | A4 §2·§3 · `85:D06`(계보) · `85:D07` §2 · `80/02_dbt_pipeline/10_dbt_pipeline/README.md` · `85:N05` §1·§2 | 충족 |

## 1. 사용 형태 · 버전 · 설정

| 항목 | 값 | 근거 |
|---|---|---|
| 사용 형태 | **dbt Projects on Snowflake**(Snowflake 내장 dbt · DBT PROJECT 객체). dbt Cloud · 외부 dbt Core 서버는 쓰지 않는다 | A4 §1 |
| 프로젝트 객체 | `GN_DW.OPS.DW_PIPELINE` · 소유 GN_DW_ADMIN | R00_Q07 |
| dbt Core 버전 | 1.9.4 | R00_Q07 · ZL A0_Q04_4 |
| adapter(dbt-snowflake) 버전 | 1.9.2 | 같음 |
| 외부 package(`packages.yml`) | **없음** — `dbt deps` 불필요 · 외부 접근 통합(EAI) 불필요 | 소스 트리 · `external_access_integrations = None` |
| dbt 프로젝트 이름 · 버전 | `gn_dw_silver` · 1.0.0 | `dbt_project.yml` :3~4 |
| 버전 관리 방식 | **버전형**(default = LAST · `VERSION$29` · alias `AGENT_ML_TUNING_20261026140806` · 2026-10-26 18:42 · 누적 VERSION$1~29) | `_ENV/ZL50263/R00_Q07_1.csv` · R90_Q06_1 |
| 실행 롤 · WH | GN_DW_DBT · GN_DW_ETL_WH(profiles 3 target 공통 · threads 4) | `profiles.yml` |
| target | `dev`(기본 · 스키마 SILVER) · `dev2`(시험 · SILVER_2 / BRONZE_CRM_2) · `prod`(GOLD) | 같음 |
| 주요 vars | `bigquery_lookback_days: 3`(GA 롤링 창) · `billing_coverage_start_month: 202201` · `cal_start/cal_end` · `ltv_*` | `dbt_project.yml` :62~187 |
| 보조 프로젝트 | `OPS.DW2_PIPELINE`(시험용 · LIVE 형 · 원천 = 공유 워크스페이스 `GN_DW.PUBLIC.GNI_SHARE` · 최종 갱신 2026-09-30) | R00_Q07_1 · R02 §4 |

- 🔴 `profiles.yml` 은 80번 패키지에 없다(DR-18) — 워크스페이스 `10_dbt_pipeline/profiles.yml` 을 함께 넘긴다. 비밀값은 들어 있지 않다(account·user 공란 · Snowflake 세션 인증).

## 2. 저장소 · 최종 commit/tag

| 항목 | 현재 상태 | 근거 |
|---|---|---|
| 소스 정본 위치 | Snowsight 개인 워크스페이스 `USER$.PUBLIC."snowflake_files"` 의 `10_dbt_pipeline/` (기본 VERSION$29 원본). 🟠 과거 버전 29 중 12개(VERSION$1·4~7·9·10·12~15·28)는 공유 워크스페이스 `GN_DW.PUBLIC.GNI_SHARE` 에서 배포 ⇒ 원본이 두 곳에 섞여 있다 | R90_Q06_1 `source_location_uri` |
| 인계 사본 | `80_인수인계_프로젝트완료 및 유지보수용/02_dbt_pipeline/10_dbt_pipeline/` (워크스페이스와 210/210 해시 일치 · 2026-10-20 · profiles 제외) | A4 §1(DR-18) |
| Git 저장소 | 🟠 **dbt 프로젝트 배포는 Git 을 거치지 않는다**. 2026-10-26 `SHOW GIT REPOSITORIES` = 0(10-21 캡처의 GIT_INTEGRATION 1건은 이번 조회에 없음 · 삭제 여부 확인) · 개인 SECRET `USER$CHOIH.PUBLIC.GIT_SEC` 만 남음(R07 §3) | R90_Q08_1 · R90_Q03_1 |
| commit / tag | 🔴 **없음** — `SHOW VERSIONS` 의 `git_commit_hash` = 공란. 배포본 식별자는 dbt 버전 번호(`VERSION$29`) · alias(`AGENT_ML_TUNING_20261026140806`)와 프로젝트 COMMENT(`[20261026] AGENT 배선 및 머신러닝 개선2`)뿐이다 | R90_Q06_1 · R00_Q07_1 |
| 권고 | 인수 직후 워크스페이스 → 내부 Git 저장소(조직 계정) 연결 → 현 소스 commit + tag `handover-YYYYMMDD` → 이후 `DEPLOY FROM '@<git_repo_stage>/branches/main/10_dbt_pipeline'` 로 전환(R11 §1) | Snowflake 문서 ALTER DBT PROJECT |

## 3. 프로젝트 구성 (사용 항목)

| 항목 | 사용 | 수량(워크스페이스 2026-10-25) | 규칙 |
|---|---|---|---|
| sources | 사용 | `models/silver/_sources.yml` 1 · `source()` 참조 88 | BRONZE_* 6 스키마 · dev2 분기는 `_sources.yml` |
| models | 사용 | SILVER 64 sql(+yml 5 · 하위 agency·bigquery·bridge·crm·erp) · GOLD 82 sql(+yml 3 · dim·fact·wide) | 「구조는 DDL, 데이터는 dbt」(A4 §2) |
| macros | 사용 | 13 (`silver_purge` · `gold_fact_purge` · `bigquery_range_*` · `ga4_union_shards` · `gn_biz_codes` · `generate_schema_name` 등) | 범위 증분 = `RANGED_MODELS`/`RANGED_FACTS` 등재 |
| seeds | 사용 | 5 (`MAP_BUDGET_PROCEDURE` · `MAP_EXT_DATA_TYPE` · `MAP_SERVICE_GROUP_RULE` · `MAP_SPONSORSHIP_GROUP4` · `ORG_SUCCESSION_MANUAL`) | 매핑 변경 = csv 수정 + `dbt seed`/build |
| snapshots | **정의만 · 미가동** | 11 (`snp_crm_*`) | 🔴 `+enabled: false`(DEC-61) 바꾸지 않는다 |
| tests | 사용 | 단일 테스트 37 (이름 규칙: `assert_*` 15 = 불변식 · `warn_*` 22 = 관측 · 실제 severity 는 각 파일 `config`) + yml 일반 테스트 | `build` = run + test 게이트 · 실패 저장 = OPS(R02 §4) |
| docs | yml description · 뷰 COMMENT | `gn_view_commented` 매크로 · `warn_gold_view_comment_coverage` | 뷰 COMMENT 정본 = `_wide_schema.yml` |

- 증분 전략(키): SILVER = append + TRUNCATE(전량 · 멱등) · GOLD dim = merge(`unique_key`) · GOLD fact = append + 범위 DELETE · GOLD wide = view (A4 §2 표).
- 업무 변환 규칙 해설 = `80/02_dbt_pipeline/10_dbt_pipeline/README.md` · 각 모델 머리 주석 · 계보 = `85:D06` · 지표 정의 = `85:D01`.

## 4. 인수자 확인 절차 (현업 확인 기준: 「내부 계정으로 소스를 내려받아 의존성 구성 · 대표 모델과 테스트 실행 · 변환 로직·증분 기준 설명」)

1. 내부 계정 워크스페이스로 소스를 가져온다(80번 `02_dbt_pipeline/10_dbt_pipeline/` 업로드 또는 Git 연결) + `profiles.yml` 추가.
2. 의존성: 외부 package 가 없으므로 `dbt deps` 는 생략한다. `parse` 가 통과하면 의존 구성 완료다.
3. 대표 모델 실행(🔴 사람이 실행 · `dev2` 또는 시험 계정 권장):
```sql
USE ROLE GN_DW_DBT; USE WAREHOUSE GN_DW_ETL_WH;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select FACT_MEMBER_FEE';   -- 모델 + 테스트
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='test --select assert_fpbs_billing_preserved';
```
4. 결과 판정 = ERROR 0 · SKIP 0(`85:N05` §1 T1 기준) · 대사 = R10 Q01·Q02·Q08.
5. 설명 확인: `FACT_MEMBER_FEE` 의 월 키(`COALESCE(회비월, 납입월)`) · 증분 방식(append + 창 DELETE) · `PAID_FEE`(회비 ∪ 기부금)와 `PAID_FEE_BILLABLE`(회비만)의 차이를 인수자가 설명할 수 있어야 한다(R10 §3).
