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
        - GN_DW_ANALYST:  # 분석 쿼리 (SELECT only — BRONZE 포함)
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
    scope: "BRONZE, SILVER, GOLD, SERVING(USAGE), OPS, dbt_test__audit"
    note: |
      🔴 [2026-08-20 O91 정정 ㉠] 종전 scope 는 "BRONZE, SILVER, GOLD, SERVING(USAGE)" 였고
      **`OPS` 와 `dbt_test__audit` 이 누락**돼 있었다. 둘 다 dbt 실행에 필수인 실권한이다:
      · `OPS` = dbt 프로젝트 객체(`GN_DW.OPS.DW_PIPELINE`)와 `store_failures` 테이블의 자리
        ⇒ `USAGE, CREATE TABLE` 필요(07 §D.6-2). 🔴 종전 라이브에는 `USAGE` 가 빠져 있었다.
      · `dbt_test__audit` = dbt 테스트 실패 감사 스키마. 테스트 **343노드**가 이 스키마 소속이라
        `store_failures` 를 OPS 로 돌려도 우회되지 않는다 ⇒ **선생성 + `USAGE, CREATE TABLE`**(07 §D.6-1).
      🟢 2026-08-20 라이브 부여·실측 확인. 구현 정본 = `07_ENVIRONMENT_RBAC_setup.sql` §D.6.
  - id: GN_DW_ANALYST
    purpose: 분석 쿼리
    warehouse: [GN_DW_ANALYTICS_WH]
    scope: "BRONZE_*(읽기), SILVER(읽기), GOLD(읽기), SERVING(SV/Agent/Streamlit 소비)"
    note: |
      🟢 [2026-08-18 요건 변경] BRONZE_* 4스키마 SELECT 추가(종전 "-") + Streamlit 소비·저작.
      구현 = 07 §D.4(BRONZE 읽기) · §D.7(Agent·Streamlit 소비) · §D.8(Workspace 저작 2단계 모델).
      ⚠️ BRONZE 추가로 owner's rights 경유 확산이 새 위험 → 앱 소유는 최소권한 롤(GN_DW_SERVICE),
         앱 코드는 caller's rights 연결을 표준으로 한다(07 §D.7 통제 3원칙).
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
>
> 🔴🔴 **[2026-08-20 O91 정정 ㉡] 위 「dbt 롤에 `CREATE TABLE` 불요」는 데이터 계층(SILVER/GOLD)에만 성립한다 — 무조건 명제가 아니다.**
> 종전 문안은 조건 없이 「불요」로 읽혀 `07 §D.6` 의 예외 2건과 **정면으로 모순**됐다. 축을 명시해 정정한다:
> · 🟢 **여전히 불요** = `GOLD`·`SILVER` 의 구조 생성. 구조·컬럼 COMMENT·FK 는 `06_DDL`/`08_DDL`(소유 = `GN_DW_ADMIN`)이 보존한다.
>   ⚠️ 단 `SILVER` 는 `07 §D.3:225` 가 ENGINEER 에게 `CREATE TABLE` 을 **이미 부여**하고 있다 — 「불요」는 *필요 없다*는 뜻이고 *부여돼 있지 않다*는 뜻이 아니다.
> · 🔴 **필요한 예외 2건**(둘 다 대상이 **데이터가 아니라 테스트 실패 이력**이다):
>   ㉠ `GN_DW.OPS` = `USAGE, CREATE TABLE`(`store_failures` 테이블 · `07 §D.6-2`)
>   ㉡ `GN_DW.dbt_test__audit` = `USAGE, CREATE TABLE`(테스트 **343노드**의 감사 스키마 · `07 §D.6-1`)
> · 🔴 **DB 레벨 `CREATE SCHEMA` 는 여전히 부여하지 않는다** — audit 스키마를 `GN_DW_ADMIN` 이 선생성해 요구를 좁힌다(`07 §D.6` A 항목).
> · 🟢 **판단 기준(일반화)** = 「구조 소유가 DDL 에 있는가」로 가른다. 있으면 불요, dbt 가 스스로 만들고 소유하는 객체면 필요다.

### 3.1 GN_DW_DBT 분리 시점 (trigger) — 현재 **미충족**

아래 조건 중 하나라도 해당될 때만 `GN_DW_DBT` Role 분리를 검토(현재 셋 다 해당 없음):
- ~~dbt가 Gold 스키마에 테이블을 직접 생성해야 하는 경우~~ → **해당 없음**: dbt는 적재 전용(구조는 DDL 소유).
- dbt 파이프라인과 수동 ETL의 권한을 물리적으로 격리해야 하는 경우(감사/규제 요구)
- dbt 전용 서비스 계정을 CI/CD에서 별도 자격증명으로 운용하는 경우
- 🆕 🟠 **[2026-08-20 O91 신설 ㉢ — 재검토 트리거] GA4 평탄화가 Python 저장 프로시저로 이전되는 경우**
  · 배경 = 사용자 제시 방향(「다음주 Python 프로시저가 평탄화 담당」) + **▣4 결정 = ㉡ SILVER 원천 겸용**.
    ⇒ SILVER 에 **원천을 쓰는 주체**가 dbt 외에 하나 더 생긴다 ⇒ 이 절이 요구하는 「권한 물리 격리」 조건에 접근한다.
  · 🟢 **격리가 불필요해질 수도 있다**(방향이 반대로도 작동한다) — SP 를 `GN_DW_ADMIN` 소유 +
    **`EXECUTE AS OWNER`**(기본)로 만들면 SILVER 쓰기가 소유자 권한으로 실행되므로
    ENGINEER 에게는 **`USAGE ON PROCEDURE` 만** 필요해지고 DML grant 대부분이 불요해진다.
    ⚠️ 반대로 `EXECUTE AS CALLER` 면 SILVER 전체 DML 이 필요해진다 ⇒ **OWNER 권장**(「커스텀 롤은 소유 없음」 원칙과 정합).
  · 🔴 **판정 시점** = 프로시저 소유·실행 모델이 확정될 때. 그때 이 트리거를 **충족/미충족으로 닫는다**.
    SP **생성** 권한(`CREATE PROCEDURE ON SCHEMA SILVER`)은 `07 §D.3:225` 에 이미 있고 2026-08-20 라이브 부여도 확인됐다.

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
