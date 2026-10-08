create or replace semantic view SV_SPNSR_CLS_AGGR
	tables (
		SC as GN_DW.GOLD.WIDE_SPNSR_CLS_AGGR primary key (MONTH_KEY,AGGR_TY_NM,CPR_NM,SPNSR_BSNS_GRP_NM,NEW_EXST_DIV_NM,HDQ_BRNCH_GRP_NM) with synonyms=('후원 분류별 집계','회비예측 분류 집계','후원분류 예측값') comment='회원실 회비예측 월간 후원 분류별 집계 (base: GOLD.WIDE_SPNSR_CLS_AGGR). [Grain: 월 × 집계유형 × 법인 × 후원사업그룹 × 신규기존 × 본부지부그룹]. [활성 지표: 예측값1/예측값2]. [주의: 집계유형 간 합산 금지, 부서 자체 수식이며 ML 예측 아님]. [원천: 회원실 집계 → SILVER.MM_SPNSR_CLS_AGGR_DATA].'
	)
	dimensions (
		SC.MONTH_KEY as sc.MONTH_KEY with synonyms=('기준월','연월') comment='기준월 YYYYMM(정수).',
		SC.CAL_YEAR as sc.CAL_YEAR with synonyms=('연도') comment='연도.',
		SC.CAL_MONTH as sc.CAL_MONTH with synonyms=('월') comment='월(1~12).',
		SC.AGGR_TY_NM as sc.AGGR_TY_NM with synonyms=('집계유형','분류','후원분류') comment='집계 유형명(감액/개발/중단/활동/회비). 🔴 반드시 WHERE 로 고정하거나 GROUP BY 에 넣는다.',
		SC.CPR_NM as sc.CPR_NM with synonyms=('법인','법인명') comment='법인명.',
		SC.SPNSR_BSNS_GRP_NM as sc.SPNSR_BSNS_GRP_NM with synonyms=('후원사업그룹','후원사업') comment='후원 사업 그룹 명.',
		SC.NEW_EXST_DIV_NM as sc.NEW_EXST_DIV_NM with synonyms=('신규기존','신규/기존') comment='신규기존구분명.',
		SC.HDQ_BRNCH_GRP_NM as sc.HDQ_BRNCH_GRP_NM with synonyms=('본부지부','본부/지부') comment='본부 지부 그룹 명(회원실 집계 기준).'
	)
	metrics (
		SC.TOTAL_VALUE1 as SUM(sc.VALUE1) with synonyms=('예측값1','후원분류집계 예측값1') comment='후원분류집계 예측값1 합계. 🔴 집계유형 하나로 고정해서만 쓴다(유형마다 값의 척도가 다르다 · 단위는 원천 미기재).',
		SC.TOTAL_VALUE2 as SUM(sc.VALUE2) with synonyms=('예측값2','후원분류집계 예측값2') comment='후원분류집계 예측값2 합계. ⚠️회비 유형에만 값이 있고 나머지 유형은 NULL 이다(0 이 아니다).'
	)
	comment='회원실 회비예측 월간 후원 분류별 집계 SV. base=GOLD.WIDE_SPNSR_CLS_AGGR. 🔴🔴 **AGGR_TY_NM(감액/개발/중단/활동/회비)을 고정하거나 그룹에 넣는다** — 유형마다 값의 단위·뜻이 달라 섞어 합하면 의미가 없다. 🔴🔴 부서 자체 수식이며 ML 예측이 아니다 — ML 예측 SV 와 같은 표에 합산하지 않는다. ⚠️ 예측값2 는 회비 유형에만 있다. 활성: 예측값1·예측값2 · 월/집계유형/법인/후원사업그룹/신규기존/본부지부 축. 비활성: 예측값1·2 의 산식 설명(원천 정의만 제공).'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **AGGR_TY_NM 을 WHERE 로 하나 고정하거나 GROUP BY 에 넣는다.** 유형을 섞어 합하지 않는다. (2) 🔴 **단위를 단정하지 않는다** — 원천에 단위가 기재되지 않았다. 원·건 같은 단위를 붙이지 말고 「예측값」으로 표기한다. (3) 🔴 **예측값1·예측값2 의 산식을 추정해 설명하지 않는다** — 「회원실 후원분류집계 예측값1/2」로만 부른다. (4) 🔴 **예측값2 가 NULL 인 유형을 0 으로 답하지 않는다** — 그 유형에는 값이 없다고 밝힌다. (5) 🔴 **ML 예측과 섞지 않는다.** (6) **기준월 미지정 시 데이터에 존재하는 최신 기준월로 한정하고 밝힌다.** (7) 적용 조건(그룹 미지정 시): 최신 기준월로 한정해 집계유형별 예측값1·예측값2 를 반환한다. (8) 🔴 metric 이름을 sc 컬럼처럼 참조하지 않는다 — 정의식(SUM(sc.VALUE1) 등)으로 집계한다.';