---
project_id: GN_DW
doc_type: session_handoff_prompt
created: 2026-07-14
author: Co-authored with CoCo
carryover_from: 순서 9 (설계적합성검토 — 항목1 + GOLD fact table→append 전환 + DIM_DATE 재설계)
---

# [GN_DW 순서 9-B — GOLD fact 전환 검증 마무리 + 설계 적합성 검토 계속]

## 세션 성격 (검토 중심 — 이어하기)
순서 9의 연속. 구현이 설계와 일치하는지 검증·감사하고, 발견된 gap 을 판정→필요한 것만 수정. 순서 9에서 **항목 1(컬럼 정합)** 중 GOLD fact 계열을 감사하다 `table` materialization 문제(G-1/G-2)를 발견해 대규모 수정에 들어갔고, 그 수정의 **build 검증이 아직 안 끝났다.** 먼저 그걸 마무리한 뒤 나머지 검토 항목으로 진행.

## 세션 운영 규칙 (반드시 준수)
- ⚠️ **dbt build/compile·DDL 대량실행·bash 는 사용자가 직접 실행한다.** CoCo 는 명령만 정확히 제시하고 멈춘다.
- **읽기 전용 SQL(SELECT·INFORMATION_SCHEMA 진단)은 CoCo 가 직접 실행 가능**(순서9에서 합의). 편집(파일 수정)은 CoCo 수행.
- 워크스페이스: `USER$.PUBLIC."snowflake_files"`, dbt 프로젝트 루트 `/10_dbt_pipeline`. 파일 실제 경로 `/snowflake/stages/user__public__snowflake_files_/...`.
- 워크스페이스 직접실행 형식(배포객체 아님, live 즉시반영):
  `execute dbt project from workspace "USER$"."PUBLIC"."snowflake_files" project_root='/10_dbt_pipeline' args='<...> --target dev'`
- 대답 짧게. 반복작업(다수 파일 대조/편집)은 착수 전 사용자 확인.
- 추정으로 코드 건드리지 말 것 — 에러/데이터는 SELECT 로 계량 후 보수적으로 수정.

## 순서 9에서 한 일 (완료된 편집 — 되돌리지 말 것)

### 배경 판정: G-1/G-2 (항목1·7 gap)
- GOLD fact 6개가 `materialized='table'` → 매 run `CREATE OR REPLACE TABLE AS SELECT` 로 **06_DDL 구조를 덮어써** 타입 소실(G-1) + fact FK 23개 드롭(G-2, 실측 FK 35→12). dim(merge)은 DDL 보존이라 정상.
- **결정**: `table` 전면 폐기 → SILVER 와 동일 **incremental + append + pre-hook TRUNCATE + full_refresh:false**(DDL=구조 소유, dbt=데이터만). TRUNCATE 는 구조·타입·FK 보존.

### 완료된 파일 편집 (순서9)
1. `dbt_project.yml`
   - `models.gn_dw_silver.gold.fact` 블록 추가: `+materialized: incremental`, `+incremental_strategy: append`, `+pre-hook: "TRUNCATE TABLE IF EXISTS {{ this }}"` (gold 에서 `+full_refresh:false` 상속).
   - `vars` 에 `cal_start: '1991-01-01'`, `cal_end: '2035-12-31'` 추가.
2. `macros/gold_helpers.sql`
   - `date_sk` 매크로: 캘린더 범위 클램프. `CASE WHEN col BETWEEN cal_start AND cal_end THEN TRY_TO_NUMBER(TO_CHAR(col,'YYYYMMDD')) END` → 범위밖/NULL 은 NULL 반환(→fact 에서 0 라우팅).
3. GOLD fact 6개 (`models/gold/fact/*.sql`): `materialized='table'`·`unique_key` 제거, `tags` 만 유지, D1 주석 개정.
   - **FMM**: `MONTH_KEY = COALESCE(TRY_TO_NUMBER(MBRFEE_MT), TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')), 0)` (회비월 grain, 미납행 보존). `WHERE MBER_NO IS NOT NULL` (불량 5행 제외). group by 동일 식.
   - **FEP**: `DATE_SK = COALESCE(date_sk(PARTCPT_DT::DATE), date_sk(e.EVENT_START_DATE), 0)` (참여일→행사시작일→0).
   - **FSE**: `DATE_SK = COALESCE(date_sk(SNDNG_DE::DATE),0)`, `WHERE s.MBER_NO IS NOT NULL` (불량 745행 제외).
   - **FME**: DATE_SK 2곳(dev/stop) `COALESCE(date_sk(...),0)`.
   - **FGA**: DATE_SK `COALESCE(date_sk(EVENT_DT),0)`.
   - **FTG_D**: config 전환만.
4. GOLD conformed dim — SK=0 'Unknown' 멤버(UNION ALL 리터럴 행) 추가:
   - `DIM_DATE`: **GA4 의존 제거 → 고정 캘린더 1991~2035** + DATE_SK=0 Unknown(MONTH_KEY=0, 나머지 NULL/FALSE).
   - `DIM_DEVICE`, `DIM_GA_EVENT`, `DIM_GA_SOURCE`: SK=0 Unknown 행 추가.

## ⚠️ 미완료 — 이 세션 첫 작업: build 검증

**직전 상태**: 전체 build 시 FMM `NULL result in non-nullable MONTH_KEY` 모델 에러(→위 FMM 수정으로 해소 예정) + relationships 27건 실패. FMM/FSE/FEP/FGA 는 append 실패로 0행이었음(FME 4.63M·FTG_D 7272 만 적재).

**첫 실행 명령 (사용자)**: dim→fact DAG 순서로 GOLD 전체 재빌드. 06_DDL 불필요(구조 변경 없음, 로직만).
```
execute dbt project from workspace "USER$"."PUBLIC"."snowflake_files" project_root='/10_dbt_pipeline' args='build --target dev --select path:models/gold'
```

**기대 결과**:
- 6개 fact 전부 적재(0행 해소), FMM 모델 에러 해소.
- `DATE_SK→DIM_DATE`(FME/FEP/FSE)·FGA GA-dim 3종(DEVICE/GA_EVENT/GA_SOURCE) relationships **통과**.
- **남는 실패 = MEMBER_DK 고아뿐** 이어야 함 → 실패 수 확인 후 Phase 2 진행.

**검증 SELECT (CoCo 가 실행 가능)**:
- 6 fact 행수 > 0 확인.
- fk_count: `SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE constraint_schema='GOLD' AND constraint_type='FOREIGN KEY'` → 35 기대(fact FK 생존, G-2 해소).
- FMM 타입: MONTH_KEY NUMBER(6,0)·PAID_FEE NUMBER(18,2) 복원(G-1 해소).
- DIM_DATE 행수 ≈ 16,437(+Unknown 0).

## Phase 2 — MEMBER_DK 고아 (미해결, build 후 판정)
- `MEMBER_DK→DIM_MEMBER` relationships: 실측 FME 17 distinct(ONCE 아님, non-S). 여러 fact 합쳐 수백 행. **0멤버로 해결 안 됨(실-ID 라 매칭 불가)**.
- 선택지: **(a) 라우팅** — fact 에 `LEFT JOIN DIM_MEMBER` 후 없으면 `'(unknown)'`(RI 하드 유지, 소수 실-ID 추적성 상실) / **(b) DIM_MEMBER 보강**(참조 회원 전부 포함) / **(c) severity: warn**(스캐폴드 단계 경고 강등).
- build 후 실제 잔여 실패 수 보고 사용자와 방식 확정.

## 그다음 — 순서 9 나머지 검토 항목 (항목 1 GOLD fact 외 미완)
검토 항목 1(컬럼 정합)은 GOLD fact 6개 + dim 5개만 봄. **미검토**:
- 항목 1 잔여: GOLD 나머지 dim(DIM_MEMBER 등 이미 봄, DIM_CAMPAIGN/ORG/EVENT/REASON/PAYMENT/SPONSORSHIP/SERVICE 등) + **SILVER 32모델** SELECT ↔ 08_SILVER_테이블DDL 컬럼 정합.
- 항목 2 grain·키, 3 의존성(ref) 방향, 4 정제규칙 이행(09_적재쿼리), 5 누락/과잉(미적재 6개·DIM_MEMBER_IDENTITY 결정), 6 test 커버리지(relationships 일관성 — 순서9에서 sentinel where!=0 누락 3종 발견해 0멤버로 처리; 나머지 점검), 7 materialization(순서9에서 GOLD fact 통일 완료).

## 참고: 순서9에서 실측한 데이터 사실
- DIM_DATE 원래 1행(20260501, GA4 단일일). → 고정캘린더로 교체함.
- FME 4,633,105행: 실제날짜 1991-01-09~2026-07-09, <1910 불량 88행, >2030 2행 → date_sk 클램프+0라우팅으로 처리.
- FMM 소스 47.5M: MBRFEE_MT NULL 1,130,252행(전부 PAY_DE 존재→납입월 폴백). PAY_DE NULL 640만(회비월로 보존).
- MEMBER_DK 최대길이: FEP/FSE 10·FMM 9·FME 7 (VARCHAR(10) 무위험). 금액 NUMBER(18,2)/(18,4) 무위험.
- relationships 정의: `models/gold/_gold_ready_schema.yml`. sentinel SK 는 `config: {where: "SK != 0"}` 로 제외돼 있으나 DATE_SK·MEMBER_DK·GA dim 3종은 제외/0멤버 부재였음(순서9에서 0멤버로 보강).

## 가드레일
- SELECT * 금지(단 DIM_DATE Unknown UNION 은 `select *` from calendar CTE 사용 — 의도적) · SILVER만 ref(교차소스 XREF 예외) · run 아닌 build(test 게이트) · 외부패키지 불가(커스텀 매크로) · DDL 소유 원칙(구조=06/08_DDL, dbt=데이터).
- 검토 결과·결정은 최종적으로 `DEPLOY_RUNBOOK.md` CHANGELOG "순서 9" 절에 기록(아직 미기록 — build 검증 후 정리).

## 먼저 할 일
1. 위 `build --select path:models/gold` 실행 결과(성공/잔여 실패 수)를 CoCo 에게 전달.
2. CoCo: 6 fact 행수·fk_count(35)·FMM 타입 검증 SELECT 실행 → G-1/G-2/DATE 해소 확인.
3. 잔여 MEMBER_DK 실패 수 확인 → Phase 2 (a/b/c) 판정·수정.
4. 이후 항목 1 잔여(SILVER 컬럼 정합) → 항목 2~6 순차 진행.
5. 완료분 `DEPLOY_RUNBOOK.md` "순서 9" 절에 기록. (선택) 배포객체 ADD VERSION 은 승인 후.
