-- GN_DW_AGENT PoC: RAW 테이블·Semantic View·Cortex Agent 생성/정리 스크립트 (방송 매체효율 분석 보강)

--------------------------------------------------------------
-- 기초환경구성: Agent가 참조하는 오브젝트를 실제 DDL 기반으로 생성
-- 순서: DB/Schema/WH → RAW 테이블 → ANALYTICS 뷰 → Semantic View → Agent
--------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS GN_DW_POC;
CREATE SCHEMA IF NOT EXISTS GN_DW_POC.RAW;
CREATE SCHEMA IF NOT EXISTS GN_DW_POC.ANALYTICS;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

--------------------------------------------------------------
-- RAW 스키마: Agent의 Semantic View가 최종적으로 참조하는 원본 테이블
--------------------------------------------------------------

create or replace TABLE GN_DW_POC.RAW.DIM_CAMPAIGN_CODE (
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

create or replace TABLE GN_DW_POC.RAW.DIM_MEMBER_ATTRIBUTE (
	"회원번호" VARCHAR(16777216),
	"성별" VARCHAR(16777216),
	"연령대" VARCHAR(16777216),
	"지역" VARCHAR(16777216)
);

create or replace TABLE GN_DW_POC.RAW.DIM_ORG_CODE (
	"부서코드" VARCHAR(16777216),
	"부서명" VARCHAR(16777216),
	"부서경로" VARCHAR(16777216),
	"상위부서코드" VARCHAR(16777216)
);

create or replace TABLE GN_DW_POC.RAW.DIM_TEMP_TO_REGULAR_MATCH (
	"회원번호(정기)" VARCHAR(16777216),
	"회원번호(일시)" VARCHAR(16777216),
	"전환일" VARCHAR(16777216)
);

create or replace TABLE GN_DW_POC.RAW.FACT_MEMBER_DEV_ALL (
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

create or replace TABLE GN_DW_POC.RAW.FACT_PAYMENT_HISTORY (
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

create or replace TABLE GN_DW_POC.RAW.FACT_DISCONTINUED_MEMBER (
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

create or replace TABLE GN_DW_POC.RAW.FACT_SMS_ALIMTALK_SEND (
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

create or replace TABLE GN_DW_POC.RAW.FACT_MARKETING_SEND_NEW (
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

create or replace TABLE GN_DW_POC.RAW.FACT_DRTV_BROADCAST_EFF (
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

create or replace TABLE GN_DW_POC.RAW.FACT_DRTV_MONTHLY_DEV (
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

create or replace TABLE GN_DW_POC.RAW.FACT_DIGITAL_AD_DETAIL (
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

create or replace TABLE GN_DW_POC.RAW.FACT_DIGITAL_MONTHLY_DEV (
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

create or replace TABLE GN_DW_POC.RAW.FACT_AD_GA_AUDIENCE (
	"날짜" NUMBER(38,0),
	"잠재고객이름" VARCHAR(16777216),
	"세션캠페인" VARCHAR(16777216),
	"회원번호" VARCHAR(16777216),
	"세션수" NUMBER(38,0),
	"활성사용자" NUMBER(38,0)
);

create or replace TABLE GN_DW_POC.RAW.FACT_AD_GOOGLE_DEMANDGEN (
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

create or replace TABLE GN_DW_POC.RAW.FACT_AD_GOOGLE_PMAX (
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

create or replace TABLE GN_DW_POC.RAW.FACT_AD_META (
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

create or replace TABLE GN_DW_POC.RAW.FACT_RETRANSMIT_BROADCAST_CONV (
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

create or replace TABLE GN_DW_POC.RAW.FACT_RETRANSMIT_MONTHLY_DEV (
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

create or replace TABLE GN_DW_POC.RAW.FACT_GA_VISITS_APP (
	"페이지경로" VARCHAR(16777216),
	"이벤트이름" VARCHAR(16777216),
	"회원ID" VARCHAR(16777216),
	"세션수" VARCHAR(16777216),
	"페이지뷰" VARCHAR(16777216),
	"활성사용자수" VARCHAR(16777216),
	"방문수" VARCHAR(16777216),
	"이벤트수" VARCHAR(16777216)
);

create or replace TABLE GN_DW_POC.RAW.FACT_GA_VISITS_MOBILE (
	"페이지경로" VARCHAR(16777216),
	"이벤트이름" VARCHAR(16777216),
	"회원ID" VARCHAR(16777216),
	"세션수" VARCHAR(16777216),
	"페이지뷰" VARCHAR(16777216),
	"활성사용자수" VARCHAR(16777216),
	"방문수" VARCHAR(16777216),
	"이벤트수" VARCHAR(16777216)
);

create or replace TABLE GN_DW_POC.RAW.FACT_GA_VISITS_PC (
	"페이지경로" VARCHAR(16777216),
	"회원ID" VARCHAR(16777216),
	"세션수" VARCHAR(16777216),
	"페이지뷰" VARCHAR(16777216),
	"활성사용자수" VARCHAR(16777216),
	"방문수" VARCHAR(16777216),
	"이벤트수" VARCHAR(16777216)
);

create or replace TABLE GN_DW_POC.RAW.FACT_GA_VISITS_TOTAL (
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

create or replace TABLE GN_DW_POC.RAW.FACT_GA_FEEDBACK_PAGE (
	"페이지경로쿼리" VARCHAR(16777216),
	"세션수" VARCHAR(16777216),
	"페이지뷰" VARCHAR(16777216),
	"이벤트수" VARCHAR(16777216),
	"이탈률" VARCHAR(16777216),
	"참여율" VARCHAR(16777216),
	"평균세션시간" VARCHAR(16777216)
);

create or replace TABLE GN_DW_POC.RAW.FACT_TEMP_MEMBER_DONATION (
	"일시회원번호" VARCHAR(16777216),
	"후원금액" NUMBER(38,0),
	"후원일" VARCHAR(16777216),
	"실적부서코드" VARCHAR(16777216),
	"실적부서명" VARCHAR(16777216),
	"세부캠페인코드" NUMBER(38,0),
	"세부캠페인명" VARCHAR(16777216)
);

--------------------------------------------------------------
-- ANALYTICS 스키마: Agent의 Semantic View가 참조하는 뷰
-- ※ ANALYTICS_DDL.sql 파일을 먼저 실행하세요 (V_* 뷰 생성)
--------------------------------------------------------------

-- [실행 순서 2] ANALYTICS_DDL.sql 전체 실행

--------------------------------------------------------------
-- Semantic View 생성 (semantic_ddl.sql에서 추출한 실제 DDL)
--------------------------------------------------------------

-- [실행 순서 3] semantic_ddl.sql 전체 실행

--------------------------------------------------------------
-- [실행 순서 3-1] 추가 Semantic View: 방송 광고매체 효율 (DRTV/재송출)
-- ※ semantic_ddl.sql의 7개 SV에 없던 '광고매체 효율' 영역을 보강.
--   1번 문서가 생성하는 RAW 방송 팩트를 직접 참조 (SV_AD_PLATFORM과 동일 패턴).
--------------------------------------------------------------

create or replace semantic view GN_DW_POC.ANALYTICS.SV_MEDIA_EFFICIENCY
  tables (
    DRTV_EFF as GN_DW_POC.RAW.FACT_DRTV_BROADCAST_EFF comment='DRTV 방송 편성/광고 효율(채널사별 시청률·광고비·인입콜·CPC).',
    DRTV_DEV as GN_DW_POC.RAW.FACT_DRTV_MONTHLY_DEV comment='DRTV 월별 개발 목표/실적/예산(예산절차별).',
    RETRANS_CONV as GN_DW_POC.RAW.FACT_RETRANSMIT_BROADCAST_CONV comment='재송출 방송 전환(방송사별 인입콜·회원개발·편성비).',
    RETRANS_DEV as GN_DW_POC.RAW.FACT_RETRANSMIT_MONTHLY_DEV comment='재송출 월별 개발 목표/실적/예산(예산절차별).'
  )
  facts (
    DRTV_EFF.AD_COST as TRY_TO_NUMBER(REPLACE("실구매광고비(원)", ',', '')) with synonyms=('실구매광고비','광고비') comment='DRTV 실구매광고비(원).',
    DRTV_EFF.INBOUND_CALL as TRY_TO_NUMBER(REPLACE("인입콜", ',', '')) with synonyms=('인입콜') comment='DRTV 인입콜수.',
    DRTV_EFF.CPC_VAL as TRY_TO_NUMBER(REPLACE(CPC, ',', '')) with synonyms=('CPC','콜당비용') comment='DRTV CPC(콜당 광고비).',
    DRTV_EFF.VIEW_RATE as TRY_TO_DOUBLE(REPLACE("광고시청률", '%', '')) with synonyms=('광고시청률','시청률') comment='DRTV 광고시청률.',
    DRTV_DEV.DRTV_TARGET as "월별 목표" with synonyms=('월별목표','목표') comment='DRTV 월별 개발목표(건).',
    DRTV_DEV.DRTV_ACTUAL as "월별 실적" with synonyms=('월별실적','실적') comment='DRTV 월별 개발실적(건).',
    DRTV_DEV.DRTV_BUDGET as "집행 예산" with synonyms=('집행예산') comment='DRTV 월별 집행예산(원).',
    RETRANS_CONV.RT_INBOUND as "인입콜" with synonyms=('인입콜') comment='재송출 인입콜수.',
    RETRANS_CONV.RT_DEV as "회원개발(건)" with synonyms=('회원개발','개발건') comment='재송출 회원개발(건).',
    RETRANS_CONV.RT_COST as "방송편성비" with synonyms=('방송편성비','편성비') comment='재송출 방송편성비(원).',
    RETRANS_DEV.RT_TARGET as "월별 목표" with synonyms=('월별목표') comment='재송출 월별 개발목표(건).',
    RETRANS_DEV.RT_ACTUAL as "월별 실적" with synonyms=('월별실적') comment='재송출 월별 개발실적(건).',
    RETRANS_DEV.RT_BUDGET as "집행 예산" with synonyms=('집행예산') comment='재송출 월별 집행예산(원).'
  )
  dimensions (
    DRTV_EFF.CHANNEL as "채널" with synonyms=('채널','채널사','채널명') comment='DRTV 채널명.',
    DRTV_EFF.CHANNEL_TYPE as "채널사 유형" with synonyms=('채널사유형') comment='DRTV 채널사 유형.',
    DRTV_EFF.BROADCAST_MONTH as "방송월" with synonyms=('방송월') comment='DRTV 방송월.',
    DRTV_EFF.YEAR as "해당연도" with synonyms=('연도','해당연도') comment='DRTV 해당연도.',
    DRTV_EFF.CAMPAIGN as "CRM(세부캠페인)명칭" with synonyms=('세부캠페인','캠페인명') comment='DRTV 연결 세부캠페인명.',
    DRTV_DEV.DRTV_DIV as "구분" with synonyms=('구분') comment='DRTV 월별개발 구분.',
    DRTV_DEV.DRTV_BUDGET_PROCESS as "예산절차" with synonyms=('예산절차') comment='DRTV 예산절차(예산절차별 조회 시 필수).',
    DRTV_DEV.DRTV_YEAR as "해당연도" with synonyms=('연도') comment='DRTV 월별개발 해당연도.',
    DRTV_DEV.DRTV_MONTH as "월 구분" with synonyms=('월구분','월') comment='DRTV 월 구분.',
    RETRANS_CONV.BROADCASTER as "방송사" with synonyms=('방송사','채널사') comment='재송출 방송사.',
    RETRANS_CONV.BROADCASTER_TYPE as "방송사 유형" with synonyms=('방송사유형') comment='재송출 방송사 유형.',
    RETRANS_CONV.RT_PARENT_CAMPAIGN as "상위캠페인명" with synonyms=('상위캠페인') comment='재송출 상위캠페인명.',
    RETRANS_CONV.RT_YEAR as "년도" with synonyms=('연도','년도') comment='재송출 년도.',
    RETRANS_CONV.RT_MONTH as "방송월" with synonyms=('방송월') comment='재송출 방송월.',
    RETRANS_CONV.RT_DOMESTIC as "국내/해외 구분" with synonyms=('국내해외구분','국내해외') comment='재송출 국내/해외 구분.',
    RETRANS_DEV.RT_DEV_DIV as "구분" with synonyms=('구분') comment='재송출 월별개발 구분.',
    RETRANS_DEV.RT_DEV_BUDGET_PROCESS as "예산절차" with synonyms=('예산절차') comment='재송출 예산절차.',
    RETRANS_DEV.RT_BROADCAST_DIV as "방송구분" with synonyms=('방송구분') comment='재송출 방송구분.',
    RETRANS_DEV.RT_DEV_YEAR as "연도" with synonyms=('연도') comment='재송출 월별개발 연도.'
  )
  metrics (
    DRTV_EFF.TOTAL_AD_COST as SUM(TRY_TO_NUMBER(REPLACE("실구매광고비(원)", ',', ''))) with synonyms=('총광고비') comment='DRTV 총 광고비(원).',
    DRTV_EFF.TOTAL_INBOUND as SUM(TRY_TO_NUMBER(REPLACE("인입콜", ',', ''))) with synonyms=('총인입콜') comment='DRTV 총 인입콜수.',
    DRTV_EFF.AVG_CPC as AVG(TRY_TO_NUMBER(REPLACE(CPC, ',', ''))) with synonyms=('평균CPC') comment='DRTV 평균 CPC(콜당비용).',
    DRTV_EFF.AVG_VIEW_RATE as AVG(TRY_TO_DOUBLE(REPLACE("광고시청률", '%', ''))) with synonyms=('평균시청률') comment='DRTV 평균 광고시청률.',
    DRTV_EFF.CHANNEL_ROI as SUM(TRY_TO_NUMBER(REPLACE("인입콜", ',', ''))) / NULLIF(SUM(TRY_TO_NUMBER(REPLACE("실구매광고비(원)", ',', ''))), 0) with synonyms=('채널ROI','광고비대비인입콜') comment='DRTV 광고비 대비 인입콜 효율(인입콜/광고비).',
    DRTV_DEV.DRTV_SUM_TARGET as SUM("월별 목표") with synonyms=('DRTV총목표') comment='DRTV 총 개발목표(건).',
    DRTV_DEV.DRTV_SUM_ACTUAL as SUM("월별 실적") with synonyms=('DRTV총실적') comment='DRTV 총 개발실적(건).',
    DRTV_DEV.DRTV_SUM_BUDGET as SUM("집행 예산") with synonyms=('DRTV총집행예산') comment='DRTV 총 집행예산(원).',
    RETRANS_CONV.RT_TOTAL_INBOUND as SUM("인입콜") with synonyms=('재송출총인입콜') comment='재송출 총 인입콜수.',
    RETRANS_CONV.RT_TOTAL_DEV as SUM("회원개발(건)") with synonyms=('재송출총개발') comment='재송출 총 회원개발(건).',
    RETRANS_CONV.RT_TOTAL_COST as SUM("방송편성비") with synonyms=('재송출총편성비') comment='재송출 총 방송편성비(원).',
    RETRANS_DEV.RT_SUM_TARGET as SUM("월별 목표") with synonyms=('재송출총목표') comment='재송출 총 개발목표(건).',
    RETRANS_DEV.RT_SUM_ACTUAL as SUM("월별 실적") with synonyms=('재송출총실적') comment='재송출 총 개발실적(건).'
  )
  comment='광고매체(방송) 효율 분석: DRTV/재송출 채널사별 광고비·인입콜·시청률·CPC·ROI 및 월별 개발 목표대비실적/예산집행(예산절차별).'
  ai_sql_generation '숫자는 소수점 1자리 ROUND. 한글 컬럼명은 쌍따옴표. DRTV 방송효율 테이블의 광고비/인입콜/CPC/시청률은 VARCHAR이므로 TRY_TO_NUMBER/TRY_TO_DOUBLE로 변환 후 집계. 예산절차별 조회 시 "예산절차" 컬럼 필터.'
  ai_question_categorization '방송 매체(DRTV/재송출) 채널사별 광고비, 인입콜, 시청률, CPC, ROI, 월별 목표대비실적, 예산집행 분석에 답변.';

--------------------------------------------------------------
-- Agent 생성: 8개 Semantic View를 tool_resources로 연결한 Cortex Agent
--------------------------------------------------------------

CREATE AGENT GN_DW_POC.ANALYTICS.GN_DW_AGENT
  COMMENT = '굿네이버스 데이터 분석 에이전트. 회원개발/납입이력/중단회원/일시→정기전환/마케팅발송/광고플랫폼/방송매체효율 분석.'
  FROM SPECIFICATION $$
{
  "models": {"orchestration": "auto"},
  "orchestration": {"budget": {"seconds": 60, "tokens": 32000}},
  "instructions": {
    "response": "답변은 간결하고 정확하게. 표 형식 제공. 데이터 기반 인사이트 포함.",
    "orchestration": "질문 라우팅 규칙:\n- 납입회비, 미납, 청구금액 → payment_analyst\n- 중단회원, 유지기간, 일시→정기 전환 → lifecycle_analyst\n- 회원개발, 캠페인별 개발건수, ROI, 유지율 → member_dev_analyst\n- 알림톡, 문자발송, 발송전환 → messaging_analyst\n- 디지털광고(구글/메타/GA), 디지털 CTR/CPC → ad_platform_analyst\n- 방송매체(DRTV/재송출) 채널사별 광고비/인입콜/시청률/CPC/ROI, 월별 목표대비실적·예산집행(예산절차별) → media_efficiency_analyst\n- 웹/앱 방문 → web_app_analyst\n",
    "sample_questions": [
      {"question": "2025년 납입회비가 가장 높았던 캠페인은?"},
      {"question": "2025년 중단회원 중 고려인 캠페인 가입 회원의 유지기간은?"},
      {"question": "2025년 미납비중이 높은 세부캠페인 TOP3와 회원특성은?"},
      {"question": "일시회원이 정기회원으로 전환된 비중이 가장 높은 캠페인은?"},
      {"question": "2025년 알림톡 수신 회원의 연간 발송횟수, 증액건, 중단건은?"},
      {"question": "2025년 매체별 광고 효율(CTR, CPC)은?"},
      {"question": "2025년 DRTV 채널사별 광고비 대비 인입콜 효율(CPC)은?"},
      {"question": "방송매체(DRTV/재송출) 월별 개발 목표대비실적을 예산절차별로 비교해줘"}
    ]
  },
  "tools": [
    {"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "payment_analyst", "description": "납입이력 분석. 캠페인별 납입금액/미납비중/평균회비. 납입구분이 미납인 건만 미납금액 산출."}},
    {"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "lifecycle_analyst", "description": "회원 라이프사이클. 중단회원 유지기간/캠페인별/사유별. 일시→정기 전환."}},
    {"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "member_dev_analyst", "description": "회원개발 종합. 캠페인별 개발건수/실적/유지율. 유지율은 가입연도 필터 필수."}},
    {"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "messaging_analyst", "description": "마케팅발송. 알림톡=제목에 알림톡 포함건. 알림톡/문자/발송전환."}},
    {"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "ad_platform_analyst", "description": "디지털 광고 플랫폼. 매체별 효율(CTR/CPC), GA, 메타."}},
    {"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "media_efficiency_analyst", "description": "방송 광고매체 효율. DRTV/재송출 채널사별 광고비·인입콜·시청률·CPC·ROI, 월별 개발 목표대비실적 및 예산집행(예산절차별)."}},
    {"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "web_app_analyst", "description": "웹/앱 방문 분석."}},
    {"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "MEMBER_JOURNEY", "description": "회원별 후원 전후 통합 여정. 가입/매체/발송/증액/중단 연결."}},
    {"tool_spec": {"type": "data_to_chart", "name": "data_to_chart"}}
  ],
  "tool_resources": {
    "payment_analyst": {"semantic_view": "GN_DW_POC.ANALYTICS.SV_PAYMENT_ANALYSIS"},
    "lifecycle_analyst": {"semantic_view": "GN_DW_POC.ANALYTICS.SV_MEMBER_LIFECYCLE"},
    "member_dev_analyst": {"semantic_view": "GN_DW_POC.ANALYTICS.SV_MEMBER_DEVELOPMENT"},
    "messaging_analyst": {"semantic_view": "GN_DW_POC.ANALYTICS.SV_MARKETING_MESSAGING"},
    "ad_platform_analyst": {"semantic_view": "GN_DW_POC.ANALYTICS.SV_AD_PLATFORM"},
    "web_app_analyst": {"semantic_view": "GN_DW_POC.ANALYTICS.SV_WEB_APP_ANALYTICS"},
    "MEMBER_JOURNEY": {"execution_environment": {"type": "warehouse", "warehouse": ""}, "semantic_view": "GN_DW_POC.ANALYTICS.SV_MEMBER_JOURNEY"}
  }
}
$$;

--------------------------------------------------------------
-- 오브젝트 삭제: 위에서 생성한 모든 오브젝트를 의존성 역순으로 제거
--------------------------------------------------------------

DROP AGENT IF EXISTS GN_DW_POC.ANALYTICS.GN_DW_AGENT;

DROP SEMANTIC VIEW IF EXISTS GN_DW_POC.ANALYTICS.SV_PAYMENT_ANALYSIS;
DROP SEMANTIC VIEW IF EXISTS GN_DW_POC.ANALYTICS.SV_MEMBER_LIFECYCLE;
DROP SEMANTIC VIEW IF EXISTS GN_DW_POC.ANALYTICS.SV_MEMBER_DEVELOPMENT;
DROP SEMANTIC VIEW IF EXISTS GN_DW_POC.ANALYTICS.SV_MARKETING_MESSAGING;
DROP SEMANTIC VIEW IF EXISTS GN_DW_POC.ANALYTICS.SV_AD_PLATFORM;
DROP SEMANTIC VIEW IF EXISTS GN_DW_POC.ANALYTICS.SV_MEDIA_EFFICIENCY;
DROP SEMANTIC VIEW IF EXISTS GN_DW_POC.ANALYTICS.SV_WEB_APP_ANALYTICS;
DROP SEMANTIC VIEW IF EXISTS GN_DW_POC.ANALYTICS.SV_MEMBER_JOURNEY;

DROP SCHEMA IF EXISTS GN_DW_POC.ANALYTICS CASCADE;
DROP SCHEMA IF EXISTS GN_DW_POC.RAW CASCADE;
DROP DATABASE IF EXISTS GN_DW_POC;
DROP WAREHOUSE IF EXISTS COMPUTE_WH;
