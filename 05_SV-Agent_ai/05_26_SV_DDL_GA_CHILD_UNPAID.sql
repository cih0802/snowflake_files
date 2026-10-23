-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_GA_CHILD_UNPAID (🆕 O239 · G1 잔여 2건)
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_GA_CHILD_UNPAID
-- Run order  : 운영계 #43
-- Depends on : GN_DW.GOLD.FACT_GA_CHILD_VIEW, GN_DW.GOLD.DIM_DATE, GN_DW.GOLD.FACT_UNPAID_SERVICE_CONV
-- Issue      : O239
-- =============================================================================
-- ============================================================================
-- 05_26_SV_DDL_GA_CHILD_UNPAID.sql — Semantic View DDL 정본: SV_GA_CHILD_UNPAID ( O239 · G1 잔여 2건)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 대상 = 공#122 결연아동코드 · 공#81 미납서비스 전환율 — WARN: 추천안 A/B 를 둘 다 metric 으로 싣는다
--     (사용자 결정 2026-10-16 = 구현 후 Agent 실사용으로 현업이 하나를 고른다 · 고르면 다른 안 metric 을 걷어낸다).
--   · 선행 = GN_DW.GOLD.FACT_GA_CHILD_VIEW · FACT_UNPAID_SERVICE_CONV(03_top-down_gold/06_DDL.sql · dbt build).
--   · 두 팩트는 서로 결합하지 않는다(관계 없음) — 질문마다 한 팩트만 쓴다.
--   · 공통 규약 = 05_0_SV_DDL.sql
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_GA_CHILD_UNPAID
  TABLES (
    gcv AS GN_DW.GOLD.FACT_GA_CHILD_VIEW
      WITH SYNONYMS ('결연아동 페이지 조회', '결연아동코드', '아동 페이지')
      COMMENT = 'GA 결연아동 관련 페이지(URL 에 childnum= 포함) 조회 팩트. [Grain: 일 × 페이지 × 결연아동코드 × URL 회원번호]. 결연아동코드 = URL childnum= 뒤 값(지표사전 공#122). 🔴 추천안 2개(잠정) = A 형식 기준(IS_FORMAT_VALID) · B CRM 아동번호 대조(IS_CRM_MATCHED). [원천: GA4 → SILVER.BIGQUERY_EVENT · CRM → SILVER.CRM_CHILD → GOLD.FACT_GA_CHILD_VIEW].',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '방문일')
      COMMENT = '일 차원. [원천] ETL 생성(달력).',
    usc AS GN_DW.GOLD.FACT_UNPAID_SERVICE_CONV
      WITH SYNONYMS ('미납서비스', '미납 안내', '미납서비스 전환')
      COMMENT = '미납서비스 클릭회원 × 이후 납입 전환 팩트. [Grain: 클릭월 × 회원 × 서비스범위]. 클릭회원 = GA URL memnum(발송 링크로 들어온 회원). 🔴 추천안 2개(잠정) = A(미납 안내 페이지만 · 미납분 납입) · B(미납 안내 + 결제정보 변경 페이지 · 모든 납입) — B 는 A 를 포함하므로 범위를 섞지 않는다. [원천: GA4 → SILVER.BIGQUERY_EVENT · CRM → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_UNPAID_SERVICE_CONV].'
  )
  RELATIONSHIPS (
    gcv_to_date AS gcv (DATE_SK) REFERENCES date
  )
  DIMENSIONS (
    date.VISIT_DATE AS date.FULL_DATE WITH SYNONYMS ('방문일', '일자') COMMENT = '결연아동 페이지 방문일',
    date.YEAR  AS date.YEAR  WITH SYNONYMS ('연도', '년') COMMENT = '방문 연도',
    date.MONTH AS date.MONTH WITH SYNONYMS ('월') COMMENT = '방문 월(1~12)',
    gcv.CHILD_CODE AS gcv.CHILD_CODE_RAW WITH SYNONYMS ('결연아동코드', '아동코드', 'childnum', '공122') COMMENT = '결연아동코드(URL childnum= 원값 · 대문자). NULL = 값이 비어 있는 URL(원천 그대로) — 집계에서 「코드 없음」으로 따로 밝힌다',
    gcv.IS_FORMAT_VALID AS gcv.IS_FORMAT_VALID WITH SYNONYMS ('형식 유효', '추천안A 판정') COMMENT = '추천안A = 영문3-숫자4-숫자6 형식 코드(TRUE/FALSE)',
    gcv.IS_CRM_MATCHED AS gcv.IS_CRM_MATCHED WITH SYNONYMS ('CRM 아동 일치', '추천안B 판정') COMMENT = '추천안B = CRM 아동번호(CRM_CHILD.CHILD_NO)에 실재하는 코드(TRUE/FALSE)',
    gcv.CRM_CHILD_CD AS gcv.CHILD_CD WITH SYNONYMS ('CRM 아동코드') COMMENT = 'CRM 숫자 아동코드(추천안B 일치분만)',
    gcv.PAGE_PATH AS gcv.PAGE_PATH WITH SYNONYMS ('페이지', '페이지 경로') COMMENT = '페이지 경로(자유 텍스트 · ILIKE 부분일치로 필터)',
    usc.CLICK_MONTH_KEY AS usc.CLICK_MONTH_KEY WITH SYNONYMS ('클릭월', '기준월') COMMENT = '미납서비스 클릭월 YYYYMM',
    usc.CLICK_YEAR AS FLOOR(usc.CLICK_MONTH_KEY / 100) WITH SYNONYMS ('클릭 연도', '연도') COMMENT = '미납서비스 클릭 연도 YYYY',
    usc.SVC_SCOPE AS usc.SVC_SCOPE WITH SYNONYMS ('서비스 범위', '추천안') COMMENT = '서비스 범위 = ''A''(미납 안내 페이지만) · ''B''(A + 결제정보 변경 페이지). 🔴 metric 이 범위를 이미 고정하므로 직접 필터하지 않는다'
  )
  METRICS (
    gcv.CHILD_CODE_CNT_A AS COUNT(DISTINCT CASE WHEN gcv.IS_FORMAT_VALID THEN gcv.CHILD_CODE_RAW END)
      WITH SYNONYMS ('결연아동코드 수', '결연아동 수(추천안A)', '공122')
      COMMENT = '고유 결연아동코드 수 — 추천안A(형식 기준 · 잠정). D(distinct · 가산 금지).',
    gcv.CHILD_CODE_CNT_B AS COUNT(DISTINCT CASE WHEN gcv.IS_CRM_MATCHED THEN gcv.CHILD_CODE_RAW END)
      WITH SYNONYMS ('결연아동 수(추천안B)', 'CRM 일치 결연아동 수', '공122')
      COMMENT = '고유 결연아동코드 수 — 추천안B(CRM 아동번호 대조 · 잠정). D(distinct · 가산 금지).',
    gcv.CHILD_PAGE_VIEWS AS SUM(gcv.VIEW_CNT)
      WITH SYNONYMS ('결연아동 페이지뷰')
      COMMENT = '결연아동 페이지 페이지뷰 합계(건). F(가산).',
    gcv.CHILD_PAGE_EVENTS AS SUM(gcv.EVENT_CNT)
      WITH SYNONYMS ('결연아동 페이지 이벤트수')
      COMMENT = '결연아동 페이지 이벤트 합계(건). F(가산).',
    gcv.CHILD_PAGE_MEMBERS AS COUNT(DISTINCT gcv.URL_MEMBER_DK)
      WITH SYNONYMS ('결연아동 페이지 방문 회원수', '공111')
      COMMENT = 'URL 회원번호(memnum)로 식별된 고유 회원 수(명). D. 비식별 방문은 빠진다.',
    usc.UNPAID_SVC_CLICK_MEMBERS_A AS COUNT(CASE WHEN usc.SVC_SCOPE = 'A' THEN 1 END)
      WITH SYNONYMS ('미납서비스 클릭회원(추천안A)')
      COMMENT = '미납서비스 클릭회원(명 · 회원×월) — 추천안A 분모. 월 하나면 회원수와 같다.',
    usc.UNPAID_SVC_CONV_RATE_A AS SUM(CASE WHEN usc.SVC_SCOPE = 'A' THEN usc.ARREAR_PAID_D30_FLAG END) / NULLIF(COUNT(CASE WHEN usc.SVC_SCOPE = 'A' THEN 1 END), 0) * 100
      WITH SYNONYMS ('미납서비스 전환율', '미납서비스 전환율(추천안A)', '공81')
      COMMENT = '미납서비스 전환율(%) — 추천안A(잠정) = 미납 안내 페이지 클릭회원 중 클릭 후 30일 안에 미납분(청구월 < 클릭월)을 납입한 비중. N(비율 · 재합산 금지).',
    usc.UNPAID_SVC_CONV_RATE_A_D5 AS SUM(CASE WHEN usc.SVC_SCOPE = 'A' THEN usc.ARREAR_PAID_D5_FLAG END) / NULLIF(COUNT(CASE WHEN usc.SVC_SCOPE = 'A' THEN 1 END), 0) * 100
      WITH SYNONYMS ('미납서비스 5일 전환율(추천안A)', '공81')
      COMMENT = '추천안A 의 5일 창 판본(%). 창 길이 현업 확인 대상. N.',
    usc.UNPAID_SVC_CLICK_MEMBERS_B AS COUNT(CASE WHEN usc.SVC_SCOPE = 'B' THEN 1 END)
      WITH SYNONYMS ('미납서비스 클릭회원(추천안B)')
      COMMENT = '미납서비스 클릭회원(명 · 회원×월) — 추천안B 분모(결제정보 변경 페이지 포함).',
    usc.UNPAID_SVC_CONV_RATE_B AS SUM(CASE WHEN usc.SVC_SCOPE = 'B' THEN usc.PAID_D30_FLAG END) / NULLIF(COUNT(CASE WHEN usc.SVC_SCOPE = 'B' THEN 1 END), 0) * 100
      WITH SYNONYMS ('미납서비스 전환율(추천안B)', '공81')
      COMMENT = '미납서비스 전환율(%) — 추천안B(잠정) = 미납 안내 + 결제정보 변경 페이지 클릭회원 중 클릭 후 30일 안에 납입(종류 무관)한 비중. N.',
    usc.UNPAID_SVC_CONV_RATE_B_D5 AS SUM(CASE WHEN usc.SVC_SCOPE = 'B' THEN usc.PAID_D5_FLAG END) / NULLIF(COUNT(CASE WHEN usc.SVC_SCOPE = 'B' THEN 1 END), 0) * 100
      WITH SYNONYMS ('미납서비스 5일 전환율(추천안B)', '공81')
      COMMENT = '추천안B 의 5일 창 판본(%). N.'
  )
  COMMENT = 'GA 기반 결연아동코드(공#122)·미납서비스 전환율(공#81) SV. 🔴 두 지표 모두 추천안 A/B 를 함께 싣는 잠정판이다 — 답변에 두 안의 값을 나란히 보여주고 「잠정 · 현업 정의 확정 대기」를 밝힌다. [원천: GA4 → SILVER.BIGQUERY_EVENT · CRM → SILVER.CRM_CHILD · CRM_PAYMENT_BILLING].'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·분모는 반드시 SQL 이 낸다 — 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지). 중복제거 수(COUNT DISTINCT)는 그룹 값을 더하지 않고 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴 [O239 추천안 병기] 「결연아동코드 수」·「미납서비스 전환율」 질문에는 추천안A·B 두 metric 을 한 SELECT 에 함께 내고, 답변에 각 안의 정의를 1줄씩 붙이고 「잠정(현업 정의 확정 대기)」을 밝힌다 — 한 안만 골라 단정하지 않는다. (2) 미납서비스 metric 은 SVC_SCOPE 를 이미 고정한다 ⇒ SVC_SCOPE 로 다시 필터하거나 A·B 행을 더하지 않는다. (3) 미납서비스 분모는 회원×월이다 — 여러 달을 합치면 같은 회원이 달마다 다시 센다는 점을 밝히고, 기간 미지정이면 CLICK_MONTH_KEY 별로 내고 전체 합은 열로 낸다(표에 행으로 붙이지 않는다). (4) gcv(결연아동)와 usc(미납서비스)는 한 쿼리에서 결합하지 않는다. (5) 결연아동코드 NULL(빈 값)은 두 안 모두 세지 않는다 — 코드별 목록에서는 제외한다. (6) 기간 미지정 시 결연아동은 데이터 최신월 기준 직전 3개월, 미납서비스는 전체 기간 월별로 한다.'
  AI_VERIFIED_QUERIES (
    vqr_o239_unpaid_conv AS (
      QUESTION '클릭월별 미납서비스 전환율'
      VERIFIED_BY '(DW = O239 · O242 한글 별칭·반올림)'
      SQL 'SELECT usc.CLICK_MONTH_KEY AS "클릭월", COUNT(CASE WHEN usc.SVC_SCOPE = ''A'' THEN 1 END) AS "미납서비스 클릭회원(추천안A)(명)", ROUND(SUM(CASE WHEN usc.SVC_SCOPE = ''A'' THEN usc.ARREAR_PAID_D30_FLAG END) / NULLIF(COUNT(CASE WHEN usc.SVC_SCOPE = ''A'' THEN 1 END), 0) * 100, 2)::NUMBER(38,2) AS "미납서비스 전환율(추천안A)(%)", COUNT(CASE WHEN usc.SVC_SCOPE = ''B'' THEN 1 END) AS "미납서비스 클릭회원(추천안B)(명)", ROUND(SUM(CASE WHEN usc.SVC_SCOPE = ''B'' THEN usc.PAID_D30_FLAG END) / NULLIF(COUNT(CASE WHEN usc.SVC_SCOPE = ''B'' THEN 1 END), 0) * 100, 2)::NUMBER(38,2) AS "미납서비스 전환율(추천안B)(%)" FROM usc GROUP BY usc.CLICK_MONTH_KEY ORDER BY usc.CLICK_MONTH_KEY'
    ),
    vqr_o239_child_codes AS (
      QUESTION '연도별 결연아동코드 수'
      VERIFIED_BY '(DW = O239 · O242 한글 별칭)'
      SQL 'SELECT date.YEAR AS "연도", COUNT(DISTINCT CASE WHEN gcv.IS_FORMAT_VALID THEN gcv.CHILD_CODE_RAW END) AS "결연아동 수(추천안A)", COUNT(DISTINCT CASE WHEN gcv.IS_CRM_MATCHED THEN gcv.CHILD_CODE_RAW END) AS "결연아동 수(추천안B)" FROM gcv JOIN date ON gcv.DATE_SK = date.DATE_SK GROUP BY date.YEAR ORDER BY date.YEAR'
    )
  );

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_CHILD_UNPAID TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_CHILD_UNPAID TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_CHILD_UNPAID TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인) — SV 값 = 팩트 직접식
SELECT (SELECT CHILD_CODE_CNT_B FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_GA_CHILD_UNPAID METRICS gcv.CHILD_CODE_CNT_B)) AS sv_child_b,
       (SELECT COUNT(DISTINCT CHILD_CODE_RAW) FROM GN_DW.GOLD.FACT_GA_CHILD_VIEW WHERE IS_CRM_MATCHED) AS fact_child_b,
       (SELECT UNPAID_SVC_CONV_RATE_A FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_GA_CHILD_UNPAID METRICS usc.UNPAID_SVC_CONV_RATE_A)) AS sv_rate_a,
       (SELECT SUM(ARREAR_PAID_D30_FLAG) / NULLIF(COUNT(*), 0) * 100 FROM GN_DW.GOLD.FACT_UNPAID_SERVICE_CONV WHERE SVC_SCOPE = 'A') AS fact_rate_a;
