-- ============================================================================
-- 05_24_SV_DDL_CAMPAIGN_CUM_STOP.sql — Semantic View DDL 정본: SV_CAMPAIGN_CUM_STOP (🆕 O236)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 근거 = 신규지표 #17 「캠페인별 누계중단율(%)」 = 캠페인별 누계중단(건) / (캠페인별 누계개발(건) + 캠페인별 연도초활동회원(건))
--     (90_provided_definition/신규지표_20260820.csv:29). 캠페인 귀속 = 후원건(후원사업) 캠페인(사용자 결정 A · 2026-10-15).
--   · 왜 별도 SV 인가 = SV_MEMBER_MONTHLY 로는 누계를 낼 수 없다(연도초 월 반복 · 캠페인 미귀속) — 대사 = 05_24b_대사_CAMPAIGN_CUM_STOP.sql.
--   · 선행 = GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP(03_top-down_gold/06_DDL.sql · dbt build).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_CUM_STOP
  TABLES (
    fccs AS GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP
      PRIMARY KEY (BASE_MONTH_KEY, CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인 누계 중단', '캠페인별 누계중단율', '캠페인 누계')
      COMMENT = '캠페인별 누계 중단·개발·연도초활동 팩트(base: GOLD.FACT_CAMPAIGN_CUM_STOP). [Grain: 기준연월 × 캠페인 · 누계 = 같은 해 1월~기준월]. 🔴 누계 grain — 기준연월 하나를 고정한다(여러 기준월을 합산하면 누계가 겹쳐 커진다). [원천: CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN(중단·연도초 · 후원사업 대표캠페인) · GOLD.FACT_MEMBER_EVENT(개발 · 개발 사건 캠페인) → GOLD.FACT_CAMPAIGN_CUM_STOP].',
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인', '후원 캠페인', '후원건 캠페인')
      COMMENT = '캠페인 차원(PK 유일 · fan-out 0). 후원건(후원사업)의 캠페인 — 중단·연도초는 후원사업 대표캠페인(신규 개발 우선 → 최초일자), 개발은 개발 사건의 캠페인. SK=0 = (미매핑). [원천] BRONZE_CRM.TM_CM_CMPGN_MNG.'
  )
  RELATIONSHIPS (
    fccs_to_campaign AS fccs (CAMPAIGN_SK) REFERENCES campaign
  )
  DIMENSIONS (
    fccs.BASE_MONTH_KEY AS fccs.BASE_MONTH_KEY WITH SYNONYMS ('기준연월', '기준월', '조회연월', '연월') COMMENT = '기준연월 YYYYMM 정수(예: 202609 = 2026년 9월 기준 · 1월~9월 누계). 🔴 반드시 하나로 고정한다',
    fccs.BASE_YEAR AS fccs.BASE_YEAR WITH SYNONYMS ('기준연도', '연도', '년') COMMENT = '기준연도(연도초 기준 해). 연도만 물으면 그 해 마지막 적재 기준월을 고른다',
    campaign.CAMPAIGN_NAME AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인명', '캠페인') COMMENT = '후원건 캠페인명. (미매핑) = 후원사업·개발 사건에 캠페인이 연결되지 않은 건',
    campaign.CAMPAIGN_TYPE AS campaign.CAMPAIGN_TYPE WITH SYNONYMS ('캠페인카테고리', '캠페인 카테고리', '주요캠페인') COMMENT = '캠페인 카테고리(MM294 라벨).',
    campaign.DOMESTIC_OVERSEAS AS campaign.DOMESTIC_OVERSEAS WITH SYNONYMS ('캠페인유형', '국내해외', '국내/해외') COMMENT = '캠페인유형 국내/통합/해외(MM295).',
    campaign.BIZ_CASE_TYPE AS campaign.BIZ_CASE_TYPE WITH SYNONYMS ('캠페인유형2', '사업사례', '사업/사례') COMMENT = '캠페인유형2 굿즈/기타/사례/사업(MM296).',
    campaign.INFLOW_PATH AS campaign.INFLOW_PATH WITH SYNONYMS ('개발인입경로', '인입경로') COMMENT = '캠페인 개발인입경로(MM293).',
    campaign.CMMN_BRND_NM AS campaign.CMMN_BRND_NM WITH SYNONYMS ('공통브랜드', '공통 브랜드') COMMENT = '캠페인 공통브랜드(MM297).',
    campaign.MARKETING_CAMPAIGN AS campaign.MARKETING_CAMPAIGN WITH SYNONYMS ('마케팅캠페인', '마케팅캠페인명') COMMENT = '마케팅캠페인명.',
    campaign.MKTG_CHANNEL_NM AS campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '캠페인 채널') COMMENT = '캠페인 마케팅 채널명(TC_MKTNG_DTL_CD C002).',
    campaign.MKTG_UTM_NM AS campaign.MKTG_UTM_NM WITH SYNONYMS ('마케팅UTM', 'UTM') COMMENT = '캠페인 UTM 라벨(TC_MKTNG_DTL_CD U001).',
    campaign.PARENT_CAMPAIGN_NAME AS campaign.PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명') COMMENT = '상위캠페인명. 상위가 없으면 NULL.'
  )
  METRICS (
    fccs.CUM_STOP AS SUM(fccs.CUM_STOP_CNT)
      WITH SYNONYMS ('누계중단(건)', '캠페인별 누계중단', '누계중단') COMMENT = '누계중단(건) = 1월~기준월 중단 후원사업 약정금액 ÷ 10,000. 가산(캠페인 합산 가능 · 기준월은 고정).',
    fccs.CUM_DEV AS SUM(fccs.CUM_DEV_CNT)
      WITH SYNONYMS ('누계개발(건)', '캠페인별 누계개발', '누계개발') COMMENT = '누계개발(건) = 1월~기준월 MSTR 개발(건)(인정금액 ÷ 10,000). 가산(기준월은 고정).',
    fccs.YEAR_START_ACTIVE AS SUM(fccs.YEAR_START_ACTIVE_CNT)
      WITH SYNONYMS ('연도초활동회원(건)', '캠페인별 연도초활동회원', '연도초활동(건)', '연초활동', '공49') COMMENT = '연도초활동회원(건) = 기준연도 1월 as-of 활동 후원사업 약정금액 ÷ 10,000. 기준월마다 1회만 들어 있다(월 반복 없음).',
    fccs.CUM_STOP_RATE AS SUM(fccs.CUM_STOP_CNT) / NULLIF(SUM(fccs.CUM_DEV_CNT) + SUM(fccs.YEAR_START_ACTIVE_CNT), 0) * 100
      WITH SYNONYMS ('캠페인별 누계중단율(%)', '누계중단율', '누계중단비중', '누적중단율', '누계중단률', '캠페인별 누계중단비중')
      COMMENT = '신규 #17 캠페인별 누계중단율(%) = 누계중단(건) ÷ (누계개발(건) + 연도초활동회원(건)) ×100. 비율(재합산 금지 · 상위 축은 이 지표를 그대로 다시 계산한다). 25년부터 산출(연도초 기준).',
    -- 🆕 [O237] 신규 #18 연도별 캠페인 신규 중단율
    fccs.CUM_STOP_RATE_DEV AS SUM(fccs.CUM_STOP_CNT) / NULLIF(SUM(fccs.CUM_DEV_CNT), 0) * 100
      WITH SYNONYMS ('연도별 캠페인 신규 중단율(%)', '캠페인 신규 중단율', '누계개발 대비 누계중단율', '신규18')
      COMMENT = '신규 #18 연도별 캠페인 신규 중단율(%) = 누계중단(건) ÷ 누계개발(건) ×100 — 분모에 연도초활동을 넣지 않는다(#17 과 다르다). 비율(재합산 금지). 🔴 기준연월 하나 고정 · 🔴 분자(중단 = 후원사업 대표캠페인)와 분모(개발 = 개발 사건 캠페인)의 캠페인 규칙이 달라 100% 를 넘는 캠페인이 있을 수 있다 — 그 사실을 밝히고 분모가 작은 캠페인은 해석 주의.'
  )
  COMMENT = '캠페인별 누계중단율(신규 #17) SV. 「캠페인별 누계중단율·누계중단비중을 N월 기준으로 계산」 질문용 — 근사하지 않고 이 SV 로 바로 계산한다. 🔴 기준연월 하나를 고정한다. 🔴 캠페인 = 후원건 캠페인(중단·연도초 = 후원사업 대표캠페인 · 개발 = 개발 사건 캠페인 · 규칙이 다르다). 「그 달 후원 캠페인」(SV_MEMBER_MONTHLY campaign)과 다른 축이다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) WHERE fccs.BASE_MONTH_KEY = <YYYYMM> 으로 기준연월 하나를 반드시 고정한다(「2026년 9월 기준」 = 202609). 여러 기준월을 함께 SUM 하지 않는다. (2) 누계중단율 = SUM(CUM_STOP_CNT) / NULLIF(SUM(CUM_DEV_CNT) + SUM(YEAR_START_ACTIVE_CNT), 0) * 100 — 행별 비율을 평균내지 않는다. (3) 결과에 누계중단(건)·누계개발(건)·연도초활동회원(건)·누계중단율(%)을 함께 보이고 ROLLUP 전체 행을 붙인다. (4) (미매핑) 행을 빼지 말고 그대로 보인다(전체 합 정합). (5) 분모가 0 이거나 매우 작은 캠페인의 비율은 해석에 주의하라고 밝힌다.'
  AI_VERIFIED_QUERIES (
    vqr_o236_campaign_cum_stop_rate AS (
      QUESTION '2026년 9월 기준 캠페인별 누계중단율'
      VERIFIED_BY '(DW = O236 · 전 캠페인 합 = FMM 2026-01~09 합 · 전사 13.78%)'
      SQL 'SELECT campaign.CAMPAIGN_NAME, SUM(fccs.CUM_STOP_CNT) AS CUM_STOP, SUM(fccs.CUM_DEV_CNT) AS CUM_DEV, SUM(fccs.YEAR_START_ACTIVE_CNT) AS YEAR_START_ACTIVE, SUM(fccs.CUM_STOP_CNT) / NULLIF(SUM(fccs.CUM_DEV_CNT) + SUM(fccs.YEAR_START_ACTIVE_CNT), 0) * 100 AS CUM_STOP_RATE FROM fccs LEFT JOIN campaign ON fccs.CAMPAIGN_SK = campaign.CAMPAIGN_SK WHERE fccs.BASE_MONTH_KEY = 202609 GROUP BY ROLLUP (campaign.CAMPAIGN_NAME) ORDER BY CUM_STOP DESC NULLS FIRST'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_CUM_STOP TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_CUM_STOP TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_CAMPAIGN_CUM_STOP TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인) — SV 지표 = 팩트 직접 합(2026-09 기준)
SELECT (SELECT CUM_STOP_RATE FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_CAMPAIGN_CUM_STOP DIMENSIONS fccs.BASE_MONTH_KEY METRICS fccs.CUM_STOP_RATE) WHERE BASE_MONTH_KEY = 202609) AS sv_rate,
       (SELECT SUM(CUM_STOP_CNT) / NULLIF(SUM(CUM_DEV_CNT) + SUM(YEAR_START_ACTIVE_CNT), 0) * 100
          FROM GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP WHERE BASE_MONTH_KEY = 202609) AS fact_rate;
