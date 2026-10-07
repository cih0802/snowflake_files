## O206-C 인수인계

### ▣ O206-C-0 🔴 먼저 알아라 (2026-10-07 · JU93656 · ㉡ 적용 · 확정위반 0 · 세션 누계 1 = O206-A R1-7-2)

- 🔴 **3차 개선 비판적 검토**(`12_agent개선과제/00_작업계획.md` §9-4 C1~C7) — 표 헤더만 보던 판정이 **본문 수치 오류 3건**(연간 합계 1,667.6억 ↔ 실제 1,627.6억 · 분모 43,666 ↔ 43,498 · 1.27억을 127억)을 놓쳤다.
- 🟢 처방 = SV 28종 `[O206-C 합계 규칙]`(합계·분모는 SQL · ROLLUP · COUNT DISTINCT 별도) · Agent 4종 `[O206-C 수치 근거]`(답변 직전 셀 대조) · 판정기 `tmp/o206_numcheck.py`(본문 수치 ↔ 모든 도구 결과).
- 🟢 라이브(SHOW VERSIONS 실측 · default) = AGENT_MEMBER VERSION$6 · AGENT_EXECUTIVE VERSION$6 · AGENT_MARKETING VERSION$6 · AGENT_MSTR VERSION$7 · SV 28/28 두 마커 실재.
- 🟢 재측정 10건(`tmp/o206_round3c/`) = 표 헤더 10/10 · 근거없음 수치 2(R11 두 행 덧셈 · 값 정확 · △ 유지).
- 🟢 06 = 정식 러너 `scripts/run_bronze_audit_host.py` 로 재생성(🔴 `gen_bronze_exposure_audit.py` 직접 실행 금지 · 노트북 전용) · 스냅샷 라벨 UNLABELED(R1-7-10 경고 · 다음엔 `--label` 지정).
- 🟠 `_wide_schema.yml` 「임시 규칙」 3곳 교정 = **파일만** — 라이브 뷰 COMMENT 는 다음 dbt build 때 반영된다.

### ▣ O206-C-1 🟠 남은 작업

㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 👤 다음 dbt build 때 `WIDE_MEMBER_SERVICE_COHORT` 포함 | yml COMMENT 3곳 라이브 반영 확인(`DESCRIBE VIEW` comment 에 「O206 A안」) |
| 2 | 스모크 표준에 수치 근거 판정기 편입 | 이후 Agent 재측정은 `tmp/o206_judge.py` + `tmp/o206_numcheck.py` 두 판정기로 한다(scripts/ 정식 편입은 사용자 결정) |

㉡ 워크스페이스 백로그 = O206-B-1 ㉠1·2 · ㉡ 그대로(N-28 회신 · 기획실/나마본 피드백 · MSTR 일일 적재 · 04.row_keys · live_change_gate).

### ▣ O206-C-2 ⚪ 결정 완료(재론 금지)

- 「두 행 덧셈」 수준의 서술 산술(R11)은 규칙을 더 강화하지 않는다 — 값이 맞고, 더 막으면 서술이 경직된다(△ 유지).
- 규칙 문안에 실측 수치를 넣지 않는다(규칙7) — 사고 유형만 서술했다.
