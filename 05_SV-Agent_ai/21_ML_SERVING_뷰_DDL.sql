-- ============================================================================
-- GN_DW.SERVING ML 예측 뷰 DDL — Semantic View(22_ML_SV_DDL) 의 base 계층 · 구조 정본
--   · GN_DW.ML 예측결과 테이블만 감싼다(학습·중간 테이블 비노출). SV 는 이 뷰만 base 로 쓴다.
--   · 뷰를 끼우는 이유 = ML 테이블 교체 내성 · VARIANT(PREDICTION/PREDICT) 평탄화 · 회원 예측 중복 단일화.
--   · 실행 = GN_DW_ADMIN · 선행 = GN_DW.ML 결과 테이블 적재(dbt 무관).
--   · 컬럼 COMMENT 는 뷰 정의 안에 있다 — 재생성해도 유지된다. GRANT 는 재생성 시 사라지므로 같은 파일 말미에 있다.
--   · 🔴 ⛔ 표식 구간 = 원천 삭제로 비활성인 코드(되살리려면 새 사용자 결정).
--   · 설계근거·실측 이력 = 21_ML_SERVING_뷰_설계이력_부록.md · 설계 = 20_ML_SV_설계.md
--
--   🆕 2026-10-02 O198 · ML 이관 범위 12종 기준 재정렬 (정본 = 50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql)
--     · 분류 4종 피처 컬럼 제거 ⇒ ML_MEMBER_RISK_V / ML_SPONSOR_RISK_V 에서 피처·피처 기반 라벨 컬럼 삭제.
--       └ 회원 예측 중복 단일화 기준(월말 상태 spell · MBER_STAT_CD)이 원천에서 사라졌다 ⇒ 키 단위 집계로 교체
--         (확률 = 중복행 평균 · 분류 = 하나라도 '1' 이면 '1' · 중복 행수 컬럼 발행). 실측 202606: 101,817 키 중 16,290 키 중복.
--     · SPNSR_CHURN_12M 의 CMPGN_CD → CMPGN_CTGR_CD ⇒ 캠페인·상위캠페인 축 삭제 · 캠페인카테고리 축으로 교체.
--     · 시계열 SERIES → 의미 컬럼명(CMPGN_CTGR_CD · CMPGN_CD · MKTG_CHANNEL).
--     · LTV 4종(UCMPGN_LTV · UCMPGN_LTV_SCORE · CMPGN_LTV · CMPGN_LTV_SCORE) 이관 제외 ⇒
--       ML_LTV_FORECAST_V 는 신규 2종(MKTG_CHANNEL_MBER_AVG_LTV · CMPGN_SPNSR_AMT_LTV)으로 재구성 · ML_LTV_SCORE_V 는 ⛔ 폐기.
--       🔴 CMPGN_SPNSR_AMT_LTV.MKTG_CHANNEL 은 이름과 달리 **캠페인코드**다(실측 50/50 이 CMPGN_CD 일치 · MKTG_CHANNEL 일치 4는 숫자 우연) — 원천 확인 대상.
--     · CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION 의 FEATURE_TYPE 제거 ⇒ 해당 유형은 NULL.
--     · ONCE_CONVERSION 이 (STDR_MT, ONCE_MBER_NO, PREDICT) 3컬럼 · STDR_MT 단일(202606) ⇒ 「관측월(가입월부터 6개월)」 해석 폐기,
--       STDR_MT = 기준월(다른 ML 뷰와 동일 의미)로 재정의. 회원당 다중 예측행은 DEC-59 #1 대로 유지.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

-- [1] ML_MEMBER_RISK_V — ML 회원단위 예측(중단·증액·충성) 통합
--   ⚠️ 원천(중단·증액)이 같은 기준월에 회원당 여러 행(확률 상이)을 담는다 — 실행 순번 컬럼이 없어 최신을 고를 수 없다.
--      ⇒ 키 단위 집계: 확률 = 평균 · 분류 = MAX(하나라도 '1') · *_PRED_ROWS 로 중복 수를 드러낸다(임의 행 선택 금지).
--   ⚠️ 중단 예측 지평은 발행하지 않는다(테이블명 12M · 원천 테이블 COMMENT 6개월 · 확인 전 기간 미기재).
--   ⚠️ 충성회원은 모집단이 다르다 — FULL 결합 · NULL 허용.
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_MEMBER_RISK_V (
    STDR_MT                COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
    STDR_MONTH_KEY         COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
    MBER_NO                COMMENT '정기회원번호(7자리 TEXT) [원천: ML 회원 예측]',
    CHURN_PROB             COMMENT '중단 예측 확률(0~1) — 원천 중복행 평균 · 예측 지평은 발행하지 않는다(원천 기간 표기 불일치)',
    CHURN_CLASS            COMMENT '중단 예측 분류(모델 class) — 원천 중복행 중 하나라도 1 이면 1 · 업무 판정선 아님',
    CHURN_PRED_ROWS        COMMENT '이 회원·기준월의 원천 중단 예측 행수 — 1 초과 = 원천 중복(평균으로 단일화됨)',
    INC_PROB               COMMENT '증액 예측 확률(0~1) — 원천 중복행 평균',
    INC_CLASS              COMMENT '증액 예측 분류(모델 class) — 원천 중복행 중 하나라도 1 이면 1',
    INC_PRED_ROWS          COMMENT '이 회원·기준월의 원천 증액 예측 행수 — 1 초과 = 원천 중복',
    LOYAL_PROB             COMMENT '충성회원 예측 확률(0~1) — 모집단이 중단·증액과 다르다(HAS_LOYAL_PRED)',
    LOYAL_CLASS            COMMENT '충성회원 예측 분류(모델 class)',
    HAS_CHURN_PRED         COMMENT '중단 예측 존재 여부 — 분모 판정용',
    HAS_INC_PRED           COMMENT '증액 예측 존재 여부 — 분모 판정용',
    HAS_LOYAL_PRED         COMMENT '충성 예측 존재 여부 — 분모 판정용(모집단 상이)',
    PREDICTION_HAS_ERROR   COMMENT '예측 로그에 오류가 있는 행 여부(PREDICTION:logs:Error 비어있지 않음) · 3종·중복행 중 하나라도',
    CHURN_GRADE            COMMENT '중단위험 등급(F-4) — 기준월 내 백분위: 상위 10% 고위험 · 10~25% 주의 · 나머지 일반 · 예측 없음 NULL. 🔴 확률 임계가 아니라 순위다',
    LOYAL_GRADE            COMMENT '장기회원 등급(F-4) — 기준월 내 백분위: 상위 5% 최상위 · 5~10% 상 · 10~25% 중 · 나머지 하 · 충성 예측 모집단만(그 외 NULL)'
)
  COMMENT = 'ML 회원단위 예측(중단·증액·충성) 통합. grain=기준월×회원(키 집계 후 유일). 원천 중복행은 확률 평균·분류 MAX 로 단일화했다(원천 미해소·완화 · 이후 피처 컬럼 없음). 예측치이며 실적이 아니다.'
AS
WITH churn AS (
  SELECT STDR_MT,
         MBER_NO,
         AVG(PREDICTION:probability:"1"::FLOAT)            AS CHURN_PROB,
         MAX(PREDICTION:class::VARCHAR)                     AS CHURN_CLASS,
         COUNT(*)                                           AS CHURN_PRED_ROWS,
         BOOLOR_AGG(ARRAY_SIZE(PREDICTION:logs:Error) > 0)  AS CHURN_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M
  GROUP BY 1, 2
),
inc AS (
  SELECT STDR_MT,
         MBER_NO,
         AVG(PREDICTION:probability:"1"::FLOAT)            AS INC_PROB,
         MAX(PREDICTION:class::VARCHAR)                     AS INC_CLASS,
         COUNT(*)                                           AS INC_PRED_ROWS,
         BOOLOR_AGG(ARRAY_SIZE(PREDICTION:logs:Error) > 0)  AS INC_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_MBER_INC_12M
  GROUP BY 1, 2
),
loyal AS (
  -- 실측 202606: 43,498행 = 43,498키(중복 없음). 원천 변경 대비 같은 방식으로 집계한다.
  SELECT STDR_MT,
         MBER_NO,
         AVG(PREDICTION:probability:"1"::FLOAT)            AS LOYAL_PROB,
         MAX(PREDICTION:class::VARCHAR)                     AS LOYAL_CLASS,
         BOOLOR_AGG(ARRAY_SIZE(PREDICTION:logs:Error) > 0)  AS LOYAL_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_LOYAL_MBER
  GROUP BY 1, 2
),
u AS (
  SELECT STDR_MT, MBER_NO FROM churn
  UNION
  SELECT STDR_MT, MBER_NO FROM inc
  UNION
  SELECT STDR_MT, MBER_NO FROM loyal
)
SELECT
    u.STDR_MT                                    AS STDR_MT,
    TO_NUMBER(u.STDR_MT)                         AS STDR_MONTH_KEY,
    u.MBER_NO                                    AS MBER_NO,
    c.CHURN_PROB                                 AS CHURN_PROB,
    c.CHURN_CLASS                                AS CHURN_CLASS,
    c.CHURN_PRED_ROWS                            AS CHURN_PRED_ROWS,
    i.INC_PROB                                   AS INC_PROB,
    i.INC_CLASS                                  AS INC_CLASS,
    i.INC_PRED_ROWS                              AS INC_PRED_ROWS,
    l.LOYAL_PROB                                 AS LOYAL_PROB,
    l.LOYAL_CLASS                                AS LOYAL_CLASS,
    c.MBER_NO IS NOT NULL                        AS HAS_CHURN_PRED,
    i.MBER_NO IS NOT NULL                        AS HAS_INC_PRED,
    l.MBER_NO IS NOT NULL                        AS HAS_LOYAL_PRED,
    COALESCE(c.CHURN_HAS_ERROR, FALSE)
      OR COALESCE(i.INC_HAS_ERROR, FALSE)
      OR COALESCE(l.LOYAL_HAS_ERROR, FALSE)      AS PREDICTION_HAS_ERROR,
    CASE WHEN c.CHURN_PROB IS NULL THEN NULL
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, c.CHURN_PROB IS NULL ORDER BY c.CHURN_PROB DESC) < 0.10 THEN '고위험'
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, c.CHURN_PROB IS NULL ORDER BY c.CHURN_PROB DESC) < 0.25 THEN '주의'
         ELSE '일반' END                          AS CHURN_GRADE,
    CASE WHEN l.LOYAL_PROB IS NULL THEN NULL
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, l.LOYAL_PROB IS NULL ORDER BY l.LOYAL_PROB DESC) < 0.05 THEN '최상위'
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, l.LOYAL_PROB IS NULL ORDER BY l.LOYAL_PROB DESC) < 0.10 THEN '상'
         WHEN PERCENT_RANK() OVER (PARTITION BY u.STDR_MT, l.LOYAL_PROB IS NULL ORDER BY l.LOYAL_PROB DESC) < 0.25 THEN '중'
         ELSE '하' END                            AS LOYAL_GRADE
FROM u
LEFT JOIN churn c ON c.STDR_MT = u.STDR_MT AND c.MBER_NO = u.MBER_NO
LEFT JOIN inc   i ON i.STDR_MT = u.STDR_MT AND i.MBER_NO = u.MBER_NO
LEFT JOIN loyal l ON l.STDR_MT = u.STDR_MT AND l.MBER_NO = u.MBER_NO;

-- [2] ML_SPONSOR_RISK_V — ML 후원건단위 이탈 예측
--   🆕 O198: 원천 6컬럼(STDR_MT, MBER_NO, SPNSR_BSNS_ID, SPNSR_BSNS_NO, CMPGN_CTGR_CD, PREDICTION).
--      캠페인코드·결제수단·피처(유지기간·금액·변경건수 등)는 원천에서 제거됐다 ⇒ 캠페인/상위캠페인 축·금액 지표 삭제.
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_SPONSOR_RISK_V (
    STDR_MT              COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
    STDR_MONTH_KEY       COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
    MBER_NO              COMMENT '회원번호 — 회원수는 COUNT(DISTINCT) 로 센다(후원건 grain)',
    SPNSR_BSNS_ID        COMMENT '후원사업ID [원천]',
    SPNSR_BSNS_NAME      COMMENT '후원사업명(SILVER.CRM_SPONSORSHIP) — 미매칭 NULL',
    SPNSR_BSNS_NO        COMMENT '후원사업번호(약정) [원천]',
    CMPGN_CTGR_CD        COMMENT '캠페인카테고리코드 [원천]',
    CMPGN_CTGR_NAME      COMMENT '캠페인카테고리명(캠페인 마스터 DISTINCT · 코드당 1개 실측) — 미매칭 NULL',
    CHURN_PROB           COMMENT '후원건 이탈 예측 확률(0~1) · 예측 지평 미발행',
    CHURN_CLASS          COMMENT '이탈 예측 분류(모델 class) — 업무 판정선 아님',
    PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICTION:logs:Error 비어있지 않음)',
    CHURN_GRADE          COMMENT '후원건 이탈위험 등급(F-4) — 기준월 내 후원건 백분위: 상위 5% 고위험 · 5~25% 주의 · 나머지 일반. 🔴 확률 임계가 아니라 순위다'
)
  COMMENT = 'ML 후원건단위 이탈 예측. grain=기준월×회원×후원사업ID×후원사업번호(실측 유일). 회원수는 반드시 중복제거로 센다. 예측치이며 실적이 아니다.'
AS
SELECT
    r.STDR_MT                                     AS STDR_MT,
    TO_NUMBER(r.STDR_MT)                          AS STDR_MONTH_KEY,
    r.MBER_NO                                     AS MBER_NO,
    r.SPNSR_BSNS_ID                               AS SPNSR_BSNS_ID,
    sp.SPNSR_BSNS_NM                              AS SPNSR_BSNS_NAME,
    r.SPNSR_BSNS_NO                               AS SPNSR_BSNS_NO,
    r.CMPGN_CTGR_CD                               AS CMPGN_CTGR_CD,
    ctgr.CMPGN_CTGR_NM                            AS CMPGN_CTGR_NAME,
    r.PREDICTION:probability:"1"::FLOAT            AS CHURN_PROB,
    r.PREDICTION:class::VARCHAR                    AS CHURN_CLASS,
    ARRAY_SIZE(r.PREDICTION:logs:Error) > 0        AS PREDICTION_HAS_ERROR,
    CASE WHEN r.PREDICTION:probability:"1"::FLOAT IS NULL THEN NULL
         WHEN PERCENT_RANK() OVER (PARTITION BY r.STDR_MT, r.PREDICTION:probability:"1"::FLOAT IS NULL
                                   ORDER BY r.PREDICTION:probability:"1"::FLOAT DESC) < 0.05 THEN '고위험'
         WHEN PERCENT_RANK() OVER (PARTITION BY r.STDR_MT, r.PREDICTION:probability:"1"::FLOAT IS NULL
                                   ORDER BY r.PREDICTION:probability:"1"::FLOAT DESC) < 0.25 THEN '주의'
         ELSE '일반' END                             AS CHURN_GRADE
FROM GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M r
LEFT JOIN GN_DW.SILVER.CRM_SPONSORSHIP sp ON sp.SPNSR_BSNS_ID = r.SPNSR_BSNS_ID
LEFT JOIN (
    SELECT DISTINCT CMPGN_CTGR_CD::VARCHAR AS CTGR_CD, CMPGN_CTGR_NM
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE CMPGN_CTGR_CD IS NOT NULL
) ctgr ON ctgr.CTGR_CD = r.CMPGN_CTGR_CD;

-- [3] ML_DVLP_FORECAST_V — ML 개발금액 예측 2종(전사·캠페인) 통합
--   ⚠️ 단위 = 만원(회비·LTV 는 원 — 섞지 않는다) · SERIES_TYPE 간 합산은 중복계상.
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_DVLP_FORECAST_V (
    SERIES_TYPE COMMENT '계열유형: TOTAL·CAMPAIGN — 🔴 유형 간 합산은 중복계상 · 항상 고정·그룹 (부서·후원사업·신규기존은 원천 삭제로 비활성)',
    SERIES_CD   COMMENT '계열코드(유형에 따라 캠페인 코드 / (전사))',
    SERIES_NAME COMMENT '계열명(마스터 조인 라벨 · 미매칭 NULL)',
    STDR_MT     COMMENT '예측 실행 기준월 YYYYMM [원천]',
    TS          COMMENT '예측월 시작일 [원천]',
    FORECAST    COMMENT '예측 개발금액 — 🔴 단위 만원(신규+증액+재후원) [원천]',
    LOWER_BOUND COMMENT '95% 신뢰구간 하한(만원)',
    UPPER_BOUND COMMENT '95% 신뢰구간 상한(만원)'
)
  COMMENT = 'ML 개발금액 예측 2종(전사·캠페인) 통합. 부서·후원사업·신규기존 예측은 원천 삭제로 제공하지 않음. grain=기준월×계열유형×계열×예측월. 단위=만원. 계열유형 간 합산은 중복계상이다. 예측치이며 실적이 아니다.'
AS
SELECT 'TOTAL'                          AS SERIES_TYPE,
       '(전사)'                          AS SERIES_CD,
       '(전사 합계)'                      AS SERIES_NAME,
       t.STDR_MT, t.TS, t.FORECAST, t.LOWER_BOUND, t.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_DVLP_AMT t
-- ⛔ [2026-09-30] 원천 테이블 삭제로 비활성 · [2026-10-01 O196] D-3 종결 = 재활성하지 않는다(라이브 DROP · 되살리려면 새 사용자 결정)
--    기획실 3종(MONTHLY_DEPT_DVLP_AMT · MONTHLY_SPNSR_BSNS_ID_DVLP_AMT · MONTHLY_NEW_OLD_DVLP_AMT)은 O198 이관 범위에서도 제외다.
--    되살릴 경우 원천의 SERIES 컬럼명이 바뀌었는지 05번 DDL 로 먼저 확인한다(O198 에서 다른 시계열은 의미 컬럼명으로 바뀌었다).
UNION ALL
SELECT 'CAMPAIGN', c.CMPGN_CD, cm.CMPGN_NM,
       c.STDR_MT, c.TS, c.FORECAST, c.LOWER_BOUND, c.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT c
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm ON cm.CMPGN_CD = c.CMPGN_CD;

-- [4] ML_FEE_FORECAST_V — ML 캠페인카테고리별 회비(후원금액) 예측
--   ⚠️ 단위 = 원(개발금액 예측 만원과 다른 뷰에 둔 이유).
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_FEE_FORECAST_V (
    STDR_MT            COMMENT '예측 실행 기준월 YYYYMM',
    STDR_MONTH_KEY     COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
    CMPGN_CTGR_CD      COMMENT '캠페인카테고리코드(예측 계열)',
    CMPGN_CTGR_NAME    COMMENT '캠페인카테고리명(캠페인 마스터 DISTINCT) — 미매칭 NULL',
    FORECAST_TS        COMMENT '예측월 시작일',
    FORECAST_MONTH_KEY COMMENT '예측월 YYYYMM(FORECAST_TS 파생)',
    FORECAST_AMT       COMMENT '예측 회비(후원금액) — 🔴 단위 원(개발금액 예측 만원과 다름)',
    FORECAST_LOWER     COMMENT '95% 신뢰구간 하한(원)',
    FORECAST_UPPER     COMMENT '95% 신뢰구간 상한(원)'
)
  COMMENT = 'ML 캠페인카테고리별 회비(후원금액) 예측. grain=기준월×캠페인카테고리×예측월. 단위=원. 개발금액 예측(만원)과 단위가 다르므로 합산하지 않는다. 예측치이며 실적이 아니다.'
AS
SELECT
    r.STDR_MT                        AS STDR_MT,
    TO_NUMBER(r.STDR_MT)             AS STDR_MONTH_KEY,
    r.CMPGN_CTGR_CD                  AS CMPGN_CTGR_CD,
    ctgr.CMPGN_CTGR_NM               AS CMPGN_CTGR_NAME,
    r.TS                             AS FORECAST_TS,
    TO_NUMBER(TO_CHAR(r.TS,'YYYYMM')) AS FORECAST_MONTH_KEY,
    r.FORECAST                       AS FORECAST_AMT,
    r.LOWER_BOUND                    AS FORECAST_LOWER,
    r.UPPER_BOUND                    AS FORECAST_UPPER
FROM GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT r
LEFT JOIN (
    SELECT DISTINCT CMPGN_CTGR_CD::VARCHAR AS CTGR_CD, CMPGN_CTGR_NM
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE CMPGN_CTGR_CD IS NOT NULL
) ctgr ON ctgr.CTGR_CD = r.CMPGN_CTGR_CD;

-- [5] ML_LTV_FORECAST_V — ML LTV 월별 예측 2종 (🆕 O198 재구성)
--   · MKTG_CHANNEL_AVG_MEMBER = ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV (마케팅채널별 회원평균 후원금액 · 계열 = CRM_CAMPAIGN.MKTG_CHANNEL 실측 48/48)
--   · CMPGN_TOTAL             = ML_RST_DATA_CMPGN_SPNSR_AMT_LTV (월간 후원금액 · 🔴 원천 컬럼명 MKTG_CHANNEL 이나 값은 CMPGN_CD — 실측 50/50)
--   🔴 원천 테이블 COMMENT 는 둘 다 「채널별」이라 적었으나 CMPGN_SPNSR_AMT_LTV 의 실제 계열은 캠페인이다 ⇒ 원천 확인 대상(정정되면 이 조인을 바꾼다).
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_LTV_FORECAST_V (
    LTV_TYPE      COMMENT 'LTV유형: MKTG_CHANNEL_AVG_MEMBER(마케팅채널 회원평균) · CMPGN_TOTAL(캠페인 월간 후원금액) — 🔴 하나로 고정',
    LTV_TYPE_NAME COMMENT 'LTV유형 라벨',
    SERIES_CD     COMMENT '계열코드(유형별 마케팅채널 코드 / 캠페인코드) — 원천 컬럼명은 둘 다 MKTG_CHANNEL',
    SERIES_NAME   COMMENT '계열명(마케팅채널명 / 캠페인명 · 캠페인 마스터) — 미매칭 NULL',
    STDR_MT       COMMENT '예측 실행 기준월 YYYYMM',
    TS            COMMENT '예측월 시작일',
    FORECAST      COMMENT '예측값(원) — 회원평균 유형은 합산 금지',
    LOWER_BOUND   COMMENT '95% 신뢰구간 하한(원)',
    UPPER_BOUND   COMMENT '95% 신뢰구간 상한(원)'
)
  COMMENT = 'ML LTV 월별 예측 2종. MKTG_CHANNEL_AVG_MEMBER=마케팅채널별 회원평균 후원금액 · CMPGN_TOTAL=캠페인별 월간 후원금액(원천 컬럼명은 MKTG_CHANNEL 이나 값은 캠페인코드). 두 유형은 계열축과 의미가 달라 합산·비교할 수 없다. 단위=원. 예측치이며 실적이 아니다.'
AS
SELECT 'MKTG_CHANNEL_AVG_MEMBER'           AS LTV_TYPE,
       '마케팅채널 회원평균 후원금액'        AS LTV_TYPE_NAME,
       a.MKTG_CHANNEL                      AS SERIES_CD,
       ch.MKTG_CHANNEL_NM                  AS SERIES_NAME,
       a.STDR_MT, a.TS, a.FORECAST, a.LOWER_BOUND, a.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV a
LEFT JOIN (
    SELECT DISTINCT MKTG_CHANNEL::VARCHAR AS MKTG_CHANNEL, MKTG_CHANNEL_NM
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE MKTG_CHANNEL IS NOT NULL
) ch ON ch.MKTG_CHANNEL = a.MKTG_CHANNEL
UNION ALL
SELECT 'CMPGN_TOTAL',
       '캠페인 월간 후원금액',
       s.MKTG_CHANNEL,
       cm.CMPGN_NM,
       s.STDR_MT, s.TS, s.FORECAST, s.LOWER_BOUND, s.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_CMPGN_SPNSR_AMT_LTV s
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm ON cm.CMPGN_CD = s.MKTG_CHANNEL;

-- [6] ⛔ ML_LTV_SCORE_V — [2026-10-02 O198] 원천 2종(UCMPGN_LTV_SCORE · CMPGN_LTV_SCORE) 이관 제외로 폐기
--   · 신규 LTV 2종은 월별 예측만 있고 스코어(계열당 1행) 테이블이 없다 ⇒ 대체 뷰 없음.
--   · 라이브 정리(되돌릴 수 없음 — SV_ML_LTV_SCORE 와 Agent 도구 등록을 먼저 제거한 뒤 수동 실행):
--     DROP VIEW IF EXISTS GN_DW.SERVING.ML_LTV_SCORE_V;
--   · 되살리려면 원천 스코어 테이블 재공급 + 새 사용자 결정이 필요하다. 구 정의 = 라이브 GET_DDL('VIEW','GN_DW.SERVING.ML_LTV_SCORE_V') (DROP 전).

-- [7] ML_FEATURE_IMPORTANCE_V — ML 요인분석(피처 중요도) 2종
--   🆕 O198: CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION 에서 FEATURE_TYPE 이 제거됐다 ⇒ 그 유형은 NULL.
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V (
    ANALYSIS_TYPE      COMMENT '분석유형: CHANNEL_NEW_SPNSR · DVLP_INC — 🔴 하나로 고정(유형 내 합계=1)',
    ANALYSIS_TYPE_NAME COMMENT '분석유형 라벨',
    STDR_MT            COMMENT '분석 실행 기준월 YYYYMM [원천]',
    RANK               COMMENT '피처 중요도 순위 [원천]',
    FEATURE            COMMENT '피처명(사람이 지정한 후보) [원천]',
    SCORE              COMMENT '피처 중요도 0~1(유형 내 합계=1) — 금액·건수 아님 · 인과 아님 [원천]',
    FEATURE_TYPE       COMMENT '피처 유형(user_provided = 사람이 지정) [원천] — CHANNEL_NEW_SPNSR 는 원천 컬럼 제거로 NULL'
)
  COMMENT = 'ML 요인분석(피처 중요도) 2종. grain=기준월×분석유형×피처. 값은 0~1 기여도이며 금액·건수가 아니다(분석유형 내 합계=1). 모델 설명이며 업무 실적이 아니다.'
AS
SELECT 'CHANNEL_NEW_SPNSR'          AS ANALYSIS_TYPE,
       '신규 후원 유치 요인'          AS ANALYSIS_TYPE_NAME,
       a.STDR_MT, a.RANK, a.FEATURE, a.SCORE,
       NULL::VARCHAR                 AS FEATURE_TYPE
FROM GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION a
UNION ALL
SELECT 'DVLP_INC',
       '증액 개발 요인',
       b.STDR_MT, b.RANK, b.FEATURE, b.SCORE, b.FEATURE_TYPE
FROM GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION b;

-- [8] ML_ONCE_CONVERSION_V — ML 일시후원회원의 정기후원 전환 예측 (🆕 O198 재정의)
--   · 원천 3컬럼(STDR_MT, ONCE_MBER_NO, PREDICT) · 실측 202606 단일 기준월 · 13,065행 / 6,718 키.
--   · 🔴 종전 「관측월(가입월부터 6개월)」 해석은 폐기 — STDR_MT 는 다른 ML 뷰와 같은 「기준월」이다(원천 테이블 COMMENT: 향후 6개월 내 전환 가능성).
--   · 🔴 회원당 다중 예측행(실행순번 없음)은 DEC-59 #1 대로 **유지**한다 — 회원수는 반드시 중복제거로 센다.
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V (
    STDR_MT              COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
    STDR_MONTH_KEY       COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
    ONCE_MBER_NO         COMMENT '일시회원번호(S 접두) — 정기회원번호와 체계가 달라 조인 금지',
    CONVERT_PROB         COMMENT '정기 전환 예측 확률(0~1) · 예측 지평 미발행',
    CONVERT_CLASS        COMMENT '전환 예측 분류(모델 class) — 업무 판정선 미확정',
    PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICT:logs:Error 비어있지 않음)',
    SEX_NAME             COMMENT '성별 라벨(SILVER.CRM_MEMBER 현재 스냅샷)',
    MEMBER_DIV_NAME      COMMENT '회원구분 라벨(현재 스냅샷)',
    REGIST_DEPT_NAME     COMMENT '등록부서명(DIM_ORG · 현재 스냅샷)',
    CPR_DIV_NAME         COMMENT '🆕 [O245] 법인구분(통합·사단·사복 · 코드사전 CM019 · 현재 스냅샷)',
    AMOUNT_BAND          COMMENT '🆕 [O245] 후원금액대(기준월 이하 가장 최근 납입월의 일시후원 납입액 · 정기 금액대1 과 같은 5만원 구간) — 🔴 정기회원 금액대(약정금액 기준)와 기준이 다르다 · 납입 이력이 없으면 NULL',
    TENURE_BAND          COMMENT '🆕 [O245] 유지기간대(같은 월실적 행의 기간대1) — 월실적 행이 없으면 NULL',
    PAYMENT_METHOD_NAME  COMMENT '🆕 [O245] 납입방식(기준월 이하 가장 최근 청구월의 청구액 최대 결제수단 · 잠정) — 청구 이력이 없으면 NULL',
    SPONSORSHIP_NAME     COMMENT '🆕 [O245] 후원사업(기준월 이하 가장 최근 납입월의 납입액 최대 후원사업) — 납입 이력이 없으면 NULL'
)
  COMMENT = 'ML 일시후원회원의 정기후원 전환 예측. grain=기준월×일시후원회원이나 원천이 회원당 다중 예측행을 담는다(실행순번 없음 · #1 유지). 회원수는 중복제거로 센다. 예측치이며 실적이 아니다. 🆕 [O245] 캠페인카테고리·회원상태·연령대·지역은 일시회원에 원천 값이 없어(2026-10-18 실측 0건) 컬럼을 두지 않는다.'
AS
WITH k AS (
    SELECT DISTINCT STDR_MT, ONCE_MBER_NO FROM GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION
), fm AS (
    SELECT k.STDR_MT, k.ONCE_MBER_NO, f.AMOUNT_BAND1, f.PERIOD_BAND1
    FROM k JOIN GN_DW.GOLD.FACT_MEMBER_MONTHLY f
      ON f.MEMBER_DK = k.ONCE_MBER_NO AND f.MONTH_KEY <= TO_NUMBER(k.STDR_MT)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY k.STDR_MT, k.ONCE_MBER_NO ORDER BY f.MONTH_KEY DESC) = 1
), pm AS (
    SELECT k.STDR_MT, k.ONCE_MBER_NO, w.PAYMENT_METHOD_NAME
    FROM k JOIN GN_DW.GOLD.WIDE_MEMBER_FEE w
      ON w.MEMBER_DK = k.ONCE_MBER_NO AND w.MONTH_KEY <= TO_NUMBER(k.STDR_MT) AND w.PAYMENT_METHOD_NAME IS NOT NULL
    GROUP BY k.STDR_MT, k.ONCE_MBER_NO, w.MONTH_KEY, w.PAYMENT_METHOD_NAME
    QUALIFY ROW_NUMBER() OVER (PARTITION BY k.STDR_MT, k.ONCE_MBER_NO
                               ORDER BY w.MONTH_KEY DESC, SUM(w.BILLED_AMT) DESC NULLS LAST, w.PAYMENT_METHOD_NAME) = 1
), sp AS (
    SELECT k.STDR_MT, k.ONCE_MBER_NO, ds.SPONSORSHIP_NAME
    FROM k JOIN GN_DW.GOLD.FACT_MEMBER_FEE f
      ON f.MEMBER_DK = k.ONCE_MBER_NO AND f.MONTH_KEY <= TO_NUMBER(k.STDR_MT) AND f.SPONSORSHIP_SK > 0
    JOIN GN_DW.GOLD.DIM_SPONSORSHIP ds ON ds.SPONSORSHIP_SK = f.SPONSORSHIP_SK
    GROUP BY k.STDR_MT, k.ONCE_MBER_NO, f.MONTH_KEY, ds.SPONSORSHIP_NAME
    QUALIFY ROW_NUMBER() OVER (PARTITION BY k.STDR_MT, k.ONCE_MBER_NO
                               ORDER BY f.MONTH_KEY DESC, SUM(f.PAID_FEE) DESC NULLS LAST, ds.SPONSORSHIP_NAME) = 1
), am AS (
    SELECT k.STDR_MT, k.ONCE_MBER_NO, SUM(f.PAID_FEE) AS PAID_AMT
    FROM k JOIN GN_DW.GOLD.FACT_MEMBER_FEE f
      ON f.MEMBER_DK = k.ONCE_MBER_NO AND f.MONTH_KEY <= TO_NUMBER(k.STDR_MT)
    GROUP BY k.STDR_MT, k.ONCE_MBER_NO, f.MONTH_KEY
    QUALIFY ROW_NUMBER() OVER (PARTITION BY k.STDR_MT, k.ONCE_MBER_NO ORDER BY f.MONTH_KEY DESC) = 1
), cpr AS (
    SELECT DTL_CD_ID, DTL_CD_NM FROM GN_DW.SILVER.CRM_CODE WHERE CD_ID = 'CM019'
)
SELECT
    o.STDR_MT                                 AS STDR_MT,
    TO_NUMBER(o.STDR_MT)                      AS STDR_MONTH_KEY,
    o.ONCE_MBER_NO                            AS ONCE_MBER_NO,
    o.PREDICT:probability:"1"::FLOAT          AS CONVERT_PROB,
    o.PREDICT:class::VARCHAR                  AS CONVERT_CLASS,
    ARRAY_SIZE(o.PREDICT:logs:Error) > 0      AS PREDICTION_HAS_ERROR,
    m.SEX_NM                                  AS SEX_NAME,
    m.MBER_DIV_NM                             AS MEMBER_DIV_NAME,
    og.DEPARTMENT                             AS REGIST_DEPT_NAME,
    cpr.DTL_CD_NM                             AS CPR_DIV_NAME,
    CASE WHEN am.PAID_AMT > 0
         THEN FLOOR(am.PAID_AMT / 50000) * 5 || '~' || (FLOOR(am.PAID_AMT / 50000) * 5 + 5) || '만원 미만'
    END                                       AS AMOUNT_BAND,
    fm.PERIOD_BAND1                           AS TENURE_BAND,
    pm.PAYMENT_METHOD_NAME                    AS PAYMENT_METHOD_NAME,
    sp.SPONSORSHIP_NAME                       AS SPONSORSHIP_NAME
FROM GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION o
LEFT JOIN GN_DW.SILVER.CRM_MEMBER m ON m.MEMBER_DK = o.ONCE_MBER_NO
LEFT JOIN GN_DW.GOLD.DIM_ORG og     ON og.ORG_DK   = ABS(HASH(m.REGIST_DEPT_CD))
LEFT JOIN cpr ON cpr.DTL_CD_ID = m.CPR_DIV_CD
LEFT JOIN fm  ON fm.STDR_MT = o.STDR_MT AND fm.ONCE_MBER_NO = o.ONCE_MBER_NO
LEFT JOIN am  ON am.STDR_MT = o.STDR_MT AND am.ONCE_MBER_NO = o.ONCE_MBER_NO
LEFT JOIN pm  ON pm.STDR_MT = o.STDR_MT AND pm.ONCE_MBER_NO = o.ONCE_MBER_NO
LEFT JOIN sp  ON sp.STDR_MT = o.STDR_MT AND sp.ONCE_MBER_NO = o.ONCE_MBER_NO;

-- ============================================================================
-- GRANT — 뷰 SELECT(재생성 시 사라지므로 함께 실행) · GN_DW.ML 직접 조회는 ANALYST 한정(DEC-57)
-- ============================================================================
GRANT SELECT ON VIEW GN_DW.SERVING.ML_MEMBER_RISK_V        TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_MEMBER_RISK_V        TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_MEMBER_RISK_V        TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_SPONSOR_RISK_V       TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_SPONSOR_RISK_V       TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_SPONSOR_RISK_V       TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_DVLP_FORECAST_V      TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_DVLP_FORECAST_V      TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_DVLP_FORECAST_V      TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEE_FORECAST_V       TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEE_FORECAST_V       TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEE_FORECAST_V       TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_LTV_FORECAST_V       TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_LTV_FORECAST_V       TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_LTV_FORECAST_V       TO ROLE GN_DW_SERVICE;
-- ⛔ ML_LTV_SCORE_V 폐기(O198) — GRANT 3행 삭제
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V    TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V    TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V    TO ROLE GN_DW_SERVICE;
GRANT USAGE ON SCHEMA GN_DW.ML                    TO ROLE GN_DW_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.ML     TO ROLE GN_DW_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.ML  TO ROLE GN_DW_ANALYST;

-- ============================================================================
-- [O242-B 이동] ML_CHURN_BY_CMPGN_CTGR_V — 원 정의 = 25_ML_CHURN_CMPGN_CTGR_DDL.sql(O224 · 문면 무변경 이동)
--   이유 = 아래 ML_MEMBER_ATTR_ASOF_V(21) 와 22 의 SV 가 이 뷰를 참조한다 ⇒ 신규 구축(21 → 22 → 25)에서 먼저 있어야 한다.
-- ============================================================================
-- 활동 판정(결정적): 기준월(YYYYMM) 말 기준 START_MONTH_KEY <= 기준월 AND (DSCNTC_MONTH_KEY IS NULL OR DSCNTC_MONTH_KEY > 기준월).
--   기준월 집합 = 두 ML 뷰의 기준월 합집합. 카테고리 = 약정의 대표캠페인 카테고리(ACQ_CMPGN_CTGR_NM · 적재 시점 동결값).
--   회원 단위 예측이 없는 회원은 MEMBER_* 가 NULL 이고 HAS_MEMBER_PRED = FALSE 다(R2-7 · 값 창작 금지).
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V (
    STDR_MT                COMMENT '모델 실행 기준월(YYYYMM) = 활동 판정 기준월',
    MBER_NO                COMMENT '회원번호',
    CMPGN_CTGR_NM          COMMENT '기준월 말 활동 중인 후원약정의 캠페인카테고리(MM294 · 적재 시점 동결값). NULL = 약정 대표캠페인에 카테고리 값이 없음',
    ACTIVE_SPNSR_CNT       COMMENT '그 회원이 이 카테고리로 기준월 말 활동 중인 약정 수(건)',
    HAS_MEMBER_PRED        COMMENT 'TRUE = 회원 단위 중단 예측(ML_MEMBER_RISK_V) 대상 회원',
    MEMBER_CHURN_PROB      COMMENT '회원 단위 중단확률(0~1). NULL = 회원 단위 예측 대상 아님',
    MEMBER_CHURN_CLASS     COMMENT '회원 단위 모델 판정 0/1. NULL = 회원 단위 예측 대상 아님',
    MEMBER_CHURN_GRADE     COMMENT '회원 단위 중단위험 등급(고위험/주의/일반 · 기준월 내 순위 구간). NULL = 회원 단위 예측 대상 아님',
    HAS_SPONSOR_PRED       COMMENT 'TRUE = 이 카테고리 후원건이 후원건 단위 이탈 예측(ML_SPONSOR_RISK_V) 대상',
    SPONSOR_MAX_CHURN_PROB COMMENT '이 카테고리 후원건 이탈확률 최댓값(0~1). NULL = 후원건 예측 대상 아님',
    SPONSOR_HIGH_CNT       COMMENT '이 카테고리 후원건 중 이탈위험 등급 고위험 건수(건). 0 = 고위험 후원건 없음 · NULL = 후원건 예측 대상 아님',
    SPONSOR_CHURN_GRADE    COMMENT '이 카테고리 후원건 중 가장 높은 이탈위험 등급(고위험 > 주의 > 일반). NULL = 후원건 예측 대상 아님'
)
  COMMENT = 'ML 중단 예측(회원 단위 + 후원건 단위) × 기준월 말 활동 후원 캠페인카테고리. [Grain: 기준월 × 회원 × 캠페인카테고리]. [주의: 회원당 여러 카테고리 행 · 회원수는 중복제거 · 예측치이며 실적이 아니다]. [원천: GN_DW.ML → SERVING.ML_MEMBER_RISK_V · SERVING.ML_SPONSOR_RISK_V · CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].'
AS
WITH mt AS (
    SELECT DISTINCT STDR_MT FROM GN_DW.SERVING.ML_MEMBER_RISK_V
    UNION
    SELECT DISTINCT STDR_MT FROM GN_DW.SERVING.ML_SPONSOR_RISK_V
),
act AS (
    SELECT mt.STDR_MT, f.MEMBER_DK AS MBER_NO, f.ACQ_CMPGN_CTGR_NM AS CMPGN_CTGR_NM, COUNT(*) AS ACTIVE_SPNSR_CNT
    FROM mt
    JOIN GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN f
      ON f.START_MONTH_KEY <= TO_NUMBER(mt.STDR_MT)
     AND (f.DSCNTC_MONTH_KEY IS NULL OR f.DSCNTC_MONTH_KEY > TO_NUMBER(mt.STDR_MT))
    GROUP BY 1, 2, 3
),
sp AS (
    SELECT STDR_MT, MBER_NO, CMPGN_CTGR_NAME AS CMPGN_CTGR_NM,
           MAX(CHURN_PROB) AS SPONSOR_MAX_CHURN_PROB,
           COUNT_IF(CHURN_GRADE = '고위험') AS SPONSOR_HIGH_CNT,
           CASE MAX(CASE CHURN_GRADE WHEN '고위험' THEN 3 WHEN '주의' THEN 2 WHEN '일반' THEN 1 END)
                WHEN 3 THEN '고위험' WHEN 2 THEN '주의' WHEN 1 THEN '일반' END AS SPONSOR_CHURN_GRADE
    FROM GN_DW.SERVING.ML_SPONSOR_RISK_V
    GROUP BY 1, 2, 3
)
SELECT a.STDR_MT,
       a.MBER_NO,
       a.CMPGN_CTGR_NM,
       a.ACTIVE_SPNSR_CNT,
       (m.MBER_NO IS NOT NULL),
       m.CHURN_PROB,
       m.CHURN_CLASS,
       m.CHURN_GRADE,
       (s.MBER_NO IS NOT NULL),
       s.SPONSOR_MAX_CHURN_PROB,
       s.SPONSOR_HIGH_CNT,
       s.SPONSOR_CHURN_GRADE
FROM act a
LEFT JOIN GN_DW.SERVING.ML_MEMBER_RISK_V m
  ON m.STDR_MT = a.STDR_MT AND m.MBER_NO = a.MBER_NO AND m.HAS_CHURN_PRED
LEFT JOIN sp s
  ON s.STDR_MT = a.STDR_MT AND s.MBER_NO = a.MBER_NO AND s.CMPGN_CTGR_NM = a.CMPGN_CTGR_NM;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V TO ROLE GN_DW_SERVICE;

-- ============================================================================
-- [O241-M] ML_MEMBER_ATTR_ASOF_V — ML 예측 회원의 기준월 시점 회원 특성(사용자 승인 2026-10-18)
--   grain = 기준월(STDR_MT) × 회원번호(MBER_NO) · 대상 = ML_MEMBER_RISK_V ∪ ML_SPONSOR_RISK_V ∪ ML_CHURN_BY_CMPGN_CTGR_V
--   🔴 모델 피처가 아니다 — 예측 결과를 회원 특성으로 나눠 보는 집계용 속성이다.
--   기준 시점 = 기준월 말일(STATUS_HISTORY 유효구간) · 금액대·유지기간·신규기존 = FACT_MEMBER_MONTHLY 그 달 행
--   결제수단 = WIDE_MEMBER_FEE 그 달 청구액 최대 행의 결제수단(동액이면 이름순) · 미매칭 = '(미매칭)'
-- ============================================================================
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V (
  STDR_MT COMMENT '모델 실행 기준월(YYYYMM)',
  MBER_NO COMMENT '회원번호(정기회원 체계 = MEMBER_DK)',
  GENDER_NAME COMMENT '성별(기준월 말 시점)',
  AGE_BAND COMMENT '연령대(기준월 말 시점 · 기업/단체/기타 포함)',
  REGION COMMENT '지역(기준월 말 시점)',
  MEMBER_STATUS_NAME COMMENT '회원상태(기준월 말 시점)',
  MEMBER_TYPE_NAME COMMENT '회원구분 = 개인/기업/단체(기준월 말 시점)',
  AMOUNT_BAND COMMENT '후원금액대(그 달 회원 월실적 · 금액대1)',
  TENURE_BAND COMMENT '유지기간대(그 달 회원 월실적 · 기간대1)',
  NEW_EXISTING COMMENT '신규/기존(그 달 회원 월실적)',
  PAYMENT_METHOD_NAME COMMENT '납입방식(결제수단 · 그 달 청구액 최대 행 · 잠정)',
  ATTR_MATCHED COMMENT 'TRUE=기준월 시점 회원 이력이 매칭됐다',
  REGIST_DEPT_NAME COMMENT '🆕 [O245] 등록부서명(CRM 회원 마스터 현재 값 · DIM_ORG)',
  CPR_DIV_NAME COMMENT '🆕 [O245] 법인구분(통합·사단·사복 · 코드사전 CM019 · CRM 회원 마스터 현재 값)',
  ACTIVE_SPNSR_CNT COMMENT '🆕 [O245] 기준월 말 활동 중인 후원약정 수(건 · 카테고리 무관 전체) — 0 = 활동 약정 없음'
) COMMENT = 'O241-M ML 예측 회원 기준월 시점 특성. grain = 기준월 × 회원. 모델 피처 아님. 🆕 [O245] 등록부서·법인구분·활동 약정 수 추가.' AS
WITH m AS (
  SELECT STDR_MT, MBER_NO FROM GN_DW.SERVING.ML_MEMBER_RISK_V
  UNION SELECT STDR_MT, MBER_NO FROM GN_DW.SERVING.ML_SPONSOR_RISK_V
  UNION SELECT STDR_MT, MBER_NO FROM GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V
), h AS (
  SELECT m.STDR_MT, m.MBER_NO, h.GENDER_NAME, h.AGE_BAND, h.REGION, h.MEMBER_STATUS_NAME, h.MEMBER_TYPE_NAME
  FROM m JOIN GN_DW.GOLD.DIM_MEMBER_STATUS_HISTORY h
    ON h.MEMBER_DK = m.MBER_NO
   AND LAST_DAY(TO_DATE(m.STDR_MT, 'YYYYMM')) BETWEEN h.EFFECTIVE_FROM AND COALESCE(h.EFFECTIVE_TO, '9999-12-31'::DATE)
  QUALIFY ROW_NUMBER() OVER (PARTITION BY m.STDR_MT, m.MBER_NO ORDER BY h.EFFECTIVE_FROM DESC) = 1
), p AS (
  SELECT w.MONTH_KEY, w.MEMBER_DK, w.PAYMENT_METHOD_NAME
  FROM GN_DW.GOLD.WIDE_MEMBER_FEE w
  WHERE w.MONTH_KEY IN (SELECT DISTINCT STDR_MT::INT FROM m)
  GROUP BY 1, 2, 3
  QUALIFY ROW_NUMBER() OVER (PARTITION BY w.MONTH_KEY, w.MEMBER_DK
                             ORDER BY SUM(w.BILLED_AMT) DESC NULLS LAST, w.PAYMENT_METHOD_NAME) = 1
), rd AS (
  -- 🆕 [O245] 등록부서·법인구분 = CRM 회원 마스터 현재 값(이력 테이블에 없다)
  SELECT c.MEMBER_DK, og.DEPARTMENT, cpr.DTL_CD_NM AS CPR_DIV_NM
  FROM GN_DW.SILVER.CRM_MEMBER c
  LEFT JOIN GN_DW.GOLD.DIM_ORG og ON og.ORG_DK = ABS(HASH(c.REGIST_DEPT_CD))
  LEFT JOIN (SELECT DTL_CD_ID, DTL_CD_NM FROM GN_DW.SILVER.CRM_CODE WHERE CD_ID = 'CM019') cpr ON cpr.DTL_CD_ID = c.CPR_DIV_CD
  WHERE c.MEMBER_DK IN (SELECT MBER_NO FROM m)
), ac AS (
  -- 🆕 [O245] 기준월 말 활동 약정 수(카테고리 무관 전체 · 판정식 = ML_CHURN_BY_CMPGN_CTGR_V 와 같다)
  SELECT m.STDR_MT, m.MBER_NO, COUNT(DISTINCT f.SPNSR_NO) AS N
  FROM m JOIN GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN f
    ON f.MEMBER_DK = m.MBER_NO
   AND f.START_MONTH_KEY <= TO_NUMBER(m.STDR_MT)
   AND (f.DSCNTC_MONTH_KEY IS NULL OR f.DSCNTC_MONTH_KEY > TO_NUMBER(m.STDR_MT))
  GROUP BY 1, 2
)
SELECT m.STDR_MT, m.MBER_NO,
       COALESCE(h.GENDER_NAME, '(미매칭)'), COALESCE(h.AGE_BAND, '(미매칭)'), COALESCE(h.REGION, '(미매칭)'),
       COALESCE(h.MEMBER_STATUS_NAME, '(미매칭)'), COALESCE(h.MEMBER_TYPE_NAME, '(미매칭)'),
       COALESCE(f.AMOUNT_BAND1, '(미매칭)'), COALESCE(f.PERIOD_BAND1, '(미매칭)'), COALESCE(f.NEW_EXISTING_FLAG::STRING, '(미매칭)'),
       COALESCE(p.PAYMENT_METHOD_NAME, '(미매칭)'),
       h.MBER_NO IS NOT NULL,
       COALESCE(rd.DEPARTMENT, '(미매칭)'), COALESCE(rd.CPR_DIV_NM, '(미매칭)'), COALESCE(ac.N, 0)
FROM m
LEFT JOIN h ON h.STDR_MT = m.STDR_MT AND h.MBER_NO = m.MBER_NO
LEFT JOIN GN_DW.GOLD.FACT_MEMBER_MONTHLY f ON f.MONTH_KEY = m.STDR_MT::INT AND f.MEMBER_DK = m.MBER_NO
LEFT JOIN p ON p.MONTH_KEY = m.STDR_MT::INT AND p.MEMBER_DK = m.MBER_NO
LEFT JOIN rd ON rd.MEMBER_DK = m.MBER_NO
LEFT JOIN ac ON ac.STDR_MT = m.STDR_MT AND ac.MBER_NO = m.MBER_NO;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V TO ROLE GN_DW_SERVICE;

-- ============================================================================
-- 🆕 [O245] ML_CHURN_BY_SPONSORSHIP_V — ML 중단 예측 × 기준월 말 활동 후원 캠페인카테고리 × 후원사업(사용자 승인 2026-10-18)
--   ML_CHURN_BY_CMPGN_CTGR_V 와 같은 활동 판정 · 후원사업 축만 더했다(그 뷰의 grain·VQR 은 건드리지 않는다).
--   후원건 예측은 약정번호(SPNSR_BSNS_NO)로 결합한다(2026-10-18 실측 1,686,360 / 1,686,372 일치).
-- ============================================================================
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V (
    STDR_MT                COMMENT '모델 실행 기준월(YYYYMM) = 활동 판정 기준월',
    MBER_NO                COMMENT '회원번호',
    CMPGN_CTGR_NM          COMMENT '기준월 말 활동 약정의 캠페인카테고리(MM294 · 적재 시점 동결값). NULL = 카테고리 값이 없음',
    SPONSORSHIP_NAME       COMMENT '기준월 말 활동 약정의 후원사업명(DIM_SPONSORSHIP). NULL = 후원사업 미매칭',
    ACTIVE_SPNSR_CNT       COMMENT '그 회원이 이 카테고리·후원사업으로 기준월 말 활동 중인 약정 수(건)',
    HAS_MEMBER_PRED        COMMENT 'TRUE = 회원 단위 중단 예측(ML_MEMBER_RISK_V) 대상 회원',
    MEMBER_CHURN_PROB      COMMENT '회원 단위 중단확률(0~1). NULL = 회원 단위 예측 대상 아님',
    MEMBER_CHURN_CLASS     COMMENT '회원 단위 모델 판정 0/1. NULL = 회원 단위 예측 대상 아님',
    MEMBER_CHURN_GRADE     COMMENT '회원 단위 중단위험 등급(고위험/주의/일반). NULL = 회원 단위 예측 대상 아님',
    HAS_SPONSOR_PRED       COMMENT 'TRUE = 이 묶음의 약정이 후원건 단위 이탈 예측(ML_SPONSOR_RISK_V) 대상',
    SPONSOR_MAX_CHURN_PROB COMMENT '이 묶음 약정의 이탈확률 최댓값(0~1). NULL = 후원건 예측 대상 아님',
    SPONSOR_HIGH_CNT       COMMENT '이 묶음 약정 중 이탈위험 고위험 건수(건). 0 = 고위험 없음 · NULL = 후원건 예측 대상 아님',
    SPONSOR_CHURN_GRADE    COMMENT '이 묶음 약정 중 가장 높은 이탈위험 등급(고위험 > 주의 > 일반). NULL = 후원건 예측 대상 아님'
)
  COMMENT = 'ML 중단 예측(회원 단위 + 후원건 단위) × 기준월 말 활동 약정의 캠페인카테고리 × 후원사업. [Grain: 기준월 × 회원 × 캠페인카테고리 × 후원사업]. [주의: 회원당 여러 행 · 회원수는 중복제거 · 예측치이며 실적이 아니다]. [원천: GN_DW.ML → SERVING.ML_MEMBER_RISK_V · SERVING.ML_SPONSOR_RISK_V · CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN · GOLD.DIM_SPONSORSHIP].'
AS
WITH mt AS (
    SELECT DISTINCT STDR_MT FROM GN_DW.SERVING.ML_MEMBER_RISK_V
    UNION
    SELECT DISTINCT STDR_MT FROM GN_DW.SERVING.ML_SPONSOR_RISK_V
), act AS (
    SELECT mt.STDR_MT, f.MEMBER_DK AS MBER_NO, f.ACQ_CMPGN_CTGR_NM AS CMPGN_CTGR_NM,
           ds.SPONSORSHIP_NAME, f.SPNSR_NO, f.SPNSR_BSNS_NO
    FROM mt
    JOIN GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN f
      ON f.START_MONTH_KEY <= TO_NUMBER(mt.STDR_MT)
     AND (f.DSCNTC_MONTH_KEY IS NULL OR f.DSCNTC_MONTH_KEY > TO_NUMBER(mt.STDR_MT))
    LEFT JOIN GN_DW.GOLD.DIM_SPONSORSHIP ds ON ds.SPONSORSHIP_SK = f.SPONSORSHIP_SK
), j AS (
    SELECT a.*, s.CHURN_PROB, s.CHURN_GRADE, (s.MBER_NO IS NOT NULL) AS HAS_SP
    FROM act a
    LEFT JOIN GN_DW.SERVING.ML_SPONSOR_RISK_V s
      ON s.STDR_MT = a.STDR_MT AND s.MBER_NO = a.MBER_NO AND s.SPNSR_BSNS_NO = a.SPNSR_BSNS_NO
), g AS (
    SELECT STDR_MT, MBER_NO, CMPGN_CTGR_NM, SPONSORSHIP_NAME,
           COUNT(DISTINCT SPNSR_NO) AS ACTIVE_SPNSR_CNT,
           BOOLOR_AGG(HAS_SP) AS HAS_SPONSOR_PRED,
           MAX(CHURN_PROB) AS SPONSOR_MAX_CHURN_PROB,
           IFF(BOOLOR_AGG(HAS_SP), COUNT_IF(CHURN_GRADE = '고위험'), NULL) AS SPONSOR_HIGH_CNT,
           CASE MAX(CASE CHURN_GRADE WHEN '고위험' THEN 3 WHEN '주의' THEN 2 WHEN '일반' THEN 1 END)
                WHEN 3 THEN '고위험' WHEN 2 THEN '주의' WHEN 1 THEN '일반' END AS SPONSOR_CHURN_GRADE
    FROM j
    GROUP BY 1, 2, 3, 4
)
SELECT g.STDR_MT, g.MBER_NO, g.CMPGN_CTGR_NM, g.SPONSORSHIP_NAME, g.ACTIVE_SPNSR_CNT,
       (m.MBER_NO IS NOT NULL), m.CHURN_PROB, m.CHURN_CLASS, m.CHURN_GRADE,
       g.HAS_SPONSOR_PRED, g.SPONSOR_MAX_CHURN_PROB, g.SPONSOR_HIGH_CNT, g.SPONSOR_CHURN_GRADE
FROM g
LEFT JOIN GN_DW.SERVING.ML_MEMBER_RISK_V m
  ON m.STDR_MT = g.STDR_MT AND m.MBER_NO = g.MBER_NO AND m.HAS_CHURN_PRED;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V TO ROLE GN_DW_SERVICE;
