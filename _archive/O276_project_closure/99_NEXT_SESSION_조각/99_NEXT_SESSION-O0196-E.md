<!-- LLM-METADATA
doc_id: HANDOFF_O0196_E
doc_role: 인수인계 — 세션 `O196-E` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-01
created_by: O196-E
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0196-E -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
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

_Co-authored with CoCo_
