# O227 근거 (xh20001 · 2026-10-14)

## ② MEMBER V$9 — 교차 집계 예외 조문 안 치환(K6)

- 파일 = `cortex_project/agents/AGENT_MEMBER/agent_spec.yaml:52` · 옛 = 「🔴 단 두 축의 교차 집계(…)는 새 지표가 아니라 분포 조회다」
- 새 = 「🔴 [O227 예외 판정] 질문에 새 비율·효과 지표 이름(「○○율」·「○○효과」·「효과가 높은」 등)이 없으면 분포 조회다 — 「교차 분석」·「복합 분석」 표현 포함」
- 라이브 = VERSION$9 is_default=true · 스펙 내 `O227 예외 판정` 적중 TRUE · 롤백 = `ALTER AGENT GN_DW.SERVING.AGENT_MEMBER SET DEFAULT_VERSION = 'VERSION$8'`

| 지표 (V4 · n=13 · 미채점 0) | o226v4(V$8) | o227v4(V$9) |
|---|---|---|
| answer_correctness | 0.8715 | 0.9231 |
| logical_consistency | 0.7962 | 0.8985 |
| tool_selection_accuracy | 0.4977 | 0.4323 |
| tool_execution_accuracy | 0.6092 | 0.4985 |

- 문항 |Δ|≥0.3 = R14 AC 0.33 → 1.0 · R12 0.33 → 0.67 · R15 0.67 → 1.0 · 🟠 D3 AC 1.0 → 0.33 · R10 TS 1.0 → 0.5
- 스모크(`tmp/o227/smoke_mem9.out`) = D3 직접 집계(확인 없음 · 조문 원인 아님 · 답변 건수 소수점 「-19,326.0590건」 = MSTR 개발(건) 분수값) · R14 직접 집계 · R13 확인 선행 유지
- 🟠 TS·TE 하락 = 1회 run · 기지(search_biz_definition 선행 · 정답지에 search 없음) — 재측정 대상

## ③-① COMMENT C3 테이블·뷰 레벨 33건

### 테이블 21 (파일 + 라이브 ALTER · `tmp/o227/fix_c3_tbl.py --apply`)

- 파일 = `03_top-down_gold/06_DDL.sql`(GOLD 11) · `04_silver_design/08_SILVER_테이블DDL_20260714.sql`(SILVER 10)
- 라이브 INFORMATION_SCHEMA = SILVER 10 · GOLD 11 · 잔여 이슈ID 0

| 지운 ID | 객체 |
|---|---|
| O188-F | SILVER CRM_BIZ_PLACE · CRM_CHILD · CRM_CODE_GROUP · CRM_INSTT_ACCOUNT · CRM_MSG_TEMPLATE · CRM_MSG_TEMPLATE_BUTTON · CRM_PAYMENT_METHOD_HIST · CRM_RELATION_CHANGE · CRM_RELATION_DEV · CRM_SETLE_CMPNY_ACCOUNT |
| O188-F | GOLD DIM_BIZ_PLACE · DIM_CHILD · DIM_CODE_GROUP · DIM_MSG_TEMPLATE · DIM_MSG_TEMPLATE_BUTTON · DIM_PAYMENT_ACCOUNT · FACT_PAYMENT_METHOD_CHANGE · FACT_RELATION_CHANGE · FACT_RELATION_DEV |
| O198 · DEC-60 | GOLD FACT_BUDGET |
| DEC-58 | GOLD DIM_SEND_REQUEST |

- 업무 명칭 = `10_dbt_pipeline/models/silver/crm/<모델>.sql` 1행 머리말 그대로.

### 뷰 12 (2 = O226 기반영 · 10 = 파일만 · 👤 dbt build 대기 · `tmp/o227/fix_c3_view.py --apply`)

- WIDE_TARGET_DEV · WIDE_AD_COMBINED = O226 에서 이미 4블록 재작성 · **라이브 반영 완료**(INFORMATION_SCHEMA 이슈ID 0 실측) ⇒ build 대상 아님.
- 10건 = `_wide_schema.yml` 9 · `_wide_dept_aggr_schema.yml` 1(WIDE_SPNSR_CLS_AGGR) · 줄 수 불변(1481 · 127).

| 지운 ID | 객체 |
|---|---|
| O49 · O51-F · G-5 · HOL-1 | WIDE_BIGQUERY_BEHAVIOR |
| DEC-8 · DEC-10 · O38-C · O45 · O51-F · P52 · Q10 · HOL-1 | WIDE_AD_PERFORMANCE |
| O16 · O38-C · O51-F · P52 · Q10 · HOL-1 | WIDE_AD_BROADCAST |
| O38-C · O51-F · P52 · Q10 · HOL-1 | WIDE_AD_DIGITAL |
| O14 · O51-F · P52 · Q10 | WIDE_AD_BROADCAST_CASE |
| O188 · O190 · N-24 | WIDE_TARGET_BIZ |
| CONF-4 · O175 · O51-F · O96 · E-1 · E-4 · DEC42 · 순서9-K | WIDE_BUDGET |
| DEC-31 · O40 · O45 · GATE-D | WIDE_MEMBER_FEE |
| O205 · O206 | WIDE_MEMBER_SERVICE_COHORT |
| O200-D | WIDE_SPNSR_CLS_AGGR |

라이브 실측으로 **stale 주장 삭제** (문안 = 실측 근거):

| 주장 | 실측 | 처리 |
|---|---|---|
| 휴일축 전건 FALSE 미주입(AD·BQ) | PERF_IS_HOLIDAY TRUE 12,254행 · BQ IS_HOLIDAY TRUE 66,725행 | 삭제 |
| BQ `YEAR` 단일값 | YEAR = 2024·2025·2026 | 「연도별 적재 구간이 고르지 않을 수 있다」로 대체 |
| BCASE 캠페인명 전건 센티넬 | WIDE_AD_BROADCAST_CASE 0행(검증 불가) | 삭제 |
| AD CAMPAIGN_SK·AD_CREATIVE_SK 0 | ≠0 행 0 | 유지 |
| BUDGET 부서·캠페인 전건 (미매핑) | distinct 1 = `(미매핑)` | 유지 |
| BQ 세션지표 전건 비어 있음 | non-null 0 · 0 | 유지 |

🟠 WIDE_AD_BROADCAST_CASE 0행 = 라이브 적재 확인 필요(본 단위 범위 밖 · 백로그).

_Co-authored with CoCo_
