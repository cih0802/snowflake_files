-- GN_DW 3단계: Semantic View DDL 정본 — SV_BUDGET (예산)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O37 분할]
--   대상 SV = **SV_BUDGET** — 이 파일 하나로 **독립 실행**된다(상세 = 아래 포인터).
--
-- 🔴🔴 **[2026-08-29 O118] 이 SV 는 「보류」다 — metric 을 확정하지 말고 아래를 먼저 읽어라.**
--   🟢 정본 = `04_SV_설계.md` **§0.9-D·§0.9-E** · `20_issue/30_설계_의사결정.md` **§30-G**(`DEC-44`).
--
--   ▶ 무엇이 문제인가 (실측)
--     `TOTAL_EXEC_BUDGET = SUM(fbd.EXEC_BUDGET_ERP)` 가 **예산 편성 차수를 이중계상**한다.
--     원천 `BRONZE_ERP.BDGT_ACMSLT_LEDGER` 는 같은 세세목·연도에 `BDGT_PRCD_NM` 이
--     '연사업'·'추가경정' 두 행으로 들어오고, **집행액(EXEC)이 두 행에서 완전히 동일**하다
--     (항목×연도 24키 중 **상이 0 / 동일 23**) ⇒ 합산하면 그 연도 집행이 **두 배**가 된다.
--     보정 = 전 차수 합산 → **최신 차수만**. 과대율 **+79.70%**(O115 기재와 완전 일치 = 재현 확인).
--     🔴 편성(PLAN)은 다르다 — 차수 간 **상이 17 / 24** 이므로 「어느 차수의 편성인가」가 실질 정보다.
--
--   ▶ 🔴 종전 차단조항이 **지목한 객체가 틀렸다**
--     인수인계는 "`FACT_BUDGET_YEARLY` 에 붙이지 마라"였고 이 파일의 base 는 `FACT_BUDGET`(월)이다
--     ⇒ 문자적으로는 준수했다. 그러나 **두 팩트의 집행액 합이 완전히 동일**(차이 0)하므로
--     **결함은 그대로 상속됐다.** 🟢 판정식 = **차단조항이 객체명으로 쓰여 있으면 그 결함값이
--     다른 객체에도 있는지 대조하라.** 「그 테이블을 안 썼다」 ≠ 「그 결함을 피했다」.
--
--   ▶ 🔴 그래서 무엇을 하지 않았는가 (결정 선점 금지)
--     `DROP` · metric 삭제 · `where` 축소 · 차수 필터 추가를 **하지 않았다.** 남은 것은 정책 판단이다
--     (§30-G ㉠ 「최신 차수」의 정의 · ㉡ 편성 차수를 차원으로 노출할 것인가) ⇒ **회신 후 배선**한다.
--   ▶ 🔴 그때까지의 사용 규칙: `TOTAL_EXEC_BUDGET`·`EXEC_RATE` 를 **확정 수치로 인용·발행하지 마라.**
--     편성(`TOTAL_PLAN_BUDGET`)만 쓰거나, 차수를 명시한 임시 쿼리로 답한다.
--
--   🔴 **파일 규약·선행 조건·정본 근거의 정본 = `05_0_SV_DDL.sql` §공통 규약** (2026-08-10 O55 DUP-1).
--      독립 실행 · 파일 간 순서 무관 · 재실행 반영 · `CREATE OR ALTER`(GRANT·소유권 보존) ·
--      분할 이력(O37) · 선행 조건은 `dbt build` **하나** · 실행 역할 `GN_DW_ADMIN`.
--      ⛔ 이 항목들을 이 파일에 다시 복제하지 말 것 — 그것이 P140(9중 중복)의 원인이었다.
--
-- ▶ 가드레일 요약 (전문 = `05_0_SV_DDL.sql` §공통규약)
--   R1 fan-out : 월팩트→`GOLD.DIM_MONTH` · 회원속성→`GOLD.DIM_MEMBER_CURRENT` ·
--                광고팩트→`GOLD.WIDE_AD_COMBINED`. raw `DIM_DATE`/`DIM_MEMBER` 직접조인 금지.
--                🔴 [2026-08-10 O54·O55] SERVING helper 3종 → GOLD 재배선 완료 후 **물리 DROP 완료**(DEC-34 §0.8-D).
--   R5 가산성  : F(flow)=SUM / D=COUNT(DISTINCT MEMBER_DK) / 비율=분자·분모 각각 집계 후 division.
--   조인키 타입: `MEMBER_DK`=VARCHAR(캐스팅 금지) · `MONTH_KEY`/`DATE_SK`/`*_SK`=NUMBER.
--   PRIMARY KEY: 실측 유일한 것만 선언. 비유일 grain 은 PK 미선언.
--   비활성 지표: 원천 미적재분은 SV 에서 아예 제외한다(빈 metric 이 0/NULL 을 사실처럼 반환).
--   COMMENT 규약: 🔴 **수치를 넣지 않는다**(Agent 가 COMMENT 를 근거로 인용 → 적재량 변하면 거짓이 된다) ·
--                `[원천]` 절은 테이블·컬럼 이름만 · 저카디널리티 코드 차원은 **실제 코드값을 열거**.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

/* =====================================================================================
   5. SV_BUDGET (overall Agent) — base FBD(월×조직×세세목)
      활성: 편성예산(월)·집행예산(ERP)·집행율 · 세세목명/예산구분
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET
  TABLES (
    fbd AS GN_DW.GOLD.FACT_BUDGET
      PRIMARY KEY (MONTH_KEY, BUDGET_ITEM_SK)
      WITH SYNONYMS ('예산', '예산 집행')
      COMMENT = '예산 팩트(grain=월×세세목, 실측 유일 → PK). 편성/집행. ⚠편성·집행 금액에 음수(조정/환입)가 존재한다. [원천] 시스템=ERP(예산관리, Snowflake 파일 업로드 적재) · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(예산·실적 원장): 편성 YEAR_BDGT_AMT_n · 집행 EXEC_AMT_n — 12개월 wide 컬럼을 월 long으로 언피벗 · SILVER=ERP_BUDGET.',
    month AS GN_DW.GOLD.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '예산월')
      COMMENT = '월 차원. fan-out 차단용 helper 뷰. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    item AS GN_DW.GOLD.DIM_BUDGET_ITEM
      PRIMARY KEY (BUDGET_ITEM_SK)
      WITH SYNONYMS ('세세목', '예산항목')
      COMMENT = '예산 세세목 차원. [원천] 시스템=ERP · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(JANG_NM~SUBDTL_ITEM_NM 장·관·항·목·세목·세세목 계층 + BDGT_UNIT_NM 예산단위) — DISTINCT 마스터화·MD5 대리키 · SILVER=ERP_BUDGET_ITEM.'
  )
  RELATIONSHIPS (
    fbd_to_month AS fbd (MONTH_KEY)      REFERENCES month,
    fbd_to_item  AS fbd (BUDGET_ITEM_SK) REFERENCES item
  )
  DIMENSIONS (
    month.MONTH_KEY  AS month.MONTH_KEY WITH SYNONYMS ('예산연월', '연월') COMMENT = 'YYYYMM 정수',
    month.CAL_YEAR   AS month.YEAR      WITH SYNONYMS ('연도', '년')      COMMENT = '연도',
    month.CAL_MONTH  AS month.MONTH     WITH SYNONYMS ('월')             COMMENT = '월(1~12)',
    item.BUDGET_ITEM_NAME AS item.BUDGET_ITEM_NAME WITH SYNONYMS ('세세목명', '예산항목명') COMMENT = '예산 세세목명',
    item.BUDGET_CATEGORY  AS item.BUDGET_CATEGORY  WITH SYNONYMS ('예산구분', '예산카테고리') COMMENT = '예산 구분. 실제값 2종: ''수입''·''지출'' + NULL'
  )
  METRICS (
    fbd.TOTAL_PLAN_BUDGET AS SUM(fbd.PLAN_BUDGET_MONTH)
      WITH SYNONYMS ('편성예산', '월 편성예산', '예산 편성액') COMMENT = '월 편성예산 합계(원). F(가산).',
    fbd.TOTAL_EXEC_BUDGET AS SUM(fbd.EXEC_BUDGET_ERP)
      WITH SYNONYMS ('집행예산', 'ERP 집행액', '예산 집행액') COMMENT = 'ERP 집행예산 합계(원). F(가산).',
    fbd.EXEC_RATE AS SUM(fbd.EXEC_BUDGET_ERP) / NULLIF(SUM(fbd.PLAN_BUDGET_MONTH), 0) * 100
      WITH SYNONYMS ('집행율', '예산 집행율') COMMENT = '집행율(%) = 집행예산 ÷ 편성예산 ×100. 비율(N). ⚠편성은 12개월 전량이지만 집행은 적재된 월까지만 존재하므로, 집행 미적재 월을 분모에 넣으면 집행율이 구조적으로 낮게 나온다 — 스코프 정합 규칙은 AI_SQL_GENERATION 참조.'
  )
  COMMENT = 'Phase-1 예산 SV(base FBD). [원천 요약] 원천시스템=ERP(예산관리 · Snowflake 파일 업로드로 bronze 적재) · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(편성 YEAR_BDGT_AMT_n·집행 EXEC_AMT_n 월 언피벗, 세세목 JANG_NM~SUBDTL_ITEM_NM) → SILVER(ERP_BUDGET+ERP_BUDGET_ITEM) → GOLD(FBD). ⚠광고비는 이 SV의 원천(ERP)에 없다 — 광고비는 AGENCY 원천의 SV_AD 소관(예산 원장에 광고비 컬럼 부재, E-4). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 편성예산(월)·집행예산(ERP)·집행율, 세세목/예산구분/월별. 비활성(적재 대기): 연 편성예산, 집행추정/모금성비용/광고비, 조직/캠페인별, 개발단가·ROI(신9~11).'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(세세목·예산구분 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 월별 행 + 전체 총계(합계·집행율) 행을 함께 반환해 편성예산·집행예산·집행율을 월별로 보여준다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다. ⚠집행율 산정 주의: 편성예산은 12개월 전량 적재돼 있으나 집행예산(EXEC_BUDGET_ERP)은 적재가 진행된 월까지만 값이 있고 나머지 월은 0이다. 집행율을 연 합계(전체 편성 ÷ 일부 집행)로 내면 분모가 과대해 집행율이 구조적으로 낮게 나온다. 이를 방지하기 위해 — (A) 집행율은 집행 데이터가 있는 월만 편성 분모에 포함한다: 분모 SUM(CASE WHEN EXEC_BUDGET_ERP<>0 THEN PLAN_BUDGET_MONTH END), 분자 SUM(CASE WHEN EXEC_BUDGET_ERP<>0 THEN EXEC_BUDGET_ERP END). (B) 집행 미적재 월은 "집행 미반영"으로 표기하고 편성만 보여준다. (C) 답변에 집행이 적재된 기간 범위와 그 이후는 미반영임을 반드시 명시한다 — 기간은 하드코딩하지 말고 데이터에서 EXEC_BUDGET_ERP<>0 인 최소·최대 연월을 조회해 쓴다. (D) 월별 ROLLUP 총계도 (A) 스코프로 산정한다.';


/* =====================================================================================
   GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST 가 VIEWER 를 상속하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🟢 [2026-08-10 O54] 본문이 `CREATE OR ALTER` 이므로 **기존 GRANT 는 보존**된다 →
         아래 GRANT 는 멱등 재확인이다. 🔴 판정은 소유자 세션이 아니라 **소비 역할 세션**으로
         한다(P126) — 검사기 = `scripts/sv_unit_gate.py`.
         분할의 이점: GRANT 가 대상 SV 와 같은 파일에 있어 빠뜨릴 수 없다.
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET TO ROLE GN_DW_SERVICE;
