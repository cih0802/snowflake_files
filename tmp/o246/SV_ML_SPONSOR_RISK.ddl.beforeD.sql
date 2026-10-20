create or replace semantic view SV_ML_SPONSOR_RISK
	tables (
		SR as GN_DW.SERVING.ML_SPONSOR_RISK_V primary key (STDR_MT,MBER_NO,SPNSR_BSNS_ID,SPNSR_BSNS_NO) with synonyms=('후원건 이탈 예측','카테고리별 이탈 예측','후원 이탈') comment='후원계좌 단위 이탈 예측 분석 (base: SERVING.ML_SPONSOR_RISK_V). [Grain: 기준월 × 회원 × 후원사업 × 약정번호]. [활성 지표: 후원계좌 이탈확률]. [주의: 1회원 다수 약정 보유(회원수는 COUNT DISTINCT 집계)]. [원천: ML 이탈모델 → SERVING.ML_SPONSOR_RISK_V].',
		MA as GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V primary key (STDR_MT,MBER_NO) with synonyms=('회원 특성','예측 회원 특성','기준월 시점 회원 속성') comment='예측 대상 회원의 기준월 말 시점 특성(성별·연령대·지역·회원상태·회원구분·후원금액대·유지기간대·신규기존·납입방식). grain = 기준월 × 회원. 🔴 모델 피처가 아니다 — 예측 결과를 특성으로 나눠 보는 집계용이다. 미매칭 = (미매칭).'
	)
	relationships (
		SR_TO_MEMBER_ATTR as SR(STDR_MT,MBER_NO) references MA(STDR_MT,MBER_NO)
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
		SR.PREDICTION_HAS_ERROR as sr.PREDICTION_HAS_ERROR with synonyms=('예측 오류 여부') comment='TRUE=모델 산출 로그에 오류가 기록됐다.',
		MA.GENDER_NAME as ma.GENDER_NAME with synonyms=('성별','남녀') comment='성별(기준월 말 시점). 🔴 모델 피처가 아니다.',
		MA.AGE_BAND as ma.AGE_BAND with synonyms=('연령대','나이대') comment='연령대(기준월 말 시점). 값에 기업·단체·기타가 섞여 있다 — 개인 연령 분석은 회원구분 개인으로 거른다.',
		MA.REGION as ma.REGION with synonyms=('지역','거주지역','시도') comment='지역(기준월 말 시점).',
		MA.MEMBER_STATUS_NAME as ma.MEMBER_STATUS_NAME with synonyms=('회원상태') comment='회원상태(기준월 말 시점).',
		MA.MEMBER_TYPE_NAME as ma.MEMBER_TYPE_NAME with synonyms=('회원구분','개인 기업 단체') comment='회원구분 = 개인·기업·단체(기준월 말 시점). 🔴 법인구분(통합·사단·사복)은 CPR_DIV_NAME 이다(O245).',
		MA.AMOUNT_BAND as ma.AMOUNT_BAND with synonyms=('후원금액대','금액대') comment='후원금액대(그 달 회원 월실적 금액대1).',
		MA.TENURE_BAND as ma.TENURE_BAND with synonyms=('유지기간','가입기간','후원기간대') comment='유지기간대(그 달 회원 월실적 기간대1).',
		MA.NEW_EXISTING as ma.NEW_EXISTING with synonyms=('신규기존','신규 기존 구분') comment='신규/기존(그 달 회원 월실적).',
		MA.PAYMENT_METHOD_NAME as ma.PAYMENT_METHOD_NAME with synonyms=('납입방식','결제수단') comment='납입방식(그 달 청구액이 가장 큰 결제수단 · 잠정).',
		MA.ATTR_MATCHED as ma.ATTR_MATCHED with synonyms=('특성 매칭 여부') comment='TRUE=기준월 시점 회원 이력이 매칭됐다. FALSE 회원은 특성이 (미매칭)이다.',
		MA.REGIST_DEPT_NAME as ma.REGIST_DEPT_NAME with synonyms=('등록부서','회원 등록부서') comment='🆕 [O245] 회원 등록부서명(CRM 회원 마스터 현재 값). 🔴 실적부서·귀속부서가 아니다 — 부서 목표·실적과 대조하지 않는다.',
		MA.CPR_DIV_NAME as ma.CPR_DIV_NAME with synonyms=('법인구분','사단 사복 통합') comment='🆕 [O245] 회원 법인구분(코드사전 CM019 · 통합·사단·사복 · CRM 회원 마스터 현재 값). 개인·기업·단체 구분은 MEMBER_TYPE_NAME 이다.',
		MA.MEMBER_ACTIVE_SPNSR_CNT as ma.ACTIVE_SPNSR_CNT with synonyms=('활동 약정 수','회원 활동 약정 수','후원 중인 약정 수') comment='🆕 [O245] 그 회원의 기준월 말 활동 중인 후원약정 수(건 · 카테고리·후원사업 무관 전체). 0 = 활동 약정 없음. 회원당 1개 값이다 — 구간으로 나눠 GROUP BY 하거나 그대로 출력하고 SUM 하지 않는다.'
	)
	metrics (
		SR.PREDICTED_SPONSORSHIPS as COUNT(*) with synonyms=('예측 대상 후원건수','후원건수') comment='예측 대상 후원건수. grain 이 후원건이므로 행수가 곧 건수다.',
		SR.PREDICTED_MEMBERS as COUNT(DISTINCT sr.MBER_NO) with synonyms=('예측 대상 회원수','회원수') comment='예측 대상 회원수(중복제거). 🔴후원건수와 다르다 — 「명」을 물으면 이 지표를 쓴다.',
		SR.MODEL_CHURN_SPONSORSHIPS as COUNT_IF(sr.CHURN_CLASS = '1') with synonyms=('모델 이탈분류 후원건수') comment='모델이 이탈로 분류한 후원건수. 업무 위험 건수가 아니다.',
		SR.MODEL_CHURN_MEMBERS as COUNT(DISTINCT CASE WHEN sr.CHURN_CLASS = '1' THEN sr.MBER_NO END) with synonyms=('모델 이탈분류 회원수') comment='이탈로 분류된 후원건을 가진 회원수(중복제거).',
		SR.AVG_CHURN_PROB as AVG(sr.CHURN_PROB) with synonyms=('평균 이탈확률','이탈확률') comment='이탈 예측확률 평균(0~1). 합산 금지. 🔴후원건 가중 평균이며 회원 가중이 아니다.',
		SR.MAX_CHURN_PROB as MAX(sr.CHURN_PROB) with synonyms=('최대 이탈확률') comment='이탈확률 최대값. 상위 위험 후원건 정렬에 쓴다.'
	)
	comment='ML 후원건단위 이탈 예측 SV. base=SERVING.ML_SPONSOR_RISK_V. 🔴🔴 예측치이며 실적이 아니다 — 실적 SV 와 합산 금지. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다(2026-10-02 원천 구조 교체로 캠페인·상위캠페인·결제수단·후원금액·피처 축이 사라졌다). 🔴 **grain 이 후원건이다** — 회원 단위 질문에는 반드시 중복제거 회원수를 쓴다. 회원단위 예측(SV_ML_MEMBER_RISK)과 이 SV 를 조인해 한 표로 만들지 않는다(회원당 후원건 다건이라 회원 지표가 과대계상된다). 🔴 예측 지평은 발행하지 않는다(원천 기간 표기 확인 전). 활성: 후원건수·회원수·모델 분류 건수/회원수·확률 평균/최대 · 후원사업·캠페인카테고리·판정·등급 축. 비활성: 캠페인·상위캠페인(채널) 축 · 이탈분류 후원금액(원천 금액 컬럼 제거) · 업무 위험 임계값(미확정). 🆕 [O245] 활성: 납입방식·등록부서·법인구분·활동 약정 수(ma · 회원 특성 · 모델 피처 아님).'
	ai_sql_generation '[O241-M · O245 회원 특성 축] 성별·연령대·지역·회원상태·회원구분·법인구분(통합·사단·사복)·등록부서·활동 약정 수·후원금액대·유지기간·신규기존·납입방식으로 나눠 달라는 질문은 ma 테이블 차원으로 GROUP BY 한다(기준월 말 시점 · 모델 피처 아님). 회원수는 반드시 예측 테이블 회원번호의 COUNT(DISTINCT) 로 센다. (미매칭) 행은 따로 밝힌다. 🆕 [O245] ROLLUP 합계 행에는 COALESCE(차원, (미매칭)) 를 씌우지 않는다 — CASE WHEN GROUPING(차원) = 1 THEN 전체 합계 WHEN 차원 IS NULL THEN (미매칭) ELSE 차원 END 로 구분한다. [O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **예측과 실적을 합산하지 않는다.** (2) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (3) 🔴🔴 **「명」과 「건」을 구분한다** — grain 이 후원건이므로 회원수는 PREDICTED_MEMBERS·MODEL_CHURN_MEMBERS(중복제거)를 쓰고, 건수는 PREDICTED_SPONSORSHIPS·MODEL_CHURN_SPONSORSHIPS 를 쓴다. 회원수를 COUNT(*) 로 세면 과대다. (4) 🔴 **SV_ML_MEMBER_RISK 와 한 쿼리로 조인하지 않는다** — grain 이 달라 팬아웃이 난다. 둘 다 필요하면 표를 분리하고 각 표의 grain 을 명시한다. (5) 🔴 **「위험」·「이탈할 것이다」로 단정하지 않는다** — 업무 임계값 미확정이므로 「모델이 이탈로 분류」로 표현한다. (6) 🔴 **캠페인별·상위캠페인(채널)별 이탈 예측이나 이탈분류 후원금액을 물으면 SQL 을 만들지 않는다**(납입방식·결제수단별은 ma.PAYMENT_METHOD_NAME 으로 답한다 · O245) — 원천 구조 교체로 해당 축·금액이 없다고 답하고, 캠페인카테고리별 분해를 대안으로 안내한다. (7) 🔴 **예측 지평을 숫자로 답하지 않는다**(원천 확인 중). (8) **확률은 평균·최대만 쓴다.** 평균은 후원건 가중임을 밝힌다. (9) **답변에 예측치임과 테스트 단계임을 밝힌다.** (10) 적용 조건(기준월·그룹 미지정 시): 최신 기준월로 한정하고 캠페인카테고리(CMPGN_CTGR_NAME)별 후원건수·모델 이탈분류 건수·평균 이탈확률을 반환한다. (11) 🔴 metric 이름(PREDICTED_MEMBERS·MODEL_CHURN_MEMBERS·PREDICTED_SPONSORSHIPS·MODEL_CHURN_SPONSORSHIPS 등)을 sr 컬럼처럼 참조하지 않는다 — 정의식(COUNT(DISTINCT CASE WHEN sr.CHURN_CLASS = ''1'' THEN sr.MBER_NO END) 등)으로 집계한다.';