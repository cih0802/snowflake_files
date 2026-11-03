# O245 — 21_ML_SERVING_뷰_DDL.sql 패치: ML 특성 축 확장(사용자 승인 2026-10-18)
#   ① ML_MEMBER_ATTR_ASOF_V += 등록부서 · 법인구분(사단/사복) · 활동 약정 수
#   ② ML_ONCE_CONVERSION_V += 법인구분 · 후원금액대 · 유지기간대 · 납입방식 · 후원사업
#   ③ 신설 ML_CHURN_BY_SPONSORSHIP_V(기준월 × 회원 × 캠페인카테고리 × 후원사업)
# 사용: python3 tmp/o245/patch_21.py test   (본문 SELECT 검증만 · 결과 = tmp/o245/patch_21_test.md)
#       python3 tmp/o245/patch_21.py apply  (파일 반영 · 원본 = tmp/o245/21_before.sql)
import io, sys, shutil, hashlib
sys.path.insert(0, '/workspace/scripts')

P = '/workspace/05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql'

ONCE_OLD_START = 'CREATE OR REPLACE VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V ('
ONCE_OLD_END = 'LEFT JOIN GN_DW.GOLD.DIM_ORG og     ON og.ORG_DK   = ABS(HASH(m.REGIST_DEPT_CD));'
ONCE_BODY = """WITH k AS (
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
LEFT JOIN sp  ON sp.STDR_MT = o.STDR_MT AND sp.ONCE_MBER_NO = o.ONCE_MBER_NO"""
ONCE_NEW = """CREATE OR REPLACE VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V (
    STDR_MT              COMMENT '기준월 YYYYMM(모델 실행월) — 여러 기준월 합산은 중복계상',
    STDR_MONTH_KEY       COMMENT '기준월 숫자키 YYYYMM(STDR_MT 파생)',
    ONCE_MBER_NO         COMMENT '일시회원번호(S 접두) — 정기회원번호와 체계가 달라 조인 금지',
    CONVERT_PROB         COMMENT '정기 전환 예측 확률(0~1) · 예측 지평 미발행',
    CONVERT_CLASS        COMMENT '전환 예측 분류(모델 class) — 업무 판정선 미확정',
    PREDICTION_HAS_ERROR COMMENT '예측 로그에 오류가 있는 행 여부(PREDICT:logs:Error 비어있지 않음)',
    SEX_NAME             COMMENT '성별 라벨(SILVER.CRM_MEMBER 현재 스냅샷)',
    MEMBER_DIV_NAME      COMMENT '회원구분 라벨(현재 스냅샷)',
    REGIST_DEPT_NAME     COMMENT '등록부서명(DIM_ORG · 현재 스냅샷)',
    CPR_DIV_NAME         COMMENT '🆕 [O245] 법인구분(사단·사복 · 코드사전 CM019 · 현재 스냅샷)',
    AMOUNT_BAND          COMMENT '🆕 [O245] 후원금액대(기준월 이하 가장 최근 납입월의 일시후원 납입액 · 정기 금액대1 과 같은 5만원 구간) — 🔴 정기회원 금액대(약정금액 기준)와 기준이 다르다 · 납입 이력이 없으면 NULL',
    TENURE_BAND          COMMENT '🆕 [O245] 유지기간대(같은 월실적 행의 기간대1) — 월실적 행이 없으면 NULL',
    PAYMENT_METHOD_NAME  COMMENT '🆕 [O245] 납입방식(기준월 이하 가장 최근 청구월의 청구액 최대 결제수단 · 잠정) — 청구 이력이 없으면 NULL',
    SPONSORSHIP_NAME     COMMENT '🆕 [O245] 후원사업(기준월 이하 가장 최근 납입월의 납입액 최대 후원사업) — 납입 이력이 없으면 NULL'
)
  COMMENT = 'ML 일시후원회원의 정기후원 전환 예측. grain=기준월×일시후원회원이나 원천이 회원당 다중 예측행을 담는다(실행순번 없음 · #1 유지). 회원수는 중복제거로 센다. 예측치이며 실적이 아니다. 🆕 [O245] 캠페인카테고리·회원상태·연령대·지역은 일시회원에 원천 값이 없어(2026-10-18 실측 0건) 컬럼을 두지 않는다.'
AS
""" + ONCE_BODY + ';'

ATTR_OLD_START = 'CREATE OR REPLACE VIEW GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V ('
ATTR_OLD_END = 'LEFT JOIN p ON p.MONTH_KEY = m.STDR_MT::INT AND p.MEMBER_DK = m.MBER_NO;'
ATTR_BODY = """WITH m AS (
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
LEFT JOIN ac ON ac.STDR_MT = m.STDR_MT AND ac.MBER_NO = m.MBER_NO"""
ATTR_NEW = """CREATE OR REPLACE VIEW GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V (
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
  CPR_DIV_NAME COMMENT '🆕 [O245] 법인구분(사단·사복 · 코드사전 CM019 · CRM 회원 마스터 현재 값)',
  ACTIVE_SPNSR_CNT COMMENT '🆕 [O245] 기준월 말 활동 중인 후원약정 수(건 · 카테고리 무관 전체) — 0 = 활동 약정 없음'
) COMMENT = 'O241-M ML 예측 회원 기준월 시점 특성. grain = 기준월 × 회원. 모델 피처 아님. 🆕 [O245] 등록부서·법인구분·활동 약정 수 추가.' AS
""" + ATTR_BODY + ';'

SP_BODY = """WITH mt AS (
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
  ON m.STDR_MT = g.STDR_MT AND m.MBER_NO = g.MBER_NO AND m.HAS_CHURN_PRED"""
SP_NEW = """
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
""" + SP_BODY + """;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V TO ROLE GN_DW_SERVICE;
"""
TESTS = [
    ('ONCE', 'select count(*) rows_, count(distinct STDR_MT||ONCE_MBER_NO) keys_, count(distinct ONCE_MBER_NO) members, '
             'count(distinct iff(CPR_DIV_NAME is not null, ONCE_MBER_NO, null)) cpr, count(distinct iff(AMOUNT_BAND is not null, ONCE_MBER_NO, null)) amt, '
             'count(distinct iff(TENURE_BAND is not null, ONCE_MBER_NO, null)) tenure, count(distinct iff(PAYMENT_METHOD_NAME is not null, ONCE_MBER_NO, null)) pm, '
             'count(distinct iff(SPONSORSHIP_NAME is not null, ONCE_MBER_NO, null)) spnsr from (%s)' % ONCE_BODY),
    ('ATTR', 'select count(*) rows_, count(distinct STDR_MT||MBER_NO) keys_, count_if(c13 <> \'(미매칭)\') dept, count_if(c14 <> \'(미매칭)\') cpr, '
             'count_if(c15 > 0) active, max(c15) max_active from (select * from (%s) t(c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,c14,c15)) '
             'x(STDR_MT,MBER_NO,a,b,c,d,e,f,g,h,i,j,c13,c14,c15)' % ATTR_BODY),
    ('SPNSR', 'select count(*) rows_, count(distinct STDR_MT||MBER_NO||coalesce(CMPGN_CTGR_NM,\'~\')||coalesce(SPONSORSHIP_NAME,\'~\')) keys_, '
              'count(distinct MBER_NO) members, count_if(SPONSORSHIP_NAME is null) null_spnsr, count_if(c6) member_pred, count_if(c10) sponsor_pred '
              'from (%s) t(STDR_MT,MBER_NO,CMPGN_CTGR_NM,SPONSORSHIP_NAME,c5,c6,c7,c8,c9,c10,c11,c12,c13)' % SP_BODY),
]


def run_tests():
    from sfconn import conn, q
    cn = conn()
    out = io.open('/workspace/tmp/o245/patch_21_test.md', 'w', encoding='utf-8')
    for name, sql in TESTS:
        try:
            cols, rows = q(sql, cn)
            out.write('## %s\n%s\n%s\n\n' % (name, ' | '.join(cols), ' | '.join(str(x) for x in rows[0])))
        except Exception as e:
            out.write('## %s\nERROR %s\n\n' % (name, str(e)[:500]))
    out.close()
    cn.close()


def apply():
    a = hashlib.sha256(open(P, 'rb').read()).hexdigest()
    b = hashlib.sha256(open(P, 'rb').read()).hexdigest()
    assert a == b
    s = io.open(P, encoding='utf-8', newline='').read()
    for st, en, new in ((ONCE_OLD_START, ONCE_OLD_END, ONCE_NEW), (ATTR_OLD_START, ATTR_OLD_END, ATTR_NEW)):
        assert s.count(st) == 1 and s.count(en) == 1, st
        i, j = s.index(st), s.index(en) + len(en)
        s = s[:i] + new + s[j:]
    assert 'ML_CHURN_BY_SPONSORSHIP_V' not in s
    s = s.rstrip('\n') + '\n' + SP_NEW
    shutil.copyfile(P, '/workspace/tmp/o245/21_before.sql')
    io.open(P, 'w', encoding='utf-8', newline='').write(s)
    print('applied', a[:12], '->', hashlib.sha256(open(P, 'rb').read()).hexdigest()[:12])


if __name__ == '__main__':
    run_tests() if sys.argv[1] == 'test' else apply()
