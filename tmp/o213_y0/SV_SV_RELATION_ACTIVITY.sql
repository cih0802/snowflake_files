create or replace semantic view SV_RELATION_ACTIVITY
	tables (
		FRA as GN_DW.GOLD.FACT_RELATION_ACTIVITY primary key (ACTIVITY_KEY) with synonyms=('결연활동','서신','선물금','결연 서신','아동 선물금') comment='결연활동 팩트(서신·선물금). [Grain: 활동 1행]. [원천: CRM(eCRM) → BRONZE_CRM.TM_RM_RELATNSP_LETTER_INFO·TM_RM_RELATNSP_GFTMNEY_INFO → SILVER.CRM_RELATION_ACTIVITY → GOLD.FACT_RELATION_ACTIVITY].',
		DATE as GN_DW.GOLD.DIM_DATE primary key (DATE_SK) with synonyms=('날짜','활동일') comment='일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
		MEMBER as GN_DW.GOLD.DIM_MEMBER primary key (MEMBER_DK) with synonyms=('회원','결연 후원자') comment='정규 회원 마스터 차원(회원 1명 = 1행). 결연키 → 결연 마스터로 찾은 후원 회원이다. [원천] 시스템=CRM(eCRM) · SILVER=CRM_MEMBER · GOLD=DIM_MEMBER.'
	)
	relationships (
		FRA_TO_DATE as FRA(DATE_SK) references DATE(DATE_SK),
		FRA_TO_MEMBER as FRA(MEMBER_DK) references MEMBER(MEMBER_DK)
	)
	dimensions (
		FRA.ACTIVITY_TYPE as fra.ACTIVITY_TYPE with synonyms=('활동유형','결연활동유형') comment='활동 유형 — **계열 분해의 정본 축**이다. 실제값 2종: ''서신''·''선물금''. 🔴 두 계열은 속성이 다르다(서신 계열 속성은 선물금 행에서 NULL · 선물금 계열 속성은 서신 행에서 NULL) ⇒ 계열 속성으로 분해할 때는 이 축을 동반한다',
		FRA.LETTER_DIV_CD as fra.LETTER_DIV_CD with synonyms=('서신구분코드') comment='서신 구분 **원천 코드**(라벨 미배선 · 코드군 미확정). 실제값 3종: 1·5·9 + NULL. 🔴 라벨을 추측하지 말 것 — 현업에 코드 의미를 물어야 한다',
		FRA.LETTER_STAT_CD as fra.LETTER_STAT_CD with synonyms=('편지상태코드','서신상태코드') comment='편지 상태 **원천 코드**(서신 계열 · 라벨 미배선). 실제값 2종: 2·3 + NULL. 🔴 라벨 추측 금지 · 선물금 행은 NULL(구조적 부재)',
		FRA.ONLINE_POST_WRITNG_YN as fra.ONLINE_POST_WRITNG_YN with synonyms=('온라인우편작성여부','온라인 작성') comment='온라인 우편 작성 여부(서신 계열). 실제값 2종: ''0''·''1'' + NULL. ⚠️ 원천이 Y/N 이 아니라 0/1 이다 · 선물금 행은 NULL',
		FRA.GFT_DIV_CD as fra.GFT_DIV_CD with synonyms=('선물구분코드') comment='선물 구분 **원천 코드**(선물금 계열 · 라벨 미배선). 실제값 7종: ''0''·''1''·''2''·''3''·''4''·''5''·''6'' + NULL. 🔴 라벨 추측 금지 · 서신 행은 NULL',
		FRA.TRNSFER_YN as fra.TRNSFER_YN with synonyms=('이관여부') comment='이관 여부(선물금 계열). 실제값 3종: ''0''·''1''·''2'' + NULL. 🔴 여부 컬럼이지만 3값이다 — 2 의 뜻은 원천 미확정(창작 금지)',
		DATE.ACTIVITY_DATE as date.FULL_DATE with synonyms=('활동일','접수일','일자','날짜') comment='활동일 — 서신은 접수일 · 선물금은 원천에 접수일이 없어 발송일이다. ⚠️ 일자가 없거나 달력 범위 밖인 행은 Unknown(0)으로 라우팅되어 날짜 축 집계에서 빠진다',
		DATE.FULL_DATE as date.FULL_DATE comment='달력 날짜(DIM_DATE.FULL_DATE) — ACTIVITY_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
		DATE.YEAR as date.YEAR with synonyms=('연도','년') comment='연도',
		DATE.MONTH as date.MONTH with synonyms=('월') comment='월(1~12)',
		MEMBER.GENDER_NAME as member.GENDER_NAME with synonyms=('성별') comment='회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨)',
		MEMBER.MEMBER_STATUS_NAME as member.MEMBER_STATUS_NAME with synonyms=('회원상태') comment='현재 회원상태 라벨(MM010 · 현재 마스터 스냅샷 · 활동 시점 값이 아니다). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)'''
	)
	metrics (
		FRA.TOTAL_ACTIVITY_CNT as SUM(fra.ACTIVITY_CNT) with synonyms=('활동건수','서신건수','선물금건수','결연활동(건)') comment='결연활동(건) 합계. F(가산). 서신·선물금을 나누려면 ACTIVITY_TYPE 으로 그룹핑한다.',
		FRA.DISTINCT_ACTIVITY_MEMBERS as COUNT(DISTINCT fra.MEMBER_DK) with synonyms=('활동 회원수','참여 회원수','결연활동(명)') comment='결연활동 고유 회원수(명). D(distinct). 🔴 월·유형별 회원수를 더해 기간 회원수를 만들지 말 것(중복). ⚠️ 결연 마스터에 매칭되지 않은 고아 결연 행은 회원이 NULL 이라 세지 않는다',
		FRA.TOTAL_GIFT_AMT as SUM(fra.GFTMNEY) with synonyms=('선물금','선물금액','선물금(원)') comment='선물금 합계(원). F(가산). 🔴 선물금 행만 값이 있다(서신 행은 NULL) · 미화금액(GFTMNEY_DOLLAR_AMT)은 문자열 원천이라 합산하지 않는다'
	)
	comment='결연활동 SV (base: GOLD.FACT_RELATION_ACTIVITY · grain = 서신/선물금 활동 1행 · DEC-58). 결연 후원자의 서신 접수·선물금 전달 건수, 고유 회원수, 선물금(원). ⚠️ 서신과 선물금은 계열 속성이 다르므로 ACTIVITY_TYPE 동반. 코드 속성은 라벨 미배선(코드군 미확정)이다. 발송(서비스) 실적과는 별도 팩트이며 합산하지 않는다.'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 계열 동반: 서신·선물금 계열 속성(LETTER_*, GFT_DIV_CD, TRNSFER_YN)으로 분해할 때는 ACTIVITY_TYPE 을 함께 그룹핑한다. (2) 건수 vs 회원수: 건수는 SUM(fra.ACTIVITY_CNT), 회원수(명)는 COUNT(DISTINCT fra.MEMBER_DK) 로 집계하고 월별 회원수를 더하지 않는다. (3) 선물금(원)은 SUM(fra.GFTMNEY) — 선물금 행만 값이 있다. (4) 코드 라벨 미배선: 코드값을 그대로 보여주고 라벨을 추측하지 않는다. (5) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하고 그 기간을 밝힌다. 「최근 N개월」 기준일은 비상관 CTE 1개(SELECT MAX(date.FULL_DATE) FROM fra JOIN date ON fra.DATE_SK = date.DATE_SK)로 구하고 CROSS JOIN 한다. (6) metric 이름(TOTAL_ACTIVITY_CNT 등)을 fra 컬럼처럼 참조하지 않는다. (7) 발송 실적(SV_SERVICE)과 한 쿼리로 조인·합산하지 않는다 — 필요하면 표를 분리한다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다.'
	ai_verified_queries (
		VQR_O196_TYPE_MONTH AS ( 
QUESTION '활동유형별 월별 결연활동 건수와 회원수, 선물금' 
VERIFIED_BY '(DW = O196-E)'
SQL 'SELECT date.YEAR, date.MONTH, fra.ACTIVITY_TYPE, SUM(fra.ACTIVITY_CNT) AS TOTAL_ACTIVITY_CNT, COUNT(DISTINCT fra.MEMBER_DK) AS DISTINCT_ACTIVITY_MEMBERS, SUM(fra.GFTMNEY) AS TOTAL_GIFT_AMT FROM fra JOIN date ON fra.DATE_SK = date.DATE_SK GROUP BY date.YEAR, date.MONTH, fra.ACTIVITY_TYPE ORDER BY date.YEAR, date.MONTH, fra.ACTIVITY_TYPE')
	);