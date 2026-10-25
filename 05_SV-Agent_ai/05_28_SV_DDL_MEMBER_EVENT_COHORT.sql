-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_MEMBER_EVENT_COHORT (🆕 O249 · O250-E 단독 파일로 이관)
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT_COHORT
-- Run order  : 운영계 #45
-- Depends on : GN_DW.GOLD.FACT_MEMBER_EVENT_COHORT
-- Issue      : O249, O250-E
-- =============================================================================
-- ============================================================================
-- 05_28_SV_DDL_MEMBER_EVENT_COHORT.sql — Semantic View DDL 정본: SV_MEMBER_EVENT_COHORT ( O249 · O250-E 단독 파일로 이관)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 대상 = 회원 개발사건 × 경과월(0~12) 코호트 (회원 Agent · analyst_member_event_cohort)
--   · 선행 = GN_DW.GOLD.FACT_MEMBER_EVENT_COHORT(03_top-down_gold/06_DDL.sql · dbt build)
--   · 원 배포 파일 = 35_DEPLOY_SV_AD_INFLOW_EVENT_COHORT.sql(이력 보존 · 문면 무변경 이관)
--   · 공통 규약 = 05_0_SV_DDL.sql
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT_COHORT
  TABLES (
    mec AS GN_DW.GOLD.FACT_MEMBER_EVENT_COHORT
      WITH SYNONYMS ('개발사건 코호트', '개발 후 경과', '신규 후 증액', '개발 후 유지')
      COMMENT = '개발사건 × 경과월 코호트 (base: GOLD.FACT_MEMBER_EVENT_COHORT). [Grain: 회원 × 사건월 × 개발구분 × 경과월(0~12)]. 사건 시점 속성은 동결값.'
  )
  DIMENSIONS (
    mec.EVENT_MONTH_KEY AS mec.EVENT_MONTH_KEY
      WITH SYNONYMS ('사건월', '개발월', '코호트월')
      COMMENT = '사건월 YYYYMM 정수(코호트 기준).',
    mec.DVLP_DIV_NM AS mec.DVLP_DIV_NM
      WITH SYNONYMS ('개발구분')
      COMMENT = '개발구분. 실제값: ''신규''·''증액''·''재후원''·''감액''·''후원중단''. 🔴 하나로 고정해 센다.',
    mec.MONTHS_AFTER AS mec.MONTHS_AFTER
      WITH SYNONYMS ('경과월', '개발 후 경과월')
      COMMENT = '경과월 0~12(0 = 사건월). 🔴🔴 경과월 하나를 고정해 센다 — 여러 경과월을 합하면 회원을 중복 계상한다.',
    mec.IS_OBSERVABLE AS mec.IS_OBSERVABLE
      WITH SYNONYMS ('관측 가능')
      COMMENT = '관측월이 현재월 이하인가. 유지율·후속 사건 비율은 TRUE 로 한정한다(미래 관측월 제외).',
    mec.MKTG_CMPGN_NM_AT_EVENT AS mec.MKTG_CMPGN_NM_AT_EVENT
      WITH SYNONYMS ('마케팅캠페인명')
      COMMENT = '마케팅캠페인명(사건 시점).',
    mec.INFLOW_PATH_AT_EVENT AS mec.INFLOW_PATH_AT_EVENT
      WITH SYNONYMS ('개발인입경로', '인입경로')
      COMMENT = '개발인입경로(사건 시점). 후원중단 사건은 원천에 없어 NULL. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''교육기관''·''기타 기업개발''·''뉴미디어''·''대면모금''·''디지털''·''방송''·''영상광고''·''오프라인''·''일시''·''재송출''·''지역개발''·''콜개발''',
    mec.CMPGN_CTGR_NM_AT_EVENT AS mec.CMPGN_CTGR_NM_AT_EVENT
      WITH SYNONYMS ('캠페인카테고리')
      COMMENT = '캠페인카테고리(사건 시점).',
    mec.AGE_BAND_AT_EVENT AS mec.AGE_BAND_AT_EVENT
      WITH SYNONYMS ('연령대')
      COMMENT = '연령대(사건 시점 · 현재 나이 아님). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''10대''·''10대 미만''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''70대 이상''·''기업''·''기타''·''단체''',
    mec.GENDER_AT_EVENT AS mec.GENDER_AT_EVENT
      WITH SYNONYMS ('성별')
      COMMENT = '성별(사건 시점). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''국내(남자)''·''국내(여자)''·''기업''·''기타''·''단체''·''외국인(기타)''·''외국인(남자)''·''외국인(여자)''',
    mec.NEW_EXISTING_FLAG AS mec.NEW_EXISTING_FLAG
      WITH SYNONYMS ('신규기존 구분')
      COMMENT = '신규/기존 구분(사건 시점). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''기존''·''신규''',
    mec.AMOUNT_BAND2_AT_EVENT AS mec.AMOUNT_BAND2_AT_EVENT
      WITH SYNONYMS ('후원금액대')
      COMMENT = '사건월 후원금액대(1만 단위). NULL = 약정 없음 또는 사건월 월실적 행 없음.'
  )
  METRICS (
    mec.EVENT_MEMBERS AS COUNT(DISTINCT mec.MEMBER_DK)
      WITH SYNONYMS ('사건 회원수', '개발 회원수')
      COMMENT = '사건 회원수(명) — 중복제거(경과월 필터와 무관하게 같은 값).',
    mec.EVENT_DEV_CNT_TOTAL AS SUM(IFF(mec.MONTHS_AFTER = 0, mec.EVENT_DEV_CNT, 0))
      WITH SYNONYMS ('개발(건)')
      COMMENT = '사건 개발(건) = MSTR 인정금액 ÷ 10,000 — 경과월 0 행에만 값이 있다 ⇒ 경과월을 0 으로 두거나 경과월 필터 없이 쓴다.',
    mec.OBS_MEMBERS AS COUNT(DISTINCT IFF(mec.IS_OBSERVABLE, mec.MEMBER_DK, NULL))
      WITH SYNONYMS ('관측 대상 회원수')
      COMMENT = '관측 가능 회원수(명) — 유지율·후속 사건 비율의 분모. 경과월 하나를 고정해서 쓴다.',
    mec.ACTIVE_RATE AS COUNT(DISTINCT IFF(mec.IS_OBSERVABLE AND mec.ACTIVE_FLAG, mec.MEMBER_DK, NULL)) / NULLIF(COUNT(DISTINCT IFF(mec.IS_OBSERVABLE, mec.MEMBER_DK, NULL)), 0) * 100
      WITH SYNONYMS ('유지율', '활동 유지율')
      COMMENT = '경과월 시점 월말 활동 유지율(%) = 활동 회원 ÷ 관측 회원 × 100. 경과월 하나를 고정한다.',
    mec.INC_BY_RATE AS COUNT(DISTINCT IFF(mec.IS_OBSERVABLE AND mec.INC_BY_FLAG, mec.MEMBER_DK, NULL)) / NULLIF(COUNT(DISTINCT IFF(mec.IS_OBSERVABLE, mec.MEMBER_DK, NULL)), 0) * 100
      WITH SYNONYMS ('후속 증액 비율', '신규 후 증액 비율')
      COMMENT = '관측월까지 후속 증액이 일어난 회원 비율(%).',
    mec.STOP_BY_RATE AS COUNT(DISTINCT IFF(mec.IS_OBSERVABLE AND mec.STOP_BY_FLAG, mec.MEMBER_DK, NULL)) / NULLIF(COUNT(DISTINCT IFF(mec.IS_OBSERVABLE, mec.MEMBER_DK, NULL)), 0) * 100
      WITH SYNONYMS ('후속 중단 비율')
      COMMENT = '관측월까지 후속 후원중단이 일어난 회원 비율(%).',
    mec.AT_D0_MEMBERS AS COUNT(DISTINCT IFF(mec.AT_D0_AUTO_FLAG OR mec.AT_D0_MANUAL_FLAG, mec.MEMBER_DK, NULL))
      WITH SYNONYMS ('개발 당일 알림톡 수신 회원수')
      COMMENT = '첫 사건일 당일 알림톡(자동·수동) 수신 회원수(명).',
    mec.SND_OPEN_MEMBERS AS COUNT(DISTINCT IFF(mec.SND_D0_5_OPEN_FLAG, mec.MEMBER_DK, NULL))
      WITH SYNONYMS ('문자 오픈 회원수')
      COMMENT = 'D0~5 문자 링크 클릭(오픈) 회원수(명). 🔴 알림톡·메일·우편은 오픈 원천이 없다.'
  )
  COMMENT = '회원 개발사건 코호트 SV(O248 · 회원 Agent 전용). base=GOLD.FACT_MEMBER_EVENT_COHORT. 「신규 후 N개월 증액·유지·중단」·「개발 당일 알림톡·문자 오픈」 질문에 쓴다. 🔴🔴 개발구분 하나와 경과월 하나를 고정한다(경과월 합산 = 회원 중복). 🔴 비율은 IS_OBSERVABLE 회원만 분모로 쓴다. 🔴 발송 수신·오픈과 후속 사건의 차이는 인과가 아니다. 🔴 개발건수 실적 정본은 SV_MEMBER_EVENT 이며 같은 표에 합산하지 않는다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다. [공통 규칙 보충 · 이 SV] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭(동의어 첫 항목 + 단위). [O241-R] 비율은 ROUND(<식>, 2)::NUMBER(38,2).
  핵심 규칙: (1) WHERE 에 DVLP_DIV_NM 1개와 MONTHS_AFTER 1개를 반드시 넣는다(「12개월 내 증액」 = MONTHS_AFTER = 12). (2) 사건월 미지정 시 관측이 끝난 최근 12개 사건월(EVENT_MONTH_KEY)로 한정하고 기간을 밝힌다. (3) 개발 당일 발송 질문은 MONTHS_AFTER = 0.'
;

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT_COHORT TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT_COHORT TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT_COHORT TO ROLE GN_DW_SERVICE;

-- 스모크
USE WAREHOUSE GN_DW_ANALYTICS_WH;
SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT_COHORT
  DIMENSIONS mec.DVLP_DIV_NM METRICS mec.EVENT_MEMBERS, mec.ACTIVE_RATE
  WHERE mec.MONTHS_AFTER = 12);
