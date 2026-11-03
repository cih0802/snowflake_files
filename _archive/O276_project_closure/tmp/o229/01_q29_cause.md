# O229 ② MKT Q29 AC 0.67 · TS 0.2 원인 (jw08094 · 2026-10-14)

## 근거 (원문 · run `o224_marketing_jw1` · `GET_AI_EVALUATION_DATA` × `EVAL_O224_AGENT_MARKETING_V4` · QUESTION_ID=Q29)

- 실행 버전 = `"object_version_name":"VERSION$3"`(C3 ④ VERSION$4 이전 run).
- 정답지 GT = 「GN_DW 기준으로 analyst_ml_ltv_forecast 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 기준 표기). 유의: O204 에서 EXEC·MKT 답 정의가 갈림.」
- AC 판정 원문 = 「the actual response does not explicitly address this distinction between executive-level and marketing-level answer definitions, which is a key nuance mentioned in the expected answer」 · original_score 2 → 0.67.
- TS 원문 = 「**Expected:** `[analyst_ml_ltv_forecast]` (1 tools) · **Invoked:** `[analyst_ml_ltv_forecast, analyst_member_cohort, analyst_member_cohort, analyst_member_cohort, analyst_ml_ltv_forecast]` (5 tools)」 · Score 0.20.
- LC 0.67 · TE 0.7.
- 답 요지 = ML 예측 1위 NTV 43,333원 · 실적 유지기간 SBS 59.8개월 · 「두 기준은 … 분리」.

## 판정

| 지표 | 원인 | 분류 |
|---|---|---|
| AC 0.67 | GT 끝의 **작업 메모**(「유의: O204 에서 EXEC·MKT 답 정의가 갈림」)를 채점기가 필수 내용으로 읽었다 | 🔴 정답지 결함(답은 정답 요소 4/4 충족) |
| TS 0.2 | 기대 도구 1종 ↔ 지침 「LTV 예측+실적 동반」(런북 §0 #6 · O217)으로 cohort 동반 호출이 **의도된 행동** | 🔴 정답지 stale(지침 변경 미반영) |
| TS 0.2(부분) | `analyst_ml_ltv_forecast` 2회(차트용 상위 15 재조회) · cohort 3회 | 🟠 Agent 비효율(실재) |

## 처방 (eval 실행은 사용자 지시로 제외 — 미집행)

1. MKT 정답지 V5 = Q29 GT 에서 「유의: …」 메모 제거 + 기대 도구 = `[analyst_ml_ltv_forecast, analyst_member_cohort]`(V4 는 기준선 보존 · MEMBER V5 와 같은 방식).
2. Agent 지침 = 차트 데이터는 직전 도구 결과 재사용(재조회 금지) — 효과는 다음 eval 에서 판정.
3. 🟠 같은 「유의:」 메모가 다른 문항 GT 에 있는지 전수 점검 → `02_gt_memo_scan.md`.

_Co-authored with CoCo_
