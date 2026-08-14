-- GN_DW ML 예측결과 SERVING 뷰 DDL 정본 — Semantic View 의 base 계층
-- Co-authored with CoCo · [2026-08-14 O74]
-- ============================================================================
-- ▶ 이 파일의 위상
--   `GN_DW.ML` 의 **예측결과 테이블 16종만** 소비 가능한 형태로 감싼다.
--   ⛔ `ML_TRAIN_DATA_*` 등 학습·중간 37종은 여기에 등장하지 않는다(사용자 지시).
--   SV 는 **이 뷰들만** base 로 쓴다. ML 테이블을 SV 가 직접 참조하지 않는다.
--
-- ▶ 🔴 왜 뷰 계층을 반드시 끼우는가 (설계문서 `20_ML_SV_설계.md` §5)
--   1. **교체 내성** — ML 은 테스트 단계이고 정본 DDL 이 결과 테이블을 `create or replace TABLE`
--      로 적는다. 재실행 시 객체가 새로 생겨 GRANT 가 소실되고 컬럼도 바뀔 수 있다.
--      뷰가 컬럼 계약을 고정해 충격을 흡수한다.
--   2. **학습 테이블 차폐** — 소비 역할에 `GN_DW.ML` 권한을 **한 건도 주지 않는다.**
--      뷰는 소유자(GN_DW_ADMIN) 권한으로 ML 을 읽으므로 소비 역할은 뷰만 볼 수 있다.
--      🟢 실측 근거: `SHOW GRANTS ON TABLE GN_DW.GOLD.FACT_BUDGET` = OWNERSHIP 1행뿐인데
--         기존 SV 9종이 정상 동작한다 ⇒ 소비 역할은 base 에 SELECT 없이 SV 를 쓴다.
--   3. **VARIANT 평탄화** — `PREDICTION` JSON 을 Analyst 가 조립하게 두지 않는다(§4).
--   4. **dedup** — 회원 예측 2종의 중복을 여기서 단일화한다(§1-1).
--
-- ▶ 실행
--   역할 `GN_DW_ADMIN` · 선행 조건 = `GN_DW.ML` 결과 16종 적재. dbt build 와 무관하다.
--   재실행 안전(`CREATE OR REPLACE VIEW`) — 뷰는 GRANT 를 잃으므로 §GRANT 절이 같은 파일에 있다.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;


/* =====================================================================================
   [1] ML_MEMBER_RISK_V — 회원 단위 예측 3종 통합 (중단 · 증액 · 충성)
       grain = 기준월 × 회원 (dedup 후 유일)

   🔴 dedup 규칙 = **월말 상태 기준**(사용자 확정 2026-08-14)
      원천 `ML_RST_DATA_MBER_CHURN_12M`·`_MBER_INC_12M` 은 회원당 여러 행이다.
      실측: 91,423행 / 회원 74,949명 = 중복 16,474행. 중복 회원 16,290명.
      중복행의 **피처는 전건 동일**하고 `MBER_STAT_CD` 만 다르다(16,278명) —
      원인은 `ML.MBER_MONTHLY_INFO` 가 한 달에 상태 spell 을 여러 행 담기 때문이고,
      프로시저의 학습 STEP 은 dedup 하는데 **예측 STEP 만 누락**됐다.
      ⇒ 그 달 **마지막 상태 spell**(STAT_START_DT 최대 · 동순위는 SER_NO 최대)을 대표로 잡는다.
      🟢 검증 실측: 91,423 → 74,949 (1:1) · 조인 팬아웃 0 · spell 미매칭 0.
      ⚠️ 지표 영향(측정값) — 위험확률 평균 0.382907 → 0.441761 ·
         확률 0.5 이상 건수 29,690 → 29,121. **dedup 은 무해한 정리가 아니다**(값이 움직인다).
      🔴 이것은 **완화이고 원천 해소가 아니다** — 예측 STEP dedup 추가가 근본 처방이다(성현 프로 소관).

   🔴 중단 예측의 **예측 지평은 발행하지 않는다**(사용자 확정) —
      테이블명은 `..._12M` 인데 COMMENT·프로시저명(`SP_MBER_CHURN_6M_PREDICT`)·
      학습 라벨(`CHURN_6M`)·컷오프(`-6개월`)는 **3중으로 6개월**이다. 확인 전까지 기간을 쓰지 않는다.

   ⚠️ 충성회원(`LOYAL_MBER`)은 **모집단이 다르다**(29,471행 · 원천이 tenure 구간으로 한정).
      중단·증액(74,949명)과 **분모가 다르므로** FULL OUTER 로 붙이고 결합 시 NULL 을 허용한다.
   ===================================================================================== */
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_MEMBER_RISK_V
  COMMENT = 'ML 회원단위 예측(중단·증액·충성) 통합. grain=기준월×회원(dedup 후 유일). 원천 중복은 월말 상태 spell 기준으로 단일화했다(원천 미해소·완화). 예측치이며 실적이 아니다.'
AS
WITH spell AS (
  -- 회원-월-상태 조합의 마지막 spell 시각. GROUP BY 로 미리 접어 조인 팬아웃을 0으로 만든다.
  SELECT STDR_MT,
         MBER_NO,
         STDR_MT_MBER_STAT_CD          AS STAT_CD,
         MAX(STAT_START_DT)            AS LAST_STAT_START_DT,
         MAX(SER_NO)                   AS LAST_SER_NO
  FROM GN_DW.ML.MBER_MONTHLY_INFO
  GROUP BY STDR_MT, MBER_NO, STDR_MT_MBER_STAT_CD
),
churn AS (
  SELECT r.STDR_MT,
         r.MBER_NO,
         r.MBER_STAT_CD,
         r.MONTHS_SINCE_JOIN,
         r.ACTIVE_SPNSR_CNT,
         r.TOTAL_SPNSR_AMT,
         r.DNST_RT,
         r.PAY_RATE,
         r.SETLE_CD,
         r.CPR_DIV_CD,
         r.PREDICTION:probability:"1"::FLOAT   AS CHURN_PROB,
         r.PREDICTION:class::VARCHAR            AS CHURN_CLASS,
         ARRAY_SIZE(r.PREDICTION:logs:Error) > 0 AS CHURN_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M r
  LEFT JOIN spell s
    ON  s.STDR_MT = r.STDR_MT
    AND s.MBER_NO = r.MBER_NO
    AND s.STAT_CD = r.MBER_STAT_CD
  QUALIFY ROW_NUMBER() OVER (
            PARTITION BY r.STDR_MT, r.MBER_NO
            ORDER BY s.LAST_STAT_START_DT DESC NULLS LAST,
                     s.LAST_SER_NO       DESC NULLS LAST,
                     r.MBER_STAT_CD
          ) = 1
),
inc AS (
  SELECT r.STDR_MT,
         r.MBER_NO,
         r.PREDICTION:probability:"1"::FLOAT   AS INC_PROB,
         r.PREDICTION:class::VARCHAR            AS INC_CLASS,
         ARRAY_SIZE(r.PREDICTION:logs:Error) > 0 AS INC_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_MBER_INC_12M r
  LEFT JOIN spell s
    ON  s.STDR_MT = r.STDR_MT
    AND s.MBER_NO = r.MBER_NO
    AND s.STAT_CD = r.MBER_STAT_CD
  QUALIFY ROW_NUMBER() OVER (
            PARTITION BY r.STDR_MT, r.MBER_NO
            ORDER BY s.LAST_STAT_START_DT DESC NULLS LAST,
                     s.LAST_SER_NO       DESC NULLS LAST,
                     r.MBER_STAT_CD
          ) = 1
),
loyal AS (
  -- 원천이 이미 회원당 1행(실측 29,471행 = 29,471명) → dedup 불요.
  SELECT STDR_MT,
         MBER_NO,
         CURRENT_TENURE,
         ACTIVE_MONTHS_24,
         SPNSR_CNT_24,
         TOTAL_AMT_24,
         AVG_AMT_24,
         PAY_RATE_24,
         PREDICTION:probability:"1"::FLOAT   AS LOYAL_PROB,
         PREDICTION:class::VARCHAR            AS LOYAL_CLASS,
         ARRAY_SIZE(PREDICTION:logs:Error) > 0 AS LOYAL_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_LOYAL_MBER
),
u AS (
  -- 모집단이 서로 다르므로 키 합집합을 먼저 만든다(어느 한 축에만 있는 회원을 잃지 않는다).
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
    -- 상태 라벨: 원천 코드 + MM010 라벨. 미매칭은 라벨을 창작하지 않고 NULL 로 둔다.
    c.MBER_STAT_CD                               AS MBER_STAT_CD,
    cd_stat.DTL_CD_NM                            AS MBER_STAT_NAME,
    c.SETLE_CD                                   AS SETLE_CD,
    cd_setle.DTL_CD_NM                           AS SETLE_NAME,
    c.CPR_DIV_CD                                 AS CPR_DIV_CD,
    c.MONTHS_SINCE_JOIN                          AS MONTHS_SINCE_JOIN,
    c.ACTIVE_SPNSR_CNT                           AS ACTIVE_SPNSR_CNT,
    c.TOTAL_SPNSR_AMT                            AS TOTAL_SPNSR_AMT,
    c.DNST_RT                                    AS DNST_RT,
    c.PAY_RATE                                   AS PAY_RATE,
    c.CHURN_PROB                                 AS CHURN_PROB,
    c.CHURN_CLASS                                AS CHURN_CLASS,
    i.INC_PROB                                   AS INC_PROB,
    i.INC_CLASS                                  AS INC_CLASS,
    l.LOYAL_PROB                                 AS LOYAL_PROB,
    l.LOYAL_CLASS                                AS LOYAL_CLASS,
    l.CURRENT_TENURE                             AS LOYAL_CURRENT_TENURE,
    l.ACTIVE_MONTHS_24                           AS LOYAL_ACTIVE_MONTHS_24,
    l.TOTAL_AMT_24                               AS LOYAL_TOTAL_AMT_24,
    -- 어느 예측이 이 회원에 존재하는지: 분모를 밝히지 않고 세면 틀린다.
    c.MBER_NO IS NOT NULL                        AS HAS_CHURN_PRED,
    i.MBER_NO IS NOT NULL                        AS HAS_INC_PRED,
    l.MBER_NO IS NOT NULL                        AS HAS_LOYAL_PRED,
    COALESCE(c.CHURN_HAS_ERROR, FALSE)
      OR COALESCE(i.INC_HAS_ERROR, FALSE)
      OR COALESCE(l.LOYAL_HAS_ERROR, FALSE)      AS PREDICTION_HAS_ERROR
FROM u
LEFT JOIN churn c ON c.STDR_MT = u.STDR_MT AND c.MBER_NO = u.MBER_NO
LEFT JOIN inc   i ON i.STDR_MT = u.STDR_MT AND i.MBER_NO = u.MBER_NO
LEFT JOIN loyal l ON l.STDR_MT = u.STDR_MT AND l.MBER_NO = u.MBER_NO
-- 코드그룹은 추정하지 않고 프로젝트 기존 결정을 재사용한다:
--   MM010 = 회원상태(이슈원장 Q4 확정 · ML 값 11/11 도달 실측)
--   PM040 = 결제수단(정본 = `10_dbt_pipeline/models/silver/crm/CRM_PAYMENT_METHOD.sql:24`)
-- 🔴 SETLE_CD 값은 1~13 단일 숫자라 CRM_CODE 140개 그룹과 우연 일치한다(`P36`) —
--    그래서 그룹을 우리가 고르지 않고 위 정본을 따른다.
LEFT JOIN (SELECT DISTINCT DTL_CD_ID, DTL_CD_NM FROM GN_DW.SILVER.CRM_CODE WHERE CD_ID = 'MM010') cd_stat
       ON cd_stat.DTL_CD_ID = c.MBER_STAT_CD
LEFT JOIN (SELECT DISTINCT DTL_CD_ID, DTL_CD_NM FROM GN_DW.SILVER.CRM_CODE WHERE CD_ID = 'PM040') cd_setle
       ON cd_setle.DTL_CD_ID = c.SETLE_CD;


/* =====================================================================================
   [2] ML_SPONSOR_RISK_V — 후원건 단위 이탈 예측
       grain = 기준월 × 회원 × 후원사업ID × 후원사업번호 (실측 유일 829,609행)

   🔴 회원 SV 와 **합치지 않는다** — 회원당 후원건이 여러 개라 회원 grain 과 조인하면
      팬아웃이 난다(`O8` 유형). 회원수를 세려면 반드시 `COUNT(DISTINCT MBER_NO)` 다.
   ⚠️ 회원 고아 5명(722,916 중 · 기지 `BLOCKING-1` 범위)은 라벨이 NULL 로 남는다.
   ===================================================================================== */
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_SPONSOR_RISK_V
  COMMENT = 'ML 후원건단위 이탈 예측. grain=기준월×회원×후원사업ID×후원사업번호(실측 유일). 회원수는 반드시 중복제거로 센다. 예측치이며 실적이 아니다.'
AS
SELECT
    r.STDR_MT                                     AS STDR_MT,
    TO_NUMBER(r.STDR_MT)                          AS STDR_MONTH_KEY,
    r.MBER_NO                                     AS MBER_NO,
    r.SPNSR_BSNS_ID                               AS SPNSR_BSNS_ID,
    sp.SPNSR_BSNS_NM                              AS SPNSR_BSNS_NAME,
    r.SPNSR_BSNS_NO                               AS SPNSR_BSNS_NO,
    r.CMPGN_CD                                    AS CMPGN_CD,
    cm.CMPGN_NM                                   AS CMPGN_NAME,
    cm.UPPER_CMPGN_CD                             AS UPPER_CMPGN_CD,
    cm.CMPGN_CTGR_NM                              AS CMPGN_CTGR_NAME,
    r.SETLE_CD                                    AS SETLE_CD,
    r.TENURE_MONTHS                               AS TENURE_MONTHS,
    r.STDR_MT_SPNSR_AMT                           AS STDR_MT_SPNSR_AMT,
    r.CHN_CNT                                     AS CHN_CNT,
    r.INC_CNT                                     AS INC_CNT,
    r.DEC_CNT                                     AS DEC_CNT,
    r.RE_CNT                                      AS RE_CNT,
    r.CANCL_CNT                                   AS CANCL_CNT,
    r.PAY_RATE                                    AS PAY_RATE,
    r.PREDICTION:probability:"1"::FLOAT            AS CHURN_PROB,
    r.PREDICTION:class::VARCHAR                    AS CHURN_CLASS,
    ARRAY_SIZE(r.PREDICTION:logs:Error) > 0        AS PREDICTION_HAS_ERROR
FROM GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M r
LEFT JOIN GN_DW.SILVER.CRM_SPONSORSHIP sp ON sp.SPNSR_BSNS_ID = r.SPNSR_BSNS_ID
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN    cm ON cm.CMPGN_CD      = r.CMPGN_CD;


/* =====================================================================================
   [3] ML_DVLP_FORECAST_V — 개발금액 예측 5종 통합
       grain = 기준월 × 계열유형 × 계열 × 예측월

   🟢 **5종을 한 뷰에 묶는 근거는 단위 동질성 실측이다.**
      부서 30계열 평균 881 × 30 = 26,430 ≈ 전사 30,457 ·
      신규기존 2계열 평균 15,777 × 2 = 31,554 ≈ 전사 30,457
      ⇒ 세 테이블이 **같은 스케일**임을 교차검증했다. 캠페인·후원사업도 같은 자리수다.
   🔴 **단위는 「만원」이다**(프로시저가 원 → 만원으로 나눈다 · 자리수 실측이 이를 지지한다).
      ⇒ 원 단위인 회비·LTV 를 **이 뷰에 섞지 않는다**(섞으면 10,000배 오차).
   🔴 계열유형별 라벨 축이 다르므로 `SERIES_TYPE` 을 **항상 함께 봐야 한다** —
      `SERIES_CD` 하나로는 부서코드인지 캠페인코드인지 알 수 없다.
   ⚠️ 계열유형 간 합산은 **중복계상이다**(전사 = 부서합 = 신규기존합). SV 문안에서 차단한다.
   ===================================================================================== */
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_DVLP_FORECAST_V
  COMMENT = 'ML 개발금액 예측 5종(전사·부서·후원사업·신규기존·캠페인) 통합. grain=기준월×계열유형×계열×예측월. 단위=만원. 계열유형 간 합산은 중복계상이다. 예측치이며 실적이 아니다.'
AS
SELECT 'TOTAL'                          AS SERIES_TYPE,
       '(전사)'                          AS SERIES_CD,
       '(전사 합계)'                      AS SERIES_NAME,
       t.STDR_MT, t.TS, t.FORECAST, t.LOWER_BOUND, t.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_DVLP_AMT t
UNION ALL
SELECT 'DEPT', d.SERIES, og.DEPT_NM,
       d.STDR_MT, d.TS, d.FORECAST, d.LOWER_BOUND, d.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT d
LEFT JOIN GN_DW.SILVER.CRM_ORG og ON og.DEPT_ID = d.SERIES
UNION ALL
SELECT 'SPNSR_BSNS', s.SERIES, sp.SPNSR_BSNS_NM,
       s.STDR_MT, s.TS, s.FORECAST, s.LOWER_BOUND, s.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT s
LEFT JOIN GN_DW.SILVER.CRM_SPONSORSHIP sp ON sp.SPNSR_BSNS_ID = s.SERIES
UNION ALL
SELECT 'NEW_OLD', n.SERIES,
       CASE n.SERIES WHEN 'NEW' THEN '신규' WHEN 'OLD' THEN '기존' END,
       n.STDR_MT, n.TS, n.FORECAST, n.LOWER_BOUND, n.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT n
UNION ALL
SELECT 'CAMPAIGN', c.SERIES, cm.CMPGN_NM,
       c.STDR_MT, c.TS, c.FORECAST, c.LOWER_BOUND, c.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT c
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm ON cm.CMPGN_CD = c.SERIES;


/* =====================================================================================
   [4] ML_FEE_FORECAST_V — 캠페인카테고리별 회비(후원금액) 예측
       grain = 기준월 × 캠페인카테고리 × 예측월 (실측 유일 660행)
   🔴 단위 = **원**(실측 평균 2.88억). 개발금액(만원)과 **다른 뷰**에 둔 이유가 이것이다.
   ===================================================================================== */
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_FEE_FORECAST_V
  COMMENT = 'ML 캠페인카테고리별 회비(후원금액) 예측. grain=기준월×캠페인카테고리×예측월. 단위=원. 개발금액 예측(만원)과 단위가 다르므로 합산하지 않는다. 예측치이며 실적이 아니다.'
AS
SELECT
    r.STDR_MT                        AS STDR_MT,
    TO_NUMBER(r.STDR_MT)             AS STDR_MONTH_KEY,
    r.SERIES                         AS CMPGN_CTGR_CD,
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
) ctgr ON ctgr.CTGR_CD = r.SERIES;


/* =====================================================================================
   [5] ML_LTV_FORECAST_V — LTV 월별 예측 2종
       grain = 기준월 × LTV유형 × 계열 × 예측월

   🔴 **두 원천은 계열축이 완전히 다르다 — 실측 교집합 0.**
      · `UCMPGN_LTV`  = 상위캠페인 50종(전건 `UPPER_CMPGN_YN='Y'` 확인) · 회원평균 LTV(평균 20,567원)
      · `CMPGN_LTV`   = 일반 캠페인 50종(상위캠페인 **0/50**)         · 후원 총액 LTV(평균 7.85억원)
      ⚠️ 사용자 요건 기술은 둘 다 "채널(상위캠페인) 단위" 라고 적었으나 **후자는 상위캠페인이 아니다.**
      ⇒ `LTV_TYPE` 으로 갈라 두고, **유형 간 합산·비교를 SV 문안에서 차단**한다
        (하나는 1인당 평균, 하나는 총액이라 자리수가 4~5자리 다르다).
   ===================================================================================== */
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_LTV_FORECAST_V
  COMMENT = 'ML LTV 월별 예측 2종. UCMPGN=상위캠페인 회원평균 LTV · CMPGN=일반캠페인 후원총액 LTV. 두 유형은 계열축과 의미가 달라 합산·비교할 수 없다. 단위=원. 예측치이며 실적이 아니다.'
AS
SELECT 'UCMPGN_AVG_MEMBER'                AS LTV_TYPE,
       '상위캠페인 회원평균 LTV'            AS LTV_TYPE_NAME,
       u.SERIES                            AS SERIES_CD,
       cm_u.CMPGN_NM                       AS SERIES_NAME,
       u.STDR_MT, u.TS, u.FORECAST, u.LOWER_BOUND, u.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_UCMPGN_LTV u
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm_u ON cm_u.CMPGN_CD = u.SERIES
UNION ALL
SELECT 'CMPGN_TOTAL',
       '캠페인 후원총액 LTV',
       c.SERIES,
       cm_c.CMPGN_NM,
       c.STDR_MT, c.TS, c.FORECAST, c.LOWER_BOUND, c.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_CMPGN_LTV c
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm_c ON cm_c.CMPGN_CD = c.SERIES;


/* =====================================================================================
   [6] ML_LTV_SCORE_V — LTV 스코어 2종
       grain = 기준월 × LTV유형 × 계열 (계열당 1행 · 실측 각 50행)

   🔴 예측 뷰([5])와 **합치지 않는다** — 예측은 계열당 12행, 스코어는 계열당 1행이다.
      한 SV 에 두면 `SUM` 의 분모가 섞여 조용히 틀린다(설계문서 §3 grain 근거).
   🔴 스코어 2종도 계열축 교집합 0(상위캠페인 vs 일반캠페인)이다.
   ===================================================================================== */
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_LTV_SCORE_V
  COMMENT = 'ML LTV 스코어 2종(계열당 1행). UCMPGN=상위캠페인 · CMPGN=일반캠페인. 월별 예측 뷰와 grain 이 달라 합산하지 않는다. 단위=원. 예측치이며 실적이 아니다.'
AS
SELECT 'UCMPGN_AVG_MEMBER'      AS LTV_TYPE,
       '상위캠페인 회원평균 LTV'  AS LTV_TYPE_NAME,
       u.UPPER_CMPGN_CD          AS SERIES_CD,
       cm_u.CMPGN_NM             AS SERIES_NAME,
       u.STDR_MT, u.HIST_TOTAL_AMT, u.FUTURE_TOTAL_AMT, u.LTV,
       u.AVG_MONTHLY_FORECAST, u.AVG_MONTHLY_ACTUAL, u.ACTIVE_MONTHS
FROM GN_DW.ML.ML_RST_DATA_UCMPGN_LTV_SCORE u
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm_u ON cm_u.CMPGN_CD = u.UPPER_CMPGN_CD
UNION ALL
SELECT 'CMPGN_TOTAL',
       '캠페인 후원총액 LTV',
       c.CMPGN_CD,
       cm_c.CMPGN_NM,
       c.STDR_MT, c.HIST_TOTAL_AMT, c.FUTURE_TOTAL_AMT, c.LTV,
       c.AVG_MONTHLY_FORECAST, c.AVG_MONTHLY_ACTUAL, c.ACTIVE_MONTHS
FROM GN_DW.ML.ML_RST_DATA_CMPGN_LTV_SCORE c
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm_c ON cm_c.CMPGN_CD = c.CMPGN_CD;


/* =====================================================================================
   [7] ML_FEATURE_IMPORTANCE_V — 요인분석(피처 중요도) 2종
       grain = 기준월 × 분석유형 × 피처 (실측 각 11행)

   🔴 **측정 대상이 데이터가 아니라 모델이다.** 금액·건수가 아니라 0~1 기여도이고
      분석유형 내 합계가 1 이다 ⇒ 다른 SV measure 와 같은 표에 두면 업무 수치로 오독된다.
   ⚠️ `FEATURE_TYPE` 실측값은 두 원천 모두 `user_provided` 1종뿐이다 —
      「모델이 스스로 뽑은 중요도」가 아니라 **사람이 지정한 피처 목록**이라는 뜻이므로
      SV 문안에 그대로 노출한다(해석을 우리가 만들지 않는다).
   ===================================================================================== */
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V
  COMMENT = 'ML 요인분석(피처 중요도) 2종. grain=기준월×분석유형×피처. 값은 0~1 기여도이며 금액·건수가 아니다(분석유형 내 합계=1). 모델 설명이며 업무 실적이 아니다.'
AS
SELECT 'CHANNEL_NEW_SPNSR'          AS ANALYSIS_TYPE,
       '신규 후원 유치 요인'          AS ANALYSIS_TYPE_NAME,
       a.STDR_MT, a.RANK, a.FEATURE, a.SCORE, a.FEATURE_TYPE
FROM GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION a
UNION ALL
SELECT 'DVLP_INC',
       '증액 개발 요인',
       b.STDR_MT, b.RANK, b.FEATURE, b.SCORE, b.FEATURE_TYPE
FROM GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION b;


/* =====================================================================================
   GRANT — 소비 역할에 뷰 SELECT 부여
     🔴 `GN_DW.ML` 에는 **어떤 권한도 주지 않는다.** 뷰가 소유자 권한으로 ML 을 읽으므로
        소비 역할은 이 뷰들만 볼 수 있고 학습 37종은 닫힌 채로 남는다(사용자 지시의 집행).
     ⚠️ `CREATE OR REPLACE VIEW` 는 GRANT 를 잃는다 — 그래서 GRANT 가 같은 파일에 있다.
        재실행 시 이 절까지 반드시 함께 돌린다.
   ===================================================================================== */
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
GRANT SELECT ON VIEW GN_DW.SERVING.ML_LTV_SCORE_V          TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_LTV_SCORE_V          TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_LTV_SCORE_V          TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V TO ROLE GN_DW_SERVICE;
