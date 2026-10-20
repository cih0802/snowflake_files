# 인수인계 — 프로젝트 완료 및 유지보수용

워크스페이스 원천 없이 이 폴더만으로 GN_DW(Snowflake) 를 재구축·운영할 수 있도록 구성했다.
전체 파일 목록 = `00_INDEX.csv`. 재생성 = `build_handoff.py --apply`.

## 읽는 순서

1. 00_README.md → 00_INDEX.csv 로 전체 파악
2. 07_운영런북_이슈/02_GN_DW_building/05_ARCHITECTURE.md, 06_RUNBOOK.md
3. 01_실행순서_배포SQL/문서실행순서.md (배포/재구축 순서)
4. 06_일배치_모니터링 (일상 운영)
5. 07_운영런북_이슈/20_issue (미결 이슈)
6. 02~05 (수정 시 대상별 원본)

## 인수인계 대상

| 서브폴더 | 내용 | 파일 수 |
|---|---|---|
| 01_실행순서_배포SQL | 문서실행순서.md 와 그 안의 SQL (원래 경로 유지 → 문서 경로 그대로 사용 가능) | 57 |
| 02_dbt_pipeline | dbt 프로젝트 원본 | 211 |
| 03_MSTR_이관 | MSTR 이관 PoC 전체 | 39 |
| 04_SV_Agent_스펙 | Agent YAML 정본 (09_2 배포 필수) | 4 |
| 05_RAG_지표사전 | RAG 코퍼스 CSV · 원본 정의 · 재생성 도구 | 24 |
| 06_일배치_모니터링 | 일배치 TASK · 비용/알림 모니터링 | 19 |
| 07_운영런북_이슈 | 런북 · 이슈 원장 · 사고사례 | 55 |
| 08_현업공유_산출물 | 현업 공유 산출물 | 85 |
| 09_설계근거_참고 | 설계 근거 · 보안/권한 참고 | 10 |

## 권장 추가 사유 (지정 대상 외)

- 04 Agent YAML: 09_2_AGENT_버전업.sql 이 읽는 정본 — 없으면 Agent 배포 불가
- 05 지표사전 원본·재생성 도구: 정의 변경 시 코퍼스 CSV 재생성 필요
- 06 일배치·모니터링: 일상 운영의 주 대상(TASK·비용가드·알림)
- 07 런북·이슈: 장애 대응·미결 이슈 맥락
- 09 설계근거·보안: 변경 판단 근거, Streamlit 권한, Git 시크릿 갱신

## 파일 목록 (서브폴더별)

### 01_실행순서_배포SQL

| 파일 | 설명 |
|---|---|
| 문서실행순서.md | 개발계·운영계 배포 실행순서 (정본) |
| 02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql | 문서실행순서.md 명시 SQL |
| 02_GN_DW_building/08_After_Deploy_DBT.sql | 문서실행순서.md 명시 SQL |
| 03_top-down_gold/06_DDL.sql | 문서실행순서.md 명시 SQL |
| 04_silver_design/08_SILVER_테이블DDL_20260714.sql | 문서실행순서.md 명시 SQL |
| 04_silver_design/09_SILVER_AD_CREATIVE_CAMPAIGN_MAP_적재.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_01_SV_DDL_MEMBER_MONTHLY.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_02_SV_DDL_MEMBER_EVENT.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_03_SV_DDL_MEMBER_COHORT.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_05_SV_DDL_EVENT_PARTICIPATION.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_06_SV_DDL_BUDGET.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_07_SV_DDL_AD.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_08_SV_DDL_DEV_ACHIEVEMENT.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_09_SV_DDL_MEMBER_FEE.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_11_SV_DDL_TARGET_BIZ.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_12_SV_DDL_RELATION_ACTIVITY.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_13_SV_DDL_DEPT_AGGR.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_14_SV_DDL_MEMBER_MONTHLY_KPI.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_15_SV_DDL_GA_BEHAVIOR.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_16_SV_DDL_BUDGET_YEARLY.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_17_SV_DDL_MEMBER_STATUS_ASOF.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_19_SV_DDL_PAYMENT_BILLING_STATUS.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_20_SV_DDL_GA_SESSION.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_21_SV_DDL_SEARCH_CONSOLE.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_22_SV_DDL_GA_DEMOGRAPHIC.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_23_SV_DDL_EXPENSE_RESOLUTION.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_24_SV_DDL_CAMPAIGN_CUM_STOP.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_25_SV_DDL_CAMPAIGN_MONTHLY.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/05_26_SV_DDL_GA_CHILD_UNPAID.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/09_1_AGENT_생성.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/09_2_AGENT_버전업.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/22_ML_SV_DDL.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/23_ML_INC_MKTG_CMPGN_DDL.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/24_ML_REALTIME_SIMULATOR_DDL.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/25_ML_CHURN_CMPGN_CTGR_DDL.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/26_BIZ_DEFINITION_CORPUS_DDL_적재.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/30_O240_실데이터이상치_배포순서.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/32_O241_AB병기_SV배선_배포순서.sql | 문서실행순서.md 명시 SQL |
| 05_SV-Agent_ai/33_O241C_O242_운영계반영_배포순서.sql | 문서실행순서.md 명시 SQL |
| 08_mornitoring/07_OPS_알림수신자관리_및_파이프라인_이메일알림_표준.sql | 문서실행순서.md 명시 SQL |
| 08_mornitoring/08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql | 문서실행순서.md 명시 SQL |
| 08_mornitoring/09_OPS_dbt경고_이메일알림_구축.sql | 문서실행순서.md 명시 SQL |
| 10_dbt_pipeline/01_deploy_dbt_project.sql | 문서실행순서.md 명시 SQL |
| 10_dbt_pipeline/02_dbt_parse_compile_build.sql | 문서실행순서.md 명시 SQL |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/00_mstr_schema_role.sql | 문서실행순서.md 명시 SQL |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/01_table_script.sql | 문서실행순서.md 명시 SQL |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/02_view_script.sql | 문서실행순서.md 명시 SQL |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/03_function_script.sql | 문서실행순서.md 명시 SQL |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/04_sp_script.sql | 문서실행순서.md 명시 SQL |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql | 문서실행순서.md 명시 SQL |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/06_MSTR_적재_실행.sql | 문서실행순서.md 명시 SQL |
| dbt_build_fact_ad_performance_budget.sql | 문서실행순서.md 명시 SQL |
| 12_agent개선과제/output/O217_biz_definition_corpus.csv | 26_ SQL 이 읽는 BIZ_DEFINITION 코퍼스 (실행순서 원래 경로 유지) |

### 02_dbt_pipeline

| 파일 | 설명 |
|---|---|
| 10_dbt_pipeline/00_배포운영_통합_20260715.md | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/01_deploy_dbt_project.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/02_dbt_parse_compile_build.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/10_성능검토_정적코드분석_20260716.md | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/11_성능검토_운영리스크_20260716.md | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/README.md | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/dbt_project.yml | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/bigquery_range_predicate.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/bigquery_range_purge.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/billing_campaign_asof.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/ga4_union_shards.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/generate_schema_name.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/gn_biz_codes.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/gn_member_master_filter.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/gn_no_structural_alter.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/gn_view_commented.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/gold_fact_purge.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/gold_helpers.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/silver_helpers.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/macros/silver_purge.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/_gold_ready_schema.yml | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_AD_CREATIVE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_BIGQUERY_EVENT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_BIGQUERY_SOURCE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_BIZ_PLACE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_BUDGET_ITEM.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_CAMPAIGN.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_CHILD.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_CODE_GROUP.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_DATE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_DEVICE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_EVENT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_MARKETING_CAMPAIGN.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_MEMBER_ACQUISITION.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_MEMBER_IDENTITY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_MEMBER_STATUS_HISTORY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_MONTH.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_MSG_TEMPLATE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_MSG_TEMPLATE_BUTTON.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_ORG.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_PAYMENT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_PAYMENT_ACCOUNT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_REASON.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_RELATIONSHIP.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_SEND_REQUEST.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_SEND_TYPE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_SERVICE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/dim/DIM_SPONSORSHIP.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_AD_BROADCAST.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_AD_BROADCAST_CASE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_AD_DIGITAL.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_BIGQUERY_BEHAVIOR.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_BIGQUERY_SESSION.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_BUDGET.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_BUDGET_YEARLY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_CAMPAIGN_CUM_STOP.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_CAMPAIGN_MONTHLY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_EVENT_ATTENDANCE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_EXPENSE_RESOLUTION.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_GA4_DEMOGRAPHIC.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_GA_CHILD_VIEW.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_MEMBER_COHORT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_MEMBER_COHORT_SURVIVAL.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_MEMBER_DEV_ACHIEVEMENT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_MEMBER_EVENT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_MEMBER_FEE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_MEMBER_SPONSORSHIP_SPAN.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_MESSAGE_DISPATCH.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_PAYMENT_BILLING_STATUS.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_PAYMENT_METHOD_CHANGE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_RELATION_ACTIVITY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_RELATION_CHANGE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_RELATION_DEV.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_SEARCH_CONSOLE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_SPONSORSHIP_MONTHLY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_TARGET_MEMBER_DEV.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_TARGET_PROJECT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/fact/FACT_UNPAID_SERVICE_CONV.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_AD_BROADCAST.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_AD_BROADCAST_CASE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_AD_COMBINED.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_AD_DIGITAL.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_AD_PERFORMANCE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_BIGQUERY_BEHAVIOR.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_BUDGET.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_DVLP_GOAL_ACMSLT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_EVENT_PARTICIPATION.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_MBRFEE_PRDT_ACTL.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_EVENT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_FEE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_MONTHLY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_MONTHLY_KPI.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_SERVICE_COHORT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_SERVICE_EVENT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_SPNSR_CLS_AGGR.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_TARGET_BIZ.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/WIDE_TARGET_DEV.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/_wide_dept_aggr_schema.yml | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/gold/wide/_wide_schema.yml | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/_silver_bridge_schema.yml | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/_sources.yml | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/agency/AGENCY_AD_BROADCAST.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/agency/AGENCY_AD_BROADCAST_CASE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/agency/AGENCY_AD_CREATIVE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/agency/AGENCY_AD_DIGITAL.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/agency/AGENCY_AD_PERFORMANCE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/agency/AGENCY_AD_ROW_DGT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/agency/AGENCY_AD_ROW_REBRDC.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/agency/AGENCY_AD_ROW_VIDEO.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/BIGQUERY_BASIC.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/BIGQUERY_DEVICE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/BIGQUERY_EVENT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/BIGQUERY_EVENT_DIM.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/BIGQUERY_IDENTITY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/BIGQUERY_SESSION.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/BIGQUERY_TRAFFIC_SOURCE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/GA4_USER_DEMOGRAPHIC.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/SEARCH_CONSOLE_DATA.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bigquery/_bigquery_schema.yml | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bridge/CRM_CAMPAIGN_SPONSOR_BIZ_BRIDGE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/bridge/IDENTITY_MEMBER_XREF.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_BIZ_PLACE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_BIZ_TARGET.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_CAMPAIGN.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_CHILD.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_CODE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_CODE_GROUP.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_DEV_TARGET.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_EVENT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_EVENT_PARTICIPATION.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_HOLIDAY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_INSTT_ACCOUNT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MARKETING_CAMPAIGN.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MEMBER.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MEMBER_AMT_CHANGE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MEMBER_CONVERT_HIST.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MEMBER_DEV.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MEMBER_DISCONTINUE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MEMBER_RESPONSOR.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MEMBER_SPONSOR_BIZ.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MEMBER_SPONSOR_SPAN.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MEMBER_STATUS_HIST.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MKTNG_CODE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MSG_TEMPLATE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_MSG_TEMPLATE_BUTTON.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_ORG.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_PAYMENT_BILLING.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_PAYMENT_METHOD.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_PAYMENT_METHOD_HIST.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_RELATION_ACTIVITY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_RELATION_CHANGE.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_RELATION_DEV.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_SEND_MEMBER.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_SEND_MEMBER_LINK_LOG.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_SEND_MEMBER_OPEN_LOG.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_SEND_REQUEST.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_SEND_RESULT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_SETLE_CMPNY_ACCOUNT.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_SPONSORSHIP.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/CRM_SPONSOR_RELATION.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/crm/_crm_schema.yml | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/erp/ERP_BUDGET.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/erp/ERP_BUDGET_ITEM.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/erp/ERP_BUDGET_YEARLY.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/erp/ERP_EXPENSE_RESOLUTION.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/models/silver/erp/_erp_schema.yml | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tc_cmmn_cd.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tc_cmmn_dtl_cd.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tm_cm_brnd_mng.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tm_cm_cmpgn_mng.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tm_cm_dept_info.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tm_cm_mber_dvlp_goal.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tm_cm_spnsr_bsns_info.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tm_ms_crmn.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tm_ms_email_tmplat_mng.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tm_ms_event.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/snapshots/snp_crm_tm_rm_bplc_mng.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_bigquery_pk_unique.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_dept_aggr_grain_unique.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_fact_dev_achv_goal_rows_preserved.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_fap_ad_cost_preserved.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_fap_ad_ctgr_consistency.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_fmc_churn_invariants.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_fmcs_grain_and_survival.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_fme_campaign_stop_exclusivity.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_fmm_w4_ml_columns.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_fpbs_billing_preserved.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/assert_ftg_dev_month_key_yyyymm.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_bigquery_id_scheme_unclassified.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_bigquery_load_gap.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_bigquery_null_user_pseudo_id.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_bigquery_null_user_pseudo_id_rows.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_campaign_axis_unmapped_ratio.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_erp_budget_month_grain.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_erp_budget_procedure_merge.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_erp_budget_yearly_grain.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_evt_stat_code_label.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_fact_budget_grain.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_fact_budget_yearly_grain.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_fap_mktg_unmapped_ratio.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_fep_nonnumeric_member_dk.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_fer_mktg_campaign_multi.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_fmm_future_month_cap.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_fmm_reason_unmapped_f_rows.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_gold_fact_bigquery_date_sk_zero.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_gold_view_comment_coverage.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/tests/warn_spnsr_cls_aggr_src_dup.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |
| 10_dbt_pipeline/verify_A1_A3_blocking5.sql | dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서) |

### 03_MSTR_이관

| 파일 | 설명 |
|---|---|
| 15_MSTR 이관 PoC/10_MSTR_일일적재_dbt연동_준비.md | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/MSTR_1차이관_Snowflake전환_작업계획.md | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/1차 이관대상 관련 추출/function_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/1차 이관대상 관련 추출/mstr 1차 이관 대상 쿼리.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/1차 이관대상 관련 추출/sp_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/1차 이관대상 관련 추출/table_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/1차 이관대상 관련 추출/view_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/1차 이관대상 관련 추출/갱신 없는 ExplCampList 테이블의 join용 캠페인코드 정보.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/function_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/sp_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/table_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr DDL 원본/view_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/mstr-answer.csv | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/00_mstr_schema_role.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/01_table_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/02_view_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/03_function_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/04_sp_script.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/06_MSTR_적재_실행.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/07_MSTR_일일적재_TASK.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/snowflake 적용 ddl/90_mstr_1차_이관_대상_쿼리.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/README.md | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/manifests/1차.json | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/manifests/1차_deps.json | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/mstr_common.py | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/mstr_deploy.py | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/mstr_deps.py | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/mstr_extract.py | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/mstr_gen.py | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/mstr_load_answer.py | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/mstr_pipeline.py | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/mstr_verify.py | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/templates/1차_04_sp_script.tmpl.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/tools/templates/1차_verify.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/답안체크용 쿼리.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/스킬_MSTR_검증결과.md | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/스킬_MSTR_검증쿼리.sql | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |
| 15_MSTR 이관 PoC/스킬_MSTR_비교항목.md | MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools |

### 04_SV_Agent_스펙

| 파일 | 설명 |
|---|---|
| cortex_project/cortex-project.yaml | Cortex 프로젝트 설정 |
| cortex_project/agents/AGENT_EXECUTIVE/agent_spec.yaml | 09_2_AGENT_버전업.sql 이 읽는 Agent 정본 YAML 스펙 |
| cortex_project/agents/AGENT_MARKETING/agent_spec.yaml | 09_2_AGENT_버전업.sql 이 읽는 Agent 정본 YAML 스펙 |
| cortex_project/agents/AGENT_MEMBER/agent_spec.yaml | 09_2_AGENT_버전업.sql 이 읽는 Agent 정본 YAML 스펙 |

### 05_RAG_지표사전

| 파일 | 설명 |
|---|---|
| 12_agent개선과제/output/O217_biz_definition_corpus.csv | RAG(Cortex Search SEARCH_BIZ_DEFINITION) 지표사전 코퍼스 CSV |
| 12_agent개선과제/tools/build_biz_definition_corpus.py | 코퍼스 CSV 재생성 스크립트 |
| 12_agent개선과제/tools/O217_routing_curated.csv | 코퍼스 생성용 라우팅 큐레이션 |
| 90_provided_definition/00_README.md | 현업 제공 정의 자료 안내 |
| 90_provided_definition/01_원천보고서_인벤토리 인덱스.md | 지표사전·용어사전·보고서필드 인벤토리 원본 |
| 90_provided_definition/02_지표사전 공통.md | 지표사전·용어사전·보고서필드 인벤토리 원본 |
| 90_provided_definition/03_지표사전 신규.md | 지표사전·용어사전·보고서필드 인벤토리 원본 |
| 90_provided_definition/04_마케팅_보고서필드 인벤토리.md | 지표사전·용어사전·보고서필드 인벤토리 원본 |
| 90_provided_definition/05_회원_보고서필드 인벤토리.md | 지표사전·용어사전·보고서필드 인벤토리 원본 |
| 90_provided_definition/06_지표용어사전 20260624.md | 지표사전·용어사전·보고서필드 인벤토리 원본 |
| 90_provided_definition/07_추가_지표사전_20260813기준.md | 지표사전·용어사전·보고서필드 인벤토리 원본 |
| 90_provided_definition/07_추가_지표사전_20260813기준_raw.txt | 지표사전·용어사전·보고서필드 인벤토리 원본 |
| 90_provided_definition/CRM-AGENCY 컬럼명 매핑.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/GA4스키마 20260626.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/agent 질의 피드백_2.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/gni_실적부서.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/공통지표_flat_20261003.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/데이터플랫폼 ML예측프롬프트_sample.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/데이터플랫폼 현업agent 피드백 추가본_20261007.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/신규지표_20260820.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/조직도_20260914.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/지표용어통합 20260623.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/컬럼정의서 20260714.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |
| 90_provided_definition/테이블정의 20260629.csv | 지표·컬럼·테이블 정의, 조직도 등 원본 CSV |

### 06_일배치_모니터링

| 파일 | 설명 |
|---|---|
| 11_일적재pipeline 구성/00_개요_및_실행순서.md | 일배치 TASK 스케줄·LOADER 권한 |
| 11_일적재pipeline 구성/01_스키마생성_및_구조복제.sql | 일배치 TASK 스케줄·LOADER 권한 |
| 11_일적재pipeline 구성/02_권한부여_LOADER_ENGINEER_ADMIN.sql | 일배치 TASK 스케줄·LOADER 권한 |
| 11_일적재pipeline 구성/03_일배치_TASK_스케줄.sql | 일배치 TASK 스케줄·LOADER 권한 |
| 11_일적재pipeline 구성/04_LOADER_임시권한_CALL_DBT.sql | 일배치 TASK 스케줄·LOADER 권한 |
| 11_일적재pipeline 구성/04_LOADER_임시권한_SP_EXEC_MONTH_END.sql | 일배치 TASK 스케줄·LOADER 권한 |
| 08_mornitoring/00_README.md | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/01_모니터링_대상 개요.md | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/02_Cortex_AI_사용량 모니터링.md | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/03_비용제한_예산 쿼터.md | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/04_알림_및 거버넌스.md | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/05_AI비용가드_구축.sql | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/06_웨어하우스비용가드_구축.sql | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/07_OPS_알림수신자관리_및_파이프라인_이메일알림_표준.sql | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/09_OPS_dbt경고_이메일알림_구축.sql | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/10_Cortex_Code_모델별_비용_비교.md | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/11_BRONZE_개인정보_마스킹정책_적용완료.sql | AI/웨어하우스 비용가드·알림·OPS 객체 |
| 08_mornitoring/2026-08-03_G3_코드컬럼전파_ALTER.sql | AI/웨어하우스 비용가드·알림·OPS 객체 |

### 07_운영런북_이슈

| 파일 | 설명 |
|---|---|
| 02_GN_DW_building/05_ARCHITECTURE.md | 아키텍처 |
| 02_GN_DW_building/06_RUNBOOK.md | 운영 런북 |
| 02_GN_DW_building/09_user login mfa리셋.sql | 사용자 MFA 리셋 |
| 12_agent개선과제/18_O217_운영계_재현_런북.md | 기존 계정 덧입힘 런북(백업·diff·롤백) |
| 12_agent개선과제/18_O217_운영계_재현_검증.sql | 운영계 재현 검증 SQL |
| PAID_재현_런북_20260722.md | PAID 재현 런북 |
| 20_issue/00_INDEX_이슈원장.md | 이슈 원장 |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-001.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-003.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-004.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-005.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-006.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-007.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-008.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-009.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-010.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-011.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-012.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-013.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-014.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-015.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-016.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-017.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-018.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-019.md | 이슈 원장 (분할 조각) |
| 20_issue/00_INDEX_이슈원장_조각/00_선택표.md | 이슈 원장 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치.md | dbt 파이프라인 미결 조치 |
| 20_issue/50_dbt_파이프라인_미결조치_조각/00_선택표.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-001.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-002.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-003.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-004.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-005.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-006.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-007.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-008.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-009.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-010.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-011.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-012.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-013.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-014.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-015.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-016.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-017.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-018.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-019.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-020.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-021.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-022.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-023.md | dbt 미결 조치 (분할 조각) |
| 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-024.md | dbt 미결 조치 (분할 조각) |
| 20_issue/91_사고사례집.md | 사고 사례집 |
| 20_issue/92_실측필요_후속작업.md | 실측 필요 후속작업 |

### 08_현업공유_산출물

| 파일 | 설명 |
|---|---|
| 30_output_share/00_생성기-문서명 매핑.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/01_DW_현업활용가이드.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/02_SILVER 스키마 컬럼 인벤토리_20260903.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/02_SILVER 스키마 컬럼 인벤토리_20260904.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/02_SILVER 스키마 컬럼 인벤토리_20260916.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/02_SILVER 스키마 컬럼 인벤토리_20260928.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/02_gold 스키마 컬럼 인벤토리_20260903.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/02_gold 스키마 컬럼 인벤토리_20260916.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/02_gold 스키마 컬럼 인벤토리_20260928.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/03_GN_DW_개념도.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/04_컬럼계보매핑.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/04_컬럼계보매핑.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/04_컬럼계보매핑.xlsx | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/05_지표GOLD매핑.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/05_지표GOLD매핑.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/05_지표GOLD매핑.xlsx | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/06_BRONZE노출감사.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/06_BRONZE노출감사.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/06_BRONZE노출감사.xlsx | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/07_코드체계_관문측정.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/08_SILVER→GOLD_보존율.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/08_SILVER→GOLD_보존율.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/09_보고서필드_조립가능성.csv | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/09_보고서필드_조립가능성.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/09_섹션배너.json | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/10_원천입고_결손요약.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/11_미해결이슈_요약.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/16_파이프라인 배선 수정.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/18_목표데이터_요건_및_해결이슈_정의서.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/19_원천입고_및_항목신설_대기.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/20260826_아키텍처 지도 요약본.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/21_원천입고_대기_주니어_해설서.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/30_공8_GA개발단가_정의_요약.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/30_공8및미회신29건_질문요약.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/31_공8_GA개발단가_쿼리근거.sql | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/31_공8및미회신29건_쿼리근거.sql | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/32_BRONZE_CRM_GOLD반영_설계.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/40_현업회신요청_O190.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/41_현업회신_F-1_본부지부.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/42_현업회신_E-1_모금성비용.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/43_현업회신_F-2_후원사업11개.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/44_현업회신_F-3_문자오픈.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/45_현업회신_ML_일시후원전환_grain.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/46_현업회신_DGT_이전분.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/47_신규19종_파생컬럼_COMMENT초안.md | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/GOLD_ERD_테이블별.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/GOLD_ERD_테이블별_YAML전용.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_AD_CREATIVE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_BIGQUERY_EVENT.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_BIGQUERY_SOURCE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_BUDGET_ITEM.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_CAMPAIGN.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_DATE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_DEVICE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_EVENT.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_MARKETING_CAMPAIGN.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_MEMBER.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_MEMBER_ACQUISITION.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_MEMBER_IDENTITY.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_MEMBER_STATUS_HISTORY.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_MONTH.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_ORG.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_PAYMENT.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_REASON.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_SEND_TYPE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_SERVICE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/DIM_SPONSORSHIP.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_AD_BROADCAST.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_AD_BROADCAST_CASE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_AD_DIGITAL.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_AD_PERFORMANCE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_BIGQUERY_BEHAVIOR.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_BUDGET.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_BUDGET_YEARLY.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_EVENT_ATTENDANCE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_MEMBER_COHORT.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_MEMBER_DEV_ACHIEVEMENT.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_MEMBER_EVENT.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_MEMBER_FEE.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_MEMBER_MONTHLY.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_MEMBER_SPONSORSHIP_SPAN.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_MESSAGE_DISPATCH.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_TARGET_MEMBER_DEV.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/FACT_TARGET_PROJECT.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |
| 30_output_share/erd/index.html | 현업 공유 산출물 (활용가이드·인벤토리·계보·매핑) |

### 09_설계근거_참고

| 파일 | 설명 |
|---|---|
| 05_SV-Agent_ai/08_AGENT_spec.md | Agent 스펙 설계 |
| 05_SV-Agent_ai/09_0_AGENT_정의서.md | Agent 정의서 |
| 05_SV-Agent_ai/11_거버넌스_운영.md | SV/Agent 거버넌스 운영 |
| 05_SV-Agent_ai/AGENT_연결객체_메타데이터.xlsx | Agent 연결객체 메타데이터·원천계보 |
| 05_SV-Agent_ai/AGENT_원천계보_BRONZE까지.xlsx | Agent 연결객체 메타데이터·원천계보 |
| 06_snapshot/01_스냅샷_아키텍처_및_네이밍룰.md | 스냅샷 아키텍처·네이밍룰·구축 SQL |
| 06_snapshot/02_스냅샷_파이프라인_구축_작업계획.md | 스냅샷 아키텍처·네이밍룰·구축 SQL |
| 06_snapshot/03_스냅샷_환경구축_및_검증쿼리.sql | 스냅샷 아키텍처·네이밍룰·구축 SQL |
| 09_streamlit 권한 설정/analyst-selfservice-streamlit.md | Streamlit 셀프서비스 권한 |
| SECURITY.sql | Git 자격증명 시크릿 갱신 |
