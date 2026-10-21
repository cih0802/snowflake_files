# Analyst 셀프서비스 Streamlit — 설계 및 적용 런북

| 항목 | 값 |
|---|---|
| 대상 | GN_DW 데이터웨어하우스 (paid 계정) |
| 설계 결정 | `GN_DW_VIEWER` = 소비자 / `GN_DW_ANALYST` = 소비 + 앱 저작 |
| 검증 환경 | Trial 계정 `AD50130` (AWS_AP_NORTHEAST_2, v10.29.101) |
| 상태 | 미적용 — paid 계정 적용 대기 |

---

## 1. 배경

### 1.1 기존 설계의 공백

GN_DW 역할 설계는 Streamlit을 **중앙 배포 / 광역 소비** 모델로만 정의했다.

| 역할 | 설계상 정의 |
|---|---|
| `GN_DW_ADMIN` | GN_DW DB/스키마 관리·DDL·SV/Agent 소유 |
| `GN_DW_ENGINEER` | ETL 개발·프로시저/태스크 |
| `GN_DW_LOADER` | 외부팀 BRONZE 적재 |
| `GN_DW_SERVICE` | 서비스 계정(API·Streamlit) |
| `GN_DW_ANALYST` | 분석 쿼리(SELECT)·SV/Agent 소비 |
| `GN_DW_VIEWER` | 읽기 전용·SV/Agent/Streamlit 소비 |

`GN_DW.SERVING` 스키마 주석은 "Serving 계층 — Semantic View·Cortex Agent·Streamlit 배치(P7)"로,
`GN_DW_ADMIN` 소유의 **중앙 배포 슬롯**이다. 분석가가 직접 앱을 저작하는 경로는 설계에 존재하지 않는다.

### 1.2 실제 문제는 "차단"이 아니라 "우회"

Trial 계정 실측 결과, 분석가는 **이미 앱을 배포할 수 있다.** 단, 설계 밖에서.

Personal Database(`USER$<USERNAME>`)의 권한은 **역할이 아니라 사용자에게** 부여된다:

```
CREATE SCHEMA  DATABASE  USER$TRIALADMIN  granted_to=USER  TRIALADMIN
USAGE          DATABASE  USER$TRIALADMIN  granted_to=USER  TRIALADMIN  (grant_option=true)
```

`LOCAL`·`PUBLIC` 스키마의 `owner_role_type`이 `USER`다. 즉 `GN_DW_*` 역할 설계를 **완전히 우회**한다.
그리고 앱 실행에 필요한 나머지 조각이 모두 열려 있다:

| 필요 조건 | Trial 실측 | 비고 |
|---|---|---|
| 배포 대상 스키마 | 열림 | Personal DB, 사용자 소유 |
| 컴퓨트 풀 | 열림 | `SYSTEM_COMPUTE_POOL_CPU` USAGE → **PUBLIC** |
| 웨어하우스 | 열림 | `GN_DW_ANALYTICS_WH` (주석: "Analyst·Viewer·Service") |
| 데이터 읽기 | 열림 | `GOLD` SELECT — FUTURE GRANT로 ANALYST/VIEWER 보유 |

> `ENABLE_PERSONAL_DATABASE` = `true`, **기본값 `true`**.
> Paid 계정에서도 별도 조치 없이 열려 있다.

**결론:** 설계 결함이 아니라 **거버넌스 공백**이다. "모든 Streamlit은 `SERVING`에 있다"는
설계 가정이 조용히 깨지며, 다음 리스크가 발생한다.

- Personal DB 앱은 카탈로그·certification·리니지·코드리뷰 **밖**
- 사용자 삭제 시 앱 동반 소실 (`DROPPED_USER$`)
- 공유가 사실상 불가 → 팀 배포를 위해 우회로 발생 → shadow BI
- 웨어하우스·컴퓨트 풀 비용이 발생하나 **귀속 불가**

---

## 2. 설계 결정

### 2.1 채택안

기존 상속 계층에 **생산자 / 소비자 역할을 배정**한다. 새 역할을 만들지 않는다.

```
GN_DW_ADMIN     DDL 소유 · SERVING 인증 배포 (변경 없음)
      │
GN_DW_ANALYST   SELECT · SV/Agent 소비 · ★LAB Streamlit 저작 (추가)
      │ (상속)
GN_DW_VIEWER    읽기 전용 · SV/Agent/Streamlit 소비 (변경 없음)
```

### 2.2 채택 근거

1. **상속 체인이 이미 이 모양이다.** `SHOW GRANTS OF ROLE GN_DW_VIEWER` → `GN_DW_ANALYST`
   단일 상속만 존재. 새 역할을 끼우는 게 아니라 기존 두 계층에 역할을 배정하는 것.
2. **소비자 쪽은 이미 정의되어 있다.** `GN_DW_VIEWER` 주석에 "Streamlit 소비"가 명시됨.
   `GN_DW_ANALYST`를 생산자로 지정하면 생산/소비 짝이 완성된다.
3. **ANALYST는 이미 단순 소비자가 아니다.** VIEWER에 없는 `SILVER` USAGE를 보유.
   저작 권한 추가가 기존 궤적에 부합한다.
4. **역할 수 유지.** 6개 → 6개. `GN_DW_APP_DEV` 신설 대비 거버넌스 표면이 늘지 않는다.
5. **소유자 권한 실행이 거버넌스에 유리.** 앱이 `GN_DW_ANALYST` 권한으로 실행되므로
   마스킹 정책이 앱 내부에도 적용된다. ADMIN이 대신 배포하면 ADMIN 권한으로 실행되어
   마스킹을 **우회**한다.
   ⚠️ 단 현재 `GN_DW.SECURITY`에 마스킹 정책 **0건**. 이는 현재 실익이 아니라 향후 이점이다.

### 2.3 검토 후 기각한 대안

| 대안 | 기각 사유 |
|---|---|
| `GN_DW_APP_DEV` 역할 신설 | 기존 계층과 1:1 대응되는 기능에 역할을 추가 → 역할 스프롤 |
| `GN_DW.PUBLIC`에 부여 | `SYSADMIN` 소유로 `GN_DW_ADMIN` 계층 밖 |
| 기존 `SANDBOX` DB 활용 | `SYSADMIN` 소유. 거버넌스 경계·카탈로그 응집 이탈 |
| `SERVING`에 직접 부여 | 인증 계층 오염. 승격 경계 소멸 |
| 승격 경로만 (셀프서비스 차단) | Personal DB가 기본 개방이라 차단이 실효 없음. 반복 속도 최저 |

### 2.4 수용한 트레이드오프

- **DDL이 분석 역할로 내려온다.** → §3.1 가드레일(스키마 스코프 제한)로 통제.
- **전원 부여다.** ANALYST 보유자 전체가 저작 권한을 갖는다. 일부에게만 줄 수 없다.
  선별이 필요해지면 `GN_DW_APP_DEV` 분리가 필요하며, 이는 되돌리기 작업이다.
  → 적용 전 ANALYST 부여 대상자 명단을 반드시 확인할 것.

---

## 3. 가드레일 (필수)

### 3.1 스키마 스코프 제한

`CREATE STREAMLIT`을 **계정·데이터베이스 단위로 부여하지 않는다.** 전용 스키마 하나에만 부여한다.

| 스키마 | ANALYST `CREATE STREAMLIT` |
|---|---|
| `GN_DW.LAB` | ✅ 부여 |
| `GN_DW.GOLD` / `SILVER` / `BRONZE_*` | ❌ 금지 |
| `GN_DW.SERVING` | ❌ 금지 |
| `GN_DW.OPS` / `SECURITY` | ❌ 금지 |

이것이 "DDL은 ADMIN/ENGINEER" 원칙이 유지되는 유일한 근거다.

### 3.2 SERVING 승격은 ADMIN 독점

`LAB` = 미인증 / `SERVING` = 인증. 승격은 `GN_DW_ADMIN`만 수행한다.
이 경계가 없으면 인증 계층이 오염된다.

### 3.3 3단 배치 정책

| 용도 | 위치 | 공유 | 인증 |
|---|---|---|---|
| 개인 실험 | `USER$<USER>` (Personal DB) | 불가 | 없음 |
| 팀 공유 | `GN_DW.LAB` | 가능 | 미인증 |
| 공식 | `GN_DW.SERVING` | 가능 | 인증 |

---

## 4. Paid 계정 적용 시 Trial과의 차이

> ⚠️ 아래는 Trial 실측값을 그대로 옮기면 안 되는 항목이다.

### 4.1 컴퓨트 풀 — 전용 풀 생성 권장

Trial에서는 `SYSTEM_COMPUTE_POOL_CPU`의 USAGE가 **`PUBLIC`에 부여**되어 있어 모든 역할이 상속받는다.
Snowflake 기본 grant이므로 paid 계정도 동일할 가능성이 높다. 그러나 이 경로에 의존하면:

- LAB 앱의 컴퓨트 비용을 **귀속할 수 없다**
- 다른 워크로드와 풀을 공유해 상호 영향이 발생한다

→ **전용 풀을 생성하고 `GN_DW_ANALYST`에만 부여한다.** (§5 Step 2)

적용 전 확인:
```sql
SHOW GRANTS ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU;
-- USAGE → PUBLIC 행이 있으면, 전용 풀을 만들어도 기본 풀 경로가 남아 있음을 인지할 것
```

### 4.2 Personal Database — 명시적 결정 필요

`ENABLE_PERSONAL_DATABASE`는 **기본값 `true`**다. Paid 계정에서도 열려 있다.

선택지:
- **(권장) 유지 + 정책 문서화** — §3.3의 "개인 실험" 계층으로 공식 인정.
  `LAB`이 더 나은 대안(공유 가능·카탈로그 노출)이므로 자연 유도된다.
- **비활성화** — `ALTER ACCOUNT SET ENABLE_PERSONAL_DATABASE = FALSE;`
  기존 Personal DB 객체 영향도를 먼저 조사해야 한다. Streamlit 외 용도(노트북 등)도 함께 차단된다.

### 4.3 역할 분리

Trial에서는 `ACCOUNTADMIN`으로 전부 실행 가능했으나, paid 계정은 단계별로 역할을 분리한다.

| 작업 | 역할 |
|---|---|
| 컴퓨트 풀 생성 | `ACCOUNTADMIN` (또는 `CREATE COMPUTE POOL` 보유 역할) |
| 웨어하우스 grant | `SYSADMIN` |
| 스키마 생성 / 스키마 grant | `GN_DW_ADMIN` |
| 역할 주석 변경 | `SECURITYADMIN` |

### 4.4 이름 확인

아래는 Trial 실측값이다. Paid 계정 실제 이름으로 치환할 것.

| 플레이스홀더 | Trial 값 |
|---|---|
| `<DB>` | `GN_DW` |
| `<ANALYTICS_WH>` | `GN_DW_ANALYTICS_WH` |
| `<LAB_POOL>` | (신규) `GN_DW_LAB_POOL` |

---

## 5. 적용 절차

> 멱등(idempotent) 구성. 재실행 가능.

### Step 0 — 사전 점검

```sql
USE ROLE GN_DW_ADMIN;

-- (1) 상속 구조가 문서 §2.1 가정과 일치하는지
SHOW GRANTS OF ROLE GN_DW_VIEWER;
-- 기대: GN_DW_VIEWER → ROLE GN_DW_ANALYST 단일 행

-- (2) ANALYST 현재 권한 — CREATE 계열이 없어야 함
SHOW GRANTS TO ROLE GN_DW_ANALYST;

-- (3) LAB 스키마 미존재 확인
SHOW SCHEMAS LIKE 'LAB' IN DATABASE GN_DW;

-- (4) 기존 Streamlit 인벤토리 (적용 전 기준선)
SHOW STREAMLITS IN DATABASE GN_DW;
```

```sql
USE ROLE SECURITYADMIN;
-- (5) ⚠️ ANALYST 부여 대상자 명단 확인 — 전원이 저작 권한을 갖게 된다 (§2.4)
SHOW GRANTS OF ROLE GN_DW_ANALYST;
```

### Step 1 — LAB 스키마 생성

```sql
USE ROLE GN_DW_ADMIN;

CREATE SCHEMA IF NOT EXISTS GN_DW.LAB
  COMMENT = '셀프서비스 계층 — Analyst 저작 Streamlit·프로토타입. 미인증. SERVING 승격은 ADMIN 전용';
```

**MANAGED ACCESS는 설정하지 않는다.** 근거: 앱 소유자(ANALYST)가 자기 앱의 `USAGE`를
직접 부여할 수 있어야 셀프서비스가 성립한다. MANAGED ACCESS를 켜면 모든 공유가
`GN_DW_ADMIN`을 경유해 병목이 된다. 통제는 "미인증" 라벨링과 `SERVING` 인증 계층으로 수행한다.

### Step 2 — 전용 컴퓨트 풀 (§4.1)

```sql
USE ROLE ACCOUNTADMIN;

CREATE COMPUTE POOL IF NOT EXISTS GN_DW_LAB_POOL
  MIN_NODES = 1
  MAX_NODES = 2
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_SUSPEND_SECS = 300
  AUTO_RESUME = TRUE
  COMMENT = 'Analyst 셀프서비스 Streamlit(LAB) 전용. 비용 귀속용';

GRANT USAGE, MONITOR ON COMPUTE POOL GN_DW_LAB_POOL TO ROLE GN_DW_ANALYST;
```

### Step 3 — 권한 부여

```sql
USE ROLE GN_DW_ADMIN;

-- 저작 (ANALYST)
GRANT USAGE            ON SCHEMA GN_DW.LAB TO ROLE GN_DW_ANALYST;
GRANT CREATE STREAMLIT ON SCHEMA GN_DW.LAB TO ROLE GN_DW_ANALYST;

-- 소비 (VIEWER) — ANALYST는 상속으로 자동 획득
GRANT USAGE            ON SCHEMA GN_DW.LAB TO ROLE GN_DW_VIEWER;
```

```sql
USE ROLE SYSADMIN;
-- 웨어하우스: 이미 보유 시 멱등 (Trial 실측 — ANALYST/VIEWER 모두 보유)
GRANT USAGE ON WAREHOUSE GN_DW_ANALYTICS_WH TO ROLE GN_DW_ANALYST;
```

### Step 4 — 설계문서 동기화 (주석 갱신)

> 이 계정은 스키마/역할 **COMMENT가 설계문서 역할**을 한다. 반드시 갱신할 것.

```sql
USE ROLE SECURITYADMIN;
ALTER ROLE GN_DW_ANALYST SET COMMENT =
  '분석 쿼리(SELECT)·SV/Agent 소비 + LAB Streamlit 저작';
ALTER ROLE GN_DW_VIEWER  SET COMMENT =
  '읽기 전용·SV/Agent/Streamlit 소비 (소비자 계층)';
```

### Step 5 — 검증

```sql
-- 부여 결과 확인
USE ROLE GN_DW_ADMIN;
SHOW GRANTS ON SCHEMA GN_DW.LAB;
-- 기대: ANALYST(USAGE, CREATE STREAMLIT), VIEWER(USAGE), ADMIN(OWNERSHIP)

-- 스코프 누출 점검 — 아래 결과에 CREATE STREAMLIT이 없어야 한다
SHOW GRANTS TO ROLE GN_DW_ANALYST;
-- GN_DW.LAB 외 스키마에 CREATE 계열이 있으면 §3.1 위반
```

**실배포 검증 (필수)** — `CREATE STREAMLIT`만으로 워크스페이스 배포가 완결되는지는
권한 부여만으로 단정할 수 없다. 스테이지 등 추가 권한이 필요할 수 있다.

1. `GN_DW_ANALYST`만 보유한 테스트 사용자로 로그인
2. Workspace에서 Streamlit 앱 생성 → App Location = `GN_DW.LAB`
3. Compute pool = `GN_DW_LAB_POOL`, Query warehouse = `GN_DW_ANALYTICS_WH`
4. **Run** 실행 → 정상 기동 확인
5. `GOLD` 테이블 조회 쿼리가 앱 내부에서 동작하는지 확인 (FUTURE GRANT SELECT 유효성)
6. 실패 시 오류 메시지의 누락 권한을 기록하고 §3.1 범위 내에서 최소 추가 부여

```sql
-- 배포 결과 확인
SHOW STREAMLITS IN SCHEMA GN_DW.LAB;
```

---

## 6. 롤백

```sql
USE ROLE GN_DW_ADMIN;
REVOKE CREATE STREAMLIT ON SCHEMA GN_DW.LAB FROM ROLE GN_DW_ANALYST;
-- ⚠️ REVOKE는 이미 생성된 Streamlit 객체를 삭제하지 않는다. 먼저 인벤토리 확인:
--   SHOW STREAMLITS IN SCHEMA GN_DW.LAB;
-- 필요 시 소유권 이전:
--   GRANT OWNERSHIP ON STREAMLIT GN_DW.LAB.<APP> TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;

REVOKE USAGE ON SCHEMA GN_DW.LAB FROM ROLE GN_DW_ANALYST;
REVOKE USAGE ON SCHEMA GN_DW.LAB FROM ROLE GN_DW_VIEWER;
-- 스키마 삭제는 객체 확인 후에만
-- DROP SCHEMA GN_DW.LAB;

USE ROLE ACCOUNTADMIN;
REVOKE USAGE, MONITOR ON COMPUTE POOL GN_DW_LAB_POOL FROM ROLE GN_DW_ANALYST;
-- DROP COMPUTE POOL GN_DW_LAB_POOL;

USE ROLE SECURITYADMIN;
ALTER ROLE GN_DW_ANALYST SET COMMENT = '분석 쿼리(SELECT)·SV/Agent 소비';
ALTER ROLE GN_DW_VIEWER  SET COMMENT = '읽기 전용·SV/Agent/Streamlit 소비';
```

---

## 7. 운영 정책

### 7.1 LAB → SERVING 승격 기준

`GN_DW_ADMIN`이 다음을 확인한 뒤 `SERVING`에 재배포한다.

- [ ] 코드 리뷰 완료 (버전 관리 저장소에 소스 존재)
- [ ] 참조 객체가 `GOLD` 또는 `SERVING`의 Semantic View — `SILVER`/`BRONZE_*` 직접 참조 금지
- [ ] 하드코딩 자격증명·`env_var()` 인증 없음
- [ ] 동적 SQL이 바인드 파라미터 사용 (SQL 인젝션 점검)
- [ ] 소유 조직·담당자 지정
- [ ] 예상 사용자 수 대비 웨어하우스·풀 사이징 검토

승격 후 원본 LAB 앱은 삭제하거나 "deprecated" 주석을 남긴다.

### 7.2 LAB 수명주기

- LAB 앱은 **미인증**이며 SLA 대상이 아니다. 앱 내부에 해당 문구 표기를 권장한다.
- 90일 이상 미실행 앱은 소유자 확인 후 정리한다.

```sql
-- 미사용 LAB 앱 탐지 (ACCOUNT_USAGE는 최대 3시간 지연)
SELECT s.streamlit_name, s.streamlit_owner, s.created,
       MAX(q.start_time) AS last_query
FROM SNOWFLAKE.ACCOUNT_USAGE.STREAMLITS s
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY q
  ON q.role_name = s.streamlit_owner
WHERE s.streamlit_schema = 'LAB'
  AND s.streamlit_catalog = 'GN_DW'
  AND s.deleted IS NULL
GROUP BY 1,2,3
HAVING last_query < DATEADD(day, -90, CURRENT_TIMESTAMP()) OR last_query IS NULL;
```

### 7.3 비용 귀속

전용 풀(`GN_DW_LAB_POOL`)로 분리했으므로 다음으로 추적한다.

```sql
SELECT DATE_TRUNC('day', start_time) AS d, SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPARK_CONTAINER_SERVICES_HISTORY
WHERE compute_pool_name = 'GN_DW_LAB_POOL'
GROUP BY 1 ORDER BY 1 DESC;
```

- 예산 초과 감시를 위해 리소스 모니터 또는 Budget 연결을 권장한다.
- §4.1의 `SYSTEM_COMPUTE_POOL_*` → `PUBLIC` 경로가 남아 있으면 우회 사용이 가능하므로,
  전용 풀 사용을 정책으로 강제하고 주기적으로 실제 사용 풀을 점검한다.

---

## 8. 미해결 / 후속

| 항목 | 내용 |
|---|---|
| 마스킹 정책 부재 | `GN_DW.SECURITY`에 정책 0건. §2.2-5의 이점은 정책 구현 후 실현된다 |
| `SERVING` 미착수 | Streamlit 0건. P7 단계 자체가 미구현. LAB 도입이 P7을 대체하지 않는다 |
| 선별 부여 불가 | ANALYST 전원 부여. 필요 시 `GN_DW_APP_DEV` 분리 (되돌리기 작업) |
| 기본 컴퓨트 풀 우회 | `SYSTEM_COMPUTE_POOL_*` USAGE→`PUBLIC` 경로 잔존 |
| Personal DB | 기본 개방. §4.2에서 유지/비활성 결정 필요 |
| 배포 최소 권한 미확정 | `CREATE STREAMLIT` 외 추가 권한 필요 여부는 §5 Step 5 실배포로 확정 |

---

## 부록 A. Trial 실측 근거

```
-- 역할 상속
SHOW GRANTS OF ROLE GN_DW_VIEWER;
  GN_DW_VIEWER → ROLE GN_DW_ANALYST (granted_by SECURITYADMIN)

-- ANALYST 보유 권한 (CREATE 계열 없음)
SHOW GRANTS TO ROLE GN_DW_ANALYST;
  USAGE DATABASE  GN_DW
  USAGE ROLE      GN_DW_VIEWER
  USAGE SCHEMA    GN_DW.GOLD
  USAGE SCHEMA    GN_DW.SILVER
  USAGE WAREHOUSE GN_DW_ANALYTICS_WH

-- GOLD SELECT 경로 = FUTURE GRANT
SHOW FUTURE GRANTS IN SCHEMA GN_DW.GOLD;
  SELECT TABLE GN_DW.GOLD.<TABLE> → GN_DW_ANALYST
  SELECT VIEW  GN_DW.GOLD.<VIEW>  → GN_DW_ANALYST
  SELECT TABLE GN_DW.GOLD.<TABLE> → GN_DW_VIEWER
  SELECT VIEW  GN_DW.GOLD.<VIEW>  → GN_DW_VIEWER

-- SERVING = ADMIN 단독 소유, 타 역할 grant 0건
SHOW GRANTS ON SCHEMA GN_DW.SERVING;
  OWNERSHIP SCHEMA GN_DW.SERVING → GN_DW_ADMIN (grant_option=true)

-- Streamlit 인벤토리
SHOW STREAMLITS IN DATABASE GN_DW;   -- 0건

-- 컴퓨트 풀 기본 개방
SHOW GRANTS ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU;
  OWNERSHIP → ACCOUNTADMIN
  USAGE     → PUBLIC          ← 모든 역할 상속

-- Personal DB (역할 우회)
SHOW GRANTS ON DATABASE USER$TRIALADMIN;
  CREATE SCHEMA → USER TRIALADMIN
  USAGE         → USER TRIALADMIN (grant_option=true)

-- Personal DB 기본 활성
SHOW PARAMETERS LIKE '%PERSONAL_DATABASE%' IN ACCOUNT;
  ENABLE_PERSONAL_DATABASE = true (default true)

-- 마스킹 정책 부재
SHOW MASKING POLICIES IN SCHEMA GN_DW.SECURITY;   -- 0건
```

## 부록 B. 웨어하우스 참조

| 웨어하우스 | 크기 | 주석 |
|---|---|---|
| `GN_DW_ETL_WH` | Small | ETL / 데이터 적재 (프로시저·태스크 전용) |
| `GN_DW_DEV_WH` | X-Small | 개발/테스트 (Engineer·Admin 기본) |
| `GN_DW_ANALYTICS_WH` | Medium | 분석가 쿼리 / SV·Agent 소비 (Analyst·Viewer·Service) |

LAB 앱은 `GN_DW_ANALYTICS_WH`를 사용한다. 별도 분리가 필요하면 `GN_DW_LAB_WH` 신설을 검토한다.
