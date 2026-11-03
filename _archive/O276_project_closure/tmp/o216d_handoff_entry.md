## O216-D 인수인계 (9차 정정 VERSION$6 + 백로그 추천안 집행 · 2026-10-12 · CK24285)

### ▣ O216-D-0 🔴 먼저 알아라 (㉡ 적용 · 승인 = 사용자 지시 · 확정위반 1)

- 🔴 확정위반 1 = O216-C 가 **사용자 결정을 거스르는 예외를 스펙에 넣었다** — 「사건 수를 명시하면 GN_DW 도구」.
  · 정본 결정 = O202 「개발(건) 단위 = MSTR 정의」(`99_NEXT_SESSION-O0201-D.md:31`) · O207 C안 「MSTR = 개발 지표 정본」(`12_agent개선과제/00_작업계획.md:279`).
  · 원인 = 결정 이력을 검색하지 않고 정의 차이만 보고 예외를 만들었다(`R3-9 ㉥` 결정 인용 정본 전수 검색 미실행).
  · 시정 = `tmp/o216d_agent_fix.py` · 3종 **VERSION$6** default(구 예외 0건 · `[O216-D]` 1건 · 도구 무변경) · 롤백 = VERSION$5.
  · 새 문안 = 「개발(건)·개발건수·개발 몇 건 질문은 표현과 무관하게 MSTR 정의로 답한다 — GN_DW 사건 수로 바꿔 답하지 않는다」.
- 🔴 O216-C 의 판정 오류 2건을 정정했다(둘 다 이력 미검색):
  · BLOCKING-5 「잔여 6축」 → **O183 DEC-55 로 이미 종결**(§55-C 사유별 비워 둠 확정).
  · O91-F A1 「결정 안건」 → **O176 B안으로 이미 집행**(store_failures 테스트 2종).
- 🟢 eval 은 재실행하지 않았다(문장 1개 교체 · VERSION$5 v9 결과 승계) — 필요하면 `tmp/o216_eval.py start 'VERSION$6' v3 v10`.

### ▣ O216-D-1 백로그 처리 결과

| 항목 | 판정 | 근거 |
|---|---|---|
| BLOCKING-5 | 🟢 종결 | DEC-55 §55-A 배선 41종 전건 값 있음 · §55-E ㉡ 0 · ㉠ 1(O183 675,370) · `tmp/o216d_dec55_measure.py` |
| BLOCKING-2 A | 🟢 종결 | 선납 회비월 유지 · `tests/warn_fmm_future_month_cap.sql` 신설(+37개월 · 현재 0행 · 음성 +36 → 1행) · MONTH_KEY=0 Unknown 확정(모델 기존 라우팅) |
| O91-F A1 | 🟢 종결 | O176 B안 기집행 · `OPS.WARN_BIGQUERY_NULL_USER_PSEUDO_ID(_ROWS)` 실재 · 원천 NULL 0 |
| O91-F A4-X 8 | 🟢 종결 | `_wide_schema.yml` 8 컬럼 description 에 `[O216-D A4-X 영구 센티넬]` · 라이브는 다음 build |
| O91-F A4-W 6 | 🟡 유지 | BIGQUERY 2 = build 후 배선 · AD 4 = Q10 현업 |
| 순서9-C E-1 | 🟡 회신 대기 | 추천안 문서50 `-018.md` 기재(YN_1='Y' · 좁은 정의) |
| 순서9-C G-5 | 🟡 운영계 소관 | `FACT_BIGQUERY_BEHAVIOR` 0행 — 사용자 build 진행 중 |
| O204 라벨 파일 | ⚪ 만들지 않음 | 원장 🟢 · 단발 Excel 작업 · 잔여 0 · 산출물은 O208 X1 이 소비 |

### ▣ O216-D-2 🟠 ㉠ 이 작업의 잔여 (사용자 build 후 · 다음 프롬프트)

| # | 할 일 | 비고 |
|---|---|---|
| 1 | build 결과 확인 = `warn_fmm_future_month_cap` 0행 · A4-X 라이브 COMMENT(`comment_drift_gate`) · `FACT_BIGQUERY_BEHAVIOR` 행수 | 배포본 갱신(`ADD VERSION`) 후 build 여야 새 테스트·yml 이 반영된다 |
| 2 | A4-W BIGQUERY 2건 배선(`UTM_CAMPAIGN`) | `FACT_BIGQUERY_BEHAVIOR` > 0 일 때 |
| 3 | E-1 모금성비용 배선 | 사용자가 추천안 승인 또는 현업 회신 시 |

### ▣ O216-D-3 🟡 ㉡ 회신·외부 대기 (개발계에서 닫을 수 없는 것)

- E-1 §N-17 현업 4문항 · A4-W AD 4건 Q10 · FACT_BUDGET 원천 규모(운영계 대조) · G-5 운영계 소관.
- 🔴 운영계 반영 = 사용자 지시로 **보류**(개발계 잔여·회신 대기 0 이 되면 반영).

### ▣ O216-D-4 ⚪ 결정 완료(재론 금지)

- 개발(건) = MSTR 정의 — 질문 표현과 무관(O202 · O207 C안 · O216-D 재확인).
- BLOCKING-5 = DEC-55 §55-C 가 공란 정본.
