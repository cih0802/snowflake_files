---
project_id: GN_DW
project_name: GoodNeighbors Data Warehouse 구축
doc_type: work_plan_index
format: structured-markdown + yaml
language: ko (설명) / en (구조 키)
design_direction: SERVING 스키마 도입 (재설계안·라이브 배포 완료 2026-07-22). GOLD 정본은 03_top-down_gold/(star schema). ETL은 dbt(GN_DW.OPS.DW_PIPELINE).
timezone: Asia/Seoul (UTC+9)
target_database: GN_DW
source_poc_database: GN_DW_POC
schemas: [BRONZE_CRM, BRONZE_AGENCY, BRONZE_ERP, BRONZE_GA4, SILVER, GOLD, SERVING, OPS, SECURITY]
layer_flow: BRONZE -> SILVER -> GOLD -> SERVING
chapter_files:
  - { file: "01_환경_Role.md",        sections: [1, 2],            topic: warehouse/timezone + rbac }
  - { file: "02_DB_BRONZE_SILVER.md", sections: [3.1, 3.2, 3.3, 3.4, 4], topic: db/schema + bronze(48) + silver(32) + dbt pipeline }
  - { file: "03_GOLD_SERVING.md",     sections: [3.5, 3.6, 3.7, 3.8, 3.9], topic: "gold star schema(정본→03_top-down_gold/) + WIDE view 9 + semantic view 5 + agent 2 + grants" }
  - { file: "04_운영.md",             sections: [5, 6, 7, 8],      topic: dbt pipeline + tests + security + monitoring }
  - { file: "05_ARCHITECTURE.md",    sections: [overview],          topic: 전체 아키텍처 다이어그램 + 계층/RBAC/dbt/SERVING 조감도 }
  - { file: "06_RUNBOOK.md",         sections: [operations],        topic: 운영 매뉴얼 — 일상점검/dbt 장애대응/수동실행/보안사고 }
---

# GN_DW 프로젝트 구축 작업계획서 — 인덱스 (INDEX)

> 본 문서군은 `00_GN_DW_PROJECT.md`(원본)를 LLM 파싱에 유리하도록 재구성·분할한 작업계획서다.
> 객체 정의는 YAML 블록, 관계는 명시적 ID/참조로 표현한다. 설명은 한국어, 구조 키는 영어다.
>
> **읽는 순서:** 본 인덱스(개요·원칙·실행순서·위험) → 필요한 챕터 파일만 로드.
> **설계 방향:** SERVING 스키마를 도입한 **재설계안**이다. 폴더 `01_프로젝트 진행 샘플`의 SQL은 GOLD 통합 **레거시**이므로 참고용으로만 사용한다.
> **⭐ GOLD 정본:** `03_top-down_gold/` 폴더(15 DIM + 9 FACT star schema). 본 문서의 GOLD 관련 기술은 요약이며 상세는 정본 폴더 참조.

---

## 0. 작업 개요 (work_plan_overview)

### 0.1 목적 & 범위 (purpose_scope)

```yaml
purpose: "GoodNeighbors PoC(GN_DW_POC)를 운영 등급 데이터 웨어하우스(GN_DW)로 이관·구축"
scope_in:
  - "환경/Warehouse, 유저/Role(RBAC) 구성"
  - "BRONZE→SILVER→GOLD→SERVING 4계층 오브젝트 및 권한"
  - "dbt 파이프라인(SILVER/GOLD/WIDE), 테스트, 보안, 모니터링"
scope_out:
  - "BRONZE 적재 파이프라인 구현(외부팀 LOADER 담당) — 본 문서 책임은 SILVER 정제부터"
  - "구버전 GN_DW_POC_AGENT(폐기 대상)"
  - "레거시 SQL 파일(01_프로젝트 진행 샘플) 유지보수 — 신규 SERVING 설계로 대체"
```

### 0.2 산출물 (deliverables)

```yaml
deliverables:
  databases: { GN_DW: 1 }
  schemas: [BRONZE_CRM, BRONZE_AGENCY, BRONZE_ERP, BRONZE_GA4, SILVER, GOLD, SERVING, OPS, SECURITY]   # 9 (+PUBLIC)
  warehouses: 3
  roles: 6
  bronze_tables: 48       # CRM 43 + AGENCY 3 + ERP 1 + GA4 1 (원천별 4스키마 분리)
  bronze_crm_tables: 43   # ★실측 GN_DW.BRONZE_CRM (원천정의 41 + 템플릿 2)
  silver_tables: 32       # CRM 22 + GA4 5 + ERP 2 + AGENCY 2 + bridge 1 (dbt)
  gold_star_schema: 24    # ★ 정본: 15 DIM + 9 FACT (03_top-down_gold/) — FACT: FMM·FME·FTG_D·FTG_B·FSE·FGA·FAD·FEP·FBD
  gold_wide_views: 9      # FACT 1:1 평탄화 VIEW (레거시 PoC View 없음)
  forecast_tables: 0      # ⛔ forecast 제외 결정(2026-07-10)
  semantic_views: 5       # 배포(최종 목표 7). FMM·FME·FSE·FEP·FBD
  agents: 2               # AGENT_MEMBER·AGENT_OVERALL (최종 목표 3)
  serving_helper_views: 2 # DIM_MEMBER_CURRENT·DIM_MONTH
  streamlit_apps: 0       # 미배포
  dbt_projects: 1         # GN_DW.OPS.DW_PIPELINE (65 models)
  refine_procedures: 0    # 폐기(dbt 전환) — 구설계 SP_REFINE_* 18
  tasks: 0                # 폐기(dbt 전환) — 구설계 Task DAG 4
  etl_log: 0              # 폐기(dbt run/test 로그로 대체)
  resource_monitors: 0    # 설계안(미배포)
  alerts: 0               # 설계안(미배포)
  cost_report_views: 0    # 설계안(미배포)
```

### 0.3 전제조건 (prerequisites)

```yaml
prerequisites:
  - "PoC 소스 DB(GN_DW_POC) 존재 및 RAW/ANALYTICS 객체 접근 가능"
  - "CRM 원천 테이블 정의서(BRONZE_CRM 테이블 정보.MD) 확보 — 실측 43테이블/927컬럼(정의서 41/876 참고)"
  - "ACCOUNTADMIN 권한(초기 셋업) / 이후 SYSADMIN·SECURITYADMIN으로 위임"
  - "BRONZE 적재 표준안 Excel_to_Table_개선.ipynb 준비"
  - "dbt 프로젝트 배포 환경(GN_DW.OPS.DW_PIPELINE) — 10_dbt_pipeline/deploy_dbt_project.sql"
```

### 0.4 실행 순서 (execution_order)

> 아래 순서대로 구축한다. dbt 파이프라인(step5~6)이 SILVER·GOLD를 산출한다. BRONZE→SILVER→GOLD→WIDE는 dbt 모델 의존 순서로 실행된다.

```yaml
execution_order:
  - { step: 1,  section: 1,   chapter: "01_환경_Role.md",        topic: timezone + warehouses }
  - { step: 2,  section: 2,   chapter: "01_환경_Role.md",        topic: roles + users }
  - { step: 3,  section: 3.1, chapter: "02_DB_BRONZE_SILVER.md", topic: database + 9 schemas (BRONZE 4분할 포함) }
  - { step: 4,  section: 3.3, chapter: "02_DB_BRONZE_SILVER.md", topic: 48 bronze tables (CRM 43 + AGENCY 3 + ERP 1 + GA4 1, 원천별 스키마) }
  - { step: 5,  section: 4,   chapter: "02_DB_BRONZE_SILVER.md", topic: dbt SILVER 32 (BRONZE→SILVER 정제·통합) }
  - { step: 6,  section: 3.5, chapter: "03_GOLD_SERVING.md",     topic: "dbt GOLD star schema 24 + WIDE VIEW 9 (정본→03_top-down_gold/)" }
  - { step: 7,  section: 3.6, chapter: "03_GOLD_SERVING.md",     topic: 5 semantic views (SERVING, 최종 7) + 보조뷰 2 }
  - { step: 8,  section: 3.7, chapter: "03_GOLD_SERVING.md",     topic: 2 cortex agents (SERVING, 최종 3) }
  - { step: 9,  section: 3.8, chapter: "03_GOLD_SERVING.md",     topic: grants + future grants }
  - { step: 10, section: 5,   chapter: "04_운영.md",             topic: dbt pipeline 오케스트레이션 }
  - { step: 11, section: 6,   chapter: "04_운영.md",             topic: 권한/E2E/정합성 테스트 (dbt test) }
  - { step: 12, section: 7,   chapter: "04_운영.md",             topic: network + masking + mfa (설계안) }
  - { step: 13, section: 8,   chapter: "04_운영.md",             topic: resource monitor + alert + cost (설계안) }
```

### 0.5 책임 범위 (raci)

```yaml
raci:
  - { area: "BRONZE 적재", owner: "외부팀(LOADER)", role: GN_DW_LOADER, note: "범위 밖" }
  - { area: "SILVER 정제 / GOLD / SERVING 구축", owner: "데이터 엔지니어", role: GN_DW_ENGINEER }
  - { area: "DDL / 스키마 / 권한 관리", owner: "관리자", role: GN_DW_ADMIN }
  - { area: "분석 / 대시보드 소비", owner: "분석가/뷰어", role: "GN_DW_ANALYST, GN_DW_VIEWER" }
  - { area: "거버넌스(마스킹/네트워크)", owner: "보안 관리자", role: "GN_DW_ADMIN (+SECURITYADMIN)" }
```

### 0.6 위험 & 주의사항 (risks)

```yaml
risks:
  - { id: R1, item: "네트워크 정책 적용 시 본인 IP 미포함 → 즉시 잠김", mitigation: "ALLOWED에 본인 IP 포함 후 테스트하고 적용 (04_운영.md 7.1)" }
  - { id: R2, item: "VQR/SV 내 GN_DW_POC.RAW/ANALYTICS 경로 잔존 → ANALYST/VIEWER 권한 오류", mitigation: "SV base·VQR 경로 전부 GN_DW.GOLD.*로 치환 (03_GOLD_SERVING.md 3.6)" }
  - { id: R3, item: "BRONZE 적재 반복 중복", mitigation: "적재 멱등성(MERGE/재생성) + dbt 재빌드 (P6)" }
  - { id: R4, item: "dbt 모델 의존 순서 오류", mitigation: "dbt ref() 의존 그래프 자동 해소, dbt run --select <model>+ 로 하위 포함 재실행 (03_GOLD_SERVING.md 3.5)" }
  - { id: R5, item: "SECURITY 스키마 마스킹 역할 정의 누락", mitigation: "마스킹 정책은 GN_DW_ADMIN 관리로 정리 (03_GOLD_SERVING.md 3.8)" }
  - { id: R6, item: "예상치 못한 크레딧 폭주", mitigation: "Resource Monitor 임계 SUSPEND (04_운영.md 8.1, 운영 승격 시 배포)" }
  - { id: R7, item: "구설계 문서의 레거시 View/프로시저/Task 서술이 라이브(dbt·WIDE·SV5/Agent2)와 불일치", mitigation: "본 문서군은 라이브 실측(2026-07-22) 기준. 레거시 서술은 폐기됨" }
```

---

## 핵심 원칙 (global_principles)

```yaml
principles:
  - id: P1
    name: layer_separation
    desc: "BRONZE(원천 1:1 보존)→SILVER(통합·정제/consolidation)→GOLD는 분석 계층, SERVING은 소비(SV/Agent/Streamlit) 계층"
  - id: P2
    name: no_bronze_direct_ref
    desc: "모든 GOLD View는 SILVER 또는 GOLD 내부 객체만 참조. BRONZE 직접참조 금지"
  - id: P3
    name: owners_rights_gold
    desc: "GOLD View는 GN_DW_ADMIN 소유(owner's rights). ANALYST/VIEWER는 GOLD SELECT만으로 SILVER/BRONZE 직접 권한 없이 조회"
  - id: P4
    name: role_hierarchy_best_practice
    desc: "모든 Custom Role은 SYSADMIN에 귀속. ACCOUNTADMIN으로 직접 오브젝트 생성 금지"
  - id: P5
    name: workload_isolation
    desc: "용도별 Warehouse 분리로 비용 추적 + 워크로드 격리"
  - id: P6
    name: idempotency
    desc: "정제는 CREATE OR REPLACE / MERGE 방식으로 멱등성 보장"
  - id: P7
    name: serving_separation
    desc: "SV/Agent/Streamlit은 GOLD가 아닌 SERVING 스키마에 배치. GOLD View를 cross-schema 참조"
```

---

## 챕터 맵 (chapter_map)

| 파일 | 섹션 | 내용 |
|---|---|---|
| `01_환경_Role.md` | 1, 2 | Timezone, Warehouse 3종, Role 계층 6종, 유저 프로비저닝 |
| `02_DB_BRONZE_SILVER.md` | 3.1~3.4, 4 | DB/스키마 9종(BRONZE 4분할), CRM 원천 43테이블 인벤토리, BRONZE 48테이블(1:1), SILVER 32테이블(consolidation), dbt 파이프라인 |
| `03_GOLD_SERVING.md` | 3.5~3.9 | GOLD star schema 24(정본→03_top-down_gold/) + WIDE VIEW 9, SV 5(최종 7), Agent 2(최종 3), 권한, Streamlit 0(미배포) |
| `04_운영.md` | 5~8 | dbt 파이프라인, 테스트, 보안(네트워크/마스킹/MFA), 모니터링 |
| `05_ARCHITECTURE.md` | overview | 전체 아키텍처 다이어그램, 데이터 흐름, RBAC, WH, DAG, SERVING 조감도 |
| `06_RUNBOOK.md` | operations | 운영 매뉴얼 — 일상점검, 장애대응, 수동실행, 보안사고 대응 |
| `07_ENVIRONMENT_RBAC_setup.sql` | setup(실행) | 0단계 부트스트랩 SQL — WH 3·역할 6+계층·WH/스키마 grant·SERVING 스키마·CoWork object·helper 뷰 2. 01·03 §3.8 설계의 **실행 정본**(05_SV-Agent_ai/02_SERVING_setup.sql에서 이관) |
