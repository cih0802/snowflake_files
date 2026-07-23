---
project_id: GN_DW
doc_type: work_plan_chapter
chapter: "01_환경_Role"
sections: [1, 2]
index: "00_INDEX.md"
depends_on: []
provides: [warehouses, roles, users]
language: ko (설명) / en (구조 키)
---

# 01. 환경 & Role 세팅 (environment + rbac)

> 인덱스: `00_INDEX.md` · 핵심 원칙(P1~P7)은 인덱스 참조.
> 본 챕터는 구축 1~2단계(execution_order step 1~2)를 다룬다.
> **실행 정본(멱등 SQL)**: `07_ENVIRONMENT_RBAC_setup.sql` — 본 챕터 §1.2(WH)·§2(역할·계층·권한) + `03_GOLD_SERVING.md §3.8`(스키마 grant)를 한 파일로 부트스트랩.

---

## 1. 환경 세팅 (environment)

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
    note: "dbt 파이프라인(GN_DW.OPS.DW_PIPELINE) 실행 전용. 라이브(2026-07-22): 3종 WH 실측 확인(ETL Small·ANALYTICS Medium·DEV X-Small)"
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

### 2.1 Role 계층 (role_hierarchy)

```yaml
role_hierarchy:
  ACCOUNTADMIN:
    SYSADMIN:
      GN_DW_ADMIN:        # DB/스키마 관리, DDL, SV/Agent 소유
        - GN_DW_ENGINEER  # ETL 개발, dbt 파이프라인 운영
        - GN_DW_ANALYST:  # 분석 쿼리 (SELECT only)
            - GN_DW_VIEWER # 읽기 전용 (GOLD/WIDE 읽기 + SERVING 소비)
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
    note: "ALL PRIVILEGES 보유로 모든 WH 사용 가능하나, 기본값은 DEV_WH. 운영 WH(ETL/ANALYTICS) 사용 시 명시적 USE WAREHOUSE 필요"
  - id: GN_DW_ENGINEER
    purpose: ETL 개발, dbt 파이프라인
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
  - "6개 Role 생성 후 GRANT ROLE TO ROLE로 계층 구성 (라이브 실측: 6종 전량 생성 확인)"
  - "모든 Custom Role 최종 SYSADMIN 귀속 (P4)"
  - "소유 모델: GN_DW DB·전 스키마·테이블/뷰·SV/Agent/DBT PROJECT = GN_DW_ADMIN 소유(07 §B.5로 ACCOUNTADMIN→ADMIN 이관). 커스텀 롤(ENGINEER/ANALYST/VIEWER/LOADER/SERVICE)은 적재·조회만(소유 없음)."
  - "계정 레벨 객체는 ACCOUNTADMIN 유지(이관 대상 아님): 네트워크/인증 정책·Resource Monitor·CoWork object·SNOWFLAKE.CORTEX_* 부여."
  - "MANAGED ACCESS 스키마 → 소유자 GN_DW_ADMIN이 모든 object grant 발급. dbt WIDE view는 생성 롤(ENGINEER) 소유(dbt 산출물)."
  - "ETL은 dbt 파이프라인(GN_DW.OPS.DW_PIPELINE)으로 운영 — 별도 Serverless Task 없음(향후 dbt 스케줄 Task 래핑 시 EXECUTE MANAGED TASK ON ACCOUNT를 GN_DW_ADMIN/ENGINEER에 부여)"
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

## 3. dbt 실행 권한 (GN_DW_ENGINEER — 전용 롤 불필요)

> **현재 상태(라이브 2026-07-22)**: dbt 파이프라인 `GN_DW.OPS.DW_PIPELINE`이 **배포·운영 중**이며, 실행 role은 **`GN_DW_ENGINEER`**(최소권한). 전용 `GN_DW_DBT` Role은 **불필요**(SHOW ROLES 실측 6종).
> **정정(중요)**: dbt는 GOLD/SILVER에 테이블을 **생성하지 않고 적재만** 한다 — dim=incremental merge, fact·silver=append+pre-hook TRUNCATE, WIDE=view. 구조·컬럼 COMMENT·FK는 `06_DDL`/`08_DDL`(소유=GN_DW_ADMIN)이 보존한다. 따라서 dbt 롤에 **GOLD `CREATE TABLE`은 불요**이며, 필요한 것은 granular DML(INSERT/UPDATE/DELETE)·`TRUNCATE`·WIDE용 `CREATE VIEW`뿐이다.
> 권한 사실: `TRUNCATE`는 개별 grant 가능한 TABLE 권한이고, `EXECUTE DBT PROJECT`는 `USAGE ON DBT PROJECT`로 충분 → **소유권 없이 실행 가능**. 구현 grant는 `07_ENVIRONMENT_RBAC_setup.sql` §D.5.

### 3.1 GN_DW_DBT 분리 시점 (trigger) — 현재 **미충족**

아래 조건 중 하나라도 해당될 때만 `GN_DW_DBT` Role 분리를 검토(현재 셋 다 해당 없음):
- ~~dbt가 Gold 스키마에 테이블을 직접 생성해야 하는 경우~~ → **해당 없음**: dbt는 적재 전용(구조는 DDL 소유).
- dbt 파이프라인과 수동 ETL의 권한을 물리적으로 격리해야 하는 경우(감사/규제 요구)
- dbt 전용 서비스 계정을 CI/CD에서 별도 자격증명으로 운용하는 경우

### 3.2 목표 계층 구조

```yaml
# 방식 C: GN_DW_DBT가 GN_DW_ENGINEER를 상속하고, 추가 권한 보유
role_hierarchy_extended:
  GN_DW_ADMIN:
    GN_DW_DBT:              # ENGINEER 상속 + Gold CREATE TABLE
      - GN_DW_ENGINEER      # 기존 ETL 개발 (Gold CREATE TABLE 없음)
    GN_DW_ANALYST:
      - GN_DW_VIEWER
    GN_DW_LOADER: {}
    GN_DW_SERVICE: {}
```

### 3.3 추가 부여 권한 (GN_DW_DBT 전용)

```yaml
gn_dw_dbt_grants:
  inherits: GN_DW_ENGINEER  # 모든 ENGINEER 권한 자동 포함
  additional:
    - "CREATE TABLE ON SCHEMA GN_DW.GOLD"
    - "CREATE TABLE ON SCHEMA GN_DW.SILVER"  # 이미 ENGINEER에 있으므로 중복이나 명시
  warehouse: [GN_DW_ETL_WH, GN_DW_DEV_WH]
  note: |
    일반 ENGINEER 유저는 Gold에 테이블을 생성할 수 없음.
    dbt 파이프라인(또는 dbt 서비스 계정)만 GN_DW_DBT Role로 실행.
```

### 3.4 구현 SQL (필요 시 실행)

```sql
-- 10_dbt_pipeline/dbt_setting.sql 참조
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS GN_DW_DBT COMMENT = 'dbt 파이프라인 전용 - ENGINEER 상속 + Gold DDL';
GRANT ROLE GN_DW_ENGINEER TO ROLE GN_DW_DBT;   -- ENGINEER 권한 상속
GRANT ROLE GN_DW_DBT TO ROLE GN_DW_ADMIN;      -- ADMIN이 DBT 포함

USE ROLE GN_DW_ADMIN;
GRANT CREATE TABLE ON SCHEMA GN_DW.GOLD TO ROLE GN_DW_DBT;
```

---

> **다음 단계:** `02_DB_BRONZE_SILVER.md` (DB/스키마 → BRONZE → SILVER → 프로시저)
