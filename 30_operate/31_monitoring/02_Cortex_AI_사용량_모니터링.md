# 02. Cortex AI 사용량 모니터링

CoWork, CoCo(Cortex Code), Cortex Analyst, Cortex Agent, AI 함수 등의
사용량을 조회하는 뷰와 쿼리를 정리한다.

> 모든 쿼리는 `SNOWFLAKE` 데이터베이스의 공유 뷰를 사용하며,
> 접근하려면 `ACCOUNTADMIN` 또는 `SNOWFLAKE.OBJECT_VIEWER` / `GOVERNANCE_VIEWER` 등
> 적절한 데이터베이스 역할이 필요하다.

> **개정 2026-08-12**: 계정 실측으로 `service_type` 값, 뷰 목록, 컬럼명을 교체했다.
> 이전 판의 사용자별 LLM 함수 예시 쿼리는 **실행 시 실패하는 상태**였다(§6 정정표).

---

## 1. AI 크레딧이 집계되는 service_type

### 실측 확인값 (본 계정, 2026-08-12)

`SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY` 전량 조회 결과 존재하는 값:

| service_type | 의미 | 본 계정 실측 |
|--------------|------|--------------|
| `SNOWFLAKE_COCO_SNOWSIGHT` | Snowsight UI의 CoCo | ⭕ 실측 확인 |
| `WAREHOUSE_METERING` | 웨어하우스 컴퓨트 | ⭕ |
| `TELEMETRY_DATA_INGEST` | 텔레메트리 수집 | ⭕ |
| `PIPE` | Snowpipe | ⭕ |

> 🔴 **정정**: 이전 판이 기재한 `CORTEX_CODE_SNOWSIGHT` / `CORTEX_CODE_CLI`는
> **metering의 `service_type` 값이 아니다.** 실제 값은 `SNOWFLAKE_COCO_*` 계열이다.
> `CORTEX_CODE_*`는 `ACCOUNT_USAGE`의 **뷰 이름**으로만 존재한다(§3). 둘을 혼동한 오류였다.

### 미실측 (본 계정에 사용 이력 없음)

아래 값은 해당 기능을 쓰지 않아 실측되지 않았다. **사용 전 실제 값을 재확인할 것.**
`SNOWFLAKE_COCO_SNOWSIGHT`가 `CORTEX_CODE_SNOWSIGHT`가 아니었던 것처럼,
기능명과 `service_type`이 일치하지 않는 사례가 이미 확인되었다.

- AI 함수 / Cortex Analyst / Cortex Search / Document AI / Fine-tuning 계열
- Cortex Agents 계열
- CoWork(Snowflake Intelligence) 계열
- CoCo CLI · Desktop 계열

확인 방법:

```sql
-- 실제 존재하는 service_type 만 나온다. 추정 목록을 IN 절에 하드코딩하지 말 것.
SELECT DISTINCT service_type
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
ORDER BY 1;
```

> 참고: Cortex REST API 추론(`AI_INFERENCE`)은 크레딧이 아니라 달러로 직접 과금되며
> `METERING_*` 뷰에 나타나지 않고 청구서에만 표시된다.
> 토큰·크레딧 추적은 `CORTEX_REST_API_USAGE_HISTORY`를 쓴다.

---

## 2. 계정 단위 총 AI 지출

```sql
-- 하드코딩 없이 전체를 본다. AI 계열만 보려면 결과에서 선별한다.
SELECT service_type,
       ROUND(SUM(credits_used), 4) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1
ORDER BY credits DESC;
```

조직 단위는 동일 쿼리에서 `ORGANIZATION_USAGE`로 바꾼다(Enterprise+ / 조직 계정 한정, 최대 24시간 지연).

---

## 3. 기능별 상세(누가·무엇을) 조회 뷰

기능별로 **하나의 정본(canonical) 뷰**만 사용하고, 여러 뷰의 크레딧을 합산하지 않는다.

### 실존 뷰 목록 (2026-08-12 `INFORMATION_SCHEMA.VIEWS` 실측 34개 중 AI 관련)

| 기능 | 정본 뷰 (`SNOWFLAKE.ACCOUNT_USAGE.`) | 사용자 컬럼 | 크레딧 컬럼 |
|------|--------------------------------------|-------------|-------------|
| **CoCo (전 인터페이스)** | `SNOWFLAKE_COCO_USAGE_HISTORY` | `USER_NAME` | `TOKEN_CREDITS` |
| CoWork | `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` | `USER_NAME` | `TOKEN_CREDITS` |
| Cortex Agents | `CORTEX_AGENT_USAGE_HISTORY` | `USER_NAME` | `TOKEN_CREDITS` |
| AI 함수(AISQL) | `CORTEX_AISQL_USAGE_HISTORY` | 🔴 **`USER_ID` 만** | `TOKEN_CREDITS` |
| Cortex Analyst | `CORTEX_ANALYST_USAGE_HISTORY` | 🔴 **`USERNAME`** | 🔴 **`CREDITS`** |
| Cortex Search | `CORTEX_SEARCH_SERVING_USAGE_HISTORY` | - | - |
| Document 처리 | `CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY` | - | - |
| Fine-tuning | `CORTEX_FINE_TUNING_USAGE_HISTORY` | - | - |
| REST API | `CORTEX_REST_API_USAGE_HISTORY` | - | - |
| 가드레일 | `CORTEX_AI_GUARDRAILS_USAGE_HISTORY` | - | - |

### 🔴 중복 합산 함정 — CoCo

`CORTEX_CODE_CLI_USAGE_HISTORY` · `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` ·
`CORTEX_CODE_DESKTOP_USAGE_HISTORY`는 **`SNOWFLAKE_COCO_USAGE_HISTORY`의 인터페이스별 부분집합**이다.

2026-08-12 실측 대조:

| 뷰 | 행수 | 크레딧 |
|----|------|--------|
| `SNOWFLAKE_COCO_USAGE_HISTORY` | 34 | 4.4743 |
| `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` | 34 | 4.4743 |
| `CORTEX_CODE_CLI_USAGE_HISTORY` | 0 | NULL |
| `CORTEX_CODE_DESKTOP_USAGE_HISTORY` | 0 | NULL |

통합뷰와 인터페이스별 뷰의 값이 **완전히 일치**한다(Snowsight만 사용한 계정이므로).
⇒ **함께 더하면 정확히 2배로 과대집계된다.** 통합뷰(`SNOWFLAKE_COCO_USAGE_HISTORY`)만 쓰고,
인터페이스 구분이 필요하면 그 안의 `INTERFACE` 컬럼(`snowsight` 등)으로 분해한다.

### 그 외 중복 주의

- AI 함수: `CORTEX_FUNCTIONS_USAGE_HISTORY`(레거시) · `CORTEX_AI_FUNCTIONS_USAGE_HISTORY`(중간) ·
  `CORTEX_AISQL_USAGE_HISTORY`(현재 정본) — **세 뷰를 합산하지 말 것.**
- Document 처리: `CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY`가 상위 집합.
- 기능별 뷰는 근본 metering 이벤트의 **부분집합**이므로 `METERING_HISTORY` 총합과
  정확히 일치하지 않는 것이 정상이다.

> 뷰는 최대 3시간(때로 그 이상) 지연이 있고 당일 데이터는 나중에 채워진다.

---

## 4. 사용자별 사용량 쿼리

### CoCo — 사용자·인터페이스별

```sql
SELECT user_name,
       interface,
       ROUND(SUM(token_credits), 4) AS credits,
       SUM(tokens)                  AS tokens,
       COUNT(*)                     AS requests
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1, 2
ORDER BY credits DESC;
```

`SNOWFLAKE_COCO_USAGE_HISTORY` 컬럼: `USER_ID` · `USER_NAME` · `USER_TAGS` · `REQUEST_ID` ·
`PARENT_REQUEST_ID` · `USAGE_TIME` · `INTERFACE` · `TOKEN_CREDITS` · `TOKENS` ·
`TOKENS_GRANULAR` · `CREDITS_GRANULAR` · `METADATA`.

> 🔴 크레딧 컬럼은 `CREDITS`가 아니라 **`TOKEN_CREDITS`** 다. `CREDITS`로 쓰면
> `invalid identifier 'CREDITS'`로 실패한다(실측).

### AI 함수 — USER_ID를 이름으로 해석

```sql
-- 🔴 CORTEX_AISQL_USAGE_HISTORY 에는 USER_NAME 이 없다. USERS 조인이 필수다.
SELECT u.name AS user_name,
       q.model_name,
       q.function_name,
       ROUND(SUM(q.token_credits), 4) AS token_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY q
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON u.user_id = q.user_id
WHERE q.usage_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1, 2, 3
ORDER BY token_credits DESC;
```

### Cortex Analyst — 컬럼명이 다르다

```sql
SELECT username,                       -- USER_NAME 아님
       ROUND(SUM(credits), 4) AS credits,   -- TOKEN_CREDITS 아님
       SUM(request_count)     AS requests
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1
ORDER BY credits DESC;
```

---

## 5. 통합 관찰 뷰 (구축됨)

도메인별 컬럼명 차이를 흡수한 뷰를 `GN_DW.OPS`에 만들어 두었다.

```sql
SELECT domain, user_name, usage_date,
       ROUND(SUM(credits), 4) AS credits,
       COUNT(*)               AS events
FROM GN_DW.OPS.V_AI_SPEND_BY_USER
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1, 2, 3
ORDER BY credits DESC;
```

각 도메인의 **정본 뷰만** 포함하므로 도메인 간 합산이 안전하다.
정의는 `05_AI비용가드_구축.sql` §8 참조.

quota 자체 집계로 교차검증할 수도 있다.

```sql
CALL GN_DW.OPS.AI_USER_QUOTA!GET_SPENDING_DETAILS_BY_USERS(
       DATEADD('day', -30, CURRENT_DATE()), CURRENT_DATE());
```

---

## 6. 이전 판에서 정정된 오류

| 오류 (이전 판) | 정정 (실측) |
|----------------|-------------|
| `service_type` = `CORTEX_CODE_SNOWSIGHT` / `CORTEX_CODE_CLI` | **`SNOWFLAKE_COCO_SNOWSIGHT`**. `CORTEX_CODE_*`는 뷰 이름일 뿐 service_type이 아니다 |
| "AI 관련은 5개 service_type" 확정 기술 | 본 계정 실측으로는 CoCo 1종만 확인. 나머지는 **미실측**이므로 단정 불가 |
| `CORTEX_AISQL_USAGE_HISTORY` 사용자 컬럼 "있음(user)" | **`USER_NAME` 없음.** `USER_ID`만 존재 → `USERS` 조인 필요 |
| 예시 쿼리에서 `CORTEX_AISQL_USAGE_HISTORY`의 `user_name` 사용 | **실행 실패하는 쿼리였다.** §4로 교체 |
| CoCo 정본 뷰를 CLI/Snowsight 2개로 분리 기재 | 통합 정본 **`SNOWFLAKE_COCO_USAGE_HISTORY`** 신설. 인터페이스별 뷰는 부분집합(합산 금지) |
| Desktop 인터페이스 누락 | `CORTEX_CODE_DESKTOP_USAGE_HISTORY` 존재. 통합뷰의 `INTERFACE`로 구분 |
| `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` "토큰/크레딧 롤업" | `USER_NAME` 보유 — 사용자별 귀속 가능 |
| REST API 추적 수단 미기재 | `CORTEX_REST_API_USAGE_HISTORY` |

_Co-authored with CoCo_
