# 스킬 ↔ GN_DW.MSTR 비교 항목

- 기준 스킬: `snowflake-mstr-dw-to-ods/snowflake-coco-workspace-v3`
  - 계산 로직 = `references/examples/mstr_dept_member_development_to_crm_final_202606.sql`
  - 보고서 조건 = `references/reports/02_REPORT_CONDITION_MATRIX.md`
  - 기준값/게이트 = `references/common/04_VALIDATION_GATES.yaml`
- 스킬 측 값 = 위 로직을 BRONZE_CRM 원천으로 Snowflake 에서 재계산한 값
- MSTR 측 값 = `GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM`(선택월 개발) · `GN_DW.MSTR.F_MM_SPNSR_DVLP`(전 이력 개발)
- 검증 쿼리 = `스킬_MSTR_검증쿼리.sql` (항목 ID = `@CHECK` 이름)
- 기간 = 2026-01 ~ 원천 최신월

## 1. 비교 가능 항목

| ID | 대상 REPORT_ID | 항목 | 비교 grain | 지표 | 스킬 측 정의 | MSTR 측 정의 | 판정 |
|---|---|---|---|---|---|---|---|
| V01 | DEV_1_1 | 개발구분별 기본 Fact | 월 × 개발구분 | 행수 · 회원(DISTINCT) · 개발(건) · 금액 | FN_MM_SPNSR_DVLP 1/2/4 재현(신규·재후원 = 후원사업 월합>0·유지, 증액 = RAMT 배분) | F_MM_SPNSR_DVLP_SUM, DVLP_DIV_CD 1/2/4 | 4개 지표 차이 0 |
| V02 | DEV_1_1 | 스킬 고정 기준값 게이트 (202606 전체법인) | 개발구분 | 위 4개 지표 | `04_VALIDATION_GATES.yaml` DEV_SELECTED_MONTH_202606_ALL_CORP 고정값 | 같은 지표 | 고정값과 차이 0 |
| V03 | DEV_1_1 | 원장 행 단위 대사 | 후원번호·후원사업번호·발생일·SER_NO·개발구분 | 존재 · 금액 · 회원 · 부서 · 후원사업 · 법인 | SKILL 원장 | MSTR 원장 | SKILL_ONLY · MSTR_ONLY · AMT_DIFF · ATTR_DIFF 0 |
| V04 | DEV_1_1 | 부서별 회원개발(당월) 보고서 grain | 월 × 법인 × DEPT4 × DEPT3 × DEPT × 사업약어 × 후원사업 × 개발구분 | WJXBFS1(건) · WJXBFS2(명) · WJXBFS3(금액) | 스킬 결과 2 `#MONTH_AGG` | 같은 grain 집계 | 누락/추가 키 0, 지표 차이 키 0 |
| V05 | DEV_1_2 | 부서별 회원개발(누계) | 기준월 × 위 grain (1월~기준월) | WJXBFS4(누계 건) · WJXBFS5(누계 DISTINCT 명) | 스킬 결과 2 `#YTD_AGG` | 같은 범위 누계 | 키·지표 차이 0. 스킬 상태가 `LOGIC_IMPLEMENTED_INDEPENDENT_REFERENCE_REQUIRED` 이므로 일치해도 「두 계산이 같다」까지만 확인됨 |
| V06 | DEV_1_3 / DEV_1_4 | 회원구분(신규/기존)별 개발 | 월 × 개발구분 × 회원구분 (당월 · 누계) | 건 · 명 | 회원의 원천 전체 DVLP_DIV_CD='1' MIN(OCCRRNC_DE) ≥ 기준연도 0101 → 신규 | 회원의 MSTR 원장(F_MM_SPNSR_DVLP 전 이력) DVLP_DIV_CD='1' MIN(OCCRRNC_DE) 기준 | 차이 0. 차이가 나면 「원천 전체 vs 필터된 원장」 기준 차이 |
| V07 | DEV_1_5 | 캠페인 / 상위캠페인 개발 + TOP10 | 월 × 캠페인 · 월 × 상위캠페인 | 건 · 명 · 순위 | 원장 CMPGN_CD, 상위 = BRONZE `TM_CM_CMPGN_MNG.UPPER_CMPGN_CD` | 원장 CMPGN_CD · UPPER_CMPGN_CD | 키·지표 차이 0, TOP10 순위 동일 |
| V08 | 공통 차원 | 부서 계층 · 법인 · 사업약어 매핑 | 원장 행 | DEPT2/3/4 · CPR_DIV_CD · SPNSR_BSNS_ABRV_CD | 스킬 `#DEPT_DIM`(ACMSLT_UPPER_DEPT_ID 5단 계층, 'Z~'=없음) · `#BUSINESS_DIM` | 원장 ACMSLT_DEPT2/3/4_CD · CPR_DIV_CD · SPNSR_BSNS_ABRV_CD | 불일치 행 0, 미매핑 건수 동일 |
| V09 | 공통 규칙 | 회원합계 규칙 | 월 | 전체 DISTINCT 명 vs 부서별 명 단순합 | cross_report.member_total | 같은 계산 | 양측 값 동일(규칙 위반 여부 참고) |

## 2. 비교 불가 항목 (MSTR 스키마에 대상 객체 없음)

| REPORT_ID | 사유 |
|---|---|
| ACT_2_1 활동회원(회원구분별) | 월말 활동상태·후원잔액 Base — GN_DW.MSTR 에 활동 Fact 미구성(1차 이관 범위 밖) |
| ACT_2_2 활동회원(후원사업별) | ACT_2_1 과 같은 Base 필요 |
| STOP_3_1 중단회원 | 중단 이력 Base — MSTR 미구성. 스킬도 `NOT_EQUIVALENCE_VERIFIED` |

ACT_2_1(202606·법인 I) 은 스킬에 고정 기준값(`ACTIVITY_202606_I`)이 있으므로, 활동 Fact 를 이관하면 같은 방식으로 게이트를 추가할 수 있다.

## 3. 비교 시 지켜야 할 규칙 (스킬 원문)

- `건` = 금액 / 10000. 물리 행수(COUNT(*))를 업무 건수로 쓰지 않는다. (V01 의 행수는 Fact 대사용)
- 상위 grain 회원수는 DISTINCT 로 다시 계산한다. 하위 회원수 합으로 대체하지 않는다.
- 2025 허수회원 토글 · 2026-04 수동보정은 화면(Pivot) 전용 예외다. Fact 비교에 넣지 않는다.
- 보고서마다 「신규」 정의가 다르다. DEV_1_1 은 개발구분, DEV_1_3 은 최초 신규개발일 기준이다.
- 기준값을 맞추려고 하드코딩하지 않는다.
