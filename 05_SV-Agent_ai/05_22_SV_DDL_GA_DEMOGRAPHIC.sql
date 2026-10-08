-- ============================================================================
-- 05_22_SV_DDL_GA_DEMOGRAPHIC.sql — Semantic View DDL 정본: SV_GA_DEMOGRAPHIC (🆕 O213-F Y3-F)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 🔴 선행 = dbt build `GA4_USER_DEMOGRAPHIC+`.
--   · 원천 BRONZE_GA4.GA4_USER_DEMOGRAPHIC(GA4 Data API 일 집계) 는 종전 SILVER·GOLD·MSTR 소비 0(완전 미배선).
--   · 🔴 사용자수(TOTAL_USERS·NEW_USERS)는 API 가 grain 단위로 낸 고유값 — 합산하면 중복 계상 ⇒ 지표로 노출하지 않는다.
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
    demo.DEVICE_CATEGORY AS demo.DEVICE_CATEGORY WITH SYNONYMS ('기기', 'PC/모바일') COMMENT = '기기 desktop·mobile·tablet.',
    demo.USER_GENDER AS demo.USER_GENDER WITH SYNONYMS ('성별', '방문자 성별') COMMENT = '방문자 성별 female(여성)·male(남성)·unknown(GA4 추정 불가). 🔴 unknown 은 결측이 아니라 추정 불가 버킷 — 별도 행으로 밝힌다.',
    demo.USER_AGE_BRACKET AS demo.USER_AGE_BRACKET WITH SYNONYMS ('연령대', '나이대', '방문자 연령') COMMENT = '방문자 연령대 18-24·25-34·35-44·45-54·55-64·65+·unknown(추정 불가).'
  )
  METRICS (
    demo.SESSIONS_SUM AS SUM(demo.SESSIONS)
      WITH SYNONYMS ('세션수', '방문수', '세션(회)')
      COMMENT = 'GA4 Data API 세션수 합(회). F(가산).'
  )
  COMMENT = 'GA4 인구통계 SV(🆕 O213-F). 「성별·연령대·기기별 홈페이지 방문(세션)과 그 비중」 질문에 쓴다. 🔴 GA4 추정 인구통계 — CRM 회원 성별·연령 질문은 회원 SV 소관. 🔴 사용자수는 비가산이라 제공하지 않는다(방문자수 질문은 SV_GA_SESSION 으로 안내하되 성별·연령 축은 없다고 밝힌다).'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "세션수(회)"). 영문 식별자를 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. [O206-C 합계 규칙] 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행을 반환한다.
  핵심 규칙: (1) 기간 미지정 시 데이터에 존재하는 최신 월 하나로 한정하고 밝힌다. (2) 성별 값은 여성·남성·추정불가로 한글 표기한다. (3) unknown 은 제외하지 말고 「추정 불가」로 함께 보여 준다. (4) 비중(%)은 같은 기간 세션 합 대비로 SQL 에서 계산한다.'
  AI_VERIFIED_QUERIES (
    vqr_o213f_gender AS (
      QUESTION '2026년 9월 성별 홈페이지 세션수'
      VERIFIED_BY '(O213-F · 팩트 직접 집계 대조 · unknown 998,835 · female 326,502 · male 141,904)'
      SQL 'SELECT demo.USER_GENDER AS "성별", SUM(demo.SESSIONS) AS "세션수(회)" FROM demo WHERE demo.DATE_SK BETWEEN 20260901 AND 20260930 GROUP BY ROLLUP(demo.USER_GENDER) ORDER BY 2 DESC'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_DEMOGRAPHIC TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_DEMOGRAPHIC TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_DEMOGRAPHIC TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크 — SV 세션 합 = 팩트 = 원천
SELECT (SELECT SESSIONS_SUM FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_GA_DEMOGRAPHIC METRICS demo.SESSIONS_SUM)) AS sv_val,
       (SELECT SUM(SESSIONS) FROM GN_DW.GOLD.FACT_GA4_DEMOGRAPHIC)                                         AS fact_val,
       (SELECT SUM(TRY_TO_NUMBER(SESSIONS)) FROM GN_DW.BRONZE_GA4.GA4_USER_DEMOGRAPHIC)                    AS src_val;
