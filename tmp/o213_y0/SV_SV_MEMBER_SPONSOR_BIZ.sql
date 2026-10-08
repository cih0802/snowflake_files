create or replace semantic view SV_MEMBER_SPONSOR_BIZ
	tables (
		FMSB as GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN with synonyms=('회원 후원약정','캠페인별 활동회원','후원사업별 활동회원') comment='회원×후원약정 기간 및 캠페인/사업별 활동회원 분석 (base: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN). [Grain: 회원 × 후원약정번호]. [활성 지표: 약정 활동회원수]. [주의: 전체 활동회원수 정본은 SV_MEMBER_MONTHLY 사용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].',
		SPONSORSHIP as GN_DW.GOLD.DIM_SPONSORSHIP primary key (SPONSORSHIP_SK) with synonyms=('후원사업 차원') comment='후원사업 마스터. PK 유일이라 조인이 행수를 늘리지 않는다.',
		CAMPAIGN as GN_DW.GOLD.DIM_CAMPAIGN primary key (CAMPAIGN_SK) with synonyms=('캠페인 차원') comment='캠페인 마스터. PK 유일이라 조인이 행수를 늘리지 않는다.'
	)
	relationships (
		FMSB_TO_CAMPAIGN as FMSB(CAMPAIGN_SK) references CAMPAIGN(CAMPAIGN_SK),
		FMSB_TO_SPONSORSHIP as FMSB(SPONSORSHIP_SK) references SPONSORSHIP(SPONSORSHIP_SK)
	)
	dimensions (
		FMSB.MEMBER_DK as fmsb.MEMBER_DK with synonyms=('회원번호') comment='회원 (불변키)',
		FMSB.SPNSR_BSNS_NO as fmsb.SPNSR_BSNS_NO with synonyms=('후원사업번호','약정번호') comment='회원별 후원약정 일련번호. 🔴단독 유일키 아니다 — 공동후원 쌍(부부 등)이 2개 회원에 공유되는 사례가 실재한다. 분류축이 아니다(분류는 SPONSORSHIP 축)',
		FMSB.ACQ_CMPGN_CTGR_NM as fmsb.ACQ_CMPGN_CTGR_NM with synonyms=('캠페인 카테고리','주요캠페인') comment='대표캠페인 카테고리 라벨(MM294). 🔴적재 시점 동결값(구 campaign.CAMPAIGN_TYPE 대체)',
		FMSB.IS_MULTI_CAMPAIGN as fmsb.IS_MULTI_CAMPAIGN with synonyms=('다중캠페인 여부') comment='참고용 투명성 플래그 — 이 SPNSR_BSNS_NO 의 전체 사건에서 캠페인이 2개 이상이었는지. 대표캠페인 채택 규칙과는 별개. 🟢실측상 극소수이며 최대 2개다(규모는 이슈원장·04 §0.9 참조)',
		FMSB.START_MONTH_KEY as fmsb.START_MONTH_KEY with synonyms=('활동개시월') comment='활동 개시 월키 YYYYMM. 특정월 as-of 활동 판정 시 이 축과 DSCNTC_MONTH_KEY 를 함께 WHERE 절로 비교한다(AI_SQL_GENERATION 참조)',
		FMSB.DSCNTC_MONTH_KEY as fmsb.DSCNTC_MONTH_KEY with synonyms=('중단월') comment='중단 월키 YYYYMM. 🔴NULL=미중단(현재까지 활동)이며 결측이 아니다',
		SPONSORSHIP.SPONSORSHIP as sponsorship.SPONSORSHIP_NAME with synonyms=('후원사업','후원사업명','사업') comment='후원사업명(마스터). 미매핑 없음(전건 매칭 실측 확인)',
		SPONSORSHIP.SPONSORSHIP_DIV as sponsorship.SPONSORSHIP_DIV_NAME with synonyms=('정기일시구분') comment='정기후원/일시후원 구분(CM035). 실제값 2종: ''정기후원''·''일시후원''.',
		SPONSORSHIP.SPONSORSHIP_ABBR_CATEGORY as sponsorship.SPONSORSHIP_GROUP_NAME with synonyms=('후원사업 약칭','후원사업 카테고리') comment='후원사업 약칭 그룹(CM003). 실제값 6종: ''결연''·''국내''·''기타''·''북한''·''해외''·''해외구호''.',
		CAMPAIGN.CAMPAIGN as campaign.CAMPAIGN_NAME with synonyms=('캠페인','캠페인명') comment='대표캠페인명. 판정 규칙 = CRM_MEMBER_DEV 사건 중 ①신규사건이 있으면 그 신규사건 ②없으면 최초사건(동률 0 확인). 사건 자체가 없는 약정은 "(미매핑)"(0). ⚠️단일 회원-grain 캠페인 분해(FACT_MEMBER_MONTHLY 기준)와는 다른 축이다 — 이 SV 는 약정grain 이라 값이 다르게 나올 수 있다'
	)
	metrics (
		FMSB.CURRENTLY_ACTIVE_MEMBERS as COUNT(DISTINCT IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.MEMBER_DK, NULL)) with synonyms=('지금 활동회원수','현재 활동회원') comment='**지금 시점** 활동회원수(명) = 미중단 약정을 보유한 고유회원. N(비가산). 🔴전체 활동회원수 정본은 SV_MEMBER_MONTHLY.ACTIVE_MEMBERS 다 — 이 metric 을 캠페인·후원사업으로 GROUP BY 하면 한 회원이 여러 축에 중복 집계될 수 있어 **합계가 전체보다 클 수 있다**(다중 후원 정상 현상). 특정 과거월 as-of 는 이 metric 이 아니라 START_MONTH_KEY·DSCNTC_MONTH_KEY 원시축으로 직접 WHERE 를 구성한다.',
		FMSB.TOTAL_REGISTRATIONS as COUNT(*) with synonyms=('약정건수','등록건수') comment='약정(SPNSR_BSNS_NO) 행수. F(가산). 🔴"명"이 아니다 — 회원당 여러 약정을 가질 수 있다',
		FMSB.DISTINCT_MEMBERS as COUNT(DISTINCT fmsb.MEMBER_DK) with synonyms=('고유회원수','약정보유회원수') comment='활동여부 무관, 이 팩트에 약정이 하나라도 있는 고유 회원수(명). N(비가산)',
		FMSB.CURRENTLY_ACTIVE_SPNSR_AMT as SUM(IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.SPNSR_AMT, 0)) with synonyms=('지금 활동 약정금액','현재 활동 후원금액') comment='**지금 시점** 미중단 약정의 SPNSR_AMT 합(원). F(가산). 🔴정본 (건) 표기로 바꾸려면 이 값을 만원 단위로 환산한다(CONF-2 규약) — 이 SV 는 원단위로 노출하고 환산은 소비 시 명시한다.',
		FMSB.TOTAL_SPNSR_AMT as SUM(fmsb.SPNSR_AMT) with synonyms=('약정금액 총계') comment='활동여부 무관 SPNSR_AMT 합(원). F(가산)'
	)
	comment='회원×후원약정 기간 및 캠페인/사업별 활동회원 분석 (base: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN). [Grain: 회원 × 후원약정번호]. [활성 지표: 약정 활동회원수]. [주의: 전체 활동회원수 정본은 SV_MEMBER_MONTHLY 사용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 활동회원 총계 vs 분해: 전체 활동회원수 총계는 SV_MEMBER_MONTHLY 로 라우팅. 캠페인별/후원사업별 분해 시에만 본 뷰의 CURRENTLY_ACTIVE_MEMBERS 사용. (2) 다중후원 안내: 캠페인/후원사업별 합계 > 전체 활동회원수(다중 후원 정상 현상)임을 명시. (3) 특정 과거월 as-of: 과거 특정월 활동 판정은 START_MONTH_KEY <= 월 AND (DSCNTC_MONTH_KEY IS NULL OR DSCNTC_MONTH_KEY > 월) 조건으로 직접 구성. (4) 회원 식별: 회원 식별은 항상 MEMBER_DK 기준.'
	ai_verified_queries (
		VQR_ACTIVE_BY_SPONSORSHIP AS ( 
QUESTION '후원사업별 지금 활동회원 수' 
VERIFIED_BY '(DW = O190)'
SQL 'SELECT sponsorship.SPONSORSHIP, COUNT(DISTINCT IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.MEMBER_DK, NULL)) AS CURRENTLY_ACTIVE_MEMBERS FROM fmsb LEFT JOIN sponsorship ON fmsb.SPONSORSHIP_SK = sponsorship.SPONSORSHIP_SK GROUP BY sponsorship.SPONSORSHIP ORDER BY CURRENTLY_ACTIVE_MEMBERS DESC NULLS LAST')
	);