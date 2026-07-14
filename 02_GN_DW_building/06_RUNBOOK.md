---
project_id: GN_DW
doc_type: operations_runbook
chapter: "06_RUNBOOK"
index: "00_INDEX.md"
language: ko (설명) / en (명령어)
target_audience: 운영팀 / 데이터 엔지니어
last_updated: 2026-07-10
---

# GN_DW 운영 매뉴얼 (Runbook)

> 본 문서는 GN_DW 데이터 웨어하우스의 **일상 운영 절차 및 장애 대응 방법**을 기술한다.
> 설계 상세는 `04_운영.md`, 전체 아키텍처는 `05_ARCHITECTURE.md` 참조.

---

## 목차

1. [일상 점검 (Daily Check)](#1-일상-점검-daily-check)
2. [태스크 장애 대응](#2-태스크-장애-대응)
3. [프로시저 수동 실행](#3-프로시저-수동-실행)
4. [BRONZE 적재 이상](#4-bronze-적재-이상)
5. [Warehouse / 크레딧 이상](#5-warehouse--크레딧-이상)
6. [Agent / Semantic View 장애](#6-agent--semantic-view-장애)
7. [Streamlit 앱 장애](#7-streamlit-앱-장애)
8. [보안 사고 대응](#8-보안-사고-대응)
9. [긴급 연락망 / 에스컬레이션](#9-긴급-연락망--에스컬레이션)

---

## 1. 일상 점검 (Daily Check)

매일 **오전 06:30 KST** (DAG 완료 예상 시점 이후) 아래 항목을 확인한다.

### 1.1 태스크 실행 상태

```sql
-- 최근 24시간 태스크 실행 이력
SELECT name, state, scheduled_time, completed_time, error_code, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD(HOUR, -24, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 20
))
ORDER BY scheduled_time DESC;
```

**정상:** 4개 태스크 모두 `SUCCEEDED`
**이상:** 하나라도 `FAILED` → [2. 태스크 장애 대응](#2-태스크-장애-대응) 참조

### 1.2 ETL_LOG 확인

```sql
-- 최근 정제 결과 확인
SELECT proc_name, status, row_count, error_message, run_ts
FROM GN_DW.SILVER.ETL_LOG
WHERE run_ts >= CURRENT_DATE()
ORDER BY run_ts DESC;
```

**정상:** 모든 proc STATUS = 'SUCCESS'
**이상:** STATUS = 'ERROR' 행 존재 → error_message 확인 후 [3. 프로시저 수동 실행](#3-프로시저-수동-실행)

### 1.3 BRONZE 적재 신선도

```sql
-- 대표 CRM 원천 테이블 최종 적재 시점
-- ⚠️ BRONZE는 원천별 스키마로 분리 구현됨: BRONZE_CRM / BRONZE_GA4 / BRONZE_ERP / BRONZE_AGENCY
-- 적재 메타 컬럼은 _LOAD_DT (BRONZE_RAW_load DDL 기준). 대표 테이블=정기회원 마스터.
SELECT 'TM_MM_FDRM_MBER_INFO' AS table_name,
       MAX(_LOAD_DT) AS last_loaded,
       DATEDIFF(HOUR, MAX(_LOAD_DT), CURRENT_TIMESTAMP()) AS hours_stale
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
HAVING DATEDIFF(HOUR, MAX(_LOAD_DT), CURRENT_TIMESTAMP()) > 24;
```

**이상 시:** [4. BRONZE 적재 이상](#4-bronze-적재-이상) 참조

### 1.4 크레딧 사용량

```sql
-- 당월 Warehouse별 크레딧 누적
SELECT warehouse_name, SUM(credits_used) AS credits_mtd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATE_TRUNC('MONTH', CURRENT_DATE())
GROUP BY warehouse_name
ORDER BY credits_mtd DESC;
```

---

## 2. 태스크 장애 대응

### 2.1 장애 확인 흐름

```
TASK_HISTORY에서 FAILED 확인
       │
       ├── TASK_VALIDATE_BRONZE 실패
       │      → BRONZE 품질 문제 (데이터 누락/중복/임계 위반)
       │      → 원인: 외부팀 적재 오류
       │      → 조치: 외부팀에 재적재 요청 후 수동 재실행
       │
       ├── TASK_REFINEMENT_ROOT 실패
       │      → 정제 프로시저 에러
       │      → 조치: ETL_LOG에서 실패 프로시저 특정 → 수동 재실행
       │
       ├── TASK_LOAD_GOLD 실패
       │      → SILVER→GOLD star schema 적재 에러
       │      → 조치: SP_LOAD_GOLD 수동 실행 (ETL_LOG에서 실패 대상 DIM/FACT 특정)
       │
       └── 3회 연속 실패 (자동 SUSPEND됨)
              → 조치: 원인 해결 후 RESUME
```

### 2.2 태스크 수동 재실행

```sql
-- Role 전환
USE ROLE GN_DW_ADMIN;

-- 단일 태스크 즉시 실행 (DAG 무시)
EXECUTE TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE;

-- 또는 DAG 전체를 Root부터 재실행
EXECUTE TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE;
-- (후속 Child는 Root 성공 시 자동 트리거)
```

### 2.3 자동 중단된 태스크 재개

```sql
-- 3회 연속 실패로 SUSPEND된 경우
ALTER TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE RESUME;
ALTER TASK GN_DW.SILVER.TASK_REFINEMENT_ROOT RESUME;
ALTER TASK GN_DW.SILVER.TASK_LOAD_GOLD RESUME;
ALTER TASK GN_DW.SILVER.TASK_FINALIZER RESUME;
```

> **주의:** Root 태스크를 마지막에 RESUME해야 Child가 의도치 않게 트리거되지 않음.
> 순서: Finalizer → Load_Gold → Refinement → Validate(Root) 순으로 RESUME.

---

## 3. 프로시저 수동 실행

### 3.1 전체 정제 재실행

```sql
USE ROLE GN_DW_ENGINEER;
USE WAREHOUSE GN_DW_ETL_WH;

-- 전체 정제 (모든 SILVER 테이블 갱신)
CALL GN_DW.SILVER.SP_RUN_ALL_REFINEMENT();
```

### 3.2 개별 프로시저 실행

```sql
-- ETL_LOG에서 실패한 프로시저만 재실행
-- 예: FACT_MEMBER_DEV_ALL 정제 실패 시
CALL GN_DW.SILVER.SP_REFINE_FACT_MEMBER_DEV();
```

### 3.3 GOLD star schema 적재 (수동)

```sql
-- SILVER → GOLD 15 DIM + 9 FACT MERGE 적재
CALL GN_DW.GOLD.SP_LOAD_GOLD();
```

> ⛔ 예측(Forecast) 파이프라인은 제외 결정(2026-07-10)으로 미운영. `SP_REFRESH_FORECAST_DATA`·`TASK_REFRESH_FORECAST`는 비활성.

### 3.4 BRONZE 품질 검증 (수동)

```sql
CALL GN_DW.SILVER.SP_VALIDATE_BRONZE_DATA();
-- 결과: 예외 발생 시 품질 미달, 정상 리턴 시 통과
```

---

## 4. BRONZE 적재 이상

### 4.1 증상별 대응

| 증상 | 원인 | 조치 |
|---|---|---|
| 24시간 이상 미갱신 | 외부팀 적재 미실행 | LOADER 팀에 확인 요청 |
| 행 수 급감 (>50% 감소) | 소스 시스템 장애 또는 적재 스크립트 오류 | LOADER 팀에 재적재 요청 |
| 중복 행 급증 | APPEND 중복 (MERGE 미사용) | 중복 제거 후 재정제 |
| 스키마 변경 (컬럼 추가/삭제) | 소스 시스템 DDL 변경 | BRONZE DDL 수정 → SILVER 프로시저 수정 |

### 4.2 중복 행 제거 (긴급)

```sql
-- 예: TM_MM_FDRM_MBER_INFO(정기회원 마스터)에서 PK(MBER_NO) 기준 중복 제거
-- ⚠️ BRONZE는 원천별 스키마 분리: CRM 테이블은 GN_DW.BRONZE_CRM. 적재 메타=_LOAD_DT
USE ROLE GN_DW_ENGINEER;

CREATE OR REPLACE TABLE GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO AS
SELECT * EXCLUDE rn FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY _LOAD_DT DESC) AS rn
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
)
WHERE rn = 1;

-- 이후 해당 SILVER 정제 재실행
CALL GN_DW.SILVER.SP_REFINE_DIM_MEMBER();
```

---

## 5. Warehouse / 크레딧 이상

### 5.1 Resource Monitor 트리거 시

| 임계 | 동작 | 대응 |
|---|---|---|
| 75% (ETL) / 80% (Account) | 알림 발송 | 비용 추이 확인, 이상 쿼리 조사 |
| 90% (ETL) | WH SUSPEND | 긴급 쿼리 완료 대기 → 다음 주기에 자동 리셋 또는 한도 상향 |
| 100% | SUSPEND IMMEDIATE | 즉시 중단. 운영 영향 확인 후 한도 조정 |

### 5.2 한도 긴급 상향

```sql
USE ROLE ACCOUNTADMIN;

ALTER RESOURCE MONITOR RM_ETL SET CREDIT_QUOTA = 300;  -- 200 → 300
-- 월초에 자동 리셋됨. 임시 상향 후 근본 원인 해결 필수.
```

### 5.3 비정상 쿼리 조사

```sql
-- 최근 24시간 고비용 쿼리 TOP 10
SELECT query_id, user_name, role_name, warehouse_name,
       total_elapsed_time/1000 AS elapsed_sec,
       credits_used_cloud_services,
       SUBSTR(query_text, 1, 200) AS query_preview
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
ORDER BY total_elapsed_time DESC
LIMIT 10;
```

### 5.4 WH 수동 재개

```sql
-- SUSPEND된 Warehouse 수동 RESUME (Monitor 리셋 후)
ALTER WAREHOUSE GN_DW_ETL_WH RESUME;
```

---

## 6. Agent / Semantic View 장애

### 6.1 증상별 대응

| 증상 | 원인 | 조치 |
|---|---|---|
| Agent 응답 없음 / 타임아웃 | Cortex 서비스 일시 장애 | 5분 후 재시도. 지속 시 Snowflake Support 문의 |
| "권한 없음" 오류 | SERVING USAGE 미부여 또는 GOLD SELECT 누락 | 권한 확인 (아래 SQL) |
| SQL 생성 오류 (잘못된 컬럼/테이블) | VQR 경로 오류 또는 SV 정의 불일치 | Semantic View YAML 점검 |
| 응답은 오지만 결과가 비어있음 | GOLD View 참조 SILVER 데이터 없음 | ETL 파이프라인 정상 여부 확인 |

### 6.2 권한 점검

```sql
-- Viewer가 Agent를 사용할 수 있는지 확인
USE ROLE GN_DW_VIEWER;

-- SERVING 스키마 접근
SHOW GRANTS ON SCHEMA GN_DW.SERVING;

-- Agent 사용 권한
SHOW GRANTS ON CORTEX AGENT GN_DW.SERVING.GN_DW_AGENT;

-- GOLD View 접근 (Agent가 생성하는 SQL은 호출자 권한)
SELECT * FROM GN_DW.GOLD.V_PAYMENT_ANALYSIS LIMIT 1;
```

### 6.3 Semantic View 테스트

```sql
-- SV가 정상 응답하는지 직접 테스트
USE ROLE GN_DW_ANALYST;

-- Cortex Analyst 직접 호출 (간단한 질문으로 확인)
-- Snowsight에서 Agent UI로 "이번 달 납입 건수"등 단순 질문 테스트
```

---

## 7. Streamlit 앱 장애

### 7.1 증상별 대응

| 증상 | 원인 | 조치 |
|---|---|---|
| 앱 로딩 안 됨 | WH SUSPEND 또는 크레딧 소진 | WH 상태 확인 → RESUME |
| "Access denied" | Viewer에 STREAMLIT USAGE 미부여 | 권한 확인 |
| 데이터 미표시 | GOLD View 결과 없음 (ETL 미완) | ETL 파이프라인 확인 |
| 앱 오류 (Python traceback) | 코드 버그 또는 의존성 문제 | 개발자 확인 (GN_DW_ENGINEER) |

### 7.2 Streamlit 앱 상태 확인

```sql
USE ROLE GN_DW_ADMIN;
SHOW STREAMLITS IN SCHEMA GN_DW.SERVING;
```

### 7.3 앱 Warehouse 확인

```sql
-- Streamlit은 GN_DW_ANALYTICS_WH 사용
SHOW WAREHOUSES LIKE 'GN_DW_ANALYTICS_WH';
-- STATE = 'SUSPENDED'이면 쿼리 실행 시 자동 RESUME (auto_resume=true)
-- STATE = 'SUSPENDED' + Resource Monitor SUSPEND면 Monitor 해제 필요
```

---

## 8. 보안 사고 대응

### 8.1 계정 잠김 (네트워크 정책 오설정)

```
⚠️  본인 IP가 ALLOWED LIST에서 누락되면 즉시 접속 불가.
    Snowflake Support에 계정 잠금 해제 요청 필요.
```

**예방:**
- 네트워크 정책 변경 전 반드시 본인 IP 포함 확인
- 변경은 항상 테스트 환경에서 먼저 실행

**긴급 복구 (Support 요청 전 시도):**
```sql
-- 다른 관리자가 접속 가능한 경우
USE ROLE SECURITYADMIN;
ALTER ACCOUNT UNSET NETWORK_POLICY;  -- 정책 일시 해제
-- 정책 수정 후 재적용
```

### 8.2 비정상 로그인 감지

```sql
-- 최근 24시간 로그인 실패
SELECT user_name, client_ip, error_code, error_message, event_timestamp
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
  AND is_success = 'NO'
ORDER BY event_timestamp DESC;
```

### 8.3 권한 변경 감사

```sql
-- 최근 24시간 GRANT/REVOKE 이력
SELECT query_text, user_name, role_name, execution_status, start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
  AND (query_text ILIKE '%GRANT%' OR query_text ILIKE '%REVOKE%')
  AND query_type != 'SHOW'
ORDER BY start_time DESC;
```

### 8.4 데이터 유출 의심

```sql
-- 대량 EXPORT/COPY 감지
SELECT user_name, role_name, query_type, 
       rows_produced, bytes_scanned,
       SUBSTR(query_text, 1, 300) AS query_preview
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
  AND (query_type IN ('COPY', 'UNLOAD') OR rows_produced > 1000000)
ORDER BY rows_produced DESC
LIMIT 20;
```

---

## 9. 긴급 연락망 / 에스컬레이션

### 9.1 에스컬레이션 단계

```
Level 1 (15분 이내 대응)
  │  담당: GN_DW_ENGINEER (데이터 엔지니어)
  │  범위: 태스크 실패, 프로시저 오류, 일반 운영 이슈
  │
Level 2 (30분 이내 대응)
  │  담당: GN_DW_ADMIN (관리자)
  │  범위: 권한 문제, DDL 변경, Warehouse 한도 조정, 보안 이슈
  │
Level 3 (1시간 이내 대응)
  │  담당: ACCOUNTADMIN + Snowflake Support
  │  범위: 계정 잠김, 서비스 전체 장애, 크레딧 긴급 상향
  │
외부 (SLA별 대응)
     담당: LOADER 팀 (외부)
     범위: BRONZE 적재 미실행, 소스 데이터 품질 이슈
```

### 9.2 연락처 (템플릿)

| 역할 | 담당자 | 연락처 | 비고 |
|---|---|---|---|
| GN_DW_ENGINEER | (이름) | (전화/슬랙) | 1차 대응 |
| GN_DW_ADMIN | (이름) | (전화/슬랙) | 2차 에스컬 |
| ACCOUNTADMIN | (이름) | (전화/슬랙) | 긴급 |
| LOADER 팀 | (이름) | (이메일) | BRONZE 적재 |
| Snowflake Support | - | support.snowflake.com | 서비스 장애 |

> **참고:** 실제 담당자 정보는 조직 정책에 따라 기입할 것.

---

## 부록: 자주 사용하는 운영 명령어

```sql
-- ═══════════════════════════════════════
-- 태스크 관련
-- ═══════════════════════════════════════
SHOW TASKS IN SCHEMA GN_DW.SILVER;                         -- 태스크 목록
DESCRIBE TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE;           -- 상세 정보
ALTER TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE SUSPEND;      -- 일시 중지
ALTER TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE RESUME;       -- 재개
EXECUTE TASK GN_DW.SILVER.TASK_VALIDATE_BRONZE;            -- 즉시 실행

-- ═══════════════════════════════════════
-- Warehouse 관련
-- ═══════════════════════════════════════
ALTER WAREHOUSE GN_DW_ETL_WH SUSPEND;                      -- 즉시 중지
ALTER WAREHOUSE GN_DW_ETL_WH RESUME;                       -- 재개
ALTER WAREHOUSE GN_DW_ANALYTICS_WH SET WAREHOUSE_SIZE = 'LARGE';  -- 임시 스케일업

-- ═══════════════════════════════════════
-- 오브젝트 확인
-- ═══════════════════════════════════════
SHOW TABLES IN SCHEMA GN_DW.BRONZE_CRM;    -- CRM 원천 (GA4/ERP/AGENCY는 BRONZE_GA4/ERP/AGENCY)
SHOW TABLES IN SCHEMA GN_DW.SILVER;
SHOW VIEWS IN SCHEMA GN_DW.GOLD;
SHOW CORTEX AGENTS IN SCHEMA GN_DW.SERVING;
SHOW STREAMLITS IN SCHEMA GN_DW.SERVING;

-- ═══════════════════════════════════════
-- 권한 확인
-- ═══════════════════════════════════════
SHOW GRANTS TO ROLE GN_DW_VIEWER;
SHOW GRANTS ON SCHEMA GN_DW.SERVING;
SHOW GRANTS ON DATABASE GN_DW;
```

---

> **관련 문서:** `04_운영.md` (설계) · `05_ARCHITECTURE.md` (구조) · `01_환경_Role.md` (Role 정의)
