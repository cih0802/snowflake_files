### ▣ O201-A-0 🔴 먼저 알아라 (2026-10-03 · JU93656 · ㉡ 적용 · 확정위반 0)

- 🔴 **계정이 바뀌었다** = JU93656(GRHVGDR-ZO79488 · 신규 개발계). 프롬프트의 pw69582 수치는 인용하지 않는다(사용자 결정).
- 근거철 = `20_issue/_o201_inspection_evidence.md`(§E0 결함 D1~D6 재수록 · 모든 수치의 정본).
- 🟢 D1 = 앞선 O201 시도가 `session_brief.py`·`test_session_brief.py`(축12)를 이미 고쳤다(08:23 UTC · 사용자 확인) · 테스트 80/80 · 브리핑 §1 비어 있지 않음.
- 🟢 D2 = O200-D ▣2 「09_1 COMMENT = 초기 샘플」 **결정 해제**(사용자) · `09_1`·`24` 문안 교정 · 라이브 ALTER 4건 · 종수 수치 0.
- 🟢 ③ NL 스모크 = Agent 4종 44문항 · 최종 응답 실패 0 · 중간 오류 1(EXEC_05 한글 비인용 별칭) · JU93656 기준선 1.
- 🟢 D4 = `60_repeat_어카운트시작/12_GN_DW_재구축_실행순서.md` 신설 · readme 커밋 복원 경로 무효(git 없음).
- 🟢 ⑤ = O170 집합 95 대비 해소 44 · 신규 10 · SV_AD 노출 확정 3(항상 NULL measure).
- 🟢 D5·D6 = 절차서 §3 #34~#37 · §7 O170·검토·O201 등재 · D6 탐지 설계안(근거철 §E6 · 미집행).

### ▣ O201-A-1 🟠 남은 작업

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | SV_AD 항상-NULL measure 3 처방 | `TOTAL_CRM_DEV_CNT`·`DEV_UNIT_PRICE`·`TOTAL_MEDIA_POTENTIAL` 노출 차단 또는 COMMENT 경고 — 🔴 SV 변경은 승인 후 |
| 2 | EXEC_05 중간 오류 | 생성 SQL 의 따옴표 없는 한글 별칭 · orchestration 식별자 규칙 보강 여부 결정 후 재스모크 |
| 3 | `test_verify_wide_doc` rc=1 | `View names mismatch!` — 라이브 WIDE 뷰 ↔ dbt ↔ 문서 집합 대조 |
| 4 | `BRONZE_GA4` 문안 | EXEC·MKT 스펙 「BRONZE_GA4 스키마 실재하지 않는다」 ↔ JU93656 실재(테이블 2) — 판정 보류 |
| 5 | D3 | O180~O189 예고 검토 미실행 — 착수 여부 결정 |
| 6 | D6 게이트 | §E6 설계안 → 신설 시 음성 테스트 동반 |
| 7 | 👤 사람 대기 · dbt | `dbt build --project-dir 10_dbt_pipeline --select WIDE_SPNSR_CLS_AGGR` (O200-D 승계) |
| 8 | 👤 사람 대기 · CoWork | 「MSTR 리포트」·「회원 분석」 스모크(O200-D 승계) · 새 COMMENT 표시 확인 |
| 9 | 👤 사람 대기 · 현업 | 문서20 N-26 등(O200-D 승계) |

### ▣ O201-A-2 ⚪ 결정 완료(재론 금지)

- 라이브 계정 = JU93656 에서 실행(사용자 · 2026-10-03).
- Agent COMMENT = 라이브 스펙 기준 · 종수 수치 금지(O200-D ▣2 해제).
- NL 스모크 = Agent 4종 전량(MSTR 편입).
