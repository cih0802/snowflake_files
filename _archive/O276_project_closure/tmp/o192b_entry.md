### ▣ O192-B-0 🔴 먼저 알아라 (2026-09-30 · 문서작업 계정 · DB 없음)

- 🔴 **DDL 정본 파일 구성이 바뀌었다(O192-B · 사용자 지시 「새 환경용 최적화」)** — O192-A 입고 후 절차는 유효하되 아래 차이를 반영한다.
  · SILVER `08_SILVER_테이블DDL` · GOLD `06_DDL.sql` = **CREATE 1벌**(이관용 `ALTER … ADD COLUMN` 0) · GOLD 는 말미 제약 절(PK 5 + FK 64 · 선삭제 블록 재생성).
  · `21_ML_SERVING_뷰_DDL` = 뷰 컬럼 목록에 COMMENT 내장(`ALTER VIEW … MODIFY COLUMN` 109 → 0) ⇒ **재생성해도 컬럼 COMMENT 유지**.
  · `05_1`~`05_11` · `22` = 머리말 짧게 · SV 문자열의 세션 태그 제거(`[O191-D]` · `· O190` · `(R-O191 …)` 등) · VQR `VERIFIED_BY` 는 보존.
  · `05_0` = 인덱스·공통 규약·불변식 검증만(종전 본문은 부록).
- 🟢 뺀 주석은 **삭제 0 · 부록 이관**: `04_silver_design/08_SILVER_DDL_설계이력_부록.md` · `03_top-down_gold/06_DDL_설계이력_부록.md`
  · `05_SV-Agent_ai/21_ML_SERVING_뷰_설계이력_부록.md` · `05_SV-Agent_ai/05_SV_DDL_설계이력_부록.md`. 원본 = `_archive/*.O192-A-o192-*`(16건).

### ▣ O192-B-1 🟢 이 단위가 끝낸 것

- 도구 3종(쓰기 전 자체 대조 · 멱등 재실행 = 변경 없음): `scripts/o192_ddl_compact.py`(SILVER·GOLD) · `o192_ml_serving_compact.py`(21) · `o192_sv_compact.py`(05_N·22).
- 대조 축 = 테이블/뷰/문장 집합 · 컬럼 이름·타입·순서 · COMMENT(태그 정리 규칙 적용분만 차이) · 테이블/뷰 COMMENT · 제약 · GRANT · ⛔ 비활성 구간.
- 판정 사례: GOLD `FACT_TARGET_PROJECT` 3컬럼은 ALTER 가 옛 문안(O188-E)·CREATE 가 개정본(O190) ⇒ CREATE 채택(옛 문안은 부록).
- 발견·수정: 종전 FK 선삭제 블록이 제약 23건을 빠뜨려 FK 절 부분 재실행이 실패하는 상태였다 ⇒ 제약 목록에서 재생성.
- 발견·수정: `22` SV COMMENT 의 「설계문서 276행 근거」(행번호 인용 · `sv_rule7_scan` blocking 1) ⇒ 「근거 = 20_ML_SV_설계.md」.
- 오프라인 게이트: `audit_ddl_rule7` 위반 0 · `sv_rule7_scan` 0 · `agent_tool_claim_gate` 29/0 · `doc_line_length_gate` PASS
  · `test_o125_layer_census` · `test_extract_sv_deploy` · `test_sv_unit_gate_agent` · `test_comment_drift_table_level` PASS
  · 게이트 파서 등가(`table_ddl_column_gate`·`comment_drift_gate` 파서 = 압축 전과 동일 결과).

### ▣ O192-B-2 🟠 남은 작업 (입고 후 · O192-A ▣2 에 끼워 넣는다)

| 순 | 작업 | 남은 이유 | 다음 행동 |
|---|---|---|---|
| 1 | 라이브 게이트 | DB 없음 | ① 뒤 `table_ddl_column_gate` · `gold_erd_coverage_gate` · `sv_unit_gate` · `sv_code_label_gate` |
| 2 | 21 뷰 8종 실컴파일 | GN_DW 없음 · 컬럼 목록 문법은 SANDBOX 에서 1종(29컬럼) 컴파일 확인 | ② 에서 `deploy_ml_serving_views.py` 실행 · 8/8 OK 확인 |
| 3 | SV 문자열 태그 제거 회귀 | Agent 가 읽는 문안이 바뀌었다(의미 불변 · 태그만) | ③ 스모크 때 기준선 새로 측정 |
| 4 | 부록 문서의 좌표 | 부록은 원문 이관이라 「N행」 인용이 옛 파일 기준 | 인용 시 `_archive` 스냅샷 기준으로 읽는다 |
