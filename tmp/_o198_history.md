
## O198 — O196 계열 잔여 집행 (2026-10-02 · 계정 pw69582 · 개발계 · 사용자 일괄 승인 · R4-4-2 ㉡ 적용 · 확정위반 1)

- 착수 = init_ihcho 브리핑 → 사용자 지시 「O196 진행 · 승인 전부」 ⇒ 라벨 O198 선점(`id_collision_gate --next O`).
- ① 원장 002 `--rebalance` PASS(40,752→27,385 B · 스냅샷 `O198-prerebalance`) · O196-F·O198 행 등재 · `index_row_gate` PASS.
  · 🟠 관측 = `--dry-run` 플래그를 함께 줬는데도 재균형이 집행됐다(도구 출력 「조각 17개 재기록」) — 승인 범위 안이라 피해 없음 · 도구 거동 확인 필요.
- ② 골든 = 입력 재덤프(`dump_schema`·`census_columns`) → 04→05→06(`run_bronze_audit_host.py`)→07→08→09·03 재생성 → `--update-golden --label O198`.
  · 08 +104 = 2차-B 99(`tmp/o191g_fill.txt` 표 단위 일치) + O190 1 + O190-F 2 · 잔여 2 검증 불가(구 골든 개수 전용) ⇒ `08.row_keys` 신설.
  · 06 대조 기준 = `_archive/06_BRONZE노출감사.csv.UNLABELED-regen.5`(감사일 09-29) · +1행 · 이동 110 전부 노출 증가 · 역행 0.
  · 09 = `SELF_PART_FLAG` 값없음→조립가능 1(구 판본 `30_output_share/_archive/20260830` 전건 NULL).
  · 🔴 확정위반 1 = 06 을 `get_active_session` 주입 임시 실행기로 먼저 생성(정식 러너 미확인 · 범주 2종 누락 산출) → 매핑 문서 확인 후 정식 러너로 재생성 · 임시기 삭제.
- ③ DEC-60 신설 · 06_DDL 2컬럼 · ADMIN ALTER 2 + 팩트 COMMENT · 모델 2 · `warn_fact_budget_grain` 키 확장 · SV_BUDGET 재배포(PK 3키 · 차원 2).
  · 사전 시뮬레이션 = 1,332→1,488행 · 중복 0 · 편성·집행 합계 불변.
- ④ AGENT_MEMBER `analyst_relation_activity` 신설 + 라우팅 경계(발송 5일 반응 = analyst_service) · EXEC·MKT 예산 도구 차원 안내 · 게이트 4종 PASS · V6/V7/V7.
- ⑤ 스모크 39/39 PASS(중간 오류 1 MKT_07) · 가드 R1·R2 HIT · R1 응답 암산 오류 +1,000,000(SQL 정확).
- 독해 기록(R1-3-7-b) = 지침 304줄 전량(R0-8-4·R4-4-4) · 00_BRIEF 125줄(O0197-A) · 라벨 8파일 전량(O195-A ▣1 · O196-F ▣1 순5 · O197-A ▣1 순4) · 09_2 410줄 전량([0-C] size 판정) · read 미반환 0 · 재호출 0.
- 인수인계 = `99_NEXT_SESSION-O0198-A.md`.
