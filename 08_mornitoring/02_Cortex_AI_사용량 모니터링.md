# 02. Cortex AI 사용량 모니터링

CoWork/Intelligence, Cortex Code(CoCo), Cortex Analyst, Cortex Agent, LLM 함수 등의
사용량을 조회하는 뷰와 쿼리를 정리한다.

> 모든 쿼리는 `SNOWFLAKE` 데이터베이스의 공유 뷰를 사용하며,
> 접근하려면 `ACCOUNTADMIN` 또는 `SNOWFLAKE.OBJECT_VIEWER` / `GOVERNANCE_VIEWER` 등
> 적절한 데이터베이스 역할이 필요하다.

## 1. AI 크레딧이 집계되는 service_type

`METERING_HISTORY` / `METERING_DAILY_HISTORY`에서 AI 관련 크레딧은 아래 5개 `service_type`로 집계된다.

| service_type | 포함 기능 | 과금 |
|--------------|-----------|------|
| `AI_SERVICES` | LLM 함수(COMPLETE, EXTRACT 등), **Cortex Analyst**, Cortex Search, Document AI, Fine-tuning | 크레딧 |
| `CORTEX_AGENTS` | Cortex Agents API / Orchestrator | 크레딧 |
| `CORTEX_CODE_CLI` | Snowflake CLI 기반 Cortex Code | 크레딧 |
| `CORTEX_CODE_SNOWSIGHT` | Snowsight UI 내 Cortex Code (CoCo) | 크레딧 |
| `SNOWFLAKE_INTELLIGENCE` | Snowflake Intelligence (CoWork) | 크레딧 |

> 참고: `AI_INFERENCE` (Cortex REST API 추론)는 **크레딧이 아니라 달러로 직접 과금**되며
> `METERING_*` 뷰에 나타나지 않고 청구서(billing statement)에만 표시된다.

## 2. 조직 단위 총 AI 지출 (요약)

```sql
-- 조직 전체 AI 크레딧 (Enterprise+ / 조직 계정에서만 사용 가능)
SELECT
    service_type,
    SUM(credits_used) AS total_credits
FROM SNOWFLAKE.ORGANIZATION_USAGE.METERING_DAILY_HISTORY
WHERE service_type IN (
    'AI_SERVICES',
    'CORTEX_AGENTS',
    'CORTEX_CODE_CLI',
    'CORTEX_CODE_SNOWSIGHT',
    'SNOWFLAKE_INTELLIGENCE'
)
  AND usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY service_type
ORDER BY total_credits DESC;
```

## 3. 계정 단위 총 AI 지출

```sql
-- 계정 단위 AI 크레딧 (모든 Edition에서 사용 가능)
SELECT
    service_type,
    SUM(credits_used) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type IN (
    'AI_SERVICES',
    'CORTEX_AGENTS',
    'CORTEX_CODE_CLI',
    'CORTEX_CODE_SNOWSIGHT',
    'SNOWFLAKE_INTELLIGENCE'
)
  AND usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY service_type
ORDER BY total_credits DESC;
```

## 4. 기능별 상세(누가·무엇을) 조회 뷰

기능별로 **하나의 정본(canonical) 뷰**를 선택해 분석하고, 여러 뷰의 크레딧을 합산하지 않는다.
(뷰 간 데이터가 중복될 수 있어 합산하면 과대 집계된다.)

| 기능 | 정본 뷰 (`SNOWFLAKE.ACCOUNT_USAGE.`) | 사용자 컬럼 |
|------|--------------------------------------|-------------|
| LLM 함수(AISQL) | `CORTEX_AISQL_USAGE_HISTORY` | 있음 (user) |
| Cortex Analyst | `CORTEX_ANALYST_USAGE_HISTORY` | 있음 (username) |
| Cortex Agents | `CORTEX_AGENT_USAGE_HISTORY` | agent/schema 메타데이터 |
| Snowflake Intelligence | `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` | 토큰/크레딧 롤업 |
| Cortex Search | `CORTEX_SEARCH_SERVING_USAGE_HISTORY` | - |
| Document 처리 | `CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY` | - |
| Fine-tuning | `CORTEX_FINE_TUNING_USAGE_HISTORY` | - |
| Cortex Code (CLI) | `CORTEX_CODE_CLI_USAGE_HISTORY` | 있음 |
| Cortex Code (Snowsight) | `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` | 있음 |

> 주의: 위 뷰들은 최대 3시간(때로 그 이상) 지연이 있으며, 당일 데이터는 나중에 채워질 수 있다.
> 또한 이 뷰들은 근본 metering 이벤트의 **부분집합**이므로, 합산값이 `METERING_HISTORY`의
> `AI_SERVICES` 총합과 **정확히 일치하지 않는 것이 정상**이다.

### 사용자별 LLM 함수 사용량 예시

```sql
-- 최근 30일 LLM 함수 사용자별 토큰 크레딧
SELECT
    user_name,
    model_name,
    SUM(token_credits) AS token_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY user_name, model_name
ORDER BY token_credits DESC;
```

> 컬럼명은 뷰 버전에 따라 다를 수 있으므로 실행 전
> `DESCRIBE VIEW SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY;`로 확인할 것.

### Cortex Analyst 사용자별 요청 수

```sql
SELECT
    username,
    SUM(credits) AS credits,
    COUNT(*)     AS request_cnt
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY username
ORDER BY credits DESC;
```

## 5. 정본 뷰 선택 시 주의 (중복 합산 금지)

- LLM 함수: `CORTEX_FUNCTIONS_USAGE_HISTORY`(레거시), `CORTEX_AI_FUNCTIONS_USAGE_HISTORY`(중간),
  `CORTEX_AISQL_USAGE_HISTORY`(현재 정본) — **세 뷰를 합산하지 말 것.** 현재 분석은 `CORTEX_AISQL_USAGE_HISTORY`만 사용.
- Document 처리: `CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY`가 상위 집합. 레거시 `DOCUMENT_AI_USAGE_HISTORY`와 합산 금지.
