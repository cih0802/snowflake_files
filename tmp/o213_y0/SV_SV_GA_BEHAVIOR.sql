create or replace semantic view SV_GA_BEHAVIOR
	tables (
		FBQ as GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR with synonyms=('GA','GA4','웹 행동','앱 행동','방문 행동','홈페이지 행동') comment='웹·앱 사용자 행동 팩트(GA4). [Grain: 일 × 식별자 × 이벤트 × 트래픽소스 × 기기 × 페이지]. [원천: GA4 → BigQuery → 외부 Python 적재 → GN_DW.SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_EVENT 등 → GOLD.FACT_BIGQUERY_BEHAVIOR · BRONZE_BIGQUERY 는 비어 있다]. 🔴 CRM 회비·개발 실적과 원천이 다르다(GA4 ↔ CRM) — 한 표에 합산·비율 계산하지 않는다.',
		DATE as GN_DW.GOLD.DIM_DATE primary key (DATE_SK) with synonyms=('날짜','방문일') comment='일 차원. [원천] ETL 생성(달력).',
		EVT as GN_DW.GOLD.DIM_BIGQUERY_EVENT primary key (BIGQUERY_EVENT_SK) with synonyms=('이벤트','GA 이벤트') comment='GA4 이벤트 분류 차원(카테고리·액션·라벨). [원천] SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_EVENT_DIM.',
		SRC as GN_DW.GOLD.DIM_BIGQUERY_SOURCE primary key (BIGQUERY_SOURCE_SK) with synonyms=('유입경로','트래픽소스','유입채널') comment='GA4 트래픽 소스 차원(채널그룹·소스/매체·UTM). [원천] SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_TRAFFIC_SOURCE.',
		DEV as GN_DW.GOLD.DIM_DEVICE primary key (DEVICE_SK) with synonyms=('기기','디바이스') comment='기기 차원. [원천] SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_DEVICE.'
	)
	relationships (
		FBQ_TO_DATE as FBQ(DATE_SK) references DATE(DATE_SK),
		FBQ_TO_DEV as FBQ(DEVICE_SK) references DEV(DEVICE_SK),
		FBQ_TO_EVT as FBQ(BIGQUERY_EVENT_SK) references EVT(BIGQUERY_EVENT_SK),
		FBQ_TO_SRC as FBQ(BIGQUERY_SOURCE_SK) references SRC(BIGQUERY_SOURCE_SK)
	)
	dimensions (
		FBQ.UTM_CAMPAIGN as fbq.UTM_CAMPAIGN with synonyms=('UTM 캠페인','GA 캠페인') comment='UTM campaign(자유 텍스트). 🔴 CRM 캠페인 코드와 다른 체계다 — CRM 캠페인으로 바꿔 말하지 않는다',
		FBQ.PAGE_PATH as fbq.PAGE_PATH with synonyms=('페이지','페이지 경로','URL 경로') comment='페이지 경로(고유값이 매우 많은 자유 텍스트). 특정 페이지는 ILIKE 부분일치로 필터한다. 「유입/전환/중간 페이지」 같은 퍼널 단계 라벨은 원천에 없다 — 창작하지 않는다',
		DATE.VISIT_DATE as date.FULL_DATE with synonyms=('방문일','일자','날짜') comment='행동 발생일',
		DATE.YEAR as date.YEAR with synonyms=('연도','년') comment='연도',
		DATE.MONTH as date.MONTH with synonyms=('월') comment='월(1~12)',
		DATE.WEEK_OF_YEAR as date.WEEK_OF_YEAR with synonyms=('주차') comment='연중 주차',
		EVT.EVENT_CATEGORY as evt.EVENT_CATEGORY with synonyms=('이벤트 카테고리','이벤트구분') comment='GA4 이벤트 카테고리. 주요값 예: ''donor_action''·''나의후원''·''캠페인스크롤깊이''·''후원창''·''header''·''메뉴''·''캠페인버튼클릭''. 🔴 NULL = 페이지뷰 행(카테고리 없음)이며 결측이 아니다 — 페이지뷰는 TOTAL_PAGE_VIEWS 로 센다',
		EVT.EVENT_ACTION as evt.EVENT_ACTION with synonyms=('이벤트 액션') comment='GA4 이벤트 액션(자유 텍스트 · 카디널리티 큼) — 이름으로 물으면 ILIKE 부분일치로 필터한다',
		EVT.EVENT_LABEL as evt.EVENT_LABEL with synonyms=('이벤트 라벨') comment='GA4 이벤트 라벨(자유 텍스트 · 카디널리티 큼) — ILIKE 부분일치로 필터한다',
		SRC.DEFAULT_CHANNEL_GROUP as src.DEFAULT_CHANNEL_GROUP with synonyms=('채널그룹','유입채널','GA 채널') comment='GA4 기본 채널그룹. 실제값 16종 예: ''Unassigned''·''Display''·''Organic Social''·''Organic Search''·''Paid Search''·''Paid Other''·''Paid Video''·''Referral''·''Email''·''SMS''. ⚠️ ''Unassigned''가 행의 큰 비중을 차지한다(비율은 조회로 확인) — 채널 분포를 낼 때 함께 밝힌다',
		SRC.SOURCE_MEDIUM as src.SOURCE_MEDIUM with synonyms=('소스/매체','소스매체') comment='GA4 소스/매체(예: google / cpc)',
		SRC.UTM_SOURCE as src.UTM_SOURCE with synonyms=('UTM 소스') comment='UTM source',
		SRC.UTM_MEDIUM as src.UTM_MEDIUM with synonyms=('UTM 매체') comment='UTM medium',
		DEV.DEVICE_TYPE as dev.DEVICE_TYPE with synonyms=('기기유형','디바이스유형') comment='기기 유형(PC·모바일 등)'
	)
	metrics (
		FBQ.TOTAL_EVENT_CNT as SUM(fbq.EVENT_CNT) with synonyms=('이벤트수','이벤트 건수','클릭수') comment='이벤트 발생 건수 합계. F(가산) — 이벤트·채널·페이지 어느 축으로도 더할 수 있다.',
		FBQ.TOTAL_PAGE_VIEWS as SUM(fbq.VIEW_CNT) with synonyms=('페이지뷰','조회수','PV') comment='페이지뷰 합계. F(가산). 페이지뷰 행(EVENT_CATEGORY NULL)에만 값이 있다 — 다른 이벤트로 필터하면 0 이다.',
		FBQ.IDENTIFIED_VISITORS as COUNT(DISTINCT CASE WHEN fbq.IDENTITY_SK > 0 THEN fbq.IDENTITY_SK END) with synonyms=('식별 방문자수','로그인 방문자수','회원 방문자수') comment='로그인 등으로 식별된 고유 방문자 수(명). D(distinct · 가산 금지). 🔴 비식별 방문자(전체 행의 일부 · 비중은 조회로 확인)는 빠진다 — 전체 방문자 수가 아니다. 식별자는 CRM 회원과 연결되지만 이 SV 에서 CRM 실적과 결합하지 않는다.',
		FBQ.EVENT_SESSIONS as SUM(fbq.SESSION_CNT) with synonyms=('세션수(이벤트 기준)') comment='🔴🔴 이벤트 단위 세션 수 — 같은 세션이 이벤트마다 반복 집계된다(실측 키 중복 다수 · 규모는 파일 머리 주석). **EVENT_CATEGORY 를 하나로 고정했을 때만** 쓴다. 여러 이벤트를 합친 「총 세션」·「총 방문」으로 답하지 않는다.',
		FBQ.AVG_ENGAGEMENT_RATE as AVG(fbq.ENGAGEMENT_RATE) with synonyms=('참여율') comment='행 단위 참여율의 단순 평균(가중치 없음 · 참고치). 비율(N) — 재합산 금지.'
	)
	comment='GA4 웹·앱 행동 SV(🆕 O203). 이벤트·페이지뷰·식별 방문자·채널 분석용. [원천: GA4 → GN_DW.SILVER.BIGQUERY_REFINED_DATA(외부 Python 적재) → GOLD.FACT_BIGQUERY_BEHAVIOR]. 🔴 개인 단위 예측(방문자 전환 예측·재방문 예측)·퍼널 단계 라벨·신규 사용자(first_visit) 구분은 없다 — 집계만 제공한다. 🔴 [O203 사용자 결정] GA 원천은 추가되지 않는다 ⇒ 그런 질문에는 문구를 그대로 「현재 GA 데이터로는 답변할 수 없습니다. 자세한 내용은 IT부서에 문의 바랍니다.」 로 안내하고, 추가 적재·추후 제공·약속 관련 표현을 덧붙이지 않는다.'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 건수는 TOTAL_EVENT_CNT(가산), 페이지 조회는 TOTAL_PAGE_VIEWS, 사람 수는 IDENTIFIED_VISITORS(식별자만 · distinct). (2) EVENT_SESSIONS 는 EVENT_CATEGORY 를 하나로 고정할 때만 쓰고, 여러 이벤트의 세션을 더해 총 세션으로 답하지 않는다. (3) 기간 미지정 시 데이터 최신월 기준 직전 3개월로 한정한다. 기준 시점은 비상관 CTE 1개(SELECT MAX(date.FULL_DATE) FROM fbq JOIN date ON fbq.DATE_SK = date.DATE_SK)로 구하고 CROSS JOIN 한다. (4) 채널 분포에는 Unassigned 를 함께 보여준다. (5) PAGE_PATH·EVENT_ACTION·EVENT_LABEL·UTM_CAMPAIGN 은 자유 텍스트이므로 ILIKE 부분일치로 필터한다. (6) CRM 실적(개발·회비)과 교차 계산하지 않는다. (7) ORDER BY 에는 SELECT 별칭을 그대로 쓴다.'
	ai_verified_queries (
		VQR_O203_CHANNEL_3M AS ( 
QUESTION '최근 3개월 GA 채널그룹별 이벤트수와 식별 방문자수' 
VERIFIED_BY '(DW = O203)'
SQL 'WITH mx AS (SELECT MAX(date.FULL_DATE) AS md FROM fbq JOIN date ON fbq.DATE_SK = date.DATE_SK) SELECT src.DEFAULT_CHANNEL_GROUP, SUM(fbq.EVENT_CNT) AS TOTAL_EVENT_CNT, COUNT(DISTINCT CASE WHEN fbq.IDENTITY_SK > 0 THEN fbq.IDENTITY_SK END) AS IDENTIFIED_VISITORS FROM fbq JOIN date ON fbq.DATE_SK = date.DATE_SK JOIN src ON fbq.BIGQUERY_SOURCE_SK = src.BIGQUERY_SOURCE_SK CROSS JOIN mx WHERE date.FULL_DATE > DATEADD(MONTH, -3, mx.md) GROUP BY src.DEFAULT_CHANNEL_GROUP ORDER BY TOTAL_EVENT_CNT DESC'),
		VQR_O203_DONATION_WINDOW AS ( 
QUESTION '후원창 이벤트가 많이 발생한 페이지 상위 10개' 
VERIFIED_BY '(DW = O203)'
SQL 'SELECT fbq.PAGE_PATH, SUM(fbq.EVENT_CNT) AS TOTAL_EVENT_CNT, COUNT(DISTINCT CASE WHEN fbq.IDENTITY_SK > 0 THEN fbq.IDENTITY_SK END) AS IDENTIFIED_VISITORS FROM fbq JOIN evt ON fbq.BIGQUERY_EVENT_SK = evt.BIGQUERY_EVENT_SK WHERE evt.EVENT_CATEGORY = ''후원창'' GROUP BY fbq.PAGE_PATH ORDER BY TOTAL_EVENT_CNT DESC LIMIT 10')
	);