create or replace semantic view SV_DVLP_GOAL_ACMSLT
	tables (
		GA as GN_DW.GOLD.WIDE_DVLP_GOAL_ACMSLT primary key (MONTH_KEY,DEPT_DIV_NM,NEW_EXST_DIV_NM,SPNSR_BSNS_GRP_NM) with synonyms=('개발 목표','개발 실적','목표 대비 실적','개발 달성률','기획실 개발 목표') comment='기획실 연간 개발 목표·실적 부서 집계 (base: GOLD.WIDE_DVLP_GOAL_ACMSLT). [Grain: 월 × 부서구분 × 신규기존 × 후원사업그룹]. [활성 지표: 목표건수/실적건수/달성률]. [주의: 부서 자체 수식 집계이며 ML 예측 아님, 미도래 월 실적은 NULL]. [원천: 기획실 집계 → SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA].'
	)
	dimensions (
		GA.MONTH_KEY as ga.MONTH_KEY with synonyms=('기준월','연월') comment='기준월 YYYYMM(정수).',
		GA.CAL_YEAR as ga.CAL_YEAR with synonyms=('연도','사업연도') comment='연도. 🔴 실제값은 열거하지 않는다 — 조회해서 확인한다.',
		GA.CAL_MONTH as ga.CAL_MONTH with synonyms=('월') comment='월(1~12).',
		GA.DEPT_DIV_NM as ga.DEPT_DIV_NM with synonyms=('부서','부서구분') comment='부서 구분 명(기획실 집계 기준 · DIM_ORG 부서와 같은 조직으로 단정하지 않는다).',
		GA.NEW_EXST_DIV_NM as ga.NEW_EXST_DIV_NM with synonyms=('신규기존','신규/기존') comment='신규기존구분명.',
		GA.SPNSR_BSNS_GRP_NM as ga.SPNSR_BSNS_GRP_NM with synonyms=('후원사업그룹','후원사업') comment='후원 사업 그룹 명.'
	)
	metrics (
		GA.TOTAL_GOAL_CNT as SUM(ga.GOAL_CNT) with synonyms=('목표 건수','개발 목표 건수') comment='개발 목표 건수 합계(건).',
		GA.TOTAL_ACMSLT_CNT as SUM(ga.ACMSLT_CNT) with synonyms=('실적 건수','개발 실적 건수') comment='개발 실적 건수 합계(건). 미도래 월은 NULL 이라 합계에서 빠진다.',
		GA.GOAL_TO_DATE_CNT as SUM(CASE WHEN ga.ACMSLT_CNT IS NOT NULL THEN ga.GOAL_CNT END) with synonyms=('실적월 목표 건수','누적 목표') comment='실적이 있는 월에 한정한 목표 건수 합계(건) — 달성률의 분모.',
		GA.ACMSLT_RATE as SUM(ga.ACMSLT_CNT) / NULLIF(SUM(CASE WHEN ga.ACMSLT_CNT IS NOT NULL THEN ga.GOAL_CNT END), 0) with synonyms=('달성률','목표 달성률') comment='[비가산] 달성률 = 실적 ÷ 실적이 있는 월의 목표. 연간 목표 대비 진척률은 TOTAL_ACMSLT_CNT ÷ TOTAL_GOAL_CNT 로 따로 계산한다.'
	)
	comment='기획실 연간 개발 목표·실적 SV. base=GOLD.WIDE_DVLP_GOAL_ACMSLT. 🔴🔴 부서 자체 수식 집계이며 ML 예측이 아니다 — ML 개발금액 예측(SV_ML_DVLP_FORECAST · 만원)과 같은 표에 합산하지 않는다. 🔴 단위는 건이다(금액 아님). 🔴 미도래 월의 실적은 NULL 이며 0 이 아니다. ⚠️ 부서구분은 기획실 집계 기준이며 GN_DW 조직 차원과 같은 조직이라 단정하지 않는다. 활성: 목표·실적·달성률 · 월/부서구분/신규기존/후원사업그룹 축. 비활성: 금액 목표(원천 부재) · 본부·지부 분해(원천 축 부재).'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **달성률을 물으면 ACMSLT_RATE 정의식(실적 ÷ 실적이 있는 월의 목표)을 쓴다** — 연간 목표 전체를 분모로 쓰면 미도래 월 때문에 과소가 된다. 연간 진척률을 물으면 두 값을 구분해 함께 밝힌다. (2) 🔴 **미도래 월 실적을 0 으로 채우지 않는다** — NULL 이다. (3) 🔴 **단위는 건이다** — 금액 지표나 ML 개발금액 예측(만원)과 합산하지 않는다. (4) 🔴 **ML 예측치와 섞지 않는다** — 이 SV 는 부서 자체 집계다. (5) **연도 미지정 시 데이터에 존재하는 최신 연도로 한정하고 밝힌다.** (6) 🔴 **본부·지부별 분해를 물으면 SQL 을 만들지 않는다** — 축이 없다고 답하고 부서구분·후원사업그룹별 분해를 안내한다. (7) 적용 조건(그룹 미지정 시): 최신 연도로 한정해 월별 목표·실적·달성률을 반환한다. (8) 🔴 metric 이름을 ga 컬럼처럼 참조하지 않는다 — 정의식(SUM(ga.ACMSLT_CNT) 등)으로 집계한다.';