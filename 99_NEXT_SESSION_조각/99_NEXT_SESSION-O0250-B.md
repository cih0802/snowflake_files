<!-- LLM-METADATA
doc_id: HANDOFF_O0250_B
doc_role: 인수인계 — 세션 `O250-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-21
created_by: O250-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0250-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O250-B-0 🔴 먼저 알아라

- `O250-B` = O250-A 잔여 ②⑤ 집행(2026-10-21 · TRIALADMIN(SR61467) · ㉡ · 사용자 승인 · 확정위반 0).
- 7축 예측 도구 2종을 3 Agent 에 배선 · 버전업 완료. 롤백 = 직전 버전으로 DEFAULT 이동(아래 표).

### ▣ O250-B-1 이번 단위 결과

| 항목 | 결과 |
|---|---|
| 신규 도구 | `analyst_ml_pred_axis`(SV_ML_MEMBER_PRED_AXIS) · `analyst_ml_fee_axis`(SV_ML_FEE_FORECAST_AXIS) |
| 배선 | MEMBER = 2종 · MARKETING = 2종 · EXECUTIVE = pred_axis 1종(회비 예측 도구 미보유 Agent · O212 롤백 축 유지) |
| 규칙 | 3 스펙 orchestration 선두 [O250 7축 예측] 라우팅 · churn_campaign 「마케팅캠페인 축 없음」 문구 → 7축 도구 안내로 교체 |
| 게이트 | sv_identifier · agent_tool_claim · agent_object_ref · agent_source_lineage 전 PASS · line_len PASS · YAML 파싱 도구 = 리소스 일치 |
| 배포 | 09_2 [0] 부재 0 · [0-C] 3종 OK · MEMBER VERSION$5 · EXECUTIVE VERSION$5 · MARKETING VERSION$6(전부 default) |
| 롤백 기준 | MEMBER VERSION$4 · EXECUTIVE VERSION$4 · MARKETING VERSION$5 |
| 스모크 | MARKETING 「법인별 마케팅캠페인명별 기대 증액·중단 고위험 상위 5」 → analyst_ml_pred_axis 라우팅 확인(DATA_AGENT_RUN 1회) |
| 파일 | 3 agent_spec.yaml · `05_SV-Agent_ai/09_2_AGENT_버전업.sql`([0] 5행 · [3] COMMENT) · `tmp/o250/wire_agents.py` · `deploy_agents.py` · 백업 `tmp/o250/spec_bak/` |
| 독해 | 스펙 3종은 도구·리소스·orchestration 앵커 구간만 읽음(부분 · 스크립트가 앵커 1회 일치 검증) |

### ▣ O250-B-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 CoWork UI 에서 3 Agent 7축 질문 회귀(회원·경영 · 회비 배분 질문) | 👤 사용자 |
| ② | Agent 객체 COMMENT(「소관 SV N종」) 동기화 = 09_1 [5] — 기존부터 stale | 에이전트(승인 시) |
| ③ | 현업 본부지부 3분류 정의 확인 · 배분 불가 카테고리 원인(ML 담당) | 👤 현업 |
| ④ | 운영계 이관 = 36_ → 09_2 순서 | 👤 운영 |

### ▣ O250-B-4 ⚪ 결정 완료(재론 금지)

- O250-A 결정 그대로. EXECUTIVE 는 회비 7축 도구를 배선하지 않는다(회원·마케팅 Agent 안내).

_Co-authored with CoCo_
