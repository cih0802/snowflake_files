-- PoC 당시 생성한 Cortex Analyst 시맨틱 뷰(SV_*) 7종의 DDL 백업

-- 납입이력 분석 시맨틱뷰: 캠페인별 납입/미납/평균회비를 회원특성과 연계 (V_PAYMENT_ANALYSIS 기반)
create or replace semantic view SV_PAYMENT_ANALYSIS
	tables (
		PAYMENT as GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS comment='납입이력+캠페인+회원특성 통합.'
	)
	facts (
		PAYMENT.BILLED_AMT as "청구금액" with synonyms=('청구금액') comment='청구금액(원).',
		PAYMENT.HAS_PARENT_CAMPAIGN labels = (filter) as "상위캠페인명" IS NOT NULL comment='상위캠페인명이 있는 건만 필터. 캠페인별 분석 질문 시 기본 적용.',
		PAYMENT.PAID_AMT as "납입금액" with synonyms=('납입금액','회비') comment='납입금액(원).',
		PAYMENT.UNPAID_AMT as "미납금액" with synonyms=('미납금액') comment='미납금액(원)=청구-납입.'
	)
	dimensions (
		PAYMENT.AGE_GROUP as "연령대" with synonyms=('연령대') comment='연령대.',
		PAYMENT.BILLING_MONTH as "회비청구월" with synonyms=('청구월','회비청구월') comment='회비청구월(YYYYMM).',
		PAYMENT.BILLING_YEAR as "청구연도" with synonyms=('연도','청구연도') comment='청구연도(YYYY).',
		PAYMENT.BRAND_NAME as "브랜드명" with synonyms=('브랜드','브랜드명') comment='브랜드명.',
		PAYMENT.COMMON_BRAND_NAME as "공통브랜드명" with synonyms=('공통브랜드','공통브랜드명') comment='공통브랜드명. 브랜드를 통합 재분류한 상위 그룹.',
		PAYMENT.COMMON_PARENT_CAMPAIGN as "공통상위캠페인명" with synonyms=('공통상위캠페인','공통상위캠페인명','공통캠페인') comment='공통상위캠페인명. 상위캠페인을 통합 재분류한 그룹.',
		PAYMENT.DEV_TYPE as "개발구분" with synonyms=('개발구분','신규','재후원','증액') comment='개발구분. 신규회원 분석 시 개발구분=''신규'' 필터 적용.',
		PAYMENT.DOMESTIC_OVERSEAS as "국내해외구분" with synonyms=('국내/해외','국내해외','국내해외구분') comment='국내해외구분.',
		PAYMENT.GENDER as "성별" with synonyms=('성별') comment='성별.',
		PAYMENT.MEMBER_ID as "회원번호" with synonyms=('회원번호') comment='회원번호.',
		PAYMENT.PARENT_CAMPAIGN as "상위캠페인명" with synonyms=('상위캠페인','상위캠페인명','캠페인') comment='상위캠페인명. 약 79%가 NULL일 수 있으므로, 캠페인별 분석 시 반드시 IS NOT NULL 조건 적용.',
		PAYMENT.PAY_TYPE as "납입구분" with synonyms=('납입구분') comment='납입/미납/환불 등.',
		PAYMENT.REGION_NAME as "지역" with synonyms=('지역') comment='지역.',
		PAYMENT.SUB_CAMPAIGN as "세부캠페인명" with synonyms=('세부캠페인','세부캠페인명') comment='세부캠페인명.'
	)
	metrics (
		PAYMENT.AVG_PAID as AVG(payment.paid_amt) with synonyms=('평균납입금액','평균회비') comment='평균납입금액(원).',
		PAYMENT.PAYMENT_COUNT as COUNT(*) with synonyms=('납입건수') comment='납입건수.',
		PAYMENT.TOTAL_BILLED as SUM(payment.billed_amt) with synonyms=('총청구금액') comment='총청구금액(원).',
		PAYMENT.TOTAL_PAID as SUM(payment.paid_amt) with synonyms=('총납입금액','총회비') comment='총납입금액(원).',
		PAYMENT.TOTAL_UNPAID as SUM(payment.unpaid_amt) with synonyms=('총미납금액') comment='총미납금액(원).',
		PAYMENT.UNPAID_RATIO as CASE WHEN SUM(payment.billed_amt) > 0 THEN ROUND(SUM(payment.unpaid_amt)*100.0/SUM(payment.billed_amt),1) ELSE 0 END with synonyms=('미납비중','미납율') comment='미납비중(%)=미납/청구*100.'
	)
	comment='납입이력 분석. 캠페인별 납입금액/미납비중/평균회비. 회원특성(성별,연령대,지역) 연계. 캠페인별 분석 시 상위캠페인명 IS NOT NULL 필터 필수. 신규회원 분석 시 개발구분=''신규'' 필터 사용.'
	ai_verified_queries (
		"납입회비_높은_캠페인" AS ( 
QUESTION '2025년 납입회비가 가장 높았던 캠페인과 가장 낮은 캠페인은?'
ONBOARDING_QUESTION false
SQL 'SELECT "상위캠페인명", SUM("납입금액") AS "총납입금액", AVG("납입금액") AS "평균납입금액" FROM GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS WHERE "청구연도" = ''2025'' AND "납입금액" > 0 AND "상위캠페인명" IS NOT NULL GROUP BY "상위캠페인명" HAVING COUNT(*) >= 10 ORDER BY "총납입금액" DESC'), 
		"납입회비_상위10%_캠페인" AS ( 
QUESTION '2025년 납입회비가 높았던 상위 10% 캠페인은 어떤 유입경로, 타겟 조합을 가졌는가?' 
ONBOARDING_QUESTION false
SQL 'WITH ranked AS (SELECT "상위캠페인명", SUM("납입금액") AS "총납입금액", PERCENT_RANK() OVER (ORDER BY SUM("납입금액") DESC) AS pct FROM GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS WHERE "청구연도" = ''2025'' AND "납입금액" > 0 AND "상위캠페인명" IS NOT NULL GROUP BY "상위캠페인명" HAVING COUNT(*) >= 10) SELECT * FROM ranked WHERE pct <= 0.10 ORDER BY "총납입금액" DESC'),
		"미납비중_높은_세부캠페인" AS ( 
QUESTION '2025년 미납비중이 가장 높은 세부캠페인 상위 3개와 해당 캠페인들의 회원특성(연령대,성별,지역)은?' 
ONBOARDING_QUESTION false
SQL 'WITH top3 AS (SELECT "세부캠페인명", SUM("미납금액") AS "총미납", SUM("청구금액") AS "총청구", ROUND(SUM("미납금액")*100.0/NULLIF(SUM("청구금액"),0),1) AS "미납비중" FROM GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS WHERE "청구연도" = ''2025'' AND "청구금액" > 0 AND "상위캠페인명" IS NOT NULL GROUP BY "세부캠페인명" HAVING COUNT(*) >= 50 ORDER BY "미납비중" DESC LIMIT 3) SELECT t."세부캠페인명", t."미납비중", p."연령대", p."성별", p."지역", COUNT(*) AS "건수" FROM top3 t JOIN GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS p ON t."세부캠페인명" = p."세부캠페인명" WHERE p."청구연도" = ''2025'' GROUP BY t."세부캠페인명", t."미납비중", p."연령대", p."성별", p."지역" ORDER BY t."세부캠페인명", "건수" DESC'),
		"월별_납입추이" AS ( 
QUESTION '2025년 월별 납입금액 추이는?'
ONBOARDING_QUESTION false
SQL 'SELECT "회비청구월", SUM("납입금액") AS "총납입금액", COUNT(DISTINCT "회원번호") AS "회원수" FROM GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS WHERE "청구연도" = ''2025'' AND "납입구분" = ''납입'' GROUP BY "회비청구월" ORDER BY "회비청구월"'), 
		"상위캠페인별_납입회비" AS ( 
QUESTION '2025년 상위캠페인별 납입회비금액을 분석해줘' 
ONBOARDING_QUESTION false
SQL 'SELECT "상위캠페인명" AS "상위캠페인", SUM("납입금액") AS "총납입금액(원)", AVG("납입금액") AS "평균납입금액(원)", COUNT(DISTINCT "회원번호") AS "회원수" FROM GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS WHERE "청구연도" = ''2025'' AND "상위캠페인명" IS NOT NULL AND "납입금액" > 0 GROUP BY "상위캠페인명" ORDER BY "총납입금액(원)" DESC'), 
		"공통브랜드별_신규회원_납입" AS ( 
QUESTION '2025년 공통브랜드별 신규회원의 총납입금액을 알려줘'
ONBOARDING_QUESTION false
SQL 'SELECT "공통브랜드명", SUM("납입금액") AS "총납입금액", COUNT(DISTINCT "회원번호") AS "회원수" FROM GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS WHERE "청구연도" = ''2025'' AND "개발구분" = ''신규'' AND "공통브랜드명" IS NOT NULL GROUP BY "공통브랜드명" ORDER BY "총납입금액" DESC'), 
		"공통상위캠페인별_납입분석" AS ( 
QUESTION '2025년 공통상위캠페인명별 총납입금액과 평균납입금액을 알려줘'
ONBOARDING_QUESTION false
SQL 'SELECT "공통상위캠페인명", SUM("납입금액") AS "총납입금액", AVG("납입금액") AS "평균납입금액", COUNT(DISTINCT "회원번호") AS "회원수" FROM GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS WHERE "청구연도" = ''2025'' AND "납입금액" > 0 AND "공통상위캠페인명" IS NOT NULL GROUP BY "공통상위캠페인명" ORDER BY "총납입금액" DESC'), 
		"국내해외_납입비교" AS ( 
QUESTION '2025년 국내해외구분별 총납입금액과 미납비중을 비교해줘'
ONBOARDING_QUESTION false
SQL 'SELECT "국내해외구분", SUM("납입금액") AS "총납입금액", SUM("청구금액") AS "총청구금액", ROUND(SUM("미납금액")*100.0/NULLIF(SUM("청구금액"),0),1) AS "미납비중(%)", COUNT(DISTINCT "회원번호") AS "회원수" FROM GN_DW_POC.ANALYTICS.V_PAYMENT_ANALYSIS WHERE "청구연도" = ''2025'' GROUP BY "국내해외구분" ORDER BY "총납입금액" DESC') 
	)
	with extension (CA='{"tables":[{"name":"PAYMENT","dimensions":[{"name":"AGE_GROUP"},{"name":"BILLING_MONTH"},{"name":"BILLING_YEAR"},{"name":"BRAND_NAME"},{"name":"COMMON_BRAND_NAME"},{"name":"COMMON_PARENT_CAMPAIGN"},{"name":"DEV_TYPE"},{"name":"DOMESTIC_OVERSEAS"},{"name":"GENDER"},{"name":"MEMBER_ID"},{"name":"PARENT_CAMPAIGN"},{"name":"PAY_TYPE","is_enum":true},{"name":"REGION_NAME"},{"name":"SUB_CAMPAIGN"}],"facts":[{"name":"BILLED_AMT"},{"name":"HAS_PARENT_CAMPAIGN"},{"name":"PAID_AMT"},{"name":"UNPAID_AMT"}],"metrics":[{"name":"AVG_PAID"},{"name":"PAYMENT_COUNT"},{"name":"TOTAL_BILLED"},{"name":"TOTAL_PAID"},{"name":"TOTAL_UNPAID"},{"name":"UNPAID_RATIO"}]}]}');
-- 회원 라이프사이클 시맨틱뷰: 중단회원 상세·미납이력·일시→정기 전환을 통합 분석
create or replace semantic view SV_MEMBER_LIFECYCLE
	tables (
		DISCONTINUED as GN_DW_POC.ANALYTICS.V_DISCONTINUED_DETAIL comment='중단회원 상세. 유지일수/유지개월수 포함. 가입일자/중단일자 DATE컬럼 및 주차(WEEKOFYEAR) 포함.',
		DISC_PAYMENT as GN_DW_POC.ANALYTICS.V_DISCONTINUED_PAYMENT_ANALYSIS comment='중단회원 미납이력 교차분석. 유지기간구간별 중단사유와 미납비율 분석 가능.',
		CONVERSION as GN_DW_POC.ANALYTICS.V_TEMP_MEMBER_CONVERSION comment='일시회원→정기회원 전환.'
	)
	facts (
		DISCONTINUED.SPONSOR_AMT as "후원금액" with synonyms=('후원금액') comment='후원금액(원).',
		DISCONTINUED.RETAIN_DAYS as "유지일수" with synonyms=('유지일수') comment='가입~중단 유지일수.',
		DISCONTINUED.RETAIN_MONTHS as "유지개월수" with synonyms=('유지개월수','유지기간') comment='가입~중단 유지개월수.',
		DISC_PAYMENT.DP_UNPAID_COUNT as "미납건수" with synonyms=('미납건수') comment='미납건수.',
		DISC_PAYMENT.DP_TOTAL_BILLED as "총청구건수" with synonyms=('총청구건수') comment='총청구건수.',
		DISC_PAYMENT.DP_UNPAID_RATIO as "미납비율" with synonyms=('미납비율') comment='미납비율(%).',
		DISC_PAYMENT.DP_RETAIN_MONTHS as "유지개월수" with synonyms=('유지개월수') comment='유지개월수.',
		CONVERSION.TEMP_DONATION_AMT as "일시후원금액" with synonyms=('일시후원금액') comment='일시후원금액(원).'
	)
	dimensions (
		DISCONTINUED.MEMBER_ID as "회원번호" with synonyms=('회원번호') comment='회원번호.',
		DISCONTINUED.JOIN_YEAR as "가입연도" with synonyms=('가입연도') comment='가입연도(YYYY).',
		DISCONTINUED.DISC_YEAR as "중단연도" with synonyms=('중단연도') comment='중단연도(YYYY).',
		DISCONTINUED.JOIN_MONTH as "가입월" with synonyms=('가입월') comment='가입월(YYYYMM).',
		DISCONTINUED.DISC_MONTH as "중단월" with synonyms=('중단월') comment='중단월(YYYYMM).',
		DISCONTINUED.DISC_REASON as "중단사유" with synonyms=('중단사유') comment='중단사유.',
		DISCONTINUED.SUB_CAMPAIGN as "세부캠페인명" with synonyms=('세부캠페인명','가입캠페인','캠페인') comment='가입세부캠페인명.',
		DISCONTINUED.BRAND_NAME as "브랜드" with synonyms=('브랜드명','브랜드') comment='브랜드.',
		DISCONTINUED.PARENT_CAMPAIGN as "상위캠페인" with synonyms=('상위캠페인') comment='상위캠페인.',
		DISCONTINUED.PAY_METHOD as "납입방식" with synonyms=('납입방식') comment='납입방식.',
		DISCONTINUED.GENDER as "성별" with synonyms=('성별') comment='성별.',
		DISCONTINUED.AGE_GROUP as "연령대" with synonyms=('연령대') comment='연령대.',
		DISCONTINUED.REGION_NAME as "지역" with synonyms=('지역') comment='지역.',
		DISCONTINUED.JOIN_DATE as "가입일자" with synonyms=('가입일자','가입날짜') comment='가입일자(DATE 타입, YYYY-MM-DD). 일자단위 필터 가능.',
		DISCONTINUED.DISC_DATE as "중단일자" with synonyms=('중단일자','중단날짜') comment='중단일자(DATE 타입, YYYY-MM-DD). 일자단위 필터 가능.',
		DISCONTINUED.DISC_WEEK as "중단주차_연도내" with synonyms=('중단주차','주차') comment='중단일의 해당연도 내 주차번호(WEEKOFYEAR). 주간리포트에 사용.',
		DISCONTINUED.MEMBER_CLASS as "회원분류" with synonyms=('회원분류','신규기존') comment='회원분류(신규/기존). 가입연도=중단연도면 신규, 아니면 기존.',
		DISC_PAYMENT.DP_MEMBER_ID as "회원번호" with synonyms=('회원번호') comment='회원번호.',
		DISC_PAYMENT.DP_RETAIN_SEGMENT as "유지기간구간" with synonyms=('유지기간구간') comment='유지기간구간(0~3개월/4~6개월/7~12개월/12개월이상).',
		DISC_PAYMENT.DP_DISC_REASON as "중단사유" with synonyms=('중단사유') comment='중단사유.',
		DISC_PAYMENT.DP_DISC_YEAR as "중단연도" with synonyms=('중단연도') comment='중단연도.',
		DISC_PAYMENT.DP_PARENT_CAMPAIGN as "상위캠페인" with synonyms=('상위캠페인') comment='상위캠페인.',
		DISC_PAYMENT.DP_MEMBER_CLASS as "회원분류" with synonyms=('회원분류') comment='신규/기존.',
		CONVERSION.CONV_DATE as "전환일" with synonyms=('전환일') comment='전환일.',
		CONVERSION.REGULAR_CAMPAIGN as "정기상위캠페인명" with synonyms=('정기상위캠페인명','정기캠페인') comment='정기가입 상위캠페인.',
		CONVERSION.REGULAR_MEMBER as "정기회원번호" with synonyms=('정기회원번호') comment='정기회원번호.',
		CONVERSION.REGULAR_SUB_CAMP as "정기세부캠페인명" with synonyms=('정기세부캠페인명') comment='정기가입 세부캠페인.',
		CONVERSION.TEMP_CAMPAIGN as "일시세부캠페인명" with synonyms=('일시세부캠페인명','일시캠페인') comment='일시후원 세부캠페인.',
		CONVERSION.TEMP_MEMBER as "일시회원번호" with synonyms=('일시회원번호') comment='일시회원번호.'
	)
	metrics (
		DISCONTINUED.DISC_COUNT as COUNT(*) with synonyms=('중단건수','중단회원수') comment='중단건수.',
		DISCONTINUED.AVG_RETAIN_MONTHS as AVG(discontinued.retain_months) with synonyms=('평균유지기간','평균유지개월수') comment='평균유지개월수.',
		DISCONTINUED.AVG_RETAIN_DAYS as AVG(discontinued.retain_days) with synonyms=('평균유지일수') comment='평균유지일수.',
		DISC_PAYMENT.DP_AVG_UNPAID_RATIO as AVG(disc_payment.dp_unpaid_ratio) with synonyms=('평균미납비율') comment='평균미납비율.',
		DISC_PAYMENT.DP_DISC_COUNT as COUNT(*) with synonyms=('중단건수') comment='중단건수.',
		CONVERSION.CONV_COUNT as COUNT(*) with synonyms=('전환건수','전환수') comment='일시→정기 전환건수.',
		CONVERSION.AVG_TEMP_DONATION as AVG(conversion.temp_donation_amt) with synonyms=('평균일시후원금액') comment='평균일시후원금액(원).'
	)
	comment='회원 라이프사이클 분석. 중단회원 상세(유지기간/캠페인별/사유/미납이력). 일시→정기 전환 분석. 일자(DATE)단위 데이터 포함.'
	ai_verified_queries (
		"고려인_캠페인_유지기간" AS ( 
QUESTION '2025년 중단회원 중 고려인 캠페인으로 가입한 회원들의 가입 후 유지기간은?'
ONBOARDING_QUESTION false
SQL 'SELECT "세부캠페인명", COUNT(*) AS "중단건수", ROUND(AVG("유지개월수"),1) AS "평균유지개월수", ROUND(AVG("유지일수"),0) AS "평균유지일수" FROM GN_DW_POC.ANALYTICS.V_DISCONTINUED_DETAIL WHERE "중단연도" = ''2025'' AND "세부캠페인명" LIKE ''%고려인%'' GROUP BY "세부캠페인명" ORDER BY "평균유지개월수" DESC'), 
		"중단사유별_현황" AS ( 
QUESTION '2025년 중단사유별 중단회원수는?' 
ONBOARDING_QUESTION false
SQL 'SELECT "중단사유", COUNT(*) AS "중단건수", ROUND(AVG("유지개월수"),1) AS "평균유지개월수" FROM GN_DW_POC.ANALYTICS.V_DISCONTINUED_DETAIL WHERE "중단연도" = ''2025'' GROUP BY "중단사유" ORDER BY "중단건수" DESC'),
		"주간_중단리포트" AS ( 
QUESTION '2026년 1월 2주차 중단회원 리포트를 보여줘' 
ONBOARDING_QUESTION false
SQL 'SELECT "회원분류", COUNT(*) AS "중단건수", ROUND(AVG("후원금액"),0) AS "평균후원금액", ROUND(AVG("유지개월수"),1) AS "평균유지개월수" FROM GN_DW_POC.ANALYTICS.V_DISCONTINUED_DETAIL WHERE "중단연도" = ''2026'' AND "중단월" = ''202601'' AND "중단주차_연도내" = 2 GROUP BY "회원분류"'), 
		"구간별_중단사유_미납" AS ( 
QUESTION '고려인 캠페인 유지기간 구간별 중단사유, 미납이력에 차이가 있나?' 
ONBOARDING_QUESTION false
SQL 'SELECT "유지기간구간", "중단사유", COUNT(*) AS "중단건수", ROUND(AVG("미납비율"),1) AS "평균미납비율", ROUND(AVG("미납건수"),1) AS "평균미납건수" FROM GN_DW_POC.ANALYTICS.V_DISCONTINUED_PAYMENT_ANALYSIS WHERE "중단연도" = ''2025'' AND "세부캠페인명" LIKE ''%고려인%'' GROUP BY "유지기간구간", "중단사유" ORDER BY "유지기간구간", "중단건수" DESC')
	)
	with extension (CA='{"tables":[{"name":"DISCONTINUED","dimensions":[{"name":"MEMBER_ID"},{"name":"JOIN_YEAR"},{"name":"DISC_YEAR"},{"name":"JOIN_MONTH"},{"name":"DISC_MONTH"},{"name":"DISC_REASON"},{"name":"SUB_CAMPAIGN"},{"name":"BRAND_NAME"},{"name":"PARENT_CAMPAIGN"},{"name":"PAY_METHOD"},{"name":"GENDER"},{"name":"AGE_GROUP"},{"name":"REGION_NAME"},{"name":"JOIN_DATE"},{"name":"DISC_DATE"},{"name":"DISC_WEEK"},{"name":"MEMBER_CLASS"}],"facts":[{"name":"SPONSOR_AMT"},{"name":"RETAIN_DAYS"},{"name":"RETAIN_MONTHS"}],"metrics":[{"name":"DISC_COUNT"},{"name":"AVG_RETAIN_MONTHS"},{"name":"AVG_RETAIN_DAYS"}]},{"name":"DISC_PAYMENT","dimensions":[{"name":"DP_MEMBER_ID"},{"name":"DP_RETAIN_SEGMENT","is_enum":true},{"name":"DP_DISC_REASON"},{"name":"DP_DISC_YEAR"},{"name":"DP_PARENT_CAMPAIGN"},{"name":"DP_MEMBER_CLASS"}],"facts":[{"name":"DP_UNPAID_COUNT"},{"name":"DP_TOTAL_BILLED"},{"name":"DP_UNPAID_RATIO"},{"name":"DP_RETAIN_MONTHS"}],"metrics":[{"name":"DP_AVG_UNPAID_RATIO"},{"name":"DP_DISC_COUNT"}]},{"name":"CONVERSION","dimensions":[{"name":"CONV_DATE"},{"name":"REGULAR_CAMPAIGN"},{"name":"REGULAR_MEMBER"},{"name":"REGULAR_SUB_CAMP"},{"name":"TEMP_CAMPAIGN"},{"name":"TEMP_MEMBER"}],"facts":[{"name":"TEMP_DONATION_AMT"}],"metrics":[{"name":"CONV_COUNT"},{"name":"AVG_TEMP_DONATION"}]}]}');
-- 회원개발 종합 시맨틱뷰: 개발실적 상세·중단·기간별 유지율을 캠페인 기준으로 연계
create or replace semantic view SV_MEMBER_DEVELOPMENT
	tables (
		DEV_DETAIL as GN_DW_POC.ANALYTICS.V_MEMBER_DEV_DETAIL comment='회원 개발 상세이력.',
		DISCONTINUATION as GN_DW_POC.ANALYTICS.V_DISCONTINUATION_REPORT comment='중단회원.',
		RETENTION as GN_DW_POC.ANALYTICS.V_RETENTION_BY_PERIOD comment='캠페인별 유지율. 중단테이블 교차 반영. 가입연도 필터 가능.'
	)
	facts (
		DEV_DETAIL.AMOUNT as "금액" with synonyms=('금액','약정금액') comment='약정금액(원).',
		DEV_DETAIL.DEV_PERF as "개발실적_건" with synonyms=('개발건','개발건수','개발실적') comment='개발실적(건) = 후원금액 ÷ 10,000. 이미 건수 환산 완료된 값. 사용자가 ''개발건수는 후원금액/10000으로 해줘''라고 해도 추가 나눗셈 하지 말 것.',
		DEV_DETAIL.NEW_DEV_ONLY labels = (filter) as "개발구분" IN ('신규','증액','재후원') comment='신규/증액/재후원만',
		RETENTION.RET_12M as "12개월유지율" with synonyms=('12개월유지율') comment='12개월유지율(%).',
		RETENTION.RET_3M as "3개월유지율" with synonyms=('3개월유지율') comment='3개월유지율(%). 중단시 중단일까지만 계산.',
		RETENTION.RET_AVG_MONTHS as "평균활동개월수" with synonyms=('평균활동개월수') comment='평균활동개월수. 중단시 가입~중단일, 유지시 가입~현재.',
		RETENTION.RET_CURRENT as "현재유지율" with synonyms=('현재유지율') comment='현재유지율(%). 중단테이블 교차반영.',
		RETENTION.RET_DISC_CNT as "중단자수" with synonyms=('중단자수') comment='중단자수.',
		RETENTION.RET_TOTAL as "총가입자수" with synonyms=('총가입자수') comment='총가입자수.'
	)
	dimensions (
		DEV_DETAIL.AGE_GROUP as "연령대" with synonyms=('연령대') comment='연령대.',
		DEV_DETAIL.APPLY_MONTH as "신청월" with synonyms=('기준월','신청월','월') comment='신청월(YYYYMM).',
		DEV_DETAIL.BRAND_NAME as "브랜드명" with synonyms=('브랜드','브랜드명') comment='브랜드명.',
		DEV_DETAIL.COMMON_BRAND_NAME as "공통브랜드명" with synonyms=('공통브랜드','공통브랜드명') comment='공통브랜드명. 브랜드를 통합 재분류한 상위 그룹.',
		DEV_DETAIL.COMMON_PARENT_CAMPAIGN as "공통상위캠페인명" with synonyms=('공통상위캠페인','공통상위캠페인명','공통캠페인') comment='공통상위캠페인명. 상위캠페인을 통합 재분류한 그룹.',
		DEV_DETAIL.DEPT_NAME as "실적부서명" with synonyms=('부서','실적부서명') comment='실적부서명.',
		DEV_DETAIL.DEV_TYPE as "개발구분" with synonyms=('개발구분','개발유형','신규','재후원','증액') comment='신규/증액/재후원/후원중단/감액. 신규회원 분석 시 개발구분=''신규'' 필터 적용.',
		DEV_DETAIL.DOMESTIC_OVERSEAS as "국내해외구분" with synonyms=('국내/해외','국내해외','국내해외구분') comment='국내해외구분.',
		DEV_DETAIL.GENDER as "성별" with synonyms=('성별') comment='성별.',
		DEV_DETAIL.MEMBER_ID as "회원번호" with synonyms=('회원번호') comment='회원번호.',
		DEV_DETAIL.PARENT_CAMPAIGN as "상위캠페인명" with synonyms=('상위캠페인','상위캠페인명') comment='상위캠페인명.',
		DEV_DETAIL.REGION as "지역" with synonyms=('지역') comment='지역.',
		DEV_DETAIL.SUB_CAMPAIGN as "세부캠페인명" with synonyms=('세부캠페인','세부캠페인명','캠페인명') comment='세부캠페인명.',
		DISCONTINUATION.DISC_COMMON_BRAND as "공통브랜드명" with synonyms=('중단공통브랜드') comment='중단 공통브랜드명.',
		DISCONTINUATION.DISC_COMMON_PARENT as "공통상위캠페인명" with synonyms=('중단공통상위캠페인') comment='중단 공통상위캠페인명.',
		DISCONTINUATION.DISC_DOMESTIC_OVERSEAS as "국내해외구분" with synonyms=('중단국내해외') comment='중단 국내해외구분.',
		DISCONTINUATION.DISC_MONTH as "중단월" with synonyms=('중단월') comment='중단월.',
		RETENTION.RET_COMMON_BRAND as "공통브랜드명" with synonyms=('유지율공통브랜드') comment='유지율 공통브랜드명.',
		RETENTION.RET_COMMON_PARENT as "공통상위캠페인명" with synonyms=('유지율공통상위캠페인') comment='유지율 공통상위캠페인명.',
		RETENTION.RET_DOMESTIC_OVERSEAS as "국내해외구분" with synonyms=('유지율국내해외') comment='유지율 국내해외구분.',
		RETENTION.RET_PARENT as "상위캠페인명" with synonyms=('상위캠페인','유지율캠페인') comment='유지율상위캠페인.',
		RETENTION.RET_YEAR as "가입연도" with synonyms=('가입연도') comment='가입연도(YYYY).'
	)
	metrics (
		DEV_DETAIL.TOTAL_AMOUNT as SUM(dev_detail.amount) with synonyms=('총금액') comment='총개발금액(원).',
		DEV_DETAIL.TOTAL_COUNT as COUNT(*) with synonyms=('개발건수','총건수') comment='총개발건수.',
		DISCONTINUATION.M_DISC as COUNT("회원번호") with synonyms=('중단회원수') comment='중단회원수.',
		RETENTION.M_AVG_MONTHS as AVG(retention.ret_avg_months) with synonyms=('평균활동개월수') comment='평균활동개월수.',
		RETENTION.M_RET_CURRENT as AVG(retention.ret_current) with synonyms=('현재유지율') comment='현재유지율.',
		RETENTION.M_RET12 as AVG(retention.ret_12m) with synonyms=('12개월유지율') comment='12개월유지율.'
	)
	comment='회원개발 종합분석. 유지율은 중단테이블 교차 반영. 가입연도 필터 필수. 개발실적_건 = 후원금액÷10000(이미 환산완료). 신규회원 분석 시 개발구분=''신규'' 필터 사용.'
	ai_verified_queries (
		"캠페인별_신규개발" AS ( 
QUESTION '2025년 상위캠페인별 신규 개발건수는?'
ONBOARDING_QUESTION false
SQL 'SELECT "상위캠페인명", COUNT(*) AS "개발건수" FROM GN_DW_POC.ANALYTICS.V_MEMBER_DEV_DETAIL WHERE "개발구분" = ''신규'' AND "신청월" LIKE ''2025%'' GROUP BY "상위캠페인명" ORDER BY "개발건수" DESC'),
		"유지율_높은_캠페인" AS ( 
QUESTION '2025년 가입 회원 중 평균 활동기간이 가장 긴 캠페인과 짧은 캠페인은?' 
ONBOARDING_QUESTION false
SQL 'SELECT "상위캠페인명", "총가입자수", "중단자수", "현재유지율", "평균활동개월수", "12개월유지율" FROM GN_DW_POC.ANALYTICS.V_RETENTION_BY_PERIOD WHERE "가입연도" = ''2025'' AND "총가입자수" >= 10 ORDER BY "평균활동개월수" ASC LIMIT 10'), 
		"개발건_이미환산" AS ( 
QUESTION '개발건수를 후원금액/10000으로 계산해줘'
ONBOARDING_QUESTION false
SQL 'SELECT "상위캠페인명", SUM("개발실적_건") AS "개발건수(건)" FROM GN_DW_POC.ANALYTICS.V_MEMBER_DEV_DETAIL WHERE "개발구분" IN (''신규'',''증액'',''재후원'') AND "신청월" LIKE ''2025%'' GROUP BY "상위캠페인명" ORDER BY "개발건수(건)" DESC'), 
		"공통브랜드별_신규개발" AS ( 
QUESTION '2025년 공통브랜드별 신규회원 개발건수를 보여줘'
ONBOARDING_QUESTION false
SQL 'SELECT "공통브랜드명", COUNT(*) AS "개발건수", SUM("개발실적_건") AS "개발실적(건)", SUM("금액") AS "총금액" FROM GN_DW_POC.ANALYTICS.V_MEMBER_DEV_DETAIL WHERE "개발구분" = ''신규'' AND "신청월" LIKE ''2025%'' AND "공통브랜드명" IS NOT NULL GROUP BY "공통브랜드명" ORDER BY "개발건수" DESC'),
		"공통상위캠페인별_LTV" AS ( 
QUESTION '2025~2026년 1분기 공통상위캠페인별 LTV를 산출해줘' 
ONBOARDING_QUESTION false
SQL 'SELECT "공통상위캠페인명", SUM("금액") AS "총개발금액", SUM("개발실적_건") AS "총개발건수", AVG("금액") AS "평균후원금액" FROM GN_DW_POC.ANALYTICS.V_MEMBER_DEV_DETAIL WHERE "개발구분" IN (''신규'',''증액'',''재후원'') AND "신청월" >= ''202501'' AND "신청월" <= ''202603'' AND "공통상위캠페인명" IS NOT NULL GROUP BY "공통상위캠페인명" ORDER BY "총개발금액" DESC'),
		"공통상위캠페인별_유지율" AS ( 
QUESTION '2025~2026년 공통상위캠페인별 평균활동개월수와 현재유지율을 보여줘' 
ONBOARDING_QUESTION false
SQL 'SELECT "공통상위캠페인명", SUM("총가입자수") AS "총가입자수", ROUND(AVG("현재유지율"),1) AS "현재유지율", ROUND(AVG("평균활동개월수"),1) AS "평균활동개월수" FROM GN_DW_POC.ANALYTICS.V_RETENTION_BY_PERIOD WHERE "가입연도" IN (''2025'',''2026'') AND "공통상위캠페인명" IS NOT NULL GROUP BY "공통상위캠페인명" ORDER BY "총가입자수" DESC'),
		"국내해외별_개발현황" AS ( 
QUESTION '국내해외구분별 신규 개발건수와 평균후원금액을 비교해줘'
ONBOARDING_QUESTION false
SQL 'SELECT "국내해외구분", COUNT(*) AS "개발건수", SUM("개발실적_건") AS "개발실적(건)", AVG("금액") AS "평균후원금액" FROM GN_DW_POC.ANALYTICS.V_MEMBER_DEV_DETAIL WHERE "개발구분" = ''신규'' AND "신청월" LIKE ''2025%'' GROUP BY "국내해외구분" ORDER BY "개발건수" DESC')
	)
	with extension (CA='{"tables":[{"name":"DEV_DETAIL","dimensions":[{"name":"AGE_GROUP"},{"name":"APPLY_MONTH"},{"name":"BRAND_NAME"},{"name":"COMMON_BRAND_NAME"},{"name":"COMMON_PARENT_CAMPAIGN"},{"name":"DEPT_NAME"},{"name":"DEV_TYPE"},{"name":"DOMESTIC_OVERSEAS"},{"name":"GENDER"},{"name":"MEMBER_ID"},{"name":"PARENT_CAMPAIGN"},{"name":"REGION"},{"name":"SUB_CAMPAIGN"}],"facts":[{"name":"AMOUNT"},{"name":"DEV_PERF"},{"name":"NEW_DEV_ONLY"}],"metrics":[{"name":"TOTAL_AMOUNT"},{"name":"TOTAL_COUNT"}]},{"name":"DISCONTINUATION","dimensions":[{"name":"DISC_COMMON_BRAND"},{"name":"DISC_COMMON_PARENT"},{"name":"DISC_DOMESTIC_OVERSEAS"},{"name":"DISC_MONTH"}],"metrics":[{"name":"M_DISC"}]},{"name":"RETENTION","dimensions":[{"name":"RET_COMMON_BRAND"},{"name":"RET_COMMON_PARENT"},{"name":"RET_DOMESTIC_OVERSEAS"},{"name":"RET_PARENT"},{"name":"RET_YEAR"}],"facts":[{"name":"RET_12M"},{"name":"RET_3M"},{"name":"RET_AVG_MONTHS"},{"name":"RET_CURRENT"},{"name":"RET_DISC_CNT"},{"name":"RET_TOTAL"}],"metrics":[{"name":"M_AVG_MONTHS"},{"name":"M_RET_CURRENT"},{"name":"M_RET12"}]}]}');
-- 마케팅 발송 시맨틱뷰: 알림톡/문자 발송, 발송유형별 전환, 알림톡 수신 증액 크로스분석
create or replace semantic view SV_MARKETING_MESSAGING 
	tables (
		SMS_SEND as GN_DW_POC.RAW.FACT_SMS_ALIMTALK_SEND comment='문자/알림톡 전체 발송.',
		ALIM_INC as GN_DW_POC.ANALYTICS.V_ALIMTALK_INCREASE_CROSS comment='알림톡수신회원 x 증액건 크로스분석.',
		SEND_CONV as GN_DW_POC.ANALYTICS.V_SEND_CONVERSION_ANALYSIS comment='발송유형별 전환분석.'
	)
	facts (
		ALIM_INC.AI_AMOUNT as "금액" with synonyms=('증액금액') comment='증액금액(원).',
		SEND_CONV.SC_CONV as "전환건수" with synonyms=('전환건수') comment='전환건수.',
		SEND_CONV.SC_DAYS as "평균전환소요일" with synonyms=('전환소요일') comment='평균전환소요일.',
		SEND_CONV.SC_RATE as "전환율" with synonyms=('전환율') comment='전환율.'
	)
	dimensions (
		SMS_SEND.SMS_MEMBER as "회원번호" with synonyms=('회원번호') comment='회원번호.',
		SMS_SEND.SMS_CAT_L as "발송구분(대)" with synonyms=('발송구분대') comment='대분류.',
		SMS_SEND.SMS_CAT_M as "발송구분(중)" with synonyms=('발송구분중') comment='중분류.',
		SMS_SEND.SMS_CAT_S as "발송구분(소)" with synonyms=('발송구분소') comment='소분류.',
		SMS_SEND.SMS_STATUS as "발송상태" with synonyms=('발송상태') comment='발송상태.',
		SMS_SEND.SMS_TITLE as "제목" with synonyms=('제목') comment='발송제목.',
		SMS_SEND.SMS_SEND_TIME as "발송일시" with synonyms=('발송일시') comment='발송일시.',
		ALIM_INC.AI_ALIM as "알림톡수신여부" with synonyms=('알림톡수신여부') comment='알림톡수신 Y/N.',
		ALIM_INC.AI_MONTH as "개발월" with synonyms=('개발월') comment='증액개발 월.',
		ALIM_INC.AI_YEAR as "개발연도" with synonyms=('개발연도') comment='증액개발 연도.',
		ALIM_INC.AI_PARENT as "상위캠페인명" with synonyms=('상위캠페인명','상위캠페인') comment='증액건의 상위캠페인.',
		SEND_CONV.SC_TYPE as "발송유형" with synonyms=('발송유형') comment='알림톡/마케팅메일/문자SMS.'
	)
	metrics (
		SMS_SEND.M_SMS as COUNT(*) with synonyms=('발송건수','문자건수') comment='전체발송건수.',
		SMS_SEND.M_UNIQUE_MEMBERS as COUNT(DISTINCT sms_send.sms_member) with synonyms=('발송회원수') comment='발송 고유회원수.',
		ALIM_INC.M_AI_CNT as COUNT(*) with synonyms=('알림톡증액건수') comment='알림톡수신 증액건수.',
		ALIM_INC.M_AI_AMT as SUM(alim_inc.ai_amount) with synonyms=('알림톡증액금액') comment='알림톡수신 증액금액.',
		SEND_CONV.M_CONV as SUM(send_conv.sc_conv) with synonyms=('총전환건수') comment='총전환건수.'
	)
	comment='마케팅발송 분석. 알림톡/문자 발송, 전환분석, 알림톡수신회원 증액 크로스분석. 알림톡=제목에 ''알림톡'' 포함건.'
	ai_verified_queries (
		"알림톡_증액_중단" AS ( 
QUESTION '2025년 알림톡 서비스를 받은 회원 기준 연간 서비스 발송횟수, 증액건, 중단건은?' 
ONBOARDING_QUESTION true 
SQL 'WITH alim_members AS (SELECT "회원번호", COUNT(*) AS "발송횟수" FROM GN_DW_POC.RAW.FACT_SMS_ALIMTALK_SEND WHERE "제목" LIKE ''%알림톡%'' AND LEFT("발송일시",4)=''2025'' AND "발송상태"=''발송완료'' GROUP BY "회원번호"), inc AS (SELECT "회원번호", COUNT(*) AS "증액건수" FROM GN_DW_POC.ANALYTICS.V_ALIMTALK_INCREASE_CROSS WHERE "개발연도" LIKE ''2025%'' AND "알림톡수신여부"=''Y'' GROUP BY "회원번호"), disc AS (SELECT "회원번호", COUNT(*) AS "중단건수" FROM GN_DW_POC.ANALYTICS.V_DISCONTINUED_DETAIL WHERE "중단연도"=''2025'' GROUP BY "회원번호") SELECT COUNT(DISTINCT a."회원번호") AS "알림톡수신회원수", SUM(a."발송횟수") AS "총발송횟수", ROUND(AVG(a."발송횟수"),1) AS "평균발송횟수", COALESCE(SUM(i."증액건수"),0) AS "총증액건수", COALESCE(SUM(d."중단건수"),0) AS "총중단건수" FROM alim_members a LEFT JOIN inc i ON a."회원번호"=i."회원번호" LEFT JOIN disc d ON a."회원번호"=d."회원번호"'),
		"발송유형별_전환" AS ( 
QUESTION '발송유형별 전환율과 평균전환소요일은?' 
ONBOARDING_QUESTION true 
SQL 'SELECT "발송유형", "전환건수", "전환율", "평균전환소요일" FROM GN_DW_POC.ANALYTICS.V_SEND_CONVERSION_ANALYSIS ORDER BY "전환건수" DESC')
	)
	with extension (CA='{"tables":[{"name":"SMS_SEND","dimensions":[{"name":"SMS_MEMBER"},{"name":"SMS_CAT_L"},{"name":"SMS_CAT_M"},{"name":"SMS_CAT_S"},{"name":"SMS_STATUS"},{"name":"SMS_TITLE"},{"name":"SMS_SEND_TIME"}],"metrics":[{"name":"M_SMS"},{"name":"M_UNIQUE_MEMBERS"}]},{"name":"ALIM_INC","dimensions":[{"name":"AI_ALIM"},{"name":"AI_MONTH"},{"name":"AI_YEAR"},{"name":"AI_PARENT"}],"facts":[{"name":"AI_AMOUNT"}],"metrics":[{"name":"M_AI_CNT"},{"name":"M_AI_AMT"}]},{"name":"SEND_CONV","dimensions":[{"name":"SC_TYPE"}],"facts":[{"name":"SC_CONV"},{"name":"SC_DAYS"},{"name":"SC_RATE"}],"metrics":[{"name":"M_CONV"}]}]}');
create or replace semantic view SV_AD_PLATFORM
	tables (
		DIGITAL_AD as GN_DW_POC.RAW.FACT_DIGITAL_AD_DETAIL comment='디지털대행사 광고운영상세.',
		GA_AUDIENCE as GN_DW_POC.RAW.FACT_AD_GA_AUDIENCE comment='GA 잠재고객.',
		META_AD as GN_DW_POC.RAW.FACT_AD_META comment='메타(Facebook/Instagram) 광고.'
	)
	facts (
		DIGITAL_AD.AD_COST as "GA 광고비" with synonyms=('광고비') comment='GA광고비(원).',
		DIGITAL_AD.CLICKS as "클릭수" with synonyms=('클릭수') comment='클릭수.',
		DIGITAL_AD.GA_DEV as "GA 개발건수" with synonyms=('GA개발건수') comment='GA개발건수.',
		DIGITAL_AD.IMPRESSIONS as "노출수" with synonyms=('노출수') comment='노출수.',
		GA_AUDIENCE.SESSIONS as "세션수" with synonyms=('세션수') comment='세션수.',
		META_AD.META_CLICKS as "링크클릭" with synonyms=('메타클릭') comment='메타링크클릭.',
		META_AD.META_IMPRESSIONS as "노출" with synonyms=('메타노출') comment='메타노출수.',
		META_AD.META_PURCHASE as "구매" with synonyms=('메타구매') comment='메타구매건수.',
		META_AD.META_SPEND as "지출금액_KRW" with synonyms=('메타광고비') comment='메타지출(KRW).'
	)
	dimensions (
		DIGITAL_AD.AD_DATE as "날짜" with synonyms=('광고일자','날짜') comment='광고일자.',
		DIGITAL_AD.AD_MONTH as "월" with synonyms=('월') comment='월.',
		DIGITAL_AD.AD_TYPE as "광고유형" with synonyms=('광고유형') comment='SA/DA/CPT 등.',
		DIGITAL_AD.AD_YEAR as "연도" with synonyms=('연도') comment='연도.',
		DIGITAL_AD.CAMPAIGN_NAME as "캠페인명" with synonyms=('캠페인명') comment='캠페인명.',
		DIGITAL_AD.CREATIVE as "소재" with synonyms=('소재') comment='소재명.',
		DIGITAL_AD.DEVICE as "기기" with synonyms=('기기') comment='PC/모바일.',
		DIGITAL_AD.DOMESTIC_OVERSEAS as "국내/해외" with synonyms=('국내해외') comment='국내/해외.',
		DIGITAL_AD.MEDIA as "매체" with synonyms=('매체') comment='매체.',
		DIGITAL_AD.PARENT_CAMPAIGN_NAME as "상위캠페인명" with synonyms=('상위캠페인명') comment='상위캠페인명.',
		DIGITAL_AD.CAMPAIGN_TYPE as "캠페인 유형" with synonyms=('캠페인유형','캠페인 유형') comment='캠페인 유형. 값 예시: 국내 사업, 국내 사례, 해외 사례, 통합 통합, 전체 굿즈, 해외 사업, 해외 굿즈.',
		DIGITAL_AD.BIZ_CASE as "사업/사례" with synonyms=('사업사례','사업/사례') comment='사업/사례 구분.',
		GA_AUDIENCE.AUDIENCE_NAME as "잠재고객이름" with synonyms=('잠재고객') comment='잠재고객이름.',
		GA_AUDIENCE.GA_DATE as "날짜" with synonyms=('GA날짜') comment='GA날짜.',
		GA_AUDIENCE.GA_MEMBER as "회원번호" with synonyms=('GA회원번호') comment='GA회원번호.',
		GA_AUDIENCE.SESSION_CAMPAIGN as "세션캠페인" with synonyms=('세션캠페인') comment='세션캠페인.',
		META_AD.META_AD_NAME as "광고이름" with synonyms=('메타광고이름','메타소재') comment='메타광고이름.',
		META_AD.META_ADSET as "광고세트이름" with synonyms=('광고세트') comment='광고세트.',
		META_AD.META_CAMPAIGN as "캠페인이름" with synonyms=('메타캠페인') comment='메타캠페인.',
		META_AD.META_DATE as "일" with synonyms=('메타날짜') comment='메타광고일자.'
	)
	metrics (
		DIGITAL_AD.M_AD_COST as SUM(digital_ad.ad_cost) with synonyms=('총광고비') comment='총광고비(원).',
		DIGITAL_AD.M_CLICKS as SUM(digital_ad.clicks) with synonyms=('총클릭수') comment='총클릭수.',
		DIGITAL_AD.M_CPC as CASE WHEN SUM(digital_ad.clicks)>0 THEN ROUND(SUM(digital_ad.ad_cost)/SUM(digital_ad.clicks),0) ELSE 0 END with synonyms=('CPC','클릭당비용') comment='CPC(원).',
		DIGITAL_AD.M_CTR as CASE WHEN SUM(digital_ad.impressions)>0 THEN ROUND(SUM(digital_ad.clicks)*100.0/SUM(digital_ad.impressions),2) ELSE 0 END with synonyms=('CTR','클릭률') comment='CTR(%).',
		DIGITAL_AD.M_IMPRESSIONS as SUM(digital_ad.impressions) with synonyms=('총노출수') comment='총노출수.',
		GA_AUDIENCE.M_SESSIONS as SUM(ga_audience.sessions) with synonyms=('총세션수') comment='총세션수.',
		META_AD.M_META_IMPRESSIONS as SUM(meta_ad.meta_impressions) with synonyms=('총메타노출') comment='총메타노출.',
		META_AD.M_META_SPEND as SUM(meta_ad.meta_spend) with synonyms=('총메타광고비') comment='총메타광고비.'
	)
	comment='디지털 광고 플랫폼 분석. 디지털대행사 + GA + 메타. 캠페인유형은 FACT_DIGITAL_AD_DETAIL의 ''캠페인 유형'' 컬럼 기준.'
	ai_verified_queries (
		"매체별_효율" AS ( 
QUESTION '2025년 매체별 광고효율(노출/클릭/CPC)은?' 
ONBOARDING_QUESTION false 
SQL 'SELECT "매체", SUM("노출수") AS "총노출", SUM("클릭수") AS "총클릭", ROUND(SUM("클릭수")*100.0/NULLIF(SUM("노출수"),0),2) AS CTR, ROUND(SUM("GA 광고비")/NULLIF(SUM("클릭수"),0),0) AS CPC FROM GN_DW_POC.RAW.FACT_DIGITAL_AD_DETAIL WHERE "연도" = ''2025년'' GROUP BY "매체" ORDER BY "총노출" DESC'), 
		"메타_캠페인_성과" AS ( 
QUESTION '메타 캠페인별 지출금액과 구매건수는?' 
ONBOARDING_QUESTION false 
SQL 'SELECT "캠페인이름", SUM("지출금액_KRW") AS "총지출", SUM("구매") AS "총구매", ROUND(SUM("지출금액_KRW")/NULLIF(SUM("구매"),0),0) AS "구매당비용" FROM GN_DW_POC.RAW.FACT_AD_META GROUP BY "캠페인이름" ORDER BY "총지출" DESC LIMIT 10'), 
		"캠페인유형별_효율" AS ( 
QUESTION '캠페인 유형별 매체별 효율을 분석해줘' 
ONBOARDING_QUESTION false 
SQL 'SELECT "캠페인 유형", "매체", SUM("노출수") AS "총노출", SUM("클릭수") AS "총클릭", SUM("GA 광고비") AS "총광고비", SUM("GA 개발건수") AS "총GA개발건수", ROUND(SUM("GA 광고비")/NULLIF(SUM("GA 개발건수"),0),0) AS "개발단가" FROM GN_DW_POC.RAW.FACT_DIGITAL_AD_DETAIL WHERE "연도" = ''2025년'' GROUP BY "캠페인 유형", "매체" ORDER BY "캠페인 유형", "총GA개발건수" DESC')
	)
	with extension (CA='{"tables":[{"name":"DIGITAL_AD","dimensions":[{"name":"AD_DATE"},{"name":"AD_MONTH"},{"name":"AD_TYPE"},{"name":"AD_YEAR"},{"name":"CAMPAIGN_NAME"},{"name":"CREATIVE"},{"name":"DEVICE"},{"name":"DOMESTIC_OVERSEAS"},{"name":"MEDIA"},{"name":"PARENT_CAMPAIGN_NAME"},{"name":"CAMPAIGN_TYPE","is_enum":true},{"name":"BIZ_CASE"}],"facts":[{"name":"AD_COST"},{"name":"CLICKS"},{"name":"GA_DEV"},{"name":"IMPRESSIONS"}],"metrics":[{"name":"M_AD_COST"},{"name":"M_CLICKS"},{"name":"M_CPC"},{"name":"M_CTR"},{"name":"M_IMPRESSIONS"}]},{"name":"GA_AUDIENCE","dimensions":[{"name":"AUDIENCE_NAME"},{"name":"GA_DATE"},{"name":"GA_MEMBER"},{"name":"SESSION_CAMPAIGN"}],"facts":[{"name":"SESSIONS"}],"metrics":[{"name":"M_SESSIONS"}]},{"name":"META_AD","dimensions":[{"name":"META_AD_NAME"},{"name":"META_ADSET"},{"name":"META_CAMPAIGN"},{"name":"META_DATE"}],"facts":[{"name":"META_CLICKS"},{"name":"META_IMPRESSIONS"},{"name":"META_PURCHASE"},{"name":"META_SPEND"}],"metrics":[{"name":"M_META_IMPRESSIONS"},{"name":"M_META_SPEND"}]}]}');
create or replace semantic view SV_WEB_APP_ANALYTICS
	tables (
		APP_ENGAGEMENT as GN_DW_POC.ANALYTICS.V_APP_ENGAGEMENT comment='APP 방문 분석 (페이지경로, 이벤트, 세션수, 페이지뷰)',
		GA_TOTAL as GN_DW_POC.RAW.FACT_GA_VISITS_TOTAL comment='나의후원 전체 방문수 (PC+모바일+APP)',
		GA_PC as GN_DW_POC.RAW.FACT_GA_VISITS_PC comment='나의후원 PC 방문수',
		GA_MOBILE as GN_DW_POC.RAW.FACT_GA_VISITS_MOBILE comment='나의후원 모바일 방문수',
		GA_APP as GN_DW_POC.RAW.FACT_GA_VISITS_APP comment='나의후원 APP 방문수',
		GA_FEEDBACK as GN_DW_POC.RAW.FACT_GA_FEEDBACK_PAGE comment='피드백 서비스페이지 유입 (이탈률, 참여율, 평균세션시간)'
	)
	facts (
		APP_ENGAGEMENT.SESSION_COUNT as "세션수" with synonyms=('세션수') comment='APP 세션수',
		APP_ENGAGEMENT.PAGE_VIEW_COUNT as "페이지뷰" with synonyms=('페이지뷰') comment='APP 페이지뷰수',
		APP_ENGAGEMENT.ACTIVE_USER_COUNT as "활성사용자수" with synonyms=('활성사용자수') comment='APP 활성사용자수',
		APP_ENGAGEMENT.VISIT_COUNT as "방문수" with synonyms=('방문수') comment='APP 방문수',
		APP_ENGAGEMENT.EVENT_COUNT as "이벤트수" with synonyms=('이벤트수') comment='APP 이벤트수'
	)
	dimensions (
		APP_ENGAGEMENT.APP_PAGE_PATH as "페이지경로" with synonyms=('페이지경로','페이지') comment='페이지 경로',
		APP_ENGAGEMENT.APP_EVENT_NAME as "이벤트이름" with synonyms=('이벤트이름','이벤트') comment='GA 이벤트 이름',
		APP_ENGAGEMENT.APP_MEMBER_ID as "회원ID" with synonyms=('회원ID','회원번호') comment='회원 ID',
		GA_TOTAL.TOTAL_PAGE_PATH as "페이지경로" comment='전체 방문 페이지경로',
		GA_TOTAL.TOTAL_EVENT_NAME as "이벤트이름" comment='전체 이벤트이름',
		GA_TOTAL.TOTAL_SESSION_CAMPAIGN as "세션캠페인" with synonyms=('세션캠페인') comment='세션 캠페인명',
		GA_TOTAL.TOTAL_MEMBER_ID as "회원ID" comment='전체 방문 회원ID',
		GA_PC.PC_PAGE_PATH as "페이지경로" comment='PC 페이지경로',
		GA_PC.PC_MEMBER_ID as "회원ID" comment='PC 회원ID',
		GA_MOBILE.MOBILE_PAGE_PATH as "페이지경로" comment='모바일 페이지경로',
		GA_MOBILE.MOBILE_EVENT_NAME as "이벤트이름" comment='모바일 이벤트이름',
		GA_MOBILE.MOBILE_MEMBER_ID as "회원ID" comment='모바일 회원ID',
		GA_APP.GA_APP_PAGE_PATH as "페이지경로" comment='APP 페이지경로',
		GA_APP.GA_APP_EVENT_NAME as "이벤트이름" comment='APP 이벤트이름',
		GA_APP.GA_APP_MEMBER_ID as "회원ID" comment='APP 회원ID',
		GA_FEEDBACK.FEEDBACK_PAGE_QUERY as "페이지경로쿼리" with synonyms=('페이지경로쿼리','피드백페이지') comment='피드백 페이지 경로'
	)
	metrics (
		APP_ENGAGEMENT.TOTAL_SESSIONS as SUM(app_engagement.session_count) with synonyms=('세션수','APP세션수') comment='APP 세션수',
		APP_ENGAGEMENT.TOTAL_PAGE_VIEWS as SUM(app_engagement.page_view_count) with synonyms=('페이지뷰','APP페이지뷰') comment='APP 페이지뷰수',
		APP_ENGAGEMENT.TOTAL_ACTIVE_USERS as SUM(app_engagement.active_user_count) with synonyms=('활성사용자수') comment='APP 활성사용자수',
		APP_ENGAGEMENT.TOTAL_VISITS as SUM(app_engagement.visit_count) with synonyms=('방문수','APP방문수') comment='APP 방문수',
		APP_ENGAGEMENT.TOTAL_EVENTS as SUM(app_engagement.event_count) with synonyms=('이벤트수','APP이벤트수') comment='APP 이벤트수'
	)
	comment='웹·앱 방문 분석: 디바이스별(PC/모바일/APP) 방문수, 세션, 피드백 페이지 유입'
	ai_sql_generation '숫자는 소수점 1자리 ROUND. 한글 컬럼명은 쌍따옴표. GA 데이터의 세션수/페이지뷰 등은 TEXT 타입이므로 집계시 TRY_CAST 필요.'
	ai_question_categorization '웹사이트 방문, 앱 사용, 페이지뷰, 세션, 피드백 페이지, 디바이스별 분석에 답변.';
-- 회원 여정 시맨틱뷰: 가입~매체~발송~증액~중단을 회원번호 기준으로 연결한 360도 여정 분석
create or replace semantic view SV_MEMBER_JOURNEY
	tables (
		JOURNEY as GN_DW_POC.ANALYTICS.V_MEMBER_JOURNEY comment='회원별 후원 전후 통합 여정. 가입/매체/발송/증액/중단 연결.'
	)
	facts (
		JOURNEY.JOIN_AMOUNT as "가입금액" with synonyms=('가입금액','후원금액') comment='가입 시 후원금액(원).',
		JOURNEY.GA_SESSIONS as "GA세션수" with synonyms=('GA세션수','세션수') comment='GA 총 세션수.',
		JOURNEY.SEND_COUNT as "총발송수" with synonyms=('총발송수','발송수') comment='수신한 총 발송건수.',
		JOURNEY.SEND_TYPE_COUNT as "발송종류수" with synonyms=('발송종류수') comment='수신한 발송 종류수.',
		JOURNEY.APP_SESSIONS as "앱세션수" with synonyms=('앱세션수') comment='앱 총 세션수.',
		JOURNEY.APP_PAGEVIEWS as "앱페이지뷰" with synonyms=('앱페이지뷰') comment='앱 총 페이지뷰.',
		JOURNEY.INCREASE_COUNT as "증액건수" with synonyms=('증액건수') comment='증액 건수.',
		JOURNEY.INCREASE_AMOUNT as "증액금액" with synonyms=('증액금액') comment='증액금액(원).',
		JOURNEY.RETAIN_MONTHS as "유지개월수" with synonyms=('유지개월수','유지기간') comment='가입~중단 유지개월수.'
	)
	dimensions (
		JOURNEY.MEMBER_ID as "회원번호" with synonyms=('회원번호') comment='회원번호.',
		JOURNEY.PARENT_CAMPAIGN as "상위캠페인명" with synonyms=('상위캠페인명','상위캠페인') comment='가입 상위캠페인.',
		JOURNEY.SUB_CAMPAIGN as "세부캠페인명" with synonyms=('세부캠페인명','세부캠페인','캠페인') comment='가입 세부캠페인.',
		JOURNEY.DEV_TYPE as "개발구분" with synonyms=('개발구분') comment='개발구분(신규/증액 등).',
		JOURNEY.JOIN_MONTH as "가입월" with synonyms=('가입월','신청월') comment='가입월(YYYYMM).',
		JOURNEY.AUDIENCE_LIST as "잠재고객목록" with synonyms=('잠재고객목록','잠재고객') comment='GA 잠재고객이름 목록.',
		JOURNEY.SESSION_CAMPAIGN_LIST as "세션캠페인목록" with synonyms=('세션캠페인목록','세션캠페인') comment='GA 세션캠페인 목록.',
		JOURNEY.SEND_SERVICE_LIST as "발송서비스목록" with synonyms=('발송서비스목록','발송서비스') comment='수신한 발송서비스 목록.',
		JOURNEY.DISC_REASON as "중단사유" with synonyms=('중단사유') comment='중단사유.',
		JOURNEY.DISC_MONTH as "중단월" with synonyms=('중단월') comment='중단월(YYYYMM).',
		JOURNEY.IS_INCREASED as "증액여부" with synonyms=('증액여부') comment='증액여부(Y/N).',
		JOURNEY.IS_DISCONTINUED as "중단여부" with synonyms=('중단여부') comment='중단여부(Y/N).'
	)
	metrics (
		JOURNEY.MEMBER_COUNT as COUNT(DISTINCT journey.member_id) with synonyms=('회원수','고유회원수') comment='고유 회원수.',
		JOURNEY.TOTAL_JOIN_AMOUNT as SUM(journey.join_amount) with synonyms=('총가입금액') comment='총 가입금액(원).',
		JOURNEY.AVG_RETAIN_MONTHS as AVG(journey.retain_months) with synonyms=('평균유지개월수','평균유지기간') comment='평균 유지개월수.',
		JOURNEY.AVG_SEND_COUNT as AVG(journey.send_count) with synonyms=('평균발송수') comment='회원당 평균 발송건수.',
		JOURNEY.JOURNEY_COUNT as COUNT(*) with synonyms=('건수','총건수') comment='총 건수.',
		JOURNEY.AVG_GA_SESSIONS as AVG(journey.ga_sessions) with synonyms=('평균GA세션수','평균세션수') comment='평균 GA 세션수.',
		JOURNEY.TOTAL_INCREASE_AMOUNT as SUM(journey.increase_amount) with synonyms=('총증액금액') comment='총 증액금액(원).'
	)
	comment='회원별 후원 전후 통합 여정 분석. 가입캠페인/매체/잠재고객/발송서비스/증액/중단을 회원번호 기준으로 연결.'
	ai_verified_queries (
		"캠페인별_여정_요약" AS ( 
QUESTION '상위캠페인별 회원수, 평균발송수, 증액율, 중단율은?'
ONBOARDING_QUESTION true 
SQL 'SELECT "상위캠페인명", COUNT(DISTINCT "회원번호") AS 회원수, ROUND(AVG("총발송수"),1) AS 평균발송수, ROUND(SUM(CASE WHEN "증액여부"=''Y'' THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0),1) AS 증액율, ROUND(SUM(CASE WHEN "중단여부"=''Y'' THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0),1) AS 중단율 FROM GN_DW_POC.ANALYTICS.V_MEMBER_JOURNEY GROUP BY "상위캠페인명" ORDER BY 회원수 DESC LIMIT 20'),
		"중단회원_여정리스트" AS ( 
QUESTION '중단한 회원들의 가입캠페인, 잠재고객, 발송서비스, 중단사유 리스트를 보여줘'
ONBOARDING_QUESTION true 
SQL 'SELECT "회원번호", "상위캠페인명", "가입월", "가입금액", "잠재고객목록", "총발송수", "발송서비스목록", "중단사유", "중단월", "유지개월수" FROM GN_DW_POC.ANALYTICS.V_MEMBER_JOURNEY WHERE "중단여부" = ''Y'' ORDER BY "중단월" DESC LIMIT 100'),
		"증액회원_특성" AS ( 
QUESTION '증액한 회원들의 상위캠페인별 평균유지기간과 평균발송수는?' 
ONBOARDING_QUESTION false
SQL 'SELECT "상위캠페인명", COUNT(DISTINCT "회원번호") AS 증액회원수, ROUND(AVG("유지개월수"),1) AS 평균유지개월수, ROUND(AVG("총발송수"),1) AS 평균발송수, ROUND(AVG("증액금액"),0) AS 평균증액금액 FROM GN_DW_POC.ANALYTICS.V_MEMBER_JOURNEY WHERE "증액여부" = ''Y'' GROUP BY "상위캠페인명" ORDER BY 증액회원수 DESC LIMIT 20')
	)
	with extension (CA='{"tables":[{"name":"JOURNEY","dimensions":[{"name":"MEMBER_ID"},{"name":"PARENT_CAMPAIGN"},{"name":"SUB_CAMPAIGN"},{"name":"DEV_TYPE"},{"name":"JOIN_MONTH"},{"name":"AUDIENCE_LIST"},{"name":"SESSION_CAMPAIGN_LIST"},{"name":"SEND_SERVICE_LIST"},{"name":"DISC_REASON"},{"name":"DISC_MONTH"},{"name":"IS_INCREASED"},{"name":"IS_DISCONTINUED"}],"facts":[{"name":"JOIN_AMOUNT"},{"name":"GA_SESSIONS"},{"name":"SEND_COUNT"},{"name":"SEND_TYPE_COUNT"},{"name":"APP_SESSIONS"},{"name":"APP_PAGEVIEWS"},{"name":"INCREASE_COUNT"},{"name":"INCREASE_AMOUNT"},{"name":"RETAIN_MONTHS"}],"metrics":[{"name":"MEMBER_COUNT"},{"name":"TOTAL_JOIN_AMOUNT"},{"name":"AVG_RETAIN_MONTHS"},{"name":"AVG_SEND_COUNT"},{"name":"JOURNEY_COUNT"},{"name":"AVG_GA_SESSIONS"},{"name":"TOTAL_INCREASE_AMOUNT"}]}]}');
