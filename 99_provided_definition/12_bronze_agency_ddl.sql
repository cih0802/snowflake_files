-- BRONZE_AGENCY 스키마 3개 광고 성과 테이블의 물리 DDL을 11_crm 스타일로 정리.
-- Co-authored with CoCo
-- =============================================================================
-- BRONZE_AGENCY 물리 DDL (정본 / source of truth for physical types)
-- doc_id: BRONZE_AGENCY_DDL
-- project: GN_DW (굿네이버스)
-- source: SnowSQL `create or replace` 출력
-- scope: BRONZE_AGENCY 스키마 + 3 테이블 (대행사 광고 성과 원천 적재, managed access)
-- note:
--   - 컬럼 한글 설명은 각 컬럼의 COMMENT 참조.
--   - 본 파일은 **물리 데이터타입의 정본**.
--   - 3 테이블: 디지털 / 재송출 / 영상 광고 성과 내역.
-- =============================================================================

create or replace schema GN_DW.BRONZE_AGENCY with managed access
  COMMENT='원천 데이터 적재 - AGENCY (대행사 광고 성과)';

-- -----------------------------------------------------------------------------
-- 1. DGT_AD_CMPGN_DTLS  (디지털 광고 성과 내역)
-- -----------------------------------------------------------------------------
create or replace TABLE GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS (
  TIME                 VARCHAR(16777216) COMMENT '시간',
  YEAR                 VARCHAR(16777216) COMMENT '연도',
  CPR_NM               VARCHAR(16777216) COMMENT '법인',
  DMST_OVSEA_DIV_NM    VARCHAR(16777216) COMMENT '국내해외구분',
  BSNS_CASE_DIV_NM     VARCHAR(16777216) COMMENT '사업사례구분',
  CMPGN_TY_NM          VARCHAR(16777216) COMMENT '캠페인유형',
  AD_TY_NM             VARCHAR(16777216) COMMENT '광고유형',
  MONTH                VARCHAR(16777216) COMMENT '월',
  DEVICE               VARCHAR(16777216) COMMENT '기기',
  MEDIA_NM             VARCHAR(16777216) COMMENT '매체',
  WEEK                 VARCHAR(16777216) COMMENT '주차',
  DAY                  VARCHAR(16777216) COMMENT '일자',
  DOW                  VARCHAR(16777216) COMMENT '요일',
  CMPGN_NM             VARCHAR(16777216) COMMENT '캠페인명',
  MATR                 VARCHAR(16777216) COMMENT '소재',
  MATR_TY_NM           VARCHAR(16777216) COMMENT '소재유형',
  EXPS_CNT             FLOAT             COMMENT '노출수',
  CLICK_CNT            FLOAT             COMMENT '클릭수',
  GA_AD_COST           FLOAT             COMMENT '광고비',
  GA_CONV_MBER_CNT     FLOAT             COMMENT '후원자수(명)',
  CONV_VU_CNT          FLOAT             COMMENT '전환가치(건)',
  CPA                  FLOAT             COMMENT 'CPA',
  DEV_UNIT_PRICE       FLOAT             COMMENT '개발단가',
  CTR                  FLOAT             COMMENT 'CTR',
  CVR                  FLOAT             COMMENT 'CVR',
  CPC                  FLOAT             COMMENT 'CPC',
  CPM                  FLOAT             COMMENT 'CPM',
  UPPER_CMPGN_NM       VARCHAR(16777216) COMMENT '상위캠페인',
  READ_CNT             FLOAT             COMMENT '조회수',
  MEDIA_PTNT_CUST_CNT  FLOAT             COMMENT '잠재고객수(매체)',
  DATE                 DATE              COMMENT '날짜',
  VTR                  FLOAT             COMMENT 'VTR',
  PAGE_TYPE_NM         VARCHAR(16777216) COMMENT '지면구분',
  CRM_DVLP_CNT         FLOAT             COMMENT 'CRM개발건수',
  AD_GRP_NM            VARCHAR(16777216) COMMENT '광고그룹',
  GRP_DIV_NM           VARCHAR(16777216) COMMENT '그룹구분'
) COMMENT='디지털 광고 성과 내역'
;

-- -----------------------------------------------------------------------------
-- 2. REBRDC_AD_CMPGN_DTLS  (재송출 광고 성과 내역)
-- -----------------------------------------------------------------------------
create or replace TABLE GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS (
  RE_BRDC_TY_NM          VARCHAR(16777216) COMMENT '재송출유형',
  DIV_NM                 VARCHAR(16777216) COMMENT '구분',
  YEAR                   VARCHAR(16777216) COMMENT '년도',
  BRDC_MT                VARCHAR(16777216) COMMENT '방송월',
  CHNNL_CMPNY            VARCHAR(16777216) COMMENT '채널사',
  BRDC_NM                VARCHAR(16777216) COMMENT '방송명',
  BRDC_DIV_NM            VARCHAR(16777216) COMMENT '본방송구분',
  DATE                   DATE              COMMENT '날짜',
  DOW                    VARCHAR(16777216) COMMENT '요일',
  BRDC_TIME              VARCHAR(16777216) COMMENT '방송시간',
  INBOUND_CALL_CNT       VARCHAR(16777216) COMMENT '인입콜',
  DVLP_MBER_CNT          FLOAT             COMMENT '회원개발(명)',
  DVLP_CNT               FLOAT             COMMENT '회원개발(건)',
  BRDC_SCHDL_COST        FLOAT             COMMENT '방송편성비',
  WEEK                   VARCHAR(16777216) COMMENT '주차',
  AD_CNT                 FLOAT             COMMENT '횟수',
  TIME_RNG_DIV_NM        VARCHAR(16777216) COMMENT '시간대구분',
  CELEB_NM               VARCHAR(16777216) COMMENT '셀럽',
  DMST_OVSEA_DIV_NM      VARCHAR(16777216) COMMENT '국내/해외구분',
  CASE1_BSNS_DIV_NM      VARCHAR(16777216) COMMENT '사업구분1',
  CASE1_FAM_TY_NM        VARCHAR(16777216) COMMENT '가정유형1',
  CASE1_APPEAL_POINT_NM  VARCHAR(16777216) COMMENT '소구포인트1',
  CASE1_CHILD_NM         VARCHAR(16777216) COMMENT '아동명1',
  CASE1_CASE_DIV_NM      VARCHAR(16777216) COMMENT '사례구분1',
  CASE2_BSNS_DIV_NM      VARCHAR(16777216) COMMENT '사업구분2',
  CASE2_FAM_TY_NM        VARCHAR(16777216) COMMENT '가정유형2',
  CASE2_APPEAL_POINT_NM  VARCHAR(16777216) COMMENT '소구포인트2',
  CASE2_CHILD_NM         VARCHAR(16777216) COMMENT '아동명2',
  CASE2_CASE_DIV_NM      VARCHAR(16777216) COMMENT '사례구분2',
  CASE3_BSNS_DIV_NM      VARCHAR(16777216) COMMENT '사업구분3',
  CASE3_FAM_TY_NM        VARCHAR(16777216) COMMENT '가정유형3',
  CASE3_APPEAL_POINT_NM  VARCHAR(16777216) COMMENT '소구포인트3',
  CASE3_CHILD_NM         VARCHAR(16777216) COMMENT '아동명3',
  CASE3_CASE_DIV_NM      VARCHAR(16777216) COMMENT '사례구분3'
) COMMENT='재송출 광고 성과 내역'
;

-- -----------------------------------------------------------------------------
-- 3. VIDEO_AD_CMPGN_DTLS  (영상 광고 성과 내역)
-- -----------------------------------------------------------------------------
create or replace TABLE GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS (
  CHNNL_NM               VARCHAR(16777216) COMMENT '채널',
  DOW                    VARCHAR(16777216) COMMENT '요일',
  BRDC_DATE              DATE              COMMENT '방송일자',
  TIME_RNG               VARCHAR(16777216) COMMENT '시간대',
  DAY_DIV_NM             VARCHAR(16777216) COMMENT '주중/토/일',
  PRG_STRT_TIME          VARCHAR(16777216) COMMENT '프로그램시작시간',
  SCHDL_NM               VARCHAR(16777216) COMMENT '편성명',
  CM                     VARCHAR(16777216) COMMENT 'CM',
  CM_AREA                VARCHAR(16777216) COMMENT 'CM위치',
  AD_STRT_TIME           VARCHAR(16777216) COMMENT '광고시작시간',
  AD_END_TIME            VARCHAR(16777216) COMMENT '광고종료시간',
  SPOT_TY                VARCHAR(16777216) COMMENT 'SpotType',
  AD_VIEW_RT             FLOAT             COMMENT '광고시청률',
  AD_CNT                 NUMBER(38,0)      COMMENT '횟수',
  AD_SEC                 VARCHAR(16777216) COMMENT '초수',
  ACTL_PUR_AD_COST_KRW   NUMBER(38,0)      COMMENT '실구매광고비(원)',
  INBOUND_CALL_CNT       NUMBER(38,0)      COMMENT '인입콜',
  CPC                    VARCHAR(16777216) COMMENT 'CPC',
  UPPER_CMPGN_NM         VARCHAR(16777216) COMMENT '상위캠페인',
  MATR_NM                VARCHAR(16777216) COMMENT '소재명',
  CMPGN_TY_NM            VARCHAR(16777216) COMMENT '캠페인유형',
  DUR_PD_MATR_CHN        VARCHAR(16777216) COMMENT '중도소재변경',
  CHNNL_CMPNY_TY_NM      VARCHAR(16777216) COMMENT '채널사유형',
  WEEK                   VARCHAR(16777216) COMMENT '주차',
  CONV_CALL_CNT          FLOAT             COMMENT '전환콜',
  BRDC_MT                VARCHAR(16777216) COMMENT '방송월',
  YEAR                   VARCHAR(16777216) COMMENT '해당연도',
  CTV_DIV_NM             VARCHAR(16777216) COMMENT 'CTV 구분',
  MKT_CMPGN_NM           VARCHAR(16777216) COMMENT '마케팅 캠페인명',
  SPNSR_BSNS_NM          VARCHAR(16777216) COMMENT '후원사업구분',
  DMST_OVSEA_DIV_NM      VARCHAR(16777216) COMMENT '캠페인유형(국내/해외)',
  BSNS_CASE_DIV_NM       VARCHAR(16777216) COMMENT '캠페인유형(사업/사례)'
) COMMENT='영상 광고 성과 내역'
;
