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
    note: "ALL PRIVILEGES 보유로 모든 WH 사용 가능하나, 기본값은 DEV_WH. 운영 WH(ETL/ANALYTICS) 사용 시 명시적 USE WAREHOUSE 필요"
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
  - "Serverless 태스크용 EXECUTE MANAGED TASK ON ACCOUNT를 GN_DW_ADMIN/ENGINEER에 부여 (04_운영.md 5장 연계)"
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

## 3. 향후 확장: dbt 전용 Role 분리 (방식 C)

> **현재 상태**: dbt는 `GN_DW_ENGINEER` Role을 그대로 사용.
> Gold에 CREATE TABLE이 불필요하므로 별도 Role 없이 운영 가능.

### 3.1 분리 시점 (trigger)

아래 조건 중 하나라도 해당되면 `GN_DW_DBT` Role 분리를 검토:
- dbt가 Gold 스키마에 테이블을 직접 생성해야 하는 경우
- dbt 파이프라인과 수동 ETL(프로시저/태스크)의 권한을 격리해야 하는 경우
- dbt 전용 서비스 계정을 CI/CD에서 사용하는 경우

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
