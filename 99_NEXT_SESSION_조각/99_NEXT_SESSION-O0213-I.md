<!-- LLM-METADATA
doc_id: HANDOFF_O0213_I
doc_role: 인수인계 — 세션 `O213-I` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-08
created_by: O213-I
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0213-I -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O213-I 인수인계 (Y4 Agent 배선 완료 · VERSION$7 · 다음 = Y5 전량 회귀 · Y6 eval)

### ▣ O213-I-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 승인 일괄 · 확정위반 0)

- 🟢 Agent 3종 **VERSION$7 default**(롤백 = `SET DEFAULT_VERSION = 'VERSION$6'`) · 도구 MEMBER 22 · EXECUTIVE 12 · MARKETING 20 = 스펙 · grant 4행 보존.
- 🟢 신규 도구 = MEMBER `analyst_payment_billing_status` · EXECUTIVE `analyst_expense_resolution`·`analyst_payment_billing_status` · MARKETING `analyst_ga_session`·`analyst_search_console`·`analyst_ga_demographic`·`analyst_expense_resolution`.
- 🟢 기존 도구 설명 보강 = SV 17종 · 같은 SV 는 3종 동일 문장(기계 대조 17/17) · 라우팅 = 각 스펙 orchestration 말미 「🆕 [O213 7차]」 블록.
- 🟢 스펙 편집 방식 = `tmp/o213_y4_agent_patch.py`(yaml dict 편집 · **safe_dump width=200 = 정본 생성 규약 · 3종 왕복 바이트 동일 실측**) — 다음 스펙 수정도 이 방식이 안전하다.
- 🟢 배포 = `tmp/o213_y4_deploy.py`(09_2 [0]→[0-B]→[0-C]→[2]→[3]→[5] 정본 문장 절단 실행) · COMMENT = 09_1 [1]·[5] 동시 갱신 후 [5] 실행.
- 🟢 NL 스모크 10문항 최종 10/10 · 라우팅 10/10 · 수치 일치 · ⚠️ 3건은 Analyst 1차 SQL 컴파일 오류 후 자가 재시도 성공(지표명을 컬럼처럼 · CTE 미선택 차원) — SV 직접 조회는 정상.
- 🔴 09_2 [0] 목록의 EXECUTIVE 7행(O212 롤백 전 잔재) 주석 처리 · `AGENT_GUIDE` 스펙 폴더(DROP 후 잔존)가 object_ref 게이트 FAIL·[0-C] MISSING 을 낸다 — 이번 변경과 무관.

### ▣ O213-I-1 🟠 남은 작업 — ㉠ 7차 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | Y5 전량 회귀 = `scripts/nl_routing_smoke.py --apply`(3종 추천 질문 49개 · 과금) · 기준선 대비 라우팅 퇴행 0 확인 | 승인 완료 범위 |
| 2 | Y6 eval 재측정(과금) · AC 점수 비교(O211-B v3_0 기준선) | |
| 3 | `cortex_project/agents/AGENT_GUIDE/` 처리(보존 이관 또는 삭제 — 사용자 확인) · 게이트 FAIL 해소 | |
| 4 | OPS 임시 객체 DROP(O213_* 7표 · 프로시저 5) · 문서20 N-29 ①~⑧ 회신 대기 | 7차 마감 |

### ▣ O213-I-2 ⚪ 결정 완료(재론 금지)

- O213-A~H 결정 전건 유지 + 아래 추가:
- 신규 SV 배치: GA·검색·인구통계 = MARKETING 전용 · 지출결의 = EXECUTIVE·MARKETING · 회비 청구 처리 = MEMBER·EXECUTIVE.
- 같은 SV 를 쓰는 도구는 Agent 가 달라도 7차 보강 문장을 동일하게 둔다(P212 주장 일치).

_Co-authored with CoCo_
