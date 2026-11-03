### ▣ O267-B-0 🔴 먼저 알아라

- `O267-B` = O267 세션 정리(사용자 승인 2026-10-28). 사용자 결정 = **개발계 작업 종료 · 운영계 반영으로 넘어간다**(사용자 실행).
- 세션이력 롤오버 완료(`01_세션이력-090.md` 에 `## O267` · 본문 바이트 동일 · 유실 0) ⇒ O267-A-2 ⑤ 는 닫혔다.

### ▣ O267-B-1 선택 게이트 결과(`sh scripts/optional_gates.sh` · fail=6 · 원문 = `tmp/o267/optional_gates.out`)

| 게이트 | rc | 사유(보고만 · 시정 안 함) |
|---|---|---|
| `comment_drift_gate` | 1 | GOLD 컬럼 COMMENT 불일치 29 · SILVER 7 · GOLD 테이블레벨 1 — 자격 조건 확인 전 결함 단정 금지(O120 ㉡) |
| `live_change_gate` | 1 | 2026-10-28 라이브 변경(AGENT_EXECUTIVE · SV_AD · SV_AD_INFLOW_ALLOC · SV_BUDGET 등)이 원장 §1 에 객체명으로 없다 — O266 재배포분 기록 축 |
| `rename_stale_gate` | 1 | 개명 전 이름 신규 2파일 = `30_output_share/_ENV/ZL50263/S30_Q01_1.csv`·`S30_Q02_1.csv`(운영계 측정 산출물) |
| `sv_unit_gate` | 1 | 비율 아님 단가 3건(`COST_PER_DEV` · `DEV_UNIT_PRICE_MSTR` · `TOTAL_COST_UNIT_PRICE_MSTR`) — 예외 등재 검토 |
| `table_ddl_column_gate` | 1 | `DIM_ORG_SUCCESSION` DDL 블록 부재 · `FACT_MEMBER_EVENT_COHORT` DDL 85 ↔ 모델 50(O265 발송 열 DDL 선반영) |
| `sv_code_label_gate` | 143 | 900초 timeout — 미판정 |

### ▣ O267-B-2 ㉡ 워크스페이스 백로그(추가)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | B-1 의 6건 판정·처방(특히 live_change 원장 기록 · sv_unit 예외 등재 · table_ddl 집합 정합) | 미착수 |
| ② | O267-A-4 ②③ 승계(중간 텍스트 노출 · T1↔T2 · CP949 csv) | 미착수 |
