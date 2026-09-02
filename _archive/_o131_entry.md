> #### 🟢 [2026-09-02 O131] index_row_gate 기준선 최신화 + table_ddl_column_gate SILVER 분모 전수 확장 + DEC-44 배선 및 착수표 정리

🔒 **라벨** = `id_collision_gate --next O` → **O131**(원장 §1 선점 등재).

#### 무엇을 실행했나
1. 🟢 **[작업 1] `index_row_gate` FAIL 원인 규명 및 골든 갱신**
   - 00_INDEX 99건은 닫힌 옛 세션(O45~O111) 대시보드 요약행 장문셀의 `02_상태상세`/`01_세션이력` 정상 은퇴 이관(O124~O125-E) 산물(실유실 0).
   - 99_NEXT 9건(⑩ ⑬ ⑮ ㉒ ㉓ ㉔ ㉕ ㉖ ㉗)은 O127~O129-B 조각 용량 관리 중 닫힌/이관된 착수표 행의 정상 포인터 압축 산물(실유실 0).
   - 신규 265행(00_INDEX +29, 02_상태상세 +3, 99_NEXT +233) 전건 정상 등재 확인 후 `--update-golden --reason` 갱신 완료 (`index_row_gate` ✅ PASS).

2. 🟢 **[작업 2] `table_ddl_column_gate` TARGETS 분모 확대 (GOLD 37 + SILVER 42 전수 79개)**
   - `scripts/table_ddl_column_gate.py` 를 전면 리팩터링하여 GOLD 37개 + SILVER 42개 전수 79개 테이블을 검사하도록 확장.
   - 정보 스키마 테이블 조회 최적화로 79개 테이블 컴파일 검사 속도 확보 (자기검사 4/4 PASS, 집합 일치 79/79 ✅ PASS).

3. 🟢 **[작업 3] `DEC-44` 예산 편성 차수 회계 재작성 배선**
   - SILVER `ERP_BUDGET`·`ERP_BUDGET_YEARLY` 에 `BUDGET_PROCEDURE` 컬럼 추가 (dbt 모델, `08_SILVER_테이블DDL`, 라이브 `ALTER TABLE ADD COLUMN`).
   - GOLD `FACT_BUDGET`·`FACT_BUDGET_YEARLY` 에 `BUDGET_PROCEDURE` 컬럼 노출 및 `PRCD_SEQ` 기반 연도별 최신 차수 필터링 배선 (`rnk = 1`).
   - `06_DDL.sql` 정합 반영 및 라이브 `ALTER TABLE ADD COLUMN` 집행 완료.
   - dbt tests 3종(`warn_erp_budget_procedure_merge`, `warn_erp_budget_month_grain`, `warn_erp_budget_yearly_grain`)을 `severity: error` 로 승격.
   - 기대값 검증 = 최신 차수 기준 `PLAN` = **65,202,608,326**, `EXEC` = **55,094,546,653** 일치.

4. 🟢 **[작업 4/5/6/7] 착수표 및 게이트 정비**
   - ㉞ `_gold_ready_schema.yml` relationships 18건: 이미 O128 에서 작성이 완료되어 물리 56건 ↔ YAML 63건(YAML만 7건 = DIM_MONTH 논리관계) 정합 상태임을 재실측 확인 후 착수표 `~~㉞~~` 완료 처리.
   - ㊹ FMM degen 6컬럼 grain 판정: FMM(회원×월 스냅샷) vs FME(사건) grain 불일치 및 SUM 왜곡 방지를 위해 FMM degen 드랍 보류 유지 및 G군 확정 제안.
   - ㊶ 잔여 5건: 원천 미구현 및 정의 미확정 상태로 확인되어 `R2-7-1` 에 따라 사유 창작 금지 및 보류 유지.
   - ⑤ C4 발행표면 정의 재확정 및 ⑱ O84 잔여 문서 2종(`01_SV-Agent 작업계획`, `04_SV_설계`) 전량 독해 완료.

#### 게이트 상태
`doc_census` ✅ · `clause_order_gate` ✅ · `index_row_gate` ✅ · `doc_heading_gate` ✅ · `doc_coord_gate` 🟡 · `table_ddl_column_gate` ✅
