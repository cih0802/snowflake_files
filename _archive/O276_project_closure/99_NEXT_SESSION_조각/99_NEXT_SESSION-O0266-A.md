<!-- LLM-METADATA
doc_id: HANDOFF_O0266_A
doc_role: 인수인계 — 세션 `O266-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-28
created_by: O266-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0266-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O266-A-0 🔴 먼저 알아라

- `O266-A` = 마케팅 Agent 현업 피드백 1~4 대응 + O265-C 잔여(2026-10-28 · TRIALADMIN · 개발계 ZS83821 · ㉡ 적용 · 사용자 승인 = 「재배포 및 기타 모든 작업」).
- 🔴 **dbt 는 아직 하지 않았다**(R4-1). 라이브에 있는 것 = 46 [D0](GN_DW_DBT → GN_DW.MSTR 읽기 GRANT) · [D1](FAP `LAST_STMT_AMT` 열 · 빈 `FACT_MKTG_CAMPAIGN_MONTHLY_COST`).
- 🔴 `SV_AD`·`SV_MKTG_CAMPAIGN_COST`·`SV_MEMBER_COHORT` 재배포와 Agent 버전업은 **build 뒤**다(05_07 은 WIDE_AD_COMBINED 새 열이 build 후에 생긴다).
- 게이트 = line_len PASS(18파일) · jinja PASS · sv_no_rollup PASS · sv_common_block PASS · 🟠 sv_identifier·agent_object_ref FAIL 1건씩 = 신규 SV·팩트 라이브 미배포(예상 · 배포 후 재실행).
- 확정위반 1(유실 0) = R1-7-8 성격 — 보조주석 edit 앵커가 「바꾸지 않은 것」 1줄을 삼킴 → 즉시 복원. read 미반환 0.

### ▣ O266-A-1 결과

| 영역 | 결과 | 정본 좌표 |
|---|---|---|
| O265-C ② | 45 [D2-2] 대사 일치(A 합 8,220 vs 기대 8,236 · 16 차 미규명) · 05_04 `SV_SERVICE` 재배포 · Analyst 행운의 카드 A 9 · B 22 · 중단 0 | `05_SV-Agent_ai/45_DEPLOY_SEND_GBN_AT_OPEN.sql` [D2-2] |
| 피드백 1 정산액 | 디지털 `LAST_STMT_AMT`(광고비+마크업+부가세) GOLD·WIDE·SV_AD 배선 · 영상·재방송은 정산 개념 없음(NULL) | `FACT_AD_PERFORMANCE.sql` 끝 · `05_07` `AD_SETTLE_AMT` |
| 피드백 2 한 표 | 결합 팩트 `FACT_MKTG_CAMPAIGN_MONTHLY_COST`(마케팅캠페인×월 · 개발 = MSTR) + `SV_MKTG_CAMPAIGN_COST` + Agent 도구 `analyst_mktg_campaign_cost` | `models/gold/fact/` · `05_31` · `cortex_project/agents/AGENT_MARKETING/agent_spec.yaml` |
| 피드백 3 캠페인명 | 원인 = Analyst CTE `mx` 관계 검증 실패(데이터 결손 아님) → Agent 재시도 규칙 | spec orchestration [O266] |
| 피드백 4 LTV | 금일 답변 = 도구 0회 → 「도구 필수 · 6열 표」 규칙 + `05_03` VQR | spec · `05_03` `vqr_o266_ltv_tenure_cap_unlimited` |
| 권한 | MSTR 읽기 정본 = `00_mstr_schema_role.sql` [4-b] · 07 §D.9 [1-g] 는 포인터(07 은 MSTR 스키마 생성 전 실행) | 두 파일 |
| 순서 | 문서실행순서 기존 환경 갱신 45~52 · 신규 구축 56-1·52-1 = 05_31 · 이력 = 보조주석 「O266만 덧입힐 때」 | `문서실행순서.md` · `문서실행순서_보조주석.md` |
| 사전 측정 | 모델 렌더 = 3,960행 · PK 중복 0 · 광고비 60,191,254,704.38 · 제작비 3,295,334,668 · MSTR 개발 885,881.0585 | 46 [D2] 주석 |

### ▣ O266-A-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 dbt 재배포 → `build --select FACT_AD_PERFORMANCE+ FACT_MKTG_CAMPAIGN_MONTHLY_COST` | 차단 요인 |
| ② | 46 [D2] 대사 → 05_07·05_31·05_03 재배포 → 09_2(Agent 버전업) → [D3] → 게이트 2종 재실행 | ① 후 |
| ③ | Agent 로 피드백 4문항 재현(광고비+정산 · 캠페인 한 표 · 캠페인명 · LTV 6열) | ② 후 |
| ④ | 현업 회신(4건) · 운영계 반영 = 기존 환경 갱신 43~52 | ③ 후 |
| ⑤ | 🟠 O265 잔여 = A 합 16 차 · SND GA 7,610 ↔ 4,893 원인 | 미착수 |
| ⑥ | 🟠 현업 확인 대기 = AT006038·AT006040 · child.gn · 웹팀 리다이렉트표 | 회신 대기 |

### ▣ O266-A-3 🆕 새로 발견

- 🔴 `FACT_MEMBER_COHORT_SURVIVAL` 무기한 유지개월 < 상한 유지개월 셀 37개(캠페인카테고리 35/74 · 개발인입경로 1 · 캠페인유형1 1) — 예: 참전용사 상한 80.0 · 무기한 1.0(무기한 표지가 경과월 0). LTV 무기한 값이 틀린다 ⇒ 별도 과제.
- 🟠 제작비 = 지출결의 세부캠페인코드 기재분만(33.0억 / 2,994억 ≈ 1.1%) ⇒ 현업에 「제작비 세세목」 정의 요청 필요.
- 🟠 이벤트 테이블에는 질문·답변 본문이 없다(RECORD = span 메타 · VALUE 빈값) — SQL 원문은 sql_execution.query_id → QUERY_HISTORY 로만 확보된다.
- 🟠 `sv_enum_newvalue_gate` 세션 브리핑 300초 timeout(⚪ 미판정) — 재실행 필요.

_Co-authored with CoCo_
