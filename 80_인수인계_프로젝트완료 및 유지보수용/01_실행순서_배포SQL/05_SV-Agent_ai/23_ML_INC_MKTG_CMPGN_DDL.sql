-- =============================================================================
-- Purpose    : O217-B (2026-10-13
-- Target     : VIEW GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V, SEMANTIC VIEW GN_DW.SERVING.SV_ML_INC_CAMPAIGN
-- Run order  : 운영계 #48
-- Depends on : -
-- Issue      : O217-B
-- =============================================================================
-- ============================================================================
-- 23_ML_INC_MKTG_CMPGN_DDL.sql — O217-B (2026-10-13
--   ML 회원 증액 예측 × MSTR 마케팅캠페인 귀속 서빙 뷰 + SV(SV_ML_INC_CAMPAIGN)
--   · 배경 = 채팅 「10월 증액개발이 높을 마케팅캠페인 상위 10」에 Agent 가 ML 예측을 못 찾고
--     직전 3개월 평균(추세 참고치)으로 답했다. 원인 = 증액 예측(ML_RST_DATA_MBER_INC_12M)에 캠페인 축이 없다.
--   · 구성 = USE → 뷰 → SV → GRANT → 스모크. 파일 단독 실행 가능.
--   · 의존 = SERVING.ML_MEMBER_RISK_V(21_) · SERVING.MSTR_SPNSR_DVLP_V(MSTR 이관)
--   · 롤백 = DROP SEMANTIC VIEW GN_DW.SERVING.SV_ML_INC_CAMPAIGN; DROP VIEW GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V;
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

-- 귀속 규칙(결정적): 기준월이 속한 해 1월 ~ 기준월 사이 MSTR 개발(신규·증액·재후원) 행 중
--   최근 기준일자 → 후원금액 큰 것 → 마케팅캠페인명 오름차순 1행의 마케팅캠페인을 그 회원에 귀속한다.
--   그 기간에 개발 행이 없는 회원은 귀속 축이 NULL 이고 IS_LINKED = FALSE 다(R2-7 · 값 창작 금지).
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V (
    STDR_MT          COMMENT '모델 실행 기준월(YYYYMM)',
    MBER_NO          COMMENT '회원번호',
    INC_PROB         COMMENT '증액확률(0~1 · ML_MEMBER_RISK_V 단일화 값)',
    INC_CLASS        COMMENT '모델 기본 판정 0/1',
    MK_CMPGN_NM      COMMENT '귀속 마케팅캠페인명. NULL = 기준월이 속한 해 1월~기준월 MSTR 개발 이력이 없는 회원(귀속 불가)',
    CMMN_BRND_NM     COMMENT '귀속 개발행의 공통브랜드. NULL = 귀속 불가 또는 캠페인 마스터 값 부재',
    MKTG_CHANNEL_NM  COMMENT '귀속 개발행의 마케팅채널. NULL = 귀속 불가 또는 캠페인 마스터 값 부재',
    CMPGN_CTGR_NM    COMMENT '귀속 개발행의 캠페인카테고리. NULL = 귀속 불가 또는 캠페인 마스터 값 부재',
    ATTR_DVLP_DIV_NM COMMENT '귀속 개발행의 개발구분(신규·증액·재후원). NULL = 귀속 불가',
    ATTR_STRD_MT     COMMENT '귀속 개발행의 MSTR 기준년월(YYYYMM). NULL = 귀속 불가',
    IS_LINKED        COMMENT 'TRUE = 마케팅캠페인에 귀속됨'
)
  COMMENT = 'ML 증액 예측(회원) × MSTR 마케팅캠페인 귀속. grain = 기준월 × 회원. 수치 원천 = SERVING.ML_MEMBER_RISK_V(증액 예측 보유 회원) · 귀속 원천 = SERVING.MSTR_SPNSR_DVLP_V.'
AS
WITH pred AS (
    SELECT STDR_MT, MBER_NO, INC_PROB, INC_CLASS
    FROM GN_DW.SERVING.ML_MEMBER_RISK_V
    WHERE HAS_INC_PRED
),
dev AS (
    SELECT p.STDR_MT, d.MBER_NO,
           d.MK_CMPGN_NM, d.CMMN_BRND_NM, d.MKTG_CHANNEL_NM, d.CMPGN_CTGR_NM,
           d.DVLP_DIV_NM, d.STRD_MT AS ATTR_STRD_MT,
           ROW_NUMBER() OVER (
               PARTITION BY p.STDR_MT, d.MBER_NO
               ORDER BY d.STRD_DE DESC, d.SPNSR_AMT DESC NULLS LAST, d.MK_CMPGN_NM ASC NULLS LAST
           ) AS RN
    FROM pred p
    JOIN GN_DW.SERVING.MSTR_SPNSR_DVLP_V d
      ON d.MBER_NO = p.MBER_NO
     AND d.STRD_MT BETWEEN LEFT(p.STDR_MT, 4) || '01' AND p.STDR_MT
     AND d.DVLP_DIV_NM IN ('신규', '증액', '재후원')
)
SELECT p.STDR_MT,
       p.MBER_NO,
       p.INC_PROB,
       p.INC_CLASS,
       d.MK_CMPGN_NM,
       d.CMMN_BRND_NM,
       d.MKTG_CHANNEL_NM,
       d.CMPGN_CTGR_NM,
       d.DVLP_DIV_NM,
       d.ATTR_STRD_MT,
       (d.MBER_NO IS NOT NULL)
FROM pred p
LEFT JOIN dev d
  ON d.STDR_MT = p.STDR_MT AND d.MBER_NO = p.MBER_NO AND d.RN = 1;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_INC_CAMPAIGN
  TABLES (
    ic AS GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V
      PRIMARY KEY (STDR_MT, MBER_NO)
      WITH SYNONYMS ('증액 예측 캠페인', '캠페인별 증액 예측', '마케팅캠페인 증액 예측')
      COMMENT = 'ML 회원 증액 예측을 MSTR 마케팅캠페인에 귀속한 표(base: SERVING.ML_INC_BY_MKTG_CMPGN_V). [Grain: 기준월 × 회원]. [귀속: 기준월이 속한 해 1월~기준월 MSTR 개발(신규·증액·재후원) 중 최근 1건의 마케팅캠페인]. [원천: ML 증액 예측 → SERVING.ML_MEMBER_RISK_V · MSTR 이관 → SERVING.MSTR_SPNSR_DVLP_V].'
  )
  DIMENSIONS (
    ic.STDR_MT AS ic.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '모델 실행월')
      COMMENT = '모델 실행 기준월(YYYYMM 문자열). 🔴 여러 기준월을 합산하지 않는다 — 미지정 시 최신 기준월 하나로 한정한다. 실제값은 조회로 확인한다.',
    ic.MBER_NO AS ic.MBER_NO
      WITH SYNONYMS ('회원번호', '회원')
      COMMENT = '회원번호. 회원수는 이 축의 중복제거로 센다.',
    ic.MK_CMPGN_NM AS ic.MK_CMPGN_NM
      WITH SYNONYMS ('마케팅캠페인', '마케팅캠페인명', '마케팅 캠페인')
      COMMENT = '회원에 귀속한 마케팅캠페인명(MSTR 개발 이력 기준 · 회원당 1개). 🔴 NULL 은 두 가지다 — IS_LINKED = FALSE 이면 그 해 MSTR 개발 이력이 없어 귀속할 수 없는 회원, IS_LINKED = TRUE 이면 귀속한 개발행의 캠페인에 마케팅캠페인 값이 없는 회원이다. 둘 다 캠페인 순위에서 빼고 회원수를 따로 밝힌다.',
    ic.CMMN_BRND_NM AS ic.CMMN_BRND_NM
      WITH SYNONYMS ('공통브랜드')
      COMMENT = '귀속 개발행의 공통브랜드(캠페인 마스터 현재값).',
    ic.MKTG_CHANNEL_NM AS ic.MKTG_CHANNEL_NM
      WITH SYNONYMS ('마케팅채널')
      COMMENT = '귀속 개발행의 마케팅채널(캠페인 마스터 현재값).',
    ic.CMPGN_CTGR_NM AS ic.CMPGN_CTGR_NM
      WITH SYNONYMS ('캠페인카테고리', '주요캠페인')
      COMMENT = '귀속 개발행의 캠페인카테고리(캠페인 마스터 현재값).',
    ic.ATTR_DVLP_DIV_NM AS ic.ATTR_DVLP_DIV_NM
      WITH SYNONYMS ('귀속 개발구분')
      COMMENT = '귀속에 쓴 개발행의 개발구분(신규·증액·재후원).',
    ic.ATTR_STRD_MT AS ic.ATTR_STRD_MT
      WITH SYNONYMS ('귀속 개발월')
      COMMENT = '귀속에 쓴 개발행의 MSTR 기준년월(YYYYMM).',
    ic.INC_CLASS AS ic.INC_CLASS
      WITH SYNONYMS ('증액 예측 판정')
      COMMENT = '모델 기본 임계(0.5) 판정. 실제값 2종: ''0''·''1''. 🔴 ''1'' 회원이 극소수라 캠페인 비교에 쓰지 않는다 — 비교는 기대 증액 회원수·평균 증액확률로 한다.',
    ic.IS_LINKED AS ic.IS_LINKED
      WITH SYNONYMS ('캠페인 귀속 여부')
      COMMENT = 'TRUE = 마케팅캠페인에 귀속된 예측 회원. 분모를 밝힐 때 쓴다.'
  )
  METRICS (
    ic.PREDICTED_MEMBERS AS COUNT(DISTINCT ic.MBER_NO)
      WITH SYNONYMS ('예측 대상 회원수')
      COMMENT = '증액 예측 대상 회원수(명 · 중복제거). 전체 회원수가 아니다.',
    ic.EXPECTED_INC_MEMBERS AS SUM(ic.INC_PROB)
      WITH SYNONYMS ('기대 증액 회원수', '예상 증액 회원수')
      COMMENT = '모델 기대 증액 회원수(명) = 증액확률의 합. 회원 grain 이라 캠페인별 값은 더해도 된다(같은 기준월 안). 🔴 「10월 증액 건수」가 아니다 — 모델 예측 기간 안에 증액할 것으로 기대되는 회원 수다.',
    ic.AVG_INC_PROB AS AVG(ic.INC_PROB)
      WITH SYNONYMS ('평균 증액확률', '증액확률')
      COMMENT = '증액확률 평균(0~1 · 표기는 %로). 회원 수가 적은 캠페인은 값이 흔들린다 — 예측 대상 회원수와 함께 보인다.',
    ic.MODEL_INC_MEMBERS AS COUNT(DISTINCT CASE WHEN ic.INC_CLASS = '1' THEN ic.MBER_NO END)
      WITH SYNONYMS ('모델 증액분류 회원수')
      COMMENT = '모델이 증액으로 분류한 회원수(명). 극소수다.'
  )
  COMMENT = 'ML 증액 예측 × 마케팅캠페인 SV. base=SERVING.ML_INC_BY_MKTG_CMPGN_V. 「증액이 높을 것으로 예상되는 마케팅캠페인·공통브랜드·마케팅채널·캠페인카테고리」 질문에 쓴다. 🔴🔴 머신러닝 예측치이며 실적이 아니다 — MSTR 증액 실적(SV_MSTR_SPNSR_DVLP)과 같은 표에 합산하지 않고 표를 나눈다. 🔴 머신러닝은 테스트 단계다. 🔴🔴 예측은 회원 단위 증액확률이다 — 캠페인 값은 그 캠페인에 귀속한 회원들의 확률을 모은 것이고 「N월 증액 건수」 예측이 아니다. 🔴 귀속은 Agent 데이터 규칙이다(그 해 MSTR 최근 개발 1건의 마케팅캠페인) · 모델이 캠페인을 학습한 것이 아니다. 🔴 귀속 불가 회원(MK_CMPGN_NM NULL)은 순위에서 빼고 그 회원수를 따로 밝힌다. 활성: 예측 대상 회원수·기대 증액 회원수·평균 증액확률·모델 증액분류 회원수 · 기준월·마케팅캠페인·공통브랜드·마케팅채널·캠페인카테고리 축. 비활성: 증액 금액 예측(원천에 없음) · 월별 증액 건수 예측(원천에 없음).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥에서 쓰는 차원은 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 날짜 필터는 이 시맨틱 뷰에 선언된 차원 이름만 쓴다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(WITH SYNONYMS 첫 항목 · 단위 괄호). 영문 식별자를 출력 컬럼명으로 남기지 않는다.
  핵심 규칙: (1) 기준월 미지정 시 최신 기준월(MAX(ic.STDR_MT)) 하나로 한정하고 밝힌다 — 비상관 CTE 로 구해 CROSS JOIN 한다. (2) 「증액이 높을 캠페인 상위 N」 = ic.MK_CMPGN_NM IS NOT NULL 로 한정하고 마케팅캠페인별 SUM(ic.INC_PROB) 내림차순 상위 N 을 반환한다. 열 = 마케팅캠페인 · 예측 대상 회원수 COUNT(DISTINCT ic.MBER_NO) · 기대 증액 회원수 ROUND(SUM(ic.INC_PROB),1) · 평균 증액확률(%) ROUND(AVG(ic.INC_PROB)*100,2) · 구성비(%) = 그 캠페인 SUM(INC_PROB) ÷ 귀속 회원 전체 SUM(INC_PROB) × 100(소수 2자리 · 분모는 SQL 로 구한다). (3) 귀속 불가 회원수(ic.MK_CMPGN_NM IS NULL 의 COUNT DISTINCT)와 전체 예측 대상 회원수를 별도 행 또는 별도 쿼리로 함께 반환한다. (4) 평균 증액확률 순위를 요청받으면 예측 대상 회원 100명 이상 캠페인으로 한정하고 그 하한을 밝힌다. (5) 공통브랜드·마케팅채널·캠페인카테고리별도 같은 방식이다. (6) 🔴 실적 SV 와 조인하지 않는다.';

GRANT SELECT ON VIEW GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V TO ROLE GN_DW_SERVICE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_INC_CAMPAIGN TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_INC_CAMPAIGN TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_INC_CAMPAIGN TO ROLE GN_DW_SERVICE;

-- 스모크(2026-10-13 기대값 = 기준월 202609 · 예측 70,158 · 귀속 28,324)
SELECT STDR_MT, COUNT(DISTINCT MBER_NO) AS PRED, COUNT_IF(IS_LINKED) AS LINKED
FROM GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V
GROUP BY STDR_MT ORDER BY STDR_MT;
