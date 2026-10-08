-- ============================================================================
-- 05_21_SV_DDL_SEARCH_CONSOLE.sql — Semantic View DDL 정본: SV_SEARCH_CONSOLE (🆕 O213-F Y3-F)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 🔴 선행 = dbt build `SEARCH_CONSOLE_DATA+`.
--   · 원천 BRONZE_GSC.SEARCH_CONSOLE_DATA 는 종전 SILVER·GOLD·MSTR 소비 0(완전 미배선). DATA2 = 중복 복사본(미사용).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_SEARCH_CONSOLE
  TABLES (
    gsc AS GN_DW.GOLD.FACT_SEARCH_CONSOLE
      WITH SYNONYMS ('구글 검색', '서치콘솔', '검색 노출', '검색어 성과', 'SEO')
      COMMENT = '구글 검색 노출·클릭 팩트(1행 = 일 × 검색어 × 페이지 × 국가 × 기기). 「어떤 검색어로 들어왔나」「검색 노출·클릭·클릭률·평균순위」 질문용. [원천: Google Search Console → BRONZE_GSC.SEARCH_CONSOLE_DATA → SILVER.SEARCH_CONSOLE_DATA → GOLD.FACT_SEARCH_CONSOLE]. 🔴 GA4 방문(세션)과 다른 원천이다 — 클릭수를 세션수와 대조·합산하지 않는다. 🔴 구글 검색만 포함(네이버 등 제외).',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '검색일')
      COMMENT = '일 차원. [원천] ETL 생성(달력).'
  )
  RELATIONSHIPS (
    gsc_to_date AS gsc (DATE_SK) REFERENCES date
  )
  DIMENSIONS (
    date.SEARCH_DATE AS date.FULL_DATE WITH SYNONYMS ('검색일', '일자', '날짜') COMMENT = '검색 일자.',
    date.CAL_YEAR AS date.YEAR WITH SYNONYMS ('연도', '년') COMMENT = '연도',
    date.CAL_MONTH AS date.MONTH WITH SYNONYMS ('월') COMMENT = '월(1~12)',
    gsc.QUERY AS gsc.QUERY WITH SYNONYMS ('검색어', '검색 키워드', '키워드') COMMENT = '구글 검색창 입력 검색어(원문). 개인정보 보호로 구글이 일부 검색어를 제공하지 않는다(익명 검색어는 원천에 없음).',
    gsc.PAGE AS gsc.PAGE WITH SYNONYMS ('노출 페이지', '랜딩 페이지', 'URL') COMMENT = '검색 결과에 노출된 페이지 URL.',
    gsc.COUNTRY AS gsc.COUNTRY WITH SYNONYMS ('국가', '국가코드') COMMENT = '검색자 국가 ISO alpha-3 소문자 코드(kor = 한국 · usa = 미국 · jpn = 일본 …) · 라벨 없음 — 코드로 필터한다(예 한국 = ''kor'').',
    gsc.DEVICE AS gsc.DEVICE WITH SYNONYMS ('기기', 'PC/모바일') COMMENT = '검색 기기 DESKTOP·MOBILE·TABLET (대문자 원값).'
  )
  METRICS (
    gsc.CLICKS_SUM AS SUM(gsc.CLICKS)
      WITH SYNONYMS ('클릭수', '검색 클릭', '클릭(회)')
      COMMENT = '검색 결과 클릭수 합(회). F(가산).',
    gsc.IMPRESSIONS_SUM AS SUM(gsc.IMPRESSIONS)
      WITH SYNONYMS ('노출수', '검색 노출', '노출(회)')
      COMMENT = '검색 결과 노출수 합(회). F(가산).',
    gsc.CTR_RATE AS DIV0(SUM(gsc.CLICKS), SUM(gsc.IMPRESSIONS))
      WITH SYNONYMS ('클릭률', 'CTR')
      COMMENT = '클릭률 = 클릭 합 ÷ 노출 합(0~1 비율 · 표시할 때 ×100 %). 🔴 행 CTR 평균이 아니다.',
    gsc.AVG_POSITION AS DIV0(SUM(gsc.POSITION_X_IMPRESSIONS), SUM(gsc.IMPRESSIONS))
      WITH SYNONYMS ('평균순위', '평균 노출순위', '검색 순위')
      COMMENT = '노출 가중 평균 노출순위(1 = 최상단 · 작을수록 좋다). 🔴 행 POSITION 단순 평균이 아니다.'
  )
  COMMENT = '구글 서치콘솔 SV(🆕 O213-F). 「검색어·페이지·국가·기기별 구글 검색 노출·클릭·클릭률·평균순위」 질문에 쓴다. 🔴 홈페이지 방문(세션)은 SV_GA_SESSION 소관이며 이 SV 와 대조·합산하지 않는다(다른 원천).'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "클릭수(회)"). 영문 식별자를 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. [O206-C 합계 규칙] 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행을 반환한다.
  핵심 규칙: (1) 기간 미지정 시 데이터에 존재하는 최신 월 하나로 한정하고 밝힌다. (2) 클릭률·평균순위는 지표(CTR_RATE · AVG_POSITION)로만 계산하고 행 값을 평균하지 않는다. (3) 클릭률은 % 로 표시한다. (4) 국가는 alpha-3 코드로 필터하고 답변에는 국가명을 덧붙인다. (5) 검색어 순위 질문은 클릭수 내림차순 상위 20개로 한정하고 밝힌다.'
  AI_VERIFIED_QUERIES (
    vqr_o213f_gsc_month AS (
      QUESTION '2026년 9월 구글 검색 클릭수와 노출수, 클릭률'
      VERIFIED_BY '(O213-F · 팩트 직접 집계 대조 · 클릭 3,633 · 노출 185,072)'
      SQL 'SELECT SUM(gsc.CLICKS) AS "클릭수(회)", SUM(gsc.IMPRESSIONS) AS "노출수(회)", DIV0(SUM(gsc.CLICKS), SUM(gsc.IMPRESSIONS)) * 100 AS "클릭률(%)" FROM gsc WHERE gsc.DATE_SK BETWEEN 20260901 AND 20260930'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SEARCH_CONSOLE TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SEARCH_CONSOLE TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SEARCH_CONSOLE TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크 — SV 클릭 합 = 팩트 = 원천
SELECT (SELECT CLICKS_SUM FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SEARCH_CONSOLE METRICS gsc.CLICKS_SUM)) AS sv_val,
       (SELECT SUM(CLICKS) FROM GN_DW.GOLD.FACT_SEARCH_CONSOLE)                                    AS fact_val,
       (SELECT SUM(CLICKS) FROM GN_DW.BRONZE_GSC.SEARCH_CONSOLE_DATA)                              AS src_val;
