-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_AD_INFLOW_ALLOC ( O249 · O250-E 단독 파일로 이관)
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_AD_INFLOW_ALLOC
-- Run order  : 운영계 #44
-- Depends on : GN_DW.GOLD.FACT_AD_INFLOW_ALLOC, GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
-- Issue      : O249, O250-E
-- =============================================================================
-- ============================================================================
-- 05_27_SV_DDL_AD_INFLOW_ALLOC.sql — Semantic View DDL 정본: SV_AD_INFLOW_ALLOC ( O249 · O250-E 단독 파일로 이관)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 대상 = 광고비 → 개발인입경로 배분 · 인입경로별 개발단가 (마케팅 Agent · analyst_ad_inflow_alloc)
--   · 선행 = GN_DW.GOLD.FACT_AD_INFLOW_ALLOC · DIM_MARKETING_CAMPAIGN(03_top-down_gold/06_DDL.sql · dbt build)
--   · 원 배포 파일 = 35_DEPLOY_SV_AD_INFLOW_EVENT_COHORT.sql(이력 보존 · 문면 무변경 이관)
--   · 공통 규약 = 05_0_SV_DDL.sql
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_AD_INFLOW_ALLOC
  TABLES (
    aia AS GN_DW.GOLD.FACT_AD_INFLOW_ALLOC
      WITH SYNONYMS ('인입경로별 광고비', '광고비 배분', '인입경로별 개발단가')
      COMMENT = '광고비 → 개발인입경로 배분 (base: GOLD.FACT_AD_INFLOW_ALLOC). [Grain: 월 × 마케팅캠페인 × 인입경로 × 행종류]. 배분 = 광고원천별 허용 인입경로 안에서 같은 월·마케팅캠페인의 CRM 개발(건) 비중. 🔴 배분값이며 실측 광고비가 아니다.',
    mk AS GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
      PRIMARY KEY (MKTG_CAMPAIGN_SK)
      WITH SYNONYMS ('마케팅캠페인')
      COMMENT = '마케팅캠페인 차원(현재값).'
  )
  RELATIONSHIPS (
    aia_to_mk AS aia (MKTG_CAMPAIGN_SK) REFERENCES mk
  )
  DIMENSIONS (
    aia.MONTH_KEY AS aia.MONTH_KEY
      WITH SYNONYMS ('실적월', '연월', '월')
      COMMENT = '실적월 YYYYMM 정수(광고 실적일 · 개발 사건일 같은 월).',
    aia.INFLOW_PATH AS aia.INFLOW_PATH
      WITH SYNONYMS ('개발인입경로', '인입경로', '유입경로')
      COMMENT = '개발인입경로(사건 시점 동결값). NULL = 미배분 행 또는 인입경로가 비어 있는 개발 — 숨기지 말고 「(미배분)」으로 따로 보인다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''뉴미디어''·''디지털''·''방송''·''영상광고''·''오프라인''·''재송출''·''콜개발''',
    aia.ROW_KIND AS aia.ROW_KIND
      WITH SYNONYMS ('행 종류', '배분 구분')
      COMMENT = '실제값: ''ALLOC''(허용 경로 · 광고비 배분) · ''NOT_ALLOWED''(광고 캠페인의 비허용 경로 개발 · 광고비 0) · ''UNALLOC''(광고비를 배분할 개발 없음). 개발단가는 ALLOC 만 쓴다.',
    aia.UNALLOC_REASON AS aia.UNALLOC_REASON
      WITH SYNONYMS ('미배분 사유')
      COMMENT = 'ROW_KIND = UNALLOC 일 때만. 실제값: ''UNMAPPED_CAMPAIGN''(광고행 마케팅캠페인 미매핑) · ''NO_ALLOWED_DEV''(그 달 허용 경로 개발 0).',
    mk.MKTG_CAMPAIGN_NAME AS mk.MKTG_CAMPAIGN_NAME
      WITH SYNONYMS ('마케팅캠페인명', '캠페인명')
      COMMENT = '마케팅캠페인명. SK 0 = 미매핑(마스터에 연결되지 않은 광고행).',
    mk.CMPGN_CTGR_NM AS mk.CMPGN_CTGR_NM
      WITH SYNONYMS ('캠페인카테고리')
      COMMENT = '마케팅캠페인의 캠페인카테고리(현재값).'
  )
  METRICS (
    aia.TOTAL_AD_COST_ALLOC AS SUM(aia.AD_COST_ALLOC)
      WITH SYNONYMS ('배분 광고비', '광고비')
      COMMENT = '배분 광고비 합(원). 🔴 배분값 · 전 행 합 = 원천 광고비 합(FACT_AD_PERFORMANCE).',
    aia.TOTAL_AD_COST_DIGITAL AS SUM(aia.AD_COST_DIGITAL)
      WITH SYNONYMS ('디지털 광고비')
      COMMENT = '배분 광고비 중 디지털 원천분(원).',
    aia.TOTAL_AD_COST_VIDEO AS SUM(aia.AD_COST_VIDEO)
      WITH SYNONYMS ('방송광고비', '영상 광고비')
      COMMENT = '배분 광고비 중 방송광고(VIDEO) 원천분(원). 🔴 허용 경로(영상광고·방송·콜개발·디지털)는 현업 확인 전 가정.',
    aia.TOTAL_AD_COST_REBROADCAST AS SUM(aia.AD_COST_REBROADCAST)
      WITH SYNONYMS ('재방송 광고비')
      COMMENT = '배분 광고비 중 재방송 원천분(원).',
    aia.TOTAL_DEV_CNT AS SUM(aia.DEV_CNT)
      WITH SYNONYMS ('개발(건)', '개발건수')
      COMMENT = '개발(건) = MSTR 인정금액 ÷ 10,000. UNALLOC 행은 NULL.',
    aia.COST_PER_DEV AS SUM(IFF(aia.ROW_KIND = 'ALLOC', aia.AD_COST_ALLOC, 0)) / NULLIF(SUM(IFF(aia.ROW_KIND = 'ALLOC', aia.DEV_CNT, 0)), 0)
      WITH SYNONYMS ('개발단가', '인입경로별 개발단가', '건당 광고비')
      COMMENT = '개발단가(원/건) = ALLOC 행 배분 광고비 ÷ ALLOC 행 개발(건). 🔴 배분 추정치 · 실측 단가 아님.'
  )
  COMMENT = '광고비 인입경로 배분 SV(O248 · 인입경로별 개발단가). base=GOLD.FACT_AD_INFLOW_ALLOC. 🔴🔴 배분값이며 실측이 아니다 — 광고 실적 SV(SV_AD)의 광고비와 같은 표에 합산하지 않는다(같은 돈을 다시 나눈 것). 🔴 광고비 ÷ CRM 개발건수를 직접 나누지 말고 이 SV 의 개발단가(COST_PER_DEV)를 쓴다. 🔴 VIDEO(방송광고) 허용 인입경로 = 영상광고·방송·콜개발·디지털은 현업 확인 전 가정이며, VIDEO 미배분분은 방송 효과 시차(익월 개발) 가능성이 있다. 미배분(UNALLOC) 광고비를 숨기지 말고 사유와 함께 따로 밝힌다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다. [공통 규칙 보충 · 이 SV] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(동의어 첫 항목 + 단위). (R-SV3) 「미배분」·「배분 불가」처럼 구분 값을 가진 행은 합계·소계 행이 아니다 — 아래 핵심 규칙이 그 행을 따로 붙이라고 하면 공통 규칙의 합계·소계 행 금지와 충돌하지 않는다. [O241-R] 비율·단가 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2).
  핵심 규칙: (1) 개발단가는 COST_PER_DEV 만 쓴다(ROW_KIND ALLOC 한정 산식 내장). (2) 인입경로별 표에는 미배분(UNALLOC) 광고비 합을 별도 행으로 붙인다. (3) 기간 미지정 시 최근 12개월 MONTH_KEY 로 한정하고 기간을 밝힌다.'
;

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD_INFLOW_ALLOC TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD_INFLOW_ALLOC TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD_INFLOW_ALLOC TO ROLE GN_DW_AR_SRC_AGENCY;  -- O270 원천별 접근 역할
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD_INFLOW_ALLOC TO ROLE GN_DW_SERVICE;

-- 스모크
USE WAREHOUSE GN_DW_ANALYTICS_WH;
SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD_INFLOW_ALLOC
  DIMENSIONS aia.ROW_KIND METRICS aia.TOTAL_AD_COST_ALLOC, aia.TOTAL_DEV_CNT);
