-- GN_DW ML 예측결과 Semantic View DDL 정본 — SV 7종
-- Co-authored with CoCo · [2026-08-14 O74]
-- ============================================================================
-- ▶ 이 파일의 위상
--   ML 예측결과 SV **7종**을 배포한다. base 는 전부 `21_ML_SERVING_뷰_DDL.sql` 의 SERVING 뷰다.
--   🔴 SV 는 `GN_DW.ML` 테이블을 **직접 참조하지 않는다**(교체 내성 · 설계문서 §5).
--   선행 조건 = `21_ML_SERVING_뷰_DDL.sql` 실행. dbt build 와 무관하다.
--   실행 역할 = `GN_DW_ADMIN` · `CREATE OR ALTER` 이므로 재실행 시 GRANT·소유권 보존.
--
-- ▶ 🔴 왜 7종으로 갈랐는가 (근거는 부서가 아니라 grain·단위 실측)
--   1. 개발금액 예측 5종 = 같은 단위(만원)이고 교차검증됨 ⇒ 1개 SV 로 통합
--      (부서 30계열 평균×30 ≈ 전사 · 신규기존 2계열 합 ≈ 전사)
--   2. 회비 예측 = 단위가 **원** ⇒ 개발금액과 같은 SV 에 두면 만 배 오차
--   3. LTV 예측 ↔ LTV 스코어 = grain 이 다르다(계열×12행 vs 계열×1행) ⇒ 분리
--   4. 회원 risk ↔ 후원건 risk = 회원당 후원건 다건 ⇒ 합치면 팬아웃(`O8` 유형)
--   5. 요인분석 = 측정 대상이 데이터가 아니라 **모델**이다 ⇒ 업무 수치와 섞지 않는다
--
-- ▶ 🔴 전 SV 공통 발행 문안 (없으면 조용한 오답이 난다)
--   · 예측치이며 실적이 아니다 — 실적 SV 와 같은 표에 합산하지 않는다
--   · `STDR_MT` 는 **모델 실행 기준월**이다 ⇒ 여러 기준월을 합산하면 같은 미래월이 중복계상된다
--     🔴 현재 적재는 1개 기준월뿐이라 **아직 무증상**이다. 증상이 없는 지금 문안을 넣는다.
--   · `LOWER/UPPER_BOUND` 는 95% 신뢰구간이며 별개 실적이 아니다
--   · 위험 판정 **업무 임계값은 미확정**이다 ⇒ 모델 기본 판정(`CLASS`)을 「업무 위험」으로 단정하지 않는다
--   · 머신러닝은 **테스트 단계**이며 모델·구조가 교체될 수 있다
--
-- ▶ COMMENT 규약(기존 SV 와 동일)
--   🔴 수치를 넣지 않는다 — Agent 가 COMMENT 를 근거로 인용하므로 적재량이 변하면 거짓이 된다.
--      (규모·비율은 설계문서 `20_ML_SV_설계.md` 와 이슈원장에만 둔다)
--   저카디널리티 코드 차원은 실제 값을 열거한다.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;


/* =====================================================================================
   [1] SV_ML_MEMBER_RISK — 회원단위 예측(중단·증액·충성)
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_RISK
  TABLES (
    mr AS GN_DW.SERVING.ML_MEMBER_RISK_V
      PRIMARY KEY (STDR_MT, MBER_NO)
      WITH SYNONYMS ('회원 예측', '회원 위험', '중단 예측', '증액 예측', '충성회원 예측')
      COMMENT = '회원단위 ML 예측 통합(중단·증액·충성). grain=기준월×회원. 🔴예측치이며 실적이 아니다. 🔴원천은 회원당 여러 행을 담고 있어(상태 spell 다중) 월말 상태 기준으로 단일화한 뷰다 — 원천 미해소 상태의 완화이며 원천 교정 시 값이 변한다. 🔴모집단은 전체 회원이 아니다: 그 달 상태이력이 있는 회원만 대상이고, 충성회원 예측은 그보다 더 좁은 부분집합이다 ⇒ 「전 회원 대비 비율」은 이 SV 로 산출할 수 없다. [원천] GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M(중단) · ML_RST_DATA_MBER_INC_12M(증액) · ML_RST_DATA_LOYAL_MBER(충성) → SERVING.ML_MEMBER_RISK_V. 상태·결제수단 라벨=SILVER.CRM_CODE(MM010·PM040).'
  )
  DIMENSIONS (
    mr.STDR_MT AS mr.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '모델 실행월')
      COMMENT = '모델 실행 기준월(YYYYMM 문자열). 🔴이 값이 여러 개면 서로 다른 실행 결과이므로 합산하지 않는다 — 반드시 하나를 고르거나 기준월별로 나눠 답한다. 🔴 **실제값을 여기에 열거하지 않는다** — 모델을 다시 돌릴 때마다 늘어나므로 열거하면 즉시 낡는다. 최신 기준월은 조회해서 확인한다.',
    mr.MBER_NO AS mr.MBER_NO
      WITH SYNONYMS ('회원번호', '회원')
      COMMENT = '회원번호. 회원수는 이 축의 중복제거로 센다.',
    mr.MBER_STAT_CD AS mr.MBER_STAT_CD
      WITH SYNONYMS ('회원상태코드')
      COMMENT = 'degen: 회원상태 원본 코드(MM010). 라벨은 MBER_STAT_NAME. 실제값 11종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''. 🔴 ''12''(후원중단)은 예측 대상에서 제외돼 이 SV 에 없다.',
    mr.MBER_STAT_NAME AS mr.MBER_STAT_NAME
      WITH SYNONYMS ('회원상태', '상태')
      COMMENT = '회원상태 라벨(MM010). 실제값 11종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''. 🔴🔴 **''후원중단''은 이 SV 에 없다** — 예측 대상이 이미 중단한 회원을 제외하기 때문이다(원천이 상태코드 12 를 배제한다) ⇒ 「후원중단 회원의 중단 예측」은 산출 불가이며, 그 값으로 필터하면 0행이 나온다. 🔴이 상태는 기준월 말 상태이며 중복 단일화의 기준축이기도 하다.',
    mr.SETLE_CD AS mr.SETLE_CD
      WITH SYNONYMS ('결제수단코드', '수납코드')
      COMMENT = 'degen: 결제수단 원본 코드. 실제값 6종: ''1''·''2''·''4''·''5''·''8''·''12''. 🔴코드값으로 의미를 추정해 답하지 말 것(코드가 단일 숫자여서 다른 코드그룹과 우연 일치한다) — 라벨은 SETLE_NAME 을 쓴다.',
    mr.SETLE_NAME AS mr.SETLE_NAME
      WITH SYNONYMS ('결제수단', '납입방식')
      COMMENT = '결제수단 라벨(PM040 · 프로젝트 정본 매핑 재사용). 실제값 6종: ''자동이체''·''신용카드''·''회비통장''·''휴대폰''·''OCR''·''네이버페이''. 🟢 이 SV 에서는 라벨 미도달이 없다.',
    mr.CPR_DIV_CD AS mr.CPR_DIV_CD
      WITH SYNONYMS ('법인구분코드')
      COMMENT = 'degen: 법인구분 원본 코드. 실제값 2종: ''I''·''S''. 라벨 미배선(코드그룹 미특정) ⇒ 의미를 추정해 답하지 말 것.',
    mr.CHURN_CLASS AS mr.CHURN_CLASS
      WITH SYNONYMS ('중단 예측 판정', '중단 클래스')
      COMMENT = '중단 예측의 모델 기본 판정. 실제값 2종: ''0''(유지 예측)·''1''(중단 예측). 🔴모델 기본 임계(0.5)의 판정이며 **업무 위험 판정선은 미확정**이다 ⇒ 「위험 회원」이라 단정하지 말고 「모델이 중단으로 분류한 회원」으로 답한다.',
    mr.INC_CLASS AS mr.INC_CLASS
      WITH SYNONYMS ('증액 예측 판정', '증액 클래스')
      COMMENT = '증액 가능성 예측의 모델 기본 판정. 실제값 2종: ''0''(비증액)·''1''(증액 예측). 임계값 주의사항은 CHURN_CLASS 와 동일.',
    mr.LOYAL_CLASS AS mr.LOYAL_CLASS
      WITH SYNONYMS ('충성회원 예측 판정')
      COMMENT = '충성회원 가능성 예측의 모델 기본 판정. 실제값 2종: ''0''(비충성)·''1''(충성 예측). 🔴이 예측은 모집단이 더 좁다(원천이 가입기간 구간으로 한정) ⇒ NULL 은 「비충성」이 아니라 「예측 대상 아님」이다.',
    mr.HAS_CHURN_PRED AS mr.HAS_CHURN_PRED
      WITH SYNONYMS ('중단 예측 보유')
      COMMENT = 'TRUE=이 회원에 중단 예측이 있다. 분모를 밝힐 때 쓴다.',
    mr.HAS_INC_PRED AS mr.HAS_INC_PRED
      WITH SYNONYMS ('증액 예측 보유')
      COMMENT = 'TRUE=이 회원에 증액 예측이 있다.',
    mr.HAS_LOYAL_PRED AS mr.HAS_LOYAL_PRED
      WITH SYNONYMS ('충성 예측 보유')
      COMMENT = 'TRUE=이 회원이 충성회원 예측 대상이다. 🔴충성 관련 비율의 분모는 전체 회원이 아니라 이 축이 TRUE 인 회원이다.',
    mr.PREDICTION_HAS_ERROR AS mr.PREDICTION_HAS_ERROR
      WITH SYNONYMS ('예측 오류 여부')
      COMMENT = 'TRUE=모델 산출 로그에 오류가 기록됐다. 품질 점검용.',
    mr.MONTHS_SINCE_JOIN AS mr.MONTHS_SINCE_JOIN
      WITH SYNONYMS ('가입경과월', '가입기간')
      COMMENT = '가입 후 경과 개월(모델 입력 피처).',
    mr.ACTIVE_SPNSR_CNT AS mr.ACTIVE_SPNSR_CNT
      WITH SYNONYMS ('활동 후원건수')
      COMMENT = '기준월 활동 후원건수(모델 입력 피처).'
  )
  METRICS (
    mr.PREDICTED_MEMBERS AS COUNT(DISTINCT mr.MBER_NO)
      WITH SYNONYMS ('예측 대상 회원수', '회원수')
      COMMENT = '예측 대상 회원수(중복제거). 🔴전체 회원수가 아니다 — 이 SV 의 모집단이다. 비율을 낼 때 분모로 쓰고 그 사실을 답변에 밝힌다.',
    mr.MODEL_CHURN_MEMBERS AS COUNT(DISTINCT CASE WHEN mr.CHURN_CLASS = '1' THEN mr.MBER_NO END)
      WITH SYNONYMS ('모델 중단분류 회원수', '중단 예측 회원수')
      COMMENT = '모델이 중단으로 분류한 회원수(중복제거). 🔴모델 기본 임계 판정이며 업무 위험 회원수가 아니다.',
    mr.MODEL_INC_MEMBERS AS COUNT(DISTINCT CASE WHEN mr.INC_CLASS = '1' THEN mr.MBER_NO END)
      WITH SYNONYMS ('모델 증액분류 회원수', '증액 예측 회원수')
      COMMENT = '모델이 증액 가능으로 분류한 회원수(중복제거).',
    mr.MODEL_LOYAL_MEMBERS AS COUNT(DISTINCT CASE WHEN mr.LOYAL_CLASS = '1' THEN mr.MBER_NO END)
      WITH SYNONYMS ('모델 충성분류 회원수', '충성회원 예측수')
      COMMENT = '모델이 충성회원으로 분류한 회원수(중복제거). 분모는 PREDICTED_LOYAL_MEMBERS 다.',
    mr.PREDICTED_LOYAL_MEMBERS AS COUNT(DISTINCT CASE WHEN mr.HAS_LOYAL_PRED THEN mr.MBER_NO END)
      WITH SYNONYMS ('충성 예측 대상 회원수')
      COMMENT = '충성회원 예측 대상 회원수(중복제거). 충성 관련 비율의 정본 분모다.',
    mr.AVG_CHURN_PROB AS AVG(mr.CHURN_PROB)
      WITH SYNONYMS ('평균 중단확률', '중단확률')
      COMMENT = '중단 예측확률 평균(0~1). 🔴확률은 합산하지 않는다 — 평균만 의미가 있다.',
    mr.AVG_INC_PROB AS AVG(mr.INC_PROB)
      WITH SYNONYMS ('평균 증액확률', '증액확률')
      COMMENT = '증액 가능성 확률 평균(0~1). 합산 금지.',
    mr.AVG_LOYAL_PROB AS AVG(mr.LOYAL_PROB)
      WITH SYNONYMS ('평균 충성확률', '충성확률')
      COMMENT = '충성회원 가능성 확률 평균(0~1). 합산 금지. 분모는 충성 예측 대상 회원이다.',
    mr.MAX_CHURN_PROB AS MAX(mr.CHURN_PROB)
      WITH SYNONYMS ('최대 중단확률')
      COMMENT = '중단확률 최대값. 상위 위험군을 찾을 때 정렬 기준으로 쓴다.',
    mr.TOTAL_INPUT_SPNSR_AMT AS SUM(mr.TOTAL_SPNSR_AMT)
      WITH SYNONYMS ('후원금액 합계')
      COMMENT = '기준월 후원금액 합계(원). 🔴모델 입력 피처의 합이며 회계 실적이 아니다 — 실적은 회비·월실적 SV 소관이다. ⚠️metric 이름을 base 컬럼명과 다르게 둔 것은 metric 중첩 회피 때문이다(O74 실측).'
  )
  COMMENT = 'ML 회원단위 예측 SV(중단·증액·충성). base=SERVING.ML_MEMBER_RISK_V. 🔴🔴 이 SV 의 모든 값은 **머신러닝 예측치이며 실적이 아니다** — 실적 SV(SV_MEMBER_MONTHLY·SV_MEMBER_FEE·SV_MEMBER_EVENT)의 measure 와 같은 표에 합산하지 않는다. 🔴 머신러닝은 **테스트 단계**이며 모델·피처·테이블 구조가 교체될 수 있다 ⇒ 값의 안정성을 보장하지 않는다. 🔴 **중단 예측의 예측 지평은 발행하지 않는다** — 원천의 테이블명은 12개월을 뜻하는데 산출물 설명·프로시저명·학습 라벨·학습 컷오프는 모두 6개월이어서 부정합이 있고, 어느 쪽이 맞는지 원천 담당자 확인 전이다 ⇒ 「향후 N개월」이라고 답하지 말고 「예측 지평은 원천 확인 중」이라고 밝힌다. 🔴 원천이 회원당 여러 행을 담고 있어(한 달에 상태 spell 다중) 월말 상태 기준으로 단일화했다 — 원천 교정 시 확률·건수가 변한다. 🔴 모집단이 전체 회원이 아니다(그 달 상태이력 보유 회원만) ⇒ 「전 회원 대비 비율」 산출 불가. 활성: 예측 대상 회원수·모델 분류 회원수·확률 평균/최대 · 상태·결제수단·판정 축. 비활성: 업무 위험 임계값(미확정) · 회원 인적속성 축(이 SV 에 미배선).'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **예측과 실적을 한 표에 합산하지 않는다.** 이 SV 는 예측 전용이다. 실적 수치가 함께 필요하면 표를 분리하고 각 표가 예측인지 실적인지 명시한다. (2) 🔴 **기준월(STDR_MT)을 여러 개 합산하지 않는다** — 서로 다른 모델 실행 결과이며 같은 회원이 여러 기준월에 등장한다. 기준월 지정이 없으면 데이터에 존재하는 최신 기준월(MAX(STDR_MT)) 하나로 한정하고 그 기준월을 답변에 밝힌다. (3) 🔴 **회원수는 반드시 중복제거로 센다** — PREDICTED_MEMBERS·MODEL_*_MEMBERS 를 쓰고 COUNT(*) 를 만들지 않는다. (4) 🔴 **「위험 회원」이라 단정하지 않는다** — 업무 위험 판정선이 미확정이므로 모델 분류 결과는 「모델이 중단으로 분류한 회원」으로 표현하고, 확률 기준을 사용자가 지정하면 그 기준을 답변에 명시한다. (5) 🔴 **예측 지평(몇 개월)을 숫자로 답하지 않는다** — 원천 부정합이 미해소이므로 「예측 지평은 원천 확인 중」이라고 밝힌다. 증액·충성 예측에도 같은 원칙으로 기간을 임의로 붙이지 않는다. (6) 🔴 **비율의 분모를 밝힌다** — 이 SV 의 모집단은 전체 회원이 아니라 그 달 상태이력이 있는 회원이고, 충성 예측은 더 좁은 부분집합이다. 충성 비율의 분모는 PREDICTED_LOYAL_MEMBERS 다. 「전 회원의 몇 %」 형태의 질문에는 산출 불가를 밝히고 이 SV 의 모집단 기준으로 답한다. (7) **확률은 평균·최대만 쓴다** — SUM 하지 않는다. (8) **NULL 판정은 「아니다」가 아니라 「예측 대상 아님」이다** — 특히 충성 예측의 NULL 을 비충성으로 세지 않는다. (9) **답변에 항상 예측치임과 테스트 단계임을 한 문장으로 밝힌다.** (10) 적용 조건(기준월·그룹 모두 미지정 시): 최신 기준월로 한정하고 상태(MBER_STAT_NAME)별 회원수와 평균 중단확률을 함께 반환한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_RISK TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_RISK TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_RISK TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   [2] SV_ML_SPONSOR_RISK — 후원건단위 이탈 예측
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_SPONSOR_RISK
  TABLES (
    sr AS GN_DW.SERVING.ML_SPONSOR_RISK_V
      PRIMARY KEY (STDR_MT, MBER_NO, SPNSR_BSNS_ID, SPNSR_BSNS_NO)
      WITH SYNONYMS ('후원건 이탈 예측', '캠페인별 이탈 예측', '후원 이탈')
      COMMENT = '후원건단위 이탈 예측. grain=기준월×회원×후원사업ID×후원사업번호(실측 유일). 🔴예측치이며 실적이 아니다. 🔴회원 grain 이 아니다 — 한 회원이 여러 후원건을 가지므로 회원수는 반드시 중복제거로 센다. [원천] GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M → SERVING.ML_SPONSOR_RISK_V. 후원사업·캠페인 라벨=SILVER.CRM_SPONSORSHIP·CRM_CAMPAIGN.'
  )
  DIMENSIONS (
    sr.STDR_MT AS sr.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월')
      COMMENT = '모델 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    sr.MBER_NO AS sr.MBER_NO
      WITH SYNONYMS ('회원번호', '회원')
      COMMENT = '회원번호. 🔴한 회원이 여러 행에 등장한다.',
    sr.SPNSR_BSNS_ID AS sr.SPNSR_BSNS_ID
      WITH SYNONYMS ('후원사업ID')
      COMMENT = 'degen: 후원사업 ID. 라벨은 SPNSR_BSNS_NAME. 🔴 실제값은 열거하지 않는다 — 후원사업 마스터가 늘어나면 낡기 때문이다. 값 목록은 조회해서 확인한다.',
    sr.SPNSR_BSNS_NAME AS sr.SPNSR_BSNS_NAME
      WITH SYNONYMS ('후원사업', '후원사업명', '사업')
      COMMENT = '후원사업명.',
    sr.SPNSR_BSNS_NO AS sr.SPNSR_BSNS_NO
      WITH SYNONYMS ('후원번호', '후원사업번호')
      COMMENT = 'degen: 후원건 식별번호. grain 구성 축이다.',
    sr.CMPGN_CD AS sr.CMPGN_CD
      WITH SYNONYMS ('캠페인코드')
      COMMENT = 'degen: 캠페인 코드. 라벨은 CMPGN_NAME.',
    sr.CMPGN_NAME AS sr.CMPGN_NAME
      WITH SYNONYMS ('캠페인', '캠페인명')
      COMMENT = '캠페인명.',
    sr.UPPER_CMPGN_CD AS sr.UPPER_CMPGN_CD
      WITH SYNONYMS ('상위캠페인', '채널')
      COMMENT = '상위캠페인 코드(채널). 캠페인 마스터에서 가져온 값이다.',
    sr.CMPGN_CTGR_NAME AS sr.CMPGN_CTGR_NAME
      WITH SYNONYMS ('캠페인카테고리', '캠페인 구분')
      COMMENT = '캠페인 카테고리명. ⚠️일부 카테고리는 원천에 이름이 없어 NULL 이다 — 이름을 추정해 채우지 않는다.',
    sr.SETLE_CD AS sr.SETLE_CD
      WITH SYNONYMS ('결제수단코드')
      COMMENT = 'degen: 결제수단 원본 코드. 실제값 7종: ''1''·''2''·''4''·''5''·''8''·''12''·''UNKNOWN''. 🔴 ''UNKNOWN''은 코드 도메인에 없는 값이며 **원천 프로시저가 NULL 을 문자열로 채운 것**이다 — ''(미매핑)''과 다르고 결제수단의 한 종류도 아니다. 코드로 의미를 추정하지 말 것.',
    sr.CHURN_CLASS AS sr.CHURN_CLASS
      WITH SYNONYMS ('이탈 예측 판정')
      COMMENT = '모델 기본 판정. 실제값 2종: ''0''(유지)·''1''(이탈 예측). 🔴업무 위험 판정선은 미확정이다.',
    sr.PREDICTION_HAS_ERROR AS sr.PREDICTION_HAS_ERROR
      WITH SYNONYMS ('예측 오류 여부')
      COMMENT = 'TRUE=모델 산출 로그에 오류가 기록됐다.',
    sr.TENURE_MONTHS AS sr.TENURE_MONTHS
      WITH SYNONYMS ('후원 유지개월')
      COMMENT = '해당 후원건의 유지 개월(모델 입력 피처).'
  )
  METRICS (
    sr.PREDICTED_SPONSORSHIPS AS COUNT(*)
      WITH SYNONYMS ('예측 대상 후원건수', '후원건수')
      COMMENT = '예측 대상 후원건수. grain 이 후원건이므로 행수가 곧 건수다.',
    sr.PREDICTED_MEMBERS AS COUNT(DISTINCT sr.MBER_NO)
      WITH SYNONYMS ('예측 대상 회원수', '회원수')
      COMMENT = '예측 대상 회원수(중복제거). 🔴후원건수와 다르다 — 「명」을 물으면 이 지표를 쓴다.',
    sr.MODEL_CHURN_SPONSORSHIPS AS COUNT_IF(sr.CHURN_CLASS = '1')
      WITH SYNONYMS ('모델 이탈분류 후원건수')
      COMMENT = '모델이 이탈로 분류한 후원건수. 업무 위험 건수가 아니다.',
    sr.MODEL_CHURN_MEMBERS AS COUNT(DISTINCT CASE WHEN sr.CHURN_CLASS = '1' THEN sr.MBER_NO END)
      WITH SYNONYMS ('모델 이탈분류 회원수')
      COMMENT = '이탈로 분류된 후원건을 가진 회원수(중복제거).',
    sr.AVG_CHURN_PROB AS AVG(sr.CHURN_PROB)
      WITH SYNONYMS ('평균 이탈확률', '이탈확률')
      COMMENT = '이탈 예측확률 평균(0~1). 합산 금지. 🔴후원건 가중 평균이며 회원 가중이 아니다.',
    sr.MAX_CHURN_PROB AS MAX(sr.CHURN_PROB)
      WITH SYNONYMS ('최대 이탈확률')
      COMMENT = '이탈확률 최대값. 상위 위험 후원건 정렬에 쓴다.',
    sr.AT_RISK_AMT AS SUM(CASE WHEN sr.CHURN_CLASS = '1' THEN sr.STDR_MT_SPNSR_AMT END)
      WITH SYNONYMS ('이탈분류 후원금액')
      COMMENT = '모델이 이탈로 분류한 후원건의 기준월 후원금액 합계(원). 🔴「잃게 될 금액」이 아니다 — 예측 분류된 건의 현재 금액 합이며 이탈이 실제로 발생한다는 뜻이 아니다.',
    sr.TOTAL_SPNSR_AMT AS SUM(sr.STDR_MT_SPNSR_AMT)
      WITH SYNONYMS ('후원금액 합계')
      COMMENT = '기준월 후원금액 합계(원). 모델 입력 피처의 합이며 회계 실적이 아니다.'
  )
  COMMENT = 'ML 후원건단위 이탈 예측 SV. base=SERVING.ML_SPONSOR_RISK_V. 🔴🔴 예측치이며 실적이 아니다 — 실적 SV 와 합산 금지. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴 **grain 이 후원건이다** — 회원 단위 질문에는 반드시 중복제거 회원수를 쓴다. 회원단위 예측(SV_ML_MEMBER_RISK)과 이 SV 를 조인해 한 표로 만들지 않는다(회원당 후원건 다건이라 회원 지표가 과대계상된다). 🔴 예측 지평은 발행하지 않는다(원천 기간 표기 확인 전). ⚠️ 회원 마스터에 없는 회원이 극소수 있어 그 행의 회원 라벨은 NULL 이다. 활성: 후원건수·회원수·모델 분류 건수/회원수·확률 평균/최대·이탈분류 금액 · 후원사업·캠페인·상위캠페인·카테고리·결제수단 축. 비활성: 업무 위험 임계값(미확정) · 부서 축(원천에 부재).'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **예측과 실적을 합산하지 않는다.** (2) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (3) 🔴🔴 **「명」과 「건」을 구분한다** — grain 이 후원건이므로 회원수는 PREDICTED_MEMBERS·MODEL_CHURN_MEMBERS(중복제거)를 쓰고, 건수는 PREDICTED_SPONSORSHIPS·MODEL_CHURN_SPONSORSHIPS 를 쓴다. 회원수를 COUNT(*) 로 세면 과대다. (4) 🔴 **SV_ML_MEMBER_RISK 와 한 쿼리로 조인하지 않는다** — grain 이 달라 팬아웃이 난다. 둘 다 필요하면 표를 분리하고 각 표의 grain 을 명시한다. (5) 🔴 **「위험」·「이탈할 것이다」로 단정하지 않는다** — 업무 임계값 미확정이므로 「모델이 이탈로 분류」로 표현한다. (6) 🔴 **AT_RISK_AMT 를 「손실 예상액」이라 부르지 않는다** — 이탈 분류된 건의 현재 후원금액 합일 뿐이다. (7) 🔴 **예측 지평을 숫자로 답하지 않는다**(원천 확인 중). (8) **확률은 평균·최대만 쓴다.** 평균은 후원건 가중임을 밝힌다. (9) **답변에 예측치임과 테스트 단계임을 밝힌다.** (10) 적용 조건(기준월·그룹 미지정 시): 최신 기준월로 한정하고 상위캠페인(채널)별 후원건수·모델 이탈분류 건수·평균 이탈확률을 반환한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_SPONSOR_RISK TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_SPONSOR_RISK TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_SPONSOR_RISK TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   [3] SV_ML_DVLP_FORECAST — 개발금액 예측 5종 (단위: 만원)
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST
  TABLES (
    df AS GN_DW.SERVING.ML_DVLP_FORECAST_V
      PRIMARY KEY (STDR_MT, SERIES_TYPE, SERIES_CD, TS)
      WITH SYNONYMS ('개발 예측', '개발금액 예측', '개발액 예측', '연도말 개발 예측')
      COMMENT = '개발금액 예측 5종 통합(전사·부서·후원사업·신규기존·캠페인). grain=기준월×계열유형×계열×예측월. 🔴단위=만원. 🔴예측치이며 실적이 아니다. 🔴계열유형 간 합산은 중복계상이며, 유형별 합계는 서로 일치하지도 않는다(계열별 독립 예측). [원천] GN_DW.ML.ML_RST_DATA_MONTHLY_DVLP_AMT·_MONTHLY_DEPT_DVLP_AMT·_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT·_MONTHLY_NEW_OLD_DVLP_AMT·_MONTHLY_CMPGN_DVLP_AMT → SERVING.ML_DVLP_FORECAST_V. 라벨=SILVER.CRM_ORG·CRM_SPONSORSHIP·CRM_CAMPAIGN.'
  )
  DIMENSIONS (
    df.STDR_MT AS df.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '모델 실행월')
      COMMENT = '모델 실행 기준월(YYYYMM). 🔴여러 기준월을 합산하면 같은 예측월이 중복계상된다. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    df.SERIES_TYPE AS df.SERIES_TYPE
      WITH SYNONYMS ('계열유형', '집계 단위', '분해축')
      COMMENT = '예측 계열의 유형. 실제값: ''TOTAL''(전사)·''DEPT''(부서)·''SPNSR_BSNS''(후원사업)·''NEW_OLD''(신규/기존)·''CAMPAIGN''(캠페인). 🔴🔴 **항상 이 축을 지정하거나 그룹에 넣는다** — 유형을 섞어 합하면 같은 개발 활동을 여러 축으로 겹쳐 세어 과대가 된다. 🔴 **유형별 합계는 서로 일치하지 않는다** — 각 계열을 독립적으로 예측한 결과이므로 부서 합·신규기존 합·후원사업 합이 전사 예측과 다르다 ⇒ 한 유형으로 다른 유형을 검산하지 말 것.',
    df.SERIES_CD AS df.SERIES_CD
      WITH SYNONYMS ('계열코드')
      COMMENT = 'degen: 계열 코드. 🔴계열유형에 따라 의미가 다르다(부서코드·후원사업ID·캠페인코드·NEW/OLD) ⇒ SERIES_TYPE 없이 해석하지 말 것.',
    df.SERIES_NAME AS df.SERIES_NAME
      WITH SYNONYMS ('계열명', '부서명', '후원사업명', '캠페인명')
      COMMENT = '계열 라벨(계열유형별로 부서명·후원사업명·캠페인명·신규/기존).',
    df.TS AS df.TS
      WITH SYNONYMS ('예측월', '예측 시점', '전망월')
      COMMENT = '예측 대상 월(월 시작일 타임스탬프). 🔴기준월(STDR_MT)과 다르다 — 기준월은 모델을 돌린 달이고 이것은 예측하는 달이다.'
  )
  METRICS (
    df.FORECAST_AMT AS SUM(df.FORECAST)
      WITH SYNONYMS ('예측 개발액', '개발금액 예측치', '예측액')
      COMMENT = '개발금액 예측 합계(**만원**). 🔴원 단위가 아니다 — 원으로 답할 때는 만 배 해서 원으로 바꾸고 단위를 밝힌다. 🔴같은 계열유형 안에서만 합산한다.',
    df.FORECAST_LOWER AS SUM(df.LOWER_BOUND)
      WITH SYNONYMS ('예측 하한', '신뢰구간 하한')
      COMMENT = '95% 신뢰구간 하한 합계(만원). 별개 실적이 아니다.',
    df.FORECAST_UPPER AS SUM(df.UPPER_BOUND)
      WITH SYNONYMS ('예측 상한', '신뢰구간 상한')
      COMMENT = '95% 신뢰구간 상한 합계(만원). 별개 실적이 아니다.',
    df.AVG_MONTHLY_FORECAST AS AVG(df.FORECAST)
      WITH SYNONYMS ('월평균 예측액')
      COMMENT = '예측월당 평균 개발금액(만원).',
    df.FORECAST_MONTHS AS COUNT(DISTINCT df.TS)
      WITH SYNONYMS ('예측 개월수')
      COMMENT = '예측 대상 개월 수. 예측 기간을 밝힐 때 쓴다.',
    df.SERIES_COUNT AS COUNT(DISTINCT df.SERIES_CD)
      WITH SYNONYMS ('계열 수')
      COMMENT = '계열 수. 🔴전 계열이 예측 대상은 아니다 — 원천이 일부 계열만 담을 수 있으므로 「전체」로 단정하지 않는다.'
  )
  COMMENT = 'ML 개발금액 예측 SV(5종 통합). base=SERVING.ML_DVLP_FORECAST_V. 🔴🔴 **단위는 만원이다** — 원 단위 실적(예산·회비 SV)과 같은 표에 넣으면 만 배 오차가 난다. 🔴🔴 예측치이며 실적이 아니다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴🔴 **계열유형(SERIES_TYPE)을 반드시 고정하거나 그룹에 넣는다** — 유형을 섞어 합하면 같은 개발 활동을 여러 축으로 겹쳐 세어 과대가 된다. 🔴🔴 **유형별 합계는 서로 일치하지 않는다** — 계열마다 독립적으로 예측했기 때문에 부서 합·신규기존 합·후원사업 합이 전사 예측과 다르다(후원사업 합이 전사보다 크게 나오는 구간도 있다) ⇒ 한 유형으로 다른 유형을 검산하지 말고, 「부서별 합이 전사와 다르다」는 지적에는 이 구조를 설명한다. 🔴 기준월(모델 실행월)과 예측월(TS)은 다른 축이다. ⚠️ 예측치에 음수가 존재한다(감액·해지 반영) — 음수를 오류로 보지 않는다. ⚠️ 캠페인 계열은 원천이 일부 캠페인만 담고 있다. 활성: 예측액·신뢰구간·월평균·예측개월수·계열수 · 계열유형/계열/예측월 축. 비활성: 본부·지부 분해(조직 계층 산출규칙 미확정) · 실적 대비 정확도(실적 조인 미배선) · 유형 간 정합 검산(원천이 보장하지 않는다).'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **SERIES_TYPE 을 반드시 WHERE 로 고정하거나 GROUP BY 에 넣는다.** 넣지 않으면 전사와 그 분해(부서·신규기존)를 겹쳐 세어 합계가 여러 배 과대가 된다. 질문이 「전사/전체 개발 예측」이면 SERIES_TYPE=''TOTAL'' 로 고정한다. 「부서별」이면 ''DEPT'', 「후원사업별」이면 ''SPNSR_BSNS'', 「신규/기존별」이면 ''NEW_OLD'', 「캠페인별」이면 ''CAMPAIGN'' 이다. (2) 🔴🔴 **단위는 만원이다.** 답변에 항상 단위를 밝히고, 원으로 환산하면 환산했다고 명시한다. 예산·회비 등 원 단위 지표와 같은 표에 합산하지 않는다. (3) 🔴 **기준월(STDR_MT)을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 그 기준월을 밝힌다. (4) 🔴 **기준월과 예측월(TS)을 혼동하지 않는다** — 「향후 12개월 예측」은 하나의 기준월에 속한 TS 12개다. 연도말 전망을 물으면 해당 연도에 속한 TS 만 합산하고 기준월을 밝힌다. (5) 🔴 **예측치임을 답변에 밝힌다** — 실적으로 읽히는 표현(「개발액은 …이다」)을 쓰지 않고 「예측치는 …」으로 쓴다. 테스트 단계임도 함께 밝힌다. (6) **음수 예측치를 오류로 처리하거나 0 으로 바꾸지 않는다** — 감액·해지가 반영된 값이다. (7) **신뢰구간을 별개 수치로 나열하지 않는다** — 예측치와 함께 구간으로 제시한다. (8) 🔴 **유형 간 검산을 시도하지 않는다** — 부서 합·후원사업 합·신규기존 합은 전사 예측과 일치하지 않는다(계열별 독립 예측). 사용자가 불일치를 지적하면 원천이 정합을 보장하지 않는 구조라고 설명하고, 임의로 비례배분해 맞추지 않는다. 캠페인 계열은 일부 캠페인만 예측 대상임도 밝힌다. (9) 적용 조건(기준월·계열유형 모두 미지정 시): 최신 기준월 + SERIES_TYPE=''TOTAL'' 로 한정해 예측월별 예측액과 신뢰구간을 반환하고, 다른 분해축이 있음을 안내한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   [4] SV_ML_FEE_FORECAST — 캠페인카테고리별 회비 예측 (단위: 원)
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST
  TABLES (
    ff AS GN_DW.SERVING.ML_FEE_FORECAST_V
      PRIMARY KEY (STDR_MT, CMPGN_CTGR_CD, FORECAST_TS)
      WITH SYNONYMS ('회비 예측', '카테고리별 회비 예측', '후원금액 예측')
      COMMENT = '캠페인카테고리별 회비(후원금액) 예측. grain=기준월×캠페인카테고리×예측월. 🔴단위=원. 🔴예측치이며 실적이 아니다. 개발금액 예측(만원)과 단위가 달라 합산할 수 없다. [원천] GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT → SERVING.ML_FEE_FORECAST_V. 라벨=SILVER.CRM_CAMPAIGN(CMPGN_CTGR_CD·CMPGN_CTGR_NM).'
  )
  DIMENSIONS (
    ff.STDR_MT AS ff.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월')
      COMMENT = '모델 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    ff.CMPGN_CTGR_CD AS ff.CMPGN_CTGR_CD
      WITH SYNONYMS ('캠페인카테고리코드')
      COMMENT = 'degen: 캠페인 카테고리 코드. 라벨은 CMPGN_CTGR_NAME.',
    ff.CMPGN_CTGR_NAME AS ff.CMPGN_CTGR_NAME
      WITH SYNONYMS ('캠페인카테고리', '캠페인 구분', '카테고리')
      COMMENT = '캠페인 카테고리명. ⚠️일부 카테고리는 원천 마스터에 이름이 없어 NULL 이다 — 이름을 추정해 채우지 않고 코드로 답한다.',
    ff.FORECAST_TS AS ff.FORECAST_TS
      WITH SYNONYMS ('예측월', '예측 시점')
      COMMENT = '예측 대상 월(월 시작일). 기준월과 다르다.',
    ff.FORECAST_MONTH_KEY AS ff.FORECAST_MONTH_KEY
      WITH SYNONYMS ('예측연월', '예측 YYYYMM')
      COMMENT = '예측 대상 연월(YYYYMM 정수). 연·월 필터에 쓴다.'
  )
  METRICS (
    -- 🔴 metric 이름을 base 컬럼명과 다르게 둔다 — 같게 두면 뒤의 metric 이 컬럼 대신
    --    앞의 metric 을 참조해 「metric 중첩」으로 컴파일이 거부된다(O74 실측).
    ff.TOTAL_FORECAST_FEE AS SUM(ff.FORECAST_AMT)
      WITH SYNONYMS ('예측 회비', '회비 예측치', '예측 후원금액')
      COMMENT = '회비(후원금액) 예측 합계(**원**). 🔴개발금액 예측(만원)과 합산하지 않는다.',
    ff.TOTAL_FORECAST_FEE_LOWER AS SUM(ff.FORECAST_LOWER)
      WITH SYNONYMS ('예측 하한')
      COMMENT = '95% 신뢰구간 하한 합계(원).',
    ff.TOTAL_FORECAST_FEE_UPPER AS SUM(ff.FORECAST_UPPER)
      WITH SYNONYMS ('예측 상한')
      COMMENT = '95% 신뢰구간 상한 합계(원).',
    ff.AVG_MONTHLY_FORECAST_FEE AS AVG(ff.FORECAST_AMT)
      WITH SYNONYMS ('월평균 예측 회비')
      COMMENT = '예측월당 평균 회비 예측(원).',
    ff.FORECAST_MONTHS AS COUNT(DISTINCT ff.FORECAST_TS)
      WITH SYNONYMS ('예측 개월수')
      COMMENT = '예측 대상 개월 수.',
    ff.CATEGORY_COUNT AS COUNT(DISTINCT ff.CMPGN_CTGR_CD)
      WITH SYNONYMS ('카테고리 수')
      COMMENT = '예측 대상 캠페인카테고리 수.'
  )
  COMMENT = 'ML 캠페인카테고리별 회비 예측 SV. base=SERVING.ML_FEE_FORECAST_V. 🔴🔴 예측치이며 실적이 아니다 — 회비 실적은 SV_MEMBER_FEE 소관이고 이 SV 와 같은 표에 합산하지 않는다. 🔴🔴 **단위는 원이다** — 개발금액 예측 SV(만원)와 단위가 다르다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴 기준월(모델 실행월)과 예측월은 다른 축이며 여러 기준월 합산은 중복계상이다. ⚠️ 캠페인카테고리 일부는 원천 마스터에 이름이 없어 라벨이 NULL 이다. ⚠️ 예측 대상 카테고리가 전체 카테고리와 같다고 단정하지 않는다. 활성: 예측 회비·신뢰구간·월평균·예측개월수·카테고리수 · 카테고리/예측월 축. 비활성: 캠페인 단위 분해(원천 grain 이 카테고리) · 실적 대비 정확도.'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **단위는 원이다.** 개발금액 예측(SV_ML_DVLP_FORECAST · 만원)과 같은 표에 합산하지 않는다. 두 예측을 함께 물으면 표를 나누고 각 단위를 밝힌다. (2) 🔴🔴 **예측과 실적을 합산하지 않는다** — 회비 실적은 SV_MEMBER_FEE 다. 실적과 예측을 함께 보여줄 때는 표를 분리하고 각각을 명시한다. (3) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (4) 🔴 **기준월과 예측월을 혼동하지 않는다.** 연도 전망은 해당 연도의 예측월만 합산한다. (5) 🔴 **예측치임과 테스트 단계임을 밝힌다.** (6) **라벨이 NULL 인 카테고리를 숨기거나 이름을 추정하지 않는다** — 코드로 표기하고 원천에 이름이 없다고 밝힌다. (7) **신뢰구간은 예측치와 함께 구간으로 제시한다.** (8) 적용 조건(기준월·그룹 미지정 시): 최신 기준월로 한정해 예측월별 합계와 신뢰구간을 반환하고, 카테고리별 분해가 가능함을 안내한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   [5] SV_ML_LTV_FORECAST — LTV 월별 예측 2종
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_FORECAST
  TABLES (
    lf AS GN_DW.SERVING.ML_LTV_FORECAST_V
      PRIMARY KEY (STDR_MT, LTV_TYPE, SERIES_CD, TS)
      WITH SYNONYMS ('LTV 예측', '생애가치 예측', '후원 LTV 예측')
      COMMENT = 'LTV 월별 예측 2종. grain=기준월×LTV유형×계열×예측월. 🔴두 유형은 계열축과 의미가 모두 다르다 — 하나는 상위캠페인의 회원평균 LTV, 다른 하나는 캠페인의 후원총액 LTV다. 🔴예측치이며 실적이 아니다. [원천] GN_DW.ML.ML_RST_DATA_UCMPGN_LTV·ML_RST_DATA_CMPGN_LTV → SERVING.ML_LTV_FORECAST_V. 라벨=SILVER.CRM_CAMPAIGN.'
  )
  DIMENSIONS (
    lf.STDR_MT AS lf.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월')
      COMMENT = '모델 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    lf.LTV_TYPE AS lf.LTV_TYPE
      WITH SYNONYMS ('LTV 유형', 'LTV 구분')
      COMMENT = 'LTV 유형. 실제값: ''UCMPGN_AVG_MEMBER''(상위캠페인 회원평균 LTV)·''CMPGN_TOTAL''(캠페인 후원총액 LTV). 🔴🔴 **반드시 하나로 고정한다** — 하나는 1인당 평균이고 하나는 총액이라 자리수가 크게 다르고, 계열 집합도 서로 겹치지 않는다.',
    lf.LTV_TYPE_NAME AS lf.LTV_TYPE_NAME
      WITH SYNONYMS ('LTV 유형명')
      COMMENT = 'LTV 유형 라벨. 실제값 2종: ''상위캠페인 회원평균 LTV''·''캠페인 후원총액 LTV''.',
    lf.SERIES_CD AS lf.SERIES_CD
      WITH SYNONYMS ('계열코드', '캠페인코드', '채널코드')
      COMMENT = 'degen: 계열 코드. 🔴LTV유형에 따라 상위캠페인 코드 또는 일반 캠페인 코드다 — 유형 없이 해석하지 말 것.',
    lf.SERIES_NAME AS lf.SERIES_NAME
      WITH SYNONYMS ('계열명', '캠페인명', '채널명')
      COMMENT = '계열 라벨(캠페인명).',
    lf.TS AS lf.TS
      WITH SYNONYMS ('예측월', '예측 시점')
      COMMENT = '예측 대상 월(월 시작일). 기준월과 다르다.'
  )
  METRICS (
    lf.AVG_FORECAST_LTV AS AVG(lf.FORECAST)
      WITH SYNONYMS ('평균 LTV 예측', 'LTV 예측치')
      COMMENT = 'LTV 예측 평균(원). 🔴LTV유형을 고정한 상태에서만 의미가 있다. 회원평균 유형에서는 「회원 1인당 평균의 평균」이므로 회원수 가중이 아니다.',
    lf.TOTAL_FORECAST_LTV AS SUM(lf.FORECAST)
      WITH SYNONYMS ('LTV 예측 합계')
      COMMENT = 'LTV 예측 합계(원). 🔴🔴 **회원평균 LTV 유형에서는 합산하지 않는다** — 1인당 평균을 더한 값은 업무 의미가 없다. 총액 유형에서만 합산한다.',
    lf.FORECAST_LOWER AS AVG(lf.LOWER_BOUND)
      WITH SYNONYMS ('LTV 예측 하한')
      COMMENT = '95% 신뢰구간 하한 평균(원).',
    lf.FORECAST_UPPER AS AVG(lf.UPPER_BOUND)
      WITH SYNONYMS ('LTV 예측 상한')
      COMMENT = '95% 신뢰구간 상한 평균(원).',
    lf.FORECAST_MONTHS AS COUNT(DISTINCT lf.TS)
      WITH SYNONYMS ('예측 개월수')
      COMMENT = '예측 대상 개월 수.',
    lf.SERIES_COUNT AS COUNT(DISTINCT lf.SERIES_CD)
      WITH SYNONYMS ('계열 수', '채널 수')
      COMMENT = '예측 대상 계열 수.'
  )
  COMMENT = 'ML LTV 월별 예측 SV(2종). base=SERVING.ML_LTV_FORECAST_V. 🔴🔴 예측치이며 실적이 아니다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴🔴 **LTV_TYPE 을 반드시 하나로 고정한다** — ''UCMPGN_AVG_MEMBER''는 상위캠페인의 **회원 1인당 평균 LTV**이고 ''CMPGN_TOTAL''은 캠페인의 **후원 총액 LTV**다. 두 유형은 의미·자리수가 다르고 계열 집합이 서로 겹치지 않으므로 합산·순위 비교를 함께 하면 반드시 틀린다. ⚠️ **원천 요건 기술과 데이터가 다르다** — 요건은 두 예측을 모두 「채널(상위캠페인) 단위」로 적었으나, 실제로 상위캠페인인 것은 UCMPGN 쪽뿐이고 CMPGN 쪽은 일반 캠페인이다 ⇒ 「채널별 LTV」 질문은 UCMPGN 유형으로 답한다. 🔴 회원평균 유형의 LTV 를 합산하지 않는다. 활성: LTV 예측 평균/합계·신뢰구간·예측개월수·계열수 · LTV유형/계열/예측월 축. 비활성: 회원 단위 LTV(원천 grain 이 계열) · 실적 대비 정확도. 스코어 형태(계열당 단일 행)는 SV_ML_LTV_SCORE 소관이다.'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **LTV_TYPE 을 WHERE 로 하나 고정한다.** 두 유형을 한 표에 섞지 않는다 — 하나는 1인당 평균, 하나는 총액이며 계열 집합이 겹치지 않는다. 「채널별/상위캠페인별 LTV」는 ''UCMPGN_AVG_MEMBER'', 「캠페인별 총 LTV」는 ''CMPGN_TOTAL'' 이다. 어느 쪽인지 불분명하면 사용자에게 확인하거나 두 표로 나눠 각 정의를 밝힌다. (2) 🔴🔴 **회원평균 LTV 유형에서 TOTAL_FORECAST_LTV(합계)를 쓰지 않는다** — 1인당 평균을 더한 값은 의미가 없다. 그 유형에서는 AVG_FORECAST_LTV 를 쓴다. (3) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (4) 🔴 **예측치임과 테스트 단계임을 밝힌다.** (5) **단위는 원이다.** 개발금액 예측(만원)과 합산하지 않는다. (6) **월별 예측과 스코어를 한 표에 합치지 않는다** — 스코어는 SV_ML_LTV_SCORE 이고 grain 이 다르다(계열당 단일 행). (7) 적용 조건(기준월·유형 미지정 시): 최신 기준월 + LTV_TYPE=''UCMPGN_AVG_MEMBER'' 로 한정해 계열별 평균 LTV 예측 상위를 반환하고, 다른 유형이 있음을 안내한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_FORECAST TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_FORECAST TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_FORECAST TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   [6] SV_ML_LTV_SCORE — LTV 스코어 2종 (계열당 단일 행)
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_SCORE
  TABLES (
    ls AS GN_DW.SERVING.ML_LTV_SCORE_V
      PRIMARY KEY (STDR_MT, LTV_TYPE, SERIES_CD)
      WITH SYNONYMS ('LTV 스코어', 'LTV 점수', '채널 LTV')
      COMMENT = 'LTV 스코어 2종. grain=기준월×LTV유형×계열(계열당 단일 행). 🔴월별 예측(SV_ML_LTV_FORECAST)과 grain 이 달라 합산할 수 없다. 🔴예측 기반 산출이며 실적이 아니다. [원천] GN_DW.ML.ML_RST_DATA_UCMPGN_LTV_SCORE·ML_RST_DATA_CMPGN_LTV_SCORE → SERVING.ML_LTV_SCORE_V.'
  )
  DIMENSIONS (
    ls.STDR_MT AS ls.STDR_MT
      WITH SYNONYMS ('기준월', '산출 기준월')
      COMMENT = '모델 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    ls.LTV_TYPE AS ls.LTV_TYPE
      WITH SYNONYMS ('LTV 유형', 'LTV 구분')
      COMMENT = 'LTV 유형. 실제값: ''UCMPGN_AVG_MEMBER''(상위캠페인 회원평균)·''CMPGN_TOTAL''(캠페인 후원총액). 🔴반드시 하나로 고정한다 — 의미·자리수가 다르고 계열 집합이 겹치지 않는다.',
    ls.LTV_TYPE_NAME AS ls.LTV_TYPE_NAME
      WITH SYNONYMS ('LTV 유형명')
      COMMENT = 'LTV 유형 라벨. 실제값 2종: ''상위캠페인 회원평균 LTV''·''캠페인 후원총액 LTV''.',
    ls.SERIES_CD AS ls.SERIES_CD
      WITH SYNONYMS ('계열코드', '캠페인코드', '채널코드')
      COMMENT = 'degen: 계열 코드(LTV유형에 따라 상위캠페인 또는 일반 캠페인).',
    ls.SERIES_NAME AS ls.SERIES_NAME
      WITH SYNONYMS ('계열명', '캠페인명', '채널명')
      COMMENT = '계열 라벨(캠페인명).'
  )
  METRICS (
    ls.AVG_LTV AS AVG(ls.LTV)
      WITH SYNONYMS ('평균 LTV', 'LTV')
      COMMENT = 'LTV 스코어 평균(원). LTV유형 고정 상태에서만 의미가 있다.',
    ls.MAX_LTV AS MAX(ls.LTV)
      WITH SYNONYMS ('최대 LTV')
      COMMENT = 'LTV 최대값(원). 상위 계열 정렬에 쓴다.',
    ls.AVG_HIST_AMT AS AVG(ls.HIST_TOTAL_AMT)
      WITH SYNONYMS ('과거 누적금액 평균')
      COMMENT = '과거 구간 누적금액 평균(원). 🔴이 값은 과거 실적 성격이나 이 SV 의 산출 맥락 안의 값이다 — 회계 실적으로 인용하지 않는다.',
    ls.AVG_FUTURE_AMT AS AVG(ls.FUTURE_TOTAL_AMT)
      WITH SYNONYMS ('미래 예측금액 평균')
      COMMENT = '미래 구간 예측금액 평균(원). 예측치다.',
    ls.MEAN_MONTHLY_FORECAST AS AVG(ls.AVG_MONTHLY_FORECAST)
      WITH SYNONYMS ('월평균 예측금액')
      COMMENT = '월평균 예측금액(원). ⚠️metric 이름을 base 컬럼명과 다르게 둔 것은 metric 중첩 회피 때문이다.',
    ls.MEAN_MONTHLY_ACTUAL AS AVG(ls.AVG_MONTHLY_ACTUAL)
      WITH SYNONYMS ('월평균 실적금액')
      COMMENT = '월평균 과거 실적금액(원). 🔴예측과 비교할 때 둘의 성격을 밝힌다.',
    ls.AVG_ACTIVE_MONTHS AS AVG(ls.ACTIVE_MONTHS)
      WITH SYNONYMS ('평균 활동개월')
      COMMENT = '평균 활동 개월수.',
    ls.SERIES_COUNT AS COUNT(DISTINCT ls.SERIES_CD)
      WITH SYNONYMS ('계열 수', '채널 수')
      COMMENT = '스코어 산출 대상 계열 수.'
  )
  COMMENT = 'ML LTV 스코어 SV(2종). base=SERVING.ML_LTV_SCORE_V. 🔴🔴 예측 기반 산출이며 회계 실적이 아니다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴🔴 **LTV_TYPE 을 반드시 하나로 고정한다**(상위캠페인 회원평균 ↔ 캠페인 후원총액 · 계열 집합이 서로 겹치지 않는다). 🔴 **월별 예측 SV(SV_ML_LTV_FORECAST)와 한 표에 합치지 않는다** — 이 SV 는 계열당 단일 행이고 그쪽은 계열당 예측월 다수라, 섞으면 분모가 달라 조용히 틀린다. ⚠️ 과거금액·월평균 실적 컬럼이 함께 있으나 이 SV 의 산출 맥락 값이며 실적 정본이 아니다 — 실적은 회비·월실적 SV 소관이다. 활성: LTV 평균/최대·과거누적·미래예측·월평균 예측/실적·활동개월·계열수 · LTV유형/계열 축. 비활성: 월별 시계열(월별 예측 SV 소관) · 회원 단위 LTV.'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **LTV_TYPE 을 하나 고정한다.** 두 유형을 한 표에 섞거나 순위를 함께 매기지 않는다. (2) 🔴🔴 **SV_ML_LTV_FORECAST 와 한 쿼리로 합치지 않는다** — grain 이 다르다(여기는 계열당 단일 행). 월별 추이가 필요하면 그 SV 로 라우팅한다. (3) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (4) 🔴 **AVG_MONTHLY_ACTUAL 을 실적 정본으로 인용하지 않는다** — 회비·월실적 SV 가 실적 정본이다. 예측과 나란히 보여줄 때 각각의 성격을 밝힌다. (5) 🔴 **예측 기반 산출임과 테스트 단계임을 밝힌다.** (6) **단위는 원이다.** (7) 적용 조건(기준월·유형 미지정 시): 최신 기준월 + LTV_TYPE=''UCMPGN_AVG_MEMBER'' 로 한정해 계열별 LTV 상위를 반환하고 다른 유형이 있음을 안내한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_SCORE TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_SCORE TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_SCORE TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   [7] SV_ML_FEATURE_IMPORTANCE — 요인분석(피처 중요도) 2종
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEATURE_IMPORTANCE
  TABLES (
    fi AS GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V
      PRIMARY KEY (STDR_MT, ANALYSIS_TYPE, FEATURE)
      WITH SYNONYMS ('요인분석', '피처 중요도', '기여도', '결정 요인')
      COMMENT = '요인분석(피처 중요도) 2종. grain=기준월×분석유형×피처. 🔴🔴 측정 대상이 데이터가 아니라 **모델**이다 — 값은 0~1 기여도이며 금액·건수·회원수가 아니다(분석유형 내 합계=1). [원천] GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION·ML_RST_DATA_DVLP_INC_CONTRIBUTION → SERVING.ML_FEATURE_IMPORTANCE_V.'
  )
  DIMENSIONS (
    fi.STDR_MT AS fi.STDR_MT
      WITH SYNONYMS ('기준월', '분석 기준월')
      COMMENT = '분석 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    fi.ANALYSIS_TYPE AS fi.ANALYSIS_TYPE
      WITH SYNONYMS ('분석유형', '분석 구분')
      COMMENT = '분석 유형. 실제값: ''CHANNEL_NEW_SPNSR''(신규 후원 유치 요인)·''DVLP_INC''(증액 개발 요인). 🔴반드시 하나로 고정한다 — 유형 내 기여도 합계가 1 이므로 섞으면 합계가 1 을 넘는다.',
    fi.ANALYSIS_TYPE_NAME AS fi.ANALYSIS_TYPE_NAME
      WITH SYNONYMS ('분석유형명')
      COMMENT = '분석 유형 라벨. 실제값 2종: ''신규 후원 유치 요인''·''증액 개발 요인''.',
    fi.FEATURE AS fi.FEATURE
      WITH SYNONYMS ('피처', '요인', '변수')
      COMMENT = '피처(요인) 이름. 모델 입력 변수명이며 업무 용어가 아닐 수 있다. 🔴 **실제값을 여기에 열거하지 않는다** — 피처 목록은 모델이 교체되면 바뀌므로 열거하면 낡은 목록이 사실처럼 발행된다. 값은 조회해서 확인한다.',
    fi.RANK AS fi.RANK
      WITH SYNONYMS ('순위', '중요도 순위')
      COMMENT = '피처 중요도 순위(1=가장 중요). 상위 요인을 뽑을 때 쓴다.',
    fi.FEATURE_TYPE AS fi.FEATURE_TYPE
      WITH SYNONYMS ('피처 유형')
      COMMENT = '피처 유형. 실제값: ''user_provided''. 🔴🔴 이 값의 뜻은 **피처 목록을 사람이 지정했다**는 것이다 — 모델이 스스로 후보 변수를 탐색해 고른 결과가 아니므로 「데이터가 밝혀낸 요인」으로 답하지 않는다.'
  )
  METRICS (
    fi.TOTAL_SCORE AS SUM(fi.SCORE)
      WITH SYNONYMS ('기여도 합계')
      COMMENT = '기여도 합계. 🔴한 분석유형·기준월 안에서 전 피처를 더하면 1 이다 — 유형을 섞으면 1 을 넘고 의미가 사라진다.',
    fi.AVG_SCORE AS AVG(fi.SCORE)
      WITH SYNONYMS ('평균 기여도')
      COMMENT = '평균 기여도(0~1).',
    fi.MAX_SCORE AS MAX(fi.SCORE)
      WITH SYNONYMS ('최대 기여도', '최상위 요인 기여도')
      COMMENT = '최대 기여도(0~1).',
    fi.FEATURE_COUNT AS COUNT(DISTINCT fi.FEATURE)
      WITH SYNONYMS ('피처 수', '요인 수')
      COMMENT = '분석에 포함된 피처 수.'
  )
  COMMENT = 'ML 요인분석(피처 중요도) SV(2종). base=SERVING.ML_FEATURE_IMPORTANCE_V. 🔴🔴 **이 SV 는 모델을 설명하는 것이고 업무 실적을 측정하는 것이 아니다** — 값은 0~1 기여도이며 금액·건수·회원수가 아니다. 다른 SV 의 measure 와 같은 표에 넣으면 업무 수치로 오독된다. 🔴 머신러닝은 테스트 단계이며 모델·피처가 교체될 수 있다. 🔴🔴 **ANALYSIS_TYPE 을 반드시 하나로 고정한다** — 유형 내 기여도 합계가 1 이므로 섞으면 합계가 1 을 넘는다. 🔴🔴 **피처 목록은 사람이 지정한 것이다**(피처 유형이 전건 ''user_provided'') ⇒ 「데이터 분석으로 발견한 요인」이라 답하지 않고 「지정된 후보 요인 중 모델이 매긴 상대 중요도」로 답한다. 🔴 **기여도는 인과가 아니다** — 「이 요인을 늘리면 신규 후원이 늘어난다」는 결론을 내지 않는다. 활성: 기여도 합계/평균/최대·피처수 · 분석유형/피처/순위/피처유형 축. 비활성: 인과 효과 크기 · 요인별 금액 환산.'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **ANALYSIS_TYPE 을 하나 고정한다** — 유형 내 기여도 합계가 1 이므로 두 유형을 섞으면 합계가 1 을 넘고 순위도 뒤섞인다. (2) 🔴🔴 **이 값을 업무 수치로 답하지 않는다** — 금액·건수·회원수가 아니라 모델 기여도(0~1)다. 다른 SV 의 measure 와 같은 표에 넣지 않는다. (3) 🔴🔴 **인과로 답하지 않는다** — 「A 를 늘리면 신규 후원이 늘어난다」가 아니라 「모델이 A 에 가장 큰 상대 중요도를 부여했다」로 표현한다. (4) 🔴 **피처 목록이 사람이 지정한 후보라는 사실을 밝힌다**(피처 유형=user_provided) — 「데이터가 찾아낸 요인」이라 하지 않는다. 지정되지 않은 요인은 애초에 후보가 아니었으므로 「중요하지 않다」고 말할 수 없다. (5) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (6) **상위 요인은 RANK 로 정렬한다.** (7) **답변에 모델 설명이며 테스트 단계임을 밝힌다.** (8) 적용 조건(기준월·유형 미지정 시): 최신 기준월 + 사용자가 언급한 주제에 맞는 분석유형 하나로 한정해 RANK 순 상위 요인과 기여도를 반환하고, 다른 분석유형이 있음을 안내한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEATURE_IMPORTANCE TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEATURE_IMPORTANCE TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEATURE_IMPORTANCE TO ROLE GN_DW_SERVICE;
