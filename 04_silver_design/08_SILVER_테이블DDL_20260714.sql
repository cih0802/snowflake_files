-- GN_DW SILVER 테이블 정의 DDL (STEP 1 스키마 + STEP 2 SILVER 32테이블 CREATE TABLE). 적재/ALTER 쿼리는 09_SILVER_적재쿼리_20260714.sql 참조.
-- Co-authored with CoCo
/*
================================================================================
  GN_DW.SILVER — 32테이블 정의 DDL (테이블 구조 정본)
    구성: CRM 21 + ERP 3 + AGENCY 2 + GA4 5 + bridge(IDENTITY_MEMBER_XREF) 1 = 32.
          dbt SILVER 모델 32개와 1:1 대응(구조 소유주 = 이 파일, dbt 는 데이터만 갱신).
  ★ 구 silver_stepbystep_ddl.sql 을 08(구조 DDL) + 09(적재 쿼리)로 분할 — 2026-07-14.
      - 08 (이 파일): STEP 1 스키마 생성 + STEP 2 CREATE OR REPLACE TABLE x32 (멱등).
      - 09          : STEP 3 BRONZE→SILVER 정제 INSERT OVERWRITE + 발송키 PK ALTER.
  실행 순서 : 08 먼저(테이블 생성) → 09(적재). 08 은 CREATE OR REPLACE 로 안전 재실행.
  근거      : 03_SILVER_작업계획_CRM전용 · 02_SILVER_작업계획_BRONZE-GOLD연결 · 03_top-down_gold/08_silver의존.md
  S-5 반영  : [G1] CRM_MEMBER_DEV·CRM_MEMBER_AMT_CHANGE = AREA_CD·AREA_NM(CM018)·AGE
              [G2] CRM_SEND_REQUEST = SEND_GBN_TOP/MID/BOT(+_NM) 3계층 (SND 채널 한정)
  주의      : 발송 2테이블(CRM_SEND_REQUEST·CRM_SEND_MEMBER)의 복합 PK 전환은
              09 상단 ALTER 로 수행(멱등 로드 흐름 유지) — 본 파일 CREATE 는 단일 PK.
================================================================================
*/
-- ============================================================================
-- STEP 1 — 스키마 생성
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS GN_DW.SILVER
  COMMENT = 'Silver 레이어 — Bronze(CRM·GA4·ERP·AGENCY) 정제 객체 (GOLD 입력용)';

USE SCHEMA GN_DW.SILVER;

-- ============================================================================
-- STEP 2 — SILVER 32테이블 DDL (CRM21·ERP3·AGENCY2·GA4 5·bridge1, 빈 테이블 생성, 정제 INSERT 는 STEP 3)
-- ============================================================================

-- CRM 1: CRM_MEMBER (회원 통합 — 정기 ∪ 일시)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER (
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키 (PK, 조인용)',
    MEMBER_TYPE         VARCHAR(10)     COMMENT '회원구분 파생 (정기=FDRM / 일시=ONCE)',
    MBER_DIV_CD         VARCHAR(3)      COMMENT '회원구분코드 (MM018: 개인/기업/단체)',
    MBER_DIV_NM         VARCHAR         COMMENT '회원구분명 (코드 라벨)',
    CPR_DIV_CD          VARCHAR(3)      COMMENT '법인구분코드',
    SEX                 VARCHAR(2)      COMMENT '성별',
    MBER_STAT_CD        VARCHAR(3)      COMMENT '회원상태코드',
    MBER_STAT_NM        VARCHAR         COMMENT '회원상태명 (코드 라벨)',
    CMPGN_CD            VARCHAR(20)     COMMENT '가입 캠페인코드 (→CRM_CAMPAIGN)',
    ACT_DEPT_CD         VARCHAR(10)     COMMENT '활동부서코드 (→CRM_ORG)',
    REGIST_DEPT_CD      VARCHAR(10)     COMMENT '등록부서코드 (→CRM_ORG)',
    JOIN_PATH_CD        VARCHAR(3)      COMMENT '가입경로코드 (MM014)',
    HMPG_ID             VARCHAR(30)     COMMENT '홈페이지/앱 ID',
    ENTRPS_NM           VARCHAR(200)    COMMENT '기업/단체명 (법인회원)',
    EMAIL_RECPTN        VARCHAR         COMMENT '이메일 수신동의 여부',
    PSTMTR_RECPTN       VARCHAR         COMMENT '우편물 수신동의 여부',
    JOIN_DT             TIMESTAMP_NTZ   COMMENT '가입일시',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (MEMBER_DK)
) COMMENT = '회원 통합(정기∪일시). Q6 UNION 스키마 정렬 잠정';

-- CRM 2: CRM_MEMBER_STATUS_HIST (회원 상태전이 · SCD2)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_STATUS_HIST (
    MBER_NO             VARCHAR(10)     NOT NULL COMMENT '회원번호 (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '상태전이 일련번호 (PK)',
    BF_STAT_CD          VARCHAR(3)      COMMENT '변경 전 상태코드',
    BF_STAT_NM          VARCHAR         COMMENT '변경 전 상태명 (코드 라벨)',
    CHN_STAT_CD         VARCHAR(3)      COMMENT '변경 후 상태코드',
    CHN_STAT_NM         VARCHAR         COMMENT '변경 후 상태명 (코드 라벨)',
    EFFECTIVE_FROM      TIMESTAMP_NTZ   COMMENT 'SCD2 유효시작 시각',
    EFFECTIVE_TO        TIMESTAMP_NTZ   COMMENT 'SCD2 유효종료 시각',
    IS_CURRENT          BOOLEAN         COMMENT '현재행 여부',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (MBER_NO, SER_NO)
) COMMENT = '회원 상태전이 이력 (SCD2 range)';

-- CRM 3: CRM_MEMBER_DEV (개발약정)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_DEV (
    SPNSR_NO            VARCHAR(9)      NOT NULL COMMENT '후원번호 (PK)',
    SPNSR_BSNS_NO       NUMBER(19,0)    NOT NULL COMMENT '후원사업번호 (PK)',
    OCCRRNC_DE          VARCHAR(8)      NOT NULL COMMENT '발생일자 YYYYMMDD (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '일련번호 (PK)',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    SPNSR_BSNS_ID       VARCHAR(20)     COMMENT '후원사업ID (→CRM_SPONSORSHIP)',
    SPNSR_AMT           NUMBER(19,0)    COMMENT '약정 후원금액 (원단위)',
    DVLP_DIV_CD         VARCHAR(3)      COMMENT '개발구분코드',
    ACT_DEPT_CD         VARCHAR(10)     COMMENT '활동부서코드 (→CRM_ORG)',
    ACMSLT_DEPT_CD      VARCHAR(10)     COMMENT '실적부서코드 (→CRM_ORG)',
    CMPGN_CD            VARCHAR(20)     COMMENT '캠페인코드 (→CRM_CAMPAIGN)',
    SETLE_CD            VARCHAR(3)      COMMENT '결제수단코드',
    AREA_CD             VARCHAR(3)      COMMENT '지역코드 (CM018) — [S-5 G1] DIM_MEMBER REGION 스냅샷 소스',
    AREA_NM             VARCHAR         COMMENT '지역명 (코드 라벨)',
    AGE                 NUMBER(10,0)    COMMENT '연령 — [S-5 G1] DIM_MEMBER AGE_BAND 스냅샷 소스',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO)
) COMMENT = '개발약정 (Q13 스파인 — N:1 LEFT JOIN 안전). [S-5 G1] AREA_CD(CM018)·AGE = DIM_MEMBER REGION/AGE_BAND 스냅샷 소스';

-- CRM 4: CRM_MEMBER_AMT_CHANGE (증감)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_AMT_CHANGE (
    OCCRRNC_DE          VARCHAR(8)      NOT NULL COMMENT '발생일자 YYYYMMDD (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '일련번호 (PK)',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    SPNSR_AMT           NUMBER(19,0)    COMMENT '변경 후 약정금액 (원단위)',
    RDCAMT_YN           VARCHAR(1)      COMMENT '감액여부 (Y=감액/N=증액)',
    ACMSLT_DEPT_CD      VARCHAR(10)     COMMENT '실적부서코드 (→CRM_ORG)',
    CMPGN_CD            VARCHAR(20)     COMMENT '캠페인코드 (→CRM_CAMPAIGN)',
    AREA_CD             VARCHAR(3)      COMMENT '지역코드 (CM018) — [S-5 G1] DIM_MEMBER REGION 스냅샷 소스',
    AREA_NM             VARCHAR         COMMENT '지역명 (코드 라벨)',
    AGE                 NUMBER(10,0)    COMMENT '연령 — [S-5 G1] DIM_MEMBER AGE_BAND 스냅샷 소스',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (OCCRRNC_DE, SER_NO)
) COMMENT = '약정 증감(증액/감액). [S-5 G1] AREA_CD(CM018)·AGE = DIM_MEMBER REGION/AGE_BAND 스냅샷 소스';

-- CRM 5: CRM_MEMBER_DISCONTINUE (중단)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_DISCONTINUE (
    MBER_NO             VARCHAR(10)     NOT NULL COMMENT '회원번호 (PK)',
    SPNSR_DSCNTC_DE     VARCHAR(8)      NOT NULL COMMENT '후원중단일자 YYYYMMDD (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '일련번호 (PK)',
    DSCNTC_RSN_CD       VARCHAR(3)      COMMENT '중단사유코드',
    DSCNTC_RSN_NM       VARCHAR         COMMENT '중단사유명 (코드 라벨)',
    DSCNTC_PATH         VARCHAR(1)      COMMENT '중단경로',
    REGIST_DEPT_CD      VARCHAR(10)     COMMENT '등록부서코드 (→CRM_ORG)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (MBER_NO, SPNSR_DSCNTC_DE, SER_NO)
) COMMENT = '후원중단';

-- CRM 6: CRM_MEMBER_RESPONSOR (재후원)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_RESPONSOR (
    MBER_NO             VARCHAR(10)     NOT NULL COMMENT '회원번호 (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '일련번호 (PK)',
    RE_SPNSR_DE         VARCHAR(8)      NOT NULL COMMENT '재후원일자 YYYYMMDD (PK)',
    REGIST_DEPT_CD      VARCHAR(10)     COMMENT '등록부서코드 (→CRM_ORG)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (MBER_NO, SER_NO, RE_SPNSR_DE)
) COMMENT = '재후원';

-- CRM 7: CRM_MEMBER_SPONSOR_BIZ (회원×후원사업)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_SPONSOR_BIZ (
    SPNSR_NO            VARCHAR(9)      NOT NULL COMMENT '후원번호 (PK)',
    SPNSR_BSNS_NO       NUMBER(19,0)    NOT NULL COMMENT '후원사업번호 (PK)',
    SPNSR_BSNS_ID       VARCHAR(20)     COMMENT '후원사업ID (→CRM_SPONSORSHIP)',
    SPNSR_AMT           NUMBER(19,0)    COMMENT '약정금액 (원단위)',
    SPNSR_DSCNTC_YN     VARCHAR(1)      COMMENT '후원중단여부 (Y/N)',
    SPNSR_DSCNTC_DE     VARCHAR(8)      COMMENT '후원중단일자 YYYYMMDD',
    SPNSR_DSCNTC_RSN_CD VARCHAR(3)      COMMENT '후원중단사유코드',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SPNSR_NO, SPNSR_BSNS_NO)
) COMMENT = '회원×후원사업 약정';

-- CRM 8: CRM_SPONSOR_RELATION (결연)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SPONSOR_RELATION (
    RELATNSP_KEY        NUMBER(10,0)    NOT NULL COMMENT '결연키 (PK)',
    SPNSR_NO            VARCHAR(9)      COMMENT '후원번호',
    SPNSR_BSNS_NO       NUMBER(19,0)    COMMENT '후원사업번호',
    SPNSR_BSNS_ID       VARCHAR(20)     COMMENT '후원사업ID (Q15 크로스워크 파생)',
    CHILD_CD            NUMBER(10,0)    COMMENT '결연아동코드',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    RELATNSP_STRT_DE    DATE            COMMENT '결연 시작일',
    RELATNSP_DSCNTC_DE  DATE            COMMENT '결연 중단일',
    RELATNSP_DSCNTC_YN  VARCHAR(1)      COMMENT '결연 중단여부 (Y/N)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (RELATNSP_KEY)
) COMMENT = '결연(아동). Q15 SPNSR_BSNS_ID 크로스워크 파생';

-- CRM 9: CRM_PAYMENT_BILLING (납입·청구 — 회비 ∪ 기부금)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_PAYMENT_BILLING (
    PAY_KEY             VARCHAR         NOT NULL COMMENT '납입/청구 대체키 (PK)',
    PAYMENT_TYPE        VARCHAR         COMMENT '납입유형 파생 (회비/기부금)',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    SPNSR_BSNS_ID       VARCHAR(20)     COMMENT '후원사업ID (→CRM_SPONSORSHIP)',
    RELATNSP_KEY        NUMBER(10,0)    COMMENT '결연키 (→CRM_SPONSOR_RELATION)',
    MBRFEE_MT           VARCHAR(6)      COMMENT '회비 대상월 YYYYMM',
    MBRFEE_SQNC         NUMBER(3,0)     COMMENT '회비 회차',
    RQEST_AMT           NUMBER(19,0)    COMMENT '청구금액 (원단위)',
    RQEST_DE            DATE            COMMENT '청구일자',
    PAY_AMT             NUMBER(10,0)    COMMENT '납입금액 (원단위)',
    PAY_DE              DATE            COMMENT '납입일자',
    PAY_STAT_CD         VARCHAR(3)      COMMENT '납입상태코드',
    SETLE_CD            VARCHAR(3)      COMMENT '결제수단코드',
    GFT_DIV_CD          VARCHAR(3)      COMMENT '기부구분코드',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (PAY_KEY)
) COMMENT = '납입/청구(회비∪기부금). Q14 납입 dedup·청구 행기준';

-- CRM 10: CRM_PAYMENT_METHOD (결제수단)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_PAYMENT_METHOD (
    SETLE_KEY           NUMBER(10,0)    NOT NULL COMMENT '결제수단키 (PK)',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    SETLE_CD            VARCHAR(3)      COMMENT '결제수단코드',
    SETLE_NM            VARCHAR         COMMENT '결제수단명 (코드 라벨)',
    CARD_DIV_CD         VARCHAR(3)      COMMENT '카드구분코드',
    FNLT_CD             VARCHAR(10)     COMMENT '금융기관코드',
    WTDRW_STRT_DE       DATE            COMMENT '출금 시작일',
    SETLE_STAT_CD       VARCHAR(3)      COMMENT '결제상태코드',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SETLE_KEY)
) COMMENT = '결제수단 (현재상태)';

-- CRM 11: CRM_CAMPAIGN (캠페인 마스터)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CAMPAIGN (
    CMPGN_CD            VARCHAR(20)     NOT NULL COMMENT '캠페인코드 (PK)',
    CMPGN_NM            VARCHAR(200)    COMMENT '캠페인명',
    UPPER_CMPGN_CD      VARCHAR(20)     COMMENT '상위캠페인코드 (자기참조)',
    UPPER_CMPGN_YN      VARCHAR(1)      COMMENT '상위캠페인 여부 (Y/N)',
    BRND_ID             VARCHAR(30)     COMMENT '브랜드ID',
    BRND_NM             VARCHAR(200)    COMMENT '브랜드명',
    PR_MTH_CD           VARCHAR(3)      COMMENT '홍보방법코드',
    SPNSR_BSNS_ID       VARCHAR(100)    COMMENT '후원사업ID (Q16 조인키)',
    CMPGN_CTGR_CD       NUMBER(10,0)    COMMENT '캠페인 카테고리코드',
    CMPGN_TYPE1_BSN     NUMBER(10,0)    COMMENT '캠페인 유형1 (사업)',
    CMPGN_TYPE2_BSN     NUMBER(10,0)    COMMENT '캠페인 유형2 (사업)',
    MKTG_CMPGN_NM       NUMBER(10,0)    COMMENT '마케팅 캠페인명 코드',
    MK_CMPGN_NM         VARCHAR(200)    COMMENT '마케팅 캠페인명 (라벨)',
    CMPGN_STRT_DE       VARCHAR(8)      COMMENT '캠페인 시작일 YYYYMMDD',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (CMPGN_CD)
) COMMENT = '캠페인 마스터. Q2/Q3 코드 라벨·Q16 조인키';

-- CRM 12: CRM_SPONSORSHIP (후원사업 마스터)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SPONSORSHIP (
    SPNSR_BSNS_ID       VARCHAR(20)     NOT NULL COMMENT '후원사업ID (PK)',
    SPNSR_BSNS_NM       VARCHAR(50)     COMMENT '후원사업명',
    SPNSR_BSNS_ABRV_CD  VARCHAR(3)      COMMENT '후원사업 약칭코드',
    SPNSR_DIV_CD        VARCHAR(3)      COMMENT '후원구분코드',
    DNTN_TY_CD          VARCHAR(3)      COMMENT '기부유형코드',
    CPR_DIV_CD          VARCHAR(3)      COMMENT '법인구분코드',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SPNSR_BSNS_ID)
) COMMENT = '후원사업 마스터 (실측 50개)';

-- CRM 13: CRM_ORG (조직 마스터)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_ORG (
    DEPT_ID                 VARCHAR(20)     NOT NULL COMMENT '부서ID (PK)',
    DEPT_NM                 VARCHAR(50)     COMMENT '부서명',
    UPPER_DEPT_ID           VARCHAR(20)     COMMENT '상위부서ID (조직 계층)',
    ACMSLT_UPPER_DEPT_ID    VARCHAR(20)     COMMENT '실적상위부서ID (실적팀 재귀 LVL5)',
    ACMSLT_DEPT_YN          VARCHAR(1)      COMMENT '실적부서 여부 (Y/N)',
    STATS_DEPT_LVL          NUMBER(3,0)     COMMENT '통계부서 레벨',
    USE_YN                  VARCHAR(1)      COMMENT '사용여부 (Y/N, 원천 확인)',
    SORT_ORDR               NUMBER(10,0)    COMMENT '정렬순서 (원천 확인)',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (DEPT_ID)
) COMMENT = '조직 마스터. 실적팀=ACMSLT_UPPER_DEPT_ID 재귀 LVL5. USE_YN·SORT_ORDR 원천 확인';

-- CRM 14: CRM_DEV_TARGET (개발목표)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_DEV_TARGET (
    STDYY               VARCHAR(4)      NOT NULL COMMENT '기준연도 YYYY (PK)',
    STDR_MT             VARCHAR(6)      NOT NULL COMMENT '기준월 YYYYMM (PK)',
    MBER_DVLP_DIV_CD    VARCHAR(1)      NOT NULL COMMENT '회원개발 구분코드 (PK)',
    DEPT_ID             VARCHAR(20)     NOT NULL COMMENT '부서ID (PK, →CRM_ORG)',
    GOAL_CNT            NUMBER(10,0)    COMMENT '목표 건수',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (STDYY, STDR_MT, MBER_DVLP_DIV_CD, DEPT_ID)
) COMMENT = '회원개발 목표 (월×조직×개발구분)';

-- CRM 15: CRM_SEND_REQUEST (발송요청)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_REQUEST (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL COMMENT '발송키 (PK)',
    SEND_CHANNEL        VARCHAR         COMMENT '발송채널 (SND/SMS/EMAIL 등)',
    SNDNG_TY_CD         VARCHAR(3)      COMMENT '발송유형코드',
    SEND_GBN_TOP        VARCHAR(255)    COMMENT '발송구분 대분류코드 [S-5 G2] DIM_SERVICE 대(SND 채널만)',
    SEND_GBN_TOP_NM     VARCHAR(255)    COMMENT '발송구분 대분류명 [S-5 G2]',
    SEND_GBN_MID        VARCHAR(255)    COMMENT '발송구분 중분류코드 [S-5 G2] DIM_SERVICE 중',
    SEND_GBN_MID_NM     VARCHAR(255)    COMMENT '발송구분 중분류명 [S-5 G2]',
    SEND_GBN_BOT        VARCHAR(255)    COMMENT '발송구분 소분류코드 [S-5 G2] DIM_SERVICE 소',
    SEND_GBN_BOT_NM     VARCHAR(255)    COMMENT '발송구분 소분류명 [S-5 G2]',
    TIT                 VARCHAR(100)    COMMENT '발송 제목',
    SNDNG_STDR_DE       TIMESTAMP_NTZ   COMMENT '발송 기준일시',
    REQ_SEQ_NO          NUMBER(19,0)    COMMENT '요청 일련번호',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SNDNG_KEY)
) COMMENT = '발송요청 마스터. Q5 발송키 이원화. [S-5 G2] SEND_GBN_TOP/MID/BOT(+_NM)=DIM_SERVICE 대/중/소(SND 채널만, 타 채널 NULL)';

-- CRM 16: CRM_SEND_MEMBER (발송×회원)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_MEMBER (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL COMMENT '발송키 (PK, →CRM_SEND_REQUEST)',
    SNDNG_DTL_KEY       NUMBER(10,0)    NOT NULL COMMENT '발송상세키 (PK)',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    SNDNG_DE            TIMESTAMP_NTZ   COMMENT '발송일시',
    SNDNG_RST_CD        VARCHAR(3)      COMMENT '발송결과코드',
    SEND_CHANNEL        VARCHAR         COMMENT '발송채널',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SNDNG_KEY, SNDNG_DTL_KEY)
) COMMENT = '발송×회원 상세';

-- CRM 17: CRM_SEND_RESULT (발송×채널 집계)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_RESULT (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL COMMENT '발송키 (PK, →CRM_SEND_REQUEST)',
    SEND_CHANNEL        VARCHAR         NOT NULL COMMENT '발송채널 (PK)',
    SNDNG_CNT           NUMBER(10,0)    COMMENT '발송 건수',
    SUCCES_CNT          NUMBER(10,0)    COMMENT '성공 건수',
    FAILR_CNT           NUMBER(10,0)    COMMENT '실패 건수',
    TOT_CLICK_CNT       NUMBER          COMMENT '총 클릭수',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SNDNG_KEY, SEND_CHANNEL)
) COMMENT = '발송×채널 집계';

-- CRM 18: CRM_EVENT (행사 마스터)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_EVENT (
    EVENT_KEY           VARCHAR         NOT NULL COMMENT '행사키 (PK)',
    EVENT_SOURCE        VARCHAR         COMMENT '행사출처 (이벤트/캠페인행사)',
    EVENT_DIV_CD        VARCHAR(3)      COMMENT '행사구분코드',
    EVENT_NM            VARCHAR(200)    COMMENT '행사명',
    STRT_DE             VARCHAR(8)      COMMENT '시작일자 YYYYMMDD',
    END_DE              VARCHAR(8)      COMMENT '종료일자 YYYYMMDD',
    RCRIT_PSNNL_CO      NUMBER(10,0)    COMMENT '모집인원 수',
    BRNCH_DEPT_ID       VARCHAR(20)     COMMENT '주관부서ID (→CRM_ORG)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (EVENT_KEY)
) COMMENT = '행사 마스터(이벤트∪캠페인행사)';

-- CRM 19: CRM_EVENT_PARTICIPATION (행사×참여자)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_EVENT_PARTICIPATION (
    EVENT_KEY           VARCHAR         NOT NULL COMMENT '행사키 (PK, →CRM_EVENT)',
    MBER_NO             VARCHAR(10)     NOT NULL COMMENT '회원번호 (PK)',
    PARTCPT_SEQ         NUMBER(10,0)    NOT NULL COMMENT '참여 일련번호 (PK)',
    PARTCPT_STAT_CD     VARCHAR(3)      COMMENT '참여상태코드',
    PARTCPT_CHNNL_CD    VARCHAR(3)      COMMENT '참여채널코드',
    PARTCPT_PATH_CD     VARCHAR(3)      COMMENT '참여경로코드',
    PRZWIN_CD           NUMBER(10,0)    COMMENT '당첨코드',
    RCPMNY_AMT          NUMBER(19,0)    COMMENT '입금금액 (원단위)',
    PARTCPT_DT          TIMESTAMP_NTZ   COMMENT '참여일시',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (EVENT_KEY, MBER_NO, PARTCPT_SEQ)
) COMMENT = '행사×참여자';

-- CRM 20: CRM_RELATION_ACTIVITY (결연활동 · EHGT 제외)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_RELATION_ACTIVITY (
    ACTIVITY_KEY        VARCHAR         NOT NULL COMMENT '결연활동 대체키 (PK)',
    ACTIVITY_TYPE       VARCHAR         COMMENT '활동유형 파생 (서신/선물금)',
    RELATNSP_KEY        NUMBER(10,0)    COMMENT '결연키 (→CRM_SPONSOR_RELATION)',
    MNG_NO              VARCHAR(7)      COMMENT '관리번호',
    GFTMNEY             NUMBER(10,0)    COMMENT '선물금 (원단위)',
    LETTER_DIV_CD       NUMBER(10,0)    COMMENT '서신구분코드',
    RCEPT_DE            DATE            COMMENT '접수일자',
    SNDNG_DE            DATE            COMMENT '발송일자',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (ACTIVITY_KEY)
) COMMENT = '결연활동(서신∪선물금). EHGT 제외';

-- CRM 21: CRM_CODE (코드 사전)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CODE (
    CD_ID               VARCHAR(20)     NOT NULL COMMENT '코드그룹 ID (PK)',
    DTL_CD_ID           VARCHAR(50)     NOT NULL COMMENT '상세코드 ID (PK)',
    DTL_CD_NM           VARCHAR(100)    COMMENT '상세코드명 (라벨)',
    UPPER_CD_ID         VARCHAR(20)     COMMENT '상위코드 ID (코드 계층)',
    SORT_ORDR           NUMBER(10,0)    COMMENT '정렬순서',
    USE_YN              VARCHAR(1)      COMMENT '사용여부 (Y/N)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (CD_ID, DTL_CD_ID)
) COMMENT = '코드→라벨 사전. (CD_ID,DTL_CD_ID) 복합키';

-- ============================================================================
-- STEP 4 — ERP (트랙 C, 2차) : BRONZE_ERP.BDGT_ACMSLT_LEDGER → SILVER 2객체 (사업목표는 CRM 트랙으로 재분류 2026-07-20)
--   근거 : 05_SILVER_작업계획_ERP전용
--   실측(2026-07-14) : 원장 2,041행 = 지출1,875 + 수입165 + TOTAL 1(사전집계 요약행 → 제외).
--                      full-hierarchy DISTINCT = 행수 → 각 행이 유일 예산과목(세세목).
--   원장 구조 : 차원 10 + 총액 4 + 월별 48(편성YEAR_BDGT/추경CHN/조정ADJ/집행EXEC × 12개월).
--   설계 : ITEM(마스터) + BUDGET(월 long 언피벗). ※BIZ_TARGET(사업목표)은 원천=CRM 확정 → CRM 트랙(STEP 3)으로 이동, SILVER.CRM_BIZ_TARGET.
--   키 : BUDGET_ITEM_DK = MD5(연도|수입지출|예산단위|장|관|항|목|목세|세세목|재원) — DIM/FACT 동일식.
-- ============================================================================

-- ERP 1: ERP_BUDGET_ITEM (예산과목 마스터 → DIM_BUDGET_ITEM)
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_BUDGET_ITEM (
    BUDGET_ITEM_DK      VARCHAR         NOT NULL COMMENT 'MD5 해시 대체키 (PK) = MD5(연도|수입지출|예산단위|장|관|항|목|세목|세세목|재원)',
    BUDGET_YEAR         NUMBER(4,0)     COMMENT '예산연도 YYYY',
    INCOME_EXPENSE_DIV  VARCHAR         COMMENT '수입/지출 구분',
    BUDGET_UNIT_NM      VARCHAR         COMMENT '예산단위 (=조직명, 코드 없음)',
    JANG_NM             VARCHAR         COMMENT '예산과목 1단계 장',
    KWAN_NM             VARCHAR         COMMENT '예산과목 2단계 관',
    HANG_NM             VARCHAR         COMMENT '예산과목 3단계 항',
    MOK_NM              VARCHAR         COMMENT '예산과목 4단계 목',
    DTL_ITEM_NM         VARCHAR         COMMENT '예산과목 5단계 세목',
    SUBDTL_ITEM_NM      VARCHAR         COMMENT '예산과목 6단계 세세목',
    FUND_SOURCE_NM      VARCHAR         COMMENT '재원',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (BUDGET_ITEM_DK)
) COMMENT = '예산과목 마스터(예산단위×장/관/항/목/세목/세세목×재원). TOTAL 요약행 제외. → DIM_BUDGET_ITEM';

-- ERP 2: ERP_BUDGET (월별 편성/추경/조정/집행 long → FBD)
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_BUDGET (
    BUDGET_ITEM_DK      VARCHAR         NOT NULL COMMENT '예산과목 대체키 (PK, →ERP_BUDGET_ITEM)',
    BUDGET_YEAR         NUMBER(4,0)     COMMENT '예산연도 YYYY',
    MONTH_NO            NUMBER(2,0)     NOT NULL COMMENT '월 1~12 (PK)',
    MONTH_KEY           VARCHAR(6)      COMMENT '월키 YYYYMM',
    YEAR_BUDGET_AMT     NUMBER(38,0)    COMMENT '편성(연예산) 금액 원단위',
    CHN_BUDGET_AMT      NUMBER(38,0)    COMMENT '추경 금액 원단위',
    ADJ_BUDGET_AMT      NUMBER(38,0)    COMMENT '조정 금액 원단위',
    EXEC_AMT            NUMBER(38,0)    COMMENT '집행 금액 원단위',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (BUDGET_ITEM_DK, MONTH_NO)
) COMMENT = '예산 편성/추경/조정/집행 월 grain(wide→long). 금액 원단위. → FBD(편성/집행). 모금성비용·광고비는 AGENCY 보강(E-1)';

-- CRM(신규) : CRM_BIZ_TARGET (사업목표 → FTG-B) — ⛔ CRM 신규 목표 테이블 입고 대기(E-6): 스키마-only, 적재 보류
-- ※원천=CRM 확정(2026-07-20 정정, 트랙 ERP→CRM 재분류). BRONZE_CRM.CRM_BIZ_TARGET → SILVER.CRM_BIZ_TARGET → GOLD FACT_TARGET_BIZ.
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_BIZ_TARGET (
    BIZ_TARGET_DK       VARCHAR         NOT NULL COMMENT '사업목표 대체키 (PK)',
    TARGET_YEAR         NUMBER(4,0)     COMMENT '목표연도 YYYY',
    MONTH_NO            NUMBER(2,0)     COMMENT '월 1~12',
    MONTH_KEY           VARCHAR(6)      COMMENT '월키 YYYYMM',
    ORG_CD              VARCHAR         COMMENT '조직코드 (FK→DIM_ORG; 이름조인 보완)',
    ORG_NM              VARCHAR         COMMENT '조직 (이름 — 크로스워크 전 조인키)',
    SPONSOR_BIZ_NM      VARCHAR         COMMENT '후원사업',
    CAMPAIGN_NM         VARCHAR         COMMENT '캠페인 (연결키 부재 Q10 — nullable)',
    TARGET_TYPE         VARCHAR         COMMENT '목표유형: 당초/추경1차/추경2차 → GOLD ANNUAL/SUPP 분기',
    TARGET_CNT          NUMBER(18,4)    COMMENT '연/추경 (누계)목표 건수(건) — 지표사전 #152~155. ※금액(원) 입고 시 /10000 파생',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (BIZ_TARGET_DK)
) COMMENT = 'FTG-B 사업목표. 원천=CRM 확정(2026-07-20). ⛔CRM 신규 목표 테이블 입고 대기(E-6) → 스키마-only, 적재 보류';

-- ============================================================================
-- STEP 5 — AGENCY (트랙 D, 3차) : BRONZE_AGENCY 3테이블 → SILVER 2객체 (AGENCY_COST는 리뷰 후 제거→GOLD)
--   근거 : 06_SILVER_작업계획_AGENCY전용
--   실측(2026-07-14) 설계결정 6종 확정 :
--     ① _SOURCE_SYSTEM = 테이블 기반(DIGITAL/REBROADCAST/VIDEO) — 행단위 출처 플래그 없음(A-2/Q9)
--     ② 인입콜 : REBRDC.INBOUND_CALL_CNT=TEXT(비수치 2/2064) → TRY_TO_NUMBER · VIDEO=NUMBER
--     ③ 전환 명/건 : DGT GA_CONV_MBER_CNT(명)/CONV_VU_CNT(VU) · REBRDC DVLP_MBER_CNT/DVLP_CNT · VIDEO CONV_CALL_CNT
--     ④ measure 불균일 : 노출·클릭=DGT만 / 광고비=GA_AD_COST·BRDC_SCHDL_COST(편성)·ACTL_PUR_AD_COST_KRW(집행) → NULL 패딩
--     ⑤ 캠페인명 : DGT.CMPGN_NM(100%) · VIDEO.MKT_CMPGN_NM(98.4%) · REBRDC=컬럼부재(방송명 BRDC_NM 대체)
--     ⑥ 파생(CPA/CTR/CVR/CPC/CPM/VTR) : SILVER 미적재(원천 base만 보존) — 재계산은 GOLD/SV(P2)
--   그레인 : AD_PERFORMANCE = 원천 1행(UNION, 총 235,572) · CREATIVE/COST = 파생 정제.
-- ============================================================================

-- AGENCY 1: AGENCY_AD_CREATIVE (매체·소재·CM위치·초수·유형 → DIM_AD_CREATIVE)
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_CREATIVE (
    CREATIVE_DK         VARCHAR         NOT NULL COMMENT 'MD5(소스+매체+소재+유형+CM위치+초수) 대체키 (PK)',
    SOURCE_SYSTEM       VARCHAR         NOT NULL COMMENT '소스 시스템 (DIGITAL/REBROADCAST/VIDEO)',
    MEDIA_CHANNEL_NM    VARCHAR         COMMENT '매체/채널명',
    CREATIVE_NM         VARCHAR         COMMENT '소재명 (DGT.MATR/REBRDC.BRDC_NM/VIDEO.MATR_NM)',
    CREATIVE_TYPE_NM    VARCHAR         COMMENT '소재유형/RT유형/캠페인유형',
    CM_AREA_NM          VARCHAR         COMMENT 'CM위치 (VIDEO)',
    AD_SEC_NM           VARCHAR         COMMENT '초수 (VIDEO)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (CREATIVE_DK)
) COMMENT = '광고 소재/매체 차원(3소스 UNION distinct). → DIM_AD_CREATIVE. 소스별 필드 산재→NULL 허용';

-- AGENCY 2: AGENCY_AD_PERFORMANCE (3소스 정제→UNION 광고성과 → FAD)
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_PERFORMANCE (
    SOURCE_SYSTEM       VARCHAR         NOT NULL COMMENT '소스 시스템 (DIGITAL/REBROADCAST/VIDEO) (②⑤)',
    AD_DATE             DATE            COMMENT '광고 집행일자',
    AD_YEAR             NUMBER(4,0)     COMMENT '광고 집행연도 YYYY',
    AD_MONTH            NUMBER(2,0)     COMMENT '광고 집행월 1~12',
    CAMPAIGN_NM         VARCHAR         COMMENT '캠페인명 (DGT.CMPGN_NM/VIDEO.MKT_CMPGN_NM/REBRDC=NULL) (⑤)',
    UPPER_CAMPAIGN_NM   VARCHAR         COMMENT '상위 캠페인명',
    MEDIA_CHANNEL_NM    VARCHAR         COMMENT '매체/채널명',
    DEVICE_NM           VARCHAR         COMMENT '디바이스 (DGT만)',
    CREATIVE_NM         VARCHAR         COMMENT '소재명',
    PROGRAM_NM          VARCHAR         COMMENT '프로그램명 (REBRDC.BRDC_NM/VIDEO.SCHDL_NM)',
    IMPRESSION_CNT      NUMBER(38,4)    COMMENT '노출수 (DGT만) (④)',
    CLICK_CNT           NUMBER(38,4)    COMMENT '클릭수 (DGT만) (④)',
    CONV_MEMBER_CNT     NUMBER(38,4)    COMMENT '전환/개발 명수 (③)',
    CONV_UNIT_CNT       NUMBER(38,4)    COMMENT '전환 VU/건수 (③, 비건수 주의)',
    INBOUND_CALL_CNT    NUMBER(38,4)    COMMENT '인입콜 수 (REBRDC=TRY_TO_NUMBER + VIDEO) (②)',
    CONV_CALL_CNT       NUMBER(38,4)    COMMENT 'VIDEO 전환콜 (별개 measure)',
    AD_CNT              NUMBER(38,4)    COMMENT '광고횟수 (REBRDC/VIDEO)',
    AD_COST             NUMBER(38,4)    COMMENT '광고비 (소스별 컬럼 상이)',
    COST_TYPE           VARCHAR         COMMENT '비용유형 (GA/편성(REBRDC)/집행(VIDEO))',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '광고성과 3소스 UNION(원천 1행 grain, 총 235,572). 파생 미적재(⑥). → FAD. GA4 전환 결합은 GOLD';

-- AGENCY 3: AGENCY_COST — ❌ 제거(2026-07-14 아키텍처 리뷰): 월 롤업은 master §3상 GOLD 소관 ·
--   AD_PERFORMANCE.AD_COST+COST_TYPE와 중복 · SILVER→SILVER 파생(단방향 위반). 비용은 성과팩트 원천 grain 보존, 롤업/ERP결합은 GOLD FBD.


-- ============================================================================
-- STEP 6 — GA4 (트랙 B, 1차) : BRONZE_GA4.events_YYYYMMDD 샤드 UNION → SILVER 5객체
--   근거 : 07_GA4_SILVER_샤드통합 설계결정.md · 14_GA4_작업지시 프롬프트_20260714.md
--   착수 게이트(§2) : 현재 1일 샤드 events_20260501(287,025행)만 입고 → PoC(DDL·FLATTEN 검증).
--                     전기간 샤드 입고 후 동일 DDL·적재로 멱등 재적재.
--   DDL 초안 이관원 : _archive/09_SILVER_DDL_20260702.sql (GA4 5테이블).
--   규칙 : 명시 30컬럼(SELECT * 금지) · session_traffic_source_last_click(UI 일치) ·
--          비가산 지표 raw 적재(율/평균은 GOLD) · 메타 4+1컬럼 · 멱등 INSERT OVERWRITE(09).
--   ⚠️ all-NULL 잡컬럼(app_info·event_dimensions·publisher)은 NUMBER — 매핑 제외.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- GA4 1: GA4_TRAFFIC_SOURCE  (DISTINCT 그레인 — PK 없음)
--   ⚠️ 그레인 = session_traffic_source_last_click 한정(last-click). first-touch(traffic_source)·
--      collected(collected_traffic_source)는 어트리뷰션 모델·grain 상이 → 본 차원 제외(혼재 시
--      그레인 팽창·DIM_GA_SOURCE fan-out). 필요 시 별도 유저/이벤트 grain 차원으로(GOLD). (GA4-검토 2026-07-14)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_TRAFFIC_SOURCE (
    UTM_SOURCE              VARCHAR         COMMENT 'UTM source (센티넬 NULLIF (not set)/(direct))',
    UTM_MEDIUM              VARCHAR         COMMENT 'UTM medium (센티넬 NULLIF (not set)/(none)/(direct))',
    UTM_CAMPAIGN            VARCHAR         COMMENT 'UTM campaign',
    UTM_CONTENT             VARCHAR         COMMENT 'UTM content',
    UTM_TERM                VARCHAR         COMMENT 'UTM term',
    SOURCE_MEDIUM           VARCHAR         COMMENT '파생 source / medium',
    XCHAN_SOURCE            VARCHAR         COMMENT 'cross_channel_campaign source (동일 last-click variant)',
    XCHAN_MEDIUM            VARCHAR         COMMENT 'cross_channel_campaign medium',
    XCHAN_CAMPAIGN          VARCHAR         COMMENT 'cross_channel_campaign campaign',
    DEFAULT_CHANNEL_GROUP   VARCHAR         COMMENT '기본 채널그룹 (⚠️정규화 금지 — 정상 라벨)',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE         VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA 트래픽소스(session/last-click 한정). 그레인=source/medium/campaign/content/term(+xchan/channel_group) DISTINCT → DIM_GA_SOURCE. first-touch·collected는 grain 상이로 제외(GA4-검토)';

-- ----------------------------------------------------------------------------
-- GA4 2: GA4_EVENT_DIM  (DISTINCT 그레인 — 키 NULL 가능 → PK 없음)
--   ⚠️ GA-2(카디널리티 리스크): event_label 혼합타입(문자+숫자)이 고카디널리티면 전기간 확장 시
--      본 차원이 사실상 팩트化(1일 실측 event_name 49개 대비 3,633행). GOLD DIM_GA_EVENT 는
--      event_name(+안정 category/action) 키로 conform, 변동성 label 은 팩트측(GA4_EVENT.EVENT_LABEL) 유지 권고.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_EVENT_DIM (
    EVENT_NAME          VARCHAR(200)    NOT NULL COMMENT '이벤트명 (그레인 핵심키)',
    EVENT_CATEGORY      VARCHAR         COMMENT '이벤트 카테고리',
    EVENT_LABEL         VARCHAR         COMMENT '이벤트 라벨 (⚠️혼합타입 → COALESCE(string,int))',
    EVENT_ACTION        VARCHAR         COMMENT '이벤트 액션',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA 이벤트분류. 그레인=event_name×category×label×action DISTINCT (PK 없음) → DIM_GA_EVENT';

-- ----------------------------------------------------------------------------
-- GA4 3: GA4_DEVICE  (DISTINCT 그레인 — 키 NULL 가능 → PK 없음)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_DEVICE (
    DEVICE_TYPE         VARCHAR(10)     NOT NULL COMMENT '디바이스 유형 PC/M/APP(파생) → DIM_DEVICE 핵심',
    PLATFORM            VARCHAR(50)     COMMENT '플랫폼 WEB/ANDROID/IOS (O2 conform 대기)',
    DEVICE_CATEGORY     VARCHAR         COMMENT '디바이스 카테고리 (원본)',
    OS                  VARCHAR         COMMENT '운영체제',
    BROWSER             VARCHAR         COMMENT '브라우저',
    LANGUAGE            VARCHAR         COMMENT '언어',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA 디바이스. 그레인=device_type×platform×category DISTINCT (PK 없음) → DIM_DEVICE(GA분)';

-- ----------------------------------------------------------------------------
-- GA4 4: GA4_EVENT  (이벤트 팩트 소스 — 복합 PK)
--   ⚠️ GA-1: 원천 샤드에 복합키 중복군 존재(1일 실측 16,187군) → 적재는 PK GROUP BY 로 dedup.
--   ⚠️ 07 §5-A session-fill: 원본 USER_ID 불변 보존 + 파생 USER_ID_FILLED/ID_RESOLUTION 신설.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_EVENT (
    USER_PSEUDO_ID          VARCHAR(200)    NOT NULL COMMENT '세션 스파인 (PK)',
    EVENT_TIMESTAMP         NUMBER          NOT NULL COMMENT 'UTC microsec (원본, 불변) (PK)',
    EVENT_NAME              VARCHAR(200)    NOT NULL COMMENT '이벤트명 (PK)',
    BATCH_ORDERING_ID       NUMBER          NOT NULL COMMENT '배치 내 정렬 ID (PK, dedup 보조)',
    EVENT_DATE              VARCHAR(8)      COMMENT '원본 YYYYMMDD (date-shard)',
    EVENT_DT                DATE            COMMENT '파생: TO_DATE(event_date,''YYYYMMDD'')',
    EVENT_TS                TIMESTAMP_NTZ   COMMENT '파생: TO_TIMESTAMP(event_timestamp/1e6)',
    USER_ID                 VARCHAR(10)     COMMENT 'CRM 회원번호(Q1) ⚠️VARCHAR·원본 불변',
    GA_SESSION_ID           NUMBER          COMMENT 'GA 세션ID (event_params 승격)',
    GA_SESSION_NUMBER       NUMBER          COMMENT 'GA 세션 번호',
    GA_SESSION_KEY          VARCHAR         COMMENT '파생: user_pseudo_id∥''-''∥ga_session_id (세션 자연키)',
    USER_ID_FILLED          VARCHAR(10)     COMMENT '파생: 세션 전파 회원번호(07 §5-A) — 회원 귀속용',
    ID_RESOLUTION           VARCHAR(20)     COMMENT '신원해소 신뢰도 DIRECT/SESSION_FILL/UNRESOLVED/CONFLICT',
    SESSION_ENGAGED         VARCHAR(5)      COMMENT '세션 engaged 여부 (⚠️혼합타입 → COALESCE)',
    ENGAGEMENT_TIME_MSEC    NUMBER          COMMENT '참여시간 msec (비가산 raw, O1)',
    PAGE_LOCATION           VARCHAR         COMMENT '페이지 URL',
    PAGE_TITLE              VARCHAR         COMMENT '페이지 제목',
    PAGE_REFERRER           VARCHAR         COMMENT '리퍼러 URL',
    EVENT_CATEGORY          VARCHAR         COMMENT '이벤트 카테고리',
    EVENT_ACTION            VARCHAR         COMMENT '이벤트 액션',
    EVENT_LABEL             VARCHAR         COMMENT '이벤트 라벨 (⚠️혼합타입 → COALESCE)',
    PERCENT_SCROLLED        NUMBER          COMMENT '스크롤 비율',
    LINK_URL                VARCHAR         COMMENT '클릭 링크 URL',
    LINK_TEXT               VARCHAR         COMMENT '클릭 링크 텍스트',
    DEVICE_TYPE             VARCHAR(10)     COMMENT '디바이스 유형 파생 PC/M/APP',
    DEVICE_CATEGORY         VARCHAR         COMMENT '디바이스 카테고리 (원본)',
    OS                      VARCHAR         COMMENT '운영체제',
    GEO_COUNTRY             VARCHAR         COMMENT '국가',
    GEO_CITY                VARCHAR         COMMENT '도시',
    UTM_SOURCE              VARCHAR         COMMENT 'UTM source (센티넬 NULLIF)',
    UTM_MEDIUM              VARCHAR         COMMENT 'UTM medium',
    UTM_CAMPAIGN            VARCHAR         COMMENT 'UTM campaign',
    DEFAULT_CHANNEL_GROUP   VARCHAR         COMMENT '기본 채널그룹',
    PLATFORM                VARCHAR(50)     COMMENT '플랫폼 WEB/ANDROID/IOS',
    IS_ACTIVE_USER          BOOLEAN         COMMENT '활성 사용자 여부',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE         VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, BATCH_ORDERING_ID)
) COMMENT = 'GA 이벤트 팩트 소스 → FACT_GA_BEHAVIOR. 비가산(engagement_time_msec 등)=raw 적재(O1). 원천 PK 중복은 적재 GROUP BY dedup(GA-1)';

-- ----------------------------------------------------------------------------
-- GA4 5: GA4_IDENTITY  (신원 — Q1 접두사 분기, 세션 채움 반영)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_IDENTITY (
    USER_PSEUDO_ID      VARCHAR(200)    NOT NULL COMMENT '세션 스파인 (PK)',
    GA_MEMBER_ID        VARCHAR(10)     COMMENT '= user_id_filled(세션 채움 후 회원번호) ⚠️VARCHAR',
    MEMBER_TYPE         VARCHAR(10)     COMMENT '파생: ''S%''→ONCE else FDRM',
    MBER_NO             VARCHAR(10)     COMMENT '정기 회원번호 ※비강제 FK→TM_MM_FDRM_MBER_INFO.MBER_NO(파생)',
    ONCE_MBER_NO        VARCHAR(10)     COMMENT '일시 회원번호 ※비강제 FK→TM_MM_ONCE_MBER_INFO.ONCE_MBER_NO(파생)',
    ID_RESOLUTION       VARCHAR(20)     COMMENT '신원해소 신뢰도 DIRECT/SESSION_FILL',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID)
) COMMENT = 'GA 신원(Q1 구조확정) → S-7 IDENTITY_MEMBER_XREF. 접두사 분기: S%→ONCE_MBER_NO / else→MBER_NO. 세션 채움(07 §5-A) 반영';

-- STEP 6 (DDL) 완료 — GA4 5객체. 적재는 09 STEP 6 참조.


-- ============================================================================
-- STEP 7 (DDL) — S-7 신원 브리지 (교차소스 유일 예외)
-- ----------------------------------------------------------------------------
--  IDENTITY_MEMBER_XREF : GA 신원(GA4_IDENTITY) ↔ CRM 회원(CRM_MEMBER) 해소 브리지.
--  ▸ 배치 근거(보수적 아키텍처): master §3 "교차소스 conform→GOLD" 원칙의 유일 예외.
--    확률적/추론 신원해소(GA측 ID_RESOLUTION=session-fill 추론값 + GA↔CRM MATCH_CONFIDENCE)를
--    SILVER 경계에 격리하여 GOLD.DIM_MEMBER_IDENTITY 를 결정적 차원으로 유지.
--  ▸ 서러게이트키(IDENTITY_SK) 없음 — SK 부여·conform 은 GOLD 소관. 여기는 자연키+매칭메타만.
--  ▸ grain = 1행/USER_PSEUDO_ID(GA 스파인). CHILD_CODE 제외(CRM_SPONSOR_RELATION 회원×아동 fan-out 회피).
--  ▸ ★grain 주의 : pseudo grain(1,348) ≠ member grain(distinct MEMBER_DK 1,274). GOLD DIM_MEMBER_IDENTITY(회원차원)
--    구축 시 MEMBER_DK DISTINCT 필수 · UNMATCHED 제외(MEMBER_DK NOT NULL). 커버리지 4.84%(익명 95%→LEFT JOIN). 09 STEP7 소비계약 참조.
--  ▸ 미매칭 GA 신원도 보존(MATCH_METHOD='UNMATCHED') — 전기간 샤드 커버리지·DQ 추적용.
--  ▸ 단방향 : SILVER(GA4_IDENTITY, CRM_MEMBER) 만 참조. BRONZE/GOLD 직참조 없음.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.IDENTITY_MEMBER_XREF (
    USER_PSEUDO_ID      VARCHAR(200)    NOT NULL COMMENT 'GA 세션 스파인 (PK)',
    GA_MEMBER_ID        VARCHAR(10)     COMMENT 'GA측 회원번호(=user_id_filled)',
    MEMBER_TYPE         VARCHAR(10)     COMMENT '회원구분 ONCE(S%)/FDRM',
    MEMBER_DK           VARCHAR(10)     COMMENT '매칭된 CRM 불변회원키(미매칭 NULL). ※비강제 FK→CRM_MEMBER.MEMBER_DK',
    HOMEPAGE_ID         VARCHAR         COMMENT '매칭 CRM 회원의 HMPG_ID(미매칭 NULL)',
    ID_RESOLUTION       VARCHAR(20)     COMMENT 'GA측 신뢰도 passthrough: DIRECT/SESSION_FILL',
    MATCH_METHOD        VARCHAR(30)     COMMENT '매칭방법 MEMBER_ID_EXACT / UNMATCHED',
    MATCH_CONFIDENCE    VARCHAR(10)     COMMENT '매칭신뢰도 HIGH(exact+DIRECT) / MEDIUM(exact+SESSION_FILL) / NONE(미매칭)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID)
) COMMENT = 'S-7 신원 브리지(교차소스 유일예외). GA4_IDENTITY ↔ CRM_MEMBER 자연키 해소 + MATCH_METHOD/CONFIDENCE. SK없음(GOLD 소관). CHILD_CODE 제외(fan-out). 미매칭 보존';

-- STEP 7 (DDL) 완료 — 신원 브리지 1객체. 적재는 09 ST