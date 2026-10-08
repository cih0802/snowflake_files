create or replace semantic view SV_MEMBER_MONTHLY_KPI
	tables (
		KPI as GN_DW.GOLD.WIDE_MEMBER_MONTHLY_KPI with synonyms=('회원 활동율','활동율 집계') comment='회원 월 지표 모집단 집계(grain = 월 × 신규기존). 🔴 행이 회원이 아니다 — 회원 속성으로 분해하지 않는다. 누계개발(건) = 당해년도 1월~조회월 개발(건) 합계(사용자 확정 2026-10-03).'
	)
	dimensions (
		KPI.MONTH_KEY as kpi.MONTH_KEY with synonyms=('연월','조회연월') comment='YYYYMM 정수 · 🔴 비율 지표는 한 달을 지정해 쓴다',
		KPI.CAL_YEAR as kpi.CAL_YEAR with synonyms=('연도','년') comment='연도(YYYY)',
		KPI.NEW_EXISTING_FLAG as kpi.NEW_EXISTING_FLAG with synonyms=('신규기존구분','신규/기존') comment='신규기존구분(공113) — 그 달 회원 행의 구분'
	)
	metrics (
		KPI.DEV_CUM_AMT_CNT_SUM as SUM(kpi.DEV_CUM_AMT_CNT) with synonyms=('누계개발(건)','누계개발건','당해년 누계개발') comment='누계개발(건) = 당해년도 1월~조회월의 개발(건) 합계 · 개발(건) = **MSTR 정의**(O202): 신규·재후원·증액 MSTR 인정금액 ÷ 10,000(활동(건)과 같은 단위). 🔴 한 달을 지정한다(누계라 여러 달을 더하지 않는다).',
		KPI.DEV_CUM_EVENT_CNT_SUM as SUM(kpi.DEV_CUM_CNT) with synonyms=('누계개발 회원월 경유') comment='참고 — 같은 MSTR 개발(건)을 회원 월 팩트(FMM) 경유로 누적한 값(O202 이후 정의 동일 · 신규기존 판정 경로만 다르다). 🔴 활동율 계산에는 DEV_CUM_AMT_CNT_SUM 을 쓴다.',
		KPI.ACTIVE_RATE as SUM(kpi.MONTH_END_ACTIVE_CNT) / NULLIF(SUM(kpi.YEAR_START_ACTIVE_CNT) + SUM(kpi.DEV_CUM_AMT_CNT), 0) * 100 with synonyms=('활동율','공45','전체회원 활동율') comment='공45 활동율(%) = 월말활동(건) ÷ (연도초활동(건) + 누계개발(건)) ×100. 비율(N). 🔴 한 달을 지정한다.',
		KPI.ACTIVE_RATE_NEW as SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '신규' THEN kpi.DEV_CUM_AMT_CNT END)
        / NULLIF(SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '신규' THEN kpi.ACTIVE_CNT END), 0) * 100 with synonyms=('신규 활동율','공46') comment='공46 신규 활동율(%) = 누계개발(건)[신규] ÷ 활동(건)[신규] ×100 — **지표 사전 원문 그대로**. 🟢 [O203 · 2026-10-06 현업 재회신] 원래 계산식이 맞다(O202 의 「오타」 판정 철회) · 🔴 **100% 를 넘는 값이 정상이다**(현업 확인) — 100% 초과를 오류·이상치로 설명하지 않는다. 비율(N). 🔴 한 달을 지정한다.',
		KPI.ACTIVE_RATE_EXISTING as SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '기존' THEN kpi.ACTIVE_CNT END)
        / NULLIF(SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '기존' THEN kpi.DEV_CUM_AMT_CNT + kpi.YEAR_START_ACTIVE_CNT END), 0) * 100 with synonyms=('기존 활동율','공47') comment='공47 기존 활동율(%) = 활동(건)[기존] ÷ (누계개발(건)[기존] + 연도초활동(건)[기존]) ×100. 비율(N). 🔴 한 달을 지정한다.'
	)
	comment='회원 활동율(공45·46·47) SV (base: GOLD.WIDE_MEMBER_MONTHLY_KPI · grain = 월 × 신규기존). 누계개발(건) = 당해년도 1월~조회월 개발(건) 합계. 🔴 회원 월 실적 상세(회비·미납 등)는 SV_MEMBER_MONTHLY 소관이며 두 SV 수치를 한 표에서 합산하지 않는다.'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.';