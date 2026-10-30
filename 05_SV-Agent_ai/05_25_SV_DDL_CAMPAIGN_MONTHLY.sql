-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_CAMPAIGN_MONTHLY (🆕 O237-B)
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_MONTHLY
-- Run order  : 운영계 #42
-- Depends on : GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY, GN_DW.GOLD.DIM_CAMPAIGN, GN_DW.GOLD.DIM_PAYMENT
-- Issue      : O237-B
-- =============================================================================
-- ============================================================================
-- 05_25_SV_DDL_CAMPAIGN_MONTHLY.sql — Semantic View DDL 정본: SV_CAMPAIGN_MONTHLY ( O237-B)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 근거 = 신규지표 #12~#16 · #19 · #21~#25 · #27~#28(90_provided_definition/신규지표_20260820.csv)
--     캠페인 귀속 = 후원건(후원사업) 캠페인(사용자 결정 A · 2026-10-15) · 납입방식 = 그 달 청구 결제수단(잠정 · 2026-10-16 승인)
--   · 선행 = GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY(05_25b [0] · dbt build) · 대사 = 05_25b_대사_CAMPAIGN_MONTHLY.sql
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_MONTHLY
  TABLES (
    fcm AS GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY
      PRIMARY KEY (BASE_MONTH_KEY, CAMPAIGN_SK, PAYMENT_SK)
      WITH SYNONYMS ('캠페인 월 지표', '캠페인별 활동율', '캠페인별 납입율')
      COMMENT = '캠페인별 월 지표 팩트(base: GOLD.FACT_CAMPAIGN_MONTHLY). [Grain: 기준연월 × 캠페인 × 납입방식]. 당월 measure = 기준월 값 · 누계 measure = 같은 해 1월~기준월 · 연도초 = 기준연도 1월 as-of(기준월마다 같은 값). 🔴 기준연월 하나를 고정한다. [원천: CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN(활동·중단·연도초 · 후원사업 대표캠페인) · FACT_MEMBER_EVENT(개발 · 개발 사건 캠페인) · FACT_MEMBER_FEE(회비) · SILVER.CRM_MEMBER_AMT_CHANGE(감액) → GOLD.FACT_CAMPAIGN_MONTHLY].',
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인', '후원 캠페인', '후원건 캠페인')
      COMMENT = '캠페인 차원(PK 유일 · fan-out 0). 후원건(후원사업)의 캠페인 — 활동·중단·연도초·회비 = 후원사업 대표캠페인 · 개발 = 개발 사건 캠페인 · 감액 = 금액변경 원천 캠페인. SK=0 = (미매핑). [원천] BRONZE_CRM.TM_CM_CMPGN_MNG.',
    payment AS GN_DW.GOLD.DIM_PAYMENT
      PRIMARY KEY (PAYMENT_SK)
      WITH SYNONYMS ('납입방식', '결제수단')
      COMMENT = '결제수단 차원(PK 유일). 6종 라벨(자동이체·신용카드·회비통장·휴대폰·네이버페이·OCR) + SK=0 (미매핑 = 그 달 청구 없음 또는 라벨 없는 원천 코드). [원천] CRM 결제수단 코드(SETLE_CD).'
  )
  RELATIONSHIPS (
    fcm_to_campaign AS fcm (CAMPAIGN_SK) REFERENCES campaign,
    fcm_to_payment AS fcm (PAYMENT_SK) REFERENCES payment
  )
  DIMENSIONS (
    fcm.BASE_MONTH_KEY AS fcm.BASE_MONTH_KEY WITH SYNONYMS ('기준연월', '기준월', '조회연월', '연월') COMMENT = '기준연월 YYYYMM 정수(예: 202609 = 2026년 9월 · 누계 = 1월~9월). 🔴 반드시 하나로 고정한다',
    fcm.BASE_YEAR AS fcm.BASE_YEAR WITH SYNONYMS ('기준연도', '연도', '년') COMMENT = '기준연도. 「연도별」 질문은 각 연도의 마지막 적재 기준월(또는 12월)을 고른다 — 연도로 묶어 SUM 하지 않는다',
    campaign.CAMPAIGN_NAME AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인명', '캠페인', '개발캠페인', '공18', '공120') COMMENT = '후원건 캠페인명. (미매핑) = 캠페인이 연결되지 않은 건',
    campaign.CAMPAIGN_TYPE AS campaign.CAMPAIGN_TYPE WITH SYNONYMS ('캠페인카테고리', '캠페인 카테고리', '주요캠페인') COMMENT = '캠페인 카테고리(MM294 라벨).',
    campaign.DOMESTIC_OVERSEAS AS campaign.DOMESTIC_OVERSEAS WITH SYNONYMS ('캠페인유형', '국내해외', '국내/해외') COMMENT = '캠페인유형 국내/통합/해외(MM295). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''국내''·''전체사업''·''통합''·''해외''',
    campaign.BIZ_CASE_TYPE AS campaign.BIZ_CASE_TYPE WITH SYNONYMS ('캠페인유형2', '사업사례', '사업/사례') COMMENT = '캠페인유형2 굿즈/기타/사례/사업(MM296). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''굿즈''·''기타''·''사례''·''사업''',
    campaign.INFLOW_PATH AS campaign.INFLOW_PATH WITH SYNONYMS ('개발인입경로', '인입경로') COMMENT = '캠페인 개발인입경로(MM293). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''교육기관''·''기타 기업개발''·''뉴미디어''·''대면모금''·''디지털''·''방송''·''영상광고''·''오프라인''·''일시''·''재송출''·''지역개발''·''콜개발''',
    campaign.CMMN_BRND_NM AS campaign.CMMN_BRND_NM WITH SYNONYMS ('공통브랜드', '공통 브랜드', '공117') COMMENT = '캠페인 공통브랜드(MM297). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''교육기관''·''기업''·''뉴미디어''·''대면모금''·''디지털''·''마케팅콜개발''·''방송''·''영상광고''·''일시''·''재송출''·''지역개발''·''콜개발''·''회원 기타''·''회원 오프라인개발''·''회원 온라인개발''·''회원 콜개발''',
    campaign.MARKETING_CAMPAIGN AS campaign.MARKETING_CAMPAIGN WITH SYNONYMS ('마케팅캠페인', '마케팅캠페인명') COMMENT = '마케팅캠페인명.',
    campaign.MKTG_CHANNEL_NM AS campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '캠페인 채널') COMMENT = '캠페인 마케팅 채널명(TC_MKTNG_DTL_CD C002).',
    campaign.CAMPAIGN_TARGET_NAME AS campaign.CAMPAIGN_TARGET_NAME WITH SYNONYMS ('캠페인대상', '캠페인 대상', '대상 구분') COMMENT = '캠페인 대상 구분(CM002 라벨 · O262-B). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''일반인''·''정기회원''·''후원중단회원''·''기업임직원''·''웹진구독회원''·''일시회원''·''정기/일시회원''·''GNI USA''·''직원''·''일반인/일시회원''. 코드 없음 = NULL(값이 없는 캠페인 · 미매핑 아님).',
    campaign.MKTG_UTM_NM AS campaign.MKTG_UTM_NM WITH SYNONYMS ('마케팅UTM', 'UTM') COMMENT = '캠페인 UTM 라벨(TC_MKTNG_DTL_CD U001).',
    campaign.PARENT_CAMPAIGN_NAME AS campaign.PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명', '공119') COMMENT = '상위캠페인명. 상위가 없으면 NULL.',
    payment.SETTLE_METHOD AS payment.SETTLE_METHOD WITH SYNONYMS ('납입방식', '결제수단', '결제방식', '공125', '공126') COMMENT = '결제수단 라벨(자동이체·신용카드·회비통장·휴대폰·네이버페이·OCR). NULL = (미매핑). 🔴 잠정 축 = 그 달 회원×후원사업 청구 행의 결제수단(현업 확인 대상) 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''OCR''·''네이버페이''·''신용카드''·''자동이체''·''회비통장''·''휴대폰'''
  )
  METRICS (
    fcm.ACTIVE_CNT_SUM AS SUM(fcm.ACTIVE_CNT)
      WITH SYNONYMS ('캠페인별 활동(건)', '월말활동(건)', '캠페인 활동건') COMMENT = '월말 활동(건) = 기준월 as-of 활동 후원사업 약정금액 ÷ 10,000. 가산(캠페인·납입방식 합산 가능 · 기준월 고정).',
    fcm.STOP_CNT_SUM AS SUM(fcm.STOP_CNT)
      WITH SYNONYMS ('캠페인별 중단(건)', '당월 중단(건)') COMMENT = '당월 중단(건) = 기준월 중단 약정금액 ÷ 10,000. 가산.',
    fcm.DEV_CNT_SUM AS SUM(fcm.DEV_CNT)
      WITH SYNONYMS ('캠페인별 개발(건)', '당월 개발(건)') COMMENT = '당월 개발(건) = MSTR 개발(건). 가산.',
    fcm.CHURN_CNT_SUM AS SUM(fcm.CHURN_CNT)
      WITH SYNONYMS ('캠페인별 이탈(건)', '이탈(건)', '신규20') COMMENT = '신규 #20 이탈(건) = 중단(건) + 감액(건). 가산.',
    fcm.CUM_DEV_CNT_SUM AS SUM(fcm.CUM_DEV_CNT)
      WITH SYNONYMS ('캠페인별 누계개발(건)', '개발누계건') COMMENT = '누계개발(건) = 1월~기준월 개발(건). 기준월 고정.',
    fcm.YEAR_START_ACTIVE_CNT_SUM AS SUM(fcm.YEAR_START_ACTIVE_CNT)
      WITH SYNONYMS ('캠페인별 연도초활동(건)', '연도초활동건', '공49') COMMENT = '연도초활동(건) = 기준연도 1월 as-of 활동 ÷ 10,000. 🔴 기준월 하나에서만 쓴다(기준월마다 같은 값이 반복된다).',
    fcm.PAID_FEE_SUM AS SUM(fcm.PAID_FEE_BILLABLE)
      WITH SYNONYMS ('캠페인별 납입회비', '월 납입회비') COMMENT = '당월 납입회비(원 · 회비만). 가산.',
    fcm.UNPAID_FEE_SUM AS SUM(fcm.UNPAID_BILLED_AMT)
      WITH SYNONYMS ('캠페인별 미납회비', '월 미납회비') COMMENT = '당월 미납회비(원) = 결제 실패·미기록 청구액. 가산.',
    fcm.CAMPAIGN_ACTIVE_RATE AS SUM(fcm.ACTIVE_CNT) / NULLIF(SUM(fcm.CUM_DEV_CNT) + SUM(fcm.YEAR_START_ACTIVE_CNT), 0) * 100
      WITH SYNONYMS ('캠페인별 활동율(%)', '연도별 캠페인 활동율(%)', '캠페인별 납입방식 활동율(%)', '신규12', '신규13', '신규14')
      COMMENT = '신규 #12 캠페인별 활동율(%) = 활동(건) ÷ (개발누계(건) + 연도초활동(건)) ×100. 비율(재합산 금지). #13 연도별 = 각 연도 마지막 기준월에서 같은 식 · #14 납입방식별 = SETTLE_METHOD 로 나눈다. 🔴 기준월 고정.',
    fcm.CAMPAIGN_STOP_RATE AS SUM(fcm.STOP_CNT) / NULLIF(SUM(fcm.DEV_CNT) + SUM(fcm.YEAR_START_ACTIVE_CNT), 0) * 100
      WITH SYNONYMS ('캠페인별 중단율(%)', '캠페인별 납입방식 중단율(%)', '신규15', '신규19')
      COMMENT = '신규 #15 캠페인별 중단율(%) = 당월 중단(건) ÷ (당월 개발(건) + 연도초활동(건)) ×100 — 사전 원문 그대로. 비율. #19 납입방식별 = SETTLE_METHOD 로 나눈다. 🔴 기준월 고정.',
    fcm.CAMPAIGN_STOP_RATE_PREV AS SUM(fcm.STOP_CNT) / NULLIF(SUM(fcm.DEV_CNT) + SUM(fcm.PREV_MONTH_END_ACTIVE_CNT), 0) * 100
      WITH SYNONYMS ('연도별 캠페인 중단율(%)', '전월말 기준 캠페인 중단율', '신규16')
      COMMENT = '신규 #16 연도별 캠페인 중단율(%) = 중단(건) ÷ (개발(건) + 전월말활동(건)) ×100. 비율. 🔴 기준월 고정 · 연도별은 각 연도 기준월을 고른다.',
    fcm.CAMPAIGN_CHURN_RATE AS SUM(fcm.CHURN_CNT) / NULLIF(SUM(fcm.DEV_CNT), 0) * 100
      WITH SYNONYMS ('캠페인별 이탈율(%)', '신규21')
      COMMENT = '신규 #21 캠페인별 이탈율(%) = 이탈(건) ÷ 개발(건) ×100(당월). 비율. 🔴 개발이 작은 캠페인은 100% 를 넘을 수 있다 — 해석 주의를 밝힌다.',
    fcm.CAMPAIGN_PAY_IN_RATE AS SUM(fcm.PAID_FEE_BILLABLE) / NULLIF(SUM(fcm.ACTIVE_CNT) * 10000, 0) * 100
      WITH SYNONYMS ('캠페인별 납입율(%)', '연도별 캠페인별 납입율(%)', '신규22', '신규23')
      COMMENT = '신규 #22 캠페인별 납입율(%) = 월 납입회비 ÷ (월말활동(건) × 1만 원) ×100. 비율. 🔴 공64 납부율(청구 대비)과 다르다 · 기준월 고정.',
    fcm.CAMPAIGN_CUM_PAY_IN_RATE AS SUM(fcm.CUM_PAID_FEE_BILLABLE) / NULLIF(SUM(fcm.CUM_ACTIVE_CNT) * 10000, 0) * 100
      WITH SYNONYMS ('캠페인별 누계 납입율(%)', '연도별 캠페인 누계납입율(%)', '신규24', '신규25')
      COMMENT = '신규 #24 캠페인별 누계 납입율(%) = 1월~기준월 납입회비 ÷ (1월~기준월 월말활동(건) 합 × 1만 원) ×100. 비율. 🔴 기준월 고정.',
    fcm.CAMPAIGN_UNPAID_RATE AS SUM(fcm.UNPAID_BILLED_AMT) / NULLIF(SUM(fcm.ACTIVE_CNT) * 10000, 0) * 100
      WITH SYNONYMS ('캠페인별 미납율(%)', '연도별 캠페인 미납율(%)', '신규27', '신규28')
      COMMENT = '신규 #27 캠페인별 미납율(%) = 월 미납회비 ÷ (월말활동(건) × 1만 원) ×100. 비율. 🔴 공76 미납율(건 기준)·미납비중(청구 대비)과 다르다 · 기준월 고정.'
  )
  COMMENT = '캠페인별 월 지표 SV(신규 #12~#16 · #19~#25 · #27~#28). 「캠페인별 활동율·중단율·이탈율·납입율·미납율을 N월 기준으로」 질문용 — 근사하지 않고 이 SV 로 계산한다. 🔴 기준연월 하나를 고정한다. 🔴 캠페인 = 후원건 캠페인(활동·중단·연도초·회비 = 후원사업 대표캠페인 · 개발 = 개발 사건 캠페인 · 감액 = 금액변경 캠페인). 「그 달 후원 캠페인」(SV_MEMBER_MONTHLY campaign)과 다른 축이다. 누계중단율(#17)·신규 중단율(#18)은 SV_CAMPAIGN_CUM_STOP 이다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) WHERE fcm.BASE_MONTH_KEY = <YYYYMM> 으로 기준연월 하나를 반드시 고정한다(「2026년 9월 기준」 = 202609 · 기간 미지정이면 마감된 최신월). 여러 기준월을 함께 SUM 하지 않는다. (2) 「연도별」은 각 연도의 마지막 기준월(12월 또는 그 해 최신 마감월)을 연도마다 하나씩 골라 같은 식을 낸다. (3) 비율은 분자·분모 합의 비로 계산한다 — 행별 비율을 평균내지 않는다. 결과에 분자·분모 measure 를 함께 보이고 전체 합 행은 붙이지 않는다(필요하면 전체 합 열 · 표 밖 본문 1줄). (4) (미매핑) 캠페인·결제수단 행을 빼지 말고 그대로 보인다(전체 합 정합). (5) 분모가 작은 캠페인의 비율·100% 초과 값은 해석 주의를 밝힌다. 🆕 [O237-C 소규모 이상치 · 사용자 결정 2026-10-16] 캠페인별 비율의 **순위·상위/하위 목록**에서는 그 비율의 분모(건)가 100 미만인 캠페인을 HAVING 으로 제외한다(전체 합은 HAVING 전 값이어야 하므로 그룹 없는 CTE 로 낸다 · 제외 없이 그대로) — 답변에 「분모가 100 미만인 소규모 캠페인 N개는 비율 이상치(분모가 작아 비정상적으로 큰 미납율 등)로 인해 순위에서 제외했다」와 제외 개수를 밝힌다. 특정 캠페인을 이름으로 물으면 제외하지 않고 값과 「소규모 · 해석 주의」를 함께 낸다. (6) 납입방식은 잠정 축(그 달 청구 결제수단)임을 답변에 밝힌다.'
  AI_VERIFIED_QUERIES (
    vqr_o237b_campaign_active_rate AS (
      QUESTION '2026년 9월 기준 캠페인별 활동율'
      VERIFIED_BY '(DW = O237-B · 전 캠페인 합 = FMM 2026-09 합 · 대사 05_25b)'
      SQL 'SELECT CAMPAIGN_NAME AS "캠페인", ACTIVE_CNT_SUM AS "활동(건)", CUM_DEV_CNT_SUM AS "누계 개발(건)", YEAR_START_ACTIVE_CNT_SUM AS "연도초 활동(건)", ROUND(CAMPAIGN_ACTIVE_RATE, 2)::NUMBER(38,2) AS "활동율(%)" FROM (SELECT campaign.CAMPAIGN_NAME, SUM(fcm.ACTIVE_CNT) AS ACTIVE_CNT_SUM, SUM(fcm.CUM_DEV_CNT) AS CUM_DEV_CNT_SUM, SUM(fcm.YEAR_START_ACTIVE_CNT) AS YEAR_START_ACTIVE_CNT_SUM, SUM(fcm.ACTIVE_CNT) / NULLIF(SUM(fcm.CUM_DEV_CNT) + SUM(fcm.YEAR_START_ACTIVE_CNT), 0) * 100 AS CAMPAIGN_ACTIVE_RATE FROM fcm LEFT JOIN campaign ON fcm.CAMPAIGN_SK = campaign.CAMPAIGN_SK WHERE fcm.BASE_MONTH_KEY = 202609 GROUP BY campaign.CAMPAIGN_NAME) ORDER BY ACTIVE_CNT_SUM DESC NULLS LAST'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_MONTHLY TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_MONTHLY TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_MONTHLY TO ROLE GN_DW_AR_SRC_COMMON;  -- O270 원천별 접근 역할
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_MONTHLY TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인) — SV 활동율 = 팩트 직접 계산(2026-09 기준)
SELECT (SELECT CAMPAIGN_ACTIVE_RATE FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_CAMPAIGN_MONTHLY DIMENSIONS fcm.BASE_MONTH_KEY METRICS fcm.CAMPAIGN_ACTIVE_RATE) WHERE BASE_MONTH_KEY = 202609) AS sv_rate,
       (SELECT SUM(ACTIVE_CNT) / NULLIF(SUM(CUM_DEV_CNT) + SUM(YEAR_START_ACTIVE_CNT), 0) * 100
          FROM GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY WHERE BASE_MONTH_KEY = 202609) AS fact_rate;
