---
project_id: GN_DW
project_name: GoodNeighbors Data Warehouse 구축
doc_type: work_plan_index
format: structured-markdown + yaml
language: ko (설명) / en (구조 키)
design_direction: SERVING 스키마 도입 (재설계안). GOLD 정본은 03_top-down_gold/(star schema). 기존 SQL 파일은 레거시 참고용.
timezone: Asia/Seoul (UTC+9)
target_database: GN_DW
source_poc_database: GN_DW_POC
schemas: [BRONZE, SILVER, GOLD, SERVING, OPS, SECURITY]
layer_flow: BRONZE -> SILVER -> GOLD -> SERVING
chapter_files:
  - { file: "01_환경_Role.md",        sections: [1, 2],            topic: warehouse/timezone + rbac }
  - { file: "02_DB_BRONZE_SILVER.md", sections: [3.1, 3.2, 3.3, 3.4, 4], topic: db/schema + bronze + silver + procedures }
  - { file: "03_GOLD_SERVING.md",     sections: [3.5, 3.6, 3.7, 3.8, 3.9], topic: "gold star schema(정본→03_top-down_gold/) + legacy views + semantic view + agent + grants + streamlit" }
  - { file: "04_운영.md",             sections: [5, 6, 7, 8],      topic: tasks + tests + security + monitoring }
  - { file: "05_ARCHITECTURE.md",    sections: [overview],          topic: 전체 아키텍처 다이어그램 + 계층/RBAC/DAG/SERVING 조감도 }
  - { file: "06_RUNBOOK.md",         sections: [operations],        topic: 운영 매뉴얼 — 일상점검/장애대응/수동실행/보안사고 }
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
  - "정제 프로시저, 태스크(DAG), 테스트, 보안, 모니터링"
scope_out:
  - "BRONZE 적재 파이프라인 구현(외부팀 LOADER 담당) — 본 문서 책임은 SILVER 정제부터"
  - "구버전 GN_DW_POC_AGENT(폐기 대상)"
  - "레거시 SQL 파일(01_프로젝트 진행 샘플) 유지보수 — 신규 SERVING 설계로 대체"
```

### 0.2 산출물 (deliverables)

```yaml
deliverables:
  databases: { GN_DW: 1 }
  schemas: [BRONZE, SILVER, GOLD, SERVING, OPS, SECURITY]   # 6
  warehouses: 3
  roles: 6
  crm_bronze_tables: 43  # ★현재 측정 기준(실측 2026-07-13): GN_DW.BRONZE_CRM = 43테이블/927컬럼, 전량 적재(수백만 행). 참고(원천정의서 BRONZE_CRM 테이블 정보.MD=41/876; 정의서 per-table 컬럼수는 실측과 상이 → 실측을 기준으로 사용). 추가 2테이블: TD_MS_AT_TMPLAT_BTN_LIST·TM_MS_EMAIL_TMPLAT_MNG
  bronze_tables: 56      # CRM 41 + 외부 15 (원천 구조 보존)
  silver_tables: 23      # BRONZE 56개를 통합·정제(consolidation)하여 축소
  gold_star_schema: 24   # ★ 정본: 15 DIM + 9 FACT (03_top-down_gold/) — FACT: FMM·FME·FTG_D·FTG_B·FSE·FGA·FAD·FEP·FBD
  gold_legacy_views: 35  # PoC 호환 계층 (star schema와 병존)
  forecast_tables: 0     # ⛔ forecast 제외 결정(2026-07-10) — star schema 24에 예측 테이블 없음. 레거시 FORECAST_* 5종·V_FORECAST_* 뷰는 비활성(전환 대상 아님)
  semantic_views: 7
  agents: 1
  streamlit_apps: 6
  refine_procedures: 18
  utility_procedures: 3
  forecast_procedures: 0 # ⛔ forecast 제외 결정(2026-07-10) — SP_REFRESH_FORECAST_DATA 비활성
  tasks: 4               # VALIDATE_BRONZE → REFINEMENT_ROOT → LOAD_GOLD → FINALIZER
  resource_monitors: 4
  alerts: 3
  cost_report_views: 2
```

### 0.3 전제조건 (prerequisites)

```yaml
prerequisites:
  - "PoC 소스 DB(GN_DW_POC) 존재 및 RAW/ANALYTICS 객체 접근 가능"
  - "CRM 원천 테이블 정의서(BRONZE_CRM 테이블 정보.MD) 확보 — 41개 테이블/876개 컬럼"
  - "ACCOUNTADMIN 권한(초기 셋업) / 이후 SYSADMIN·SECURITYADMIN으로 위임"
  - "BRONZE 적재 표준안 Excel_to_Table_개선.ipynb 준비"
  - "Serverless 태스크용 EXECUTE MANAGED TASK ON ACCOUNT 권한"
```

### 0.4 실행 순서 (execution_order)

> 아래 순서대로 구축한다. 정제 프로시저(step5)가 SILVER를 산출해야 GOLD View(step6)가 SILVER 참조 가능 → 프로시저를 GOLD View보다 먼저 실행.

```yaml
execution_order:
  - { step: 1,  section: 1,   chapter: "01_환경_Role.md",        topic: timezone + warehouses }
  - { step: 2,  section: 2,   chapter: "01_환경_Role.md",        topic: roles + users }
  - { step: 3,  section: 3.1, chapter: "02_DB_BRONZE_SILVER.md", topic: database + 6 schemas }
  - { step: 4,  section: 3.3, chapter: "02_DB_BRONZE_SILVER.md", topic: 56 bronze tables (CRM 41 + 외부 15, 원천 1:1) }
  - { step: 5,  section: 4,   chapter: "02_DB_BRONZE_SILVER.md", topic: ETL_LOG + 통합·정제 프로시저 (SILVER 23개 산출, consolidation 56→23) }
  - { step: 6,  section: 3.5, chapter: "03_GOLD_SERVING.md",     topic: "GOLD star schema 24테이블(정본→03_top-down_gold/) + 레거시 View 35개 병존" }
  - { step: 7,  section: 3.6, chapter: "03_GOLD_SERVING.md",     topic: 7 semantic views (SERVING) }
  - { step: 8,  section: 3.7, chapter: "03_GOLD_SERVING.md",     topic: GN_DW_AGENT (SERVING) }
  - { step: 9,  section: 3.9, chapter: "03_GOLD_SERVING.md",     topic: 6 streamlit apps (SERVING) }
  - { step: 10, section: 3.8, chapter: "03_GOLD_SERVING.md",     topic: grants + future grants }
  - { step: 11, section: 5,   chapter: "04_운영.md",             topic: 4 tasks (DAG) }
  - { step: 12, section: 6,   chapter: "04_운영.md",             topic: 권한/E2E/정합성 테스트 }
  - { step: 13, section: 7,   chapter: "04_운영.md",             topic: network + masking + mfa }
  - { step: 14, section: 8,   chapter: "04_운영.md",             topic: resource monitor + alert + cost }
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
  - { id: R2, item: "VQR 내 GN_DW_POC.RAW/ANALYTICS 경로 잔존 → ANALYST/VIEWER 권한 오류", mitigation: "VQR 경로 전부 GN_DW.GOLD.*로 치환 (03_GOLD_SERVING.md 3.6)" }
  - { id: R3, item: "BRONZE APPEND 반복 중복", mitigation: "MERGE 또는 DELETE+INSERT 멱등성 (P6)" }
  - { id: R4, item: "GOLD view-on-view 생성 순서 오류", mitigation: "하위 View 우선 생성 (03_GOLD_SERVING.md 3.5)" }
  - { id: R5, item: "레거시 07 SQL의 GN_DW_MASKING_ADMIN 역할이 02에 미정의", mitigation: "신규 작성 시 역할 정리 (03_GOLD_SERVING.md 3.8)" }
  - { id: R6, item: "예상치 못한 크레딧 폭주", mitigation: "Resource Monitor 임계 SUSPEND (04_운영.md 8.1)" }
  - { id: R7, item: "레거시 SQL은 GOLD에 SV/Agent/Streamlit 통합 → 신규 SERVING 설계와 불일치", mitigation: "레거시 SQL은 참고만, 신규는 SERVING 기준으로 작성" }
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
| `02_DB_BRONZE_SILVER.md` | 3.1~3.4, 4 | DB/스키마, CRM 원천 41테이블 인벤토리, BRONZE 56테이블(1:1), SILVER 23테이블(consolidation), 통합·정제 프로시저 |
| `03_GOLD_SERVING.md` | 3.5~3.9 | GOLD star schema 24(정본→03_top-down_gold/) + 레거시 View 35(병존), SV 7, Agent 1, 권한, Streamlit 6 |
| `04_운영.md` | 5~8 | 태스크 DAG, 테스트, 보안(네트워크/마스킹/MFA), 모니터링 |
| `05_ARCHITECTURE.md` | overview | 전체 아키텍처 다이어그램, 데이터 흐름, RBAC, WH, DAG, SERVING 조감도 |
| `06_RUNBOOK.md` | operations | 운영 매뉴얼 — 일상점검, 장애대응, 수동실행, 보안사고 대응 |
