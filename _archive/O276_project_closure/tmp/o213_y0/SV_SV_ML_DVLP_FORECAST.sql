create or replace semantic view SV_ML_DVLP_FORECAST
	tables (
		DF as GN_DW.SERVING.ML_DVLP_FORECAST_V primary key (STDR_MT,SERIES_TYPE,SERIES_CD,TS) with synonyms=('개발 예측','개발금액 예측','개발액 예측','연도말 개발 예측') comment='개발금액 시계열 예측 2계열 분석 (base: SERVING.ML_DVLP_FORECAST_V). [Grain: 기준월 × 계열유형 × 계열 × 예측월]. [활성 지표: 예측 개발금액(만원)]. [주의: 단위=만원, 계열유형 간 단순 합산 금지(독립 예측), 부서·후원사업·신규기존 예측은 원천 삭제로 미제공]. [원천: ML 시계열모델 2종 → SERVING.ML_DVLP_FORECAST_V].'
	)
	dimensions (
		DF.STDR_MT as df.STDR_MT with synonyms=('기준월','예측 기준월','모델 실행월') comment='모델 실행 기준월(YYYYMM). 🔴여러 기준월을 합산하면 같은 예측월이 중복계상된다. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
		DF.SERIES_TYPE as df.SERIES_TYPE with synonyms=('계열유형','집계 단위','분해축') comment='예측 계열의 유형. 실제값: ''TOTAL''(전사)·''CAMPAIGN''(캠페인). 🔴🔴 **항상 이 축을 지정하거나 그룹에 넣는다** — 유형을 섞어 합하면 같은 개발 활동을 여러 축으로 겹쳐 세어 과대가 된다. 🔴 **유형별 합계는 서로 일치하지 않는다** — 각 계열을 독립적으로 예측한 결과이므로 전사와 캠페인 합이 다르다(캠페인은 일부 계열) ⇒ 한 유형으로 다른 유형을 검산하지 말 것. 🔴 부서·후원사업·신규기존 예측은 원천 삭제로 제공하지 않는다.',
		DF.SERIES_CD as df.SERIES_CD with synonyms=('계열코드') comment='degen: 계열 코드. 🔴계열유형에 따라 의미가 다르다(캠페인코드 / (전사)) ⇒ SERIES_TYPE 없이 해석하지 말 것.',
		DF.SERIES_NAME as df.SERIES_NAME with synonyms=('계열명','부서명','후원사업명','캠페인명') comment='계열 라벨(계열유형별로 캠페인명·전사 합계).',
		DF.TS as df.TS with synonyms=('예측월','예측 시점','전망월') comment='예측 대상 월(월 시작일 타임스탬프). 🔴기준월(STDR_MT)과 다르다 — 기준월은 모델을 돌린 달이고 이것은 예측하는 달이다.'
	)
	metrics (
		DF.FORECAST_AMT as SUM(df.FORECAST) with synonyms=('예측 개발액','개발금액 예측치','예측액') comment='개발금액 예측 합계(**만원**). 🔴원 단위가 아니다 — 원으로 답할 때는 만 배 해서 원으로 바꾸고 단위를 밝힌다. 🔴같은 계열유형 안에서만 합산한다.',
		DF.FORECAST_LOWER as SUM(df.LOWER_BOUND) with synonyms=('예측 하한','신뢰구간 하한') comment='95% 신뢰구간 하한 합계(만원). 별개 실적이 아니다.',
		DF.FORECAST_UPPER as SUM(df.UPPER_BOUND) with synonyms=('예측 상한','신뢰구간 상한') comment='95% 신뢰구간 상한 합계(만원). 별개 실적이 아니다.',
		DF.AVG_MONTHLY_FORECAST as AVG(df.FORECAST) with synonyms=('월평균 예측액') comment='예측월당 평균 개발금액(만원).',
		DF.FORECAST_MONTHS as COUNT(DISTINCT df.TS) with synonyms=('예측 개월수') comment='예측 대상 개월 수. 예측 기간을 밝힐 때 쓴다.',
		DF.SERIES_COUNT as COUNT(DISTINCT df.SERIES_CD) with synonyms=('계열 수') comment='계열 수. 🔴전 계열이 예측 대상은 아니다 — 원천이 일부 계열만 담을 수 있으므로 「전체」로 단정하지 않는다.'
	)
	comment='ML 개발금액 예측 SV(2종 통합 · 전사·캠페인). base=SERVING.ML_DVLP_FORECAST_V. 🔴🔴 **단위는 만원이다** — 원 단위 실적(예산·회비 SV)과 같은 표에 넣으면 만 배 오차가 난다. 🔴🔴 예측치이며 실적이 아니다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴🔴 **계열유형(SERIES_TYPE)을 반드시 고정하거나 그룹에 넣는다** — 유형을 섞어 합하면 같은 개발 활동을 여러 축으로 겹쳐 세어 과대가 된다. 🔴🔴 **유형별 합계는 서로 일치하지 않는다** — 계열마다 독립적으로 예측했기 때문에 전사와 캠페인 합이 다르다(캠페인은 일부 계열) ⇒ 한 유형으로 다른 유형을 검산하지 말고, 「캠페인 합이 전사와 다르다」는 지적에는 이 구조를 설명한다. 🔴 기준월(모델 실행월)과 예측월(TS)은 다른 축이다. ⚠️ 예측치에 음수가 존재한다(감액·해지 반영) — 음수를 오류로 보지 않는다. ⚠️ 캠페인 계열은 원천이 일부 캠페인만 담고 있다(근거 = 20_ML_SV_설계.md). 🔴 부서·후원사업·신규기존 예측은 원천 테이블 삭제로 제공하지 않는다. 활성: 예측액·신뢰구간·월평균·예측개월수·계열수 · 계열유형/계열/예측월 축. 비활성: 본부·지부 분해(조직 계층 산출규칙 미확정) · 부서/후원사업/신규기존 분해(원천 삭제) · 실적 대비 정확도(실적 조인 미배선) · 유형 간 정합 검산(원천이 보장하지 않는다).'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **SERIES_TYPE 을 반드시 WHERE 로 고정하거나 GROUP BY 에 넣는다.** 넣지 않으면 전사와 캠페인을 겹쳐 세어 합계가 과대가 된다. 질문이 「전사/전체 개발 예측」이면 SERIES_TYPE=''TOTAL'' 로 고정한다. 「캠페인별」이면 ''CAMPAIGN'' 이다. 🔴 「부서별·후원사업별·신규/기존별 개발 예측」을 물으면 SQL을 만들지 말고, 해당 예측은 원천 삭제로 현재 제공하지 않는다고 답한다. 전사 또는 캠페인 예측을 대안으로 안내하되 이를 부서 값처럼 나눠 계산하지 않는다. (2) 🔴🔴 **단위는 만원이다.** 답변에 항상 단위를 밝히고, 원으로 환산하면 환산했다고 명시한다. 예산·회비 등 원 단위 지표와 같은 표에 합산하지 않는다. (3) 🔴 **기준월(STDR_MT)을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 그 기준월을 밝힌다. (4) 🔴 **기준월과 예측월(TS)을 혼동하지 않는다** — 「향후 12개월 예측」은 하나의 기준월에 속한 TS 12개다. 연도말 전망을 물으면 해당 연도에 속한 TS 만 합산하고 기준월을 밝힌다. (5) 🔴 **예측치임을 답변에 밝힌다** — 실적으로 읽히는 표현(「개발액은 …이다」)을 쓰지 않고 「예측치는 …」으로 쓴다. 테스트 단계임도 함께 밝힌다. (6) **음수 예측치를 오류로 처리하거나 0 으로 바꾸지 않는다** — 감액·해지가 반영된 값이다. (7) **신뢰구간을 별개 수치로 나열하지 않는다** — 예측치와 함께 구간으로 제시한다. (8) 🔴 **유형 간 검산을 시도하지 않는다** — 캠페인 합은 전사 예측과 일치하지 않는다(계열별 독립 예측 · 캠페인은 일부 계열). 사용자가 불일치를 지적하면 원천이 정합을 보장하지 않는 구조라고 설명하고, 임의로 비례배분해 맞추지 않는다. 캠페인 계열은 일부 캠페인만 예측 대상임도 밝힌다. (9) 적용 조건(기준월·계열유형 모두 미지정 시): 최신 기준월 + SERIES_TYPE=''TOTAL'' 로 한정해 예측월별 예측액과 신뢰구간을 반환하고, 다른 분해축이 있음을 안내한다.'
	ai_verified_queries (
		VQR_TOTAL_FORECAST_BY_MONTH AS ( 
QUESTION '최신 기준월 전사 개발금액 예측(예측월별)' 
VERIFIED_BY '(DW = O190)'
SQL 'SELECT df.TS, SUM(df.FORECAST) AS FORECAST_AMT FROM df WHERE df.SERIES_TYPE = ''TOTAL'' AND df.STDR_MT = (SELECT MAX(df.STDR_MT) FROM df) GROUP BY df.TS ORDER BY df.TS')
	);