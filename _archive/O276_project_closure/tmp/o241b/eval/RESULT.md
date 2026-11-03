# O241-F/T 결과 (2026-10-18 · 개발계 mn11232)

## 변경
- 정답지 V5 = V4 + MARKETING Q25 개정(O224-B 대리지표+한계 명시가 정답 · 도구 analyst_ga_behavior) → `EVAL_O224_AGENT_*_V5` · `O224_*_DS_V5`
- Agent 3종 VERSION$5(롤백 = VERSION$4)
  - response 선두 [O241-F 출력 전 자기점검 ㉠~㉤]
  - orchestration 선두 [O241-T 도구 호출 절약 ①~④]
- 스크립트: tmp/o241b/ds_v5.py · patch_spec.py · deploy_agents.py · eval_v5.py

## MEMBER 호출 대조(O241 run · 원인 확정)
- 같은 SV 도구 재호출(+1~+4) 11/13문항
- search_biz_definition 불필요 호출 5문항
- 기대 도구 누락: Q01 ml_sponsor_risk · R11 service · R15 member_cohort·mstr
- system_execute_sql 추가 호출 가설은 기각(0건)

## native eval (O241 V4 → O241f V5)
| Agent | AC | LC | TS | TE |
|---|---|---|---|---|
| EXECUTIVE | 1.00 → 0.97 | 0.92 → 0.86 | 0.95 → 0.95 | 0.79 → 0.78 |
| MARKETING | 0.905 → 0.976 | 0.858 → 0.906 | 0.798 → 0.916 | 0.957 → 0.957 |
| MEMBER | 0.821 → 0.845 | 0.745 → 0.745 | 0.42 → 0.554 | 0.533 → 0.644 |

## 스모크(형식 자동점검 F1~F5)
- 해소: F1 태그 · F4 요약 중복(4/4 통과)
- 잔존: F2 쉼표(S1·S2·S3) · F3 소수(S2·S4) · F5 영문 헤더(S4)
  - 원인: 모두 플랫폼이 자동 렌더하는 SQL 결과표다. Agent 가 직접 쓴 표·요약은 정상이다 ⇒ response 지시로는 막을 수 없다.
  - 다음 조치: SV AI_SQL_GENERATION 에 「한글 별칭 + ROUND(…,2) + TO_CHAR 쉼표」 지시를 추가한다.
- system_execute_sql 사용
  - S1~S3 은 SV 생성 SQL 실행(semantic_model 지정)이다.
  - S4 는 analyst_ga_child_unpaid 를 호출하지 않고 직접 SQL 을 실행했다 ⇒ 잔존 결함.
