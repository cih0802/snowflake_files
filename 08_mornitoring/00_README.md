# 08_모니터링

Snowflake 운영 모니터링 및 AI(CoCo·CoWork·Agent·AI 함수) 사용량·비용 통제 문서 모음입니다.

> **검토 원칙**: 본 문서는 Snowflake 공식 문서 + **본 계정 실측**을 근거로 작성되었습니다.
> 2026-08-12 개정에서 Per-user quota의 실제 API를 계정에서 조회해 전면 교체했습니다.
> 이전 판은 메서드명을 추정으로 기재해 존재하지 않는 구문을 담고 있었습니다.

## 문서 목록

| 문서 | 내용 |
|------|------|
| `01_모니터링_대상 개요.md` | 모니터링 대상·수단, Resource Monitor vs Budget vs quota 비교 |
| `02_Cortex_AI_사용량 모니터링.md` | 사용량 조회 뷰·컬럼·쿼리, 중복 합산 함정 |
| `03_비용제한_예산 쿼터.md` | Per-user quota / Budget / RBAC 3계층 통제 |
| `04_알림_및 거버넌스.md` | quota 내장 알림, Alert, 거버넌스 체크리스트 |
| **`05_AI비용가드_구축.sql`** | **실행 가능한 구축 런북 (정본)** |

## 핵심 요약

- **Resource Monitor는 웨어하우스 전용**이며 서버리스·AI 서비스에는 적용되지 않는다.
- AI 비용의 **사용자 기반 하드 차단은 Per-user quota의 내장 Block**이 유일한 무코드 수단이다.
  - `SNOWFLAKE.CORE.QUOTA` 인스턴스 · **Preview-Open**(전 계정 사용 가능)
  - 대상 도메인: `AI FUNCTION` · `CORTEX CODE` · `SNOWFLAKE INTELLIGENCE` · `CORTEX AGENT`
  - **웨어하우스는 추적만 되고 차단되지 않는다.**
- **Budget 단독은 알림 전용**이다. 차단은 custom action + 저장 프로시저 자작이 필요하다.
- **RBAC**(`SNOWFLAKE.CORTEX_USER` 통제)는 접근 자체를 막는 최후 방어선이다.

## 본 계정 구축 현황 (2026-08-12)

| 오브젝트 | 위치 | 상태 |
|----------|------|------|
| `AI_USER_QUOTA` | `GN_DW.OPS` | 생성 · 4개 AI 도메인 감시 |
| `AI_COST_SCOPE` (TAG) | `GN_DW.SECURITY` | 생성 · quota 스코프로 연결 |
| `V_AI_SPEND_BY_USER` | `GN_DW.OPS` | 생성 · 관찰 가능 |

**설정값**: 월 한도 `NULL` · 일 한도 `NULL` · 차단 `FALSE` · `GET_USERS()` 0행
⇒ **현재는 순수 관찰 상태이며 어떤 사용자도 차단되지 않는다.**

**오브젝트 배치 원칙** (GN_DW 계층 설계 준수)
- `OPS` = 운영/비용 객체 (quota, 관찰 뷰) — 기존 `GN_DW.OPS.DW_PIPELINE`(dbt)과 동일 계층
- `SECURITY` = 거버넌스 정책 객체 (적용대상 판별 TAG)

**차단 전환 절차**: `05` §5 한도 설정 → §1 태그 부여 → §9-3 대상 확인 → §6 차단 활성화

## 실측으로 정정된 주요 오류

| 오류 | 정정 | 문서 |
|------|------|------|
| `SET_SPENDING_LIMIT` / `SET_DAILY_SPENDING_LIMIT` | **`SET_PER_USER_LIMIT(n)` / `(n, 'DAILY')`** | 03 §5 |
| `SET_BLOCK_ENFORCEMENT(TRUE)` | **`SET_BLOCK_ENFORCEMENT_ENABLED(TRUE)`** | 03 §5 |
| `service_type = 'CORTEX_CODE_SNOWSIGHT'` | **`SNOWFLAKE_COCO_SNOWSIGHT`**. `CORTEX_CODE_*`는 뷰 이름일 뿐 | 02 §1 |
| `CORTEX_AISQL_USAGE_HISTORY`에 `user_name` 사용 | **해당 컬럼 없음.** `USER_ID` → `USERS` 조인 필요 | 02 §4 |
| CoCo 뷰를 CLI/Snowsight로 분리 집계 | 통합 정본 `SNOWFLAKE_COCO_USAGE_HISTORY` 신설. **인터페이스별 뷰와 합산하면 2배 과대집계**(실측 확인) | 02 §3 |
| Budget으로 Cortex "하드 차단 불가" | custom action으로 역할 회수 차단 가능 | 03 §2 |
| Per-user quota "사용 가능 여부 확인 필요" | Preview-**Open**, 전 계정 사용 가능 | 03 §1 |
| `ALTER USER ... SET RESOURCE_MONITOR_CREDIT_QUOTA` | 존재하지 않는 구문 (이전 판에서 이미 정정, 유지) | 03 §5 |

## 실측된 Preview 결함

- 🔴 `EXCLUDE_USERS('USER', [...])`가 `INVALID_TARGET_TYPE`으로 실패한다.
  오류 메시지가 허용값으로 `'USER'`를 안내하면서 정작 `'USER'`를 거부한다(대소문자 무관).
  ⇒ **태그 기반 스코프(`SET_USER_TAGS`)로 우회**했다. 상세는 03 §1-4.
- `CREATE SNOWFLAKE.CORE.QUOTA`는 구문검증(compile-only)을 지원하지 않는다. 실제 생성만 가능.

_Co-authored with CoCo_
