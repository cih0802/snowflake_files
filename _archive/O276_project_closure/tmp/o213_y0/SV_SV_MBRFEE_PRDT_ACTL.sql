create or replace semantic view SV_MBRFEE_PRDT_ACTL
	tables (
		MP as GN_DW.GOLD.WIDE_MBRFEE_PRDT_ACTL primary key (MONTH_KEY,DATA_TYPE_NM,SPNSR_BSNS_GRP_NM,NEW_EXST_DIV_NM,HDQ_BRNCH_GRP_NM) with synonyms=('회비 예측 실측','회원실 회비예측','연간 회비 예측','회비 계획') comment='회원실 연간 회비 예측·실측 (base: GOLD.WIDE_MBRFEE_PRDT_ACTL). [Grain: 월 × 예측실측구분 × 후원사업그룹 × 신규기존 × 본부지부그룹]. [활성 지표: 개발·중단·감액 건수 · 회비 · 누계 · 비율]. [주의: 부서 자체 수식이며 ML 예측 아님, 예측/실측 행 혼재, 누계 컬럼 월 합산 금지]. [원천: 회원실 집계 → SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA].'
	)
	dimensions (
		MP.MONTH_KEY as mp.MONTH_KEY with synonyms=('기준월','연월') comment='기준월 YYYYMM(정수).',
		MP.CAL_YEAR as mp.CAL_YEAR with synonyms=('연도','사업연도') comment='연도.',
		MP.CAL_MONTH as mp.CAL_MONTH with synonyms=('월') comment='월(1~12).',
		MP.DATA_TYPE_NM as mp.DATA_TYPE_NM with synonyms=('예측실측구분','예측/실측','구분') comment='예측 실측 구분(예측/실측). 🔴 반드시 WHERE 로 고정하거나 GROUP BY 에 넣는다.',
		MP.IS_FORECAST as mp.IS_FORECAST with synonyms=('예측여부') comment='예측행 여부(DATA_TYPE_NM=예측).',
		MP.SPNSR_BSNS_GRP_NM as mp.SPNSR_BSNS_GRP_NM with synonyms=('후원사업그룹','후원사업') comment='후원 사업 그룹 명.',
		MP.NEW_EXST_DIV_NM as mp.NEW_EXST_DIV_NM with synonyms=('신규기존','신규/기존') comment='신규기존구분명.',
		MP.HDQ_BRNCH_GRP_NM as mp.HDQ_BRNCH_GRP_NM with synonyms=('본부지부','본부/지부','지부그룹') comment='본부 지부 그룹 명(회원실 집계 기준).'
	)
	metrics (
		MP.TOTAL_DVLP_CNT as SUM(mp.DVLP_CNT) with synonyms=('개발건수','월 개발건수') comment='월 개발건수 합계(건 · 월 합산 가능).',
		MP.TOTAL_DSCNTC_CNT as SUM(mp.DSCNTC_CNT) with synonyms=('중단건수') comment='월 중단건수 합계(건 · 월 합산 가능).',
		MP.TOTAL_ADJ_DSCNTC_CNT as SUM(mp.ADJ_DSCNTC_CNT) with synonyms=('조정 중단건수') comment='월 조정 중단건수 합계(건).',
		MP.TOTAL_RDCAMT_CNT as SUM(mp.RDCAMT_CNT) with synonyms=('감액건수') comment='월 감액건수 합계(건).',
		MP.TOTAL_ADJ_RDCAMT_CNT as SUM(mp.ADJ_RDCAMT_CNT) with synonyms=('조정 감액건수') comment='월 조정 감액건수 합계(건).',
		MP.TOTAL_SPNSR_BSNS_CHN_DEC_CNT as SUM(mp.SPNSR_BSNS_CHN_DEC_CNT) with synonyms=('후원사업변경 감소건수') comment='월 후원사업변경 감소건수 합계(건).',
		MP.TOTAL_ADJ_MBRFEE_AMT as SUM(mp.ADJ_MBRFEE_AMT) with synonyms=('조정 회비','월 회비') comment='월 조정 회비 합계(원 · 월 합산 가능).',
		MP.TOTAL_MBRFEE_DIFF_AMT as SUM(mp.MBRFEE_DIFF_AMT) with synonyms=('회비 차액') comment='회비 차액 합계(원). 원천 정의 그대로이며 산식을 추정해 설명하지 않는다.',
		MP.CMLT_DVLP_CNT_AT_MONTH as SUM(mp.CMLT_DVLP_CNT) with synonyms=('누적개발건수','연누계 개발건수') comment='🔴 누계(건). 한 기준월로 고정해서만 쓴다 — 여러 달을 더하면 중복계상이다.',
		MP.CMLT_MBRFEE_AMT_AT_MONTH as SUM(mp.CMLT_MBRFEE_AMT) with synonyms=('누적 회비','연누계 회비') comment='🔴 누계(원). 한 기준월로 고정해서만 쓴다.',
		MP.ADJ_CMLT_MBRFEE_AMT_AT_MONTH as SUM(mp.ADJ_CMLT_MBRFEE_AMT) with synonyms=('조정 누계회비') comment='🔴 누계(원). 한 기준월로 고정해서만 쓴다.',
		MP.ADJ_CMLT_DSCNTC_CNT_AT_MONTH as SUM(mp.ADJ_CMLT_DSCNTC_CNT) with synonyms=('조정 누계 중단건수') comment='🔴 누계(건). 한 기준월로 고정해서만 쓴다.',
		MP.CMLT_ACT_MBER_CNT_AT_MONTH as SUM(mp.CMLT_ACT_MBER_CNT) with synonyms=('누적 활동회원건수') comment='🔴 누계(건). 한 기준월로 고정해서만 쓴다.',
		MP.CMLT_EOM_ACT_MBER_CNT_AT_MONTH as SUM(mp.CMLT_EOM_ACT_MBER_CNT) with synonyms=('누적 월말활동회원건수') comment='🔴 누계(건). 한 기준월로 고정해서만 쓴다.',
		MP.AVG_DSCNTC_RT as AVG(mp.DSCNTC_RT) with synonyms=('중단율') comment='[비가산] 중단율(0~1) 행 평균. 그룹을 묶으면 단순평균이 되어 원천 비율과 다르다.',
		MP.AVG_RDCAMT_RT as AVG(mp.RDCAMT_RT) with synonyms=('감액율') comment='[비가산] 감액율(0~1) 행 평균.',
		MP.AVG_ACT_RT as AVG(mp.ACT_RT) with synonyms=('활동율') comment='[비가산] 활동율(0~1) 행 평균.',
		MP.AVG_CMLT_PAY_RT as AVG(mp.CMLT_PAY_RT) with synonyms=('누계납입율') comment='[비가산] 누계납입율(0~1) 행 평균.'
	)
	comment='회원실 연간 회비 예측·실측 SV. base=GOLD.WIDE_MBRFEE_PRDT_ACTL. 🔴🔴 **예측행과 실측행이 함께 있다** — DATA_TYPE_NM 을 고정하거나 그룹에 넣지 않으면 예측과 실측이 합산된다. 🔴🔴 부서 자체 수식이며 ML 예측이 아니다 — ML 회비 예측(SV_ML_FEE_FORECAST)·회비 실적(SV_MEMBER_FEE)과 같은 표에 합산하지 않는다. 🔴🔴 누계(_AT_MONTH) 지표는 한 기준월로 고정해서만 쓴다. 🔴 비율(_RT)은 비가산이다. 단위 = 건수는 건 · 금액은 원. 활성: 개발·중단·감액 건수 · 조정회비 · 누계 · 비율 · 월/구분/후원사업그룹/신규기존/본부지부 축. 비활성: 회원 단위 분해(원천 grain 이 집계).'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **DATA_TYPE_NM 을 반드시 WHERE 로 고정하거나 GROUP BY 에 넣는다.** 「예측」 질문은 ''예측'', 「실적·실측」 질문은 ''실측'' 이다. 예측 대비 실측을 물으면 두 값을 열로 나란히 두고 각각을 밝힌다. (2) 🔴🔴 **누계 지표(이름이 _AT_MONTH 로 끝남)는 MONTH_KEY 하나로 고정한다** — 여러 달을 더하지 않는다. 연간 누계를 물으면 해당 연도의 가장 늦은 월 하나를 쓰고 그 월을 밝힌다. (3) 🔴 **비율(AVG_*_RT)을 합하지 않는다** — 그룹별로 제시하고, 여러 그룹을 묶은 평균은 단순평균임을 밝힌다. 비율은 백분율로 바꿔 표기해도 된다. (4) 🔴 **ML 예측과 섞지 않는다** — 이 SV 는 회원실 자체 수식이다. (5) **단위를 밝힌다** — 건수는 건, 금액은 원. (6) **연도 미지정 시 데이터에 존재하는 최신 연도로 한정하고 밝힌다.** (7) 🔴 **회원 단위·캠페인 단위 분해를 물으면 SQL 을 만들지 않는다** — 이 SV 의 grain 이 집계라고 답한다. (8) 적용 조건(그룹 미지정 시): 최신 연도로 한정해 월별 예측·실측 조정회비와 개발건수를 나란히 반환한다. (9) 🔴 metric 이름을 mp 컬럼처럼 참조하지 않는다 — 정의식(SUM(mp.ADJ_MBRFEE_AMT) 등)으로 집계한다.';