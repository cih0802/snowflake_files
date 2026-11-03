-- O246-B 신규 — GN_DW.SERVING.SV_ML_MEMBER_PRED_BRIDGE (회원 브리지 SV · 사용자 승인 2026-10-19)
USE ROLE GN_DW_ADMIN;
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_BRIDGE
  TABLES (
    mb AS GN_DW.SERVING.ML_MEMBER_PRED_BRIDGE_V
      PRIMARY KEY (STDR_MT, MBER_NO)
      WITH SYNONYMS ('예측 회원 브리지', '예측 실적 매칭', '중단 예측 회원 실적', '예측 회원 캠페인')
      COMMENT = 'ML 회원 단위 예측(중단·증액·충성) × 실적 축·실적 상태 (base: SERVING.ML_MEMBER_PRED_BRIDGE_V). [Grain: 기준월 × 회원]. [축: 대표 약정의 후원사업·획득 캠페인카테고리·마케팅캠페인명·공통브랜드·UTM·유입경로 · 금액대·기간대·납입방식]. [실적 상태: 최근 청구액·직전 12개월 납입·미납·개발 건수]. [주의: 축으로 나눈 회원수는 매칭 집계 · 확률 합은 추정치].'
  )
  DIMENSIONS (
    mb.STDR_MT AS mb.STDR_MT WITH SYNONYMS ('기준월', '예측 기준월') COMMENT = '모델 실행 기준월(YYYYMM). 🔴 여러 기준월 합산 금지 · 미지정 시 최신 1개.',
    mb.MBER_NO AS mb.MBER_NO WITH SYNONYMS ('회원번호') COMMENT = '회원번호. 명단 질문에만 쓴다.',
    mb.CHURN_GRADE AS mb.CHURN_GRADE WITH SYNONYMS ('중단위험 등급', '고위험군') COMMENT = '중단위험 등급(고위험/주의/일반 · 기준월 내 순위 구간). NULL = 중단 예측 대상 아님.',
    mb.LOYAL_GRADE AS mb.LOYAL_GRADE WITH SYNONYMS ('장기회원 등급') COMMENT = '충성(장기회원) 등급. NULL = 충성 예측 대상 아님.',
    mb.INC_CLASS AS mb.INC_CLASS WITH SYNONYMS ('증액 판정') COMMENT = '증액 모델 판정 0/1. NULL = 증액 예측 대상 아님.',
    mb.HAS_CHURN_PRED AS mb.HAS_CHURN_PRED WITH SYNONYMS ('중단 예측 대상') COMMENT = 'TRUE = 중단 예측 대상. 중단 관련 질문은 이 값을 TRUE 로 필터한다.',
    mb.HAS_INC_PRED AS mb.HAS_INC_PRED WITH SYNONYMS ('증액 예측 대상') COMMENT = 'TRUE = 증액 예측 대상.',
    mb.HAS_LOYAL_PRED AS mb.HAS_LOYAL_PRED WITH SYNONYMS ('충성 예측 대상') COMMENT = 'TRUE = 충성 예측 대상.',
    mb.SPONSORSHIP_NAME AS mb.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업') COMMENT = '대표 약정의 후원사업명(약정금액 최대 활동 약정).',
    mb.ACQ_CMPGN_CTGR_NM AS mb.ACQ_CMPGN_CTGR_NM WITH SYNONYMS ('캠페인카테고리') COMMENT = '대표 약정의 획득 캠페인카테고리(적재 시점 동결값).',
    mb.ACQ_MKTG_CMPGN_NM AS mb.ACQ_MKTG_CMPGN_NM WITH SYNONYMS ('마케팅캠페인명', '마케팅캠페인') COMMENT = '대표 약정의 획득 마케팅캠페인명.',
    mb.ACQ_CMMN_BRND_NM AS mb.ACQ_CMMN_BRND_NM WITH SYNONYMS ('공통브랜드', '브랜드') COMMENT = '대표 약정의 획득 공통브랜드.',
    mb.ACQ_MKTG_UTM_NM AS mb.ACQ_MKTG_UTM_NM WITH SYNONYMS ('UTM', '마케팅 UTM') COMMENT = '대표 약정의 획득 UTM. ⚠️ 값 보유가 일부(디지털 경로 위주)라 NULL 이 많다 — NULL 비중을 함께 밝힌다.',
    mb.ACQ_INFLOW_PATH_NM AS mb.ACQ_INFLOW_PATH_NM WITH SYNONYMS ('유입경로', '회원유입경로') COMMENT = '대표 약정의 획득 회원유입경로.',
    mb.REP_SPNSR_SOURCE AS mb.REP_SPNSR_SOURCE WITH SYNONYMS ('대표 약정 출처') COMMENT = '활동약정 / 종료약정(활동 약정이 없어 마지막 종료 약정으로 보완).',
    mb.AMOUNT_BAND AS mb.AMOUNT_BAND WITH SYNONYMS ('후원금액대') COMMENT = '후원금액대(기준월 행 없으면 직전 실적 월 값 · ATTR_FALLBACK).',
    mb.TENURE_BAND AS mb.TENURE_BAND WITH SYNONYMS ('유지기간대', '후원기간대') COMMENT = '유지기간대(폴백 동일).',
    mb.PAYMENT_METHOD_NAME AS mb.PAYMENT_METHOD_NAME WITH SYNONYMS ('납입방식', '결제수단') COMMENT = '납입방식(폴백 동일 · 잠정).',
    mb.ATTR_FALLBACK AS mb.ATTR_FALLBACK WITH SYNONYMS ('특성 보완 여부') COMMENT = 'TRUE = 금액대·기간대가 직전 실적 월 값으로 보완됐다.',
    mb.IS_UNPAID_STDR AS mb.IS_UNPAID_STDR WITH SYNONYMS ('기준월 미납 여부') COMMENT = 'TRUE = 기준월에 미납 청구가 있다(실적).'
  )
  METRICS (
    mb.PRED_MEMBERS AS COUNT(DISTINCT mb.MBER_NO) WITH SYNONYMS ('예측 대상 회원수') COMMENT = '예측 대상 회원수(명 · 매칭 집계).',
    mb.HIGH_CHURN_MEMBERS AS COUNT(DISTINCT IFF(mb.CHURN_GRADE = '고위험', mb.MBER_NO, NULL)) WITH SYNONYMS ('중단 고위험 회원수') COMMENT = '중단위험 고위험 회원수(명 · 매칭 집계).',
    mb.EXPECTED_CHURN_MEMBERS AS SUM(mb.CHURN_PROB) WITH SYNONYMS ('기대 중단 회원수', '예상 중단 회원수') COMMENT = '기대 중단 회원수(명 · 추정치) = 중단확률 합. 🔴 중단 예측 데이터 기반 추정치이며 모델이 직접 낸 건수가 아니다.',
    mb.EXPECTED_REMAIN_MEMBERS AS SUM(IFF(mb.HAS_CHURN_PRED, 1 - mb.CHURN_PROB, NULL)) WITH SYNONYMS ('활동 유지 기대 회원수', '예상 활동회원') COMMENT = '활동 유지 기대 회원수(명 · 추정치) = 중단 예측 대상 중 (1 − 중단확률) 합. 🔴 활동회원 예측 모델은 없다 — 중단 예측 기반 추정치.',
    mb.FEE_AT_RISK AS SUM(mb.CHURN_PROB * mb.LAST_BILLED_AMT) WITH SYNONYMS ('회비 위험액', '중단 예상 회비') COMMENT = '월 회비 위험액(원 · 추정치) = 중단확률 × 최근 청구액 합. 🔴 회비 예측 모델 값이 아니다 — 중단 예측 기반 추정치.',
    mb.EXPECTED_INC_MEMBERS AS SUM(mb.INC_PROB) WITH SYNONYMS ('기대 증액 회원수') COMMENT = '기대 증액 회원수(명 · 추정치) = 증액확률 합.',
    mb.AVG_CHURN_PROB AS AVG(mb.CHURN_PROB) WITH SYNONYMS ('평균 중단확률') COMMENT = '평균 중단확률(0~1 · 예측치 평균).',
    mb.UNPAID_STDR_MEMBERS AS COUNT(DISTINCT IFF(mb.IS_UNPAID_STDR, mb.MBER_NO, NULL)) WITH SYNONYMS ('기준월 미납 회원수') COMMENT = '기준월 미납 회원수(명 · 실적).',
    mb.TOTAL_UNPAID_AMT_12M AS SUM(mb.UNPAID_AMT_12M) WITH SYNONYMS ('직전 12개월 미납액') COMMENT = '직전 12개월 미납 청구액 합(원 · 실적).',
    mb.TOTAL_PAID_FEE_12M AS SUM(mb.PAID_FEE_12M) WITH SYNONYMS ('직전 12개월 납입회비') COMMENT = '직전 12개월 납입회비 합(원 · 실적).',
    mb.TOTAL_LAST_BILLED_AMT AS SUM(mb.LAST_BILLED_AMT) WITH SYNONYMS ('최근 월 청구액') COMMENT = '마지막 청구월 청구액 합(원 · 실적).',
    mb.TOTAL_DVLP_UP_CNT_12M AS SUM(mb.DVLP_UP_CNT_12M) WITH SYNONYMS ('직전 12개월 개발건수') COMMENT = '직전 12개월 신규·증액·재후원 개발 건수(건 · 실적).',
    mb.TOTAL_DVLP_DOWN_CNT_12M AS SUM(mb.DVLP_DOWN_CNT_12M) WITH SYNONYMS ('직전 12개월 감액중단건수') COMMENT = '직전 12개월 감액·후원중단 건수(건 · 실적).'
  )
  COMMENT = 'ML 회원 단위 예측 × 실적 브리지 SV. base=SERVING.ML_MEMBER_PRED_BRIDGE_V. 🔴🔴 값 라벨을 구분한다 — 회원수·실적 금액은 매칭 집계/실적, 확률 합(기대 중단·활동 유지·회비 위험액·기대 증액)은 예측 데이터 기반 추정치다. 🔴 미납·활동·회비 예측 모델은 없다 — 이 SV 의 추정 지표로 답하고 그 사실을 밝힌다. 🔴 머신러닝은 테스트 단계다. 🔴 예측 지평은 원천 확인 중이다(숫자로 말하지 않는다). 🔴 축은 단일 대표 약정 기준이다(회원이 여러 약정을 가지면 약정금액 최대 활동 약정).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — CTE 안에서는 베이스 컬럼을 직접 집계한다. (나) CTE 를 거쳐 바깥에서 쓰는 차원은 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 날짜 필터는 이 SV 에 선언된 차원 이름만 쓴다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율·평균·확률·기대 회원수 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림한다. 금액·건수·명수는 숫자형 그대로 둔다. [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(동의어 첫 항목 + 단위). [O206-C 합계 규칙] 합계·분모는 SQL 이 낸다 — GROUP BY ROLLUP 합계 행을 함께 반환하고, 합계 행에는 COALESCE(차원, ''(미매칭)'') 를 씌우지 않는다(CASE WHEN GROUPING(차원) = 1 THEN ''전체 합계'' WHEN 차원 IS NULL THEN ''(미매칭)'' ELSE 차원 END).
  핵심 규칙: (1) 🔴 최신 STDR_MT 1개로 한정한다. (2) 🔴 중단 관련 질문은 HAS_CHURN_PRED = TRUE 로, 증액은 HAS_INC_PRED, 충성은 HAS_LOYAL_PRED 로 필터한다(모집단이 다르다). (3) 축별 분해는 차원에 GROUP BY 하고 NULL 축값은 (미매칭) 별도 행으로 둔다. (4) 🔴 NULL 축값이 전체 회원의 절반 이상이면 결과에 그 비중을 함께 반환한다(답변 단계에서 보완 설명에 쓴다). (5) 기대 중단 회원수·활동 유지 기대 회원수·회비 위험액·기대 증액 회원수는 추정치 지표다 — 출력 별칭에 (추정) 을 붙인다. (6) 회원번호 명단 질문만 MBER_NO 를 선택하고 LIMIT 을 둔다.';
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_BRIDGE TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_BRIDGE TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_PRED_BRIDGE TO ROLE GN_DW_SERVICE;
