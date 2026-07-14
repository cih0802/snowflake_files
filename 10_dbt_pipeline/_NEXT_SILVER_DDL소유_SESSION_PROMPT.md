---
project_id: GN_DW
doc_type: session_handoff_prompt
created: 2026-07-14
author: Co-authored with CoCo
carryover_from: 순서 8 (GOLD 완료 + SILVER DDL소유 전환 착수)
---

# [GN_DW 순서 8-B 이어서 — SILVER "DDL 구조 소유 + dbt 데이터만 갱신" 전환 검증]

## 세션 운영 규칙 (반드시 준수)
- ⚠️ **execute 계열(dbt build/compile, DDL, SELECT, bash)은 전부 내가(사용자) 직접 실행한다. 너(CoCo)는 그 단계에 오면 명령만 정확히 제시하고 멈춘다.** 최근 세션에서 CoCo의 SQL/bash 실행은 거부됨 — 편집(파일 수정)만 수행하고 실행은 대기.
- 워크스페이스: `USER$.PUBLIC."snowflake_files"`, dbt 프로젝트 루트 `/10_dbt_pipeline`.
- 워크스페이스 직접실행 형식(배포객체 아님, live 파일 즉시 반영):
  `execute dbt project from workspace "USER$"."PUBLIC"."snowflake_files" project_root='/10_dbt_pipeline' args='<...> --target dev'`
- 배포객체 `GN_DW.SILVER.GN_DW_SILVER_PIPELINE` = VERSION$2(default). **GOLD·SILVER 개정 모두 아직 배포객체에 미반영** → 반영하려면 `ALTER DBT PROJECT ... ADD VERSION FROM '<live>/10_dbt_pipeline'` 필요(승인 후).

## 완료된 상태 (순서 8, 2026-07-14)

### A. GOLD 파이프라인 — 활성화·구현·검증 **완료**
- `GN_DW.GOLD` 스키마 생성(MANAGED ACCESS, ACCOUNTADMIN 소유).
- `03_top-down_gold/06_DDL.sql` 실행 → 24테이블(DIM15+FACT9) 구조·제약(NOT ENFORCED 정보성)·주석 생성.
- `dbt_project.yml` gold 블록 활성화: `+enabled:true`, `+database:GN_DW`, `+schema:GOLD`, `+full_refresh:false`.
  - **dim = incremental(merge, DDL 구조 보존)** / **fact = table(스캐폴드 grain 비유일 → 행소실 방지, D1 정본)**.
  - DIM_MEMBER_IDENTITY = 자체 `enabled=false`(GA4_IDENTITY·XREF 대기) → dbt 적재 18개(dim12+fact6), DDL 24 중 미적재 6개(AD_CREATIVE/BUDGET_ITEM/TARGET_BIZ/AD_PERFORMANCE/BUDGET + IDENTITY).
- build 결과: dim PASS=27, fact PASS=15, 멱등 재실행 PASS=38, **전 18테이블 Δ0**. ERROR=0.
- 관찰: `DIM_DATE=1행` = GA4_EVENT.EVENT_DT 전량 2026-05-01 단일일자(distinct=1) → 데이터 기반 정상, GA4 샤드 추가 시 자동 확장.
- 이력: `10_dbt_pipeline/DEPLOY_RUNBOOK.md` CHANGELOG "2026-07-14 순서8" 절에 baseline 행수·결정 기록.

**GOLD baseline 행수(회귀 비교 기준, Δ0 유지되어야 함):**
DIM_MEMBER 1,763,065 · DIM_CAMPAIGN 36,144 · DIM_REASON 5,835 · DIM_EVENT 3,787 · DIM_GA_EVENT 2,841 · DIM_ORG 1,315 · DIM_GA_SOURCE 110 · DIM_SERVICE 11 · DIM_DEVICE 2 · DIM_DATE 1 · DIM_PAYMENT 7 · DIM_SPONSORSHIP 51 · FACT_SERVICE_EVENT 38,471,525 · FACT_MEMBER_MONTHLY 36,577,960 · FACT_MEMBER_EVENT 4,633,105 · FACT_EVENT_PARTICIPATION 1,134,126 · FACT_GA_BEHAVIOR 19,555 · FACT_TARGET_DEV 7,272.

### B. SILVER "DDL 소유 + dbt 데이터만 갱신" — **편집만 완료, 실행·검증 미완**
사용자 요청: "SILVER도 DDL은 보존하고 dbt로는 업데이트만". 선택 = **옵션 A: TRUNCATE+append**.

이미 편집됨(파일 수정 완료):
- `dbt_project.yml` silver 블록: `+materialized: incremental`, `+incremental_strategy: append`, `+full_refresh: false`, `+pre-hook: "TRUNCATE TABLE IF EXISTS {{ this }}"`.
  - 의미: 매 run 기존 DDL 테이블 TRUNCATE(제약·주석·구조 보존) 후 전체 SELECT append 재적재. unique_key 불필요, grain 비유일 행소실 없음, 멱등. `full_refresh:false`로 `--full-refresh` 시 CTAS 재생성 차단.
- 인라인 `materialized='table'` 6개 → `'incremental'` 변경(프로젝트 설정 상속):
  `models/silver/ga4/GA4_EVENT.sql, GA4_DEVICE.sql, GA4_EVENT_DIM.sql, GA4_IDENTITY.sql, GA4_TRAFFIC_SOURCE.sql`, `models/silver/bridge/IDENTITY_MEMBER_XREF.sql`.
- `dbt_project.yml` 상단 materialization 방침 주석 갱신.

구조 소유주 DDL: `04_silver_design/08_SILVER_테이블DDL_20260714.sql` (CREATE SCHEMA + 33테이블 CREATE OR REPLACE, 제약·주석). GOLD 06_DDL과 동일 패턴.

## 이번 세션 목표: SILVER 옵션 A 실행·검증 완료

### ⚠️ 핵심 리스크 — append 컬럼 정합
append 는 대상(DDL) 테이블의 **모든 컬럼명이 모델 산출 컬럼(SELECT alias)에 존재**해야 함. 없으면 해당 모델 build 가 `invalid identifier` 로 실패(그 테이블은 pre-hook TRUNCATE 로 이미 비워진 채 남음). SILVER 32모델이라 GOLD보다 대조 필요.
- 사전대조가 필요하면: 08_DDL 테이블별 컬럼 vs 현재 SILVER 테이블 컬럼(=모델 산출) 비교. (DB SELECT 또는 파일 파싱 — 실행은 사용자.)
- 또는 파일럿 1개 build 로 메커니즘 먼저 검증 후 전체.

### 실행 순서 (사용자 직접 실행, CoCo는 명령 제시 후 대기)
1. **08 DDL 실행** — `snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/04_silver_design/08_SILVER_테이블DDL_20260714.sql`
   (33테이블 재생성 = 기존 SILVER 데이터 비워짐. 2~4에서 재적재. GOLD는 SILVER ref → 재적재 완료 전까지 GOLD 재빌드 금지.)
2. **compile** — `args='compile --target dev'`
3. **파일럿 build 1개** — `args='build --target dev --select CRM_CODE'` (truncate+append·컬럼정합 검증)
4. **전체 SILVER build** — `args='build --target dev --select silver'`
5. **결과 검증** — `invalid identifier`/컬럼 불일치 나오면 해당 모델 SELECT 를 DDL 컬럼에 맞게 수정(또는 DDL을 모델에 맞게 조정) 후 재실행. 이상 없으면:
   - **멱등 재실행**: `args='build --target dev --select silver'` 2회차 → 행수 Δ0 확인(BEFORE 스냅샷 대비).
   - SILVER test PASS 확인(_crm_schema.yml/_ga4_schema.yml).
6. **문서 갱신** — `DEPLOY_RUNBOOK.md` CHANGELOG 에 "순서 8-B SILVER DDL소유 전환" 절 추가(전략·행수·결정). `99_DEPLOY_ORCHESTRATION.sql` 의 SILVER 실행 방침(현재 build 계약) 문구가 table→incremental/append 전환과 모순되지 않는지 점검·수정.

### 후속(선택)
- 검증 완료 후 배포객체 반영: `ALTER DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ADD VERSION FROM '<live>/10_dbt_pipeline' COMMENT='순서8 GOLD활성화+SILVER DDL소유전환'` (승인 후). 신규 버전이 default.

## 가드레일 (순서 7~8 학습)
- SELECT * 금지 · SILVER만 ref(BRONZE 직접참조 금지) · run 아닌 **build**(test 게이트, run은 0행도 SUCCESS) · 외부패키지 불가(커스텀 매크로) · GA4 BRONZE는 소문자 인용식별자(단 SILVER 경유하면 무관).
- append 전제: DDL 선행(테이블 미존재 시 incremental 첫 run이 CTAS로 구조 없이 생성).

## 먼저 할 일
`dbt_project.yml`(silver/gold 블록)과 변경된 6개 GA4/bridge 모델, `04_silver_design/08_SILVER_테이블DDL_20260714.sql` 를 읽어 편집 상태를 확인한 뒤, 위 실행 순서 1번 명령을 제시하고 사용자 실행을 대기하라.
