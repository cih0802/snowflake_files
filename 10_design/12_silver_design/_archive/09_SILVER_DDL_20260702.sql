-- GN_DW.SILVER 전체 테이블 DDL — 미사용 감사 컬럼 DW_BATCH_ID 제거 반영.
-- Co-authored with CoCo
/*
================================================================================
  ⛔ ARCHIVED / SUPERSEDED (2026-07-14)
  ─────────────────────────────────────────────────────────────────────────────
  이 파일의 역할(SILVER 테이블 DDL 정본)은 `silver_stepbystep_ddl.sql`(CRM 21테이블
  DDL + BRONZE→SILVER 정제 INSERT 통합 실행 정본)이 대체함. 신규 작업은 그 파일 사용.
  본 파일은 참조용으로만 보존:
    - GA4 SILVER 5테이블 DDL(GA4_TRAFFIC_SOURCE·GA4_EVENT_DIM·GA4_DEVICE·GA4_EVENT·
      GA4_IDENTITY)은 아직 stepbystep에 미이관 → 트랙 B(S-6) 착수 시 이 초안 참조.
================================================================================
  GN_DW.SILVER — 전체 테이블 DDL (26개: CRM 21 + GA4 5)
  작성일   : 2026-07-02
  근거 문서 : SILVER 스키마 컬럼 인벤토리_20260630.csv (CRM 21 + GA4 5)
             04_silver_design/SILVER_작업계획_BRONZE-GOLD연결 20260630.md
             04_silver_design/SILVER_작업계획_GA4전용 20260702.md
--------------------------------------------------------------------------------
  DDL 생성 규칙 (보수적 · 후속 로드 오류 방지)
  ─────────────────────────────────────────────────────────────────────────────
  1. NOT NULL 은 (PK 컬럼) + (DW_SOURCE_SYSTEM · DW_LOAD_TS) 에만 적용.
     그 외 컬럼은 인벤토리가 N이라도 NULLABLE 로 생성.
     → Silver 정제 INSERT 시 예기치 못한 NULL 로 인한 로드 실패 방지(Gold DDL 동일 정책).
  2. FK 제약은 생성하지 않음(전부 ※비강제) — 컬럼만 정의, 조인은 ETL/뷰에서.
     Snowflake 는 PK/FK/UNIQUE 를 강제하지 않음(정보성) — PK 는 문서화 목적.
  3. DISTINCT 그레인 차원(GA4_TRAFFIC_SOURCE·GA4_EVENT_DIM·GA4_DEVICE)은
     키 구성 컬럼이 NULL 가능 → PRIMARY KEY 선언 안 함(그레인은 COMMENT 로 기록).
  4. VARCHAR 무길이는 Snowflake 기본(16MB). 인벤토리 명시 길이는 그대로 반영.
  5. 회원키(MEMBER_DK·MBER_NO·ONCE_MBER_NO·GA_MEMBER_ID·USER_ID) = VARCHAR
     — 선행0·S접두 보존(NUMBER 캐스팅 금지, Q1 구조확정).
  6. 제외: CRM_RELATION_ACTIVITY.EHGT (Q11 해소 — Silver 미연동).
  7. 메타 5컬럼: DW_SOURCE_SYSTEM · DW_SOURCE_TABLE · DW_LOAD_TS(최초적재,NOT NULL) · DW_UPDATE_TS(최종적재) · DW_BATCH_ID(=dbt invocation_id).
     LOAD_TS는 merge 갱신 제외(보존), UPDATE_TS·BATCH_ID는 run마다 갱신.

  ⚠️ 후속 작업 주의 (파싱 SQL 정합)
  ─────────────────────────────────────────────────────────────────────────────
  - 본 DDL 로 빈 테이블 생성 후, 정제는 `INSERT INTO <table> SELECT ...` 로 채운다.
    기존 GA4 파싱 SQL(SILVER_GA4_bronze_parsing_20260702.sql)의
    `CREATE OR REPLACE TABLE ... AS SELECT`(CTAS)는 이 DDL 구조(PK·타입·길이)를
    덮어쓰므로, INSERT 패턴으로 교체하거나 컬럼 캐스팅을 DDL과 일치시킬 것.
  - 파싱 SQL 컬럼명(소문자)을 본 DDL(대문자)에 맞춰 정렬 필요.
================================================================================
*/

CREATE SCHEMA IF NOT EXISTS GN_DW.SILVER
  COMMENT = 'Silver 레이어 — Bronze(CRM·GA4) 정제 객체 (GOLD 입력용)';

USE SCHEMA GN_DW.SILVER;

-- ============================================================================
-- CRM 1: CRM_MEMBER (회원 통합 — 정기 ∪ 일시)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER (
    MEMBER_DK           VARCHAR(10)     NOT NULL,   -- 회원키(정기 MBER_NO / 일시 ONCE_MBER_NO). ⚠️Q6 UNION 잠정
    MEMBER_TYPE         VARCHAR(10),                -- 정기/일시(파생)
    MBER_DIV_CD         VARCHAR(3),
    MBER_DIV_NM         VARCHAR,                     -- 파생(코드→라벨)
    CPR_DIV_CD          VARCHAR(3),
    SEX                 VARCHAR(2),
    MBER_STAT_CD        VARCHAR(3),                  -- MM010(정기만)
    MBER_STAT_NM        VARCHAR,                     -- 파생
    CMPGN_CD            VARCHAR(20),
    ACT_DEPT_CD         VARCHAR(10),
    REGIST_DEPT_CD      VARCHAR(10),
    JOIN_PATH_CD        VARCHAR(3),
    HMPG_ID             VARCHAR(30),
    ENTRPS_NM           VARCHAR(200),
    EMAIL_RECPTN        VARCHAR,                     -- ⚠️Q6 멀티값 정규화 필요
    PSTMTR_RECPTN       VARCHAR,                     -- ⚠️Q6 동일 규칙
    JOIN_DT             TIMESTAMP_NTZ,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (MEMBER_DK)
) COMMENT = '회원 통합(정기∪일시). ⚠️Q6 UNION 스키마 정렬 잠정';

-- ============================================================================
-- CRM 2: CRM_MEMBER_STATUS_HIST (회원 상태전이 · SCD2)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_STATUS_HIST (
    MBER_NO             VARCHAR(10)     NOT NULL,   -- ※비강제 FK→CRM_MEMBER.MEMBER_DK
    SER_NO              NUMBER(10,0)    NOT NULL,
    BF_STAT_CD          VARCHAR(3),
    BF_STAT_NM          VARCHAR,                     -- 파생
    CHN_STAT_CD         VARCHAR(3),
    CHN_STAT_NM         VARCHAR,                     -- 파생
    EFFECTIVE_FROM      TIMESTAMP_NTZ,               -- SCD2 시작
    EFFECTIVE_TO        TIMESTAMP_NTZ,               -- SCD2 종료(파생)
    IS_CURRENT          BOOLEAN,                     -- SCD2(파생)
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (MBER_NO, SER_NO)
) COMMENT = '회원 상태전이 이력 (SCD2 range)';

-- ============================================================================
-- CRM 3: CRM_MEMBER_DEV (개발약정)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_DEV (
    SPNSR_NO            VARCHAR(9)      NOT NULL,
    SPNSR_BSNS_NO       NUMBER(19,0)    NOT NULL,   -- 약정단위(차원키 아님)
    OCCRRNC_DE          VARCHAR(8)      NOT NULL,
    SER_NO              NUMBER(10,0)    NOT NULL,
    MBER_NO             VARCHAR(10),                 -- ※비강제 FK→CRM_MEMBER
    SPNSR_BSNS_ID       VARCHAR(20),                 -- ※비강제 FK→CRM_SPONSORSHIP
    SPNSR_AMT           NUMBER(19,0),                -- 원금액 보존
    DVLP_DIV_CD         VARCHAR(3),                  -- MM015
    ACT_DEPT_CD         VARCHAR(10),
    ACMSLT_DEPT_CD      VARCHAR(10),
    CMPGN_CD            VARCHAR(20),
    SETLE_CD            VARCHAR(3),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO)
) COMMENT = '개발약정 (Q13 스파인 — N:1 LEFT JOIN 안전)';

-- ============================================================================
-- CRM 4: CRM_MEMBER_AMT_CHANGE (증감)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_AMT_CHANGE (
    OCCRRNC_DE          VARCHAR(8)      NOT NULL,
    SER_NO              NUMBER(10,0)    NOT NULL,
    MBER_NO             VARCHAR(10),
    SPNSR_AMT           NUMBER(19,0),                -- 원금액 보존
    RDCAMT_YN           VARCHAR(1),                  -- Y=감액·N=증액
    ACMSLT_DEPT_CD      VARCHAR(10),
    CMPGN_CD            VARCHAR(20),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (OCCRRNC_DE, SER_NO)
) COMMENT = '약정 증감(증액/감액)';

-- ============================================================================
-- CRM 5: CRM_MEMBER_DISCONTINUE (중단)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_DISCONTINUE (
    MBER_NO             VARCHAR(10)     NOT NULL,
    SPNSR_DSCNTC_DE     VARCHAR(8)      NOT NULL,
    SER_NO              NUMBER(10,0)    NOT NULL,
    DSCNTC_RSN_CD       VARCHAR(3),                  -- MM005 → DIM_REASON
    DSCNTC_RSN_NM       VARCHAR,                     -- 파생
    DSCNTC_PATH         VARCHAR(1),
    REGIST_DEPT_CD      VARCHAR(10),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (MBER_NO, SPNSR_DSCNTC_DE, SER_NO)
) COMMENT = '후원중단';

-- ============================================================================
-- CRM 6: CRM_MEMBER_RESPONSOR (재후원)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_RESPONSOR (
    MBER_NO             VARCHAR(10)     NOT NULL,
    SER_NO              NUMBER(10,0)    NOT NULL,
    RE_SPNSR_DE         VARCHAR(8)      NOT NULL,
    REGIST_DEPT_CD      VARCHAR(10),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (MBER_NO, SER_NO, RE_SPNSR_DE)
) COMMENT = '재후원';

-- ============================================================================
-- CRM 7: CRM_MEMBER_SPONSOR_BIZ (회원×후원사업)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_SPONSOR_BIZ (
    SPNSR_NO            VARCHAR(9)      NOT NULL,
    SPNSR_BSNS_NO       NUMBER(19,0)    NOT NULL,
    SPNSR_BSNS_ID       VARCHAR(20),                 -- Q15 NO→ID 크로스워크 소스
    SPNSR_AMT           NUMBER(19,0),
    SPNSR_DSCNTC_YN     VARCHAR(1),
    SPNSR_DSCNTC_DE     VARCHAR(8),
    SPNSR_DSCNTC_RSN_CD VARCHAR(3),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SPNSR_NO, SPNSR_BSNS_NO)
) COMMENT = '회원×후원사업 약정';

-- ============================================================================
-- CRM 8: CRM_SPONSOR_RELATION (결연)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SPONSOR_RELATION (
    RELATNSP_KEY        NUMBER(10,0)    NOT NULL,
    SPNSR_NO            VARCHAR(9),
    SPNSR_BSNS_NO       NUMBER(19,0),
    SPNSR_BSNS_ID       VARCHAR(20),                 -- ⚠️Q15 NO→ID 크로스워크(파생·20건 모호)
    CHILD_CD            NUMBER(10,0),                -- 결연아동코드 → DIM_MEMBER_IDENTITY
    MBER_NO             VARCHAR(10),
    RELATNSP_STRT_DE    DATE,
    RELATNSP_DSCNTC_DE  DATE,
    RELATNSP_DSCNTC_YN  VARCHAR(1),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (RELATNSP_KEY)
) COMMENT = '결연(아동). ⚠️Q15 SPNSR_BSNS_ID 크로스워크 파생';

-- ============================================================================
-- CRM 9: CRM_PAYMENT_BILLING (납입·청구 — 회비 ∪ 기부금)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_PAYMENT_BILLING (
    PAY_KEY             VARCHAR         NOT NULL,   -- 파생 통합키(MBRFEE_KEY/DNTN_KEY 접두)
    PAYMENT_TYPE        VARCHAR,                     -- 회비/기부금(파생)
    MBER_NO             VARCHAR(10),
    SPNSR_BSNS_ID       VARCHAR(20),
    RELATNSP_KEY        NUMBER(10,0),
    MBRFEE_MT           VARCHAR(6),                  -- YYYYMM(회비)
    MBRFEE_SQNC         NUMBER(3,0),
    RQEST_AMT           NUMBER(19,0),                -- ⚠️Q14 청구는 행 기준
    RQEST_DE            DATE,
    PAY_AMT             NUMBER(10,0),                -- ⚠️Q14 납입건 dedup 후 집계
    PAY_DE              DATE,
    PAY_STAT_CD         VARCHAR(3),                  -- 미납=F OR NULL[C-3]
    SETLE_CD            VARCHAR(3),
    GFT_DIV_CD          VARCHAR(3),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (PAY_KEY)
) COMMENT = '납입/청구(회비∪기부금). ⚠️Q14 납입 dedup·청구 행기준';

-- ============================================================================
-- CRM 10: CRM_PAYMENT_METHOD (결제수단)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_PAYMENT_METHOD (
    SETLE_KEY           NUMBER(10,0)    NOT NULL,
    MBER_NO             VARCHAR(10),
    SETLE_CD            VARCHAR(3),
    SETLE_NM            VARCHAR,                     -- 파생
    CARD_DIV_CD         VARCHAR(3),
    FNLT_CD             VARCHAR(10),
    WTDRW_STRT_DE       DATE,
    SETLE_STAT_CD       VARCHAR(3),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,               -- 가변 테이블(이력반영)
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SETLE_KEY)
) COMMENT = '결제수단 (현재상태)';

-- ============================================================================
-- CRM 11: CRM_CAMPAIGN (캠페인 마스터)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CAMPAIGN (
    CMPGN_CD            VARCHAR(20)     NOT NULL,
    CMPGN_NM            VARCHAR(200),
    UPPER_CMPGN_CD      VARCHAR(20),                 -- 자기참조
    UPPER_CMPGN_YN      VARCHAR(1),
    BRND_ID             VARCHAR(30),
    BRND_NM             VARCHAR(200),                -- 동일소스 JOIN
    PR_MTH_CD           VARCHAR(3),                  -- CM008
    SPNSR_BSNS_ID       VARCHAR(100),
    CMPGN_CTGR_CD       NUMBER(10,0),                -- MM294 #17 ⚠️Q3
    CMPGN_TYPE1_BSN     NUMBER(10,0),                -- MM295 #15 ⚠️Q2
    CMPGN_TYPE2_BSN     NUMBER(10,0),                -- MM296 #16 ⚠️Q2
    MKTG_CMPGN_NM       NUMBER(10,0),                -- ⚠️조인키 불일치 확인(Q16)
    MK_CMPGN_NM         VARCHAR(200),                -- ⚠️조인키 확인
    CMPGN_STRT_DE       VARCHAR(8),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (CMPGN_CD)
) COMMENT = '캠페인 마스터. ⚠️Q2/Q3 코드 라벨·Q16 조인키';

-- ============================================================================
-- CRM 12: CRM_SPONSORSHIP (후원사업 마스터)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SPONSORSHIP (
    SPNSR_BSNS_ID       VARCHAR(20)     NOT NULL,   -- DIM_SPONSORSHIP 키
    SPNSR_BSNS_NM       VARCHAR(50),
    SPNSR_BSNS_ABRV_CD  VARCHAR(3),
    SPNSR_DIV_CD        VARCHAR(3),                  -- CM035
    DNTN_TY_CD          VARCHAR(3),
    CPR_DIV_CD          VARCHAR(3),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SPNSR_BSNS_ID)
) COMMENT = '후원사업 마스터 (실측 50개)';

-- ============================================================================
-- CRM 13: CRM_ORG (조직 마스터)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_ORG (
    DEPT_ID                 VARCHAR(20)     NOT NULL,
    DEPT_NM                 VARCHAR(50),
    UPPER_DEPT_ID           VARCHAR(20),             -- 자기참조 계층
    ACMSLT_UPPER_DEPT_ID    VARCHAR(20),             -- 실적상위(루트 ZV000000)
    ACMSLT_DEPT_YN          VARCHAR(1),
    STATS_DEPT_LVL          NUMBER(3,0),             -- 미사용[C-7]
    USE_YN                  VARCHAR(1),              -- ⚠️추가(원천 확인)
    SORT_ORDR               NUMBER(10,0),            -- ⚠️추가(원천 확인)
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL,
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (DEPT_ID)
) COMMENT = '조직 마스터. 실적팀=ACMSLT_UPPER_DEPT_ID 재귀 LVL5. ⚠️USE_YN·SORT_ORDR 원천 확인';

-- ============================================================================
-- CRM 14: CRM_DEV_TARGET (개발목표)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_DEV_TARGET (
    STDYY               VARCHAR(4)      NOT NULL,
    STDR_MT             VARCHAR(6)      NOT NULL,
    MBER_DVLP_DIV_CD    VARCHAR(1)      NOT NULL,   -- MM015
    DEPT_ID             VARCHAR(20)     NOT NULL,
    GOAL_CNT            NUMBER(10,0),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (STDYY, STDR_MT, MBER_DVLP_DIV_CD, DEPT_ID)
) COMMENT = '회원개발 목표 (월×조직×개발구분)';

-- ============================================================================
-- CRM 15: CRM_SEND_REQUEST (발송요청)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_REQUEST (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL,   -- ⚠️Q5 키 이원화 미해소
    SEND_CHANNEL        VARCHAR,                     -- 파생(EMAIL/MSG_AT/PSTMTR)
    SNDNG_TY_CD         VARCHAR(3),
    TIT                 VARCHAR(100),
    SNDNG_STDR_DE       TIMESTAMP_NTZ,
    REQ_SEQ_NO          NUMBER(19,0),                -- ⚠️Q5
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SNDNG_KEY)
) COMMENT = '발송요청 마스터. ⚠️Q5 발송키 이원화';

-- ============================================================================
-- CRM 16: CRM_SEND_MEMBER (발송×회원)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_MEMBER (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL,   -- ※비강제 FK→CRM_SEND_REQUEST
    SNDNG_DTL_KEY       NUMBER(10,0)    NOT NULL,
    MBER_NO             VARCHAR(10),
    SNDNG_DE            TIMESTAMP_NTZ,
    SNDNG_RST_CD        VARCHAR(3),                  -- 하드코딩 0/1/4/5 CASE 매핑
    SEND_CHANNEL        VARCHAR,                     -- 파생
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SNDNG_KEY, SNDNG_DTL_KEY)
) COMMENT = '발송×회원 상세';

-- ============================================================================
-- CRM 17: CRM_SEND_RESULT (발송×채널 집계)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_RESULT (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL,
    SEND_CHANNEL        VARCHAR         NOT NULL,   -- 파생(PK 일부)
    SNDNG_CNT           NUMBER(10,0),
    SUCCES_CNT          NUMBER(10,0),
    FAILR_CNT           NUMBER(10,0),
    TOT_CLICK_CNT       NUMBER,                      -- ⚠️CTNT 문자→숫자 파싱
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SNDNG_KEY, SEND_CHANNEL)
) COMMENT = '발송×채널 집계';

-- ============================================================================
-- CRM 18: CRM_EVENT (행사 마스터)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_EVENT (
    EVENT_KEY           VARCHAR         NOT NULL,   -- 파생 통합키(EVENT_CD/CRMN_CD)
    EVENT_SOURCE        VARCHAR,                     -- 파생(EVENT/CRMN)
    EVENT_DIV_CD        VARCHAR(3),
    EVENT_NM            VARCHAR(200),
    STRT_DE             VARCHAR(8),
    END_DE              VARCHAR(8),
    RCRIT_PSNNL_CO      NUMBER(10,0),
    BRNCH_DEPT_ID       VARCHAR(20),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (EVENT_KEY)
) COMMENT = '행사 마스터(이벤트∪캠페인행사)';

-- ============================================================================
-- CRM 19: CRM_EVENT_PARTICIPATION (행사×참여자)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_EVENT_PARTICIPATION (
    EVENT_KEY           VARCHAR         NOT NULL,
    MBER_NO             VARCHAR(10)     NOT NULL,
    PARTCPT_SEQ         NUMBER(10,0)    NOT NULL,
    PARTCPT_STAT_CD     VARCHAR(3),
    PARTCPT_CHNNL_CD    VARCHAR(3),
    PARTCPT_PATH_CD     VARCHAR(3),
    PRZWIN_CD           NUMBER(10,0),
    RCPMNY_AMT          NUMBER(19,0),                -- 원금액
    PARTCPT_DT          TIMESTAMP_NTZ,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (EVENT_KEY, MBER_NO, PARTCPT_SEQ)
) COMMENT = '행사×참여자';

-- ============================================================================
-- CRM 20: CRM_RELATION_ACTIVITY (결연활동 · EHGT 제외)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_RELATION_ACTIVITY (
    ACTIVITY_KEY        VARCHAR         NOT NULL,   -- 파생 통합키(서신/선물금)
    ACTIVITY_TYPE       VARCHAR,                     -- 파생
    RELATNSP_KEY        NUMBER(10,0),                -- ※비강제 FK→CRM_SPONSOR_RELATION
    MNG_NO              VARCHAR(7),
    GFTMNEY             NUMBER(10,0),                -- 원금액
    LETTER_DIV_CD       NUMBER(10,0),
    RCEPT_DE            DATE,
    SNDNG_DE            DATE,
    -- EHGT 제외 (Q11 해소 — Silver 미연동)
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (ACTIVITY_KEY)
) COMMENT = '결연활동(서신∪선물금). EHGT 제외';

-- ============================================================================
-- CRM 21: CRM_CODE (코드 사전)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CODE (
    CD_ID               VARCHAR(20)     NOT NULL,
    DTL_CD_ID           VARCHAR(50)     NOT NULL,   -- ⚠️전역 비유일 → 복합키 필수
    DTL_CD_NM           VARCHAR(100),                -- 라벨
    UPPER_CD_ID         VARCHAR(20),
    SORT_ORDR           NUMBER(10,0),
    USE_YN              VARCHAR(1),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (CD_ID, DTL_CD_ID)
) COMMENT = '코드→라벨 사전. (CD_ID,DTL_CD_ID) 복합키';


-- ============================================================================
-- GA4 1: GA4_TRAFFIC_SOURCE  (DISTINCT 그레인 — PK 없음)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_TRAFFIC_SOURCE (
    UTM_SOURCE              VARCHAR,                 -- 센티넬 NULLIF
    UTM_MEDIUM              VARCHAR,                 -- 센티넬 NULLIF
    UTM_CAMPAIGN            VARCHAR,
    UTM_CONTENT             VARCHAR,
    UTM_TERM                VARCHAR,
    SOURCE_MEDIUM           VARCHAR,                 -- 파생
    XCHAN_SOURCE            VARCHAR,
    XCHAN_MEDIUM            VARCHAR,
    XCHAN_CAMPAIGN          VARCHAR,
    DEFAULT_CHANNEL_GROUP   VARCHAR,                 -- ⚠️정규화 금지(정상 라벨)
    TS_SOURCE               VARCHAR,                 -- first-touch(보조)
    TS_MEDIUM               VARCHAR,
    TS_CAMPAIGN             VARCHAR,
    CTS_SOURCE              VARCHAR,                 -- ⚠️표본 0/1000(Q-GA6)
    CTS_MEDIUM              VARCHAR,                 -- ⚠️표본 0/1000(Q-GA6)
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL,
    DW_SOURCE_TABLE         VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR
) COMMENT = 'GA 트래픽소스(session/last-click). 그레인=source/medium/campaign/content/term DISTINCT (PK 없음)';

-- ============================================================================
-- GA4 2: GA4_EVENT_DIM  (DISTINCT 그레인 — 키 NULL 가능 → PK 없음)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_EVENT_DIM (
    EVENT_NAME          VARCHAR(200)    NOT NULL,
    EVENT_CATEGORY      VARCHAR,
    EVENT_LABEL         VARCHAR,                     -- ⚠️혼합타입 → COALESCE
    EVENT_ACTION        VARCHAR,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR
) COMMENT = 'GA 이벤트분류. 그레인=event_name×category×label×action DISTINCT (category/label/action NULL 가능 → PK 없음)';

-- ============================================================================
-- GA4 3: GA4_DEVICE  (DISTINCT 그레인 — 키 NULL 가능 → PK 없음)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_DEVICE (
    DEVICE_TYPE         VARCHAR(10)     NOT NULL,   -- PC/M/APP(파생) → DIM_DEVICE 핵심
    PLATFORM            VARCHAR(50),                 -- WEB/ANDROID/IOS
    DEVICE_CATEGORY     VARCHAR,
    OS                  VARCHAR,
    BROWSER             VARCHAR,
    LANGUAGE            VARCHAR,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR
) COMMENT = 'GA 디바이스. 그레인=device_type×platform×category DISTINCT (platform/category NULL 가능 → PK 없음)';

-- ============================================================================
-- GA4 4: GA4_EVENT  (이벤트 팩트 소스 — 복합 PK)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_EVENT (
    USER_PSEUDO_ID          VARCHAR(200)    NOT NULL,   -- ⚠️PK 복합 유일성 미검증(GA-1)
    EVENT_TIMESTAMP         NUMBER          NOT NULL,   -- UTC microsec(원본)
    EVENT_NAME              VARCHAR(200)    NOT NULL,
    BATCH_ORDERING_ID       NUMBER          NOT NULL,
    EVENT_DATE              VARCHAR(8),                  -- YYYYMMDD(date-shard)
    EVENT_DT                DATE,                        -- 파생
    EVENT_TS                TIMESTAMP_NTZ,               -- 파생
    USER_ID                 VARCHAR(10),                 -- CRM 회원번호(Q1) ⚠️VARCHAR 필수
    GA_SESSION_ID           NUMBER,                      -- 세션키 = pseudo_id + ga_session_id
    GA_SESSION_NUMBER       NUMBER,
    SESSION_ENGAGED         VARCHAR(5),                  -- ⚠️혼합타입 → COALESCE
    ENGAGEMENT_TIME_MSEC    NUMBER,
    PAGE_LOCATION           VARCHAR,
    PAGE_TITLE              VARCHAR,
    PAGE_REFERRER           VARCHAR,
    EVENT_CATEGORY          VARCHAR,
    EVENT_ACTION            VARCHAR,
    EVENT_LABEL             VARCHAR,                     -- ⚠️혼합타입 → COALESCE
    PERCENT_SCROLLED        NUMBER,
    LINK_URL                VARCHAR,
    LINK_TEXT               VARCHAR,
    DEVICE_TYPE             VARCHAR(10),                 -- 파생
    DEVICE_CATEGORY         VARCHAR,
    OS                      VARCHAR,
    GEO_COUNTRY             VARCHAR,
    GEO_CITY                VARCHAR,
    UTM_SOURCE              VARCHAR,                     -- 센티넬 NULLIF
    UTM_MEDIUM              VARCHAR,                     -- 센티넬 NULLIF
    UTM_CAMPAIGN            VARCHAR,
    DEFAULT_CHANNEL_GROUP   VARCHAR,
    PLATFORM                VARCHAR(50),
    IS_ACTIVE_USER          BOOLEAN,
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL,
    DW_SOURCE_TABLE         VARCHAR,
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, BATCH_ORDERING_ID)
) COMMENT = 'GA 이벤트 팩트 소스 → FACT_GA_BEHAVIOR. ⚠️PK 복합 유일성 전량 미검증(GA-1)';

-- ============================================================================
-- GA4 5: GA4_IDENTITY  (신원 — Q1 접두사 분기)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_IDENTITY (
    USER_PSEUDO_ID      VARCHAR(200)    NOT NULL,   -- 세션 스파인
    GA_MEMBER_ID        VARCHAR(10),                 -- = user_id(CRM 회원번호) ⚠️VARCHAR 필수
    MEMBER_TYPE         VARCHAR(10),                 -- 파생: 'S%'→ONCE else FDRM
    MBER_NO             VARCHAR(10),                 -- ※비강제 FK→TM_MM_FDRM_MBER_INFO.MBER_NO(파생)
    ONCE_MBER_NO        VARCHAR(10),                 -- ※비강제 FK→TM_MM_ONCE_MBER_INFO.ONCE_MBER_NO(파생)
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (USER_PSEUDO_ID)
) COMMENT = 'GA 신원(Q1 구조확정). 접두사 분기: user_id S%→ONCE_MBER_NO / else→MBER_NO';


-- ============================================================================
-- [검증 쿼리] 26개 테이블 생성 확인
-- ============================================================================
SELECT
    CASE WHEN table_name LIKE 'GA4%' THEN 'GA4' ELSE 'CRM' END AS domain,
    table_name,
    comment
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'SILVER'
ORDER BY domain, table_name;
-- 기대값: CRM 21행 + GA4 5행 = 26행


/*
================================================================================
  부록 B. GA4 Silver 정제(INSERT) 참조 SQL
  (구 SILVER_GA4_bronze_parsing_20260702.sql 에서 이관 — 아카이브 처리)
--------------------------------------------------------------------------------
  변경점(레거시 대비):
   - CTAS(CREATE OR REPLACE TABLE AS) → INSERT INTO (위 DDL 구조·PK·타입·길이 유지)
   - 컬럼명 대문자 정렬 (DDL 일치)
   - 깨진 STEP 1 중복 쿼리 제거 · GA4_IDENTITY 접두사 분기(Q1 확정) 반영
   - DDL 에 없는 컬럼(video_*·link_domain 등)은 제외
  운영:
   - date-shard 다기간 시 FROM 절을 UNION ALL 또는 동적 스크립트로 교체
   - 원천 = GN_DW.BRONZE_GA4.EVENTS_YYYYMMDD (예시는 EVENTS_20260501)
   - 재적재 멱등: 대상 테이블 TRUNCATE 후 INSERT (또는 DW_BATCH_ID=dbt invocation_id 기준 삭제 후 재적재)

   [2026-07-10 실적재 검증 — 후속 정정]
   - 🟥 실적재 샤드 식별자는 **소문자** events_20260501 (따옴표 생성). 미인용 대문자 EVENTS_20260501 로는
     "does not exist" 오류 → 아래 B-1~B-5 FROM 절을 GN_DW.BRONZE_GA4."events_20260501" 로 수정 완료.
     동적 스크립트/UNION 전환 시에도 소문자·인용 유지, 테이블 발견은 ILIKE 'events_%'.
   - 샤드 1일만 적재(events_20260501, 287,025행). 전체기간 아님.
   - GA4_IDENTITY: user_id 채움률 4.2%(12,120/287,025·식별 1,290명). 구조·조인키(G-1) 유효하나
     회원단위 커버리지 낮음 → 활성 시 커버리지 DQ 노출 권장.
================================================================================

-- B-1. GA4_TRAFFIC_SOURCE
INSERT INTO GN_DW.SILVER.GA4_TRAFFIC_SOURCE
(UTM_SOURCE, UTM_MEDIUM, UTM_CAMPAIGN, UTM_CONTENT, UTM_TERM, SOURCE_MEDIUM,
 XCHAN_SOURCE, XCHAN_MEDIUM, XCHAN_CAMPAIGN, DEFAULT_CHANNEL_GROUP,
 TS_SOURCE, TS_MEDIUM, TS_CAMPAIGN, CTS_SOURCE, CTS_MEDIUM,
 DW_SOURCE_SYSTEM, DW_SOURCE_TABLE, DW_LOAD_TS, DW_UPDATE_TS, DW_BATCH_ID)
SELECT DISTINCT
    NULLIF(NULLIF(s:manual_campaign:source::STRING,'(not set)'),'(direct)'),
    NULLIF(NULLIF(NULLIF(s:manual_campaign:medium::STRING,'(not set)'),'(none)'),'(direct)'),
    NULLIF(s:manual_campaign:campaign_name::STRING,'(not set)'),
    NULLIF(s:manual_campaign:content::STRING,'(not set)'),
    NULLIF(s:manual_campaign:term::STRING,'(not set)'),
    CONCAT_WS(' / ',
        NULLIF(NULLIF(s:manual_campaign:source::STRING,'(not set)'),'(direct)'),
        NULLIF(NULLIF(NULLIF(s:manual_campaign:medium::STRING,'(not set)'),'(none)'),'(direct)')),
    s:cross_channel_campaign:source::STRING,
    s:cross_channel_campaign:medium::STRING,
    s:cross_channel_campaign:campaign_name::STRING,
    s:cross_channel_campaign:default_channel_group::STRING,
    NULLIF(traffic_source:source::STRING,'(not set)'),
    NULLIF(traffic_source:medium::STRING,'(not set)'),
    NULLIF(traffic_source:name::STRING,'(not set)'),
    collected_traffic_source:manual_source::STRING,
    collected_traffic_source:manual_medium::STRING,
    'GA4', 'BRONZE_GA4.EVENTS_20260501', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), NULL
FROM (
    SELECT session_traffic_source_last_click AS s, traffic_source, collected_traffic_source
    FROM GN_DW.BRONZE_GA4."events_20260501"
);

-- B-2. GA4_EVENT_DIM
INSERT INTO GN_DW.SILVER.GA4_EVENT_DIM
(EVENT_NAME, EVENT_CATEGORY, EVENT_LABEL, EVENT_ACTION,
 DW_SOURCE_SYSTEM, DW_SOURCE_TABLE, DW_LOAD_TS, DW_UPDATE_TS, DW_BATCH_ID)
SELECT DISTINCT EVENT_NAME, EVENT_CATEGORY, EVENT_LABEL, EVENT_ACTION,
    'GA4', 'BRONZE_GA4.EVENTS_20260501', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), NULL
FROM (
    SELECT e.event_name AS EVENT_NAME,
        MAX(IFF(p.value:key::STRING='event_category', p.value:value:string_value::STRING, NULL)) AS EVENT_CATEGORY,
        MAX(IFF(p.value:key::STRING='event_label',
            COALESCE(p.value:value:string_value::STRING, p.value:value:int_value::STRING), NULL)) AS EVENT_LABEL,
        MAX(IFF(p.value:key::STRING='event_action', p.value:value:string_value::STRING, NULL)) AS EVENT_ACTION
    FROM GN_DW.BRONZE_GA4."events_20260501" e, LATERAL FLATTEN(input => e.event_params) p
    GROUP BY e.event_name, e.event_timestamp, e.user_pseudo_id, e.batch_ordering_id
);

-- B-3. GA4_DEVICE
INSERT INTO GN_DW.SILVER.GA4_DEVICE
(DEVICE_TYPE, PLATFORM, DEVICE_CATEGORY, OS, BROWSER, LANGUAGE,
 DW_SOURCE_SYSTEM, DW_SOURCE_TABLE, DW_LOAD_TS, DW_UPDATE_TS, DW_BATCH_ID)
SELECT DISTINCT
    CASE WHEN platform IN ('ANDROID','IOS') THEN 'APP'
         WHEN device:category::STRING IN ('mobile','tablet') THEN 'M'
         ELSE 'PC' END,
    platform,
    device:category::STRING,
    device:operating_system::STRING,
    device:browser::STRING,
    device:language::STRING,
    'GA4', 'BRONZE_GA4.EVENTS_20260501', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), NULL
FROM GN_DW.BRONZE_GA4."events_20260501";

-- B-4. GA4_EVENT (메인 팩트 소스 — FLATTEN + param 승격)
INSERT INTO GN_DW.SILVER.GA4_EVENT
(USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, BATCH_ORDERING_ID, EVENT_DATE, EVENT_DT, EVENT_TS,
 USER_ID, GA_SESSION_ID, GA_SESSION_NUMBER, SESSION_ENGAGED, ENGAGEMENT_TIME_MSEC,
 PAGE_LOCATION, PAGE_TITLE, PAGE_REFERRER, EVENT_CATEGORY, EVENT_ACTION, EVENT_LABEL,
 PERCENT_SCROLLED, LINK_URL, LINK_TEXT, DEVICE_TYPE, DEVICE_CATEGORY, OS, GEO_COUNTRY, GEO_CITY,
 UTM_SOURCE, UTM_MEDIUM, UTM_CAMPAIGN, DEFAULT_CHANNEL_GROUP, PLATFORM, IS_ACTIVE_USER,
 DW_SOURCE_SYSTEM, DW_SOURCE_TABLE, DW_LOAD_TS, DW_UPDATE_TS, DW_BATCH_ID)
SELECT
    e.user_pseudo_id,
    e.event_timestamp,
    e.event_name,
    e.batch_ordering_id,
    e.event_date,
    TO_DATE(e.event_date,'YYYYMMDD'),
    TO_TIMESTAMP(e.event_timestamp/1000000),
    e.user_id,                                             -- CRM 회원번호(Q1) · VARCHAR 유지
    MAX(IFF(p.value:key::STRING='ga_session_id', p.value:value:int_value::NUMBER, NULL)),
    MAX(IFF(p.value:key::STRING='ga_session_number', p.value:value:int_value::NUMBER, NULL)),
    MAX(IFF(p.value:key::STRING='session_engaged',
        COALESCE(p.value:value:string_value::STRING, p.value:value:int_value::STRING), NULL)),
    MAX(IFF(p.value:key::STRING='engagement_time_msec', p.value:value:int_value::NUMBER, NULL)),
    MAX(IFF(p.value:key::STRING='page_location', p.value:value:string_value::STRING, NULL)),
    MAX(IFF(p.value:key::STRING='page_title', p.value:value:string_value::STRING, NULL)),
    MAX(IFF(p.value:key::STRING='page_referrer', p.value:value:string_value::STRING, NULL)),
    MAX(IFF(p.value:key::STRING='event_category', p.value:value:string_value::STRING, NULL)),
    MAX(IFF(p.value:key::STRING='event_action', p.value:value:string_value::STRING, NULL)),
    MAX(IFF(p.value:key::STRING='event_label',
        COALESCE(p.value:value:string_value::STRING, p.value:value:int_value::STRING), NULL)),
    MAX(IFF(p.value:key::STRING='percent_scrolled', p.value:value:int_value::NUMBER, NULL)),
    MAX(IFF(p.value:key::STRING='link_url', p.value:value:string_value::STRING, NULL)),
    MAX(IFF(p.value:key::STRING='link_text', p.value:value:string_value::STRING, NULL)),
    CASE WHEN e.platform IN ('ANDROID','IOS') THEN 'APP'
         WHEN e.device:category::STRING IN ('mobile','tablet') THEN 'M' ELSE 'PC' END,
    e.device:category::STRING,
    e.device:operating_system::STRING,
    e.geo:country::STRING,
    e.geo:city::STRING,
    NULLIF(NULLIF(e.session_traffic_source_last_click:manual_campaign:source::STRING,'(not set)'),'(direct)'),
    NULLIF(NULLIF(NULLIF(e.session_traffic_source_last_click:manual_campaign:medium::STRING,'(not set)'),'(none)'),'(direct)'),
    NULLIF(e.session_traffic_source_last_click:manual_campaign:campaign_name::STRING,'(not set)'),
    e.session_traffic_source_last_click:cross_channel_campaign:default_channel_group::STRING,
    e.platform,
    e.is_active_user,
    'GA4', 'BRONZE_GA4.EVENTS_20260501', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), NULL
FROM GN_DW.BRONZE_GA4."events_20260501" e, LATERAL FLATTEN(input => e.event_params) p
GROUP BY
    e.user_pseudo_id, e.event_timestamp, e.event_name, e.batch_ordering_id, e.event_date,
    e.user_id, e.is_active_user, e.platform, e.device, e.geo, e.session_traffic_source_last_click;

-- B-5. GA4_IDENTITY (Q1 접두사 분기 — 구조 확정)
INSERT INTO GN_DW.SILVER.GA4_IDENTITY
(USER_PSEUDO_ID, GA_MEMBER_ID, MEMBER_TYPE, MBER_NO, ONCE_MBER_NO,
 DW_SOURCE_SYSTEM, DW_SOURCE_TABLE, DW_LOAD_TS, DW_UPDATE_TS, DW_BATCH_ID)
SELECT
    user_pseudo_id,
    user_id,                                               -- = 회원번호 (VARCHAR 유지)
    CASE WHEN user_id ILIKE 'S%' THEN 'ONCE' ELSE 'FDRM' END,
    IFF(user_id ILIKE 'S%', NULL, user_id),                -- → TM_MM_FDRM_MBER_INFO.MBER_NO
    IFF(user_id ILIKE 'S%', user_id, NULL),                -- → TM_MM_ONCE_MBER_INFO.ONCE_MBER_NO
    'GA4', 'BRONZE_GA4.EVENTS_20260501', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), NULL
FROM GN_DW.BRONZE_GA4."events_20260501"
WHERE user_id IS NOT NULL
GROUP BY user_pseudo_id, user_id;
-- GA-7 브리지: 위 결과를 CRM 마스터에 LEFT JOIN (행매칭은 CRM 전량/겹치는 표본 후)
*/
