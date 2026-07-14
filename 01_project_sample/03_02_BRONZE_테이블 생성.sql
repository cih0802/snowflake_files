------------------------------------------------------
-- 3.3 BRONZE 테이블 생성
-- PoC RAW 스키마 → GN_DW.BRONZE 매핑
------------------------------------------------------
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- DIM 테이블
CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.DIM_CAMPAIGN_CODE (
    "브랜드코드" VARCHAR,
    "브랜드명" VARCHAR,
    "브랜드사용여부" VARCHAR,
    "브랜드사용부서" VARCHAR,
    "브랜드사용부서코드" VARCHAR,
    "상위캠페인코드" VARCHAR,
    "상위캠페인명" VARCHAR,
    "상위캠페인사용여부" VARCHAR,
    "세부캠페인명" VARCHAR,
    "세부캠페인코드" VARCHAR,
    "세부캠페인사용부서(실적부서)" VARCHAR,
    "실적부서코드" VARCHAR,
    "세부캠페인시작일" VARCHAR,
    "공통브랜드명" VARCHAR,
    "공통상위캠페인명" VARCHAR,
    "국내해외구분" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.DIM_CAMPAIGN_CODE_BACKUP (
    "브랜드코드" VARCHAR,
    "브랜드명" VARCHAR,
    "브랜드사용여부" VARCHAR,
    "브랜드사용부서" VARCHAR,
    "상위캠페인코드" VARCHAR,
    "상위캠페인명" VARCHAR,
    "상위캠페인사용여부" VARCHAR,
    "세부캠페인명" VARCHAR,
    "세부캠페인코드" VARCHAR,
    "세부캠페인사용부서(실적부서)" VARCHAR,
    "세부캠페인사용여부" VARCHAR,
    "실적부서코드" VARCHAR,
    "세부캠페인시작일" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.DIM_MEMBER_ATTRIBUTE (
    "회원번호" VARCHAR,
    "성별" VARCHAR,
    "연령대" VARCHAR,
    "지역" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.DIM_ORG_CODE (
    "부서코드" VARCHAR,
    "부서명" VARCHAR,
    "부서경로" VARCHAR,
    "상위부서코드" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.DIM_TEMP_TO_REGULAR_MATCH (
    "회원번호(정기)" VARCHAR,
    "회원번호(일시)" VARCHAR,
    "전환일" VARCHAR
);

-- FACT 테이블
CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_AD_GA_AUDIENCE (
    "날짜" NUMBER(38,0),
    "잠재고객이름" VARCHAR,
    "세션캠페인" VARCHAR,
    "회원번호" VARCHAR,
    "세션수" NUMBER(38,0),
    "활성사용자" NUMBER(38,0)
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_AD_GOOGLE_DEMANDGEN (
    "날짜" VARCHAR,
    "캠페인유형" VARCHAR,
    "캠페인이름" VARCHAR,
    "기기" VARCHAR,
    "타겟팅" VARCHAR,
    "방문페이지" VARCHAR,
    "노출수" NUMBER(38,0),
    "클릭수" NUMBER(38,0),
    "통화" VARCHAR,
    "비용" NUMBER(38,0),
    "전환수" NUMBER(38,0),
    "전환율" FLOAT,
    "전환가치" FLOAT
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_AD_GOOGLE_PMAX (
    "날짜" VARCHAR,
    "캠페인유형" VARCHAR,
    "캠페인이름" VARCHAR,
    "기기" VARCHAR,
    "방문페이지" VARCHAR,
    "최종URL" VARCHAR,
    "노출수" NUMBER(38,0),
    "클릭수" NUMBER(38,0),
    "통화" VARCHAR,
    "비용" NUMBER(38,0),
    "전환수" NUMBER(38,0),
    "전환율" FLOAT,
    "전환가치" FLOAT
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_AD_META (
    "일" VARCHAR,
    "캠페인이름" VARCHAR,
    "광고세트이름" VARCHAR,
    "광고이름" VARCHAR,
    "노출" NUMBER(38,0),
    "링크클릭" FLOAT,
    "지출금액_KRW" NUMBER(38,0),
    "캠페인예산" VARCHAR,
    "캠페인예산유형" VARCHAR,
    "광고세트예산" FLOAT,
    "광고세트예산유형" VARCHAR,
    "구매" FLOAT,
    "구매당비용" FLOAT,
    "보고시작" VARCHAR,
    "보고종료" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_DIGITAL_AD_DETAIL (
    "연도" VARCHAR,
    "국내/해외" VARCHAR,
    "사업/사례" VARCHAR,
    "캠페인 유형" VARCHAR,
    "광고유형" VARCHAR,
    "월" VARCHAR,
    "기기" VARCHAR,
    "매체" VARCHAR,
    "날짜" VARCHAR,
    "주차" VARCHAR,
    "일자" VARCHAR,
    "요일" VARCHAR,
    "캠페인명" VARCHAR,
    "소재" VARCHAR,
    "노출수" FLOAT,
    "클릭수" FLOAT,
    "GA 광고비" FLOAT,
    "GA 전환명수" FLOAT,
    "GA 개발건수" FLOAT,
    "상위캠페인명" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_DIGITAL_MONTHLY_DEV (
    "연도" VARCHAR,
    "예산절차" VARCHAR,
    "월" VARCHAR,
    "날짜" VARCHAR,
    "월별 개발목표(건)" FLOAT,
    "월별 개발실적(건)" FLOAT,
    "연목표(건)" FLOAT,
    "월별 편성예산(원)" FLOAT,
    "월별 집행예산(원)" FLOAT,
    "연 광고 예산(원)" FLOAT
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_DISCONTINUED_MEMBER (
    "순번" NUMBER(38,0),
    "법인구분" VARCHAR,
    "회원번호" VARCHAR,
    "회원구분" VARCHAR,
    "납입방식" VARCHAR,
    "후원금액" NUMBER(38,0),
    "가입일" NUMBER(38,0),
    "중단일" NUMBER(38,0),
    "중단사유" VARCHAR,
    "가입캠페인(세부캠페인)" VARCHAR,
    "브랜드" VARCHAR,
    "상위캠페인" VARCHAR,
    "가입부서(실적부서)" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_DRTV_BROADCAST_EFF (
    "채널" VARCHAR,
    "요일" VARCHAR,
    "방송일자" VARCHAR,
    "시간대" VARCHAR,
    "주중/토/일" VARCHAR,
    "프로그램 시작시간" VARCHAR,
    "편성명" VARCHAR,
    CM VARCHAR,
    "CM위치" VARCHAR,
    "광고 시작시간" VARCHAR,
    "광고시청률" VARCHAR,
    "광고종료시간" VARCHAR,
    "Spot Type" VARCHAR,
    "횟수" VARCHAR,
    "초수" VARCHAR,
    "실구매광고비(원)" VARCHAR,
    "인입콜" VARCHAR,
    CPC VARCHAR,
    "소재" VARCHAR,
    "CRM(세부캠페인)명칭" VARCHAR,
    "소재 일관화" VARCHAR,
    "주차" VARCHAR,
    "요일2" VARCHAR,
    "방송월" VARCHAR,
    "채널사 유형" VARCHAR,
    "해당연도" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_DRTV_MONTHLY_DEV (
    "구분" VARCHAR,
    "월별 목표" FLOAT,
    "월별 실적" FLOAT,
    "달성율" FLOAT,
    "누계목표" FLOAT,
    "누계실적" FLOAT,
    "누계달성율" FLOAT,
    "월별 예산" FLOAT,
    "집행 예산" FLOAT,
    "누계집행율" FLOAT,
    "누계 집행 예산" FLOAT,
    "연목표" FLOAT,
    "연 광고예산" FLOAT,
    "해당연도" VARCHAR,
    "예산절차" VARCHAR,
    "월 구분" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_GA_FEEDBACK_PAGE (
    "페이지경로쿼리" VARCHAR,
    "세션수" VARCHAR,
    "페이지뷰" VARCHAR,
    "이벤트수" VARCHAR,
    "이탈률" VARCHAR,
    "참여율" VARCHAR,
    "평균세션시간" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_GA_VISITS_APP (
    "페이지경로" VARCHAR,
    "이벤트이름" VARCHAR,
    "회원ID" VARCHAR,
    "세션수" VARCHAR,
    "페이지뷰" VARCHAR,
    "활성사용자수" VARCHAR,
    "방문수" VARCHAR,
    "이벤트수" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_GA_VISITS_MOBILE (
    "페이지경로" VARCHAR,
    "이벤트이름" VARCHAR,
    "회원ID" VARCHAR,
    "세션수" VARCHAR,
    "페이지뷰" VARCHAR,
    "활성사용자수" VARCHAR,
    "방문수" VARCHAR,
    "이벤트수" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_GA_VISITS_PC (
    "페이지경로" VARCHAR,
    "회원ID" VARCHAR,
    "세션수" VARCHAR,
    "페이지뷰" VARCHAR,
    "활성사용자수" VARCHAR,
    "방문수" VARCHAR,
    "이벤트수" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_GA_VISITS_TOTAL (
    "페이지경로" VARCHAR,
    "이벤트이름" VARCHAR,
    "세션캠페인" VARCHAR,
    "회원ID" VARCHAR,
    "세션수" VARCHAR,
    "페이지뷰" VARCHAR,
    "활성사용자수" VARCHAR,
    "방문수" VARCHAR,
    "이벤트수" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_MARKETING_SEND_NEW (
    "순번" NUMBER(38,0),
    "발송구분(대)" VARCHAR,
    "발송구분(중)" VARCHAR,
    "발송구분(소)" VARCHAR,
    "제목" VARCHAR,
    "총건수" VARCHAR,
    "성공건수" VARCHAR,
    "회원번호" VARCHAR,
    "발송일시" VARCHAR,
    "발송상태" VARCHAR,
    "대체발송" VARCHAR,
    "등록일" VARCHAR,
    "성공률(%)" VARCHAR,
    "브랜드" VARCHAR,
    "상위캠페인" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_MEMBER_DEV_ALL (
    "법인구분" VARCHAR,
    "후원신청일" NUMBER(38,0),
    "실적부서코드" VARCHAR,
    "실적부서" VARCHAR,
    "브랜드ID" NUMBER(38,0),
    "브랜드" VARCHAR,
    "홍보방법" VARCHAR,
    "가입경로" VARCHAR,
    "상위캠페인코드" VARCHAR,
    "상위캠페인" VARCHAR,
    "세부캠페인코드" VARCHAR,
    "세부캠페인" VARCHAR,
    "후원사업ID" NUMBER(38,0),
    "후원사업" VARCHAR,
    "개발구분" VARCHAR,
    "회원번호" VARCHAR,
    "금액" NUMBER(38,0),
    SPNSR_NO NUMBER(38,0),
    SPNSR_BSNS_NO NUMBER(38,0)
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_PAYMENT_HISTORY (
    "회원번호" VARCHAR,
    SPNSR_NO NUMBER(38,0),
    SPNSR_BSNS_NO NUMBER(38,0),
    "회비청구월" NUMBER(38,0),
    "청구금액" NUMBER(38,0),
    "납입금액" NUMBER(38,0),
    "납입일" VARCHAR,
    "납입구분" VARCHAR,
    "비고" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_RETRANSMIT_BROADCAST_CONV (
    "구분" VARCHAR,
    "년도" VARCHAR,
    "방송월" VARCHAR,
    "방송사" VARCHAR,
    "방송명" VARCHAR,
    "상위캠페인명" VARCHAR,
    "본방송 구분" VARCHAR,
    "날짜" VARCHAR,
    "요일" VARCHAR,
    "방송시간" VARCHAR,
    "인입콜" FLOAT,
    "회원개발(건)" FLOAT,
    "방송편성비" FLOAT,
    "주차" VARCHAR,
    "횟수" FLOAT,
    "시간대 구분" VARCHAR,
    "국내/해외 구분" VARCHAR,
    "실적부서" VARCHAR,
    "방송사 유형" VARCHAR,
    "방송 대분류" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_RETRANSMIT_MONTHLY_DEV (
    "구분" VARCHAR,
    "월별 목표" FLOAT,
    "월별 실적" FLOAT,
    "달성율" FLOAT,
    "누계목표" FLOAT,
    "누계실적" FLOAT,
    "누계달성율" FLOAT,
    "월별 예산" FLOAT,
    "집행 예산" FLOAT,
    "누계집행율" FLOAT,
    "누계 집행 예산" FLOAT,
    "연목표" FLOAT,
    "연 광고예산" FLOAT,
    "연도" VARCHAR,
    "예산절차" VARCHAR,
    "월 구분" VARCHAR,
    "방송구분" VARCHAR,
    "실적부서" VARCHAR
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_SMS_ALIMTALK_SEND (
    "순번" NUMBER(38,0),
    "발송구분(대)" VARCHAR,
    "발송구분(중)" VARCHAR,
    "발송구분(소)" VARCHAR,
    "제목" VARCHAR,
    "총건수" VARCHAR,
    "성공건수" VARCHAR,
    "회원번호" VARCHAR,
    "발송일시" VARCHAR,
    "발송상태" VARCHAR,
    "대체발송" VARCHAR,
    "등록일" VARCHAR,
    "성공률(%)" VARCHAR,
    "일시후원여부" VARCHAR DEFAULT 'N'
);

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE.FACT_TEMP_MEMBER_DONATION (
    "일시회원번호" VARCHAR,
    "후원금액" NUMBER(38,0),
    "후원일" VARCHAR,
    "실적부서코드" VARCHAR,
    "실적부서명" VARCHAR,
    "세부캠페인코드" NUMBER(38,0),
    "세부캠페인명" VARCHAR
);
