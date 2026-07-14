-- PoC 당시 RAW 스키마와 하위 DDL 백업 (각 쿼리별 설명 주석 포함)

-- RAW 스키마 생성 (없으면 만들고 있으면 덮어씀)
create or replace schema RAW;

-- 캠페인 코드 차원 테이블: 브랜드/상위캠페인/세부캠페인 코드 및 부서 정보 정의
create or replace TABLE DIM_CAMPAIGN_CODE (
  "브랜드코드" VARCHAR(16777216),
  "브랜드명" VARCHAR(16777216),
  "브랜드사용여부" VARCHAR(16777216),
  "브랜드사용부서" VARCHAR(16777216),
  "브랜드사용부서코드" VARCHAR(16777216),
  "상위캠페인코드" VARCHAR(16777216),
  "상위캠페인명" VARCHAR(16777216),
  "상위캠페인사용여부" VARCHAR(16777216),
  "세부캠페인명" VARCHAR(16777216),
  "세부캠페인코드" VARCHAR(16777216),
  "세부캠페인사용부서(실적부서)" VARCHAR(16777216),
  "실적부서코드" VARCHAR(16777216),
  "세부캠페인시작일" VARCHAR(16777216),
  "공통브랜드명" VARCHAR(16777216),
  "공통상위캠페인명" VARCHAR(16777216),
  "국내해외구분" VARCHAR(16777216)
);
-- 캠페인 코드 차원 백업 테이블: DIM_CAMPAIGN_CODE의 이전 버전 백업본
create or replace TABLE DIM_CAMPAIGN_CODE_BACKUP (
  "브랜드코드" VARCHAR(16777216),
  "브랜드명" VARCHAR(16777216),
  "브랜드사용여부" VARCHAR(16777216),
  "브랜드사용부서" VARCHAR(16777216),
  "상위캠페인코드" VARCHAR(16777216),
  "상위캠페인명" VARCHAR(16777216),
  "상위캠페인사용여부" VARCHAR(16777216),
  "세부캠페인명" VARCHAR(16777216),
  "세부캠페인코드" VARCHAR(16777216),
  "세부캠페인사용부서(실적부서)" VARCHAR(16777216),
  "세부캠페인사용여부" VARCHAR(16777216),
  "실적부서코드" VARCHAR(16777216),
  "세부캠페인시작일" VARCHAR(16777216)
);
-- 회원 속성 차원 테이블: 회원번호별 성별/연령대/지역 정보
create or replace TABLE DIM_MEMBER_ATTRIBUTE (
  "회원번호" VARCHAR(16777216),
  "성별" VARCHAR(16777216),
  "연령대" VARCHAR(16777216),
  "지역" VARCHAR(16777216)
);
-- 조직(부서) 코드 차원 테이블: 부서코드/부서명/부서경로 및 상위부서 계층 정보
create or replace TABLE DIM_ORG_CODE (
  "부서코드" VARCHAR(16777216),
  "부서명" VARCHAR(16777216),
  "부서경로" VARCHAR(16777216),
  "상위부서코드" VARCHAR(16777216)
);
-- 일시→정기 회원 전환 매핑 테이블: 정기/일시 회원번호와 전환일 연결
create or replace TABLE DIM_TEMP_TO_REGULAR_MATCH (
  "회원번호(정기)" VARCHAR(16777216),
  "회원번호(일시)" VARCHAR(16777216),
  "전환일" VARCHAR(16777216)
);
-- GA 잠재고객 광고 실적 팩트 테이블: 날짜/캠페인별 세션수·활성사용자
create or replace TABLE FACT_AD_GA_AUDIENCE (
  "날짜" NUMBER(38,0),
  "잠재고객이름" VARCHAR(16777216),
  "세션캠페인" VARCHAR(16777216),
  "회원번호" VARCHAR(16777216),
  "세션수" NUMBER(38,0),
  "활성사용자" NUMBER(38,0)
);
-- 구글 디맨드젠 광고 실적 팩트 테이블: 노출/클릭/비용/전환 지표
create or replace TABLE FACT_AD_GOOGLE_DEMANDGEN (
  "날짜" VARCHAR(16777216),
  "캠페인유형" VARCHAR(16777216),
  "캠페인이름" VARCHAR(16777216),
  "기기" VARCHAR(16777216),
  "타겟팅" VARCHAR(16777216),
  "방문페이지" VARCHAR(16777216),
  "노출수" NUMBER(38,0),
  "클릭수" NUMBER(38,0),
  "통화" VARCHAR(16777216),
  "비용" NUMBER(38,0),
  "전환수" NUMBER(38,0),
  "전환율" FLOAT,
  "전환가치" FLOAT
);
-- 구글 PMax 광고 실적 팩트 테이블: 노출/클릭/비용/전환 지표
create or replace TABLE FACT_AD_GOOGLE_PMAX (
  "날짜" VARCHAR(16777216),
  "캠페인유형" VARCHAR(16777216),
  "캠페인이름" VARCHAR(16777216),
  "기기" VARCHAR(16777216),
  "방문페이지" VARCHAR(16777216),
  "최종URL" VARCHAR(16777216),
  "노출수" NUMBER(38,0),
  "클릭수" NUMBER(38,0),
  "통화" VARCHAR(16777216),
  "비용" NUMBER(38,0),
  "전환수" NUMBER(38,0),
  "전환율" FLOAT,
  "전환가치" FLOAT
);
-- 메타(페이스북/인스타) 광고 실적 팩트 테이블: 캠페인/광고세트/광고별 노출·지출·구매
create or replace TABLE FACT_AD_META (
  "일" VARCHAR(16777216),
  "캠페인이름" VARCHAR(16777216),
  "광고세트이름" VARCHAR(16777216),
  "광고이름" VARCHAR(16777216),
  "노출" NUMBER(38,0),
  "링크클릭" FLOAT,
  "지출금액_KRW" NUMBER(38,0),
  "캠페인예산" VARCHAR(16777216),
  "캠페인예산유형" VARCHAR(16777216),
  "광고세트예산" FLOAT,
  "광고세트예산유형" VARCHAR(16777216),
  "구매" FLOAT,
  "구매당비용" FLOAT,
  "보고시작" VARCHAR(16777216),
  "보고종료" VARCHAR(16777216)
);
-- 디지털 광고 상세 팩트 테이블: 매체/소재/일자별 노출·클릭·광고비·전환·개발 지표
create or replace TABLE FACT_DIGITAL_AD_DETAIL (
  "연도" VARCHAR(16777216),
  "국내/해외" VARCHAR(16777216),
  "사업/사례" VARCHAR(16777216),
  "캠페인 유형" VARCHAR(16777216),
  "광고유형" VARCHAR(16777216),
  "월" VARCHAR(16777216),
  "기기" VARCHAR(16777216),
  "매체" VARCHAR(16777216),
  "날짜" VARCHAR(16777216),
  "주차" VARCHAR(16777216),
  "일자" VARCHAR(16777216),
  "요일" VARCHAR(16777216),
  "캠페인명" VARCHAR(16777216),
  "소재" VARCHAR(16777216),
  "노출수" FLOAT,
  "클릭수" FLOAT,
  "GA 광고비" FLOAT,
  "GA 전환명수" FLOAT,
  "GA 개발건수" FLOAT,
  "상위캠페인명" VARCHAR(16777216)
);
-- 디지털 월별 개발(회원모집) 목표·실적·예산 팩트 테이블
create or replace TABLE FACT_DIGITAL_MONTHLY_DEV (
  "연도" VARCHAR(16777216),
  "예산절차" VARCHAR(16777216),
  "월" VARCHAR(16777216),
  "날짜" VARCHAR(16777216),
  "월별 개발목표(건)" FLOAT,
  "월별 개발실적(건)" FLOAT,
  "연목표(건)" FLOAT,
  "월별 편성예산(원)" FLOAT,
  "월별 집행예산(원)" FLOAT,
  "연 광고 예산(원)" FLOAT
);
-- 후원 중단 회원 팩트 테이블: 중단 회원의 가입/중단 정보 및 캠페인·부서 내역
create or replace TABLE FACT_DISCONTINUED_MEMBER (
  "순번" NUMBER(38,0),
  "법인구분" VARCHAR(16777216),
  "회원번호" VARCHAR(16777216),
  "회원구분" VARCHAR(16777216),
  "납입방식" VARCHAR(16777216),
  "후원금액" NUMBER(38,0),
  "가입일" NUMBER(38,0),
  "중단일" NUMBER(38,0),
  "중단사유" VARCHAR(16777216),
  "가입캠페인(세부캠페인)" VARCHAR(16777216),
  "브랜드" VARCHAR(16777216),
  "상위캠페인" VARCHAR(16777216),
  "가입부서(실적부서)" VARCHAR(16777216)
);
-- DRTV 방송 효과 팩트 테이블: 채널/편성/광고별 시청률·광고비·인입콜 등 방송 성과
create or replace TABLE FACT_DRTV_BROADCAST_EFF (
  "채널" VARCHAR(16777216),
  "요일" VARCHAR(16777216),
  "방송일자" VARCHAR(16777216),
  "시간대" VARCHAR(16777216),
  "주중/토/일" VARCHAR(16777216),
  "프로그램 시작시간" VARCHAR(16777216),
  "편성명" VARCHAR(16777216),
  CM VARCHAR(16777216),
  "CM위치" VARCHAR(16777216),
  "광고 시작시간" VARCHAR(16777216),
  "광고시청률" VARCHAR(16777216),
  "광고종료시간" VARCHAR(16777216),
  "Spot Type" VARCHAR(16777216),
  "횟수" VARCHAR(16777216),
  "초수" VARCHAR(16777216),
  "실구매광고비(원)" VARCHAR(16777216),
  "인입콜" VARCHAR(16777216),
  CPC VARCHAR(16777216),
  "소재" VARCHAR(16777216),
  "CRM(세부캠페인)명칭" VARCHAR(16777216),
  "소재 일관화" VARCHAR(16777216),
  "주차" VARCHAR(16777216),
  "요일2" VARCHAR(16777216),
  "방송월" VARCHAR(16777216),
  "채널사 유형" VARCHAR(16777216),
  "해당연도" VARCHAR(16777216)
);
-- DRTV 월별 개발 목표·실적·예산 및 누계 달성/집행율 팩트 테이블
create or replace TABLE FACT_DRTV_MONTHLY_DEV (
  "구분" VARCHAR(16777216),
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
  "해당연도" VARCHAR(16777216),
  "예산절차" VARCHAR(16777216),
  "월 구분" VARCHAR(16777216)
);
-- GA 피드백 페이지 팩트 테이블: 페이지별 세션·페이지뷰·이탈률·참여율 등 행동 지표
create or replace TABLE FACT_GA_FEEDBACK_PAGE (
  "페이지경로쿼리" VARCHAR(16777216),
  "세션수" VARCHAR(16777216),
  "페이지뷰" VARCHAR(16777216),
  "이벤트수" VARCHAR(16777216),
  "이탈률" VARCHAR(16777216),
  "참여율" VARCHAR(16777216),
  "평균세션시간" VARCHAR(16777216)
);
-- GA 앱 방문 팩트 테이블: 앱 페이지/이벤트별 세션·페이지뷰·방문 지표
create or replace TABLE FACT_GA_VISITS_APP (
  "페이지경로" VARCHAR(16777216),
  "이벤트이름" VARCHAR(16777216),
  "회원ID" VARCHAR(16777216),
  "세션수" VARCHAR(16777216),
  "페이지뷰" VARCHAR(16777216),
  "활성사용자수" VARCHAR(16777216),
  "방문수" VARCHAR(16777216),
  "이벤트수" VARCHAR(16777216)
);
-- GA 모바일 방문 팩트 테이블: 모바일 페이지/이벤트별 세션·페이지뷰·방문 지표
create or replace TABLE FACT_GA_VISITS_MOBILE (
  "페이지경로" VARCHAR(16777216),
  "이벤트이름" VARCHAR(16777216),
  "회원ID" VARCHAR(16777216),
  "세션수" VARCHAR(16777216),
  "페이지뷰" VARCHAR(16777216),
  "활성사용자수" VARCHAR(16777216),
  "방문수" VARCHAR(16777216),
  "이벤트수" VARCHAR(16777216)
);
-- GA PC 방문 팩트 테이블: PC 페이지별 세션·페이지뷰·방문 지표
create or replace TABLE FACT_GA_VISITS_PC (
  "페이지경로" VARCHAR(16777216),
  "회원ID" VARCHAR(16777216),
  "세션수" VARCHAR(16777216),
  "페이지뷰" VARCHAR(16777216),
  "활성사용자수" VARCHAR(16777216),
  "방문수" VARCHAR(16777216),
  "이벤트수" VARCHAR(16777216)
);
-- GA 전체 방문 통합 팩트 테이블: 전 채널 합산 세션·페이지뷰·방문 지표
create or replace TABLE FACT_GA_VISITS_TOTAL (
  "페이지경로" VARCHAR(16777216),
  "이벤트이름" VARCHAR(16777216),
  "세션캠페인" VARCHAR(16777216),
  "회원ID" VARCHAR(16777216),
  "세션수" VARCHAR(16777216),
  "페이지뷰" VARCHAR(16777216),
  "활성사용자수" VARCHAR(16777216),
  "방문수" VARCHAR(16777216),
  "이벤트수" VARCHAR(16777216)
);
-- 마케팅 발송(신규) 팩트 테이블: 발송 건별 제목·건수·성공률·회원·브랜드 정보
create or replace TABLE FACT_MARKETING_SEND_NEW (
  "순번" NUMBER(38,0),
  "발송구분(대)" VARCHAR(16777216),
  "발송구분(중)" VARCHAR(16777216),
  "발송구분(소)" VARCHAR(16777216),
  "제목" VARCHAR(16777216),
  "총건수" VARCHAR(16777216),
  "성공건수" VARCHAR(16777216),
  "회원번호" VARCHAR(16777216),
  "발송일시" VARCHAR(16777216),
  "발송상태" VARCHAR(16777216),
  "대체발송" VARCHAR(16777216),
  "등록일" VARCHAR(16777216),
  "성공률(%)" VARCHAR(16777216),
  "브랜드" VARCHAR(16777216),
  "상위캠페인" VARCHAR(16777216)
);
-- 회원 개발(모집) 전체 팩트 테이블: 신규 후원 가입 건별 캠페인·부서·금액 상세
create or replace TABLE FACT_MEMBER_DEV_ALL (
  "법인구분" VARCHAR(16777216),
  "후원신청일" NUMBER(38,0),
  "실적부서코드" VARCHAR(16777216),
  "실적부서" VARCHAR(16777216),
  "브랜드ID" NUMBER(38,0),
  "브랜드" VARCHAR(16777216),
  "홍보방법" VARCHAR(16777216),
  "가입경로" VARCHAR(16777216),
  "상위캠페인코드" VARCHAR(16777216),
  "상위캠페인" VARCHAR(16777216),
  "세부캠페인코드" VARCHAR(16777216),
  "세부캠페인" VARCHAR(16777216),
  "후원사업ID" NUMBER(38,0),
  "후원사업" VARCHAR(16777216),
  "개발구분" VARCHAR(16777216),
  "회원번호" VARCHAR(16777216),
  "금액" NUMBER(38,0),
  SPNSR_NO NUMBER(38,0),
  SPNSR_BSNS_NO NUMBER(38,0)
);
-- 회비 납입 이력 팩트 테이블: 회원별 청구월·청구/납입 금액 및 납입 구분
create or replace TABLE FACT_PAYMENT_HISTORY (
  "회원번호" VARCHAR(16777216),
  SPNSR_NO NUMBER(38,0),
  SPNSR_BSNS_NO NUMBER(38,0),
  "회비청구월" NUMBER(38,0),
  "청구금액" NUMBER(38,0),
  "납입금액" NUMBER(38,0),
  "납입일" VARCHAR(16777216),
  "납입구분" VARCHAR(16777216),
  "비고" VARCHAR(16777216)
);
-- 재방송 방송 전환 팩트 테이블: 방송사/방송명별 인입콜·회원개발·편성비 등 성과
create or replace TABLE FACT_RETRANSMIT_BROADCAST_CONV (
  "구분" VARCHAR(16777216),
  "년도" VARCHAR(16777216),
  "방송월" VARCHAR(16777216),
  "방송사" VARCHAR(16777216),
  "방송명" VARCHAR(16777216),
  "상위캠페인명" VARCHAR(16777216),
  "본방송 구분" VARCHAR(16777216),
  "날짜" VARCHAR(16777216),
  "요일" VARCHAR(16777216),
  "방송시간" VARCHAR(16777216),
  "인입콜" FLOAT,
  "회원개발(건)" FLOAT,
  "방송편성비" FLOAT,
  "주차" VARCHAR(16777216),
  "횟수" FLOAT,
  "시간대 구분" VARCHAR(16777216),
  "국내/해외 구분" VARCHAR(16777216),
  "실적부서" VARCHAR(16777216),
  "방송사 유형" VARCHAR(16777216),
  "방송 대분류" VARCHAR(16777216)
);
-- 재방송 월별 개발 목표·실적·예산 및 누계 달성/집행율 팩트 테이블
create or replace TABLE FACT_RETRANSMIT_MONTHLY_DEV (
  "구분" VARCHAR(16777216),
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
  "연도" VARCHAR(16777216),
  "예산절차" VARCHAR(16777216),
  "월 구분" VARCHAR(16777216),
  "방송구분" VARCHAR(16777216),
  "실적부서" VARCHAR(16777216)
);
-- SMS/알림톡 발송 팩트 테이블: 발송 건별 제목·건수·성공률 및 일시후원 여부
create or replace TABLE FACT_SMS_ALIMTALK_SEND (
  "순번" NUMBER(38,0),
  "발송구분(대)" VARCHAR(16777216),
  "발송구분(중)" VARCHAR(16777216),
  "발송구분(소)" VARCHAR(16777216),
  "제목" VARCHAR(16777216),
  "총건수" VARCHAR(16777216),
  "성공건수" VARCHAR(16777216),
  "회원번호" VARCHAR(16777216),
  "발송일시" VARCHAR(16777216),
  "발송상태" VARCHAR(16777216),
  "대체발송" VARCHAR(16777216),
  "등록일" VARCHAR(16777216),
  "성공률(%)" VARCHAR(16777216),
  "일시후원여부" VARCHAR(16777216) DEFAULT 'N'
);
-- 일시 회원 후원(기부) 팩트 테이블: 일시회원별 후원금액·후원일·부서·세부캠페인
create or replace TABLE FACT_TEMP_MEMBER_DONATION (
  "일시회원번호" VARCHAR(16777216),
  "후원금액" NUMBER(38,0),
  "후원일" VARCHAR(16777216),
  "실적부서코드" VARCHAR(16777216),
  "실적부서명" VARCHAR(16777216),
  "세부캠페인코드" NUMBER(38,0),
  "세부캠페인명" VARCHAR(16777216)
);
