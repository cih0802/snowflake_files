<!-- LLM-METADATA
doc_id: HANDOFF_O0193_A
doc_role: 인수인계 — 세션 `O193-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-01
created_by: O193-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0193-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O193-A-0 🔴 먼저 알아라 (2026-10-01 · 문서작업 계정 pw69582 · DB 없음)

- 🟢 **O192-A·O192-B 의 입고 후 절차는 그대로 유효하다** — 이 단위는 Agent 스펙·게이트만 바꿨고 DDL·dbt 는 건드리지 않았다.
- 🔴 이 단위의 변경은 **라이브 배포 0** 이다 — `AGENT_MEMBER` 스펙 파일만 바뀌었다 ⇒ 운영계에서 `05_SV-Agent_ai/09_2_AGENT_버전업.sql` 로 버전업해야 반영된다.

### ▣ O193-A-1 🟢 이 단위가 끝낸 것

- `cortex_project/agents/AGENT_MEMBER/agent_spec.yaml` (백업 = `cortex_project/_archive/AGENT_MEMBER.agent_spec_BAK_20261001.yaml`)
  · 실적 도구 8종 원천 괄호 = BRONZE_CRM 테이블명 + GOLD 팩트(dbt 리니지 · 29종 `_sources.yml` 실재).
  · response 각주 규칙 = 「도구 description 원천 괄호의 이름만 옮겨 쓴다 · TC_* 생략」.
  · orchestration 신설 절(O193) = 예측 부재 시 ① 부재 고지 ② **다른 예측 제안 금지** ③ 실적 도구 접근 확인(경량 조회) ④ 「실적을 먼저 보시겠어요?」 되묻기 · system ③ 정렬.
- `scripts/agent_source_lineage_gate.py` 신설(gate_census **JUDGE** 등재 · 파일만 읽음)
  · 판정 = ①리니지 밖 BRONZE ②리니지 밖 GOLD(blocking) · ③핵심 원천 누락 ④원천 괄호 미기재(advisory · `--strict` blocking) · ⑤dbt 밖 SV 관측.
  · 🟢 **SV 배선 때 쓰는 법** = `python3 scripts/agent_source_lineage_gate.py --suggest --sv SV_XXX` → 원천 문구 출력(업무 라벨은 사람이 붙인다) → 스펙에 기재 → 무인자 실행으로 판정.
  · 음성 테스트 `scripts/test_agent_source_lineage_gate.py` 10축 PASS · 실스펙 blocking 0 · advisory 10.
- 원장 `O193` 행 등재(원장 `--rebalance` 1회 · 상한 초과 해소) · 세션이력 `--rollover` 등재.

### ▣ O193-A-2 🟠 남은 작업

- 운영계: `09_2` 로 AGENT_MEMBER 버전업 → 실답변 검증 2건 = ㉠ 원천 질문에 BRONZE 테이블명이 나오는가 ㉡ 「후원사업별 개발금액 예측」에 다른 예측 제안 없이 실적 확인을 되묻는가.
- AGENT_EXECUTIVE·AGENT_MARKETING 원천 괄호 미기재(advisory ④ 7건) — 같은 형식으로 맞출지 사용자 결정 대기.
- 개발금액 예측(`SV_ML_DVLP_FORECAST` · 전사/캠페인만)을 AGENT_MEMBER 에 배선할지 = 현업 의도(예측 vs 실적) 확인 대기. 후원사업 예측은 원천 삭제로 불가.
- `o192_*` 3종 gate_census 미분류(O192-B 소관 · 이 단위는 손대지 않음).
- O191-G · O192-A · O192-B 원장 행/세션이력 미기록(O192-A-4 지적) — 이 단위는 O193 만 기록했다.

_Co-authored with CoCo_
