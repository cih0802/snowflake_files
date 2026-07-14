-- PoC 당시 ANALYTICS 분석 스키마 및 하위 객체(테이블/뷰/Streamlit)들의 DDL 백업

-- 분석 레이어 ANALYTICS 스키마 생성
create or replace schema ANALYTICS; 

-- 브랜드별 평균 납입금액 예측(Forecast) 결과 저장 테이블
create or replace TABLE FORECAST_AVG_PAYMENT_RESULT ( 
	SERIES VARIANT,
	TS TIMESTAMP_NTZ(9),
	FORECAST FLOAT,
	LOWER_BOUND FLOAT,
	UPPER_BOUND FLOAT
);
-- 브랜드별 개발건수 예측(Forecast) 결과 저장 테이블
create or replace TABLE FORECAST_DEV_COUNT_RESULT ( 
	SERIES VARIANT,
	TS TIMESTAMP_NTZ(9),
	FORECAST FLOAT,
	LOWER_BOUND FLOAT,
	UPPER_BOUND FLOAT
);
-- 예측 모델 학습용 통합 데이터 테이블(브랜드별 개발건수/금액/평균납입)
create or replace TABLE FORECAST_TRAINING_DATA (
	MONTH_DATE DATE,
	BRAND VARCHAR(16777216),
	DEV_COUNT NUMBER(18,0),
	TOTAL_AMOUNT NUMBER(38,0),
	AVG_PAYMENT NUMBER(38,0)
);
-- 브랜드별 월별 평균 납입금액 학습 데이터 테이블
create or replace TABLE TRAIN_AVG_PAYMENT ( 
	MONTH_DATE DATE,
	BRAND VARCHAR(16777216),
	AVG_PAYMENT NUMBER(38,0)
);
-- 개발건수 예측 모델 학습 데이터(브랜드/월별)
create or replace TABLE TRAIN_DEV_COUNT ( 
	MONTH_DATE DATE,
	BRAND VARCHAR(16777216),
	DEV_COUNT NUMBER(18,0)
);
-- 알림톡 발송 대비 전환(개발) 효과 분석 뷰
create or replace view V_ALIMTALK_EFFECTIVENESS(
	"회원번호",
	"발송일시",
	"발송구분(대)",
	"발송구분(중)",
	"발송구분(소)",
	"제목",
	"발송상태",
	"성공률(%)",
	"브랜드",
	"상위캠페인",
	"전환여부",
	"전환유형",
	"전환금액"
) as
WITH alimtalk_sends AS (
SELECT "회원번호", "발송일시", "발송구분(대)", "발송구분(중)", "발송구분(소)",
"제목", "발송상태", "성공률(%)" 
FROM GN_DW_POC.RAW.FACT_SMS_ALIMTALK_SEND 
WHERE "제목" LIKE '%알림톡%' OR "발송구분(소)" LIKE '%알림%'
),
marketing_send AS ( 
SELECT "회원번호", "발송일시", "발송구분(대)", "발송구분(중)", "발송구분(소)", "브랜드", "상위캠페인" 
FROM GN_DW_POC.RAW.FACT_MARKETING_SEND_NEW
) 
SELECT
a."회원번호", a."발송일시", a."발송구분(대)", a."발송구분(중)", a."발송구분(소)", 
a."제목", a."발송상태", a."성공률(%)",
ms."브랜드", ms."상위캠페인", 
CASE WHEN d."회원번호" IS NOT NULL THEN 'Y' ELSE 'N' END AS "전환여부", 
d."개발구분" AS "전환유형", 
d."금액" AS "전환금액"
FROM alimtalk_sends a 
LEFT JOIN marketing_send ms ON a."회원번호" = ms."회원번호" AND a."발송일시" = ms."발송일시"
LEFT JOIN GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d ON a."회원번호" = d."회원번호"
AND d."개발구분" IN ('신규', '증액', '재후원'); 
-- 증액 개발건과 알림톡 수신여부 교차 분석 뷰
create or replace view V_ALIMTALK_INCREASE_CROSS( 
	"회원번호",
	"개발월",
	"개발연도",
	"상위캠페인명",
	"세부캠페인명",
	"금액",
	"개발구분",
	"알림톡수신여부"
) as
WITH alimtalk_members AS (
SELECT DISTINCT "회원번호", LEFT("발송일시", 7) AS send_month 
FROM GN_DW_POC.RAW.FACT_SMS_ALIMTALK_SEND 
WHERE ("제목" LIKE '%알림톡%' OR "발송구분(소)" LIKE '%알림%')
AND "발송상태" = '발송완료' AND "회원번호" IS NOT NULL
),
increase_dev AS ( 
SELECT d."회원번호",
LEFT(TO_VARCHAR(d."후원신청일"), 6) AS dev_month, 
LEFT(TO_VARCHAR(d."후원신청일"), 4) AS dev_year,
COALESCE(c."상위캠페인명", d."상위캠페인") AS "상위캠페인명", 
COALESCE(c."세부캠페인명", d."세부캠페인") AS "세부캠페인명", 
d."금액", d."개발구분"
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
WHERE d."개발구분" = '증액' 
) 
SELECT
i."회원번호", i.dev_month AS "개발월", i.dev_year AS "개발연도",
i."상위캠페인명", i."세부캠페인명", i."금액", i."개발구분", 
CASE WHEN a."회원번호" IS NOT NULL THEN 'Y' ELSE 'N' END AS "알림톡수신여부"
FROM increase_dev i 
LEFT JOIN alimtalk_members a ON i."회원번호" = a."회원번호";
-- 앱 GA 방문/이벤트 참여(engagement) 지표 뷰
create or replace view V_APP_ENGAGEMENT(
	"페이지경로",
	"이벤트이름",
	"회원ID",
	"세션수",
	"페이지뷰",
	"활성사용자수",
	"방문수",
	"이벤트수"
) as
SELECT
"페이지경로", 
"이벤트이름", 
"회원ID", 
TRY_TO_NUMBER("세션수") AS "세션수",
TRY_TO_NUMBER("페이지뷰") AS "페이지뷰",
TRY_TO_NUMBER("활성사용자수") AS "활성사용자수",
TRY_TO_NUMBER("방문수") AS "방문수",
TRY_TO_NUMBER("이벤트수") AS "이벤트수" 
FROM GN_DW_POC.RAW.FACT_GA_VISITS_APP;
-- 매체별(DRTV/디지털/재송출) 예산 집행 효율 통합 뷰
create or replace view V_BUDGET_EFFICIENCY( 
	"매체구분",
	"기준일",
	"월",
	"월별 예산",
	"집행 예산",
	"누계 집행 예산",
	"누계집행율",
	"연 광고예산",
	"개발건수",
	"건당비용(CPA)",
	"연도",
	"예산절차"
) as
WITH drtv AS (
SELECT 'DRTV' AS "매체구분", "구분" AS "기준일", "월 구분" AS "월", 
"월별 예산", "집행 예산", "누계 집행 예산", "누계집행율", "연 광고예산",
"월별 실적" AS "개발건수",
CASE WHEN "월별 실적" > 0 THEN "집행 예산" / "월별 실적" ELSE NULL END AS "건당비용(CPA)",
"해당연도" AS "연도", "예산절차"
FROM GN_DW_POC.RAW.FACT_DRTV_MONTHLY_DEV
WHERE "월 구분" IS NOT NULL AND "예산절차" IS NOT NULL
),
digital AS (
SELECT '디지털' AS "매체구분", "날짜" AS "기준일", "월",
"월별 편성예산(원)" AS "월별 예산", "월별 집행예산(원)" AS "집행 예산", 
NULL AS "누계 집행 예산", NULL AS "누계집행율", 
"연 광고 예산(원)" AS "연 광고예산",
"월별 개발실적(건)" AS "개발건수",
CASE WHEN "월별 개발실적(건)" > 0 THEN "월별 집행예산(원)" / "월별 개발실적(건)" ELSE NULL END AS "건당비용(CPA)",
"연도", "예산절차"
FROM GN_DW_POC.RAW.FACT_DIGITAL_MONTHLY_DEV 
WHERE "월" IS NOT NULL AND "예산절차" IS NOT NULL 
),
retransmit AS ( 
SELECT '재송출' AS "매체구분", "구분" AS "기준일", "월 구분" AS "월", 
"월별 예산", "집행 예산", "누계 집행 예산", "누계집행율", "연 광고예산",
"월별 실적" AS "개발건수",
CASE WHEN "월별 실적" > 0 THEN "집행 예산" / "월별 실적" ELSE NULL END AS "건당비용(CPA)",
"연도", "예산절차"
FROM GN_DW_POC.RAW.FACT_RETRANSMIT_MONTHLY_DEV
WHERE "월 구분" IS NOT NULL AND "예산절차" IS NOT NULL
) 
SELECT * FROM drtv
UNION ALL SELECT * FROM digital 
UNION ALL SELECT * FROM retransmit; 
-- 캠페인별 월별 개발건수/총금액 집계 뷰(개발 실적 예측용)
create or replace view V_CAMPAIGN_DEV_FORECAST( 
	"신청월",
	"브랜드",
	"상위캠페인",
	"캠페인코드",
	"개발구분",
	"개발건수",
	"총금액",
	"캠페인명",
	"상위캠페인명",
	"브랜드명",
	"실적부서명",
	"실적부서",
	"후원사업",
	"홍보방법",
	"법인구분"
) as
SELECT
LEFT(TO_VARCHAR(d."후원신청일"), 6) AS "신청월",
d."브랜드", 
d."상위캠페인", 
d."세부캠페인코드" AS "캠페인코드", 
d."개발구분", 
COUNT(*) AS "개발건수", 
SUM(d."금액") AS "총금액",
COALESCE(c."세부캠페인명", d."세부캠페인") AS "캠페인명", 
COALESCE(c."상위캠페인명", d."상위캠페인") AS "상위캠페인명", 
d."브랜드" AS "브랜드명", 
o."부서명" AS "실적부서명", 
d."실적부서코드" AS "실적부서", 
d."후원사업", 
d."홍보방법", 
d."법인구분"
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
LEFT JOIN GN_DW_POC.RAW.DIM_ORG_CODE o ON d."실적부서코드" = o."부서코드" 
WHERE d."개발구분" IN ('신규', '증액', '재후원')
GROUP BY LEFT(TO_VARCHAR(d."후원신청일"), 6), d."브랜드", d."상위캠페인", 
 d."세부캠페인코드", d."개발구분",
 c."세부캠페인명", c."상위캠페인명", d."세부캠페인",
 o."부서명", d."실적부서코드", d."후원사업", d."홍보방법", d."법인구분";
-- 캠페인별 유지율/회비(생존분석 기반) 예측 뷰
create or replace view V_CAMPAIGN_FEE_FORECAST( 
	"캠페인코드",
	"캠페인명",
	"상위캠페인명",
	"총개발건수",
	"중단건수",
	"유지율",
	"평균개발금액",
	"평균활동개월수",
	"평균납입금액",
	"총중단건수",
	"평균중단활동개월수",
	"공통브랜드명",
	"공통상위캠페인명",
	"국내해외구분"
) as
WITH survival AS (
SELECT d."세부캠페인코드" AS "캠페인코드",
COALESCE(c."세부캠페인명", d."세부캠페인") AS "캠페인명", 
COALESCE(c."상위캠페인명", d."상위캠페인") AS "상위캠페인명", 
COUNT(*) AS "총개발건수", 
0 AS "중단건수",
1.0 AS "유지율",
AVG(d."금액") AS "평균개발금액",
NULL AS "평균활동개월수", 
NULL AS "평균납입금액", 
c."공통브랜드명", 
c."공통상위캠페인명", 
c."국내해외구분"
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
WHERE d."개발구분" IN ('신규', '증액', '재후원')
GROUP BY d."세부캠페인코드", c."세부캠페인명", c."상위캠페인명", d."상위캠페인", d."세부캠페인", c."공통브랜드명", c."공통상위캠페인명", c."국내해외구분" 
) 
SELECT "캠페인코드", "캠페인명", "상위캠페인명", "총개발건수", "중단건수", "유지율", "평균개발금액", "평균활동개월수", "평균납입금액", "중단건수" AS "총중단건수", "평균활동개월수" AS "평균중단활동개월수",
"공통브랜드명", "공통상위캠페인명", "국내해외구분"
FROM survival;
-- 캠페인별 LTV(생애가치) 분석 뷰
create or replace view V_CAMPAIGN_LTV(
	"캠페인코드",
	"캠페인명",
	"상위캠페인명",
	"브랜드명",
	"개발건수",
	"총개발금액",
	"총납입금액",
	"평균납입금액",
	"중단건수",
	"평균활동일수",
	"평균개발금액",
	CAMPAIGN_CODE
) as
SELECT
d."세부캠페인코드" AS "캠페인코드", 
COALESCE(c."세부캠페인명", d."세부캠페인") AS "캠페인명", 
COALESCE(c."상위캠페인명", d."상위캠페인") AS "상위캠페인명", 
COALESCE(c."브랜드명", d."브랜드") AS "브랜드명", 
COUNT(*) AS "개발건수", 
SUM(d."금액") AS "총개발금액",
NULL AS "총납입금액", 
NULL AS "평균납입금액", 
0 AS "중단건수",
NULL AS "평균활동일수", 
AVG(d."금액") AS "평균개발금액",
d."세부캠페인코드" AS CAMPAIGN_CODE 
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
WHERE d."개발구분" IN ('신규', '증액', '재후원')
GROUP BY d."세부캠페인코드", c."세부캠페인명", c."상위캠페인명", c."브랜드명", d."상위캠페인", d."브랜드", d."세부캠페인";
-- 캠페인별 광고비 대비 ROI/CPA 분석 뷰
create or replace view V_CAMPAIGN_ROI(
	"캠페인명",
	"총광고비",
	"총개발건수",
	"총개발실적",
	"신규후원자수",
	"총약정금액",
	CPA,
	ROI
) as
WITH ad_cost_by_campaign AS ( 
SELECT "상위캠페인명", SUM("광고비") AS total_ad_cost 
FROM GN_DW_POC.ANALYTICS.V_MEDIA_EFFICIENCY_DETAIL
WHERE "상위캠페인명" IS NOT NULL AND "상위캠페인명" != '' 
GROUP BY "상위캠페인명" 
),
dev_data AS ( 
SELECT COALESCE(c."상위캠페인명", d."상위캠페인") AS campaign_name, 
COUNT(*) AS total_dev_raw, SUM(d."금액") / 10000.0 AS dev_performance,
SUM(CASE WHEN d."개발구분" = '신규' THEN 1 ELSE 0 END) AS new_sponsors, 
SUM(d."금액") AS total_pledge_amount
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
WHERE d."개발구분" IN ('신규', '증액', '재후원')
GROUP BY COALESCE(c."상위캠페인명", d."상위캠페인") 
) 
SELECT
COALESCE(a."상위캠페인명", d.campaign_name) AS "캠페인명",
COALESCE(a.total_ad_cost, 0) AS "총광고비", 
COALESCE(d.total_dev_raw, 0) AS "총개발건수", 
COALESCE(d.dev_performance, 0) AS "총개발실적", 
COALESCE(d.new_sponsors, 0) AS "신규후원자수",
COALESCE(d.total_pledge_amount, 0) AS "총약정금액", 
CASE WHEN d.total_dev_raw > 0 THEN a.total_ad_cost / d.total_dev_raw ELSE NULL END AS "CPA",
CASE WHEN a.total_ad_cost > 0 THEN d.total_pledge_amount / a.total_ad_cost ELSE NULL END AS "ROI" 
FROM ad_cost_by_campaign a
FULL OUTER JOIN dev_data d ON a."상위캠페인명" = d.campaign_name
WHERE COALESCE(a."상위캠페인명", d.campaign_name) IS NOT NULL;
-- 매체(채널)별 광고비/인입콜 대비 ROI/CPA 분석 뷰
create or replace view V_CHANNEL_ROI( 
	CHANNEL_NAME,
	"매체구분",
	CHANNEL_TYPE,
	TOTAL_AD_COST,
	TOTAL_CALL,
	TOTAL_FREQ,
	LINKED_CAMPAIGNS,
	TOTAL_DEV,
	TOTAL_DEV_PERF,
	TOTAL_NEW_SPONSORS,
	CPA
) as
WITH channel_cost AS (
SELECT "매체" AS channel_name, "매체구분", "매체유형" AS channel_type,
SUM("광고비") AS total_ad_cost, SUM("인입콜") AS total_call, SUM("횟수") AS total_freq, 
COUNT(DISTINCT "상위캠페인명") AS linked_campaigns
FROM GN_DW_POC.ANALYTICS.V_MEDIA_EFFICIENCY_DETAIL
WHERE "매체" IS NOT NULL AND "매체" != '' 
GROUP BY "매체", "매체구분", "매체유형" 
),
channel_campaigns AS (
SELECT DISTINCT "매체" AS channel_name, "상위캠페인명"
FROM GN_DW_POC.ANALYTICS.V_MEDIA_EFFICIENCY_DETAIL WHERE "매체" IS NOT NULL AND "상위캠페인명" IS NOT NULL
),
campaign_dev AS ( 
SELECT COALESCE(c."상위캠페인명", d."상위캠페인") AS campaign_name, 
COUNT(*) AS dev_count, SUM(d."금액") / 10000.0 AS dev_performance,
SUM(CASE WHEN d."개발구분" = '신규' THEN 1 ELSE 0 END) AS new_sponsors
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
WHERE d."개발구분" IN ('신규', '증액', '재후원')
GROUP BY COALESCE(c."상위캠페인명", d."상위캠페인") 
) 
SELECT cc.channel_name, cc."매체구분", cc.channel_type, 
cc.total_ad_cost, cc.total_call, cc.total_freq, cc.linked_campaigns,
SUM(cd.dev_count) AS total_dev, SUM(cd.dev_performance) AS total_dev_perf,
SUM(cd.new_sponsors) AS total_new_sponsors, 
CASE WHEN SUM(cd.dev_count) > 0 THEN cc.total_ad_cost / SUM(cd.dev_count) ELSE NULL END AS cpa
FROM channel_cost cc
LEFT JOIN channel_campaigns link ON cc.channel_name = link.channel_name 
LEFT JOIN campaign_dev cd ON link."상위캠페인명" = cd.campaign_name 
GROUP BY cc.channel_name, cc."매체구분", cc.channel_type, cc.total_ad_cost, cc.total_call, cc.total_freq, cc.linked_campaigns;
-- 전환(개발)회원의 인구통계/캠페인 프로필 상세 뷰
create or replace view V_CONVERTED_MEMBER_PROFILE(
	"개발구분",
	"후원사업",
	"브랜드",
	"상위캠페인",
	"세부캠페인",
	"세부캠페인코드",
	"성별",
	"연령대",
	"지역",
	"상위캠페인명",
	"브랜드명",
	"금액",
	"신청일",
	"신청월",
	"회원번호",
	"후원번호",
	"후원사업번호",
	"실적부서",
	"실적부서명",
	"홍보방법",
	"법인구분",
	"가입경로",
	"세부캠페인명"
) as
SELECT
d."개발구분" AS "개발구분", 
d."후원사업", d."브랜드", d."상위캠페인", 
d."세부캠페인", d."세부캠페인코드", 
m."성별", m."연령대", m."지역", 
COALESCE(c."상위캠페인명", d."상위캠페인") AS "상위캠페인명", 
d."브랜드" AS "브랜드명", 
d."금액", d."후원신청일" AS "신청일", 
LEFT(TO_VARCHAR(d."후원신청일"), 6) AS "신청월",
d."회원번호", d."SPNSR_NO" AS "후원번호", d."SPNSR_BSNS_NO" AS "후원사업번호",
d."실적부서코드" AS "실적부서", o."부서명" AS "실적부서명", 
d."홍보방법", d."법인구분", d."가입경로", 
COALESCE(c."세부캠페인명", d."세부캠페인") AS "세부캠페인명"
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_MEMBER_ATTRIBUTE m ON d."회원번호" = m."회원번호" 
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
LEFT JOIN GN_DW_POC.RAW.DIM_ORG_CODE o ON d."실적부서코드" = o."부서코드" 
WHERE d."개발구분" IN ('신규', '증액', '재후원'); 
-- 중단회원 주간 보고용 상세 뷰(중단주차/사유/캠페인 포함)
create or replace view V_DISCONTINUATION_REPORT(
	"회원번호",
	"회원구분",
	"납입방식",
	"후원금액",
	"가입일",
	"중단일",
	"중단사유",
	"캠페인코드",
	"브랜드",
	"상위캠페인",
	"실적부서",
	"성별",
	"연령대",
	"지역",
	"캠페인명",
	"상위캠페인명",
	"브랜드명",
	"중단주차",
	"중단월",
	"실적부서명",
	"가입일자",
	"중단일자",
	"중단주차_연도내",
	"가입연도",
	"중단연도",
	"회원분류",
	"공통브랜드명",
	"공통상위캠페인명",
	"국내해외구분"
) as
SELECT
d."회원번호", d."회원구분", d."납입방식", d."후원금액", d."가입일", d."중단일", 
d."중단사유", 
d."가입캠페인(세부캠페인)" AS "캠페인코드", 
d."브랜드", d."상위캠페인", 
d."가입부서(실적부서)" AS "실적부서", 
m."성별", m."연령대", m."지역", 
COALESCE(c."세부캠페인명", d."가입캠페인(세부캠페인)") AS "캠페인명", 
COALESCE(c."상위캠페인명", d."상위캠페인") AS "상위캠페인명", 
COALESCE(c."브랜드명", d."브랜드") AS "브랜드명", 
CEIL(DATEDIFF('day', TRY_TO_DATE(TO_VARCHAR(d."가입일"), 'YYYYMMDD'), 
TRY_TO_DATE(TO_VARCHAR(d."중단일"), 'YYYYMMDD')) / 7.0) AS "중단주차",
LEFT(TO_VARCHAR(d."중단일"), 6) AS "중단월",
o."부서명" AS "실적부서명", 
TRY_TO_DATE(TO_VARCHAR(d."가입일"), 'YYYYMMDD') AS "가입일자",
TRY_TO_DATE(TO_VARCHAR(d."중단일"), 'YYYYMMDD') AS "중단일자",
WEEKOFYEAR(TRY_TO_DATE(TO_VARCHAR(d."중단일"), 'YYYYMMDD')) AS "중단주차_연도내", 
LEFT(TO_VARCHAR(d."가입일"), 4) AS "가입연도",
LEFT(TO_VARCHAR(d."중단일"), 4) AS "중단연도",
CASE
WHEN LEFT(TO_VARCHAR(d."가입일"), 4) = LEFT(TO_VARCHAR(d."중단일"), 4) THEN '신규'
ELSE '기존' 
END AS "회원분류",
c."공통브랜드명", 
c."공통상위캠페인명", 
c."국내해외구분"
FROM GN_DW_POC.RAW.FACT_DISCONTINUED_MEMBER d 
LEFT JOIN GN_DW_POC.RAW.DIM_MEMBER_ATTRIBUTE m ON d."회원번호" = m."회원번호" 
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."가입캠페인(세부캠페인)" = c."세부캠페인코드"
LEFT JOIN GN_DW_POC.RAW.DIM_ORG_CODE o ON d."가입부서(실적부서)" = o."부서코드";
-- 중단회원 상세 뷰(유지일수/유지개월수 계산 포함)
create or replace view V_DISCONTINUED_DETAIL( 
	"회원번호",
	"법인구분",
	"회원구분",
	"납입방식",
	"후원금액",
	"가입일",
	"중단일",
	"중단사유",
	"세부캠페인명",
	"브랜드",
	"상위캠페인",
	"가입부서",
	"가입연도",
	"중단연도",
	"가입월",
	"중단월",
	"유지일수",
	"유지개월수",
	"성별",
	"연령대",
	"지역",
	"가입일자",
	"중단일자",
	"중단주차_연도내",
	"회원분류"
) as
SELECT
d."회원번호", d."법인구분", d."회원구분", d."납입방식", 
d."후원금액", d."가입일", d."중단일", d."중단사유", 
d."가입캠페인(세부캠페인)" AS "세부캠페인명", 
d."브랜드", d."상위캠페인", 
d."가입부서(실적부서)" AS "가입부서", 
LEFT(TO_VARCHAR(d."가입일"), 4) AS "가입연도",
LEFT(TO_VARCHAR(d."중단일"), 4) AS "중단연도",
LEFT(TO_VARCHAR(d."가입일"), 6) AS "가입월",
LEFT(TO_VARCHAR(d."중단일"), 6) AS "중단월",
DATEDIFF('day', 
TRY_TO_DATE(TO_VARCHAR(d."가입일"), 'YYYYMMDD'),
TRY_TO_DATE(TO_VARCHAR(d."중단일"), 'YYYYMMDD') 
) AS "유지일수",
ROUND(DATEDIFF('day', 
TRY_TO_DATE(TO_VARCHAR(d."가입일"), 'YYYYMMDD'),
TRY_TO_DATE(TO_VARCHAR(d."중단일"), 'YYYYMMDD') 
) / 30.0, 1) AS "유지개월수", 
m."성별", m."연령대", m."지역", 
TRY_TO_DATE(TO_VARCHAR(d."가입일"), 'YYYYMMDD') AS "가입일자",
TRY_TO_DATE(TO_VARCHAR(d."중단일"), 'YYYYMMDD') AS "중단일자",
WEEKOFYEAR(TRY_TO_DATE(TO_VARCHAR(d."중단일"), 'YYYYMMDD')) AS "중단주차_연도내", 
CASE
WHEN LEFT(TO_VARCHAR(d."가입일"), 4) = LEFT(TO_VARCHAR(d."중단일"), 4) THEN '신규'
ELSE '기존' 
END AS "회원분류" 
FROM GN_DW_POC.RAW.FACT_DISCONTINUED_MEMBER d 
LEFT JOIN GN_DW_POC.RAW.DIM_MEMBER_ATTRIBUTE m ON d."회원번호" = m."회원번호";
-- 중단회원의 납입/미납 이력 결합 분석 뷰
create or replace view V_DISCONTINUED_PAYMENT_ANALYSIS( 
	"회원번호",
	"가입연도",
	"중단연도",
	"가입월",
	"중단월",
	"유지개월수",
	"유지기간구간",
	"중단사유",
	"상위캠페인",
	"세부캠페인명",
	"후원금액",
	"납입방식",
	"총청구건수",
	"미납건수",
	"미납비율",
	"성별",
	"연령대",
	"지역",
	"회원분류"
) as
WITH disc AS (
SELECT "회원번호", "가입연도", "중단연도", "가입월", "중단월",
"유지개월수", "중단사유", "상위캠페인", "세부캠페인명", 
"후원금액", "납입방식", "성별", "연령대", "지역", "회원분류", 
CASE
WHEN "유지개월수" <= 3 THEN '0~3개월' 
WHEN "유지개월수" <= 6 THEN '4~6개월' 
WHEN "유지개월수" <= 12 THEN '7~12개월' 
ELSE '12개월이상' 
END AS "유지기간구간" 
FROM GN_DW_POC.ANALYTICS.V_DISCONTINUED_DETAIL
),
payment_summary AS (
SELECT "회원번호",
COUNT(*) AS "총청구건수", 
SUM(CASE WHEN "납입금액" = 0 OR "납입금액" IS NULL THEN 1 ELSE 0 END) AS "미납건수" 
FROM GN_DW_POC.RAW.FACT_PAYMENT_HISTORY 
GROUP BY "회원번호" 
) 
SELECT
d."회원번호", d."가입연도", d."중단연도", d."가입월", d."중단월", 
d."유지개월수", d."유지기간구간", d."중단사유", d."상위캠페인", d."세부캠페인명", 
d."후원금액", d."납입방식", 
COALESCE(ps."총청구건수", 0) AS "총청구건수", 
COALESCE(ps."미납건수", 0) AS "미납건수", 
CASE WHEN COALESCE(ps."총청구건수", 0) > 0
THEN ROUND(COALESCE(ps."미납건수", 0) * 100.0 / ps."총청구건수", 1) 
ELSE 0
END AS "미납비율",
d."성별", d."연령대", d."지역", d."회원분류"
FROM disc d 
LEFT JOIN payment_summary ps ON d."회원번호" = ps."회원번호"; 
-- DRTV 스팟(CM 위치/유형)별 효율(CPC 등) 분석 뷰
create or replace view V_DRTV_SPOT_EFFICIENCY(
	"CM위치",
	"Spot Type",
	"채널사 유형",
	"방송월",
	"주차",
	"연도",
	"편성수",
	"총횟수",
	"총광고비",
	"총인입콜",
	"평균시청률",
	CPC
) as
SELECT
"CM위치", 
"Spot Type",
"채널사 유형",
"방송월", 
"주차", 
"해당연도" AS "연도", 
COUNT(*) AS "편성수", 
SUM(TRY_TO_NUMBER("횟수")) AS "총횟수", 
SUM(TRY_TO_NUMBER("실구매광고비(원)")) AS "총광고비", 
SUM(TRY_TO_NUMBER("인입콜")) AS "총인입콜", 
AVG(TRY_TO_DOUBLE("광고시청률")) AS "평균시청률", 
CASE WHEN SUM(TRY_TO_NUMBER("인입콜")) > 0
 THEN SUM(TRY_TO_NUMBER("실구매광고비(원)")) / SUM(TRY_TO_NUMBER("인입콜")) 
 ELSE NULL END AS "CPC" 
FROM GN_DW_POC.RAW.FACT_DRTV_BROADCAST_EFF
GROUP BY "CM위치", "Spot Type", "채널사 유형", "방송월", "주차", "해당연도";
-- 평균 납입금액 실적+예측 결과 통합 뷰
create or replace view V_FORECAST_AVG_PAYMENT(
	BRAND,
	MONTH_DATE,
	VALUE,
	LOWER_BOUND,
	UPPER_BOUND,
	DATA_TYPE
) as
SELECT
brand,
month_date, 
avg_payment AS value, 
NULL AS lower_bound,
NULL AS upper_bound,
'actual' AS data_type 
FROM GN_DW_POC.ANALYTICS.TRAIN_AVG_PAYMENT
UNION ALL 
SELECT
REPLACE(SERIES, '"', '') AS brand,
TS::DATE AS month_date, 
ROUND(FORECAST, 0) AS value,
ROUND(LOWER_BOUND, 0) AS lower_bound, 
ROUND(UPPER_BOUND, 0) AS upper_bound, 
'forecast' AS data_type 
FROM GN_DW_POC.ANALYTICS.FORECAST_AVG_PAYMENT_RESULT; 
-- 개발건수 실적+예측 결과 통합 뷰
create or replace view V_FORECAST_DEV_COUNT(
	BRAND,
	MONTH_DATE,
	VALUE,
	LOWER_BOUND,
	UPPER_BOUND,
	DATA_TYPE
) as
SELECT
brand,
month_date, 
dev_count AS value, 
NULL AS lower_bound,
NULL AS upper_bound,
'actual' AS data_type 
FROM GN_DW_POC.ANALYTICS.TRAIN_DEV_COUNT
UNION ALL 
SELECT
REPLACE(SERIES, '"', '') AS brand,
TS::DATE AS month_date, 
ROUND(GREATEST(FORECAST, 0), 0) AS value, 
ROUND(GREATEST(LOWER_BOUND, 0), 0) AS lower_bound,
ROUND(UPPER_BOUND, 0) AS upper_bound, 
'forecast' AS data_type 
FROM GN_DW_POC.ANALYTICS.FORECAST_DEV_COUNT_RESULT; 
-- 충성(2회 이상 개발/증액/재후원)회원 분석 뷰
create or replace view V_LOYAL_MEMBER_ANALYSIS( 
	"회원번호",
	"상위캠페인명",
	"세부캠페인명",
	"브랜드명",
	"후원사업",
	"최초신청일",
	"총개발횟수",
	"총약정금액",
	"증액횟수",
	"증액금액",
	"재후원횟수",
	"성별",
	"연령대",
	"지역"
) as
WITH member_history AS (
SELECT d."회원번호",
COALESCE(c."상위캠페인명", d."상위캠페인") AS parent_campaign,
COALESCE(c."세부캠페인명", d."세부캠페인") AS sub_campaign, 
COALESCE(c."브랜드명", d."브랜드") AS brand,
d."후원사업", d."후원신청일" AS "신청일", d."금액", 
d."개발구분" AS dev_type
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
),
member_first AS ( 
SELECT "회원번호", MIN(parent_campaign) AS parent_campaign, MIN(sub_campaign) AS sub_campaign,
MIN(brand) AS brand, MIN("후원사업") AS sponsorship, MIN("신청일") AS first_apply 
FROM member_history WHERE dev_type IN ('신규', '증액', '재후원')
GROUP BY "회원번호" 
),
member_agg AS ( 
SELECT "회원번호", COUNT(*) AS total_dev, SUM("금액") AS total_pledge,
SUM(CASE WHEN dev_type = '증액' THEN 1 ELSE 0 END) AS increase_count, 
SUM(CASE WHEN dev_type = '증액' THEN "금액" ELSE 0 END) AS increase_amount, 
SUM(CASE WHEN dev_type = '재후원' THEN 1 ELSE 0 END) AS re_sponsor_count
FROM member_history 
GROUP BY "회원번호" 
) 
SELECT f."회원번호", f.parent_campaign AS "상위캠페인명", f.sub_campaign AS "세부캠페인명", 
f.brand AS "브랜드명", f.sponsorship AS "후원사업", 
f.first_apply AS "최초신청일",
a.total_dev AS "총개발횟수", a.total_pledge AS "총약정금액",
a.increase_count AS "증액횟수", a.increase_amount AS "증액금액",
a.re_sponsor_count AS "재후원횟수", 
m."성별", m."연령대", m."지역"
FROM member_first f 
JOIN member_agg a ON f."회원번호" = a."회원번호"
LEFT JOIN GN_DW_POC.RAW.DIM_MEMBER_ATTRIBUTE m ON f."회원번호" = m."회원번호" 
WHERE a.total_dev >= 2; 
-- 매체별(DRTV/디지털/재송출) 광고 효율 상세 통합 뷰
create or replace view V_MEDIA_EFFICIENCY_DETAIL( 
	"매체구분",
	"날짜",
	"주차",
	"요일",
	"매체",
	"매체유형",
	"광고유형",
	"캠페인명",
	"상위캠페인명",
	"브랜드명",
	"횟수",
	"광고비",
	"인입콜",
	CPC,
	"광고시청률",
	"방송월",
	"연도",
	"노출수",
	"클릭수",
	"GA개발건수",
	"GA전환명수"
) as
WITH drtv AS (
SELECT 'DRTV' AS "매체구분", b."방송일자" AS "날짜", b."주차", b."요일",
b."채널" AS "매체", b."채널사 유형" AS "매체유형", 'TV광고' AS "광고유형",
b."CRM(세부캠페인)명칭" AS "캠페인명",
c."상위캠페인명", 
c."브랜드명", 
TRY_TO_NUMBER(b."횟수") AS "횟수",
TRY_TO_NUMBER(b."실구매광고비(원)") AS "광고비",
TRY_TO_NUMBER(b."인입콜") AS "인입콜",
TRY_TO_DOUBLE(b."CPC") AS "CPC",
TRY_TO_DOUBLE(b."광고시청률") AS "광고시청률",
b."방송월", b."해당연도" AS "연도", 
NULL AS "노출수", NULL AS "클릭수", NULL AS "GA개발건수", NULL AS "GA전환명수"
FROM GN_DW_POC.RAW.FACT_DRTV_BROADCAST_EFF b
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON b."CRM(세부캠페인)명칭" = c."세부캠페인명" 
),
digital AS (
SELECT '디지털' AS "매체구분", d."날짜", d."주차", d."요일",
d."매체", d."기기" AS "매체유형", d."광고유형", 
d."캠페인명", d."상위캠페인명", NULL AS "브랜드명", 
NULL AS "횟수", 
d."GA 광고비" AS "광고비",
NULL AS "인입콜", 
CASE WHEN d."클릭수" > 0 THEN d."GA 광고비" / d."클릭수" ELSE NULL END AS "CPC",
NULL AS "광고시청률", 
d."월" AS "방송월", d."연도", 
d."노출수", d."클릭수", d."GA 개발건수" AS "GA개발건수", d."GA 전환명수" AS "GA전환명수"
FROM GN_DW_POC.RAW.FACT_DIGITAL_AD_DETAIL d 
),
retransmit AS ( 
SELECT '재송출' AS "매체구분", r."날짜", r."주차", r."요일",
r."방송사" AS "매체", r."방송사 유형" AS "매체유형", r."방송 대분류" AS "광고유형", 
r."방송명" AS "캠페인명", r."상위캠페인명", NULL AS "브랜드명", 
r."횟수", 
r."방송편성비" AS "광고비", 
r."인입콜", 
CASE WHEN r."인입콜" > 0 THEN r."방송편성비" / r."인입콜" ELSE NULL END AS "CPC", 
NULL AS "광고시청률", 
r."방송월", r."년도" AS "연도", 
NULL AS "노출수", NULL AS "클릭수", NULL AS "GA개발건수", NULL AS "GA전환명수"
FROM GN_DW_POC.RAW.FACT_RETRANSMIT_BROADCAST_CONV r 
) 
SELECT * FROM drtv UNION ALL SELECT * FROM digital UNION ALL SELECT * FROM retransmit;
-- 회원 개발 실적 건별 상세 뷰
create or replace view V_MEMBER_DEV_DETAIL( 
	"신청월",
	"법인구분",
	"실적부서",
	"실적부서명",
	"브랜드명",
	"홍보방법",
	"가입경로",
	"상위캠페인",
	"상위캠페인명",
	"세부캠페인",
	"세부캠페인명",
	"세부캠페인코드",
	"후원사업",
	"개발구분",
	"회원번호",
	"금액",
	"후원번호",
	"후원사업번호",
	"성별",
	"연령대",
	"지역",
	"개발실적_건",
	MEMBER_ID,
	CAMPAIGN_CODE,
	PARENT_CAMPAIGN,
	APPLY_MONTH,
	DEV_TYPE,
	"공통브랜드명",
	"공통상위캠페인명",
	"국내해외구분"
) as
SELECT
LEFT(TO_VARCHAR(d."후원신청일"), 6) AS "신청월",
d."법인구분", d."실적부서코드" AS "실적부서", 
o."부서명" AS "실적부서명", 
d."브랜드" AS "브랜드명", d."홍보방법", d."가입경로", d."상위캠페인", 
COALESCE(c."상위캠페인명", d."상위캠페인") AS "상위캠페인명", 
d."세부캠페인" AS "세부캠페인", 
COALESCE(c."세부캠페인명", d."세부캠페인") AS "세부캠페인명", 
d."세부캠페인코드", 
d."후원사업", 
d."개발구분", 
d."회원번호", d."금액", 
d."SPNSR_NO" AS "후원번호", d."SPNSR_BSNS_NO" AS "후원사업번호",
m."성별", m."연령대", m."지역", 
d."금액" / 10000.0 AS "개발실적_건",
d."회원번호" AS MEMBER_ID,
d."세부캠페인코드" AS CAMPAIGN_CODE,
COALESCE(c."상위캠페인명", d."상위캠페인") AS PARENT_CAMPAIGN,
LEFT(TO_VARCHAR(d."후원신청일"), 6) AS APPLY_MONTH, 
d."개발구분" AS DEV_TYPE, 
c."공통브랜드명", 
c."공통상위캠페인명", 
c."국내해외구분"
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_MEMBER_ATTRIBUTE m ON d."회원번호" = m."회원번호" 
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
LEFT JOIN GN_DW_POC.RAW.DIM_ORG_CODE o ON d."실적부서코드" = o."부서코드";
-- 매체별 개발 목표 대비 실적/달성율 현황 뷰
create or replace view V_MEMBER_DEV_STATUS( 
	"매체구분",
	"기준일",
	"월",
	"월별 목표",
	"월별 실적",
	"달성율",
	"누계목표",
	"누계실적",
	"누계달성율",
	"연도",
	"예산절차"
) as
WITH drtv AS (
SELECT 'DRTV' AS "매체구분", "구분" AS "기준일", "월 구분" AS "월", 
"월별 목표", "월별 실적", "달성율", "누계목표", "누계실적", "누계달성율", 
"해당연도" AS "연도", "예산절차"
FROM GN_DW_POC.RAW.FACT_DRTV_MONTHLY_DEV
WHERE "월 구분" IS NOT NULL AND "예산절차" IS NOT NULL
),
digital AS (
SELECT '디지털' AS "매체구분", "날짜" AS "기준일", "월",
"월별 개발목표(건)" AS "월별 목표", "월별 개발실적(건)" AS "월별 실적", 
CASE WHEN "월별 개발목표(건)" > 0 THEN "월별 개발실적(건)" / "월별 개발목표(건)" ELSE NULL END AS "달성율", 
NULL AS "누계목표", NULL AS "누계실적", NULL AS "누계달성율", 
"연도", "예산절차"
FROM GN_DW_POC.RAW.FACT_DIGITAL_MONTHLY_DEV 
WHERE "월" IS NOT NULL AND "예산절차" IS NOT NULL 
),
retransmit AS ( 
SELECT '재송출' AS "매체구분", "구분" AS "기준일", "월 구분" AS "월", 
"월별 목표", "월별 실적", "달성율", "누계목표", "누계실적", "누계달성율", 
"연도", "예산절차"
FROM GN_DW_POC.RAW.FACT_RETRANSMIT_MONTHLY_DEV
WHERE "월 구분" IS NOT NULL AND "예산절차" IS NOT NULL
) 
SELECT * FROM drtv
UNION ALL SELECT * FROM digital 
UNION ALL SELECT * FROM retransmit; 
-- 회원 후원여정(개발~GA~발송~증액~중단) 통합 360도 뷰
create or replace view V_MEMBER_JOURNEY(
	"회원번호",
	"상위캠페인명",
	"세부캠페인명",
	"개발구분",
	"가입월",
	"가입금액",
	"잠재고객목록",
	"세션캠페인목록",
	"GA세션수",
	"총발송수",
	"발송종류수",
	"발송서비스목록",
	"앱세션수",
	"앱페이지뷰",
	"증액건수",
	"증액금액",
	"중단사유",
	"중단월",
	"유지개월수",
	"증액여부",
	"중단여부",
	"공통브랜드명",
	"공통상위캠페인명",
	"국내해외구분"
) as
WITH
dev AS (
SELECT "회원번호", "상위캠페인명", "세부캠페인명",
 "개발구분", "신청월", "금액",
 "공통브랜드명", "공통상위캠페인명", "국내해외구분" 
FROM GN_DW_POC.ANALYTICS.V_MEMBER_DEV_DETAIL
),
ga AS ( 
SELECT "회원번호",
 LISTAGG(DISTINCT "잠재고객이름", ', ') AS "잠재고객목록",
 LISTAGG(DISTINCT "세션캠페인", ', ') AS "세션캠페인목록",
 SUM("세션수") AS "총세션수"
FROM GN_DW_POC.RAW.FACT_AD_GA_AUDIENCE
GROUP BY "회원번호" 
),
sms AS (
SELECT "회원번호",
 COUNT(*) AS "총발송수",
 COUNT(DISTINCT "제목") AS "발송종류수",
 LISTAGG(DISTINCT "발송구분(중)", ', ') AS "발송서비스목록" 
FROM GN_DW_POC.RAW.FACT_SMS_ALIMTALK_SEND 
WHERE "발송상태" = '발송완료' 
GROUP BY "회원번호" 
),
inc AS (
SELECT "회원번호",
 COUNT(*) AS "증액건수",
 SUM("금액") AS "증액금액"
FROM GN_DW_POC.ANALYTICS.V_ALIMTALK_INCREASE_CROSS
WHERE "알림톡수신여부" IS NOT NULL
GROUP BY "회원번호" 
),
disc AS ( 
SELECT "회원번호", "중단사유", "중단월",
 "유지개월수", "후원금액" AS "중단시후원금액" 
FROM GN_DW_POC.ANALYTICS.V_DISCONTINUED_DETAIL
),
app AS (
SELECT "회원ID",
 SUM("세션수") AS "앱세션수", 
 SUM("페이지뷰") AS "앱페이지뷰"
FROM GN_DW_POC.ANALYTICS.V_APP_ENGAGEMENT 
GROUP BY "회원ID" 
) 
SELECT
d."회원번호", 
d."상위캠페인명", 
d."세부캠페인명", 
d."개발구분", 
d."신청월"AS "가입월",
d."금액"AS "가입금액",
ga."잠재고객목록",
ga."세션캠페인목록",
ga."총세션수"AS "GA세션수", 
sms."총발송수", 
sms."발송종류수", 
sms."발송서비스목록", 
app."앱세션수", 
app."앱페이지뷰", 
inc."증액건수", 
inc."증액금액", 
disc."중단사유",
disc."중단월",
disc."유지개월수",
CASE WHEN inc."회원번호" IS NOT NULL THEN 'Y' ELSE 'N' END AS "증액여부", 
CASE WHEN disc."회원번호" IS NOT NULL THEN 'Y' ELSE 'N' END AS "중단여부",
d."공통브랜드명", 
d."공통상위캠페인명", 
d."국내해외구분"
FROM dev d
LEFT JOIN gaON d."회원번호" = ga."회원번호" 
LEFT JOIN sms ON d."회원번호" = sms."회원번호"
LEFT JOIN inc ON d."회원번호" = inc."회원번호"
LEFT JOIN discON d."회원번호" = disc."회원번호" 
LEFT JOIN app ON d."회원번호" = app."회원ID"; 
-- 회비 청구/납입/미납 상세 분석 뷰
create or replace view V_PAYMENT_ANALYSIS(
	"회원번호",
	SPNSR_NO,
	SPNSR_BSNS_NO,
	"회비청구월",
	"청구연도",
	"청구금액",
	"납입금액",
	"미납금액",
	"납입일",
	"납입구분",
	"세부캠페인코드_raw",
	"세부캠페인명",
	"상위캠페인명",
	"브랜드명",
	"개발구분",
	"성별",
	"연령대",
	"지역",
	"공통브랜드명",
	"공통상위캠페인명",
	"국내해외구분"
) as
WITH dev_dedup AS ( 
SELECT "회원번호", "SPNSR_NO", "SPNSR_BSNS_NO", 
"세부캠페인코드", "세부캠페인", "상위캠페인", "브랜드", 
"개발구분", "후원신청일", "실적부서코드", 
ROW_NUMBER() OVER (PARTITION BY "회원번호", "SPNSR_NO", "SPNSR_BSNS_NO" 
ORDER BY "후원신청일" DESC) AS rn 
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL
),
dev AS (
SELECT * FROM dev_dedup WHERE rn = 1
),
dev_member_only AS (
SELECT DISTINCT "회원번호", 
FIRST_VALUE("세부캠페인코드") OVER (PARTITION BY "회원번호" ORDER BY "후원신청일" DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS "세부캠페인코드", 
FIRST_VALUE("세부캠페인") OVER (PARTITION BY "회원번호" ORDER BY "후원신청일" DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS "세부캠페인", 
FIRST_VALUE("상위캠페인") OVER (PARTITION BY "회원번호" ORDER BY "후원신청일" DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS "상위캠페인", 
FIRST_VALUE("브랜드") OVER (PARTITION BY "회원번호" ORDER BY "후원신청일" DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS "브랜드", 
FIRST_VALUE("개발구분") OVER (PARTITION BY "회원번호" ORDER BY "후원신청일" DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS "개발구분"
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL
),
disc_campaign AS (
SELECT DISTINCT d."회원번호", 
d."가입캠페인(세부캠페인)" AS "세부캠페인코드", 
d."상위캠페인", 
d."브랜드"
FROM GN_DW_POC.RAW.FACT_DISCONTINUED_MEMBER d 
) 
SELECT
p."회원번호", p."SPNSR_NO", p."SPNSR_BSNS_NO",
p."회비청구월", 
LEFT(TO_VARCHAR(p."회비청구월"), 4) AS "청구연도",
p."청구금액", p."납입금액", 
COALESCE(p."청구금액", 0) - COALESCE(p."납입금액", 0) AS "미납금액",
p."납입일", p."납입구분", 
COALESCE(dev."세부캠페인코드", dmo."세부캠페인코드", dc."세부캠페인코드") AS "세부캠페인코드_raw",
COALESCE(c1."세부캠페인명", dev."세부캠페인", dmo."세부캠페인", c2."세부캠페인명") AS "세부캠페인명", 
COALESCE(c1."상위캠페인명", dev."상위캠페인", dmo."상위캠페인", c2."상위캠페인명", dc."상위캠페인") AS "상위캠페인명",
COALESCE(c1."브랜드명", dev."브랜드", dmo."브랜드", c2."브랜드명", dc."브랜드") AS "브랜드명",
COALESCE(dev."개발구분", dmo."개발구분") AS "개발구분", 
m."성별", m."연령대", m."지역", 
COALESCE(c1."공통브랜드명", c2."공통브랜드명") AS "공통브랜드명", 
COALESCE(c1."공통상위캠페인명", c2."공통상위캠페인명") AS "공통상위캠페인명", 
COALESCE(c1."국내해외구분", c2."국내해외구분") AS "국내해외구분"
FROM GN_DW_POC.RAW.FACT_PAYMENT_HISTORY p 
LEFT JOIN dev ON p."회원번호" = dev."회원번호" AND p."SPNSR_NO" = dev."SPNSR_NO" AND p."SPNSR_BSNS_NO" = dev."SPNSR_BSNS_NO"
LEFT JOIN dev_member_only dmo ON p."회원번호" = dmo."회원번호" AND dev."회원번호" IS NULL 
LEFT JOIN disc_campaign dc ON p."회원번호" = dc."회원번호" AND dev."회원번호" IS NULL AND dmo."회원번호" IS NULL
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c1 ON COALESCE(dev."세부캠페인코드", dmo."세부캠페인코드") = c1."세부캠페인코드"
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c2 ON dc."세부캠페인코드" = c2."세부캠페인코드" AND c1."세부캠페인코드" IS NULL 
LEFT JOIN GN_DW_POC.RAW.DIM_MEMBER_ATTRIBUTE m ON p."회원번호" = m."회원번호";
-- 기간별(3/6/12개월) 회원 유지율 분석 뷰
create or replace view V_RETENTION_BY_PERIOD( 
	"상위캠페인명",
	"세부캠페인명",
	"브랜드명",
	"가입연도",
	"총가입자수",
	"중단자수",
	"현재유지율",
	"3개월유지수",
	"3개월유지율",
	"6개월유지수",
	"6개월유지율",
	"12개월유지수",
	"12개월유지율",
	"평균개발금액",
	"평균활동개월수",
	"공통브랜드명",
	"공통상위캠페인명",
	"국내해외구분"
) as
WITH member_data AS ( 
SELECT COALESCE(c."상위캠페인명", d."상위캠페인") AS parent_campaign, 
COALESCE(c."세부캠페인명", d."세부캠페인") AS sub_campaign, 
COALESCE(c."브랜드명", d."브랜드") AS brand,
d."회원번호", d."후원신청일" AS "신청일", d."금액", 
LEFT(TO_VARCHAR(d."후원신청일"), 4) AS "가입연도",
TRY_TO_DATE(TO_VARCHAR(d."후원신청일"), 'YYYYMMDD') AS join_date, 
TRY_TO_DATE(TO_VARCHAR(disc."중단일"), 'YYYYMMDD') AS disc_date,
CASE WHEN disc."회원번호" IS NOT NULL THEN 'Y' ELSE 'N' END AS "중단여부",
DATEDIFF('month', TRY_TO_DATE(TO_VARCHAR(d."후원신청일"), 'YYYYMMDD'),
COALESCE(TRY_TO_DATE(TO_VARCHAR(disc."중단일"), 'YYYYMMDD'), CURRENT_DATE())
) AS active_months, 
c."공통브랜드명", 
c."공통상위캠페인명", 
c."국내해외구분"
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL d
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON d."세부캠페인코드" = c."세부캠페인코드"
LEFT JOIN GN_DW_POC.RAW.FACT_DISCONTINUED_MEMBER disc ON d."회원번호" = disc."회원번호" 
WHERE d."개발구분" IN ('신규', '증액', '재후원')
) 
SELECT parent_campaign AS "상위캠페인명", sub_campaign AS "세부캠페인명", brand AS "브랜드명",
"가입연도", 
COUNT(*) AS "총가입자수", 
SUM(CASE WHEN "중단여부" = 'Y' THEN 1 ELSE 0 END) AS "중단자수",
ROUND(SUM(CASE WHEN "중단여부" = 'N' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS "현재유지율",
SUM(CASE WHEN active_months >= 3 THEN 1 ELSE 0 END) AS "3개월유지수", 
ROUND(SUM(CASE WHEN active_months >= 3 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS "3개월유지율", 
SUM(CASE WHEN active_months >= 6 THEN 1 ELSE 0 END) AS "6개월유지수", 
ROUND(SUM(CASE WHEN active_months >= 6 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS "6개월유지율", 
SUM(CASE WHEN active_months >= 12 THEN 1 ELSE 0 END) AS "12개월유지수", 
ROUND(SUM(CASE WHEN active_months >= 12 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS "12개월유지율", 
AVG("금액") AS "평균개발금액",
ROUND(AVG(active_months), 1) AS "평균활동개월수", 
MAX("공통브랜드명") AS "공통브랜드명",
MAX("공통상위캠페인명") AS "공통상위캠페인명",
MAX("국내해외구분") AS "국내해외구분" 
FROM member_data
GROUP BY parent_campaign, sub_campaign, brand, "가입연도";
-- 발송유형(알림톡/메일/SMS)별 전환율/전환소요일 분석 뷰
create or replace view V_SEND_CONVERSION_ANALYSIS(
	"발송유형",
	"발송구분_대",
	"전환건수",
	"평균전환소요일",
	"평균전환금액",
	"전환율",
	"총발송건수"
) as
WITH sends AS ( 
SELECT
CASE
WHEN "제목" LIKE '%알림톡%' OR "발송구분(소)" LIKE '%알림%' THEN '알림톡' 
WHEN "발송구분(대)" IN ('참여') THEN '마케팅메일' 
ELSE '문자/SMS' 
END AS send_type, 
"발송구분(대)", 
"회원번호", 
TRY_TO_TIMESTAMP("발송일시") AS send_ts 
FROM GN_DW_POC.RAW.FACT_SMS_ALIMTALK_SEND 
WHERE "회원번호" IS NOT NULL AND "발송일시" IS NOT NULL 
),
conversions AS (
SELECT
"회원번호", 
TRY_TO_DATE(TO_VARCHAR("후원신청일"), 'YYYYMMDD') AS conv_date, 
"금액", 
"개발구분" AS dev_type
FROM GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL
WHERE "개발구분" IN ('신규', '증액', '재후원')
),
matched AS (
SELECT
s.send_type, s."발송구분(대)", s."회원번호", s.send_ts, 
c.conv_date, c."금액",
DATEDIFF('day', s.send_ts::DATE, c.conv_date) AS days_to_conv 
FROM sends s
INNER JOIN conversions c ON s."회원번호" = c."회원번호" 
WHERE c.conv_date >= s.send_ts::DATE AND c.conv_date <= DATEADD('day', 90, s.send_ts::DATE) 
) 
SELECT
send_type AS "발송유형", "발송구분(대)" AS "발송구분_대", 
COUNT(*) AS "전환건수", AVG(days_to_conv) AS "평균전환소요일",
AVG("금액") AS "평균전환금액",
COUNT(*) * 1.0 / NULLIF((SELECT COUNT(DISTINCT "회원번호") FROM sends s2 WHERE s2.send_type = matched.send_type), 0) AS "전환율", 
(SELECT COUNT(DISTINCT "회원번호") FROM sends s3 WHERE s3.send_type = matched.send_type) AS "총발송건수"
FROM matched
GROUP BY send_type, "발송구분(대)"; 
-- 일시후원 → 정기후원 전환 회원 매칭 분석 뷰
create or replace view V_TEMP_MEMBER_CONVERSION(
	"정기회원번호",
	"일시회원번호",
	"전환일",
	"일시후원금액",
	"후원일",
	"실적부서명",
	"일시세부캠페인코드",
	"일시세부캠페인명",
	"정기상위캠페인명",
	"정기세부캠페인명",
	"정기브랜드명",
	"정기개발구분",
	"정기가입일"
) as
SELECT
m."회원번호(정기)" AS "정기회원번호", 
m."회원번호(일시)" AS "일시회원번호", 
m."전환일", 
d."후원금액" AS "일시후원금액", 
d."후원일", 
d."실적부서명", 
d."세부캠페인코드" AS "일시세부캠페인코드", 
d."세부캠페인명" AS "일시세부캠페인명", 
c."상위캠페인명" AS "정기상위캠페인명", 
c."세부캠페인명" AS "정기세부캠페인명", 
c."브랜드명" AS "정기브랜드명", 
dev."개발구분" AS "정기개발구분", 
dev."후원신청일" AS "정기가입일"
FROM GN_DW_POC.RAW.DIM_TEMP_TO_REGULAR_MATCH m
LEFT JOIN GN_DW_POC.RAW.FACT_TEMP_MEMBER_DONATION d ON m."회원번호(일시)" = d."일시회원번호"
LEFT JOIN GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL dev ON m."회원번호(정기)" = dev."회원번호"
AND dev."개발구분" = '신규' 
LEFT JOIN GN_DW_POC.RAW.DIM_CAMPAIGN_CODE c ON dev."세부캠페인코드" = c."세부캠페인코드"; 
-- 시간대/요일별 매체(DRTV/재송출) 광고 효율 분석 뷰
create or replace view V_TIME_SLOT_EFFICIENCY(
	"매체구분",
	"날짜",
	"시간대",
	"주중토일",
	"매체",
	"프로그램",
	"횟수",
	"광고비",
	"인입콜",
	"광고시청률",
	"방송월",
	"연도"
) as
WITH drtv AS (
SELECT
'DRTV' AS "매체구분", 
"방송일자" AS "날짜", 
"시간대", 
"주중/토/일" AS "주중토일", 
"채널" AS "매체", 
"편성명" AS "프로그램", 
TRY_TO_NUMBER("횟수") AS "횟수",
TRY_TO_NUMBER("실구매광고비(원)") AS "광고비",
TRY_TO_NUMBER("인입콜") AS "인입콜",
TRY_TO_DOUBLE("광고시청률") AS "광고시청률",
"방송월", 
"해당연도" AS "연도"
FROM GN_DW_POC.RAW.FACT_DRTV_BROADCAST_EFF
),
retransmit AS ( 
SELECT
'재송출' AS "매체구분", 
"날짜", 
"시간대 구분" AS "시간대",
NULL AS "주중토일", 
"방송사" AS "매체", 
"방송명" AS "프로그램", 
"횟수", 
"방송편성비" AS "광고비", 
"인입콜", 
NULL AS "광고시청률", 
"방송월", 
"년도" AS "연도"
FROM GN_DW_POC.RAW.FACT_RETRANSMIT_BROADCAST_CONV 
) 
SELECT * FROM drtv
UNION ALL 
SELECT * FROM retransmit; 
-- Streamlit 앱: 테스트(개발/검증용)
create or replace streamlit ONDFJOGVRZN_YDUW/versions/live' 
	main_file='streamlit_app.py'
	query_warehouse='COMPUTE_WH'
	comment='{"lastUpdatedUser":"1875080080741","lastUpdatedTime":1776823028120}'
	title='테스트';
-- Streamlit 앱: 캠페인별 LTV/CAC 분석 대시보드
create or replace streamlit P428CVN7VG4_UZGX/versions/live' 
	main_file='streamlit_app.py'
	query_warehouse='POC_WH'
	comment='{"lastUpdatedUser":"991788961584","lastUpdatedTime":1776740503926}'
	title='캠페인별 LTV/CAC 분석';
-- Streamlit 앱: 주요캠페인별 미납현황 대시보드
create or replace streamlit PKDCCUN5158BDP85/versions/live' 
	main_file='streamlit_app.py'
	query_warehouse='COMPUTE_WH'
	comment='{"lastUpdatedUser":"1875080080741","lastUpdatedTime":1776242339002}'
	title='주요캠페인별 미납현황';
-- Streamlit 앱: 개발회원 후원여정 현황 대시보드
create or replace streamlit V85MJS3P8ZIJLX3F/versions/live' 
	main_file='streamlit_app.py'
	query_warehouse='COMPUTE_WH'
	comment='{"lastUpdatedUser":"1875080080741","lastUpdatedTime":1776674541592}'
	title='개발회원 후원여정 현황';
-- Streamlit 앱: 주간 중단회원 보고 대시보드
create or replace streamlit VH9Q89S7JE3OZNMY/versions/live' 
	main_file='streamlit_app.py'
	query_warehouse='COMPUTE_WH'
	comment='{"lastUpdatedUser":"1875080080741","lastUpdatedTime":1776822754999}'
	title='주간중단회원 보고';
-- Streamlit 앱: 주요캠페인별 중단현황 대시보드
create or replace streamlit ZA3JAG62UK__W13T/versions/live' 
	main_file='streamlit_app.py'
	query_warehouse='COMPUTE_WH'
	comment='{"lastUpdatedUser":"1875080080741","lastUpdatedTime":1776068703596}'
	title='주요캠페인별 중단현황';
