-- GN_DW 3단계: Semantic View DDL 정본 — SV_BUDGET (예산)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O37 분할]
--   대상 SV = **SV_BUDGET**. 이 파일 하나로 **독립 실행**된다
--   (역할·웨어하우스·스키마 설정 + SV 정의 + GRANT + 스모크가 모두 들어 있다).
--   🔴 다른 `05_*_SV_DDL_*.sql` 과 **실행 순서 의존이 없다** — 필요한 파일만 단독 실행한다.
--   최초 세팅과 변경 반영이 같은 파일이다(통째로 재실행 · 별도 update 스크립트 없음).
--   `CREATE OR REPLACE` 가 GRANT 를 파괴하지만 GRANT 절이 같은 파일에 있어 자기완결적이다.
--
--   ⚠️ 종전에는 SV 6종이 단일 파일 `05_SV_DDL.sql(현 `_archive/05_SV_DDL_ORIGINAL_BACKUP_20260805.sql`)`(708행)에 있었다. SV 하나를 고칠 때마다
--      파일 전체를 재작성해야 해서 **손대지 않은 SV 의 COMMENT 를 훼손할 경로**였고
--      (O27→O30 · P58 과 같은 유형), 신규 SV 추가도 기존 파일 편집을 강제했다. → SV 단위로 분할.
--      `05_0_SV_DDL.sql` 은 **인덱스 + 전체 배포 검증**으로 전환됐다(SV 정의는 더 이상 없다).
--
-- ▶ 선행 조건 (이것만 만족하면 언제든 실행 가능)
--   ① GOLD 적재 완료(`dbt build`) — 이 SV 의 논리테이블 원천
--   ② **`02_GN_DW_building/08_After_Deploy_DBT.sql` §G** — SERVING helper 뷰
--      (`DIM_MONTH`·`DIM_MEMBER_CURRENT`). 이 파일이 논리테이블로 참조하므로 필수 선행.
--      ⚠ `02_SERVING_setup.sql`·`07_ENVIRONMENT_RBAC_setup.sql` 이 아니다(O36 실측 교정).
--   ⚠ 반드시 `GN_DW_ADMIN` 역할로 실행한다. ACCOUNTADMIN 으로 만들면 소유권이 어긋나 이후
--     재배포가 권한 오류로 막힌다(복구 SQL = `05_0_SV_DDL.sql` 전체검증 §8-11 주석).
--
-- ▶ 정본 근거 (수치·이력·판정 경위는 이 파일에 두지 않는다)
--   `04_SV_설계.md` §0.1 helper뷰 · §0.3 가산성 · §1~6 SV구조 · **§6.9 구조적 제약**
--   `03_SV_metric_배속.md` 지표별 분자/분모 직역 · **§8.5 미해결 + §8.5.1 근거 쿼리**
--   `01_SV-Agent 작업계획.md` §3 3단계 · 원칙10(fan-out) · R1·R5 가산성 · 원칙6 한글 synonyms
--   `05_0_SV_DDL.sql` 분할 인덱스 · 전체 배포 검증 · 공통 규약 전문
--
-- ▶ 가드레일 요약 (전문 = `05_0_SV_DDL.sql` §공통규약)
--   R1 fan-out : 월팩트→`SERVING.DIM_MONTH` · 회원속성→`SERVING.DIM_MEMBER_CURRENT` ·
--                광고팩트→`SERVING.FACT_AD_COMBINED`. raw `DIM_DATE`/`DIM_MEMBER` 직접조인 금지.
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
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET
  TABLES (
    fbd AS GN_DW.GOLD.FACT_BUDGET
      PRIMARY KEY (MONTH_KEY, BUDGET_ITEM_SK)
      WITH SYNONYMS ('예산', '예산 집행')
      COMMENT = '예산 팩트(grain=월×세세목, 실측 유일 → PK). 편성/집행. ⚠편성·집행 금액에 음수(조정/환입)가 존재한다. [원천] 시스템=ERP(예산관리, Snowflake 파일 업로드 적재) · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(예산·실적 원장): 편성 YEAR_BDGT_AMT_n · 집행 EXEC_AMT_n — 12개월 wide 컬럼을 월 long으로 언피벗 · SILVER=ERP_BUDGET.',
    month AS GN_DW.SERVING.DIM_MONTH
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
    item.BUDGET_CATEGORY  AS item.BUDGET_CATEGORY  WITH SYNONYMS ('예산구분', '예산카테고리') COMMENT = '예산 구분'
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
      🔴 `CREATE OR REPLACE` 는 기존 GRANT 를 전부 삭제한다(OWNERSHIP 만 잔존) →
         이 파일을 재실행할 때 **아래 GRANT 를 반드시 함께 실행**한다.
         분할의 이점: GRANT 가 대상 SV 와 같은 파일에 있어 빠뜨릴 수 없다.
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET TO ROLE GN_DW_SERVICE;
