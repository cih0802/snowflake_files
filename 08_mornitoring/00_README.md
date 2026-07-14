# 08_모니터링

Snowflake 운영 모니터링 및 Cortex AI(LLM) 사용량·비용 통제에 대한 이론 문서 모음입니다.

> **검토 원칙**: 본 문서는 Snowflake 공식 문서를 기준으로 사실 확인 후 작성되었습니다.
> 일부 기능은 계정 Edition, 리전, Preview 여부에 따라 사용 불가할 수 있으므로,
> 실제 적용 전 반드시 `SHOW`/`DESCRIBE` 또는 공식 문서로 재확인하시기 바랍니다.

## 문서 목록

| 문서 | 내용 |
|------|------|
| `01_모니터링_대상_개요.md` | Snowflake에서 모니터링 가능한 대상과 수단 정리 |
| `02_Cortex_AI_사용량_모니터링.md` | Cortex AI(CoWork/Intelligence, CoCo 등) 사용량 조회 뷰와 쿼리 |
| `03_비용제한_예산_쿼터.md` | Budget, Per-user quota, RBAC를 통한 비용 통제 |
| `04_알림_및_거버넌스.md` | Alert 기반 알림, 접근 제어, 운영 권장 전략 |

## 핵심 요약

- **Resource Monitor는 웨어하우스(가상 컴퓨팅) 전용**이며, Cortex AI 같은 **서버리스 기능에는 적용되지 않는다.**
- Cortex AI 비용 통제는 다음 3가지를 조합한다.
  1. **가시성** — `ACCOUNT_USAGE` / `ORGANIZATION_USAGE`의 metering 및 `CORTEX_*_USAGE_HISTORY` 뷰
  2. **소프트 제어(알림)** — Budget (한도 도달 시 알림, *하드 차단 아님*)
  3. **하드 제어** — Per-user quota(사용자별 크레딧 상한, 초과 시 차단 / **Preview**) + RBAC(접근 자체 제한)

## 주의: 이전 구두 설명에서 정정된 오류

| 오류 | 정정 |
|------|------|
| `ALTER USER ... SET RESOURCE_MONITOR_CREDIT_QUOTA` | **존재하지 않는 구문.** 사용자별 상한은 Per-user quota 객체 사용 |
| `service_type = 'CORTEX_CODE'` | 실제 값은 `CORTEX_CODE_CLI`, `CORTEX_CODE_SNOWSIGHT` (분리됨) |
| `QUERY_ATTRIBUTION_HISTORY`에 `service_type`으로 Cortex 필터 | 해당 컬럼 없음. 사용자별 귀속은 `CORTEX_*_USAGE_HISTORY` 뷰 사용 |
| Budget으로 Cortex를 "하드 차단" | Budget은 **알림 전용**. 차단은 Per-user quota 또는 RBAC |
