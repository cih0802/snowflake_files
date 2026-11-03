# O242 C④ 근거(R1-3-7-c) — VERSION$7 native eval(정답지 V6 · tag o241s · 2026-10-18 · mn11232)

## E1 점수 — `tmp/o242/eval_s/state.json` score (AVG · 문항수)

| Agent | AC | LC | TS | TE | 문항 |
|---|---|---|---|---|---|
| EXECUTIVE | 0.9843 | 0.779 | 1.0 | 0.8071 | 21 |
| MARKETING | 0.9286 | 0.8336 | 0.875 | 0.9357 | 14 |
| MEMBER | 0.8454 | 0.6162 | 0.4362 | 0.4785 | 13 |

- 비교 기준 = O241-C-2 o241m($6 · V5) EXEC 1.00/0.95/0.98/0.80 · MKT 0.976/0.905/0.911/0.964 · MEM 0.872/0.719/0.479/0.494(AC/LC/TS/TE).

## E2 MEMBER Q01 — GET_AI_EVALUATION_DATA(o224_member_o241s) tool_selection_accuracy METRIC_CALLS 원문

- "**Expected:** `[analyst_ml_churn_campaign]` (1 tools)" · "**Invoked:** `[analyst_ml_sponsor_risk, analyst_ml_sponsor_risk]` (2 tools)" · "Score: 0.00"
- AC 1 · LC 0.33 · TE 0.
- OUTPUT 원문 일부 = "\n\n\nका캠페인카테고리별 중단(이탈) 예측 결과를 그래프로 정리하겠습니다." ⇒ 이물 문자(데바나가리 `का`) 1건.

## 판정

- Q01 경로는 실행마다 다르다($6 = churn_campaign · 이번 = sponsor_risk ×2) ⇒ 단일 기대 도구 정답지는 어느 쪽이든 편차를 낸다.
- V6 하에서 이번 실행은 V5 였으면 TS 0.5(sponsor_risk 일치) ⇒ 이번 MEMBER TS 하락분 일부는 정답지 교체 효과.
- EXEC LC 0.95 → 0.78 은 문항 단위 원인 미분해(다음 세션).
