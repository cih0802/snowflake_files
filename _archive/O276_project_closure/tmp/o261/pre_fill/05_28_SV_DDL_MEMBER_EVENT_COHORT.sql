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
      COMMENT = '개발인입경로(사건 시점). 후원중단 사건은 원천에 없어 NULL.',
    mec.CMPGN_CTGR_NM_AT_EVENT AS mec.CMPGN_CTGR_NM_AT_EVENT
      WITH SYNONYMS ('캠페인카테고리')
      COMMENT = '캠페인카테고리(사건 시점).',
    mec.AGE_BAND_AT_EVENT AS mec.AGE_BAND_AT_EVENT
      WITH SYNONYMS ('연령대')
      COMMENT = '연령대(사건 시점 · 현재 나이 아님).',
    mec.GENDER_AT_EVENT AS mec.GENDER_AT_EVENT
      WITH SYNONYMS ('성별')
      COMMENT = '성별(사건 시점).',
    mec.NEW_EXISTING_FLAG AS mec.NEW_EXISTING_FLAG
      WITH SYNONYMS ('신규기존 구분')
      COMMENT = '신규/기존 구분(사건 시점).',
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
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭(동의어 첫 항목 + 단위). [O241-R] 비율은 ROUND(<식>, 2)::NUMBER(38,2). 핵심 규칙: (1) WHERE 에 DVLP_DIV_NM 1개와 MONTHS_AFTER 1개를 반드시 넣는다(「12개월 내 증액」 = MONTHS_AFTER = 12). (2) 사건월 미지정 시 관측이 끝난 최근 12개 사건월(EVENT_MONTH_KEY)로 한정하고 기간을 밝힌다. (3) 개발 당일 발송 질문은 MONTHS_AFTER = 0.'
;

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT_COHORT TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT_COHORT TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT_COHORT TO ROLE GN_DW_SERVICE;

-- 스모크
USE WAREHOUSE GN_DW_ANALYTICS_WH;
SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT_COHORT
  DIMENSIONS mec.DVLP_DIV_NM METRICS mec.EVENT_MEMBERS, mec.ACTIVE_RATE
  WHERE mec.MONTHS_AFTER = 12);
