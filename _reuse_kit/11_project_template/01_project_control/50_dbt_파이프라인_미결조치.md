<!-- LLM-METADATA
doc_id: 50_DBT_OPEN_ACTIONS
doc_role: dbt 파이프라인 미결조치 — 절 단위 증분형(새 절은 꼬리 · 처분 줄만 제자리 갱신)
project: {{DB}}
created: YYYY-MM-DD
END-METADATA -->

# 50_dbt_파이프라인_미결조치

> 절 제목 선두 이모지 = 상태(🔴 미결 · 🟠 진행 · 🟡 대기 · 🟢 해소). `session_brief.py` 가 🔴/🟠/🟡 절을 「열린 절」로 집계한다.
> 🔴 `--rebalance` 금지(증분형 · 좌표 파괴) — 상한 초과 시 `split_doc.py --rollover`.
