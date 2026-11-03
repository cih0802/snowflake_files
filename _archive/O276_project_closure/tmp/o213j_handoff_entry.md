## O213-J 인수인계 (🟢 7차 종결 · 다음 세션 = 8차 Agent 업데이트 착수)

### ▣ O213-J-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 승인 일괄 · 확정위반 0)

- 🟢 **7차 종결** — 원천(BRONZE·SILVER 계산값·GA4·GSC·ERP) 카테고리 축을 GOLD/SV 로 전수 배선하고 Agent 3종에 연결했다(계획서 §13 단계표 Y0~Y4 🟢 · Y5 🟡).
- 🟢 라이브 = Agent 3종 **VERSION$7 default**(도구 MEMBER 22 · EXECUTIVE 12 · MARKETING 20 · 롤백 = `SET DEFAULT_VERSION = 'VERSION$6'`).
- 🟢 신규 SV 5종 = SV_PAYMENT_BILLING_STATUS(05_19) · SV_GA_SESSION(05_20) · SV_SEARCH_CONSOLE(05_21) · SV_GA_DEMOGRAPHIC(05_22) · SV_EXPENSE_RESOLUTION(05_23) · 기존 SV 17종 신규 축.
- 🟢 AGENT_GUIDE 스펙 = `cortex_project/_archive/AGENT_GUIDE.agent_spec_RETIRED_20261008.yaml` 보존 이관(README 표 기록) → `agent_object_ref_gate` PASS.
- 🟢 스펙 수정 정본 방식 = yaml dict 편집 + `safe_dump(width=200, allow_unicode, sort_keys=False)`(3종 왕복 바이트 동일 · 예시 = `tmp/o213_y4_agent_patch.py`) · 배포 = `tmp/o213_y4_deploy.py`(09_2 절차 그대로).

### ▣ O213-J-1 🟠 ㉠ 7차 잔여 → **8차 Agent 업데이트로 이월**(사용자 결정 2026-10-08)

| # | 할 일 | 비고 |
|---|---|---|
| 1 | 전량 NL 회귀 = `scripts/nl_routing_smoke.py --apply`(3종 추천 질문 전량 · 과금) · VERSION$6 대비 라우팅 퇴행 0 | 7차 신규 10문항은 최종 10/10 |
| 2 | eval 재측정(과금) · O211-B v3_0 기준선(AC EXEC 0.91 · MEMBER 0.85 · MKT 0.93) 대비 | |
| 3 | Analyst 1차 SQL 오류 패턴(지표명을 컬럼처럼 · CTE 미선택 차원) 저감 — SV AI_SQL_GENERATION 규칙 보강 후보(SV_EXPENSE_RESOLUTION·SV_BUDGET_YEARLY·SV_MEMBER_EVENT) | 응답 지연 요인 |
| 4 | OPS 임시 객체 DROP = O213_CAT_INVENTORY·LINEAGE_GAP·TRACE_STATUS_T·BRONZE_TO_SILVER·Y2_JUDGE·Y2_NAMEHIT·Y2_FINAL + 프로시저 5(PROFILE_SCHEMA·TRACE_LINEAGE·TRACE_LINEAGE2·TRACE_STATUS·TRACE_TEST) | 🔴 R4-4-3 승인 · Y2_FINAL 은 8차 판정 근거라 DROP 전 CSV 보존 권장 |
| 5 | 문서20 N-29 ①~⑧ 회신 반영(청구 코드 Y·F · 청구/처리결과 코드군 · SND 혼재 코드 · 상위캠페인 · 결연 중단사유 MM002 · 지출결의 동일 행) | 현업 회신 대기 |
| 6 | 라벨 해소 잔여(행사 그룹 3 · 이전상태 · 약칭 코드) | |

### ▣ O213-J-2 🟡 ㉡ 워크스페이스 백로그(7차와 무관)

- `split_doc.py --republish` 를 `--label` 없이 쓰면 `_archive/<허브>.UNLABELED-prehub.N` 접미가 **99 소진**돼 실패한다 — 이번엔 `--label O213-I` 로 우회 · 🔲 `_archive/` UNLABELED 스냅샷 정리(🔴 R4-4-3 승인 · 삭제 전 목록 확인).
- `09_2 [0-C]` 는 스테이지 폴더 전체를 비교한다 — Agent 를 은퇴시키면 워크스페이스 폴더를 `_archive` 로 옮겨야 MISSING 이 사라진다(이번 처리로 해소).

### ▣ O213-J-3 ⚪ 결정 완료(재론 금지)

- O213-A~I 결정 전건 유지 · 7차 잔여는 8차 Agent 업데이트에서 처리한다.
