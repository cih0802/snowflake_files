-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_EXPENSE_RESOLUTION ( O213-F Y3-K)
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_EXPENSE_RESOLUTION
-- Run order  : 운영계 #40
-- Depends on : GN_DW.GOLD.FACT_EXPENSE_RESOLUTION, GN_DW.GOLD.DIM_DATE, GN_DW.GOLD.DIM_MARKETING_CAMPAIGN, GN_DW.BRONZE_ERP.EXPENSE_RESOLUTION
-- Issue      : O213-F, O51-F, O114-B, O225-B
-- =============================================================================
-- ============================================================================
-- 05_23_SV_DDL_EXPENSE_RESOLUTION.sql — Semantic View DDL 정본: SV_EXPENSE_RESOLUTION ( O213-F Y3-K)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · WARN: 선행 = dbt build `ERP_EXPENSE_RESOLUTION+`.
--   · 왜 신설했나 — 「부서별 지출(집행)」을 물을 곳이 없었다. 예산 SV(SV_BUDGET)의 부서 축은 전건 센티넬(O51-F)이고
--     결의부서를 가진 원천 BRONZE_ERP.EXPENSE_RESOLUTION 은 소비 모델 0 이었다(O114-B 선언만).
--   · WARN: SV_BUDGET·SV_BUDGET_YEARLY 와 금액을 대조·합산하지 않는다 — 과목키 일치 0.02% · 금액 규모 약 9.9배(원천·범위 상이).
--   · WARN: 원천 전 컬럼 동일 행 7,287 을 보존했다(반복 명세인지 적재 중복인지 미판별 · 문서20 N-29 ⑧).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_EXPENSE_RESOLUTION
  TABLES (
    exp AS GN_DW.GOLD.FACT_EXPENSE_RESOLUTION
      WITH SYNONYMS ('지출결의', '지출 결의', '부서별 지출', '집행 내역', '지출 내역')
      COMMENT = '지출결의 팩트(원천 명세 1행 = 1행). 「부서별·목/세목/세세목별·재원별 지출 금액」 질문용. [원천: ERP → BRONZE_ERP.EXPENSE_RESOLUTION → SILVER.ERP_EXPENSE_RESOLUTION → GOLD.FACT_EXPENSE_RESOLUTION]. 🔴 예산(편성·집행 원장 SV_BUDGET)과 다른 원천이라 금액을 서로 대조·합산하지 않는다.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '결의일')
      COMMENT = '일 차원. [원천] ETL 생성(달력).',
    --  [2026-10-14 O225-B] 세부캠페인코드(콘텐츠구분자) → 마케팅캠페인 축
    mkc AS GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
      PRIMARY KEY (MKTG_CAMPAIGN_SK)
      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인')
      COMMENT = '마케팅캠페인 conformed 차원. SK=0 = (미매핑) — 지출결의에 세부캠페인코드 미기재·CRM 미등록.'
  )
  RELATIONSHIPS (
    exp_to_date AS exp (DATE_SK) REFERENCES date,
    exp_to_mkc AS exp (MKTG_CAMPAIGN_SK) REFERENCES mkc
  )
  DIMENSIONS (
    date.RESOLUTION_DATE AS date.FULL_DATE WITH SYNONYMS ('결의일', '작성일', '일자') COMMENT = '지출결의 작성일.',
    date.CAL_YEAR AS date.YEAR WITH SYNONYMS ('연도', '년') COMMENT = '연도(작성일 기준).',
    date.CAL_MONTH AS date.MONTH WITH SYNONYMS ('월') COMMENT = '월(1~12 · 작성일 기준).',
    exp.RESOLUTION_YEAR AS exp.RESOLUTION_YEAR WITH SYNONYMS ('회계연도') COMMENT = '회계연도(원천 YEAR). 작성일 연도와 다를 수 있다.',
    exp.RESOLUTION_DEPT_NM AS exp.RESOLUTION_DEPT_NM WITH SYNONYMS ('결의부서', '부서', '지출 부서') COMMENT = '결의부서명(원값). 「부서별 지출」의 1순위 축.',
    exp.SOURCE_DIV_NM AS exp.SOURCE_DIV_NM WITH SYNONYMS ('출처구분') COMMENT = '출처구분명(원값). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''가지급금정산서''·''구매품의''·''기안서''·''대체결의''·''외화출장품의서''·''품의서''',
    exp.BDGT_UNIT_NM AS exp.BDGT_UNIT_NM WITH SYNONYMS ('예산단위') COMMENT = '예산단위명(원값).',
    exp.MOK_NM AS exp.MOK_NM WITH SYNONYMS ('목', '예산 목') COMMENT = '예산 과목 목(원값). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''가지급금''·''권리옹호사업''·''기관홍보사업''·''미디어모금''·''사업비''·''사회복지법인예산''·''아동발달지원사업''·''온라인모금''·''위기가정지원사업''·''인식개선사업''·''지역사회조직사업''·''프로젝트사업''',
    exp.BDGT_ITEM_NM AS exp.BDGT_ITEM_NM WITH SYNONYMS ('예산항목', '예산항목명') COMMENT = '지출결의 예산항목명(원값 · 목·세목·세세목과 다른 축 · 미기재 NULL · O262-B).',
    exp.DTL_ITEM_NM AS exp.DTL_ITEM_NM WITH SYNONYMS ('세목') COMMENT = '예산 과목 세목(원값). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''가지급금''·''사업비''·''사회복지법인예산''·''옹호사업''',
    exp.SUBDTL_ITEM_NM AS exp.SUBDTL_ITEM_NM WITH SYNONYMS ('세세목', '지출 항목') COMMENT = '예산 과목 세세목(원값).',
    exp.FUND_SOURCE_NM AS exp.FUND_SOURCE_NM WITH SYNONYMS ('재원', '재원명') COMMENT = '재원명(원값).',
    exp.EXPS_RESOLUTION_NM AS exp.EXPS_RESOLUTION_NM WITH SYNONYMS ('지출결의명', '결의 제목') COMMENT = '지출결의명(자유문 · 부분일치 검색용).',
    exp.RESOLUTION_NO AS exp.RESOLUTION_NO WITH SYNONYMS ('결의번호') COMMENT = '결의번호 — 1결의가 여러 명세행이다.',
    exp.CONTENTS_DELIMITER AS exp.CONTENTS_DELIMITER WITH SYNONYMS ('세부캠페인코드', '콘텐츠구분자', '세부캠페인') COMMENT = '콘텐츠구분자 = 세부캠페인코드(CRM 캠페인코드 원값). NULL·「-」 = 미기재.',
    mkc.MKTG_CAMPAIGN_NAME AS mkc.MKTG_CAMPAIGN_NAME WITH SYNONYMS ('마케팅캠페인명', '마케팅캠페인', '캠페인명') COMMENT = '세부캠페인코드로 연결한 마케팅캠페인명. (미매핑) = 코드 미기재·미등록 지출.'
  )
  METRICS (
    exp.SUM_AMT_TOTAL AS SUM(exp.SUM_AMT)
      WITH SYNONYMS ('지출액', '지출 금액', '집행액', '지출액(원)')
      COMMENT = '지출 금액 합(원). F(가산).',
    exp.RESOLUTION_CNT AS COUNT(DISTINCT exp.RESOLUTION_NO)
      WITH SYNONYMS ('결의 건수', '지출결의 건수', '결의(건)')
      COMMENT = '고유 결의번호 수(건). 🔴 비가산 — 부서 합과 전체 값이 다를 수 있다.'
  )
  COMMENT = '지출결의 SV. 「부서·과목(목/세목/세세목)·재원·출처구분별 지출 금액과 결의 건수」 질문에 쓴다. 🔴 예산 편성·집행 원장(SV_BUDGET·SV_BUDGET_YEARLY)과 다른 원천이다 — 「예산 대비 지출」을 이 SV 와 예산 SV 를 섞어 계산하지 말고 두 값을 따로 밝힌다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다. [공통 규칙 보충 · 이 SV] 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "지출액(원)"). 영문 식별자를 출력 컬럼명으로 남기지 않는다. 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만).
  핵심 규칙: (1) 기간 미지정 시 데이터에 존재하는 최신 연도 하나로 한정하고 밝힌다(작성일 기준). (2) 부서별 질문은 RESOLUTION_DEPT_NM 으로 묶고 상위 20개로 한정해 밝힌다. (3) 예산 대비 비율을 요구받으면 이 SV 로 계산하지 말고 원천이 다르다고 밝힌다. (4) 결의 건수는 COUNT DISTINCT 이므로 부서별 합이 전체와 다를 수 있다. (5) [O225-B] 마케팅캠페인별·세부캠페인별 지출(제작비)은 MKTG_CAMPAIGN_NAME·CONTENTS_DELIMITER 로 묶는다 — 세부캠페인코드가 기재된 지출만 연결되므로 결과에 「(미매핑)」 금액(코드 미기재분)을 그룹 행으로 함께 반드시 표시하고 「세부캠페인코드 기재분만 집계」라고 밝힌다. 광고비와 합쳐 CAC 를 낼 때도 이 한계를 함께 적는다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EXPENSE_RESOLUTION TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EXPENSE_RESOLUTION TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EXPENSE_RESOLUTION TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크 — SV 지출액 합 = 팩트 = 원천(212,342,534,942원 · 2026-10-08)
SELECT (SELECT SUM_AMT_TOTAL FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_EXPENSE_RESOLUTION METRICS exp.SUM_AMT_TOTAL)) AS sv_val,
       (SELECT SUM(SUM_AMT) FROM GN_DW.GOLD.FACT_EXPENSE_RESOLUTION)                                        AS fact_val,
       (SELECT SUM(SUM_AMT) FROM GN_DW.BRONZE_ERP.EXPENSE_RESOLUTION)                                       AS src_val;
