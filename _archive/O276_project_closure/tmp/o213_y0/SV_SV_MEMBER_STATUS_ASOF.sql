create or replace semantic view SV_MEMBER_STATUS_ASOF
	tables (
		MSH as GN_DW.GOLD.DIM_MEMBER_STATUS_HISTORY primary key (MEMBER_SK) with synonyms=('회원상태 이력','과거 회원상태','상태 이력') comment='회원 상태 이력(SCD2 · 1행 = 회원 × 상태 유효구간). 「특정 과거 시점의 회원상태 분포」 질문용. [원천: CRM(eCRM) → BRONZE_CRM.TM_MM_FDRM_MBER_INFO·TH_MM_FDRM_MBER_STNG_DTLS → SILVER.CRM_MEMBER_STATUS_HIST → GOLD.DIM_MEMBER_STATUS_HISTORY]. 🔴 반드시 기준일 하나로 as-of 조건을 건다 — 조건 없이 세면 같은 회원의 여러 상태 버전이 모두 세어진다.'
	)
	dimensions (
		MSH.EFFECTIVE_FROM as msh.EFFECTIVE_FROM with synonyms=('상태 시작일','유효 시작일') comment='이 상태가 시작된 날. as-of 조건 = EFFECTIVE_FROM <= 기준일',
		MSH.EFFECTIVE_TO as msh.EFFECTIVE_TO with synonyms=('상태 종료일','유효 종료일') comment='이 상태가 끝난 날(다음 상태 시작일과 같은 날 · NULL = 현재 상태). 🔴 as-of 조건 = (EFFECTIVE_TO > 기준일 OR EFFECTIVE_TO IS NULL) — 「>=」 를 쓰면 경계일에 회원이 중복된다',
		MSH.IS_CURRENT as msh.IS_CURRENT with synonyms=('현재 상태 여부') comment='현재 유효 행 여부(회원당 TRUE 단일 행). 「지금」 질문은 이것으로 거른다',
		MSH.MEMBER_STATUS_NAME as msh.MEMBER_STATUS_NAME with synonyms=('회원상태','상태') comment='회원상태 라벨(MM010). 실제값 13종: ''활동회원''·''후원중단''·''신규미납1~5''·''장기미납1~5''·''(해당없음)''(일시회원). 🔴 이 라벨의 「활동회원」은 월실적 KPI 활동회원(월말 활동 약정 보유)과 정의가 다르다 — 두 수치를 비교·대체하지 않는다',
		MSH.MEMBER_STATUS_GROUP as msh.MEMBER_STATUS_GROUP with synonyms=('회원상태 그룹','상태 그룹') comment='회원상태 상위 그룹',
		MSH.PREV_MEMBER_STATUS_NAME as msh.PREV_MEMBER_STATUS_NAME with synonyms=('직전 회원상태','이전 상태') comment='이 상태 직전의 회원상태 라벨(상태 전환 분석용)',
		MSH.MEMBER_TYPE_NAME as msh.MEMBER_TYPE_NAME with synonyms=('회원구분') comment='회원구분 라벨(개인·기업·단체)',
		MSH.GENDER_NAME as msh.GENDER_NAME with synonyms=('성별') comment='성별 라벨',
		MSH.FIRST_JOIN_DATE as msh.FIRST_JOIN_DATE with synonyms=('최초가입일','가입일') comment='회원 최초가입일',
		MSH.FIRST_JOIN_YEAR as YEAR(msh.FIRST_JOIN_DATE) with synonyms=('가입연도') comment='회원 최초가입 연도'
	)
	metrics (
		MSH.MEMBER_COUNT as COUNT(DISTINCT msh.MEMBER_DK) with synonyms=('회원수','회원 수','명') comment='고유 회원수(명). D(distinct). 🔴 as-of 조건(기준일 1개)을 건 상태에서만 의미가 있다.'
	)
	comment='과거 시점 회원상태 SV(🆕 O203). 「2025년 6월 말 기준 회원상태별 회원수」처럼 기준일을 정한 질문에 쓴다. 월별 활동회원 KPI·회비·개발 실적은 다른 SV 소관이며 한 표에 합산하지 않는다.'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 반드시 기준일 하나를 정해 WHERE msh.EFFECTIVE_FROM <= 기준일 AND (msh.EFFECTIVE_TO > 기준일 OR msh.EFFECTIVE_TO IS NULL) 를 건다. 「○월 말」은 그 달 말일을 기준일로 쓴다. (2) 「지금·현재」는 msh.IS_CURRENT = TRUE 로 거른다. (3) 회원수는 COUNT(DISTINCT msh.MEMBER_DK) 만 쓴다. (4) 여러 기준일을 비교하면 기준일별로 따로 집계해 나란히 보여주고 더하지 않는다. (5) ORDER BY 에는 SELECT 별칭을 그대로 쓴다.'
	ai_verified_queries (
		VQR_O203_STATUS_ASOF AS ( 
QUESTION '2026년 6월 말 기준 회원상태별 회원수' 
VERIFIED_BY '(DW = O203 · 활동회원 681,134 · 후원중단 854,378)'
SQL 'SELECT msh.MEMBER_STATUS_NAME, COUNT(DISTINCT msh.MEMBER_DK) AS MEMBER_COUNT FROM msh WHERE msh.EFFECTIVE_FROM <= ''2026-06-30'' AND (msh.EFFECTIVE_TO > ''2026-06-30'' OR msh.EFFECTIVE_TO IS NULL) GROUP BY msh.MEMBER_STATUS_NAME ORDER BY MEMBER_COUNT DESC')
	);