<!-- LLM-METADATA
doc_id: HANDOFF_O0223_A
doc_role: 인수인계 — 세션 `O223-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-14
created_by: O223-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0223-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O223-A-0 🔴 먼저 알아라

- 세션 O223: Agent 언어 가드레일 강화 및 법인구분(CPR_DIV_CD) 회비·실적 매핑 개선 완료.
- 0단계 운영계 피드백 분석 및 1차 문서 / 2차 실적재 데이터 검증:
  · Agent thinking/reasoning 과정에서 드물게 발생하는 외국어(일본어/영어) 방지 대책 수립.
  · 법인구분 '산출불가' 코멘트 원인 분석: `DIM_ORG.CORP`(조직 차원 법인)는 부서-법인 N:M 혼재로 산출불가(`CONF-4`)이나, 회비/개발실적/후원사업/세부캠페인은 원천 `CPR_DIV_CD`(`CM019`: I=사단, S=사복)로 정상 적재/산출 가능함을 실측(`WIDE_MEMBER_FEE` 사단 1,614만건, `TM_PM_MBRFEE_ACMSLT` 사단 4,021만건).
- 1단계 Agent Thinking / 언어 가드레일 강제 (`cortex_project/agents/*/agent_spec.yaml` 3종):
  · 사고 과정(Reasoning/Thinking), 중간 진행 안내 문장, 최종 답변을 한국어로만 작성하고 일본어/영어 추론·출력을 전면 금지하는 `O223` 가드레일 적용.
- 2단계 시맨틱 뷰 동의어 확장 및 VQR 배포:
  · `05_SV-Agent_ai/05_09_SV_DDL_MEMBER_FEE.sql` (`SV_MEMBER_FEE`): `ACQ_CPR_DIV`에 '법인구분', '사단법인', '사복', '사회복지법인', '사단' 등 동의어 추가 및 사단법인 연도별 회비 VQR(`vqr_o223_sadan_member_fee`) 추가 후 라이브 배포 및 실측 성공.
- 3단계 에이전트 스펙 라우팅 지침 및 코퍼스 보강:
  · 에이전트 3종 스펙에 사단법인 회비(`analyst_member_fee`, `fee.ACQ_CPR_DIV = '사단'`) 및 개발실적(`analyst_member_event`, `sponsorship.SPONSORSHIP_CPR_DIV_NM = '사단'`) 라우팅 가이드 명시.
  · 코퍼스(`O217_biz_definition_corpus.csv` 및 `O217_routing_curated.csv` RT-21) 법인명 설명 보강 및 `GN_DW.SERVING.BIZ_DEFINITION_CORPUS` 2,154행 재적재 완료.

### ▣ O223-A-1 라이브 반영 및 실측 현황

| 구분 | 객체/도구 | 실측 상태 | 비고 |
|---|---|---|---|
| 시맨틱 뷰 | `GN_DW.SERVING.SV_MEMBER_FEE` | 배포 및 실측 성공 | `ACQ_CPR_DIV` 동의어 및 VQR 추가 |
| 사단법인 회비 실측 | `SV_MEMBER_FEE` 사단 회비 | 2026년 청구 546.7억, 납입 446.5억 (81.67%) | SEMANTIC_VIEW 정상 쿼리 확인 |
| 코퍼스 테이블 | `GN_DW.SERVING.BIZ_DEFINITION_CORPUS` | 2,154행 재적재 완료 | RT-21 법인명 설명 보강 |
| Agent 스펙 | `AGENT_MEMBER`, `AGENT_EXECUTIVE`, `AGENT_MARKETING` | 스펙 정본 갱신 완료 | 언어 가드레일 및 법인구분 라우팅 명시 |
| 게이트 검증 | `sv_identifier_gate`, `agent_tool_claim_gate` | 🟢 전건 PASS | blocking 위반 0건 |

### ▣ O223-A-2 🟠 ㉠ 이 작업의 성과 및 잔여

- ① Agent reasoning/thinking 및 출력 언어 한국어 전용 강제 가드레일 확립.
- ② 사단법인/사회복지법인 회비 및 실적 질의에 대한 시맨틱 뷰 및 에이전트 라우팅 정상화.
- ③ 코퍼스(`BIZ_DEFINITION_CORPUS`)와 에이전트 스펙 간 설명 정합성 일치.

### ▣ O223-A-3 🟡 ㉡ 워크스페이스 백로그

- 전체 목록 = `12_agent개선과제/20_O21X_잔여작업_정리.md`
- 열림 4건 (#12, #14, #17, #19) 유지.

### ▣ O223-A-4 ⚪ 결정 완료(재론 금지)

- 사단법인/사회복지법인 질의 시 회비는 `ACQ_CPR_DIV = '사단'`, 개발실적은 `SPONSORSHIP_CPR_DIV_NM = '사단'`을 정본 필터 축으로 사용한다.

_Co-authored with CoCo_
