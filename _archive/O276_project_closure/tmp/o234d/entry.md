### ▣ O234-D-0 🔴 먼저 알아라

- 개발계 = jw08094 · 2026-10-15 · 운영계 반영 없음 · ㉡ 적용(사용자 승인).
- 🔴 **마운트 단절 재발**(O233-A 와 동일) — 단절 중 수정은 `/tmp` 작성 → `cortex ws cp` 업로드로만 했다. 복구 후 마운트에서 O234 토큰 대조 3/3.
- 🔴 함정 = `cortex ws cp <prefix>/` 는 **하위 폴더를 평탄화**한다(경로 의존 게이트·테스트 미러로 쓰면 오판 · `gate_census` 미분류 35 는 이 산물).
- 🔴 함정 = `python3 - <<'PY' </dev/null` 은 뒤 리다이렉트가 heredoc 을 덮어 **스크립트가 조용히 안 돈다**.
- 확정위반 0(새로 추가).

### ▣ O234-D-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① live_change_gate | FAIL 3(오늘 Agent 3종 변경이 원장 §1 에 객체명 미기재) → O233·O234 행에 `AGENT_*` 객체명 보강 · 무기록 0 |
| ② gold_erd_coverage_gate | FMC `LAST_STOP_DATE_SK`(O233-A 신설) 미분류 → CONFORM 등재(실측 NOT NULL 931,014 · 미해소 0) · PASS |
| ③ table_ddl_column_gate | O232 `gn_*` 매크로 렌더 · vars 블록 jinja2 사전렌더(vars 정본 = dbt_project.yml) · config 제거 시 공백 흡수 방지 → 집합 116/116 · 음성 실증(미지원 매크로 rc=1) |
| ④ sv_rule7_scan · sv_unit_gate | 05_07 「(O230 · 0원 단정 금지)」 = 응답 규칙 표제 ⇒ SV 무수정 · `NUM_EXEMPT` 에 「0원 단정 금지」 형태만 등재(서술형 0원은 계속 검출 실증) |
| ⑤ test_verify_wide_doc | `09_빅테이블 VIEW.md` 생성물 stale → `build_wide_doc.py` 재생성 · 불일치 0(720컬럼) |
| ⑥ 전수 재실행 | `tmp/o234d/tests.txt` · `tmp/o234d/optional.txt`(결과는 이 단위 말미 표 참조) |
