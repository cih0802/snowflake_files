create or replace semantic view SV_ML_SPONSOR_RISK
	tables (
		SR as GN_DW.SERVING.ML_SPONSOR_RISK_V primary key (STDR_MT,MBER_NO,SPNSR_BSNS_ID,SPNSR_BSNS_NO) with synonyms=('후원건 이탈 예측','카테고리별 이탈 예측','후원 이탈') comment='후원계좌 단위 이탈 예측 분석 (base: SERVING.ML_SPONSOR_RISK_V). [Grain: 기준월 × 회원 × 후원사업 × 약정번호]. [활성 지표: 후원계좌 이탈확률]. [주의: 1회원 다수 약정 보유(회원수는 COUNT DISTINCT 집계)]. [원천: ML 이탈모델 → SERVING.ML_SPONSOR_RISK_V].'
	)
	dimensions (
		SR.STDR_MT as sr.STDR_MT with synonyms=('기준월','예측 기준월') comment='모델 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
		SR.MBER_NO as sr.MBER_NO with synonyms=('회원번호','회원') comment='회원번호. 🔴한 회원이 여러 행에 등장한다.',
		SR.SPNSR_BSNS_ID as sr.SPNSR_BSNS_ID with synonyms=('후원사업ID') comment='degen: 후원사업 ID. 라벨은 SPNSR_BSNS_NAME. 🔴 실제값은 열거하지 않는다 — 후원사업 마스터가 늘어나면 낡기 때문이다. 값 목록은 조회해서 확인한다.',
		SR.SPNSR_BSNS_NAME as sr.SPNSR_BSNS_NAME with synonyms=('후원사업','후원사업명','사업') comment='후원사업명.',
		SR.SPNSR_BSNS_NO as sr.SPNSR_BSNS_NO with synonyms=('후원번호','후원사업번호') comment='degen: 후원건 식별번호. grain 구성 축이다.',
		SR.CMPGN_CTGR_CD as sr.CMPGN_CTGR_CD with synonyms=('캠페인카테고리코드') comment='degen: 캠페인 카테고리 코드(원천 컬럼). 라벨은 CMPGN_CTGR_NAME. 🔴 실제값은 열거하지 않는다 — 값 목록은 SELECT DISTINCT 로 조회한다.',
		SR.CMPGN_CTGR_NAME as sr.CMPGN_CTGR_NAME with synonyms=('캠페인카테고리','캠페인 구분','카테고리') comment='캠페인 카테고리명(캠페인 마스터 DISTINCT · 코드당 1개). 카테고리별 분해의 정본 축이다. 🔴 개별 캠페인·상위캠페인(채널) 축은 원천 구조 교체(2026-10-02)로 이 SV 에 없다.',
		SR.CHURN_CLASS as sr.CHURN_CLASS with synonyms=('이탈 예측 판정') comment='모델 기본 판정. 실제값 2종: ''0''(유지)·''1''(이탈 예측). 🔴업무 위험 판정선은 미확정이다.',
		SR.CHURN_GRADE as sr.CHURN_GRADE with synonyms=('이탈위험 등급','위험 등급','고위험 후원건') comment='F-4 후원건 이탈위험 등급 — 값 3종: ''고위험''·''주의''·''일반''(기준월 안의 후원건 확률 순위 구간 · 경계 정의 = SERVING.ML_SPONSOR_RISK_V). 🔴 순위 기반 · 기준월 1개로 고정한다.',
		SR.PREDICTION_HAS_ERROR as sr.PREDICTION_HAS_ERROR with synonyms=('예측 오류 여부') comment='TRUE=모델 산출 로그에 오류가 기록됐다.'
	)
	metrics (
		SR.PREDICTED_SPONSORSHIPS as COUNT(*) with synonyms=('예측 대상 후원건수','후원건수') comment='예측 대상 후원건수. grain 이 후원건이므로 행수가 곧 건수다.',
		SR.PREDICTED_MEMBERS as COUNT(DISTINCT sr.MBER_NO) with synonyms=('예측 대상 회원수','회원수') comment='예측 대상 회원수(중복제거). 🔴후원건수와 다르다 — 「명」을 물으면 이 지표를 쓴다.',
		SR.MODEL_CHURN_SPONSORSHIPS as COUNT_IF(sr.CHURN_CLASS = '1') with synonyms=('모델 이탈분류 후원건수') comment='모델이 이탈로 분류한 후원건수. 업무 위험 건수가 아니다.',
		SR.MODEL_CHURN_MEMBERS as COUNT(DISTINCT CASE WHEN sr.CHURN_CLASS = '1' THEN sr.MBER_NO END) with synonyms=('모델 이탈분류 회원수') comment='이탈로 분류된 후원건을 가진 회원수(중복제거).',
		SR.AVG_CHURN_PROB as AVG(sr.CHURN_PROB) with synonyms=('평균 이탈확률','이탈확률') comment='이탈 예측확률 평균(0~1). 합산 금지. 🔴후원건 가중 평균이며 회원 가중이 아니다.',
		SR.MAX_CHURN_PROB as MAX(sr.CHURN_PROB) with synonyms=('최대 이탈확률') comment='이탈확률 최대값. 상위 위험 후원건 정렬에 쓴다.'
	)
	comment='ML 후원건단위 이탈 예측 SV. base=SERVING.ML_SPONSOR_RISK_V. 🔴🔴 예측치이며 실적이 아니다 — 실적 SV 와 합산 금지. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다(2026-10-02 원천 구조 교체로 캠페인·상위캠페인·결제수단·후원금액·피처 축이 사라졌다). 🔴 **grain 이 후원건이다** — 회원 단위 질문에는 반드시 중복제거 회원수를 쓴다. 회원단위 예측(SV_ML_MEMBER_RISK)과 이 SV 를 조인해 한 표로 만들지 않는다(회원당 후원건 다건이라 회원 지표가 과대계상된다). 🔴 예측 지평은 발행하지 않는다(원천 기간 표기 확인 전). 활성: 후원건수·회원수·모델 분류 건수/회원수·확률 평균/최대 · 후원사업·캠페인카테고리·판정·등급 축. 비활성: 캠페인·상위캠페인(채널)·결제수단 축 · 이탈분류 후원금액(원천 금액 컬럼 제거) · 업무 위험 임계값(미확정) · 부서 축(원천에 부재).'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **예측과 실적을 합산하지 않는다.** (2) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (3) 🔴🔴 **「명」과 「건」을 구분한다** — grain 이 후원건이므로 회원수는 PREDICTED_MEMBERS·MODEL_CHURN_MEMBERS(중복제거)를 쓰고, 건수는 PREDICTED_SPONSORSHIPS·MODEL_CHURN_SPONSORSHIPS 를 쓴다. 회원수를 COUNT(*) 로 세면 과대다. (4) 🔴 **SV_ML_MEMBER_RISK 와 한 쿼리로 조인하지 않는다** — grain 이 달라 팬아웃이 난다. 둘 다 필요하면 표를 분리하고 각 표의 grain 을 명시한다. (5) 🔴 **「위험」·「이탈할 것이다」로 단정하지 않는다** — 업무 임계값 미확정이므로 「모델이 이탈로 분류」로 표현한다. (6) 🔴 **캠페인별·상위캠페인(채널)별·결제수단별 이탈 예측이나 이탈분류 후원금액을 물으면 SQL 을 만들지 않는다** — 원천 구조 교체로 해당 축·금액이 없다고 답하고, 캠페인카테고리별 분해를 대안으로 안내한다. (7) 🔴 **예측 지평을 숫자로 답하지 않는다**(원천 확인 중). (8) **확률은 평균·최대만 쓴다.** 평균은 후원건 가중임을 밝힌다. (9) **답변에 예측치임과 테스트 단계임을 밝힌다.** (10) 적용 조건(기준월·그룹 미지정 시): 최신 기준월로 한정하고 캠페인카테고리(CMPGN_CTGR_NAME)별 후원건수·모델 이탈분류 건수·평균 이탈확률을 반환한다. (11) 🔴 metric 이름(PREDICTED_MEMBERS·MODEL_CHURN_MEMBERS·PREDICTED_SPONSORSHIPS·MODEL_CHURN_SPONSORSHIPS 등)을 sr 컬럼처럼 참조하지 않는다 — 정의식(COUNT(DISTINCT CASE WHEN sr.CHURN_CLASS = ''1'' THEN sr.MBER_NO END) 등)으로 집계한다.';