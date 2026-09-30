-- ============================================================================
-- GN_DW.SERVING ML 예측 뷰 DDL — Semantic View(22_ML_SV_DDL) 의 base 계층 · 구조 정본
--   · GN_DW.ML 예측결과 테이블만 감싼다(학습·중간 테이블 비노출). SV 는 이 뷰만 base 로 쓴다.
--   · 뷰를 끼우는 이유 = ML 테이블 교체 내성 · VARIANT(PREDICTION) 평탄화 · 회원 예측 dedup.
--   · 실행 = GN_DW_ADMIN · 선행 = GN_DW.ML 결과 테이블 적재(dbt 무관).
--   · 컬럼 COMMENT 는 뷰 정의 안에 있다 — 재생성해도 유지된다. GRANT 는 재생성 시 사라지므로 같은 파일 말미에 있다.
--   · 🔴 ⛔ 표식 구간 = 원천 삭제로 비활성인 코드(재적재 시 주석 해제로 복구).
--   · 설계근거·실측 이력 = 21_ML_SERVING_뷰_설계이력_부록.md · 설계 = 20_ML_SV_설계.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

-- [1] ML_MEMBER_RISK_V — ML 회원단위 예측(중단·증액·충성) 통합
--   ⚠️ 원천이 회원당 여러 행 — 그 달 마지막 상태 spell 로 dedup(값이 움직이는 판정 · 임의 tiebreaker 금지).
--   ⚠️ 중단 예측 지평은 발행하지 않는다(테이블명 12M · 실제 6개월 근거 3중 · 확인 전 기간 미기재).
--   ⚠️ 충성회원은 모집단이 다르다 — FULL OUTER 결합 · NULL 허용.
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_MEMBER_RISK_V (
    STDR_MT                COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
    STDR_MONTH_KEY         COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
    MBER_NO                COMMENT '정기회원번호(7자리 TEXT) [원천: ML 회원 예측]',
    MBER_STAT_CD           COMMENT '기준월 회원상태코드(MM010) — 월말 상태 spell 기준 dedup 대표값 · 모델 피처',
    MBER_STAT_NAME         COMMENT '회원상태 라벨(MM010) — 사전 미매칭은 NULL',
    SETLE_CD               COMMENT '결제수단코드(PM040)',
    SETLE_NAME             COMMENT '결제수단 라벨(PM040) — 사전 미매칭은 NULL',
    CPR_DIV_CD             COMMENT '법인구분코드(A/I/S)',
    CPR_DIV_NM             COMMENT '법인구분 라벨(통합/사단/사복 · 캠페인 마스터 DISTINCT 짝)',
    MONTHS_SINCE_JOIN      COMMENT '가입 후 경과 월수 [원천]',
    ACTIVE_SPNSR_CNT       COMMENT '활성 후원건 수 [원천]',
    TOTAL_SPNSR_AMT        COMMENT '총 후원금액(원) [원천]',
    DNST_RT                COMMENT '중단율(금액 기준) [원천] — 모델 피처',
    PAY_RATE               COMMENT '납입 성공률 [원천] — 모델 피처',
    CHURN_PROB             COMMENT '중단 예측 확률(0~1) · 예측 지평은 발행하지 않는다(원천 기간 표기 불일치)',
    CHURN_CLASS            COMMENT '중단 예측 분류(모델 class) — 업무 판정선 아님',
    INC_PROB               COMMENT '증액 예측 확률(0~1)',
    INC_CLASS              COMMENT '증액 예측 분류(모델 class)',
    LOYAL_PROB             COMMENT '충성회원 예측 확률(0~1) — 모집단이 중단·증액과 다르다(HAS_LOYAL_PRED)',
    LOYAL_CLASS            COMMENT '충성회원 예측 분류(모델 class)',
    LOYAL_CURRENT_TENURE   COMMENT '현재 가입 경과 월수(충성 모델 입력) [원천]',
    LOYAL_ACTIVE_MONTHS_24 COMMENT '초기 24개월 중 활성 월수 [원천]',
    LOYAL_TOTAL_AMT_24     COMMENT '초기 24개월 총 후원금액(원) [원천]',
    HAS_CHURN_PRED         COMMENT '중단 예측 존재 여부 — 분모 판정용',
    HAS_INC_PRED           COMMENT '증액 예측 존재 여부 — 분모 판정용',
    HAS_LOYAL_PRED         COMMENT '충성 예측 존재 여부 — 분모 판정용(모집단 상이)',
    PREDICTION_HAS_ERROR   COMMENT '예측 로그에 오류가 있는 행 여부(PREDICTION:logs:Error 비어있지 않음) · 3종 중 하나라도',
    CHURN_GRADE            COMMENT '중단위험 등급(F-4 · O190) — 기준월 내 백분위: 상위 10% 고위험 · 10~25% 주의 · 나머지 일반 · 예측 없음 NULL. 🔴 확률 임계가 아니라 순위다',
    LOYAL_GRADE            COMMENT '장기회원 등급(F-4 · O190) — 기준월 내 백분위: 상위 5% 최상위 · 5~10% 상 · 10~25% 중 · 나머지 하 · 충성 예측 모집단만(그 외 NULL)'
)
  COMMENT = 'ML 회원단위 예측(중단·증액·충성) 통합. grain=기준월×회원(dedup 후 유일). 원천 중복은 월말 상태 spell 기준으로 단일화했다(원천 미해소·완화). 예측치이며 실적이 아니다.'
AS
WITH mt AS (
  SELECT DISTINCT STDR_MT FROM GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M
  UNION
  SELECT DISTINCT STDR_MT FROM GN_DW.ML.ML_RST_DATA_MBER_INC_12M
),
spell AS (
  SELECT m.STDR_MT,
         h.MBER_NO,
         h.CHN_STAT_CD          AS STAT_CD,
         MAX(h.EFFECTIVE_FROM)  AS LAST_STAT_START_DT,
         MAX(h.SER_NO)          AS LAST_SER_NO
  FROM mt m
  JOIN GN_DW.SILVER.CRM_MEMBER_STATUS_HIST h
    ON  h.EFFECTIVE_FROM <  DATEADD(month, 1, TO_DATE(m.STDR_MT || '01', 'YYYYMMDD'))
    AND (h.EFFECTIVE_TO IS NULL OR h.EFFECTIVE_TO >= TO_DATE(m.STDR_MT || '01', 'YYYYMMDD'))
  GROUP BY 1, 2, 3
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
    c.MBER_STAT_CD                               AS MBER_STAT_CD,
    cd_stat.DTL_CD_NM                            AS MBER_STAT_NAME,
    c.SETLE_CD                                   AS SETLE_CD,
    cd_setle.DTL_CD_NM                           AS SETLE_NAME,
    c.CPR_DIV_CD                                 AS CPR_DIV_CD,
    cd_cpr.CPR_DIV_NM                            AS CPR_DIV_NM,
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
LEFT JOIN loyal l ON l.STDR_MT = u.STDR_MT AND l.MBER_NO = u.MBER_NO
LEFT JOIN (SELECT DISTINCT DTL_CD_ID, DTL_CD_NM FROM GN_DW.SILVER.CRM_CODE WHERE CD_ID = 'MM010') cd_stat
       ON cd_stat.DTL_CD_ID = c.MBER_STAT_CD
LEFT JOIN (SELECT DISTINCT DTL_CD_ID, DTL_CD_NM FROM GN_DW.SILVER.CRM_CODE WHERE CD_ID = 'PM040') cd_setle
       ON cd_setle.DTL_CD_ID = c.SETLE_CD
LEFT JOIN (SELECT DISTINCT CPR_DIV_CD, CPR_DIV_NM FROM GN_DW.SILVER.CRM_CAMPAIGN
            WHERE CPR_DIV_CD IS NOT NULL) cd_cpr
       ON cd_cpr.CPR_DIV_CD = c.CPR_DIV_CD;

-- [2] ML_SPONSOR_RISK_V — ML 후원건단위 이탈 예측
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_SPONSOR_RISK_V (
    STDR_MT              COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
    STDR_MONTH_KEY       COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
    MBER_NO              COMMENT '회원번호 — 회원수는 COUNT(DISTINCT) 로 센다(후원건 grain)',
    SPNSR_BSNS_ID        COMMENT '후원사업ID [원천]',
    SPNSR_BSNS_NAME      COMMENT '후원사업명(SILVER.CRM_SPONSORSHIP) — 미매칭 NULL',
    SPNSR_BSNS_NO        COMMENT '후원사업번호(약정) [원천]',
    CMPGN_CD             COMMENT '캠페인코드 [원천]',
    CMPGN_NAME           COMMENT '캠페인명(SILVER.CRM_CAMPAIGN) — 미매칭 NULL',
    UPPER_CMPGN_CD       COMMENT '상위캠페인코드(캠페인 마스터)',
    UPPER_CMPGN_NAME     COMMENT '상위캠페인명(캠페인 마스터 자기조인)',
    CMPGN_CTGR_NAME      COMMENT '캠페인카테고리명(캠페인 마스터)',
    SETLE_CD             COMMENT '결제수단코드(PM040) — 라벨 미배선',
    TENURE_MONTHS        COMMENT '후원 유지기간(월) [원천]',
    STDR_MT_SPNSR_AMT    COMMENT '기준월 후원금액(원) [원천]',
    CHN_CNT              COMMENT '변경 건수 [원천]',
    INC_CNT              COMMENT '증액 건수 [원천]',
    DEC_CNT              COMMENT '감액 건수 [원천]',
    RE_CNT               COMMENT '재후원 건수 [원천]',
    CANCL_CNT            COMMENT '해지 건수 [원천]',
    PAY_RATE             COMMENT '납입 성공률 [원천]',
    CHURN_PROB           COMMENT '후원건 이탈 예측 확률(0~1) · 예측 지평 미발행',
    CHURN_CLASS          COMMENT '이탈 예측 분류(모델 class) — 업무 판정선 아님',
    PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICTION:logs:Error 비어있지 않음)',
    CHURN_GRADE          COMMENT '후원건 이탈위험 등급(F-4 · O190) — 기준월 내 후원건 백분위: 상위 5% 고위험 · 5~25% 주의 · 나머지 일반. 🔴 확률 임계가 아니라 순위다'
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
    r.CMPGN_CD                                    AS CMPGN_CD,
    cm.CMPGN_NM                                   AS CMPGN_NAME,
    cm.UPPER_CMPGN_CD                             AS UPPER_CMPGN_CD,
    cm_u.CMPGN_NM                                 AS UPPER_CMPGN_NAME,
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
    ARRAY_SIZE(r.PREDICTION:logs:Error) > 0        AS PREDICTION_HAS_ERROR,
    CASE WHEN r.PREDICTION:probability:"1"::FLOAT IS NULL THEN NULL
         WHEN PERCENT_RANK() OVER (PARTITION BY r.STDR_MT, r.PREDICTION:probability:"1"::FLOAT IS NULL
                                   ORDER BY r.PREDICTION:probability:"1"::FLOAT DESC) < 0.05 THEN '고위험'
         WHEN PERCENT_RANK() OVER (PARTITION BY r.STDR_MT, r.PREDICTION:probability:"1"::FLOAT IS NULL
                                   ORDER BY r.PREDICTION:probability:"1"::FLOAT DESC) < 0.25 THEN '주의'
         ELSE '일반' END                             AS CHURN_GRADE
FROM GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M r
LEFT JOIN GN_DW.SILVER.CRM_SPONSORSHIP sp ON sp.SPNSR_BSNS_ID = r.SPNSR_BSNS_ID
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN    cm ON cm.CMPGN_CD      = r.CMPGN_CD
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN  cm_u ON cm_u.CMPGN_CD    = cm.UPPER_CMPGN_CD;

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
-- ⛔ [2026-09-30] 원천 테이블 삭제로 비활성 · 재적재 시 복구
-- UNION ALL
-- SELECT 'DEPT', d.SERIES, og.DEPT_NM,
--        d.STDR_MT, d.TS, d.FORECAST, d.LOWER_BOUND, d.UPPER_BOUND
-- FROM GN_DW.ML.ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT d
-- LEFT JOIN GN_DW.SILVER.CRM_ORG og ON og.DEPT_ID = d.SERIES
-- ⛔ [2026-09-30] 원천 테이블 삭제로 비활성 · 재적재 시 복구
-- UNION ALL
-- SELECT 'SPNSR_BSNS', s.SERIES, sp.SPNSR_BSNS_NM,
--        s.STDR_MT, s.TS, s.FORECAST, s.LOWER_BOUND, s.UPPER_BOUND
-- FROM GN_DW.ML.ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT s
-- LEFT JOIN GN_DW.SILVER.CRM_SPONSORSHIP sp ON sp.SPNSR_BSNS_ID = s.SERIES
-- ⛔ [2026-09-30] 원천 테이블 삭제로 비활성 · 재적재 시 복구
-- UNION ALL
-- SELECT 'NEW_OLD', n.SERIES,
--        CASE n.SERIES WHEN 'NEW' THEN '신규' WHEN 'OLD' THEN '기존' END,
--        n.STDR_MT, n.TS, n.FORECAST, n.LOWER_BOUND, n.UPPER_BOUND
-- FROM GN_DW.ML.ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT n
UNION ALL
SELECT 'CAMPAIGN', c.SERIES, cm.CMPGN_NM,
       c.STDR_MT, c.TS, c.FORECAST, c.LOWER_BOUND, c.UPPER_BOUND
FROM GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT c
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cm ON cm.CMPGN_CD = c.SERIES;

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

-- [5] ML_LTV_FORECAST_V — ML LTV 월별 예측 2종
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_LTV_FORECAST_V (
    LTV_TYPE      COMMENT 'LTV유형: UCMPGN_AVG_MEMBER(상위캠페인 회원평균) · CMPGN_TOTAL(일반캠페인 후원총액) — 🔴 하나로 고정',
    LTV_TYPE_NAME COMMENT 'LTV유형 라벨',
    SERIES_CD     COMMENT '계열 캠페인코드(유형별 상위캠페인 / 일반캠페인)',
    SERIES_NAME   COMMENT '계열 캠페인명(캠페인 마스터) — 미매칭 NULL',
    STDR_MT       COMMENT '예측 실행 기준월 YYYYMM',
    TS            COMMENT '예측월 시작일',
    FORECAST      COMMENT 'LTV 예측값(원) — 회원평균 유형은 합산 금지',
    LOWER_BOUND   COMMENT '95% 신뢰구간 하한(원)',
    UPPER_BOUND   COMMENT '95% 신뢰구간 상한(원)'
)
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

-- [6] ML_LTV_SCORE_V — ML LTV 스코어 2종(계열당 1행)
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_LTV_SCORE_V (
    LTV_TYPE             COMMENT 'LTV유형: UCMPGN_AVG_MEMBER · CMPGN_TOTAL — 🔴 하나로 고정',
    LTV_TYPE_NAME        COMMENT 'LTV유형 라벨',
    SERIES_CD            COMMENT '계열 캠페인코드',
    SERIES_NAME          COMMENT '계열 캠페인명(캠페인 마스터) — 미매칭 NULL',
    STDR_MT              COMMENT '예측 실행 기준월 YYYYMM [원천]',
    HIST_TOTAL_AMT       COMMENT '과거 누적 금액 합계(원 · 학습 기간 전체) [원천]',
    FUTURE_TOTAL_AMT     COMMENT '향후 12개월 예측 금액 합계(원) [원천]',
    LTV                  COMMENT '장기가치 = 과거 누적 + 향후 예측(원) [원천]',
    AVG_MONTHLY_FORECAST COMMENT '향후 월평균 예측 금액(원) [원천]',
    AVG_MONTHLY_ACTUAL   COMMENT '과거 월평균 실제 금액(원) — 산출 맥락값이며 실적 정본 아님 [원천]',
    ACTIVE_MONTHS        COMMENT '과거 활성 월수 [원천]'
)
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

-- [7] ML_FEATURE_IMPORTANCE_V — ML 요인분석(피처 중요도) 2종
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V (
    ANALYSIS_TYPE      COMMENT '분석유형: CHANNEL_NEW_SPNSR · DVLP_INC — 🔴 하나로 고정(유형 내 합계=1)',
    ANALYSIS_TYPE_NAME COMMENT '분석유형 라벨',
    STDR_MT            COMMENT '분석 실행 기준월 YYYYMM [원천]',
    RANK               COMMENT '피처 중요도 순위 [원천]',
    FEATURE            COMMENT '피처명(사람이 지정한 후보) [원천]',
    SCORE              COMMENT '피처 중요도 0~1(유형 내 합계=1) — 금액·건수 아님 · 인과 아님 [원천]',
    FEATURE_TYPE       COMMENT '피처 유형(user_provided = 사람이 지정) [원천]'
)
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

-- [8] ML_ONCE_CONVERSION_V — ML 일시후원회원의 정기후원 전환 예측
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V (
    ONCE_MBER_NO         COMMENT '일시회원번호(S 접두) — 정기회원번호와 체계가 달라 조인 금지',
    OBSERVE_MT           COMMENT '관측월 YYYYMM(원천 STDR_MT) — 모델 실행월이 아니다',
    OBSERVE_MONTH_KEY    COMMENT '관측월 숫자키',
    ONCE_JOIN_MT         COMMENT '관측창 첫 월(회원별 최소 관측월)',
    MONTHS_SINCE_JOIN    COMMENT '관측창 첫 월부터 경과 월수',
    IS_LATEST_OBSERVED   COMMENT '회원별 마지막 관측월 행 여부 — 🔴 [O190] 원천 grain 변경으로 회원당 1행 보장이 깨졌다(원천 확인 중)',
    CONVERT_PROB         COMMENT '정기 전환 예측 확률(0~1) · 예측 지평 미발행',
    CONVERT_CLASS        COMMENT '전환 예측 분류(모델 class) — 업무 판정선 미확정',
    PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICTION:logs:Error 비어있지 않음)',
    SEX_NAME             COMMENT '성별 라벨(SILVER.CRM_MEMBER 현재 스냅샷)',
    MEMBER_DIV_NAME      COMMENT '회원구분 라벨(현재 스냅샷)',
    REGIST_DEPT_NAME     COMMENT '등록부서명(DIM_ORG · 현재 스냅샷)'
)
  COMMENT = 'ML 일시후원회원의 정기후원 전환 예측. grain=일시후원회원×관측월(가입월부터 6개월). 관측월은 모델 실행월이 아니다. 미래 관측월(피처 없음)은 제외했다. 예측치이며 실적이 아니다.'
AS
WITH r AS (
  SELECT o.ONCE_MBER_NO,
         o.STDR_MT,
         MIN(o.STDR_MT) OVER (PARTITION BY o.ONCE_MBER_NO) AS ONCE_JOIN_MT,
         o.PREDICT:probability:"1"::FLOAT   AS CONVERT_PROB,
         o.PREDICT:class::VARCHAR            AS CONVERT_CLASS,
         ARRAY_SIZE(o.PREDICT:logs:Error) > 0 AS PREDICTION_HAS_ERROR
  FROM GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION o
),
obs AS (
  SELECT r.*
  FROM r
  WHERE r.STDR_MT <= TO_CHAR(CURRENT_DATE(), 'YYYYMM')
)
SELECT
    obs.ONCE_MBER_NO                                   AS ONCE_MBER_NO,
    obs.STDR_MT                                        AS OBSERVE_MT,
    TO_NUMBER(obs.STDR_MT)                             AS OBSERVE_MONTH_KEY,
    obs.ONCE_JOIN_MT                                   AS ONCE_JOIN_MT,
    DATEDIFF(month,
             TO_DATE(obs.ONCE_JOIN_MT || '01', 'YYYYMMDD'),
             TO_DATE(obs.STDR_MT      || '01', 'YYYYMMDD')) AS MONTHS_SINCE_JOIN,
    obs.STDR_MT = MAX(obs.STDR_MT) OVER (PARTITION BY obs.ONCE_MBER_NO)
                                                       AS IS_LATEST_OBSERVED,
    obs.CONVERT_PROB                                   AS CONVERT_PROB,
    obs.CONVERT_CLASS                                  AS CONVERT_CLASS,
    obs.PREDICTION_HAS_ERROR                           AS PREDICTION_HAS_ERROR,
    m.SEX_NM                                           AS SEX_NAME,
    m.MBER_DIV_NM                                      AS MEMBER_DIV_NAME,
    o.DEPARTMENT                                       AS REGIST_DEPT_NAME
FROM obs
LEFT JOIN GN_DW.SILVER.CRM_MEMBER m ON m.MEMBER_DK = obs.ONCE_MBER_NO
LEFT JOIN GN_DW.GOLD.DIM_ORG o      ON o.ORG_DK    = ABS(HASH(m.REGIST_DEPT_CD));

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
GRANT SELECT ON VIEW GN_DW.SERVING.ML_LTV_SCORE_V          TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_LTV_SCORE_V          TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_LTV_SCORE_V          TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V    TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V    TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V    TO ROLE GN_DW_SERVICE;
GRANT USAGE ON SCHEMA GN_DW.ML                    TO ROLE GN_DW_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.ML     TO ROLE GN_DW_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.ML  TO ROLE GN_DW_ANALYST;
