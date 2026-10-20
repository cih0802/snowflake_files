create or replace semantic view GN_DW.SERVING.SV_ML_FEE_FORECAST
	tables (
		FF as GN_DW.SERVING.ML_FEE_FORECAST_V primary key (STDR_MT,CMPGN_CTGR_CD,FORECAST_TS) with synonyms=('회비 예측','카테고리별 회비 예측','후원금액 예측') comment='캠페인 카테고리별 회비 예측 분석 (base: SERVING.ML_FEE_FORECAST_V). [Grain: 기준월 × 캠페인카테고리 × 예측월]. [활성 지표: 예측 회비금액(원)]. [주의: 단위=원, 개발금액(만원)과 단위 상이(합산 금지)]. [원천: ML 회비예측모델 → SERVING.ML_FEE_FORECAST_V].',
		FA as GN_DW.SERVING.ML_FEE_FORECAST_ALLOC_V primary key (STDR_MT,CMPGN_CTGR_CD,FORECAST_MONTH_KEY,ALLOC_AXIS,AXIS_VALUE) with synonyms=('후원사업별 회비 예측','마케팅캠페인명별 회비 예측','공통브랜드별 회비 예측','회비 예측 배분') comment='🆕 [O246] 회비 예측 배분 추정 (base: SERVING.ML_FEE_FORECAST_ALLOC_V). [Grain: 기준월 × 캠페인카테고리 × 예측월 × 배분축 × 축값]. [산식: 카테고리 예측 × 직전 12개월 회비 납입 비중]. 🔴🔴 모델 예측치가 아니라 실적 비중 배분 추정치. 🔴🔴 ALLOC_AXIS 를 반드시 1개로 필터한다(축끼리 합산 = 3배 중복). FF 와 조인하지 않는다.'
	)
	dimensions (
		FF.STDR_MT as ff.STDR_MT with synonyms=('기준월','예측 기준월') comment='모델 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
		FF.CMPGN_CTGR_CD as ff.CMPGN_CTGR_CD with synonyms=('캠페인카테고리코드') comment='degen: 캠페인 카테고리 코드. 라벨은 CMPGN_CTGR_NAME.',
		FF.CMPGN_CTGR_NAME as ff.CMPGN_CTGR_NAME with synonyms=('캠페인카테고리','캠페인 구분','카테고리') comment='캠페인 카테고리명. ⚠️일부 카테고리는 원천 마스터에 이름이 없어 NULL 이다 — 이름을 추정해 채우지 않고 코드로 답한다.',
		FF.FORECAST_TS as ff.FORECAST_TS with synonyms=('예측월','예측 시점') comment='예측 대상 월(월 시작일). 기준월과 다르다.',
		FF.FORECAST_MONTH_KEY as ff.FORECAST_MONTH_KEY with synonyms=('예측연월','예측 YYYYMM') comment='예측 대상 연월(YYYYMM 정수). 연·월 필터에 쓴다.',
		FA.STDR_MT as fa.STDR_MT with synonyms=('배분 기준월') comment='[배분] 모델 실행 기준월(YYYYMM). 미지정 시 최신 1개.',
		FA.CMPGN_CTGR_CD as fa.CMPGN_CTGR_CD with synonyms=('배분 캠페인카테고리코드') comment='[배분] 캠페인카테고리 코드.',
		FA.CMPGN_CTGR_NAME as fa.CMPGN_CTGR_NAME with synonyms=('배분 캠페인카테고리') comment='[배분] 캠페인카테고리명(NULL = 원천 이름 없음 · 코드로 답한다).',
		FA.FORECAST_MONTH_KEY as fa.FORECAST_MONTH_KEY with synonyms=('배분 예측연월') comment='[배분] 예측 대상 연월(YYYYMM 정수).',
		FA.ALLOC_AXIS as fa.ALLOC_AXIS with synonyms=('배분 축','분해 기준') comment='[배분] 배분 축 = 후원사업 / 마케팅캠페인명 / 공통브랜드. 🔴 반드시 1개 값으로 필터한다.',
		FA.AXIS_VALUE as fa.AXIS_VALUE with synonyms=('배분 대상','후원사업','마케팅캠페인명','공통브랜드') comment='[배분] 축 값(후원사업명·마케팅캠페인명·공통브랜드명). (실적 비중 없음) = 그 카테고리에 직전 12개월 회비 실적이 없어 배분 불가(예: 일시) — 숨기지 말고 별도 행으로 표기. (미지정) = 실적 행에 값 없음.'
	)
	metrics (
		FF.TOTAL_FORECAST_FEE as SUM(ff.FORECAST_AMT) with synonyms=('예측 회비','회비 예측치','예측 후원금액') comment='회비(후원금액) 예측 합계(**원**). 🔴개발금액 예측(만원)과 합산하지 않는다.',
		FF.TOTAL_FORECAST_FEE_LOWER as SUM(ff.FORECAST_LOWER) with synonyms=('예측 하한') comment='95% 신뢰구간 하한 합계(원).',
		FF.TOTAL_FORECAST_FEE_UPPER as SUM(ff.FORECAST_UPPER) with synonyms=('예측 상한') comment='95% 신뢰구간 상한 합계(원).',
		FF.AVG_MONTHLY_FORECAST_FEE as AVG(ff.FORECAST_AMT) with synonyms=('월평균 예측 회비') comment='예측월당 평균 회비 예측(원).',
		FF.FORECAST_MONTHS as COUNT(DISTINCT ff.FORECAST_TS) with synonyms=('예측 개월수') comment='예측 대상 개월 수.',
		FF.CATEGORY_COUNT as COUNT(DISTINCT ff.CMPGN_CTGR_CD) with synonyms=('카테고리 수') comment='예측 대상 캠페인카테고리 수.',
		FA.TOTAL_ALLOC_FORECAST_FEE as SUM(fa.ALLOC_FORECAST_AMT) with synonyms=('배분 추정 회비','후원사업별 예측 회비','마케팅캠페인별 예측 회비','브랜드별 예측 회비') comment='[배분] 배분 추정 회비 합계(원). 🔴 모델 예측치 아님 · 실적 비중 배분 추정치. 한 축의 합 = 원 예측 합.',
		FA.TOTAL_ALLOC_FORECAST_LOWER as SUM(fa.ALLOC_LOWER) with synonyms=('배분 하한') comment='[배분] 하한 합계(원) = 카테고리 95% 하한 × 비중.',
		FA.TOTAL_ALLOC_FORECAST_UPPER as SUM(fa.ALLOC_UPPER) with synonyms=('배분 상한') comment='[배분] 상한 합계(원) = 카테고리 95% 상한 × 비중.'
	)
	comment='ML 캠페인카테고리별 회비 예측 SV. base=SERVING.ML_FEE_FORECAST_V. 🔴🔴 예측치이며 실적이 아니다 — 회비 실적은 SV_MEMBER_FEE 소관이고 이 SV 와 같은 표에 합산하지 않는다. 🔴🔴 **단위는 원이다** — 개발금액 예측 SV(만원)와 단위가 다르다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴 기준월(모델 실행월)과 예측월은 다른 축이며 여러 기준월 합산은 중복계상이다. ⚠️ 캠페인카테고리 일부는 원천 마스터에 이름이 없어 라벨이 NULL 이다. ⚠️ 예측 대상 카테고리가 전체 카테고리와 같다고 단정하지 않는다. 활성: 예측 회비·신뢰구간·월평균·예측개월수·카테고리수 · 카테고리/예측월 축. 🆕 [O246] 후원사업·마케팅캠페인명·공통브랜드별 = FA(배분 추정치 · 모델 예측 아님). 비활성: 모델 수준 캠페인 단위 예측(원천 grain 이 카테고리) · 실적 대비 정확도.'
	ai_sql_generation '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS ""한글명"". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: ""연 편성예산(원)"" · ""집행율(%)"" · ""개발(건)""). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **단위는 원이다.** 개발금액 예측(SV_ML_DVLP_FORECAST · 만원)과 같은 표에 합산하지 않는다. 두 예측을 함께 물으면 표를 나누고 각 단위를 밝힌다. (2) 🔴🔴 **예측과 실적을 합산하지 않는다** — 회비 실적은 SV_MEMBER_FEE 다. 실적과 예측을 함께 보여줄 때는 표를 분리하고 각각을 명시한다. (3) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (4) 🔴 **기준월과 예측월을 혼동하지 않는다.** 연도 전망은 해당 연도의 예측월만 합산한다. (5) 🔴 **예측치임과 테스트 단계임을 밝힌다.** (6) **라벨이 NULL 인 카테고리를 숨기거나 이름을 추정하지 않는다** — 코드로 표기하고 원천에 이름이 없다고 밝힌다. (7) **신뢰구간은 예측치와 함께 구간으로 제시한다.** (8) 적용 조건(기준월·그룹 미지정 시): 최신 기준월로 한정해 예측월별 합계와 신뢰구간을 반환하고, 카테고리별 분해가 가능함을 안내한다. (9) 🆕 [O246] 후원사업별·마케팅캠페인명별·공통브랜드별 회비 예측 질문은 FA 테이블만 쓴다 — WHERE ALLOC_AXIS = ''후원사업''(또는 ''마케팅캠페인명''·''공통브랜드'') 를 반드시 1개 넣고, 최신 STDR_MT 1개로 한정하며, FF 와 섞지 않는다. 결과 표 제목에 [실적 비중 배분 추정치 · 모델 예측 아님] 을 붙이고, (실적 비중 없음) 행을 숨기지 않는다.';