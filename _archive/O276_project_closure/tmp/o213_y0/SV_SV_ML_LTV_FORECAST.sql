create or replace semantic view SV_ML_LTV_FORECAST
	tables (
		LF as GN_DW.SERVING.ML_LTV_FORECAST_V primary key (STDR_MT,LTV_TYPE,SERIES_CD,TS) with synonyms=('LTV 예측','생애가치 예측','후원 LTV 예측','채널별 후원금액 예측') comment='마케팅채널·캠페인 LTV 월별 시계열 예측 분석 (base: SERVING.ML_LTV_FORECAST_V). [Grain: 기준월 × LTV유형 × 계열 × 예측월]. [활성 지표: 예측 금액(원)]. [주의: 마케팅채널 회원평균 후원금액과 캠페인 월간 후원금액 분리]. [원천: ML LTV모델 2종 → SERVING.ML_LTV_FORECAST_V].'
	)
	dimensions (
		LF.STDR_MT as lf.STDR_MT with synonyms=('기준월','예측 기준월') comment='모델 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
		LF.LTV_TYPE as lf.LTV_TYPE with synonyms=('LTV 유형','LTV 구분') comment='LTV 유형. 실제값: ''MKTG_CHANNEL_AVG_MEMBER''(마케팅채널 회원평균 후원금액)·''CMPGN_TOTAL''(캠페인 월간 후원금액). 🔴🔴 **반드시 하나로 고정한다** — 하나는 1인당 평균이고 하나는 총액이라 자리수가 크게 다르고, 계열 축(마케팅채널 ↔ 캠페인)도 다르다.',
		LF.LTV_TYPE_NAME as lf.LTV_TYPE_NAME with synonyms=('LTV 유형명') comment='LTV 유형 라벨. 실제값 2종: ''마케팅채널 회원평균 후원금액''·''캠페인 월간 후원금액''.',
		LF.SERIES_CD as lf.SERIES_CD with synonyms=('계열코드','마케팅채널코드','캠페인코드') comment='degen: 계열 코드. 🔴LTV유형에 따라 마케팅채널 코드(MKTG_CHANNEL) 또는 캠페인코드(CMPGN_CD)다 — 유형 없이 해석하지 말 것.',
		LF.SERIES_NAME as lf.SERIES_NAME with synonyms=('계열명','마케팅채널','채널명','캠페인명') comment='계열 라벨(마케팅채널명 / 캠페인명 · 캠페인 마스터). 🟢 이 SV 에서는 라벨 미도달이 없다(2026-10-02 실측).',
		LF.TS as lf.TS with synonyms=('예측월','예측 시점') comment='예측 대상 월(월 시작일). 기준월과 다르다.'
	)
	metrics (
		LF.AVG_FORECAST_LTV as AVG(lf.FORECAST) with synonyms=('평균 LTV 예측','LTV 예측치') comment='예측값 평균(원). 🔴LTV유형을 고정한 상태에서만 의미가 있다. 회원평균 유형에서는 「회원 1인당 평균의 평균」이므로 회원수 가중이 아니다.',
		LF.TOTAL_FORECAST_LTV as SUM(lf.FORECAST) with synonyms=('LTV 예측 합계','예측 후원금액 합계') comment='예측값 합계(원). 🔴🔴 **회원평균 유형(MKTG_CHANNEL_AVG_MEMBER)에서는 합산하지 않는다** — 1인당 평균을 더한 값은 업무 의미가 없다. 총액 유형(CMPGN_TOTAL)에서만 합산한다.',
		LF.FORECAST_LOWER as AVG(lf.LOWER_BOUND) with synonyms=('LTV 예측 하한') comment='95% 신뢰구간 하한 평균(원).',
		LF.FORECAST_UPPER as AVG(lf.UPPER_BOUND) with synonyms=('LTV 예측 상한') comment='95% 신뢰구간 상한 평균(원).',
		LF.FORECAST_MONTHS as COUNT(DISTINCT lf.TS) with synonyms=('예측 개월수') comment='예측 대상 개월 수.',
		LF.SERIES_COUNT as COUNT(DISTINCT lf.SERIES_CD) with synonyms=('계열 수','채널 수','캠페인 수') comment='예측 대상 계열 수.'
	)
	comment='ML LTV 월별 예측 SV(2종). base=SERVING.ML_LTV_FORECAST_V. 🔴🔴 예측치이며 실적이 아니다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다(2026-10-02 원천 교체 — 종전 상위캠페인 회원평균 LTV·캠페인 총액 LTV·LTV 스코어 4종은 폐기됐다). 🔴🔴 **LTV_TYPE 을 반드시 하나로 고정한다** — ''MKTG_CHANNEL_AVG_MEMBER''는 마케팅채널의 **회원 1인당 평균 후원금액** 예측이고 ''CMPGN_TOTAL''은 캠페인의 **월간 후원금액 총액** 예측이다. 두 유형은 의미·자리수·계열 축이 달라 합산·순위 비교를 함께 하면 반드시 틀린다. ⚠️ **원천 표기와 데이터가 다르다** — 원천은 두 테이블 모두 계열 컬럼을 MKTG_CHANNEL(채널)로 이름 붙였으나 CMPGN_TOTAL 쪽 값은 캠페인코드다 ⇒ 「채널별」 질문은 MKTG_CHANNEL_AVG_MEMBER 로, 「캠페인별 후원금액 예측」은 CMPGN_TOTAL 로 답한다(원천 확인 중). 🔴 회원평균 유형을 합산하지 않는다. 활성: 예측 평균/합계·신뢰구간·예측개월수·계열수 · LTV유형/계열/예측월 축. 비활성: 회원 단위 LTV(원천 grain 이 계열) · 계열당 LTV 스코어(원천 폐기) · 실적 대비 정확도.'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **LTV_TYPE 을 WHERE 로 하나 고정한다.** 두 유형을 한 표에 섞지 않는다 — 하나는 1인당 평균, 하나는 총액이며 계열 축이 다르다. 「채널별/마케팅채널별 (회원평균) 후원금액·LTV」는 ''MKTG_CHANNEL_AVG_MEMBER'', 「캠페인별 후원금액 예측」은 ''CMPGN_TOTAL'' 이다. 어느 쪽인지 불분명하면 사용자에게 확인하거나 두 표로 나눠 각 정의를 밝힌다. (2) 🔴🔴 **회원평균 유형에서 TOTAL_FORECAST_LTV(합계)를 쓰지 않는다** — 1인당 평균을 더한 값은 의미가 없다. 그 유형에서는 AVG_FORECAST_LTV 를 쓴다. (3) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (4) 🔴 **예측치임과 테스트 단계임을 밝힌다.** (5) **단위는 원이다.** 개발금액 예측(만원)과 합산하지 않는다. (6) 🔴 **「LTV 스코어·과거 누적 LTV·상위캠페인 LTV」를 물으면 SQL 을 만들지 않는다** — 원천 폐기로 제공하지 않는다고 답하고 이 SV 의 월별 예측을 대안으로 안내한다. (7) 적용 조건(기준월·유형 미지정 시): 최신 기준월 + LTV_TYPE=''MKTG_CHANNEL_AVG_MEMBER'' 로 한정해 계열별 평균 예측 상위를 반환하고, 다른 유형이 있음을 안내한다.'
	ai_verified_queries (
		VQR_O198_TOP_CHANNEL_AVG AS ( 
QUESTION '마케팅채널별 회원평균 후원금액 예측 상위 10(최신 기준월)' 
VERIFIED_BY '(DW = O198)'
SQL 'SELECT lf.SERIES_NAME, AVG(lf.FORECAST) AS AVG_FORECAST_LTV FROM lf WHERE lf.LTV_TYPE = ''MKTG_CHANNEL_AVG_MEMBER'' AND lf.STDR_MT = (SELECT MAX(lf.STDR_MT) FROM lf) GROUP BY lf.SERIES_NAME ORDER BY AVG_FORECAST_LTV DESC NULLS LAST LIMIT 10')
	);