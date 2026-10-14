<!-- LLM-METADATA
doc_id: O229_INSPECTION_EVIDENCE
doc_role: O229 Inspection 근거철 — 구간 O202~O228 · 결함 D-번호 · 판정식 · 실측 · 처방
project: GN_DW (굿네이버스)
created: 2026-10-14
created_by: O229-A
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# O229 Inspection 근거철 (구간 O202 ~ O228 · jw08094 · 2026-10-14)

> 트리거 = 계정 재구축(jw08094 · 절차서 §0 ㉢) + O 세션 27개 누적(㉠) · 직전 = O201(구간 O171~O200).
> 절차 정본 = `60_repeat_어카운트시작/11_O누적작업_점검_재현_절차.md`.
> 원 출력 = `tmp/o229/insp_gates/*.out` · 실행기 = `tmp/o229/insp_gates.sh`(rc 는 파이프 없이 · 로그 `tmp/o229/insp_gates.log`).

## Phase 0 — 구간·결번

- 원장 §1 = O202~O228 전 라벨 행 실재 · 결번 0 · 미래 날짜 0(`tmp/o229/insp_labels.py`).
- 🔴 자기시정 = 첫 판정식 `^## (O2\d\d)` 이 이력 미등재 8건을 냈다 → 실물 제목은 `###`·`§` 서식 ⇒ 오탐 5건.
- 남은 관측 = O203 · O204-A · O211 은 원장 행만 있고 `01_세션이력` **제목 항목 0**(`tmp/o229/insp_hist.py` · rc=0).

## Phase 1 — 도구가 못 보는 것

| D | 판정식 | 실측(원문) | 처방 |
|---|---|---|---|
| D1 | 🔴🔴 **브리핑 GATES 밖 게이트가 FAIL 인 채 방치**(카탈로그 #18 · 0-1) | 브리핑 §6 전 🟢 ↔ 밖 게이트 `sv_unit_gate` rc=1 · `live_change_gate` rc=1 · `gold_erd_coverage_gate` rc=1 · `table_ddl_column_gate` rc=1 · `doc_line_length_gate` rc=1 · `sv_code_label_gate` rc=143 | 각 D 시정 후 브리핑 편입 여부 = 사용자 결정(실행 시간 · 라이브 과금) |
| D2 | 정본 목록이 개명을 따라갔나(#6 · #34) | `doc_line_length_gate` 「대상 파일 부재 9건」 `05_1_SV_DDL_MEMBER_MONTHLY.sql` ~ `05_9_SV_DDL_MEMBER_FEE.sql`(실물 = `05_01_`~`05_09_`) | CANON 경로 갱신 |
| D3 | 렌더러가 신설 매크로를 아나 | `table_ddl_column_gate` 「렌더되지 않은 jinja … FACT_MEMBER_MONTHLY.sql: ["{{ billing_campaign_asof('b') }}"]」(O225 매크로) | 렌더러 보강 |
| D4 | ERD 고립 컬럼 분류(#20 계열) | 「미분류 고립 4건」 `DIM_RELATIONSHIP.MEMBER_DK` · `FACT_BIGQUERY_SESSION.BIGQUERY_SESSION_KEY` · `.IDENTITY_SK` · `FACT_EXPENSE_RESOLUTION.MKTG_CAMPAIGN_SK` | 컬럼별 conform/degenerate 실측 후 KNOWN_ORPHANS 등재 |
| D5 | 무기록 변경 게이트가 **계정 재구축**을 아나(#37) | 「🔴 FAIL — 무기록 라이브 변경 36건」 전건 created 2026-10-14 = jw08094 재구축(O228 행) | 오탐 — 재구축 기준시각 면제 축 필요(처방만 · 미집행) |

## Phase 3 — 라이브 실증 (`sv_unit_gate` 원문)

| D | 원문 | 처방 |
|---|---|---|
| D6 | 「🔴 GRANT 누락: SV_ML_REALTIME_SIMULATOR (5건) REFERENCES→GN_DW_ANALYST; REFERENCES→GN_DW_SERVICE; REFERENCES→GN_DW_VIEWER; SELECT→GN_DW_SERVICE; SELECT→GN_DW_VIEWER」 | 🔴 활성 결함(재구축 누락) · GRANT 5 |
| D7 | 「COMMENT 수치 신규 유입: SV_ML_CHURN_CAMPAIGN.METRIC.SPONSOR_HIGH_RISK_MEMBERS [COMMENT] 1건」 · 「SV_ML_INC_CAMPAIGN.CUSTOM_INSTRUCTION.None [AI_SQL_GENERATION] 100명」 | 규칙7 — 매치 실물 확인 후 판정(#15) |
| D8 | 「AGENT 발행 표면 결함: AGENT_EXECUTIVE ▸ 소관 SV 종수 선언 부재(기대 총수 8)」 · MARKETING 7 · MEMBER 11 | Agent 객체 COMMENT 재구축본 확인 |
| D9 | 「🔴 위반: SV_DVLP_GOAL_ACMSLT.ACMSLT_RATE [비율 명명]」 | 선행 등재 여부 확인 |

## 그 밖의 축

- 음성 테스트 52종 전건 rc=0 · `rename_stale_gate` 축1 0 · `sv_comment_object_gate` blocking 0 · `decision_closure_gate` 🟠 5(O225 이래 동일).
- D10 = MKT eval 정답지 Q29 작업 메모 채점 오염(`tmp/o229/01_q29_cause.md` · `02_gt_memo_scan.md`).
- D11 = 런북 파일명 stale 3곳(`24_BIZ…` · `25_ML_REALTIME…` ×2) → O229 시정.

_Co-authored with CoCo_
