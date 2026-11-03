<!-- LLM-METADATA
doc_id: HANDOFF_O0190_F
doc_role: 인수인계 — 세션 `O190-F` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O190-F
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0190-F -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O190-F-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 🟢 사용자 결정 = O190-E-2 추천안대로 진행 · 승인 대상 일괄 승인.
- ⏸ **dbt build 1회 필요** — E-1(ERP_BUDGET → FACT_BUDGET) 모델 2개 변경 · DDL·ADMIN ALTER 선행 완료(게이트 103/103).
- 🔴 확정위반 1 = 세션 착수 브리핑(`R4-4-1`)을 작업보다 늦게 냈다(BRIEF 는 백그라운드로 생성·독해했으나 출력 누락).

### ▣ O190-F-1 🟢 이 단위가 끝낸 것

- **1ⓐ** SV 4종(MEMBER_EVENT·SERVICE·EVENT_PARTICIPATION·AD) `date.YEAR`·`date.MONTH` 실차원(`CAL_YEAR` 위 추측 식별자) · 조회 실증.
  🔴 `fme.EVENT_DATE` 는 미적용 — 팩트에 그 컬럼이 없고 사건일은 개발(JOIN_DATE)/중단(STOP_DATE)로 갈라 의미 창작이 된다.
- **1ⓑ** VQR 8건(SV 7종: DEV_ACHIEVEMENT 2 · BUDGET · AD · SERVICE · MEMBER_SPONSOR_BIZ · ML_DVLP_FORECAST · ML_LTV_SCORE)
  — 스모크 오류 패턴(metric 을 CTE 컬럼으로) 정답 SQL · SVA `validate_verified_queries` 8/8 valid → DDL `AI_VERIFIED_QUERIES` 절 · 라이브 반영.
- **1ⓒ** `nl_routing_smoke.py` 판정 2축 — ① 최종 응답 실패 0(blocking) ② 중간 오류 기준선 이하(추이) · `--strict`·`--set-baseline` ·
  기준선 = 10(`tmp/nlsmoke/_baseline.json`) · 4축 실증(무기준선 FAIL · 기준선 PASS · strict FAIL · 회귀 9 대비 FAIL).
- **2** `SV_ML_ONCE_CONVERSION` 에 「회원당 다중 예측행 · 회원수는 중복제거로」 경고.
- **4** E-1 선배선 — SILVER `ERP_BUDGET.DIRECT_MNYRS_YN_1/2`(degen) · GOLD `FACT_BUDGET.EXEC_DIRECT_MNYRS_1/2`(후보 집행액 2종 · 판정 중립).
  🔴 첫 설계(플래그를 GOLD grain 에 포함)는 `warn_fact_budget_grain`(error) 과 충돌 ⇒ 방금 만든 빈 컬럼 2개(비NULL 0 확인) 드롭 후 측정값으로 교체.
- **7·8** 현업 회신 요청서 `30_output_share/40_현업회신요청_O190.md`(결정 6 · 신규 19종 파생 컬럼 설명 요청).
- **게이트 결함 수리** `agent_tool_claim_gate` — `tool_resources:` 가 `tools:` 앞인 스펙(EXEC)에서 설명 9건 분모 누락(거짓 PASS 경로) → 키 순서 무관 파서 · 경고 9 → 0 · 음성 테스트 17/17.

### ▣ O190-F-2 🟠 그럼에도 남은 작업

| 순 | 작업 | 남은 이유 | 다음 행동 |
|---|---|---|---|
| 1 | dbt build(E-1) | 사용자 실행(`R4-1`) | ▣3 명령 · 후보 A ≤ 후보 B ≤ 집행 총액 검증 |
| 2 | 스모크 재실행(VQR·YEAR 효과 측정) | 과금 · build 후가 정확 | build 후 `nl_routing_smoke.py --apply` → 기준선 10 대비 판정 |
| 3 | F-1 본부/지부 | 🔴 **추천안이 실측으로 불성립** — 실적부서 455 의 실적트리 상위 노드가 389종으로 흩어지고 본부·지부 명칭은 271 뿐 | 현업 요청서 1번(ⓑ 부서코드 목록) 회신 대기 |
| 4 | E-1 지표화 · F-2 11개 · F-3 SND 오픈 · ML grain · DGT 이전분 | 현업·ML 담당 회신 | 요청서 발송 |
| 5 | 신규 19종 파생 컬럼 COMMENT | 업무 문안 원천 없음(창작 금지) | 요청서 2절 회신 반영 |
| 6 | 2차-B 2단 32테이블 | 이번 단위 미착수(공수) | 이용 상위 5테이블부터 1세션 1묶음 |
| 7 | 문서02 재서술 | 이번 단위 미착수(다중 조각 재작성 · 은퇴 동반) | 새 조각 1개 생성 → 구 조각 은퇴(`retire_rows`) |
| 8 | `agent_tool_claim_gate` 키 순서 음성 축 추가 | 수리만 하고 전용 음성 케이스 미추가 | `test_agent_tool_claim_gate.py` 에 `tool_resources` 선행 픽스처 1건 |
| 9 | 산출물 03~09 재생성 + 골든 | 잔여 0 조건 | 6·7 종료 시점 |

### ▣ O190-F-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select ERP_BUDGET+';
```

_Co-authored with CoCo_
