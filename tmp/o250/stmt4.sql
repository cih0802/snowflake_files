CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS
  TABLES (
    fx AS GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V
      WITH SYNONYMS ('회비 예측 7축', '회비 예측 축별 배분')
      COMMENT = 'ML 회비 예측 × 7축 실적 비중 배분 추정(base: SERVING.ML_FEE_FORECAST_AXIS_V). [Grain: 기준월 × 캠페인카테고리 × 예측월 × 7축 조합]. [산식: 카테고리 예측 × 직전 12개월 회비 납입 조합 비중]. [원천: ML 회비예측 → SERVING.ML_FEE_FORECAST_V · 비중 → GOLD.WIDE_MEMBER_FEE × FACT_MEMBER_SPONSORSHIP_SPAN].'
  )
  DIMENSIONS (
    fx.STDR_MT AS fx.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월')
      COMMENT = '예측 실행 기준월(YYYYMM). 🔴 여러 기준월 합산은 중복계상이다 — 미지정 시 최신 하나.',
    fx.FORECAST_MONTH_KEY AS fx.FORECAST_MONTH_KEY
      WITH SYNONYMS ('예측월')
      COMMENT = '예측월(YYYYMM).',
    fx.CMPGN_CTGR_NAME AS fx.CMPGN_CTGR_NAME
      WITH SYNONYMS ('캠페인카테고리', '주요캠페인')
      COMMENT = '캠페인카테고리명(예측 계열). 일부는 원천 마스터에 이름이 없어 NULL 이다.',
    fx.NEW_EXISTING AS fx.NEW_EXISTING
      WITH SYNONYMS ('신규기존', '신규/기존', '신규기존구분')
      COMMENT = '납입월 회원 월실적의 신규/기존.',
    fx.HQ_BRANCH_NM AS fx.HQ_BRANCH_NM
      WITH SYNONYMS ('본부지부', '본부/지부', '본부지부구분', '부서구분')
      COMMENT = '본부지부 3분류. 실제값 3종: ''본부''·''지부''·''기타''.',
    fx.HQ_BRANCH_SRC_NM AS fx.HQ_BRANCH_SRC_NM
      WITH SYNONYMS ('본부지부 원값')
      COMMENT = '본부지부 원값 8종. 세부 구분 요청 시만.',
    fx.SPONSORSHIP_NAME AS fx.SPONSORSHIP_NAME
      WITH SYNONYMS ('후원사업', '후원사업구분')
      COMMENT = '후원사업명.',
    fx.CPR_DIV_NM AS fx.CPR_DIV_NM
      WITH SYNONYMS ('법인', '법인구분', '사단법인')
      COMMENT = '약정 법인. 실제값 3종: ''통합''·''사단''·''사복''.',
    fx.CMMN_BRND_NM AS fx.CMMN_BRND_NM
      WITH SYNONYMS ('공통브랜드')
      COMMENT = '약정 획득 공통브랜드.',
    fx.MKTG_CMPGN_NM AS fx.MKTG_CMPGN_NM
      WITH SYNONYMS ('마케팅캠페인명', '마케팅캠페인', '마케팅캠페인명구분')
      COMMENT = '약정 획득 마케팅캠페인명.',
    fx.IS_ALLOCATED AS fx.IS_ALLOCATED
      WITH SYNONYMS ('배분 여부')
      COMMENT = 'FALSE = 실적 비중이 없어 배분 불가인 카테고리 예측(축 NULL). 금액을 따로 밝힌다.'
  )
  METRICS (
    fx.TOTAL_ALLOC_FORECAST_FEE AS SUM(fx.ALLOC_FORECAST_AMT)
      WITH SYNONYMS ('배분 추정 회비', '예측 회비')
      COMMENT = '배분 추정 회비(원). 어떤 축 부분집합으로 나눠도 합 = 카테고리 예측 합. 🔴 추정치.',
    fx.TOTAL_ALLOC_FORECAST_LOWER AS SUM(fx.ALLOC_LOWER)
      WITH SYNONYMS ('배분 하한')
      COMMENT = '배분 하한(원).',
    fx.TOTAL_ALLOC_FORECAST_UPPER AS SUM(fx.ALLOC_UPPER)
      WITH SYNONYMS ('배분 상한')
      COMMENT = '배분 상한(원).'
  )
  COMMENT = 'ML 회비 예측 × 7축 배분 SV. base=SERVING.ML_FEE_FORECAST_AXIS_V. 「회비 예측을 신규기존·본부지부·후원사업·법인·공통브랜드·캠페인카테고리·마케팅캠페인명별로」 질문에 쓴다. 🔴🔴 모델 예측은 캠페인카테고리 단위뿐이다 — 7축 값은 직전 12개월 실적 비중 배분 추정치이며 그렇게 밝힌다. 🔴 단위 = 원. 🔴 기준월 여러 개 합산 금지. 🔴 회비 실적(SV_MEMBER_FEE)과 같은 표에 합산하지 않는다. 기존 축별 배분(SV_ML_FEE_FORECAST FA)과 카테고리 연결 기준이 다르다(이 SV = 약정 테이블 카테고리).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — CTE 안에서는 베이스 컬럼을 SUM 으로 직접 집계한다. (나) CTE 를 거쳐 바깥에서 쓰는 차원은 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 날짜 필터는 이 시맨틱 뷰에 선언된 차원 이름만 쓴다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(WITH SYNONYMS 첫 항목 · 단위 괄호).
  핵심 규칙: (1) 기준월 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (2) 예측월 미지정 시 그 기준월의 예측월 전체 합계를 쓰고 기간을 밝힌다. (3) 요청한 축만 GROUP BY 하고 SUM(fx.ALLOC_FORECAST_AMT) 로 집계한다. (4) IS_ALLOCATED = FALSE 금액은 별도 행 「배분 불가(실적 비중 없음)」로 밝힌다. (5) 금액은 원 단위 반올림 · 🔴 실적 SV 와 조인하지 않는다. (6) 🆕 [O250-D 출력 형식] 모든 출력 열에 한글 별칭 · 차원 열을 지표 열보다 앞에 둔다 · 배분 불가 행은 순위 행과 섞지 않고 맨 끝 1행으로 둔다.';