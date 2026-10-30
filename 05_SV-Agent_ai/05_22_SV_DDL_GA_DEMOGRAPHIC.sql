-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_GA_DEMOGRAPHIC (🆕 O213-F Y3-F)
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_GA_DEMOGRAPHIC
-- Run order  : 운영계 #39
-- Depends on : GN_DW.GOLD.FACT_GA4_DEMOGRAPHIC, GN_DW.GOLD.DIM_DATE, GN_DW.BRONZE_GA4.GA4_USER_DEMOGRAPHIC
-- Issue      : O213-F
-- =============================================================================
-- ============================================================================
-- 05_22_SV_DDL_GA_DEMOGRAPHIC.sql — Semantic View DDL 정본: SV_GA_DEMOGRAPHIC ( O213-F Y3-F)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · WARN: 선행 = dbt build `GA4_USER_DEMOGRAPHIC+`.
--   · 원천 BRONZE_GA4.GA4_USER_DEMOGRAPHIC(GA4 Data API 일 집계) 는 종전 SILVER·GOLD·MSTR 소비 0(완전 미배선).
--   · WARN: 사용자수(TOTAL_USERS·NEW_USERS)는 API 가 grain 단위로 낸 고유값 — 합산하면 중복 계상 ⇒ 지표로 노출하지 않는다.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_GA_DEMOGRAPHIC
  TABLES (
    demo AS GN_DW.GOLD.FACT_GA4_DEMOGRAPHIC
      WITH SYNONYMS ('방문자 인구통계', '성별 연령 방문', 'GA 인구통계')
      COMMENT = 'GA4 인구통계 일 팩트(1행 = 일 × 기기 × 성별 × 연령대). 「성별·연령대별 홈페이지 방문(세션)」 질문용. [원천: GA4 Data API → BRONZE_GA4.GA4_USER_DEMOGRAPHIC → SILVER.GA4_USER_DEMOGRAPHIC → GOLD.FACT_GA4_DEMOGRAPHIC]. 🔴 GA4 가 구글 신호로 **추정한** 성별·연령이다(CRM 회원 성별·나이 아님). 🔴 SV_GA_SESSION(BigQuery 이벤트 원천)과 세션수 정의·모수가 달라 대조·합산하지 않는다.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜')
      COMMENT = '일 차원. [원천] ETL 생성(달력).'
  )
  RELATIONSHIPS (
    demo_to_date AS demo (DATE_SK) REFERENCES date
  )
  DIMENSIONS (
    date.VISIT_DATE AS date.FULL_DATE WITH SYNONYMS ('방문일', '일자', '날짜') COMMENT = '집계 일자.',
    date.CAL_YEAR AS date.YEAR WITH SYNONYMS ('연도', '년') COMMENT = '연도',
    date.CAL_MONTH AS date.MONTH WITH SYNONYMS ('월') COMMENT = '월(1~12)',
    demo.DEVICE_CATEGORY AS demo.DEVICE_CATEGORY WITH SYNONYMS ('기기', 'PC/모바일') COMMENT = '기기 desktop·mobile·tablet. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''desktop''·''mobile''·''tablet''',
    demo.USER_GENDER AS demo.USER_GENDER WITH SYNONYMS ('성별', '방문자 성별') COMMENT = '방문자 성별 female(여성)·male(남성)·unknown(GA4 추정 불가). 🔴 unknown 은 결측이 아니라 추정 불가 버킷 — 별도 행으로 밝힌다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''female''·''male''·''unknown''',
    demo.USER_AGE_BRACKET AS demo.USER_AGE_BRACKET WITH SYNONYMS ('연령대', '나이대', '방문자 연령') COMMENT = '방문자 연령대 18-24·25-34·35-44·45-54·55-64·65+·unknown(추정 불가). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''18-24''·''25-34''·''35-44''·''45-54''·''55-64''·''65+''·''unknown'''
  )
  METRICS (
    demo.SESSIONS_SUM AS SUM(demo.SESSIONS)
      WITH SYNONYMS ('세션수', '방문수', '세션(회)')
      COMMENT = 'GA4 Data API 세션수 합(회). F(가산).'
  )
  COMMENT = 'GA4 인구통계 SV. 「성별·연령대·기기별 홈페이지 방문(세션)과 그 비중」 질문에 쓴다. 🔴 GA4 추정 인구통계 — CRM 회원 성별·연령 질문은 회원 SV 소관. 🔴 사용자수는 비가산이라 제공하지 않는다(방문자수 질문은 SV_GA_SESSION 으로 안내하되 성별·연령 축은 없다고 밝힌다).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다. [공통 규칙 보충 · 이 SV] 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "세션수(회)"). 영문 식별자를 출력 컬럼명으로 남기지 않는다. 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만).
  핵심 규칙: (1) 기간 미지정 시 데이터에 존재하는 최신 월 하나로 한정하고 밝힌다. (2) 성별 값은 여성·남성·추정불가로 한글 표기한다. (3) unknown 은 제외하지 말고 「추정 불가」로 함께 보여 준다. (4) 비중(%)은 같은 기간 세션 합 대비로 SQL 에서 계산한다.'
  AI_VERIFIED_QUERIES (
    vqr_o213f_gender AS (
      QUESTION '2026년 9월 성별 홈페이지 세션수'
      VERIFIED_BY '(O213-F · 팩트 직접 집계 대조 · unknown 998,835 · female 326,502 · male 141,904)'
      SQL 'SELECT demo.USER_GENDER AS "성별", SUM(demo.SESSIONS) AS "세션수(회)" FROM demo WHERE demo.DATE_SK BETWEEN 20260901 AND 20260930 GROUP BY demo.USER_GENDER ORDER BY 2 DESC'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_DEMOGRAPHIC TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_DEMOGRAPHIC TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_DEMOGRAPHIC TO ROLE GN_DW_AR_SRC_COMMON;  -- O270 원천별 접근 역할
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_DEMOGRAPHIC TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크 — SV 세션 합 = 팩트 = 원천
SELECT (SELECT SESSIONS_SUM FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_GA_DEMOGRAPHIC METRICS demo.SESSIONS_SUM)) AS sv_val,
       (SELECT SUM(SESSIONS) FROM GN_DW.GOLD.FACT_GA4_DEMOGRAPHIC)                                         AS fact_val,
       (SELECT SUM(TRY_TO_NUMBER(SESSIONS)) FROM GN_DW.BRONZE_GA4.GA4_USER_DEMOGRAPHIC)                    AS src_val;
