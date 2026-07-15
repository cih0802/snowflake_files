---
project_id: GN_DW
doc_type: open_items_tracker
created: 2026-07-15
author: Co-authored with CoCo
priority: HIGH — 후속 세션 착수 시 이 문서 먼저 확인
---

# ⛔ [GN_DW 미결 후속조치 추적 — 누락 금지] ⛔

> **후속 세션은 이 문서를 반드시 먼저 읽고 시작할 것.** 순서 9-B 검토(항목 1~7)에서 발견·보류된 모든 미결 항목을 한곳에 모았다. 완료 시 해당 항목에 `[DONE]` 표기하고 `DEPLOY_RUNBOOK.md` 로 이관한다.

---

## 🔴 BLOCKING-1 — SILVER/GOLD `severity: warn` 되돌리기 (회원 마스터 전량입고 후)
회원 마스터(`CRM_MEMBER`) 스냅샷 미완전으로 발생한 고아 때문에, 회원→마스터 참조무결성 테스트를 **임시로 `severity: warn`** 강등했다. **마스터가 전량 입고되면 아래를 전부 `error` 로 복귀**시켜야 한다(무결성 게이트 복원).

| 파일 | 대상 테스트 | 현재 |
|---|---|---|
| `models/gold/_gold_ready_schema.yml` | FMM·FEP·FME·FSE 의 `MEMBER_DK → DIM_MEMBER` (4건) | warn |
| `models/silver/crm/_crm_schema.yml` | `MBER_NO/MEMBER_DK → CRM_MEMBER` (10건: EVENT_PARTICIPATION·MEMBER_DEV·DISCONTINUE·AMT_CHANGE·RESPONSOR·STATUS_HIST·PAYMENT_BILLING·PAYMENT_METHOD·SEND_MEMBER·SPONSOR_RELATION) | warn |
| `models/silver/_silver_bridge_schema.yml` | `IDENTITY_MEMBER_XREF.MEMBER_DK → CRM_MEMBER` | warn |
| `models/silver/ga4/_ga4_schema.yml` | `GA4_IDENTITY.MBER_NO → CRM_MEMBER` (모델 disabled) | warn |

- **복귀 조건**: 현업이 "회원 마스터 추출 범위/시점 문제"를 확인·수정해 고아가 해소된 뒤.
- **검증 방법**: 되돌린 후 `dbt build --select path:models/silver path:models/gold` 로 ERROR=0 확인.

## 🔴 BLOCKING-2 — 현업 판정 대기 (→ `_현업검토요청_의심데이터_20260715.md`)
아래는 파이프라인이 무효/의심으로 처리했으나 **현업 회신 전까지 확정 불가**. 회신 오면 로직 반영.

| # | 항목 | 규모 | 현재 처리 | 회신 후 조치 |
|---|---|---|---|---|
| A | FMM `MONTH_KEY` 비-YYYYMM 값(예 20251·210103) | ~2,043행 | 무효→납입월/0 라우팅 | 유효 판정 시 클램프 완화 |
| B | 회원번호 마스터 부재 9,248명 + 불량ID(예 `1`) + NULL회원 750 | — | warn(보존) | 마스터 재추출 or 불량 폐기 |
| C | 캘린더 범위밖 날짜(<1910·>2030) | ~140행 | DATE_SK=0 | 유효 시 캘린더 확장 |
| D | 원천 값 전무 컬럼(CONV_CALL_CNT·캠페인분류·TOT_CLICK_CNT·BROWSER·ERP_BIZ_TARGET) | — | NULL | 추출보완 or 정상NULL 확정 |
| **E** | **`EVENT_KEY → CRM_EVENT` 고아 263,611 (참여 23%)** · `SNDNG_KEY → CRM_SEND_REQUEST` 11,313+9 | 대 | **error 유지(loud)** | 원인규명(마스터 누락 vs 키체계) 후 수정 |

- ⚠️ **E 때문에 full `dbt build` 는 여전히 실패한다(의도적).** GOLD-only build(`--select path:models/gold`)만 green. E 해결 전까지 full build green 기대 금지.

## ✅ [DONE 2026-07-15] 검토 항목 4 (정제규칙 이행) — drift 없음
- **SILVER 32모델 전량 ↔ `04_silver_design/09_SILVER_적재쿼리_20260714.sql`(912줄) 정밀 대조 완료. drift 0건 → 수정 없음.**
- 대조 범위·결과:
  - CRM 21/21 일치: `NULLIF(TRIM())`·코드 라벨조인(CM018/MM005/MM010/MM018/PM040)·`QUALIFY ROW_NUMBER` dedup·UNION 통합(EVENT/PARTICIPATION/PAYMENT_BILLING/SEND_*)·SEX 매핑(1,3→M/2,4→F/NULL/U)·수신동의 정규화(ARRAY_SORT/DISTINCT)·`::TIMESTAMP_NTZ` 캐스팅 전부 정본과 동일.
  - ERP 3/3 일치: MD5 복합키·12개월 언피벗(CTE+UNION)·`INCOME_EXPS_DIV_NM<>'TOTAL'` 제외. `ERP_BIZ_TARGET`은 정본 보류(E-6) 대로 `WHERE 1=0` 빈 모델.
  - AGENCY 2/2 일치: 3소스 UNION·`YEAR()/MONTH()` DATE 파생·`TRY_TO_NUMBER` 인입콜·MD5 소재키.
  - GA4 5/5 일치: 정본 주석대로 단일 샤드→`ga4_union_shards` 매크로(전기간 UNION)로 업그레이드(의도된 설계). param 승격·2단계 session-fill CTE·S접두 분기 동일. 매크로가 소문자 인용식별자→대문자 별칭·컬럼 명시(SELECT * 금지) 이행. `var(ga4_start/end)` dbt_project.yml 존재 확인.
  - bridge 1/1 일치: LEFT JOIN(UNMATCHED 보존, C1)·MATCH_METHOD/CONFIDENCE 파생.
- 결론: 09 정본 이후 SILVER drift 없음. 항목 1·2·3·5·6·7과 함께 순서 9-B 검토 **전 항목 완료**.

## 🟡 결정 대기 — 항목 5 (누락/과잉 GOLD 6개)
GOLD DDL 24개 중 미적재 6개. 모델 작성 여부 결정 필요:
- SILVER 소스 준비됨(모델만 쓰면 적재 가능): `DIM_AD_CREATIVE`←AGENCY_AD_CREATIVE · `FACT_AD_PERFORMANCE`←AGENCY_AD_PERFORMANCE · `DIM_BUDGET_ITEM`←ERP_BUDGET_ITEM · `FACT_BUDGET`←ERP_BUDGET
- 소스 부재: `FACT_TARGET_BIZ`(ERP_BIZ_TARGET 0행)
- `DIM_MEMBER_IDENTITY`: `enabled=false`. 소스 XREF 1,348행 존재하나 GA 행매칭 실증 대기 → 현 상태 유지 권고(FGA 가 IDENTITY_SK=0 센티넬 사용 중, 활성화 이득 없음).

## 🟡 설계 노트 (개선 후보, 비긴급)
- **월 팩트 conform**: `FACT_MEMBER_MONTHLY`·`ERP_BUDGET` 는 `MONTH_KEY`(YYYYMM) grain 인데 **DIM_MONTH 부재**, `DIM_DATE` 는 일 grain → 월 팩트가 날짜차원에 단일키 조인 불가. 월 차원 신설 또는 degenerate 명시 검토.
- **`DW_BATCH_ID` 전 SILVER NULL**: SILVER 모델이 `NULL AS DW_BATCH_ID` 하드코딩(dbt `invocation_id` 미주입). 감사메타 보완 필요(GOLD 는 `gold_meta` 매크로로 정상 주입).

## 🟢 배포 미반영
- 순서 9·9-B 모든 편집은 **워크스페이스 직접실행 검증만** 완료. 배포객체(GOLD·SILVER dbt project) **`ALTER DBT PROJECT ... ADD VERSION` 미반영** — 승인 후 신규 버전 등록 필요.

---
_생성: 순서 9-B 세션. 갱신 시 항목별 `[DONE]`·날짜 표기._
