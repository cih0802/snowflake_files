<!-- LLM-METADATA
doc_id: HANDOFF_O0212_A
doc_role: 인수인계 — 세션 `O212-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-08
created_by: O212-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0212-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O212-A 인수인계 (6차 집행 완료 = 4차 롤백 + 이월 a·b + 두괄식 + 분류 4축 SV 배선)

### ▣ O212-A-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 승인 = 프롬프트 R4·R5 + SV/뷰 교체 · 확정위반 1)

- 🟢 라이브 = AGENT 3종(EXEC·MEMBER·MKT) VERSION$5 default · AGENT_GUIDE DROP · 정본 = `12_agent개선과제/00_작업계획.md` §12-1·12-2.
- 🟢 스펙 생성기 = `tmp/o212_restore.py`(4차 원본 cp + 해시 확인 + 규칙 덧붙임) → `tmp/o212_tooldesc.py` → 발행 `tmp/o209_deploy.py` → 대조 `tmp/o212_cmp.py`.
- 🟢 SV 배선 = `SERVING.MSTR_SPNSR_DVLP_V` 4컬럼 · `SV_MSTR_SPNSR_DVLP` 4차원 + 규칙 (17)(18) · `SV_MEMBER_EVENT` 동의어(DDL = `05_SV-Agent_ai/23_MSTR_SV_DDL.sql` · `05_2_SV_DDL_MEMBER_EVENT.sql`).
- 🔴 확정위반 1 = R1-7-2 같은 파일(`23_MSTR_SV_DDL.sql`) 병렬 edit 2회 · 토큰 대조로 유실 0 확인.

### ▣ O212-A-1 🟠 남은 작업

| # | 할 일 | 비고 |
|---|---|---|
| 1 | native eval v3_0 재측정(`SERVING.O211_*_DS(_V2)` · run `o212_<a>_rollback`) + X6 판정기 | 과금 · 승인 필요 |
| 2 | 「캠페인유형 = 캠페인유형2(대분류)」 현업 확인 | 🟠 회의 메모 「확인 중」 |
| 3 | 요약 중복 1건(MEMBER S4 · 차트 앞뒤 재출력) 재현 관찰 | 🟠 |
| 4 | EXEC 의 회원 예측 질문 = 회원 Agent 안내(4차 판본) — 「한 Agent 에서 다」 요구와 충돌 시 이월 c 재판단 | 사용자 판단 |
| 5 | 운영계 반영(3종 스펙 + MSTR 뷰/SV + MEMBER_EVENT) | 운영계 세션 소관 |
| 6 | 13일 시연·19일 부서장 발표 대비 질문 리허설(12일까지 문의 수합) | 👤 |
| 7 | CRM 신규 컬럼 8종 Agent 활용 검토 | 원천 입고 후 |

### ▣ O212-A-2 ⚪ 결정 완료(재론 금지)

- 이월 = a(영문 금지) · b(「신규」 기본 해석) · c 미이월.
- 드릴다운 = 질문 명시 소분류만 · 그 외 대분류만 + 상세 끝 드릴다운 제안 1줄.
- 「브랜드」 = 공통브랜드 · 「개발인입경로」 = MM293 · 답변 = 핵심 요약 → 그래프 → ▼ 상세 · 금액 억/만 환산 금지.

_Co-authored with CoCo_
