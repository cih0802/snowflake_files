create or replace semantic view SV_ML_FEATURE_IMPORTANCE
	tables (
		FI as GN_DW.SERVING.ML_FEATURE_IMPORTANCE_V primary key (STDR_MT,ANALYSIS_TYPE,FEATURE) with synonyms=('요인분석','피처 중요도','기여도','결정 요인') comment='머신러닝 피처 중요도 분석 (base: SERVING.ML_FEATURE_IMPORTANCE_V). [Grain: 기준월 × 분석유형 × 피처]. [활성 지표: 피처별 기여도(0~1)]. [주의: 모델 해석용 지표(분석유형 내 합계=1), 업무 실적치 아님]. [원천: ML 피처중요도모델 → SERVING.ML_FEATURE_IMPORTANCE_V].'
	)
	dimensions (
		FI.STDR_MT as fi.STDR_MT with synonyms=('기준월','분석 기준월') comment='분석 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
		FI.ANALYSIS_TYPE as fi.ANALYSIS_TYPE with synonyms=('분석유형','분석 구분') comment='분석 유형. 실제값: ''CHANNEL_NEW_SPNSR''(신규 후원 유치 요인)·''DVLP_INC''(증액 개발 요인). 🔴반드시 하나로 고정한다 — 유형 내 기여도 합계가 1 이므로 섞으면 합계가 1 을 넘는다.',
		FI.ANALYSIS_TYPE_NAME as fi.ANALYSIS_TYPE_NAME with synonyms=('분석유형명') comment='분석 유형 라벨. 실제값 2종: ''신규 후원 유치 요인''·''증액 개발 요인''.',
		FI.FEATURE as fi.FEATURE with synonyms=('피처','요인','변수') comment='피처(요인) 이름. 모델 입력 변수명이며 업무 용어가 아닐 수 있다. 🔴 **실제값을 여기에 열거하지 않는다** — 피처 목록은 모델이 교체되면 바뀌므로 열거하면 낡은 목록이 사실처럼 발행된다. 값은 조회해서 확인한다.',
		FI.RANK as fi.RANK with synonyms=('순위','중요도 순위') comment='피처 중요도 순위(1=가장 중요). 상위 요인을 뽑을 때 쓴다.',
		FI.FEATURE_TYPE as fi.FEATURE_TYPE with synonyms=('피처 유형') comment='피처 유형. 실제값: ''user_provided''(DVLP_INC 만) · CHANNEL_NEW_SPNSR 는 원천 컬럼 제거(2026-10-02)로 NULL — NULL 은 「모델이 고른 피처」라는 뜻이 아니다. 🔴🔴 이 값의 뜻은 **피처 목록을 사람이 지정했다**는 것이다 — 모델이 스스로 후보 변수를 탐색해 고른 결과가 아니므로 「데이터가 밝혀낸 요인」으로 답하지 않는다.'
	)
	metrics (
		FI.TOTAL_SCORE as SUM(fi.SCORE) with synonyms=('기여도 합계') comment='기여도 합계. 🔴한 분석유형·기준월 안에서 전 피처를 더하면 1 이다 — 유형을 섞으면 1 을 넘고 의미가 사라진다.',
		FI.AVG_SCORE as AVG(fi.SCORE) with synonyms=('평균 기여도') comment='평균 기여도(0~1).',
		FI.MAX_SCORE as MAX(fi.SCORE) with synonyms=('최대 기여도','최상위 요인 기여도') comment='최대 기여도(0~1).',
		FI.FEATURE_COUNT as COUNT(DISTINCT fi.FEATURE) with synonyms=('피처 수','요인 수') comment='분석에 포함된 피처 수.'
	)
	comment='ML 요인분석(피처 중요도) SV(2종). base=SERVING.ML_FEATURE_IMPORTANCE_V. 🔴🔴 **이 SV 는 모델을 설명하는 것이고 업무 실적을 측정하는 것이 아니다** — 값은 0~1 기여도이며 금액·건수·회원수가 아니다. 다른 SV 의 measure 와 같은 표에 넣으면 업무 수치로 오독된다. 🔴 머신러닝은 테스트 단계이며 모델·피처가 교체될 수 있다. 🔴🔴 **ANALYSIS_TYPE 을 반드시 하나로 고정한다** — 유형 내 기여도 합계가 1 이므로 섞으면 합계가 1 을 넘는다. 🔴🔴 **피처 목록은 사람이 지정한 것이다**(피처 유형 ''user_provided'' · CHANNEL_NEW_SPNSR 는 원천에서 유형 컬럼이 제거돼 NULL 이나 같은 방식의 지정 후보로 본다 — 원천 확인 대상) ⇒ 「데이터 분석으로 발견한 요인」이라 답하지 않고 「지정된 후보 요인 중 모델이 매긴 상대 중요도」로 답한다. 🔴 **기여도는 인과가 아니다** — 「이 요인을 늘리면 신규 후원이 늘어난다」는 결론을 내지 않는다. 활성: 기여도 합계/평균/최대·피처수 · 분석유형/피처/순위/피처유형 축. 비활성: 인과 효과 크기 · 요인별 금액 환산.'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **ANALYSIS_TYPE 을 하나 고정한다** — 유형 내 기여도 합계가 1 이므로 두 유형을 섞으면 합계가 1 을 넘고 순위도 뒤섞인다. (2) 🔴🔴 **이 값을 업무 수치로 답하지 않는다** — 금액·건수·회원수가 아니라 모델 기여도(0~1)다. 다른 SV 의 measure 와 같은 표에 넣지 않는다. (3) 🔴🔴 **인과로 답하지 않는다** — 「A 를 늘리면 신규 후원이 늘어난다」가 아니라 「모델이 A 에 가장 큰 상대 중요도를 부여했다」로 표현한다. (4) 🔴 **피처 목록이 사람이 지정한 후보라는 사실을 밝힌다**(피처 유형=user_provided · CHANNEL_NEW_SPNSR 는 NULL) — 「데이터가 찾아낸 요인」이라 하지 않는다. 지정되지 않은 요인은 애초에 후보가 아니었으므로 「중요하지 않다」고 말할 수 없다. (5) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (6) **상위 요인은 RANK 로 정렬한다.** (7) **답변에 모델 설명이며 테스트 단계임을 밝힌다.** (8) 적용 조건(기준월·유형 미지정 시): 최신 기준월 + 사용자가 언급한 주제에 맞는 분석유형 하나로 한정해 RANK 순 상위 요인과 기여도를 반환하고, 다른 분석유형이 있음을 안내한다.';