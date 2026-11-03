create or replace semantic view SV_DEV_ACHIEVEMENT
	tables (
		ACHV as GN_DW.GOLD.FACT_MEMBER_DEV_ACHIEVEMENT primary key (MONTH_KEY,ORG_SK,DEV_TYPE) with synonyms=('개발목표','개발실적','목표대비실적','개발현황') comment='회원개발 부문 목표 대비 실적 달성률 분석 (base: GOLD.FACT_MEMBER_DEV_ACHIEVEMENT). [Grain: 월 × 부서 × 개발구분]. [활성 지표: 월/연 목표건수, 실적건수, 달성률(%)]. [주의: 앵커_경합 방지, 달성률은 GOAL_CNT>0 스코프 필수]. [원천: GOLD.FACT_TARGET_MEMBER_DEV × FACT_MEMBER_EVENT].'
	)
	dimensions (
		ACHV.MONTH_KEY as achv.MONTH_KEY with synonyms=('연월','목표월','기준연월','실적월') comment='YYYYMM 정수. 목표와 실적의 공통 월 축.',
		ACHV.CAL_YEAR as achv.CAL_YEAR with synonyms=('연도','년','목표연도') comment='연도. 연 목표·연 실적(정본 공#3)은 이 축으로 그룹하면 산출된다 — 별도 metric 이 필요 없다.',
		ACHV.CAL_MONTH as achv.CAL_MONTH with synonyms=('월') comment='월(1~12). 누계(정본 공#2)는 이 값에 범위 조건(1~기준월)을 걸어 산출한다.',
		ACHV.ORG_DEPARTMENT as achv.ORG_DEPARTMENT with synonyms=('부서','부서명','실적부서','담당부서') comment='부서명(정본 #116). 장표의 첫 축이다. 실적측은 실적부서(원천 ACMSLT_DEPT_CD) 기준으로 귀속된다. 값 ''(미매핑)''은 부서코드가 조직 마스터에 없는 소수 행이다. ⚠️본부/지부·팀·법인 축은 이 SV 에 없다 — 산출규칙 미확정(CONF-4)이라 값이 존재하지 않으며, 요청받으면 부서 단위까지만 가능하다고 답할 것(추정 금지). ⚠️조직 개편으로 목표만 편성되고 실적은 다른 부서로 귀속된 부서가 존재한다 — 달성율이 0 에 가까운 부서를 「실적 부진」으로 단정하지 말고 해당 연도에 실적이 아예 없는지 확인할 것. 🔴부서 목표 규모의 편차가 매우 크다 — 월 한 자리 수 목표인 소규모 센터와 수천 건 목표인 부서가 같은 축에 있다. **달성율 순위·「최우수 부서」 판정에는 반드시 TOTAL_GOAL_CNT 를 함께 제시**하고, 목표 규모가 극소한 부서를 단독 1위로 결론하지 말 것. 소규모 부서는 실적 몇 건으로 달성율이 100% 를 넘으며 이는 스코프 결함이 아니라 실제 초과 달성이다.',
		ACHV.DEV_TYPE as achv.DEV_TYPE with synonyms=('개발구분코드') comment='개발구분 코드 raw. 실제값은 1(신규)·2(증액)·4(재후원) 세 가지뿐이다 — 정본 공#121 개발 정의와 일치한다. 라벨은 DEV_TYPE_NAME. ⚠️감액(3)·후원중단(5)은 개발이 아니므로 목표·실적 양쪽에 없다. 실제값 3종: ''1''·''2''·''4''',
		ACHV.DEV_TYPE_NAME as achv.DEV_TYPE_NAME with synonyms=('개발구분','개발구분명','개발유형') comment='개발구분명(CRM 코드사전 MM015 라벨) — 신규/증액/재후원. 코드는 DEV_TYPE. 🔴목표 편성은 개발구분별로 관행이 크게 다르다 — 증액·재후원은 최근 연도에 목표가 0 으로 등록돼 있어 그 기간 달성율이 산출되지 않는다(현업 확인 대기). 구분별 달성율을 비교할 때 이 비대칭을 함께 밝힐 것. 실제값 3종: ''신규''·''증액''·''재후원''',
		ACHV.HAS_POSITIVE_GOAL as achv.HAS_POSITIVE_GOAL with synonyms=('목표편성여부','목표있음','목표편성') comment='TRUE=해당 월×부서×구분에 **0 보다 큰 목표가 편성**돼 있다. 🔴달성율 metric 이 이 조건으로 분자를 이미 스코프하므로 사용자가 따로 필터할 필요는 없다. 「목표가 편성된 부서만」 같은 요청에 이 축을 쓴다. ⚠️CRM 에 목표 0 으로 등록된 행이 다수 있어 「목표 행이 존재한다」와 「목표가 편성됐다」는 다르다 — 이 축은 후자다.',
		ACHV.HAS_ACTUAL as achv.HAS_ACTUAL with synonyms=('실적발생여부','실적있음') comment='TRUE=해당 월×부서×구분에 개발 실적이 발생했다. FALSE 는 목표만 편성된 월이며 **아직 오지 않은 미래월도 포함**한다 — 「미달」로 단정하지 말 것.'
	)
	metrics (
		ACHV.TOTAL_GOAL_CNT as SUM(achv.GOAL_CNT) with synonyms=('월 목표','개발목표','회원개발목표','목표건수','연 목표','누계 목표') comment='회원개발목표(건) 합계. F(가산). 🟢단월 필터=월 목표 · 1월~기준월 필터=누계 목표 · 연 그룹=연 목표 — **하나의 metric 이 세 지표를 모두 답한다**(별도 누계·연 metric 이 없는 이유다).',
		ACHV.TOTAL_ACTUAL_CNT as SUM(achv.ACTUAL_CNT) with synonyms=('월 실적','개발실적','개발건','개발건수','연 실적','누계 실적') comment='개발실적(건) 합계 — 정본 공#121 개발(신규·증액·재후원) 기준. F(가산). ⚠️여기에는 **목표가 편성되지 않은 부서·월의 실적도 포함**된다. 그래서 이 값을 TOTAL_GOAL_CNT 로 직접 나누면 달성율이 과대해진다 — 달성율은 반드시 ACHIEVEMENT_RATE 를 쓸 것.',
		ACHV.TOTAL_ACTUAL_CNT_ON_GOAL as SUM(CASE WHEN achv.GOAL_CNT > 0 THEN achv.ACTUAL_CNT END) with synonyms=('목표편성분 실적','달성율 분자') comment='목표가 편성된(GOAL_CNT>0) 월×부서×구분의 개발실적(건). F(가산). ACHIEVEMENT_RATE 의 **분자**다 — 달성율을 검산하고 싶을 때 TOTAL_GOAL_CNT 와 함께 쓴다. TOTAL_ACTUAL_CNT 보다 작다(목표 미편성분 제외).',
		ACHV.ACHIEVEMENT_RATE as SUM(CASE WHEN achv.GOAL_CNT > 0 THEN achv.ACTUAL_CNT END) / NULLIF(SUM(achv.GOAL_CNT), 0) * 100 with synonyms=('목표 달성율','달성율','목표대비 개발','월 목표 달성율','누계 목표 달성율','연 목표 달성율','목표달성률') comment='목표 달성율(%) = 개발실적 ÷ 회원개발목표 ×100. 비율(N) — 상위 집계 시 분자·분모를 각각 합산해 재계산한다. 정본 공#1(월)·#2(누계)·#3(연)을 **동일 식**으로 답한다: 기간 필터만 바꾼다. 🔴**분자가 목표 편성분(GOAL_CNT>0)으로 스코프돼 있다** — 목표가 0 인 행의 실적이 분자에 들어가면 분모 없이 비율이 폭증하기 때문에 식에 못박았다. ⚠️따라서 TOTAL_ACTUAL_CNT ÷ TOTAL_GOAL_CNT 와 값이 다르다(그쪽이 과대). 손으로 검산하려면 TOTAL_ACTUAL_CNT_ON_GOAL ÷ TOTAL_GOAL_CNT 를 쓸 것.'
	)
	comment='회원개발 부문 목표 대비 실적 달성률 분석 (base: GOLD.FACT_MEMBER_DEV_ACHIEVEMENT). [Grain: 월 × 부서 × 개발구분]. [활성 지표: 월/연 목표건수, 실적건수, 달성률(%)]. [주의: 앵커_경합 방지, 달성률은 GOAL_CNT>0 스코프 필수]. [원천: GOLD.FACT_TARGET_MEMBER_DEV × FACT_MEMBER_EVENT].'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 시간 스코프: 월 목표/실적/달성율은 단일 연월 필터, 누계는 당해 연도 1월~기준월 필터, 연간은 연도 필터 적용 (별도 누계 metric 불필요). (2) 달성율 정본: 달성율은 항상 ACHIEVEMENT_RATE (%) 사용 (TOTAL_ACTUAL_CNT ÷ TOTAL_GOAL_CNT 직접 계산 금지). (3) 목표 0 처리: 목표 편성 부서 한정 시 HAS_POSITIVE_GOAL=TRUE 사용. (4) 주간 분기: 주간 개발실적은 SV_MEMBER_EVENT 로 라우팅하며, 주간 목표는 원천 부재로 산출 불가. (5) 판정 라벨 [앵커_경합]: 개발실적보고 주간 섹션은 경합 팩트가 동수이므로 하나를 골라 섹션 전체를 답하지 않는다 — 이 뷰(월 목표·달성율)와 SV_MEMBER_EVENT(주간 실적)·SV_MEMBER_FEE(회비)를 각각 호출해 연·월 축에서 병기하고 표마다 grain 을 밝힌다. 주간 목표 수치를 창작하지 않는다.'
	ai_verified_queries (
		VQR_DEPT_ACHIEVEMENT AS ( 
QUESTION '2025년 부서별 목표·실적·달성율' 
VERIFIED_BY '(DW = O190)'
SQL 'SELECT achv.ORG_DEPARTMENT, SUM(achv.GOAL_CNT) AS TOTAL_GOAL_CNT, SUM(achv.ACTUAL_CNT) AS TOTAL_ACTUAL_CNT, SUM(CASE WHEN achv.GOAL_CNT > 0 THEN achv.ACTUAL_CNT END) / NULLIF(SUM(achv.GOAL_CNT), 0) * 100 AS ACHIEVEMENT_RATE FROM achv WHERE achv.CAL_YEAR = 2025 AND achv.HAS_POSITIVE_GOAL GROUP BY achv.ORG_DEPARTMENT ORDER BY ACHIEVEMENT_RATE DESC NULLS LAST'),
		VQR_MONTHLY_GOAL_ACTUAL AS ( 
QUESTION '월별 개발 목표와 실적' 
VERIFIED_BY '(DW = O190)'
SQL 'SELECT achv.CAL_YEAR, achv.CAL_MONTH, SUM(achv.GOAL_CNT) AS TOTAL_GOAL_CNT, SUM(achv.ACTUAL_CNT) AS TOTAL_ACTUAL_CNT FROM achv GROUP BY achv.CAL_YEAR, achv.CAL_MONTH ORDER BY achv.CAL_YEAR, achv.CAL_MONTH')
	);