<!-- LLM-METADATA
doc_id: HANDOFF_O0212_B
doc_role: 인수인계 — 세션 `O212-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-08
created_by: O212-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0212-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O212-B 인수인계 (6차 마감 = O212-A + 원천 컬럼명 원칙 · 회비월 라벨 · NGO 친화 · 7차 계획 범위 확정)

### ▣ O212-B-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 승인 일괄 · 확정위반 1)

- 🟢 라이브 = AGENT 3종(EXEC·MEMBER·MKT) **VERSION$6** default · AGENT_GUIDE DROP · SV 3종 교체(MSTR·MEMBER_EVENT·MEMBER_FEE).
- 🟢 정본 = `12_agent개선과제/00_작업계획.md` §12-1·12-2 · 세션 이력 = `01_세션이력-085.md` §O212.
- 🟢 O212-B 추가분:
  · 원천 컬럼명 원칙: 「캠페인유형」= TYPE1(국내/해외) · 「캠페인유형2」= TYPE2(사업/사례) · 「브랜드」= BRND_NM · 「공통브랜드」= CMMN_BRND_NM.
  · MSTR 뷰에 CMPGN_TYPE1_NM 컬럼 추가(총 5축) · SV_MSTR_SPNSR_DVLP 에 캠페인유형 차원 추가.
  · SV_MEMBER_FEE 에 MONTH_LABEL('YYYY-MM') 차원 추가 + AI_SQL_GENERATION 규칙(회비월 숫자 표시 202,601 문제 해결).
  · NGO 친화 표현 규칙(횡보적 평형→보합세 · 이탈→중단 · 코호트→가입 시기별 회원 묶음 · 고객→후원자 등).
- 🔴 확정위반 1 = O212-A 세션의 R1-7-2 병렬 edit(유실 0).

### ▣ O212-B-1 🟠 남은 작업

| # | 할 일 | 비고 |
|---|---|---|
| 1 | 7차 Agent 개선 = 캠페인 마스터 분류 축 전수 배선 검토(§13 계획 수립) | 다음 세션 착수 |
| 2 | native eval v3_0 재측정(과금 · 다음 프롬프트 입력시) | 승인 대기 |
| 3 | 운영계 반영(3종 스펙 + MSTR/ME/FEE SV/뷰) | 운영계 세션 소관 |
| 4 | 13일 시연·19일 부서장 발표 대비 질문 리허설 | 👤 |
| 5 | CRM 신규 컬럼 8종 Agent 활용 검토 | 원천 입고 후 |

### ▣ O212-B-2 ⚪ 결정 완료(재론 금지)

- O212-A 결정 전건 유지 + 아래 추가:
- 「캠페인유형」= 캠페인유형(국내/해외 · TYPE1) · 「캠페인유형2」= 캠페인유형(사업/사례 · TYPE2) — 원천 컬럼 COMMENT 기준(현업 확인 완료).
- 「브랜드」= 원천 브랜드(BRND_NM) · 「공통브랜드」= 공통브랜드(CMMN_BRND_NM) — 원천 컬럼 COMMENT 기준.
- EXEC 예측 질문 → 회원 Agent 안내 = 유지(에이전트별 기능 특화 필요 · 사용자 결정).
- 회비월 표시 = SV 차원으로 해결(데이터 전처리 불필요).
- NGO 친화 표현: 전문적 어투 유지 + 단어·표현만 일상적·NGO 친화적으로.
- 7차 범위 = 캠페인 마스터 분류 전수 배선 + 마케팅캠페인(MKTG_CMPGN_NM = 나마본캠페인) 포함.

_Co-authored with CoCo_

_Co-authored with CoCo_
