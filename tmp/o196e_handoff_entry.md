### ▣ O196-E-0 🔴 먼저 알아라 (2026-10-01 · 개발계 pw69582)

- 🟢 dbt build(DEC-58·59) 판정 통과 — STOP 배선 99.74% · 신규 2종 행수 = 원천 일치. 🟠 단 FMD `SEND_REQUEST_SK` 고아 11,421 → 모델 수정 완료 · **재build 필요**.
- 🟢 `SV_RELATION_ACTIVITY` 신설·배포(Agent 미배선 — 어느 Agent 에 붙일지 사용자 결정).
- 🟢 D-4 = 현행 유지 확정(DEC-59 #1).
- 🔴 AGENT_MARKETING 은 ERP 예산단위(팀)·개발인입경로 축으로 집행비용을 **아직 못 낸다** — SILVER 에는 있고 GOLD/SV 에 없다 · 「컬쳐콘텐츠팀」은 ERP 에 없다.

### ▣ O196-E-1 🟠 남은 작업 — ㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | FMD 재build(사용자) | `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select FACT_MESSAGE_DISPATCH+';` → 고아 FK 0 확인 |
| 2 | ERP 예산단위·인입경로 전파(승인 시) | `06_DDL` FACT_BUDGET 2컬럼 + ALTER → 모델 → build → SV_BUDGET 차원 2 → Agent MARKETING·EXECUTIVE |
| 3 | SV_RELATION_ACTIVITY Agent 배선 | 대상 Agent 결정 후 도구 추가 + 버전업 |
| 4 | 스모크 재측정 · 산출물 골든 · 원장 002 재분할 | O196-D-1 순3·순4 승계 |
