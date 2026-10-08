create or replace semantic view SV_TARGET_BIZ
	tables (
		TGT as GN_DW.GOLD.WIDE_TARGET_BIZ with synonyms=('사업목표','연사업목표','팀 목표','개발 목표','회원목표','회비목표') comment='사업목표 월별 분석 (base: GOLD.WIDE_TARGET_BIZ). [Grain: 월 × 목표유형 × 법인 × 팀 × 후원사업 × 원천 구분]. 🔴 목표유형(GOAL_TYPE)마다 단위가 다르다(건·명·원·비율) — 유형을 섞어 합산하지 말 것. [원천: CRM TM_CM_MBER_DVLP_GOAL_DIV → SILVER.CRM_BIZ_TARGET → GOLD.FACT_TARGET_PROJECT → GOLD.WIDE_TARGET_BIZ].'
	)
	dimensions (
		TGT.CAL_YEAR as tgt.CAL_YEAR with synonyms=('연도','년') comment='목표 연도',
		TGT.CAL_MONTH as tgt.CAL_MONTH with synonyms=('월') comment='목표 월(1~12)',
		TGT.MONTH_KEY as tgt.MONTH_KEY with synonyms=('연월') comment='목표 연월 YYYYMM',
		TGT.GOAL_TYPE as tgt.GOAL_TYPE_NM with synonyms=('목표유형','목표 지표','목표구분','후원사업 목표','회원개발 목표') comment='목표 지표 유형(원천 표기 그대로). 단위별: 건 = ''후원사업''(구 연사업 관점) · ''회원개발''(구 팀 관점 · 팀×세부구분 분해) / 명 = ''월말활동회원'' / 원 = ''정기회비'' / 비율 = ''후원사업활동율'' · ''신규기존활동율'' · ''후원사업납입율'' · ''신규기존납입율'' · ''신규기존누계납입율''. 🔴 후원사업·회원개발은 같은 개발 목표의 다른 분해이므로 합산 금지 — 반드시 하나로 필터하거나 나란히 보여줄 것.',
		TGT.CORP_DIV as tgt.CPR_DIV_NM with synonyms=('법인','법인구분','사단','사복') comment='법인구분. 원천 표기 그대로(사단/사복). 값 목록은 SELECT DISTINCT 로 조회한다 — 목표가 편성되지 않은 법인·구분의 0 을 실적 부진으로 해석하지 말 것.',
		TGT.TEAM_NAME as tgt.SRC_TEAM_NM with synonyms=('팀','팀명','부서','조직') comment='원천 팀명 그대로. 조직 차원과 이름이 일치하지 않는 값(동명 팀 · 조직명이 아닌 구분값)도 이 축으로 구분된다 — 팀별 질문은 이 축을 쓴다.',
		TGT.ORG_DEPARTMENT as tgt.ORG_DEPARTMENT with synonyms=('조직 차원 부서명') comment='조직 차원(DIM_ORG) 매칭 부서명. 활성 조직 트리에서 이름이 유일한 팀만 매칭되고 나머지는 ''(미매핑)''이다 — 팀별 합계는 TEAM_NAME 으로 답하고 이 축은 조직 경로 확인용으로만 쓴다.',
		TGT.ORG_PATH as tgt.ORG_PATH with synonyms=('조직 경로','부서 경로','상위 조직') comment='조직표 부서 경로(예: 본부 > 실 > 팀). 조직 차원 매칭 행만 값이 있고 나머지는 NULL.',
		TGT.SPONSOR_BIZ as tgt.SRC_SPONSOR_BIZ_NM with synonyms=('후원사업','사업','후원사업 그룹') comment='원천 후원사업 표기 그대로. 후원사업 유형 = 개별 후원사업명 · 회원개발 유형 = 후원사업 그룹(국내/결연/해외프로젝트/기타) — 🔴 두 유형의 값 체계가 다르므로 목표유형으로 먼저 나눈다. 비율 지표·월말활동회원·정기회비도 후원사업별 값이 있을 수 있다.',
		TGT.NEW_OLD_DIV as tgt.NEW_OLD_DIV_NM with synonyms=('신규기존','신규/기존') comment='신규/기존 구분 원천 표기. 값 = 신규 · 기존 · 🔴 소계 행 ''합계'' · ''신규합계''(비율 지표에만 있다) — 소계 행을 신규/기존과 함께 더하면 이중계상이다. 회원개발 유형은 NULL.',
		TGT.ORG_DIV as tgt.ORG_DIV_NM with synonyms=('조직구분','본부지부','본부/지부/대면') comment='조직구분 원천 표기(본부/지부/대면 계열). 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다.',
		TGT.DTL_DIV as tgt.DTL_DIV_NM with synonyms=('세부구분') comment='세부구분 원천 표기. 회원개발 유형에만 값이 있다.'
	)
	metrics (
		TGT.GOAL_CNT as SUM(CASE WHEN tgt.GOAL_TYPE_NM IN ('후원사업', '회원개발') THEN tgt.ANNUAL_GOAL_CNT END) with synonyms=('목표','목표건수','개발 목표(건)','월 목표(건)','사업목표','연사업목표(건)') comment='개발 목표 건수(당초). 단위=건. 후원사업·회원개발 유형만 집계. F(가산) — 🔴 GOAL_TYPE 안에서만 가산한다. 연 목표 = 해당 연도 월 목표의 합.',
		TGT.GOAL_MEMBER_CNT as SUM(CASE WHEN tgt.GOAL_TYPE_NM = '월말활동회원' THEN tgt.ANNUAL_GOAL_CNT END) with synonyms=('월말활동회원 목표','활동회원 목표','회원수 목표') comment='월말 활동회원 목표. 단위=명. S(잔량) — 월 안에서는 신규/기존·후원사업을 더할 수 있으나 🔴 월끼리 더하지 않는다(연 목표 = 12월 값).',
		TGT.GOAL_AMT as SUM(CASE WHEN tgt.GOAL_TYPE_NM = '정기회비' THEN tgt.ANNUAL_GOAL_CNT END) with synonyms=('정기회비 목표','회비 목표','목표 금액') comment='정기회비 목표 금액. 단위=원. F(가산) — 연 목표 = 월 목표의 합.',
		TGT.GOAL_RATE as AVG(CASE WHEN tgt.GOAL_TYPE_NM LIKE '%율' THEN tgt.ANNUAL_GOAL_CNT END) with synonyms=('목표율','활동율 목표','납입율 목표','누계납입율 목표') comment='목표 비율(0~1 · 1 = 100%). 유형 5종 = 후원사업활동율 · 신규기존활동율 · 후원사업납입율 · 신규기존납입율 · 신규기존누계납입율. N(비가산) — 🔴 GOAL_TYPE 1개 · NEW_OLD_DIV 1개 · 월 1개로 고정해 조회한다(평균은 고정 시 원값과 같다).'
	)
	comment='사업목표 SV. 목표 지표 9종을 단위별 metric(건·명·원·비율)으로 제공하며 유형을 섞어 합산하지 않는다. 추경 목표는 원천에 없어 제공하지 않는다. 실적 대비 달성률은 이 SV 에 없다(실적 팩트와 교차 집계 불가 · 부서 단위 달성률은 SV_DEV_ACHIEVEMENT).'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 목표유형: 모든 질의에 GOAL_TYPE 필터 또는 GOAL_TYPE 그룹핑을 반드시 포함한다. 건수 목표를 유형 지정 없이 물으면 GOAL_TYPE = ''후원사업'' 으로 필터한다(기본 관점 · 구 연사업 · 사용자 결정 N-24①) — 회원개발은 사용자가 팀·팀별·회원개발·채널을 말할 때만 쓰고, 두 값을 더한 총계 행은 만들지 않는다(ROLLUP 금지). (2) 단위별 metric 을 섞지 않는다: 건=GOAL_CNT · 명=GOAL_MEMBER_CNT · 원=GOAL_AMT · 비율=GOAL_RATE. (3) GOAL_MEMBER_CNT 는 월말 잔량이므로 여러 월을 더하지 않는다 — 연 목표는 12월 값, 기간 질의는 월별로 반환한다. (4) GOAL_RATE 는 GOAL_TYPE 1개로 필터하고 NEW_OLD_DIV 를 그룹핑하거나 하나로 필터한다 — 소계 행(합계·신규합계)과 신규/기존을 함께 평균·합산하지 않는다. 사용자가 전체 비율을 물으면 NEW_OLD_DIV = ''합계'' 행을 쓴다. 비율은 월별로 반환한다. (5) 팀별 질의는 TEAM_NAME, 후원사업별 질의는 SPONSOR_BIZ 를 쓰고 GOAL_TYPE 로 먼저 나눈다. (6) 기간 미지정 시 최신 연도를 월별로 반환한다. (7) 추경 목표·달성률 요청은 이 SV 로 만들지 않고 사유를 안내한다.';