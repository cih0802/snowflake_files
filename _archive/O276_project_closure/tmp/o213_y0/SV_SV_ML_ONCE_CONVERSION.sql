create or replace semantic view SV_ML_ONCE_CONVERSION
	tables (
		OC as GN_DW.SERVING.ML_ONCE_CONVERSION_V primary key (STDR_MT,ONCE_MBER_NO) with synonyms=('정기전환 예측','일시후원 전환 예측','정기후원 전환 가능성','일시회원 전환') comment='일시후원회원의 정기후원 전환 ML 예측 분석 (base: SERVING.ML_ONCE_CONVERSION_V). [Grain: 기준월 × 일시후원회원(원천 다중 예측행 포함)]. [활성 지표: 전환확률·모델 전환분류 회원수]. [주의: 예측치이며 실적 아님, 회원당 여러 예측행]. [원천: ML 전환예측 결과 → SERVING.ML_ONCE_CONVERSION_V].'
	)
	dimensions (
		OC.STDR_MT as oc.STDR_MT with synonyms=('기준월','예측 기준월','모델 실행월') comment='모델 실행 기준월(YYYYMM 문자열). 다른 ML SV 와 같은 의미다(2026-10-02 원천 교체로 종전 「관측월」 해석은 폐기). 🔴 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
		OC.STDR_MONTH_KEY as oc.STDR_MONTH_KEY with synonyms=('기준연월') comment='기준연월(YYYYMM 정수). 연·월 필터에 쓴다.',
		OC.ONCE_MBER_NO as oc.ONCE_MBER_NO with synonyms=('일시후원회원번호','일시회원번호','일시회원') comment='일시후원회원번호. 🔴정기회원 회원번호(MBER_NO)와 다른 번호체계다 — 다른 회원 SV 와 조인·대조하지 않는다. 회원수는 이 축의 중복제거로 센다.',
		OC.CONVERT_CLASS as oc.CONVERT_CLASS with synonyms=('전환 예측 판정','전환 클래스') comment='정기후원 전환 예측의 모델 기본 판정. 실제값 2종: ''0''(비전환 예측)·''1''(전환 예측). 🔴모델 기본 임계(0.5)의 판정이며 업무 판정선은 미확정이다 ⇒ 「전환할 회원」이라 단정하지 말고 「모델이 전환으로 분류한 회원」으로 답한다.',
		OC.PREDICTION_HAS_ERROR as oc.PREDICTION_HAS_ERROR with synonyms=('예측 오류 여부') comment='TRUE=모델 산출 로그에 오류가 기록됐다. 품질 점검용.',
		OC.SEX_NAME as oc.SEX_NAME with synonyms=('성별','일시회원 성별') comment='일시회원 성별 라벨(코드사전 CM013 — 내국/외국인 구분 포함). 🔴 현재 회원 마스터 값이며 가입 시점 값이 아니다. 라벨이 없는 회원은 NULL.',
		OC.MEMBER_DIV_NAME as oc.MEMBER_DIV_NAME with synonyms=('회원구분','개인/단체','일시회원 구분') comment='일시회원 회원구분 라벨(개인·단체·기업 등). 🔴 현재 회원 마스터 값이다. 값 목록은 SELECT DISTINCT 로 조회한다.',
		OC.REGIST_DEPT_NAME as oc.REGIST_DEPT_NAME with synonyms=('등록부서','일시회원 등록부서','부서') comment='일시회원을 등록한 부서명(조직 차원 DEPARTMENT). 🔴 등록 부서이며 실적부서·귀속부서가 아니다 — 부서 목표·실적과 대조하지 않는다.'
	)
	metrics (
		OC.PREDICTED_ONCE_MEMBERS as COUNT(DISTINCT oc.ONCE_MBER_NO) with synonyms=('예측 대상 일시회원수','일시회원수') comment='예측 대상 일시후원회원수(중복제거). 🔴전체 일시후원회원수가 아니다 — 이 SV 의 모집단이다. 비율을 낼 때 분모로 쓰고 그 사실을 밝힌다.',
		OC.MODEL_CONVERT_MEMBERS as COUNT(DISTINCT CASE WHEN oc.CONVERT_CLASS = '1' THEN oc.ONCE_MBER_NO END) with synonyms=('모델 전환분류 회원수','전환 예측 회원수') comment='모델이 정기후원 전환으로 분류한 일시회원수(중복제거 · 예측행 중 하나라도 전환이면 포함). 🔴실제 전환 회원수가 아니다.',
		OC.AVG_CONVERT_PROB as AVG(oc.CONVERT_PROB) with synonyms=('평균 전환확률','전환확률') comment='정기후원 전환 예측확률 평균(0~1). 🔴합산하지 않는다. 🔴회원당 다중 예측행이 섞인 행 가중 평균이다.',
		OC.MAX_CONVERT_PROB as MAX(oc.CONVERT_PROB) with synonyms=('최대 전환확률') comment='전환확률 최대값. 전환 가능성 상위 회원 정렬에 쓴다.'
	)
	comment='ML 일시후원회원 정기후원 전환 예측 SV. base=SERVING.ML_ONCE_CONVERSION_V. 🔴🔴 원천이 같은 기준월에 회원당 **여러 개의 서로 다른 예측행**을 담고 있다 — 원천에 **실행 시각·실행순번 컬럼이 없어 어느 행이 최신인지 판별할 수 없다**(현업 결정 45 의 「최신만 남기고 실행순번 추가」는 집행 불가 ⇒ **현행 유지로 확정** · DEC-59 #1). 따라서 행 수 기반 수치와 **확률 평균은 여러 실행이 섞인 값**이다 — 회원 수는 반드시 중복제거 지표로 답하고 그 사실을 밝힌다. 🔴🔴 예측치이며 실적이 아니다 — 실제 정기 전환 실적과 같은 표에 합산하지 않는다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴 **STDR_MT 는 모델 실행 기준월이다** — 2026-10-02 원천 교체로 종전의 관측월·가입월·가입경과월 축은 폐기됐다. 기준월 미지정 시 최신 기준월 하나로 한정한다. 🔴 예측 지평(몇 개월 안에 전환)을 숫자로 발행하지 않는다 — 원천 테이블 설명은 6개월이나 원천 프로시저가 인도되지 않아 정의를 확인할 수 없다. 🔴 일시회원번호는 정기회원번호와 체계가 달라 다른 회원 SV 와 조인하지 않는다. 🔴 업무 판정선은 미확정이다. 활성: 예측 대상 일시회원수·모델 전환분류 회원수·전환확률 평균/최대 · 기준월/판정 축 · 성별·회원구분·등록부서(현재 마스터 스냅샷). 비활성: 가입월·관측월·가입경과월 축(원천 교체로 폐기) · 실제 전환 실적 대비 정확도 · 가입경로 축 · 전환 후 약정금액.'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **예측과 실적을 한 표에 합산하지 않는다.** (2) 🔴 **기준월(STDR_MT)을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월(MAX(STDR_MT)) 하나로 한정하고 그 기준월을 밝힌다. (3) 🔴🔴 **회원수는 PREDICTED_ONCE_MEMBERS·MODEL_CONVERT_MEMBERS(중복제거)를 쓴다** — 원천에 회원당 여러 예측행이 있어 COUNT(*) 는 과대다. (4) 🔴 **가입월·관측월·가입 후 경과월별 분해를 물으면 SQL 을 만들지 않는다** — 원천 구조 교체로 해당 축이 없다고 답하고, 성별·회원구분·등록부서별 분해를 대안으로 안내한다. (5) 🔴 **「전환할 회원」이라 단정하지 않는다** — 「모델이 전환으로 분류한 회원」으로 표현하고, 사용자가 확률 기준을 지정하면 그 기준을 밝힌다. (6) 🔴 **예측 지평(몇 개월 안에)을 숫자로 답하지 않는다.** (7) **확률은 평균·최대만 쓴다.** 평균은 다중 예측행이 섞인 값임을 밝힌다. (8) **비율의 분모는 PREDICTED_ONCE_MEMBERS 이며 전체 일시후원회원이 아님을 밝힌다.** (9) **답변에 예측치임과 테스트 단계임을 밝힌다.** (10) 적용 조건(기간·그룹 미지정 시): 최신 기준월로 한정해 예측 대상 일시회원수·모델 전환분류 회원수·평균 전환확률을 반환하고, 회원구분·등록부서별 분해가 가능함을 안내한다. (11) 🔴 metric 이름(MODEL_CONVERT_MEMBERS·PREDICTED_ONCE_MEMBERS·AVG_CONVERT_PROB)을 oc 컬럼처럼 참조하지 않는다 — 정의식(COUNT(DISTINCT CASE WHEN oc.CONVERT_CLASS = ''1'' THEN oc.ONCE_MBER_NO END) 등)으로 집계한다.'
	ai_verified_queries (
		VQR_O198_ONCE_MEMBER_DIV AS ( 
QUESTION '회원구분별 모델 전환분류 회원수와 예측 대상 일시회원수, 평균 전환확률(최신 기준월)' 
VERIFIED_BY '(DW = O198)'
SQL 'SELECT oc.MEMBER_DIV_NAME, COUNT(DISTINCT CASE WHEN oc.CONVERT_CLASS = ''1'' THEN oc.ONCE_MBER_NO END) AS MODEL_CONVERT_MEMBERS, COUNT(DISTINCT oc.ONCE_MBER_NO) AS PREDICTED_ONCE_MEMBERS, AVG(oc.CONVERT_PROB) AS AVG_CONVERT_PROB FROM oc WHERE oc.STDR_MT = (SELECT MAX(oc.STDR_MT) FROM oc) GROUP BY oc.MEMBER_DIV_NAME ORDER BY PREDICTED_ONCE_MEMBERS DESC')
	);