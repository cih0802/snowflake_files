---
project_id: GN_DW
doc_type: dbt_pipeline_state
pipeline: gn_dw_silver (BRONZE→SILVER 32객체)
dbt_object: GN_DW.SILVER.GN_DW_SILVER_PIPELINE
active_version: VERSION$2 (default)
as_of: 2026-07-14
author: Co-authored with CoCo
---

# SILVER dbt 파이프라인 현행 상태 기록 (STATE)

> 순서 7 완료 시점의 배포·검증·운영계약 스냅샷. 다음 세션(순서 8 GOLD) 착수 전 핸드오프용.

---

## 1. 배포 상태

| 항목 | 값 |
|---|---|
| DBT PROJECT 객체 | `GN_DW.SILVER.GN_DW_SILVER_PIPELINE` |
| 활성 버전 | **VERSION$2** (is_default=true, is_last=true) |
| 이전 버전 | VERSION$1 (GA4 매크로 버그 버전, 비활성) |
| dbt / adapter | dbt 1.9.4 / snowflake 1.9.2 |
| external_access_integrations | None (프라이빗 망 적합, EAI 불요) |
| 모델/테스트/소스 | 32 models, 9 data tests, 40 sources, 482 macros |
| 워크스페이스 소스 | `snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline` |

## 2. 검증 결과 (2026-07-14)

| 단계 | 결과 |
|---|---|
| parse | 성공 |
| compile | 32 models 정상 |
| run (전체) | PASS=32 (37.67s) — CRM/ERP/AGENCY 26객체 멱등정상(Δ0), GA4 6객체 회귀 발생 |
| GA4 회귀수정 → run(silver.ga4+) | PASS=6 (7.47s) — 6객체 전량 회복 |
| **test** | **PASS=9 WARN=0 ERROR=0** |
| 최종 | **32객체 전량 BEFORE=AFTER Δ0, 멱등 확정** |

상세 행수 비교: `04_silver_design/10_SILVER_RUN_이력_비교_20260714.md`

## 3. 해결한 이슈 — GA4 매크로 대소문자 (조용한 회귀)

- **증상:** run 은 SUCCESS인데 GA4 5모델 + IDENTITY_MEMBER_XREF 가 0행.
- **원인:** BRONZE_GA4 샤드가 소문자 인용식별자(테이블 `"events_20260501"`, 컬럼 `"event_date"` 등). 매크로 `ga4_union_shards`가 대소문자 구분 필터/참조 → 샤드 0개 판단 + `invalid identifier`.
- **수정 (`macros/ga4_union_shards.sql`):**
  1. 샤드 탐색: `UPPER(table_name) LIKE 'EVENTS\_%' ESCAPE '\'` + `REPLACE(UPPER(table_name),'EVENTS_','')`
  2. FROM절: `BRONZE_GA4."{{ t }}"` (테이블명 인용)
  3. SELECT 14컬럼: `"event_date" AS event_date` 식으로 인용+대문자 alias
- **영구성:** 향후 `events_YYYYMMDD` 샤드가 동일 GA4 커넥터로 계속 적재돼도 자동 처리.

## 4. 현행 운영 계약 (★중요)

- **BRONZE 갱신 특성:** 정기 갱신이나 **주기 불규칙**.
- **결정:** 고정 CRON TASK 는 안티패턴 → **온디맨드 `build` 계약** 채택.
  ```sql
  EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='build';
  ```
- `build` = run + test 통합 → 조용한 회귀를 test 실패로 게이트. (run 단독은 0행도 SUCCESS라 위험.)
- BRONZE 적재 주체(커넥터/배치)가 적재 완료 후 위 호출을 실행하도록 배선 예정.
- 오케스트레이션 정본: `10_dbt_pipeline/99_DEPLOY_ORCHESTRATION.sql` (§C 현행 / §D CRON보류 / §E 트리거목표형).

## 5. 보류·미결 (다음 세션 이후)

| 항목 | 상태 | 비고 |
|---|---|---|
| CRON TASK 가동 | ⏸️ 보류 | 주기 불규칙 → 부적합. 정시 확정 시에만 |
| 트리거 기반 TASK (STREAM+WHEN) | 🔜 최종목표 | BRONZE 적재 메커니즘 확정 후 §E 구현 |
| **GOLD 파이프라인 (순서 8)** | 🔜 **다음 세션** | 현재 `enabled:false`. DIM/FACT 저작 대상 |
| ERP_BIZ_TARGET 0행 | ℹ️ 확인 | 원천 미입고. 의도 여부 확인 권장 |

## 6. 다음 세션 = GOLD (순서 8)

- 대상: `models/gold/` — DIM 13 + FACT 6 (현재 `+enabled: false`).
- 진입 프롬프트: `10_dbt_pipeline/_NEXT_GOLD_SESSION_PROMPT.md` 참조.
