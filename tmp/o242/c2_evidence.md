# O242 C② 근거(R1-3-7-c · 판정 전 기록)

## E1 S4 스모크 도구 경로 — `tmp/o241b/eval_s7/smoke_S4.json` content[] (thinking·tool_use 전건)

- thinking 원문: "This question exactly matches a verified query — a governed SQL statement the agent builder authored and verified as the correct answer for this exact question. I'm running that verified SQL and will answer directly from its results"
- tool_use 원문 키: `"name": "system_execute_sql"` · `"semantic_model": "analyst_ga_child_unpaid"` · `"verified_query_used": true`
- 실행 SQL = `05_SV-Agent_ai/05_26_SV_DDL_GA_CHILD_UNPAID.sql:87` 의 `vqr_o239_unpaid_conv` SQL 과 문자 동일(별칭 `UNPAID_SVC_CONV_RATE_A` 등 영문 · ROUND 없음).

## E2 기존 VQR — `05_SV-Agent_ai/05_26_SV_DDL_GA_CHILD_UNPAID.sql:84~92`

- `vqr_o239_unpaid_conv` QUESTION '클릭월별 미납서비스 전환율' = S4 질문(`tmp/o241b/eval_s7.py:20`)과 문자 동일.
- `vqr_o239_child_codes` 도 영문 별칭(`CHILD_CODE_CNT_A`).
- 같은 파일 :81 AI_SQL_GENERATION = O206 한글 별칭 · O241-R ROUND(식,2)::NUMBER(38,2) 규칙 ⇒ VQR SQL 이 SV 자신의 규칙을 어긴다.

## 판정

- O241-C ② 의 「analyst 를 거치지 않는다 · 지시로 미해소」= 플랫폼의 VQR 정확일치 직행 경로(정상 동작). 지시로 막을 대상이 아니다.
- 처방 = VQR 추가가 아니라 **기존 VQR SQL 을 한글 별칭 + ROUND 로 교정**.
- 평가 함의 = 이 경로의 도구 이름은 system_execute_sql(semantic_model = analyst_ga_child_unpaid)이다 ⇒ 기대 도구 판정 시 고려.
