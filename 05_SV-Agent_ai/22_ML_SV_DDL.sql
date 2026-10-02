-- ============================================================================
-- 22_ML_SV_DDL.sql — Semantic View DDL 정본: SV_ML_MEMBER_RISK · SV_ML_SPONSOR_RISK · SV_ML_DVLP_FORECAST · SV_ML_FEE_FORECAST · SV_ML_LTV_FORECAST · SV_ML_FEATURE_IMPORTANCE · SV_ML_ONCE_CONVERSION (⛔ SV_ML_LTV_SCORE 폐기)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
--   · 🆕 2026-10-02 O198 — ML 12종(50_handoff/05번) 기준 재정렬. base 뷰 = 21_ML_SERVING_뷰_DDL.sql 같은 날짜 판.
--       MEMBER_RISK  : 회원상태·결제수단·법인구분·피처 축/지표 삭제 · 원천 중복행 컬럼(CHURN_PRED_ROWS)·DUP_SOURCE_MEMBERS 추가
--       SPONSOR_RISK : 캠페인·상위캠페인·결제수단·유지개월 축, AT_RISK_AMT·TOTAL_SPNSR_AMT 삭제 · 캠페인카테고리 코드 축 추가
--       LTV_FORECAST : 유형 UCMPGN_AVG_MEMBER → MKTG_CHANNEL_AVG_MEMBER · CMPGN_TOTAL 의미 = 캠페인 월간 후원금액 · VQR 추가
--       LTV_SCORE    : ⛔ 폐기(원천 이관 제외) · 구 정의 = _archive/22_ML_SV_DDL_pre_O198.sql
--       FEATURE_IMPORTANCE : FEATURE_TYPE 주석만 정정(CHANNEL_NEW_SPNSR = NULL)
--       ONCE_CONVERSION    : 관측월·가입월·가입경과월·최신관측 축 폐기 · STDR_MT = 기준월 · PK (STDR_MT, ONCE_MBER_NO) · VQR 교체
--       DVLP/FEE_FORECAST  : base 뷰 컬럼 계약 불변 ⇒ 무변경
--   · 🔴 Agent 도구 설명(SV 이름·기본 분해축)을 함께 갱신해야 한다 — SV_ML_LTV_SCORE 참조 제거 포함.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_RISK
  TABLES (
    mr AS GN_DW.SERVING.ML_MEMBER_RISK_V
      PRIMARY KEY (STDR_MT, MBER_NO)
      WITH SYNONYMS ('회원 예측', '회원 위험', '중단 예측', '증액 예측', '충성회원 예측')
      COMMENT = '회원 단위 ML 예측 분석 (중단·증액·충성) (base: SERVING.ML_MEMBER_RISK_V). [Grain: 기준월 × 회원]. [활성 지표: 중단확률/증액확률/충성확률 · 등급]. [주의: 예측치이며 실적 아님, 기준월별 독립 산출(합산 금지), 원천 중복행은 확률 평균으로 단일화]. [원천: ML 예측 결과 3종 → SERVING.ML_MEMBER_RISK_V].'
  )
  DIMENSIONS (
    mr.STDR_MT AS mr.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '모델 실행월')
      COMMENT = '모델 실행 기준월(YYYYMM 문자열). 🔴이 값이 여러 개면 서로 다른 실행 결과이므로 합산하지 않는다 — 반드시 하나를 고르거나 기준월별로 나눠 답한다. 🔴 **실제값을 여기에 열거하지 않는다** — 모델을 다시 돌릴 때마다 늘어나므로 열거하면 즉시 낡는다. 최신 기준월은 조회해서 확인한다.',
    mr.MBER_NO AS mr.MBER_NO
      WITH SYNONYMS ('회원번호', '회원')
      COMMENT = '회원번호. 회원수는 이 축의 중복제거로 센다.',
    mr.CHURN_CLASS AS mr.CHURN_CLASS
      WITH SYNONYMS ('중단 예측 판정', '중단 클래스')
      COMMENT = '중단 예측의 모델 기본 판정. 실제값 2종: ''0''(유지 예측)·''1''(중단 예측). 🔴원천 중복행 중 하나라도 ''1''이면 ''1''이다(평균 확률과 어긋날 수 있다). 🔴모델 기본 임계(0.5)의 판정이며 **업무 위험 판정선은 미확정**이다 ⇒ 「위험 회원」이라 단정하지 말고 「모델이 중단으로 분류한 회원」으로 답한다.',
    mr.INC_CLASS AS mr.INC_CLASS
      WITH SYNONYMS ('증액 예측 판정', '증액 클래스')
      COMMENT = '증액 가능성 예측의 모델 기본 판정. 실제값 2종: ''0''(비증액)·''1''(증액 예측). 중복행·임계값 주의사항은 CHURN_CLASS 와 동일.',
    mr.LOYAL_CLASS AS mr.LOYAL_CLASS
      WITH SYNONYMS ('충성회원 예측 판정')
      COMMENT = '충성회원 가능성 예측의 모델 기본 판정. 실제값 2종: ''0''(비충성)·''1''(충성 예측). 🔴이 예측은 모집단이 더 좁다 ⇒ NULL 은 「비충성」이 아니라 「예측 대상 아님」이다.',
    mr.CHURN_GRADE AS mr.CHURN_GRADE
      WITH SYNONYMS ('중단위험 등급', '위험 등급', '고위험군')
      COMMENT = 'F-4 중단위험 등급 — 값 3종: ''고위험''·''주의''·''일반''(기준월 안의 확률 순위 구간 · 경계 정의 = SERVING.ML_MEMBER_RISK_V). 🔴 확률 임계가 아니라 **순위(백분위)** 다 — 「고위험군」 질문은 이 축을 쓴다 · 기준월 1개로 고정한다.',
    mr.LOYAL_GRADE AS mr.LOYAL_GRADE
      WITH SYNONYMS ('장기회원 등급', '충성 등급')
      COMMENT = 'F-4 장기회원 등급 — 값 4종: ''최상위''·''상''·''중''·''하''(기준월 안의 확률 순위 구간 · 경계 정의 = SERVING.ML_MEMBER_RISK_V). 🔴 순위 기반 · 충성 예측 모집단만 값이 있다(그 외 NULL = 대상 아님).',
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
    mr.CHURN_PRED_ROWS AS mr.CHURN_PRED_ROWS
      WITH SYNONYMS ('중단 예측 원천 행수')
      COMMENT = '이 회원·기준월의 원천 중단 예측 행수. 🔴1 을 넘으면 원천이 같은 회원에 확률이 다른 예측을 여러 개 담은 것이다(실행순번이 없어 최신을 고를 수 없어 평균으로 단일화했다). 품질 점검용이며 업무 축이 아니다.'
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
    mr.DUP_SOURCE_MEMBERS AS COUNT(DISTINCT CASE WHEN mr.CHURN_PRED_ROWS > 1 OR mr.INC_PRED_ROWS > 1 THEN mr.MBER_NO END)
      WITH SYNONYMS ('원천 중복 회원수')
      COMMENT = '원천에 중단 또는 증액 예측이 여러 행 있는 회원수(중복제거). 품질 점검용 — 업무 수치로 답하지 않는다.'
  )
  COMMENT = 'ML 회원단위 예측 SV(중단·증액·충성). base=SERVING.ML_MEMBER_RISK_V. 🔴🔴 이 SV 의 모든 값은 **머신러닝 예측치이며 실적이 아니다** — 실적 SV(SV_MEMBER_MONTHLY·SV_MEMBER_FEE·SV_MEMBER_EVENT)의 measure 와 같은 표에 합산하지 않는다. 🔴 머신러닝은 **테스트 단계**이며 모델·피처·테이블 구조가 교체될 수 있다 ⇒ 값의 안정성을 보장하지 않는다(2026-10-02 원천 구조 교체로 회원상태·결제수단·법인구분·피처 축이 사라졌다). 🔴 **중단 예측의 예측 지평은 발행하지 않는다** — 원천의 테이블명은 12개월을 뜻하는데 원천 테이블 설명은 6개월이어서 부정합이 있고, 어느 쪽이 맞는지 원천 담당자 확인 전이다 ⇒ 「향후 N개월」이라고 답하지 말고 「예측 지평은 원천 확인 중」이라고 밝힌다. 🔴 원천이 같은 기준월에 회원당 확률이 다른 예측을 여러 행 담고 있어(실행순번 없음) 확률은 평균, 분류는 「하나라도 1」로 단일화했다 — 원천 교정 시 확률·건수가 변한다. 🔴 모집단은 전체 회원이 아니라 예측 대상 회원이다 ⇒ 「전 회원 대비 비율」 산출 불가. 활성: 예측 대상 회원수·모델 분류 회원수·확률 평균/최대·원천 중복 회원수 · 판정·등급 축. 비활성: 회원상태·결제수단·법인구분·가입기간 등 회원 속성 축(원천 피처 제거로 미배선) · 업무 위험 임계값(미확정).'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **예측과 실적을 한 표에 합산하지 않는다.** 이 SV 는 예측 전용이다. 실적 수치가 함께 필요하면 표를 분리하고 각 표가 예측인지 실적인지 명시한다. (2) 🔴 **기준월(STDR_MT)을 여러 개 합산하지 않는다** — 서로 다른 모델 실행 결과이며 같은 회원이 여러 기준월에 등장한다. 기준월 지정이 없으면 데이터에 존재하는 최신 기준월(MAX(STDR_MT)) 하나로 한정하고 그 기준월을 답변에 밝힌다. (3) 🔴 **회원수는 반드시 중복제거로 센다** — PREDICTED_MEMBERS·MODEL_*_MEMBERS 를 쓰고 COUNT(*) 를 만들지 않는다. (4) 🔴 **「위험 회원」이라 단정하지 않는다** — 업무 위험 판정선이 미확정이므로 모델 분류 결과는 「모델이 중단으로 분류한 회원」으로 표현하고, 확률 기준을 사용자가 지정하면 그 기준을 답변에 명시한다. 「고위험군」은 CHURN_GRADE 순위 등급으로 답한다. (5) 🔴 **예측 지평(몇 개월)을 숫자로 답하지 않는다** — 원천 부정합이 미해소이므로 「예측 지평은 원천 확인 중」이라고 밝힌다. 증액·충성 예측에도 같은 원칙으로 기간을 임의로 붙이지 않는다. (6) 🔴 **비율의 분모를 밝힌다** — 이 SV 의 모집단은 전체 회원이 아니라 예측 대상 회원이고, 충성 예측은 더 좁은 부분집합이다. 충성 비율의 분모는 PREDICTED_LOYAL_MEMBERS 다. (7) **확률은 평균·최대만 쓴다** — SUM 하지 않는다. (8) **NULL 판정은 「아니다」가 아니라 「예측 대상 아님」이다** — 특히 충성 예측의 NULL 을 비충성으로 세지 않는다. (9) 🔴 **회원상태·결제수단·법인구분·가입기간별 분해를 물으면 SQL 을 만들지 않는다** — 원천 구조 교체로 이 SV 에 해당 축이 없다고 답하고, 등급(CHURN_GRADE·LOYAL_GRADE)별 분해를 대안으로 안내한다. (10) **답변에 항상 예측치임과 테스트 단계임을 한 문장으로 밝힌다.** (11) 적용 조건(기준월·그룹 모두 미지정 시): 최신 기준월로 한정하고 CHURN_GRADE 별 회원수와 평균 중단확률을 함께 반환한다. (12) 🔴 metric 이름(PREDICTED_MEMBERS·MODEL_CHURN_MEMBERS·MODEL_INC_MEMBERS·MODEL_LOYAL_MEMBERS·AVG_CHURN_PROB 등)을 mr 컬럼처럼 참조하지 않는다 — 정의식(COUNT(DISTINCT CASE WHEN mr.CHURN_CLASS = ''1'' THEN mr.MBER_NO END) 등)으로 집계한다.';

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_RISK TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_RISK TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_MEMBER_RISK TO ROLE GN_DW_SERVICE;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_SPONSOR_RISK
  TABLES (
    sr AS GN_DW.SERVING.ML_SPONSOR_RISK_V
      PRIMARY KEY (STDR_MT, MBER_NO, SPNSR_BSNS_ID, SPNSR_BSNS_NO)
      WITH SYNONYMS ('후원건 이탈 예측', '카테고리별 이탈 예측', '후원 이탈')
      COMMENT = '후원계좌 단위 이탈 예측 분석 (base: SERVING.ML_SPONSOR_RISK_V). [Grain: 기준월 × 회원 × 후원사업 × 약정번호]. [활성 지표: 후원계좌 이탈확률]. [주의: 1회원 다수 약정 보유(회원수는 COUNT DISTINCT 집계)]. [원천: ML 이탈모델 → SERVING.ML_SPONSOR_RISK_V].'
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
    sr.CMPGN_CTGR_CD AS sr.CMPGN_CTGR_CD
      WITH SYNONYMS ('캠페인카테고리코드')
      COMMENT = 'degen: 캠페인 카테고리 코드(원천 컬럼). 라벨은 CMPGN_CTGR_NAME. 🔴 실제값은 열거하지 않는다 — 값 목록은 SELECT DISTINCT 로 조회한다.',
    sr.CMPGN_CTGR_NAME AS sr.CMPGN_CTGR_NAME
      WITH SYNONYMS ('캠페인카테고리', '캠페인 구분', '카테고리')
      COMMENT = '캠페인 카테고리명(캠페인 마스터 DISTINCT · 코드당 1개). 카테고리별 분해의 정본 축이다. 🔴 개별 캠페인·상위캠페인(채널) 축은 원천 구조 교체(2026-10-02)로 이 SV 에 없다.',
    sr.CHURN_CLASS AS sr.CHURN_CLASS
      WITH SYNONYMS ('이탈 예측 판정')
      COMMENT = '모델 기본 판정. 실제값 2종: ''0''(유지)·''1''(이탈 예측). 🔴업무 위험 판정선은 미확정이다.',
    sr.CHURN_GRADE AS sr.CHURN_GRADE
      WITH SYNONYMS ('이탈위험 등급', '위험 등급', '고위험 후원건')
      COMMENT = 'F-4 후원건 이탈위험 등급 — 값 3종: ''고위험''·''주의''·''일반''(기준월 안의 후원건 확률 순위 구간 · 경계 정의 = SERVING.ML_SPONSOR_RISK_V). 🔴 순위 기반 · 기준월 1개로 고정한다.',
    sr.PREDICTION_HAS_ERROR AS sr.PREDICTION_HAS_ERROR
      WITH SYNONYMS ('예측 오류 여부')
      COMMENT = 'TRUE=모델 산출 로그에 오류가 기록됐다.'
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
      COMMENT = '이탈확률 최대값. 상위 위험 후원건 정렬에 쓴다.'
  )
  COMMENT = 'ML 후원건단위 이탈 예측 SV. base=SERVING.ML_SPONSOR_RISK_V. 🔴🔴 예측치이며 실적이 아니다 — 실적 SV 와 합산 금지. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다(2026-10-02 원천 구조 교체로 캠페인·상위캠페인·결제수단·후원금액·피처 축이 사라졌다). 🔴 **grain 이 후원건이다** — 회원 단위 질문에는 반드시 중복제거 회원수를 쓴다. 회원단위 예측(SV_ML_MEMBER_RISK)과 이 SV 를 조인해 한 표로 만들지 않는다(회원당 후원건 다건이라 회원 지표가 과대계상된다). 🔴 예측 지평은 발행하지 않는다(원천 기간 표기 확인 전). 활성: 후원건수·회원수·모델 분류 건수/회원수·확률 평균/최대 · 후원사업·캠페인카테고리·판정·등급 축. 비활성: 캠페인·상위캠페인(채널)·결제수단 축 · 이탈분류 후원금액(원천 금액 컬럼 제거) · 업무 위험 임계값(미확정) · 부서 축(원천에 부재).'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **예측과 실적을 합산하지 않는다.** (2) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (3) 🔴🔴 **「명」과 「건」을 구분한다** — grain 이 후원건이므로 회원수는 PREDICTED_MEMBERS·MODEL_CHURN_MEMBERS(중복제거)를 쓰고, 건수는 PREDICTED_SPONSORSHIPS·MODEL_CHURN_SPONSORSHIPS 를 쓴다. 회원수를 COUNT(*) 로 세면 과대다. (4) 🔴 **SV_ML_MEMBER_RISK 와 한 쿼리로 조인하지 않는다** — grain 이 달라 팬아웃이 난다. 둘 다 필요하면 표를 분리하고 각 표의 grain 을 명시한다. (5) 🔴 **「위험」·「이탈할 것이다」로 단정하지 않는다** — 업무 임계값 미확정이므로 「모델이 이탈로 분류」로 표현한다. (6) 🔴 **캠페인별·상위캠페인(채널)별·결제수단별 이탈 예측이나 이탈분류 후원금액을 물으면 SQL 을 만들지 않는다** — 원천 구조 교체로 해당 축·금액이 없다고 답하고, 캠페인카테고리별 분해를 대안으로 안내한다. (7) 🔴 **예측 지평을 숫자로 답하지 않는다**(원천 확인 중). (8) **확률은 평균·최대만 쓴다.** 평균은 후원건 가중임을 밝힌다. (9) **답변에 예측치임과 테스트 단계임을 밝힌다.** (10) 적용 조건(기준월·그룹 미지정 시): 최신 기준월로 한정하고 캠페인카테고리(CMPGN_CTGR_NAME)별 후원건수·모델 이탈분류 건수·평균 이탈확률을 반환한다. (11) 🔴 metric 이름(PREDICTED_MEMBERS·MODEL_CHURN_MEMBERS·PREDICTED_SPONSORSHIPS·MODEL_CHURN_SPONSORSHIPS 등)을 sr 컬럼처럼 참조하지 않는다 — 정의식(COUNT(DISTINCT CASE WHEN sr.CHURN_CLASS = ''1'' THEN sr.MBER_NO END) 등)으로 집계한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_SPONSOR_RISK TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_SPONSOR_RISK TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_SPONSOR_RISK TO ROLE GN_DW_SERVICE;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST
  TABLES (
    df AS GN_DW.SERVING.ML_DVLP_FORECAST_V
      PRIMARY KEY (STDR_MT, SERIES_TYPE, SERIES_CD, TS)
      WITH SYNONYMS ('개발 예측', '개발금액 예측', '개발액 예측', '연도말 개발 예측')
      COMMENT = '개발금액 시계열 예측 2계열 분석 (base: SERVING.ML_DVLP_FORECAST_V). [Grain: 기준월 × 계열유형 × 계열 × 예측월]. [활성 지표: 예측 개발금액(만원)]. [주의: 단위=만원, 계열유형 간 단순 합산 금지(독립 예측), 부서·후원사업·신규기존 예측은 원천 삭제로 미제공]. [원천: ML 시계열모델 2종 → SERVING.ML_DVLP_FORECAST_V].'
  )
  DIMENSIONS (
    df.STDR_MT AS df.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '모델 실행월')
      COMMENT = '모델 실행 기준월(YYYYMM). 🔴여러 기준월을 합산하면 같은 예측월이 중복계상된다. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    df.SERIES_TYPE AS df.SERIES_TYPE
      WITH SYNONYMS ('계열유형', '집계 단위', '분해축')
      COMMENT = '예측 계열의 유형. 실제값: ''TOTAL''(전사)·''CAMPAIGN''(캠페인). 🔴🔴 **항상 이 축을 지정하거나 그룹에 넣는다** — 유형을 섞어 합하면 같은 개발 활동을 여러 축으로 겹쳐 세어 과대가 된다. 🔴 **유형별 합계는 서로 일치하지 않는다** — 각 계열을 독립적으로 예측한 결과이므로 전사와 캠페인 합이 다르다(캠페인은 일부 계열) ⇒ 한 유형으로 다른 유형을 검산하지 말 것. 🔴 부서·후원사업·신규기존 예측은 원천 삭제로 제공하지 않는다.',
    df.SERIES_CD AS df.SERIES_CD
      WITH SYNONYMS ('계열코드')
      COMMENT = 'degen: 계열 코드. 🔴계열유형에 따라 의미가 다르다(캠페인코드 / (전사)) ⇒ SERIES_TYPE 없이 해석하지 말 것.',
    df.SERIES_NAME AS df.SERIES_NAME
      WITH SYNONYMS ('계열명', '부서명', '후원사업명', '캠페인명')
      COMMENT = '계열 라벨(계열유형별로 캠페인명·전사 합계).',
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
  COMMENT = 'ML 개발금액 예측 SV(2종 통합 · 전사·캠페인). base=SERVING.ML_DVLP_FORECAST_V. 🔴🔴 **단위는 만원이다** — 원 단위 실적(예산·회비 SV)과 같은 표에 넣으면 만 배 오차가 난다. 🔴🔴 예측치이며 실적이 아니다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴🔴 **계열유형(SERIES_TYPE)을 반드시 고정하거나 그룹에 넣는다** — 유형을 섞어 합하면 같은 개발 활동을 여러 축으로 겹쳐 세어 과대가 된다. 🔴🔴 **유형별 합계는 서로 일치하지 않는다** — 계열마다 독립적으로 예측했기 때문에 전사와 캠페인 합이 다르다(캠페인은 일부 계열) ⇒ 한 유형으로 다른 유형을 검산하지 말고, 「캠페인 합이 전사와 다르다」는 지적에는 이 구조를 설명한다. 🔴 기준월(모델 실행월)과 예측월(TS)은 다른 축이다. ⚠️ 예측치에 음수가 존재한다(감액·해지 반영) — 음수를 오류로 보지 않는다. ⚠️ 캠페인 계열은 원천이 일부 캠페인만 담고 있다(근거 = 20_ML_SV_설계.md). 🔴 부서·후원사업·신규기존 예측은 원천 테이블 삭제로 제공하지 않는다. 활성: 예측액·신뢰구간·월평균·예측개월수·계열수 · 계열유형/계열/예측월 축. 비활성: 본부·지부 분해(조직 계층 산출규칙 미확정) · 부서/후원사업/신규기존 분해(원천 삭제) · 실적 대비 정확도(실적 조인 미배선) · 유형 간 정합 검산(원천이 보장하지 않는다).'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **SERIES_TYPE 을 반드시 WHERE 로 고정하거나 GROUP BY 에 넣는다.** 넣지 않으면 전사와 캠페인을 겹쳐 세어 합계가 과대가 된다. 질문이 「전사/전체 개발 예측」이면 SERIES_TYPE=''TOTAL'' 로 고정한다. 「캠페인별」이면 ''CAMPAIGN'' 이다. 🔴 「부서별·후원사업별·신규/기존별 개발 예측」을 물으면 SQL을 만들지 말고, 해당 예측은 원천 삭제로 현재 제공하지 않는다고 답한다. 전사 또는 캠페인 예측을 대안으로 안내하되 이를 부서 값처럼 나눠 계산하지 않는다. (2) 🔴🔴 **단위는 만원이다.** 답변에 항상 단위를 밝히고, 원으로 환산하면 환산했다고 명시한다. 예산·회비 등 원 단위 지표와 같은 표에 합산하지 않는다. (3) 🔴 **기준월(STDR_MT)을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 그 기준월을 밝힌다. (4) 🔴 **기준월과 예측월(TS)을 혼동하지 않는다** — 「향후 12개월 예측」은 하나의 기준월에 속한 TS 12개다. 연도말 전망을 물으면 해당 연도에 속한 TS 만 합산하고 기준월을 밝힌다. (5) 🔴 **예측치임을 답변에 밝힌다** — 실적으로 읽히는 표현(「개발액은 …이다」)을 쓰지 않고 「예측치는 …」으로 쓴다. 테스트 단계임도 함께 밝힌다. (6) **음수 예측치를 오류로 처리하거나 0 으로 바꾸지 않는다** — 감액·해지가 반영된 값이다. (7) **신뢰구간을 별개 수치로 나열하지 않는다** — 예측치와 함께 구간으로 제시한다. (8) 🔴 **유형 간 검산을 시도하지 않는다** — 캠페인 합은 전사 예측과 일치하지 않는다(계열별 독립 예측 · 캠페인은 일부 계열). 사용자가 불일치를 지적하면 원천이 정합을 보장하지 않는 구조라고 설명하고, 임의로 비례배분해 맞추지 않는다. 캠페인 계열은 일부 캠페인만 예측 대상임도 밝힌다. (9) 적용 조건(기준월·계열유형 모두 미지정 시): 최신 기준월 + SERIES_TYPE=''TOTAL'' 로 한정해 예측월별 예측액과 신뢰구간을 반환하고, 다른 분해축이 있음을 안내한다.'
  AI_VERIFIED_QUERIES (
    vqr_total_forecast_by_month AS (
      QUESTION '최신 기준월 전사 개발금액 예측(예측월별)'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT df.TS, SUM(df.FORECAST) AS FORECAST_AMT FROM df WHERE df.SERIES_TYPE = ''TOTAL'' AND df.STDR_MT = (SELECT MAX(df.STDR_MT) FROM df) GROUP BY df.TS ORDER BY df.TS'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST TO ROLE GN_DW_SERVICE;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEE_FORECAST
  TABLES (
    ff AS GN_DW.SERVING.ML_FEE_FORECAST_V
      PRIMARY KEY (STDR_MT, CMPGN_CTGR_CD, FORECAST_TS)
      WITH SYNONYMS ('회비 예측', '카테고리별 회비 예측', '후원금액 예측')
      COMMENT = '캠페인 카테고리별 회비 예측 분석 (base: SERVING.ML_FEE_FORECAST_V). [Grain: 기준월 × 캠페인카테고리 × 예측월]. [활성 지표: 예측 회비금액(원)]. [주의: 단위=원, 개발금액(만원)과 단위 상이(합산 금지)]. [원천: ML 회비예측모델 → SERVING.ML_FEE_FORECAST_V].'
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

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_FORECAST
  TABLES (
    lf AS GN_DW.SERVING.ML_LTV_FORECAST_V
      PRIMARY KEY (STDR_MT, LTV_TYPE, SERIES_CD, TS)
      WITH SYNONYMS ('LTV 예측', '생애가치 예측', '후원 LTV 예측', '채널별 후원금액 예측')
      COMMENT = '마케팅채널·캠페인 LTV 월별 시계열 예측 분석 (base: SERVING.ML_LTV_FORECAST_V). [Grain: 기준월 × LTV유형 × 계열 × 예측월]. [활성 지표: 예측 금액(원)]. [주의: 마케팅채널 회원평균 후원금액과 캠페인 월간 후원금액 분리]. [원천: ML LTV모델 2종 → SERVING.ML_LTV_FORECAST_V].'
  )
  DIMENSIONS (
    lf.STDR_MT AS lf.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월')
      COMMENT = '모델 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    lf.LTV_TYPE AS lf.LTV_TYPE
      WITH SYNONYMS ('LTV 유형', 'LTV 구분')
      COMMENT = 'LTV 유형. 실제값: ''MKTG_CHANNEL_AVG_MEMBER''(마케팅채널 회원평균 후원금액)·''CMPGN_TOTAL''(캠페인 월간 후원금액). 🔴🔴 **반드시 하나로 고정한다** — 하나는 1인당 평균이고 하나는 총액이라 자리수가 크게 다르고, 계열 축(마케팅채널 ↔ 캠페인)도 다르다.',
    lf.LTV_TYPE_NAME AS lf.LTV_TYPE_NAME
      WITH SYNONYMS ('LTV 유형명')
      COMMENT = 'LTV 유형 라벨. 실제값 2종: ''마케팅채널 회원평균 후원금액''·''캠페인 월간 후원금액''.',
    lf.SERIES_CD AS lf.SERIES_CD
      WITH SYNONYMS ('계열코드', '마케팅채널코드', '캠페인코드')
      COMMENT = 'degen: 계열 코드. 🔴LTV유형에 따라 마케팅채널 코드(MKTG_CHANNEL) 또는 캠페인코드(CMPGN_CD)다 — 유형 없이 해석하지 말 것.',
    lf.SERIES_NAME AS lf.SERIES_NAME
      WITH SYNONYMS ('계열명', '마케팅채널', '채널명', '캠페인명')
      COMMENT = '계열 라벨(마케팅채널명 / 캠페인명 · 캠페인 마스터). 🟢 이 SV 에서는 라벨 미도달이 없다(2026-10-02 실측).',
    lf.TS AS lf.TS
      WITH SYNONYMS ('예측월', '예측 시점')
      COMMENT = '예측 대상 월(월 시작일). 기준월과 다르다.'
  )
  METRICS (
    lf.AVG_FORECAST_LTV AS AVG(lf.FORECAST)
      WITH SYNONYMS ('평균 LTV 예측', 'LTV 예측치')
      COMMENT = '예측값 평균(원). 🔴LTV유형을 고정한 상태에서만 의미가 있다. 회원평균 유형에서는 「회원 1인당 평균의 평균」이므로 회원수 가중이 아니다.',
    lf.TOTAL_FORECAST_LTV AS SUM(lf.FORECAST)
      WITH SYNONYMS ('LTV 예측 합계', '예측 후원금액 합계')
      COMMENT = '예측값 합계(원). 🔴🔴 **회원평균 유형(MKTG_CHANNEL_AVG_MEMBER)에서는 합산하지 않는다** — 1인당 평균을 더한 값은 업무 의미가 없다. 총액 유형(CMPGN_TOTAL)에서만 합산한다.',
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
      WITH SYNONYMS ('계열 수', '채널 수', '캠페인 수')
      COMMENT = '예측 대상 계열 수.'
  )
  COMMENT = 'ML LTV 월별 예측 SV(2종). base=SERVING.ML_LTV_FORECAST_V. 🔴🔴 예측치이며 실적이 아니다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다(2026-10-02 원천 교체 — 종전 상위캠페인 회원평균 LTV·캠페인 총액 LTV·LTV 스코어 4종은 폐기됐다). 🔴🔴 **LTV_TYPE 을 반드시 하나로 고정한다** — ''MKTG_CHANNEL_AVG_MEMBER''는 마케팅채널의 **회원 1인당 평균 후원금액** 예측이고 ''CMPGN_TOTAL''은 캠페인의 **월간 후원금액 총액** 예측이다. 두 유형은 의미·자리수·계열 축이 달라 합산·순위 비교를 함께 하면 반드시 틀린다. ⚠️ **원천 표기와 데이터가 다르다** — 원천은 두 테이블 모두 계열 컬럼을 MKTG_CHANNEL(채널)로 이름 붙였으나 CMPGN_TOTAL 쪽 값은 캠페인코드다 ⇒ 「채널별」 질문은 MKTG_CHANNEL_AVG_MEMBER 로, 「캠페인별 후원금액 예측」은 CMPGN_TOTAL 로 답한다(원천 확인 중). 🔴 회원평균 유형을 합산하지 않는다. 활성: 예측 평균/합계·신뢰구간·예측개월수·계열수 · LTV유형/계열/예측월 축. 비활성: 회원 단위 LTV(원천 grain 이 계열) · 계열당 LTV 스코어(원천 폐기) · 실적 대비 정확도.'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **LTV_TYPE 을 WHERE 로 하나 고정한다.** 두 유형을 한 표에 섞지 않는다 — 하나는 1인당 평균, 하나는 총액이며 계열 축이 다르다. 「채널별/마케팅채널별 (회원평균) 후원금액·LTV」는 ''MKTG_CHANNEL_AVG_MEMBER'', 「캠페인별 후원금액 예측」은 ''CMPGN_TOTAL'' 이다. 어느 쪽인지 불분명하면 사용자에게 확인하거나 두 표로 나눠 각 정의를 밝힌다. (2) 🔴🔴 **회원평균 유형에서 TOTAL_FORECAST_LTV(합계)를 쓰지 않는다** — 1인당 평균을 더한 값은 의미가 없다. 그 유형에서는 AVG_FORECAST_LTV 를 쓴다. (3) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (4) 🔴 **예측치임과 테스트 단계임을 밝힌다.** (5) **단위는 원이다.** 개발금액 예측(만원)과 합산하지 않는다. (6) 🔴 **「LTV 스코어·과거 누적 LTV·상위캠페인 LTV」를 물으면 SQL 을 만들지 않는다** — 원천 폐기로 제공하지 않는다고 답하고 이 SV 의 월별 예측을 대안으로 안내한다. (7) 적용 조건(기준월·유형 미지정 시): 최신 기준월 + LTV_TYPE=''MKTG_CHANNEL_AVG_MEMBER'' 로 한정해 계열별 평균 예측 상위를 반환하고, 다른 유형이 있음을 안내한다.'
  AI_VERIFIED_QUERIES (
    vqr_o198_top_channel_avg AS (
      QUESTION '마케팅채널별 회원평균 후원금액 예측 상위 10(최신 기준월)'
      VERIFIED_BY '(DW = O198)'
      SQL 'SELECT lf.SERIES_NAME, AVG(lf.FORECAST) AS AVG_FORECAST_LTV FROM lf WHERE lf.LTV_TYPE = ''MKTG_CHANNEL_AVG_MEMBER'' AND lf.STDR_MT = (SELECT MAX(lf.STDR_MT) FROM lf) GROUP BY lf.SERIES_NAME ORDER BY AVG_FORECAST_LTV DESC NULLS LAST LIMIT 10'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_FORECAST TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_FORECAST TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_FORECAST TO ROLE GN_DW_SERVICE;

-- ⛔ SV_ML_LTV_SCORE — [2026-10-02 O198] base 뷰(ML_LTV_SCORE_V)의 원천 2종 이관 제외로 폐기.
--   · 구 정의 = _archive/22_ML_SV_DDL_pre_O198.sql
--   · 라이브 정리(되돌릴 수 없음 — Agent 도구 등록에서 먼저 제거한 뒤 수동 실행):
--     DROP SEMANTIC VIEW IF EXISTS GN_DW.SERVING.SV_ML_LTV_SCORE;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEATURE_IMPORTANCE
  TABLES (
    fi AS GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V
      PRIMARY KEY (STDR_MT, ANALYSIS_TYPE, FEATURE)
      WITH SYNONYMS ('요인분석', '피처 중요도', '기여도', '결정 요인')
      COMMENT = '머신러닝 피처 중요도 분석 (base: SERVING.ML_FEATURE_IMPORTANCE_V). [Grain: 기준월 × 분석유형 × 피처]. [활성 지표: 피처별 기여도(0~1)]. [주의: 모델 해석용 지표(분석유형 내 합계=1), 업무 실적치 아님]. [원천: ML 피처중요도모델 → SERVING.ML_FEATURE_IMPORTANCE_V].'
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
      COMMENT = '피처 유형. 실제값: ''user_provided''(DVLP_INC 만) · CHANNEL_NEW_SPNSR 는 원천 컬럼 제거(2026-10-02)로 NULL — NULL 은 「모델이 고른 피처」라는 뜻이 아니다. 🔴🔴 이 값의 뜻은 **피처 목록을 사람이 지정했다**는 것이다 — 모델이 스스로 후보 변수를 탐색해 고른 결과가 아니므로 「데이터가 밝혀낸 요인」으로 답하지 않는다.'
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
  COMMENT = 'ML 요인분석(피처 중요도) SV(2종). base=SERVING.ML_FEATURE_IMPORTANCE_V. 🔴🔴 **이 SV 는 모델을 설명하는 것이고 업무 실적을 측정하는 것이 아니다** — 값은 0~1 기여도이며 금액·건수·회원수가 아니다. 다른 SV 의 measure 와 같은 표에 넣으면 업무 수치로 오독된다. 🔴 머신러닝은 테스트 단계이며 모델·피처가 교체될 수 있다. 🔴🔴 **ANALYSIS_TYPE 을 반드시 하나로 고정한다** — 유형 내 기여도 합계가 1 이므로 섞으면 합계가 1 을 넘는다. 🔴🔴 **피처 목록은 사람이 지정한 것이다**(피처 유형 ''user_provided'' · CHANNEL_NEW_SPNSR 는 원천에서 유형 컬럼이 제거돼 NULL 이나 같은 방식의 지정 후보로 본다 — 원천 확인 대상) ⇒ 「데이터 분석으로 발견한 요인」이라 답하지 않고 「지정된 후보 요인 중 모델이 매긴 상대 중요도」로 답한다. 🔴 **기여도는 인과가 아니다** — 「이 요인을 늘리면 신규 후원이 늘어난다」는 결론을 내지 않는다. 활성: 기여도 합계/평균/최대·피처수 · 분석유형/피처/순위/피처유형 축. 비활성: 인과 효과 크기 · 요인별 금액 환산.'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **ANALYSIS_TYPE 을 하나 고정한다** — 유형 내 기여도 합계가 1 이므로 두 유형을 섞으면 합계가 1 을 넘고 순위도 뒤섞인다. (2) 🔴🔴 **이 값을 업무 수치로 답하지 않는다** — 금액·건수·회원수가 아니라 모델 기여도(0~1)다. 다른 SV 의 measure 와 같은 표에 넣지 않는다. (3) 🔴🔴 **인과로 답하지 않는다** — 「A 를 늘리면 신규 후원이 늘어난다」가 아니라 「모델이 A 에 가장 큰 상대 중요도를 부여했다」로 표현한다. (4) 🔴 **피처 목록이 사람이 지정한 후보라는 사실을 밝힌다**(피처 유형=user_provided · CHANNEL_NEW_SPNSR 는 NULL) — 「데이터가 찾아낸 요인」이라 하지 않는다. 지정되지 않은 요인은 애초에 후보가 아니었으므로 「중요하지 않다」고 말할 수 없다. (5) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (6) **상위 요인은 RANK 로 정렬한다.** (7) **답변에 모델 설명이며 테스트 단계임을 밝힌다.** (8) 적용 조건(기준월·유형 미지정 시): 최신 기준월 + 사용자가 언급한 주제에 맞는 분석유형 하나로 한정해 RANK 순 상위 요인과 기여도를 반환하고, 다른 분석유형이 있음을 안내한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEATURE_IMPORTANCE TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEATURE_IMPORTANCE TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_FEATURE_IMPORTANCE TO ROLE GN_DW_SERVICE;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_ONCE_CONVERSION
  TABLES (
    oc AS GN_DW.SERVING.ML_ONCE_CONVERSION_V
      PRIMARY KEY (STDR_MT, ONCE_MBER_NO)
      WITH SYNONYMS ('정기전환 예측', '일시후원 전환 예측', '정기후원 전환 가능성', '일시회원 전환')
      COMMENT = '일시후원회원의 정기후원 전환 ML 예측 분석 (base: SERVING.ML_ONCE_CONVERSION_V). [Grain: 기준월 × 일시후원회원(원천 다중 예측행 포함)]. [활성 지표: 전환확률·모델 전환분류 회원수]. [주의: 예측치이며 실적 아님, 회원당 여러 예측행]. [원천: ML 전환예측 결과 → SERVING.ML_ONCE_CONVERSION_V].'
  )
  DIMENSIONS (
    oc.STDR_MT AS oc.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '모델 실행월')
      COMMENT = '모델 실행 기준월(YYYYMM 문자열). 다른 ML SV 와 같은 의미다(2026-10-02 원천 교체로 종전 「관측월」 해석은 폐기). 🔴 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    oc.STDR_MONTH_KEY AS oc.STDR_MONTH_KEY
      WITH SYNONYMS ('기준연월')
      COMMENT = '기준연월(YYYYMM 정수). 연·월 필터에 쓴다.',
    oc.ONCE_MBER_NO AS oc.ONCE_MBER_NO
      WITH SYNONYMS ('일시후원회원번호', '일시회원번호', '일시회원')
      COMMENT = '일시후원회원번호. 🔴정기회원 회원번호(MBER_NO)와 다른 번호체계다 — 다른 회원 SV 와 조인·대조하지 않는다. 회원수는 이 축의 중복제거로 센다.',
    oc.CONVERT_CLASS AS oc.CONVERT_CLASS
      WITH SYNONYMS ('전환 예측 판정', '전환 클래스')
      COMMENT = '정기후원 전환 예측의 모델 기본 판정. 실제값 2종: ''0''(비전환 예측)·''1''(전환 예측). 🔴모델 기본 임계(0.5)의 판정이며 업무 판정선은 미확정이다 ⇒ 「전환할 회원」이라 단정하지 말고 「모델이 전환으로 분류한 회원」으로 답한다.',
    oc.PREDICTION_HAS_ERROR AS oc.PREDICTION_HAS_ERROR
      WITH SYNONYMS ('예측 오류 여부')
      COMMENT = 'TRUE=모델 산출 로그에 오류가 기록됐다. 품질 점검용.',
    oc.SEX_NAME AS oc.SEX_NAME
      WITH SYNONYMS ('성별', '일시회원 성별')
      COMMENT = '일시회원 성별 라벨(코드사전 CM013 — 내국/외국인 구분 포함). 🔴 현재 회원 마스터 값이며 가입 시점 값이 아니다. 라벨이 없는 회원은 NULL.',
    oc.MEMBER_DIV_NAME AS oc.MEMBER_DIV_NAME
      WITH SYNONYMS ('회원구분', '개인/단체', '일시회원 구분')
      COMMENT = '일시회원 회원구분 라벨(개인·단체·기업 등). 🔴 현재 회원 마스터 값이다. 값 목록은 SELECT DISTINCT 로 조회한다.',
    oc.REGIST_DEPT_NAME AS oc.REGIST_DEPT_NAME
      WITH SYNONYMS ('등록부서', '일시회원 등록부서', '부서')
      COMMENT = '일시회원을 등록한 부서명(조직 차원 DEPARTMENT). 🔴 등록 부서이며 실적부서·귀속부서가 아니다 — 부서 목표·실적과 대조하지 않는다.'
  )
  METRICS (
    oc.PREDICTED_ONCE_MEMBERS AS COUNT(DISTINCT oc.ONCE_MBER_NO)
      WITH SYNONYMS ('예측 대상 일시회원수', '일시회원수')
      COMMENT = '예측 대상 일시후원회원수(중복제거). 🔴전체 일시후원회원수가 아니다 — 이 SV 의 모집단이다. 비율을 낼 때 분모로 쓰고 그 사실을 밝힌다.',
    oc.MODEL_CONVERT_MEMBERS AS COUNT(DISTINCT CASE WHEN oc.CONVERT_CLASS = '1' THEN oc.ONCE_MBER_NO END)
      WITH SYNONYMS ('모델 전환분류 회원수', '전환 예측 회원수')
      COMMENT = '모델이 정기후원 전환으로 분류한 일시회원수(중복제거 · 예측행 중 하나라도 전환이면 포함). 🔴실제 전환 회원수가 아니다.',
    oc.AVG_CONVERT_PROB AS AVG(oc.CONVERT_PROB)
      WITH SYNONYMS ('평균 전환확률', '전환확률')
      COMMENT = '정기후원 전환 예측확률 평균(0~1). 🔴합산하지 않는다. 🔴회원당 다중 예측행이 섞인 행 가중 평균이다.',
    oc.MAX_CONVERT_PROB AS MAX(oc.CONVERT_PROB)
      WITH SYNONYMS ('최대 전환확률')
      COMMENT = '전환확률 최대값. 전환 가능성 상위 회원 정렬에 쓴다.'
  )
  COMMENT = 'ML 일시후원회원 정기후원 전환 예측 SV. base=SERVING.ML_ONCE_CONVERSION_V. 🔴🔴 원천이 같은 기준월에 회원당 **여러 개의 서로 다른 예측행**을 담고 있다 — 원천에 **실행 시각·실행순번 컬럼이 없어 어느 행이 최신인지 판별할 수 없다**(현업 결정 45 의 「최신만 남기고 실행순번 추가」는 집행 불가 ⇒ **현행 유지로 확정** · DEC-59 #1). 따라서 행 수 기반 수치와 **확률 평균은 여러 실행이 섞인 값**이다 — 회원 수는 반드시 중복제거 지표로 답하고 그 사실을 밝힌다. 🔴🔴 예측치이며 실적이 아니다 — 실제 정기 전환 실적과 같은 표에 합산하지 않는다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴 **STDR_MT 는 모델 실행 기준월이다** — 2026-10-02 원천 교체로 종전의 관측월·가입월·가입경과월 축은 폐기됐다. 기준월 미지정 시 최신 기준월 하나로 한정한다. 🔴 예측 지평(몇 개월 안에 전환)을 숫자로 발행하지 않는다 — 원천 테이블 설명은 6개월이나 원천 프로시저가 인도되지 않아 정의를 확인할 수 없다. 🔴 일시회원번호는 정기회원번호와 체계가 달라 다른 회원 SV 와 조인하지 않는다. 🔴 업무 판정선은 미확정이다. 활성: 예측 대상 일시회원수·모델 전환분류 회원수·전환확률 평균/최대 · 기준월/판정 축 · 성별·회원구분·등록부서(현재 마스터 스냅샷). 비활성: 가입월·관측월·가입경과월 축(원천 교체로 폐기) · 실제 전환 실적 대비 정확도 · 가입경로 축 · 전환 후 약정금액.'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **예측과 실적을 한 표에 합산하지 않는다.** (2) 🔴 **기준월(STDR_MT)을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월(MAX(STDR_MT)) 하나로 한정하고 그 기준월을 밝힌다. (3) 🔴🔴 **회원수는 PREDICTED_ONCE_MEMBERS·MODEL_CONVERT_MEMBERS(중복제거)를 쓴다** — 원천에 회원당 여러 예측행이 있어 COUNT(*) 는 과대다. (4) 🔴 **가입월·관측월·가입 후 경과월별 분해를 물으면 SQL 을 만들지 않는다** — 원천 구조 교체로 해당 축이 없다고 답하고, 성별·회원구분·등록부서별 분해를 대안으로 안내한다. (5) 🔴 **「전환할 회원」이라 단정하지 않는다** — 「모델이 전환으로 분류한 회원」으로 표현하고, 사용자가 확률 기준을 지정하면 그 기준을 밝힌다. (6) 🔴 **예측 지평(몇 개월 안에)을 숫자로 답하지 않는다.** (7) **확률은 평균·최대만 쓴다.** 평균은 다중 예측행이 섞인 값임을 밝힌다. (8) **비율의 분모는 PREDICTED_ONCE_MEMBERS 이며 전체 일시후원회원이 아님을 밝힌다.** (9) **답변에 예측치임과 테스트 단계임을 밝힌다.** (10) 적용 조건(기간·그룹 미지정 시): 최신 기준월로 한정해 예측 대상 일시회원수·모델 전환분류 회원수·평균 전환확률을 반환하고, 회원구분·등록부서별 분해가 가능함을 안내한다. (11) 🔴 metric 이름(MODEL_CONVERT_MEMBERS·PREDICTED_ONCE_MEMBERS·AVG_CONVERT_PROB)을 oc 컬럼처럼 참조하지 않는다 — 정의식(COUNT(DISTINCT CASE WHEN oc.CONVERT_CLASS = ''1'' THEN oc.ONCE_MBER_NO END) 등)으로 집계한다.'
  AI_VERIFIED_QUERIES (
    vqr_o198_once_member_div AS (
      QUESTION '회원구분별 모델 전환분류 회원수와 예측 대상 일시회원수, 평균 전환확률(최신 기준월)'
      VERIFIED_BY '(DW = O198)'
      SQL 'SELECT oc.MEMBER_DIV_NAME, COUNT(DISTINCT CASE WHEN oc.CONVERT_CLASS = ''1'' THEN oc.ONCE_MBER_NO END) AS MODEL_CONVERT_MEMBERS, COUNT(DISTINCT oc.ONCE_MBER_NO) AS PREDICTED_ONCE_MEMBERS, AVG(oc.CONVERT_PROB) AS AVG_CONVERT_PROB FROM oc WHERE oc.STDR_MT = (SELECT MAX(oc.STDR_MT) FROM oc) GROUP BY oc.MEMBER_DIV_NAME ORDER BY PREDICTED_ONCE_MEMBERS DESC'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_ONCE_CONVERSION TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_ONCE_CONVERSION TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_ONCE_CONVERSION TO ROLE GN_DW_SERVICE;
