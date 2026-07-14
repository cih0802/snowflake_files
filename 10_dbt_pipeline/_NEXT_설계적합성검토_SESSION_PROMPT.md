---
project_id: GN_DW
doc_type: session_handoff_prompt
created: 2026-07-14
author: Co-authored with CoCo
carryover_from: 순서 8-B (SILVER DDL소유 전환 + GOLD 회귀 + 배포 완료)
---

# [GN_DW 순서 9 — 파이프라인 ↔ GOLD·SILVER 설계 적합성 검토]

## 세션 성격 (검토 중심)
이번 세션은 **구현(dbt 파이프라인)이 설계 문서와 일치하는지 검증·감사**하는 세션이다. 코드/DDL 대량 수정이 아니라 **불일치(gap) 식별 → 목록화 → 경중 판정 → 필요한 것만 수정**. 새 기능 추가는 하지 않는다.

## 세션 운영 규칙 (반드시 준수)
- ⚠️ **execute 계열(dbt build/compile, DDL, SELECT, bash 실행)은 전부 내가(사용자) 직접 실행한다. 너(CoCo)는 명령만 정확히 제시하고 멈춘다.** 편집(파일 수정)만 CoCo가 수행.
- 워크스페이스: `USER$.PUBLIC."snowflake_files"`, dbt 프로젝트 루트 `/10_dbt_pipeline`.
- 워크스페이스 직접실행 형식(배포객체 아님, live 파일 즉시 반영):
  `execute dbt project from workspace "USER$"."PUBLIC"."snowflake_files" project_root='/10_dbt_pipeline' args='<...> --target dev'`
- 대답은 짧게.

## 현재 상태 (순서 8-B 완료, 2026-07-14) — 검토의 출발점

### 구현 현황
- **BRONZE**: source 40개(정의만, 미머티리얼라이즈).
- **SILVER**: 32모델. **DDL 소유 = `04_silver_design/08_SILVER_테이블DDL_20260714.sql`(32테이블)**, dbt = `incremental + pre-hook TRUNCATE + append + full_refresh:false`(구조 보존, 데이터만 갱신, 멱등 Δ0). 정제 로직 정본 = `04_silver_design/09_SILVER_적재쿼리_20260714.sql`.
- **GOLD**: 24테이블 DDL(`03_top-down_gold/06_DDL.sql`) 중 dbt 적재 18개(dim12 incremental·merge / fact6 table). 미적재 6개 = AD_CREATIVE/BUDGET_ITEM/TARGET_BIZ/AD_PERFORMANCE/BUDGET(원천 부재) + DIM_MEMBER_IDENTITY(enabled=false).
- 배포객체 `GN_DW.SILVER.GN_DW_SILVER_PIPELINE`: 순서 8-B 개정 ADD VERSION 반영 완료(신규 버전 default).
- 전 레이어 행수 Δ0 검증·멱등 확인. 상세: `10_dbt_pipeline/DEPLOY_RUNBOOK.md` CHANGELOG "순서8"·"순서8-B" 절.

### 미해결 설계 항목 (검토 대상 포함)
- **DIM_MEMBER_IDENTITY**: enabled=false. 차단사유(GA4_IDENTITY 비활성) 해소됨(GA4_IDENTITY·IDENTITY_MEMBER_XREF 각 1,348 적재). 활성화 옵션 1(스캐폴드) vs 2(GA_MEMBER_ID 실결합, 팬아웃 dedupe 필요) 미결정.
- **FACT_GA_BEHAVIOR**: `IDENTITY_SK=0` 센티넬 하드코딩(실결합 미배선).
- **DIM_DATE=1행**: GA4_EVENT.EVENT_DT 전량 2026-05-01 단일일자(데이터 기반, 샤드 추가 시 확장).

## 이번 세션 목표: 설계 ↔ 구현 적합성 감사

### 검토 기준 문서 (설계 정본)
- GOLD: `03_top-down_gold/06_DDL.sql`(24테이블 구조·제약·주석), `03_top-down_gold/08_silver의존.md`(SILVER 의존 매핑), 기타 03_top-down_gold 설계 노트.
- SILVER: `04_silver_design/08_SILVER_테이블DDL_20260714.sql`(구조), `04_silver_design/09_SILVER_적재쿼리_20260714.sql`(정제 로직), `02_SILVER_작업계획_BRONZE-GOLD연결`, `03_SILVER_작업계획_CRM전용`.
- 구현: `/10_dbt_pipeline/models/**`, `dbt_project.yml`, `macros/gold_helpers.sql`, `models/**/_*_schema.yml`(test).

### 검토 항목 (체크리스트)
1. **컬럼 정합**: 각 GOLD·SILVER 모델 SELECT 산출 컬럼 ↔ 소유 DDL(06_DDL / 08_DDL) 컬럼명·순서·타입 일치? (append/merge 전제 — 불일치 시 조용한 실패/센티넬.)
2. **grain·키**: dim SK 정의(`gold_sk`)·unique_key ↔ 설계 grain 일치? fact grain(주석 선언) ↔ GROUP BY 실제 일치? 팬아웃/중복 위험?
3. **의존성(ref) 방향**: SILVER만 ref(BRONZE 직접참조 금지) 준수? GOLD는 SILVER ref? 교차소스 예외(IDENTITY_MEMBER_XREF)만 허용?
4. **정제 규칙 이행**: 09_적재쿼리·작업계획의 파생/코드라벨/필터(예: S-5 [G1][G2], SEND 3계층, 회원 정기∪일시)가 모델에 반영됐는가?
5. **누락/과잉 객체**: 설계 테이블 ↔ 구현 모델 1:1? 미적재 6개의 사유(원천부재 vs 설계상 필수) 재확인. DIM_MEMBER_IDENTITY 처리 결정.
6. **test 커버리지**: 설계상 PK/NOT NULL/FK(정보성)/accepted_values 가 schema.yml test 로 검증되는가? relationships 제외 항목(IDENTITY_SK 등) 타당?
7. **materialization 방침**: SILVER(incremental/append/TRUNCATE) · GOLD(dim incremental·merge / fact table) 가 설계 의도(구조소유·멱등·행소실방지)와 정합?

### 진행 순서 (제안)
1. 검토 기준 문서와 구현을 대조해 **gap 목록** 작성(항목·설계값·구현값·경중[치명/경미/의도된차이]).
2. gap 을 사용자와 함께 판정 → 수정 대상 확정.
3. 수정은 편집만(CoCo) → 사용자 build/compile 로 검증(`build --target dev --select <대상>`).
4. 검토 결과·결정을 `DEPLOY_RUNBOOK.md` CHANGELOG "순서 9 설계적합성검토" 절에 기록.
5. (선택) 수정 반영 시 배포객체 ADD VERSION(승인 후).

## 가드레일
- SELECT * 금지 · SILVER만 ref(교차소스 XREF 예외) · run 아닌 **build**(test 게이트) · 외부패키지 불가(커스텀 매크로) · DDL 소유 원칙(구조는 06/08_DDL, dbt는 데이터).
- 검토가 목적 — 불일치를 임의로 "고치기"보다 먼저 **설계 의도인지 버그인지 판정**. 설계 문서가 틀렸을 수도 있음(양방향 검토).

## 먼저 할 일
`DEPLOY_RUNBOOK.md`(현행 상태)·`03_top-down_gold/06_DDL.sql`·`04_silver_design/08_·09_`·`03_top-down_gold/08_silver의존.md` 를 읽어 설계 기준을 파악한 뒤, 검토 항목 1(컬럼 정합)부터 GOLD·SILVER 모델과 대조해 gap 목록 초안을 제시하라.
