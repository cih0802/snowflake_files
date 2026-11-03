### ▣ O201-B-0 🔴 먼저 알아라 (2026-10-03 · JU93656 · ㉡ 적용 · 확정위반 0)

- 근거철 = `20_issue/_o201_inspection_evidence.md` §E10~§E13 (수치 정본).
- 🟢 O201-A 남은 작업 1~5 종결 = SV_AD 항상-NULL 3 COMMENT 경고 · Agent 4종 열 별칭 영문 규칙(V4/V4/V4 · MSTR V5) · `test_verify_wide_doc` 통과 · BRONZE_GA4 문안 교정(EXEC·MKT V5) · O180~O189 검토.
- 🔴 **MSTR = 구조만 있고 데이터 0행**(테이블 10 전건) — 기존 3종 Agent 에는 MSTR 도구가 없다(반영된 적 없음). 값 검증은 적재 후에만 가능.
- 🟢 ML 예측 질문 33건 판정표 = `05_SV-Agent_ai/40_ML예측질문_답변가능성_검토.md`(⭕5 · △16 · ✕12).
- 🟠 스모크 생략(사용자 결정) ⇒ 별칭 규칙 효과는 미측정.

### ▣ O201-B-1 🟠 남은 작업

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | MSTR 이력 적재 | `15_MSTR 이관 PoC/tools/mstr_pipeline.py`(스킬 `mstr-migration`) 로 적재 → AGENT_MSTR 로 값 검증 → 3종 반영 여부 결정 |
| 2 | 미승계 O183-A | 공45~47·54~57·77~78 비율 지표 — 분모 「누계개발건」 정의 후 SV metric |
| 3 | 미승계 O182-A | VIDEO 캠페인 축 도달률 급락 — JU93656 재측정 |
| 4 | 미승계 O180-B | `doc_coord_gate` 「줄 내용」 축 도입 여부 결정 |
| 5 | 원장·이력 누락 | O18x 라벨 원장 §1 부재 12 · 이력 부재 8 — 소급 등재 여부 결정 |
| 6 | ML 질문 개선 후보 | MKT 에 LTV·일시전환 도구 · 기획실 A/B안 VQR · GA 행동 SV |
| 7 | D6 게이트 | 근거철 §E6 설계안 |
| 8 | 👤 사람 대기 · dbt | `dbt build --project-dir 10_dbt_pipeline --select WIDE_SPNSR_CLS_AGGR` (O200-D 승계) |
| 9 | 👤 사람 대기 · CoWork | 새 COMMENT·별칭 규칙 반영 확인 스모크 |
| 10 | 👤 사람 대기 · 현업 | 문서20 N-26 등 · 기획실 후원사업그룹(국내/결연/해외프로젝트/기타) 축 일치 확인 |

### ▣ O201-B-2 ⚪ 결정 완료(재론 금지)

- 항상-NULL 지표 = COMMENT 경고만(노출 유지) · 열 별칭 = 영문·숫자·밑줄만 · 이번 스모크 생략.
