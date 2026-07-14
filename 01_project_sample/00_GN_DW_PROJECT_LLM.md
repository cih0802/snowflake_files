---
project_id: GN_DW
project_name: GoodNeighbors Data Warehouse 구축
source_doc: 00_GN_DW_PROJECT.md
format: structured-markdown + yaml
language: ko (설명) / en (구조 키)
timezone: Asia/Seoul (UTC+9)
target_database: GN_DW
source_poc_database: GN_DW_POC
schemas: [BRONZE, SILVER, GOLD, SERVING, OPS, SECURITY]
layer_flow: BRONZE -> SILVER -> GOLD -> SERVING
sql_files:
  - { id: "01", file: "01_환경세팅.sql", topic: warehouse/timezone }
  - { id: "02", file: "02_유저_Role_세팅.sql", topic: user/role }
  - { id: "03_01", file: "03_01_DB_스키마_생성.sql", topic: db/schema }
  - { id: "03_02", file: "03_02_BRONZE_테이블_생성.sql", topic: bronze tables }
  - { id: "03_03", file: "03_03_GOLD_View_생성.sql", topic: gold views + forecast table DDL }
  - { id: "03_04", file: "03_04_Semantic_View_생성.sql", topic: semantic views }
  - { id: "03_05", file: "03_05_Agent_생성.sql", topic: agent }
  - { id: "03_06", file: "03_06_권한_부여.sql", topic: grants }
  - { id: "03_07", file: "03_07_Streamlit_배포.sql", topic: streamlit }
  - { id: "04", file: "04_프로시저_생성.sql", topic: procedures }
  - { id: "05", file: "05_태스크_생성.sql", topic: tasks }
  - { id: "06", file: "06_테스트.sql", topic: tests }
  - { id: "07", file: "07_보안_세팅.sql", topic: security }
  - { id: "08", file: "08_모니터링_세팅.sql", topic: monitoring }
---

# GN_DW 프로젝트 구축 작업계획서 (LLM-friendly)

> 본 문서는 `00_GN_DW_PROJECT.md`를 LLM 파싱에 유리하도록 재구성한 작업계획서다.
> 객체 정의는 YAML 블록으로, 관계는 명시적 ID/참조로 표현한다. 설명은 한국어, 구조 키는 영어다.
>
> **문서 구성:** 0. 작업 개요 → 핵심 원칙 → 1~8. 작업 단계별 상세

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
```

### 0.2 산출물 (deliverables)

```yaml
deliverables:
  databases: { GN_DW: 1 }
  schemas: [BRONZE, SILVER, GOLD, SERVING, OPS, SECURITY]   # 6
  warehouses: 3
  roles: 6
  bronze_tables: 26      # DIM 5 + FACT 21
  silver_tables: 23
  gold_views: 35
  forecast_tables: 5
  semantic_views: 7
  agents: 1
  streamlit_apps: 6
  refine_procedures: 18
  utility_procedures: 3
  forecast_procedures: 1
  tasks: 4
  resource_monitors: 4
  alerts: 3
  cost_report_views: 2
```

### 0.3 전제조건 (prerequisites)

```yaml
prerequisites:
  - "PoC 소스 DB(GN_DW_POC) 존재 및 RAW/ANALYTICS 객체 접근 가능"
  - "ACCOUNTADMIN 권한(초기 셋업) / 이후 SYSADMIN·SECURITYADMIN으로 위임"
  - "BRONZE 적재 표준안 Excel_to_Table_개선.ipynb 준비"
  - "Serverless 태스크용 EXECUTE MANAGED TASK ON ACCOUNT 권한"
```

### 0.4 실행 순서 (execution_order)

> SQL 파일을 아래 순서대로 실행한다. 03_03(GOLD View)은 view-on-view 의존성에 따라 하위 View 우선 생성.

```yaml
execution_order:
  - { step: 1,  section: 1,   sql: "01_환경세팅.sql",          topic: timezone + warehouses }
  - { step: 2,  section: 2,   sql: "02_유저_Role_세팅.sql",     topic: roles + users + grants 사전 }
  - { step: 3,  section: 3.1, sql: "03_01_DB_스키마_생성.sql",   topic: database + 6 schemas }
  - { step: 4,  section: 3.3, sql: "03_02_BRONZE_테이블_생성.sql", topic: 26 bronze tables }
  - { step: 5,  section: 4,   sql: "04_프로시저_생성.sql",       topic: ETL_LOG + 정제/유틸 프로시저 (SILVER 23개 산출) }
  - { step: 6,  section: 3.5, sql: "03_03_GOLD_View_생성.sql",   topic: 35 gold views + 5 forecast 테이블 DDL }
  - { step: 7,  section: 3.6, sql: "03_04_Semantic_View_생성.sql", topic: 7 semantic views }
  - { step: 8,  section: 3.7, sql: "03_05_Agent_생성.sql",       topic: GN_DW_AGENT }
  - { step: 9,  section: 3.9, sql: "03_07_Streamlit_배포.sql",   topic: 6 streamlit apps }
  - { step: 10, section: 3.8, sql: "03_06_권한_부여.sql",        topic: grants + future grants }
  - { step: 11, section: 5,   sql: "05_태스크_생성.sql",         topic: 4 tasks (DAG) }
  - { step: 12, section: 6,   sql: "06_테스트.sql",             topic: 권한/E2E/정합성 테스트 }
  - { step: 13, section: 7,   sql: "07_보안_세팅.sql",          topic: network + masking + mfa }
  - { step: 14, section: 8,   sql: "08_모니터링_세팅.sql",       topic: resource monitor + alert + cost }
order_note: "정제 프로시저(step5)가 SILVER를 산출해야 GOLD View(step6)가 SILVER 참조 가능 → 04를 03_03보다 먼저 실행"
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
  - { id: R1, item: "네트워크 정책 적용 시 본인 IP 미포함 → 즉시 잠김", mitigation: "ALLOWED에 본인 IP 포함 후 테스트하고 적용 (7.1)" }
  - { id: R2, item: "VQR 내 GN_DW_POC.RAW/ANALYTICS 경로 잔존 → ANALYST/VIEWER 권한 오류", mitigation: "VQR 경로 전부 GN_DW.GOLD.*로 치환 (3.6)" }
  - { id: R3, item: "BRONZE APPEND 반복 중복", mitigation: "MERGE 또는 DELETE+INSERT 멱등성 (P6)" }
  - { id: R4, item: "GOLD view-on-view 생성 순서 오류", mitigation: "하위 View 우선 생성 (3.5)" }
  - { id: R5, item: "07 SQL의 GN_DW_MASKING_ADMIN 역할이 02에 미정의", mitigation: "SQL 편집 시 역할 정리 (3.8)" }
  - { id: R6, item: "예상치 못한 크레딧 폭주", mitigation: "Resource Monitor 임계 SUSPEND (8.1)" }
```

---

## 핵심 원칙 (global_principles)

```yaml
principles:
  - id: P1
    name: layer_separation
    desc: "BRONZE→SILVER→GOLD는 데이터 정제 계층, SERVING은 소비(SV/Agent/Streamlit) 계층"
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
```

---

## 1. 환경 세팅 (environment)

- **sql_file**: `01_환경세팅.sql`

### 1.1 Timezone (timezone)

```yaml
timezone:
  level: ACCOUNT
  value: Asia/Seoul
  utc_offset: "+9"
  note: "유저/세션 레벨 개별 오버라이드 가능"
```

### 1.2 Warehouses (warehouses)

```yaml
warehouses:
  - id: GN_DW_ETL_WH
    purpose: ETL / 데이터 적재
    size: SMALL
    auto_suspend_sec: 60
    auto_resume: true
    note: "프로시저/태스크 전용"
  - id: GN_DW_ANALYTICS_WH
    purpose: 분석가 쿼리
    size: MEDIUM
    auto_suspend_sec: 300
    auto_resume: true
    note: "Analyst role 전용"
  - id: GN_DW_DEV_WH
    purpose: 개발/테스트
    size: XSMALL
    auto_suspend_sec: 60
    auto_resume: true
    note: "Engineer role 전용"
design_notes:
  - "ETL과 분석 쿼리 분리 -> 상호 간섭 방지"
  - "Auto Suspend 짧게(최소 60초, per-second billing) -> 유휴 비용 최소화"
  - "운영 중 ALTER WAREHOUSE로 사이즈 즉시 변경 가능"
```

---

## 2. 유저 & Role 세팅 (rbac)

- **sql_file**: `02_유저_Role_세팅.sql`

### 2.1 Role 계층 (role_hierarchy)

```yaml
role_hierarchy:
  ACCOUNTADMIN:
    SYSADMIN:
      GN_DW_ADMIN:        # DB/스키마 관리, DDL
        - GN_DW_ENGINEER  # ETL 개발, 프로시저/태스크 운영
        - GN_DW_ANALYST:  # 분석 쿼리 (SELECT only)
            - GN_DW_VIEWER # 읽기 전용 (GOLD View 읽기 + SERVING 소비)
        - GN_DW_LOADER    # 외부팀 BRONZE 적재
        - GN_DW_SERVICE   # 서비스 계정 (API, Streamlit)
    SECURITYADMIN: {}     # Role 관리
```

### 2.2 Roles (roles)

```yaml
roles:
  - id: GN_DW_ADMIN
    purpose: DB 관리, DDL
    warehouse: [GN_DW_DEV_WH]
    scope: 전체
  - id: GN_DW_ENGINEER
    purpose: ETL 개발, 프로시저
    warehouse: [GN_DW_ETL_WH, GN_DW_DEV_WH]
    scope: "BRONZE, SILVER, GOLD, SERVING(USAGE)"
  - id: GN_DW_ANALYST
    purpose: 분석 쿼리
    warehouse: [GN_DW_ANALYTICS_WH]
    scope: "SILVER(읽기), GOLD(읽기), SERVING(SV/Agent 소비)"
  - id: GN_DW_VIEWER
    purpose: 대시보드/리포트
    warehouse: [GN_DW_ANALYTICS_WH]
    scope: "GOLD View(읽기), SERVING(SV/Agent/Streamlit 소비)"
  - id: GN_DW_LOADER
    purpose: 외부팀 적재
    warehouse: [GN_DW_ETL_WH]
    scope: "BRONZE(쓰기)"
  - id: GN_DW_SERVICE
    purpose: 서비스 계정
    warehouse: [GN_DW_ANALYTICS_WH]
    scope: "GOLD(읽기), SERVING(소비)"
creation_rules:
  - "6개 Role 생성 후 GRANT ROLE TO ROLE로 계층 구성"
  - "모든 Custom Role 최종 SYSADMIN 귀속 (P4)"
```

### 2.3 유저 생성 (user_provisioning)

```yaml
user_attributes:
  DEFAULT_ROLE: "주 업무 Role"
  DEFAULT_WAREHOUSE: "Role에 맞는 Warehouse"
  DEFAULT_NAMESPACE: "GN_DW.GOLD(분석가) 또는 GN_DW.BRONZE(엔지니어)"
  MUST_CHANGE_PASSWORD: true
note: "실제 유저 정보(이름/이메일)는 조직 정책에 따라 기입. SQL은 템플릿만 제공"
```

---

## 3. 오브젝트 & 권한 세팅 (objects)

- **sql_files**: `03_01` ~ `03_07`

### 3.1 Database (database)

```yaml
database:
  id: GN_DW
  owner_role: GN_DW_ADMIN   # SYSADMIN에서 생성 후 이관
  data_retention_days: 1    # 기본, 운영 후 조정
```

### 3.2 Schemas (schemas)

```yaml
schemas:
  - id: BRONZE
    purpose: 원천 데이터 적재 (외부팀)
    owner: GN_DW_ADMIN
    note: "LOADER role 쓰기 권한"
  - id: SILVER
    purpose: 정제/변환 레이어
    owner: GN_DW_ADMIN
    note: "물리 테이블 (프로시저 갱신)"
  - id: GOLD
    purpose: 분석 View + 예측(Forecast) 물리 테이블
    owner: GN_DW_ADMIN
    note: "데이터 프로덕트 계층. Analyst/Viewer 읽기 전용(owner's rights)"
  - id: SERVING
    purpose: Semantic View + Agent + Streamlit
    owner: GN_DW_ADMIN
    note: "소비/서비스 계층. GOLD View를 cross-schema 참조. Viewer 소비 지점"
  - id: OPS
    purpose: 비용 리포트 View (+향후 모니터링 객체)
    owner: GN_DW_ADMIN
    note: "운영 메타데이터. ETL_LOG·Alert는 SILVER 유지, Resource Monitor는 계정 레벨"
  - id: SECURITY
    purpose: 마스킹 정책 · 네트워크 룰/정책 객체
    owner: GN_DW_ADMIN
    note: "거버넌스 정책 격리"
schema_contents:
  GOLD: { views: 35, forecast_tables: 5 }
  SERVING: { semantic_views: 7, agents: 1, streamlit_apps: 6 }
naming_note: "PoC ANALYTICS 스키마(=현 GOLD View)와 혼동 방지 위해 소비 계층은 SERVING으로 명명"
```

### 3.3 BRONZE 테이블 (bronze_tables)

> PoC `RAW` 스키마 → `GN_DW.BRONZE` 매핑. DIM 5 + FACT 21 = **26개**.

```yaml
bronze_dim_tables:
  - { id: DIM_CAMPAIGN_CODE, desc: 캠페인 코드 마스터 }
  - { id: DIM_CAMPAIGN_CODE_BACKUP, desc: 캠페인 코드 백업 }
  - { id: DIM_MEMBER_ATTRIBUTE, desc: "회원 속성(성별/연령대/지역)" }
  - { id: DIM_ORG_CODE, desc: 조직 부서 코드 }
  - { id: DIM_TEMP_TO_REGULAR_MATCH, desc: 일시→정기회원 매칭 }
bronze_fact_tables:
  - { id: FACT_AD_GA_AUDIENCE, desc: GA 잠재고객 세션 }
  - { id: FACT_AD_GOOGLE_DEMANDGEN, desc: Google 디맨드젠 광고 }
  - { id: FACT_AD_GOOGLE_PMAX, desc: Google P-MAX 광고 }
  - { id: FACT_AD_META, desc: Meta 광고 성과 }
  - { id: FACT_DIGITAL_AD_DETAIL, desc: 디지털 광고 상세 }
  - { id: FACT_DIGITAL_MONTHLY_DEV, desc: 디지털 월별 개발 목표/실적 }
  - { id: FACT_DISCONTINUED_MEMBER, desc: 중단회원 }
  - { id: FACT_DRTV_BROADCAST_EFF, desc: DRTV 방송효과 }
  - { id: FACT_DRTV_MONTHLY_DEV, desc: DRTV 월별 개발 목표/실적 }
  - { id: FACT_GA_FEEDBACK_PAGE, desc: GA 피드백 페이지 }
  - { id: FACT_GA_VISITS_APP, desc: "GA 방문(앱)" }
  - { id: FACT_GA_VISITS_MOBILE, desc: "GA 방문(모바일)" }
  - { id: FACT_GA_VISITS_PC, desc: "GA 방문(PC)" }
  - { id: FACT_GA_VISITS_TOTAL, desc: "GA 방문(전체)" }
  - { id: FACT_MARKETING_SEND_NEW, desc: "마케팅 발송(신규)" }
  - { id: FACT_MEMBER_DEV_ALL, desc: 회원 개발 전체 }
  - { id: FACT_PAYMENT_HISTORY, desc: 납입 이력 }
  - { id: FACT_RETRANSMIT_BROADCAST_CONV, desc: 재송출 방송 전환 }
  - { id: FACT_RETRANSMIT_MONTHLY_DEV, desc: 재송출 월별 개발 }
  - { id: FACT_SMS_ALIMTALK_SEND, desc: SMS/알림톡 발송 }
  - { id: FACT_TEMP_MEMBER_DONATION, desc: 일시후원 기부 }
```

```yaml
bronze_load_policy:
  poc_flow: "Excel -> Stage -> pandas -> Snowpark DataFrame -> RAW 테이블"
  comparison:
    - { item: 적재주체, poc: "ACCOUNTADMIN, 노트북 수동", gn_dw: "GN_DW_LOADER(최소권한)" }
    - { item: 적재방식, poc: "Snowpark create_dataframe 단건", gn_dw: "대용량은 Excel→Parquet→COPY INTO 권장" }
    - { item: 멱등성, poc: "APPEND 반복 중복 위험", gn_dw: "MERGE 또는 DELETE+INSERT" }
    - { item: 검증, poc: "row count만", gn_dw: "SP_VALIDATE_BRONZE_DATA(4.3)" }
    - { item: 스케줄, poc: 수동, gn_dw: "태스크 05:30 VALIDATE_BRONZE 이전 적재 완료 가정" }
  boundary: "BRONZE 적재 파이프라인 구현은 외부팀(LOADER) 담당으로 범위 밖. 본 문서 책임은 SILVER 정제부터. 적재 표준안=Excel_to_Table_개선.ipynb"
```

### 3.4 SILVER 정제 레이어 (silver_tables)

> SILVER 변환 로직은 4단계 프로시저에서 구현. 26개 BRONZE 중 **23개** 정제.
> 규칙: GOLD View가 소비하는 모든 BRONZE는 SILVER 정제본 필수.

```yaml
silver_tables:
  dim: [DIM_CAMPAIGN_CODE, DIM_MEMBER_ATTRIBUTE, DIM_ORG_CODE, DIM_TEMP_TO_REGULAR_MATCH]
  member_payment: [FACT_MEMBER_DEV_ALL, FACT_PAYMENT_HISTORY, FACT_DISCONTINUED_MEMBER]
  media_ad: [FACT_DRTV_BROADCAST_EFF, FACT_DRTV_MONTHLY_DEV, FACT_DIGITAL_AD_DETAIL, FACT_DIGITAL_MONTHLY_DEV, FACT_RETRANSMIT_BROADCAST_CONV, FACT_RETRANSMIT_MONTHLY_DEV]
  digital_ga: [FACT_AD_GA_AUDIENCE, FACT_AD_META, FACT_GA_VISITS_TOTAL, FACT_GA_VISITS_PC, FACT_GA_VISITS_MOBILE, FACT_GA_VISITS_APP]
  messaging_etc: [FACT_SMS_ALIMTALK_SEND, FACT_MARKETING_SEND_NEW, FACT_GA_FEEDBACK_PAGE, FACT_TEMP_MEMBER_DONATION]
silver_total: 23
excluded:
  - { id: DIM_CAMPAIGN_CODE_BACKUP, reason: 백업 }
  - { id: FACT_AD_GOOGLE_DEMANDGEN, reason: "현재 GOLD View 미참조" }
  - { id: FACT_AD_GOOGLE_PMAX, reason: "현재 GOLD View 미참조" }
```

### 3.5 GOLD 분석 View (gold_views)

> PoC `ANALYTICS` → `GN_DW.GOLD` 매핑. 모든 View는 SILVER 또는 GOLD 내부 객체만 참조(P2).
> 총계: PoC 26(A 11 + C 15) + 재설계 래핑 9(B) = **35 View**.

```yaml
gold_views_A_agent_consumed:   # Semantic View가 소비 (11)
  - { id: V_PAYMENT_ANALYSIS, desc: "납입이력+캠페인+회원특성 통합" }
  - { id: V_MEMBER_DEV_DETAIL, desc: 회원 개발 상세 }
  - { id: V_DISCONTINUATION_REPORT, desc: 중단회원 리포트 }
  - { id: V_RETENTION_BY_PERIOD, desc: "캠페인별 유지율(중단 교차)" }
  - { id: V_DISCONTINUED_DETAIL, desc: "중단회원 상세(유지일수/주차)" }
  - { id: V_DISCONTINUED_PAYMENT_ANALYSIS, desc: 중단회원 미납이력 교차 }
  - { id: V_TEMP_MEMBER_CONVERSION, desc: 일시→정기 전환 }
  - { id: V_ALIMTALK_INCREASE_CROSS, desc: "알림톡수신 x 증액 크로스" }
  - { id: V_SEND_CONVERSION_ANALYSIS, desc: 발송유형별 전환분석 }
  - { id: V_APP_ENGAGEMENT, desc: 앱 방문/이벤트 분석 }
  - { id: V_MEMBER_JOURNEY, desc: 회원 후원 전후 통합 여정 }

gold_views_B_wrapping:   # BRONZE 직접참조 제거용 SILVER 기반 정형화 View (9)
  - { id: V_SMS_ALIMTALK_SEND, replaces: FACT_SMS_ALIMTALK_SEND, used_by_sv: SV_MARKETING_MESSAGING }
  - { id: V_DIGITAL_AD_DETAIL, replaces: FACT_DIGITAL_AD_DETAIL, used_by_sv: SV_AD_PLATFORM }
  - { id: V_AD_GA_AUDIENCE, replaces: FACT_AD_GA_AUDIENCE, used_by_sv: SV_AD_PLATFORM }
  - { id: V_AD_META, replaces: FACT_AD_META, used_by_sv: SV_AD_PLATFORM }
  - { id: V_GA_VISITS_TOTAL, replaces: FACT_GA_VISITS_TOTAL, used_by_sv: SV_WEB_APP_ANALYTICS }
  - { id: V_GA_VISITS_PC, replaces: FACT_GA_VISITS_PC, used_by_sv: SV_WEB_APP_ANALYTICS }
  - { id: V_GA_VISITS_MOBILE, replaces: FACT_GA_VISITS_MOBILE, used_by_sv: SV_WEB_APP_ANALYTICS }
  - { id: V_GA_VISITS_APP, replaces: FACT_GA_VISITS_APP, used_by_sv: SV_WEB_APP_ANALYTICS }
  - { id: V_GA_FEEDBACK_PAGE, replaces: FACT_GA_FEEDBACK_PAGE, used_by_sv: SV_WEB_APP_ANALYTICS }

gold_views_C_streamlit_forecast:   # Agent 미사용, Streamlit/예측 소비 (15)
  media_efficiency: [V_MEDIA_EFFICIENCY_DETAIL, V_CHANNEL_ROI, V_BUDGET_EFFICIENCY, V_DRTV_SPOT_EFFICIENCY, V_TIME_SLOT_EFFICIENCY]
  campaign_perf: [V_CAMPAIGN_ROI, V_CAMPAIGN_LTV, V_MEMBER_DEV_STATUS, V_LOYAL_MEMBER_ANALYSIS, V_CONVERTED_MEMBER_PROFILE]
  messaging: [V_ALIMTALK_EFFECTIVENESS]
  forecast_ml: [V_CAMPAIGN_DEV_FORECAST, V_CAMPAIGN_FEE_FORECAST, V_FORECAST_DEV_COUNT, V_FORECAST_AVG_PAYMENT]

gold_views_D_forecast_tables:   # 예측 물리 테이블 (5), 4.2 SP_REFRESH_FORECAST_DATA가 갱신
  - FORECAST_TRAINING_DATA
  - TRAIN_AVG_PAYMENT
  - TRAIN_DEV_COUNT
  - FORECAST_AVG_PAYMENT_RESULT
  - FORECAST_DEV_COUNT_RESULT
```

```yaml
# GOLD View -> SILVER 소스 매핑. [G] = GOLD 내부 view-on-view (BRONZE 미접근)
gold_view_source_map:
  V_PAYMENT_ANALYSIS: [FACT_PAYMENT_HISTORY, FACT_MEMBER_DEV_ALL, FACT_DISCONTINUED_MEMBER, DIM_CAMPAIGN_CODE, DIM_MEMBER_ATTRIBUTE]
  V_MEMBER_DEV_DETAIL: [FACT_MEMBER_DEV_ALL, DIM_MEMBER_ATTRIBUTE, DIM_CAMPAIGN_CODE, DIM_ORG_CODE]
  V_DISCONTINUATION_REPORT: [FACT_DISCONTINUED_MEMBER, DIM_MEMBER_ATTRIBUTE, DIM_CAMPAIGN_CODE, DIM_ORG_CODE]
  V_RETENTION_BY_PERIOD: [FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE, FACT_DISCONTINUED_MEMBER]
  V_DISCONTINUED_DETAIL: [FACT_DISCONTINUED_MEMBER, DIM_MEMBER_ATTRIBUTE]
  V_DISCONTINUED_PAYMENT_ANALYSIS: ["[G]V_DISCONTINUED_DETAIL", FACT_PAYMENT_HISTORY]
  V_TEMP_MEMBER_CONVERSION: [DIM_TEMP_TO_REGULAR_MATCH, FACT_TEMP_MEMBER_DONATION, FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE]
  V_ALIMTALK_INCREASE_CROSS: [FACT_SMS_ALIMTALK_SEND, FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE]
  V_SEND_CONVERSION_ANALYSIS: [FACT_SMS_ALIMTALK_SEND, FACT_MEMBER_DEV_ALL]
  V_APP_ENGAGEMENT: [FACT_GA_VISITS_APP]
  V_MEMBER_JOURNEY: ["[G]V_MEMBER_DEV_DETAIL", "[G]V_ALIMTALK_INCREASE_CROSS", "[G]V_DISCONTINUED_DETAIL", "[G]V_APP_ENGAGEMENT", FACT_AD_GA_AUDIENCE, FACT_SMS_ALIMTALK_SEND]
  V_MEDIA_EFFICIENCY_DETAIL: [FACT_DRTV_BROADCAST_EFF, FACT_DIGITAL_AD_DETAIL, FACT_RETRANSMIT_BROADCAST_CONV, DIM_CAMPAIGN_CODE]
  V_CHANNEL_ROI: ["[G]V_MEDIA_EFFICIENCY_DETAIL", FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE]
  V_CAMPAIGN_ROI: ["[G]V_MEDIA_EFFICIENCY_DETAIL", FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE]
  V_BUDGET_EFFICIENCY: [FACT_DRTV_MONTHLY_DEV, FACT_DIGITAL_MONTHLY_DEV, FACT_RETRANSMIT_MONTHLY_DEV]
  V_MEMBER_DEV_STATUS: [FACT_DRTV_MONTHLY_DEV, FACT_DIGITAL_MONTHLY_DEV, FACT_RETRANSMIT_MONTHLY_DEV]
  V_DRTV_SPOT_EFFICIENCY: [FACT_DRTV_BROADCAST_EFF]
  V_TIME_SLOT_EFFICIENCY: [FACT_DRTV_BROADCAST_EFF, FACT_RETRANSMIT_BROADCAST_CONV]
  V_CAMPAIGN_LTV: [FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE]
  V_CAMPAIGN_DEV_FORECAST: [FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE, DIM_ORG_CODE]
  V_CAMPAIGN_FEE_FORECAST: [FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE]
  V_LOYAL_MEMBER_ANALYSIS: [FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE, DIM_MEMBER_ATTRIBUTE]
  V_CONVERTED_MEMBER_PROFILE: [FACT_MEMBER_DEV_ALL, DIM_MEMBER_ATTRIBUTE, DIM_CAMPAIGN_CODE, DIM_ORG_CODE]
  V_ALIMTALK_EFFECTIVENESS: [FACT_SMS_ALIMTALK_SEND, FACT_MARKETING_SEND_NEW, FACT_MEMBER_DEV_ALL]
  V_FORECAST_AVG_PAYMENT: [TRAIN_AVG_PAYMENT, FORECAST_AVG_PAYMENT_RESULT]
  V_FORECAST_DEV_COUNT: [TRAIN_DEV_COUNT, FORECAST_DEV_COUNT_RESULT]
  B_wrapping_views: "각 1:1 대응 SILVER 테이블 (3.5 B 참조)"
view_on_view_warning: "V_MEMBER_JOURNEY·V_CHANNEL_ROI·V_CAMPAIGN_ROI·V_DISCONTINUED_PAYMENT_ANALYSIS는 하위 View 먼저 생성하도록 순서 정렬"
```

### 3.6 Semantic View (semantic_views)

> `GN_DW.SERVING`에 재생성. base 객체는 모두 GOLD View(P2). cross-schema로 `GN_DW.GOLD.V_*` 참조.

```yaml
semantic_views:
  - { id: SV_PAYMENT_ANALYSIS, refs: [V_PAYMENT_ANALYSIS], desc: 납입 분석 }
  - { id: SV_MEMBER_LIFECYCLE, refs: [V_DISCONTINUED_DETAIL, V_DISCONTINUED_PAYMENT_ANALYSIS, V_TEMP_MEMBER_CONVERSION], desc: "회원 생애주기(중단/미납/일시→정기)" }
  - { id: SV_MEMBER_DEVELOPMENT, refs: [V_MEMBER_DEV_DETAIL, V_DISCONTINUATION_REPORT, V_RETENTION_BY_PERIOD], desc: 회원 개발/유지율 }
  - { id: SV_MARKETING_MESSAGING, refs: [V_SMS_ALIMTALK_SEND, V_ALIMTALK_INCREASE_CROSS, V_SEND_CONVERSION_ANALYSIS], desc: 마케팅 발송/전환 }
  - { id: SV_AD_PLATFORM, refs: [V_DIGITAL_AD_DETAIL, V_AD_GA_AUDIENCE, V_AD_META], desc: 광고 플랫폼 }
  - { id: SV_WEB_APP_ANALYTICS, refs: [V_APP_ENGAGEMENT, V_GA_VISITS_TOTAL, V_GA_VISITS_PC, V_GA_VISITS_MOBILE, V_GA_VISITS_APP, V_GA_FEEDBACK_PAGE], desc: 웹/앱 분석 }
  - { id: SV_MEMBER_JOURNEY, refs: [V_MEMBER_JOURNEY], desc: 회원 여정 }
redesign_notes:
  - "PoC에서 SV_MARKETING_MESSAGING·SV_AD_PLATFORM·SV_WEB_APP_ANALYTICS가 RAW(BRONZE) 직접참조 -> 모두 3.5(B) SILVER 기반 GOLD View 경유로 변경"
  - "VQR 경로 치환 필수: ai_verified_queries의 GN_DW_POC.RAW.* / GN_DW_POC.ANALYTICS.* -> GN_DW.GOLD.*. (Cortex Analyst/Agent는 VQR SQL을 실행 role 권한으로 base 객체에 직접 실행)"
  - "소스 중복 주의: V_APP_ENGAGEMENT와 V_GA_VISITS_APP 모두 FACT_GA_VISITS_APP 기반. join key/granularity로 중복 집계 방지"
```

### 3.7 Agent (agent)

```yaml
agent:
  id: GN_DW.SERVING.GN_DW_AGENT
  orchestration_model: auto
  budget: { time_sec: 60, tokens: 32000 }
  tools: "Cortex Analyst text-to-SQL 7개 + data_to_chart"
  sample_questions: 6
  access_roles: [GN_DW_ANALYST, GN_DW_VIEWER, GN_DW_SERVICE]
  tool_resources:
    - { tool: payment_analyst, sv: SV_PAYMENT_ANALYSIS, routes: "납입회비, 미납, 청구금액" }
    - { tool: lifecycle_analyst, sv: SV_MEMBER_LIFECYCLE, routes: "중단회원, 유지기간, 일시→정기 전환" }
    - { tool: member_dev_analyst, sv: SV_MEMBER_DEVELOPMENT, routes: "회원개발, 개발건수, ROI, 유지율" }
    - { tool: messaging_analyst, sv: SV_MARKETING_MESSAGING, routes: "알림톡, 문자발송, 발송전환" }
    - { tool: ad_platform_analyst, sv: SV_AD_PLATFORM, routes: "디지털광고, 매체, 구글/메타, CTR/CPC" }
    - { tool: web_app_analyst, sv: SV_WEB_APP_ANALYTICS, routes: "웹/앱 방문" }
    - { tool: journey_analyst, sv: SV_MEMBER_JOURNEY, routes: "회원별 후원 전후 통합 여정" }
  migration_note: "PoC 구버전 GN_DW_POC_AGENT(4 SV)는 폐기. GN_DW_AGENT(7 SV)만 이관"
```

### 3.8 권한 부여 (grants)

```yaml
schema_grants:
  GN_DW_ADMIN:    { BRONZE: ALL, SILVER: ALL, GOLD: ALL, SERVING: ALL }
  GN_DW_ENGINEER: { BRONZE: SELECT, SILVER: "ALL (CREATE TABLE/PROCEDURE/TASK 포함)", GOLD: "USAGE, SELECT, CREATE VIEW", SERVING: USAGE }
  GN_DW_LOADER:   { BRONZE: "INSERT, UPDATE", SILVER: "-", GOLD: "-", SERVING: "-" }
  GN_DW_ANALYST:  { BRONZE: "-", SILVER: SELECT, GOLD: "USAGE, SELECT", SERVING: "USAGE + USAGE ON SV/AGENT/STREAMLIT" }
  GN_DW_VIEWER:   { BRONZE: "-", SILVER: "-", GOLD: "USAGE, SELECT(SV 참조 View)", SERVING: "USAGE + USAGE ON SV/AGENT/STREAMLIT" }
  GN_DW_SERVICE:  { BRONZE: "-", SILVER: "-", GOLD: "USAGE, SELECT", SERVING: "USAGE + USAGE ON SV/AGENT/STREAMLIT" }
grant_notes:
  - "SV/Agent/Streamlit이 SERVING에 위치 -> USAGE ON SV/AGENT/STREAMLIT은 SERVING에서 부여"
  - "Viewer GOLD SELECT 필요 이유: Snowflake Intelligence(CoWork) Agent의 text-to-SQL은 호출자(Viewer) 세션에서 base 객체(GN_DW.GOLD.V_*)에 직접 실행. GOLD owner's rights라 SILVER/BRONZE 권한 불필요"
  - "Streamlit은 owner's rights 실행 -> Viewer는 USAGE ON STREAMLIT만으로 리포트 조회"
ops_security_grants:
  OPS: "GN_DW_ADMIN ALL; GN_DW_ENGINEER·GN_DW_ANALYST SELECT(비용 가시성)"
  SECURITY: "GN_DW_ADMIN만 관리. (07 SQL의 GN_DW_MASKING_ADMIN 역할은 02에 미정의 -> SQL 편집 시 정리 대상)"
future_grants: "향후 생성 테이블/뷰에 자동 권한 부여 설정"
```

### 3.9 Streamlit 대시보드 (streamlit_apps)

> PoC 6종을 `GN_DW.SERVING`에 배포. `GN_DW.GOLD.V_*`만 참조, owner's rights 실행.

```yaml
streamlit_apps:
  - { id: 1, name: "캠페인별 LTV/CAC 분석", refs: [V_CAMPAIGN_LTV, V_CAMPAIGN_ROI] }
  - { id: 2, name: "주요캠페인별 미납현황", refs: [V_PAYMENT_ANALYSIS] }
  - { id: 3, name: "개발회원 후원여정 현황", refs: [V_MEMBER_JOURNEY, V_MEMBER_DEV_DETAIL] }
  - { id: 4, name: "주간중단회원 보고", refs: [V_DISCONTINUED_DETAIL] }
  - { id: 5, name: "주요캠페인별 중단현황", refs: [V_DISCONTINUATION_REPORT, V_DISCONTINUED_DETAIL] }
  - { id: 6, name: "(테스트 앱)", refs: [], note: "운영 이관 시 정리" }
query_warehouse_change: "PoC COMPUTE_WH/POC_WH -> GN_DW_ANALYTICS_WH"
```

---

## 4. 프로시저 생성 (procedures)

- **sql_file**: `04_프로시저_생성.sql`

### 4.1 BRONZE → SILVER 정제 프로시저 (refine_procedures)

```yaml
refine_procedures:
  - { id: 1,  proc: SP_REFINE_DIM_CAMPAIGN, target: [DIM_CAMPAIGN_CODE], work: "중복 제거, 코드 TRIM, 사용여부 필터" }
  - { id: 2,  proc: SP_REFINE_DIM_MEMBER, target: [DIM_MEMBER_ATTRIBUTE], work: "NULL 처리, 연령대/지역 표준화" }
  - { id: 3,  proc: SP_REFINE_FACT_PAYMENT, target: [FACT_PAYMENT_HISTORY], work: "회비청구월 DATE 캐스팅, 미납금액 계산 컬럼" }
  - { id: 4,  proc: SP_REFINE_FACT_MEMBER_DEV, target: [FACT_MEMBER_DEV_ALL], work: "후원신청일 DATE 캐스팅, 신청월 파생" }
  - { id: 5,  proc: SP_REFINE_FACT_DISCONTINUED, target: [FACT_DISCONTINUED_MEMBER], work: "가입일/중단일 DATE 캐스팅, 유지일수 계산" }
  - { id: 6,  proc: SP_REFINE_FACT_DIGITAL_AD, target: [FACT_DIGITAL_AD_DETAIL], work: "FLOAT→NUMBER 캐스팅, NULL 0 대체" }
  - { id: 7,  proc: SP_REFINE_FACT_SMS, target: [FACT_SMS_ALIMTALK_SEND], work: "발송일시 TIMESTAMP, 성공률 NUMBER" }
  - { id: 8,  proc: SP_REFINE_FACT_AD_GA, target: [FACT_AD_GA_AUDIENCE], work: "세션수/활성사용자 NUMBER, 날짜 DATE" }
  - { id: 9,  proc: SP_REFINE_FACT_AD_META, target: [FACT_AD_META], work: "노출/클릭/지출 NUMBER, 보고기간 DATE" }
  - { id: 10, proc: SP_REFINE_FACT_GA_VISITS, target: [FACT_GA_VISITS_TOTAL, FACT_GA_VISITS_PC, FACT_GA_VISITS_MOBILE, FACT_GA_VISITS_APP], work: "세션/페이지뷰/방문수 TEXT→NUMBER (4개 테이블)" }
  - { id: 11, proc: SP_REFINE_FACT_GA_FEEDBACK, target: [FACT_GA_FEEDBACK_PAGE], work: "이탈률/참여율/평균세션시간 NUMBER" }
  - { id: 12, proc: SP_REFINE_DIM_ORG, target: [DIM_ORG_CODE], work: "부서코드 TRIM, 중복 제거" }
  - { id: 13, proc: SP_REFINE_DIM_TEMP_MATCH, target: [DIM_TEMP_TO_REGULAR_MATCH], work: "전환일 DATE, 회원번호 정규화" }
  - { id: 14, proc: SP_REFINE_FACT_DRTV, target: [FACT_DRTV_BROADCAST_EFF, FACT_DRTV_MONTHLY_DEV], work: "횟수/광고비/인입콜/시청률 NUMBER, 방송일자 DATE (2개)" }
  - { id: 15, proc: SP_REFINE_FACT_DIGITAL_DEV, target: [FACT_DIGITAL_MONTHLY_DEV], work: "예산/목표/실적 NUMBER, 날짜 DATE" }
  - { id: 16, proc: SP_REFINE_FACT_RETRANSMIT, target: [FACT_RETRANSMIT_BROADCAST_CONV, FACT_RETRANSMIT_MONTHLY_DEV], work: "횟수/편성비/인입콜 NUMBER, 날짜 DATE (2개)" }
  - { id: 17, proc: SP_REFINE_FACT_MARKETING_SEND, target: [FACT_MARKETING_SEND_NEW], work: "발송일시 TIMESTAMP, 회원번호 정규화" }
  - { id: 18, proc: SP_REFINE_FACT_TEMP_DONATION, target: [FACT_TEMP_MEMBER_DONATION], work: "후원일 DATE, 후원금액 NUMBER" }
refine_principles:
  - "CREATE OR REPLACE TABLE (전체 재생성, 멱등성)"
  - "SILVER = BRONZE 동일구조 + 파생 컬럼 + 올바른 타입"
  - "NULL key 레코드는 WHERE로 제외"
```

### 4.2 SILVER → GOLD 프로시저 (aggregate_procedures)

> GOLD는 View 구성이라 집계 프로시저 불필요. 예측 데이터 갱신만 프로시저 운영.

```yaml
forecast_pipeline:
  proc: SP_REFRESH_FORECAST_DATA
  engine: SNOWFLAKE.ML.FORECAST   # 브랜드별 월간 개발건수/평균납입액 예측
  steps:
    - "학습데이터 생성: SILVER(FACT_MEMBER_DEV_ALL, FACT_PAYMENT_HISTORY) -> FORECAST_TRAINING_DATA -> 브랜드·월 집계로 TRAIN_DEV_COUNT, TRAIN_AVG_PAYMENT"
    - "모델 학습/예측: TRAIN_* 입력으로 ML.FORECAST 모델 생성 후 FORECAST() 호출"
    - "결과 저장: FORECAST_DEV_COUNT_RESULT, FORECAST_AVG_PAYMENT_RESULT"
    - "노출: V_FORECAST_DEV_COUNT, V_FORECAST_AVG_PAYMENT가 TRAIN_*(actual) + FORECAST_*_RESULT(forecast) UNION ALL"
  location: GN_DW.GOLD
  trigger: "5단계 TASK_REFRESH_FORECAST (정제 완료 후 실행)"
```

### 4.3 유틸리티 프로시저 (utility_procedures)

> 의존성 상 ETL_LOG 테이블과 SP_LOG_ETL_STATUS는 4.1보다 먼저 정의 (4.1이 내부 호출).

```yaml
utility_procedures:
  - { id: 1, proc: SP_RUN_ALL_REFINEMENT, desc: "4.1 모든 정제 프로시저 순차 호출(오케스트레이션)" }
  - { id: 2, proc: SP_LOG_ETL_STATUS, desc: "ETL 실행 로그 기록(시작/종료/에러/row count)" }
  - { id: 3, proc: SP_VALIDATE_BRONZE_DATA, desc: "BRONZE 품질 체크(NULL 비율, row count 변동)" }
```

---

## 5. 태스크 생성 (tasks)

- **sql_file**: `05_태스크_생성.sql`

```yaml
tasks:
  - { id: 1, task: TASK_VALIDATE_BRONZE, type: "Root (DAG)", trigger: "CRON 05:30 KST", desc: "BRONZE 품질 체크. 통과 시에만 후속 트리거(게이팅)" }
  - { id: 2, task: TASK_REFINEMENT_ROOT, type: Child, trigger: "AFTER TASK_VALIDATE_BRONZE", desc: "BRONZE→SILVER 전체 정제" }
  - { id: 3, task: TASK_REFRESH_FORECAST, type: Child, trigger: "AFTER TASK_REFINEMENT_ROOT", desc: "GOLD 예측 데이터 갱신" }
  - { id: 4, task: TASK_FINALIZER, type: Finalizer, trigger: "전체 DAG 완료 후", desc: "상태 로그/알림" }
dag: "VALIDATE_BRONZE -> REFINEMENT_ROOT -> REFRESH_FORECAST -> FINALIZER"
schedule_principles:
  - "VALIDATE_BRONZE를 Root로 두어 외부팀 적재 완료 후 품질 우선 검증"
  - "SP_VALIDATE_BRONZE_DATA 임계 위반 시 예외 발생 -> 태스크 실패 -> 후속 차단(게이팅)"
  - "Serverless 모드 (비용 효율, 자동 스케일링)"
  - "Serverless는 EXECUTE MANAGED TASK ON ACCOUNT 권한 필요(02 SQL)"
  - "3회 연속 실패 시 자동 중단(SUSPEND_TASK_AFTER_NUM_FAILURES=3)"
future_extension:
  - "BRONZE 적재 Stream 기반 트리거(WHEN SYSTEM$STREAM_HAS_DATA) 전환 가능"
  - "SILVER→GOLD 성능 이슈 시 CTAS 프로시저 전환 가능"
```

---

## 6. 테스트 (tests)

- **sql_file**: `06_테스트.sql`

```yaml
permission_tests:
  - { case: "BRONZE SELECT", role: GN_DW_ENGINEER, expect: PASS }
  - { case: "BRONZE SELECT", role: GN_DW_ANALYST, expect: FAIL }
  - { case: "BRONZE INSERT", role: GN_DW_LOADER, expect: PASS }
  - { case: "BRONZE INSERT", role: GN_DW_ANALYST, expect: FAIL }
  - { case: "SILVER SELECT", role: GN_DW_ANALYST, expect: PASS }
  - { case: "GOLD SELECT", role: GN_DW_VIEWER, expect: PASS }
  - { case: "GOLD CREATE VIEW", role: GN_DW_VIEWER, expect: FAIL }
  - { case: "Semantic View USAGE", role: GN_DW_ANALYST, expect: PASS }
  - { case: "Agent USAGE", role: GN_DW_VIEWER, expect: PASS }
  - { case: "Agent USAGE", role: GN_DW_LOADER, expect: FAIL }
e2e_pipeline_tests:
  - "1: BRONZE 샘플 INSERT"
  - "2: SP_RUN_ALL_REFINEMENT 실행 -> SILVER 생성 확인"
  - "3: GOLD View 조회 -> 결과 반환 확인"
  - "4: ETL_LOG SUCCESS 확인"
  - "5: EXECUTE TASK 수동 실행 -> 정상 완료 확인"
data_integrity_tests:
  - { check: "Row count 일치", method: "BRONZE vs SILVER 건수 비교" }
  - { check: "NULL key 없음", method: "SILVER PK NULL 체크" }
  - { check: "타입 캐스팅 정상", method: "SILVER 날짜 컬럼 NULL 비율(캐스팅 실패=NULL)" }
  - { check: "View 결과 정합", method: "GOLD View 집계 vs 수기 검산" }
  - { check: "Semantic View 동작", method: "Agent 질문 -> SQL 생성 -> 결과 반환" }
```

---

## 7. 보안 세팅 (security)

- **sql_file**: `07_보안_세팅.sql`

### 7.1 네트워크 (network)

```yaml
network_rules:   # GN_DW.SECURITY 스키마
  - { id: NR_OFFICE_IP, purpose: 사무실 IP 대역 허용, type: "IPV4 (INGRESS)" }
  - { id: NR_VPN_IP, purpose: VPN 접속 IP 허용, type: "IPV4 (INGRESS)" }
  - { id: NR_SERVICE_IP, purpose: 서비스/ETL 서버 IP, type: "IPV4 (INGRESS)" }
network_policies:
  - { id: NP_GN_DW_ACCOUNT, applies_to: Account, desc: "사무실+VPN+서비스 IP만 허용" }
  - { id: NP_GN_DW_SERVICE, applies_to: GN_DW_SERVICE 유저, desc: "서비스 IP만 허용(더 엄격)" }
apply_order:
  - "Network Rule 생성 -> Network Policy 생성 -> 테스트(본인 IP 포함 확인)"
  - "Account 활성화(ALTER ACCOUNT SET NETWORK_POLICY)"
warning: "본인 IP를 ALLOWED에 미포함 시 즉시 잠김. 반드시 테스트 후 적용"
```

### 7.2 마스킹 정책 (masking)

```yaml
masking_policies:   # GN_DW.SECURITY 스키마, SILVER 컬럼 매핑
  - { id: MASK_MEMBER_ID, target_column: 회원번호, rule: "ENGINEER/ADMIN -> 원본, 나머지 -> 앞4자리+****" }
masking_layer:
  - "SILVER 물리 테이블 컬럼에 직접 적용 (View REPLACE 시 정책 단절 방지)"
  - "SILVER 마스킹은 상단 GOLD View까지 자연 상속"
  - "BRONZE는 ANALYST/VIEWER 직접 접근 불가 -> 불필요"
note: "현재 확인된 민감 컬럼=회원번호. 추가 PII 도입 시 동일 패턴 확장"
```

### 7.3 MFA (mfa)

```yaml
mfa_policy:
  - { target: "ACCOUNTADMIN 유저", policy: 필수 }
  - { target: "GN_DW_ADMIN 유저", policy: 필수 }
  - { target: GN_DW_ENGINEER, policy: 권장 }
  - { target: GN_DW_ANALYST, policy: "선택(조직 정책)" }
note: "유저별 웹UI/CLI 설정. DDL 강제 시 AUTHENTICATION POLICY 사용"
```

---

## 8. 모니터링 세팅 (monitoring)

- **sql_file**: `08_모니터링_세팅.sql`

### 8.1 Resource Monitor (resource_monitors)

> 계정 레벨 객체 (특정 스키마 미소속).

```yaml
resource_monitors:
  - { id: RM_ETL, target: GN_DW_ETL_WH, monthly_credit_limit: 200, triggers: "75% 알림, 90% SUSPEND, 100% SUSPEND_IMMEDIATE" }
  - { id: RM_ANALYTICS, target: GN_DW_ANALYTICS_WH, monthly_credit_limit: 500, triggers: "75% 알림, 90% 알림, 100% SUSPEND" }
  - { id: RM_DEV, target: GN_DW_DEV_WH, monthly_credit_limit: 100, triggers: "80% 알림, 100% SUSPEND" }
  - { id: RM_ACCOUNT, target: 전체 계정, monthly_credit_limit: 1000, triggers: "80% 알림, 95% SUSPEND" }
```

### 8.2 Alert (alerts)

> Alert와 ETL_LOG는 운영 파이프라인과 함께 `GN_DW.SILVER` 유지(OPS 이동 시 광범위 수정 발생).

```yaml
alerts:
  - { id: ALERT_ETL_FAILURE, condition: "ETL_LOG ERROR 상태(최근 1시간)", action: 이메일 알림 }
  - { id: ALERT_LONG_QUERY, condition: "쿼리 실행 > 30분", action: 이메일 알림 }
  - { id: ALERT_BRONZE_STALE, condition: "BRONZE 최종 업데이트 > 24시간", action: 이메일 알림 }
```

### 8.3 비용 추적 (cost_tracking)

```yaml
cost_tracking:
  sources:
    - SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY  # Warehouse별 크레딧 추이
    - SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY               # 쿼리별 비용
    - "Resource Monitor 알림 (임계 도달 즉시)"
  cost_report_views:   # 신규 객체, GN_DW.OPS 배치
    - { id: V_MONTHLY_COST_REPORT, desc: "Warehouse별 월간 집계" }
    - { id: V_COST_BY_ROLE, desc: "Role별 일간 집계" }
```
