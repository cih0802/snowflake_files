-- GN_DW SILVER CRM 테이블 정의 DDL (STEP 1 스키마 + STEP 2 CRM 21테이블 CREATE TABLE). 적재/ALTER 쿼리는 09_SILVER_적재쿼리_20260714.sql 참조.
-- Co-authored with CoCo
/*
================================================================================
  GN_DW.SILVER — CRM 21테이블 정의 DDL (테이블 구조 정본)
  ★ 구 silver_stepbystep_ddl.sql 을 08(구조 DDL) + 09(적재 쿼리)로 분할 — 2026-07-14.
      - 08 (이 파일): STEP 1 스키마 생성 + STEP 2 CREATE OR REPLACE TABLE x21 (멱등).
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
  COMMENT = 'Silver 레이어 — Bronze(CRM·GA4) 정제 객체 (GOLD 입력용)';

USE SCHEMA GN_DW.SILVER;

-- ============================================================================
-- STEP 2 — CRM 21테이블 DDL (빈 테이블 생성, 정제 INSERT 는 STEP 3)
-- ============================================================================

-- CRM 1: CRM_MEMBER (회원 통합 — 정기 ∪ 일시)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER (
    MEMBER_DK           VARCHAR(10)     NOT NULL,
    MEMBER_TYPE         VARCHAR(10),
    MBER_DIV_CD         VARCHAR(3),
    MBER_DIV_NM         VARCHAR,
    CPR_DIV_CD          VARCHAR(3),
    SEX                 VARCHAR(2),
    MBER_STAT_CD        VARCHAR(3),
    MBER_STAT_NM        VARCHAR,
    CMPGN_CD            VARCHAR(20),
    ACT_DEPT_CD         VARCHAR(10),
    REGIST_DEPT_CD      VARCHAR(10),
    JOIN_PATH_CD        VARCHAR(3),
    HMPG_ID             VARCHAR(30),
    ENTRPS_NM           VARCHAR(200),
    EMAIL_RECPTN        VARCHAR,
    PSTMTR_RECPTN       VARCHAR,
    JOIN_DT             TIMESTAMP_NTZ,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (MEMBER_DK)
) COMMENT = '회원 통합(정기∪일시). Q6 UNION 스키마 정렬 잠정';

-- CRM 2: CRM_MEMBER_STATUS_HIST (회원 상태전이 · SCD2)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_STATUS_HIST (
    MBER_NO             VARCHAR(10)     NOT NULL,
    SER_NO              NUMBER(10,0)    NOT NULL,
    BF_STAT_CD          VARCHAR(3),
    BF_STAT_NM          VARCHAR,
    CHN_STAT_CD         VARCHAR(3),
    CHN_STAT_NM         VARCHAR,
    EFFECTIVE_FROM      TIMESTAMP_NTZ,
    EFFECTIVE_TO        TIMESTAMP_NTZ,
    IS_CURRENT          BOOLEAN,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (MBER_NO, SER_NO)
) COMMENT = '회원 상태전이 이력 (SCD2 range)';

-- CRM 3: CRM_MEMBER_DEV (개발약정)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_DEV (
    SPNSR_NO            VARCHAR(9)      NOT NULL,
    SPNSR_BSNS_NO       NUMBER(19,0)    NOT NULL,
    OCCRRNC_DE          VARCHAR(8)      NOT NULL,
    SER_NO              NUMBER(10,0)    NOT NULL,
    MBER_NO             VARCHAR(10),
    SPNSR_BSNS_ID       VARCHAR(20),
    SPNSR_AMT           NUMBER(19,0),
    DVLP_DIV_CD         VARCHAR(3),
    ACT_DEPT_CD         VARCHAR(10),
    ACMSLT_DEPT_CD      VARCHAR(10),
    CMPGN_CD            VARCHAR(20),
    SETLE_CD            VARCHAR(3),
    AREA_CD             VARCHAR(3),
    AREA_NM             VARCHAR,
    AGE                 NUMBER(10,0),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO)
) COMMENT = '개발약정 (Q13 스파인 — N:1 LEFT JOIN 안전). [S-5 G1] AREA_CD(CM018)·AGE = DIM_MEMBER REGION/AGE_BAND 스냅샷 소스';

-- CRM 4: CRM_MEMBER_AMT_CHANGE (증감)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_AMT_CHANGE (
    OCCRRNC_DE          VARCHAR(8)      NOT NULL,
    SER_NO              NUMBER(10,0)    NOT NULL,
    MBER_NO             VARCHAR(10),
    SPNSR_AMT           NUMBER(19,0),
    RDCAMT_YN           VARCHAR(1),
    ACMSLT_DEPT_CD      VARCHAR(10),
    CMPGN_CD            VARCHAR(20),
    AREA_CD             VARCHAR(3),
    AREA_NM             VARCHAR,
    AGE                 NUMBER(10,0),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (OCCRRNC_DE, SER_NO)
) COMMENT = '약정 증감(증액/감액). [S-5 G1] AREA_CD(CM018)·AGE = DIM_MEMBER REGION/AGE_BAND 스냅샷 소스';

-- CRM 5: CRM_MEMBER_DISCONTINUE (중단)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_DISCONTINUE (
    MBER_NO             VARCHAR(10)     NOT NULL,
    SPNSR_DSCNTC_DE     VARCHAR(8)      NOT NULL,
    SER_NO              NUMBER(10,0)    NOT NULL,
    DSCNTC_RSN_CD       VARCHAR(3),
    DSCNTC_RSN_NM       VARCHAR,
    DSCNTC_PATH         VARCHAR(1),
    REGIST_DEPT_CD      VARCHAR(10),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (MBER_NO, SPNSR_DSCNTC_DE, SER_NO)
) COMMENT = '후원중단';

-- CRM 6: CRM_MEMBER_RESPONSOR (재후원)
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

-- CRM 7: CRM_MEMBER_SPONSOR_BIZ (회원×후원사업)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_SPONSOR_BIZ (
    SPNSR_NO            VARCHAR(9)      NOT NULL,
    SPNSR_BSNS_NO       NUMBER(19,0)    NOT NULL,
    SPNSR_BSNS_ID       VARCHAR(20),
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

-- CRM 8: CRM_SPONSOR_RELATION (결연)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SPONSOR_RELATION (
    RELATNSP_KEY        NUMBER(10,0)    NOT NULL,
    SPNSR_NO            VARCHAR(9),
    SPNSR_BSNS_NO       NUMBER(19,0),
    SPNSR_BSNS_ID       VARCHAR(20),
    CHILD_CD            NUMBER(10,0),
    MBER_NO             VARCHAR(10),
    RELATNSP_STRT_DE    DATE,
    RELATNSP_DSCNTC_DE  DATE,
    RELATNSP_DSCNTC_YN  VARCHAR(1),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (RELATNSP_KEY)
) COMMENT = '결연(아동). Q15 SPNSR_BSNS_ID 크로스워크 파생';

-- CRM 9: CRM_PAYMENT_BILLING (납입·청구 — 회비 ∪ 기부금)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_PAYMENT_BILLING (
    PAY_KEY             VARCHAR         NOT NULL,
    PAYMENT_TYPE        VARCHAR,
    MBER_NO             VARCHAR(10),
    SPNSR_BSNS_ID       VARCHAR(20),
    RELATNSP_KEY        NUMBER(10,0),
    MBRFEE_MT           VARCHAR(6),
    MBRFEE_SQNC         NUMBER(3,0),
    RQEST_AMT           NUMBER(19,0),
    RQEST_DE            DATE,
    PAY_AMT             NUMBER(10,0),
    PAY_DE              DATE,
    PAY_STAT_CD         VARCHAR(3),
    SETLE_CD            VARCHAR(3),
    GFT_DIV_CD          VARCHAR(3),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (PAY_KEY)
) COMMENT = '납입/청구(회비∪기부금). Q14 납입 dedup·청구 행기준';

-- CRM 10: CRM_PAYMENT_METHOD (결제수단)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_PAYMENT_METHOD (
    SETLE_KEY           NUMBER(10,0)    NOT NULL,
    MBER_NO             VARCHAR(10),
    SETLE_CD            VARCHAR(3),
    SETLE_NM            VARCHAR,
    CARD_DIV_CD         VARCHAR(3),
    FNLT_CD             VARCHAR(10),
    WTDRW_STRT_DE       DATE,
    SETLE_STAT_CD       VARCHAR(3),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SETLE_KEY)
) COMMENT = '결제수단 (현재상태)';

-- CRM 11: CRM_CAMPAIGN (캠페인 마스터)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CAMPAIGN (
    CMPGN_CD            VARCHAR(20)     NOT NULL,
    CMPGN_NM            VARCHAR(200),
    UPPER_CMPGN_CD      VARCHAR(20),
    UPPER_CMPGN_YN      VARCHAR(1),
    BRND_ID             VARCHAR(30),
    BRND_NM             VARCHAR(200),
    PR_MTH_CD           VARCHAR(3),
    SPNSR_BSNS_ID       VARCHAR(100),
    CMPGN_CTGR_CD       NUMBER(10,0),
    CMPGN_TYPE1_BSN     NUMBER(10,0),
    CMPGN_TYPE2_BSN     NUMBER(10,0),
    MKTG_CMPGN_NM       NUMBER(10,0),
    MK_CMPGN_NM         VARCHAR(200),
    CMPGN_STRT_DE       VARCHAR(8),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (CMPGN_CD)
) COMMENT = '캠페인 마스터. Q2/Q3 코드 라벨·Q16 조인키';

-- CRM 12: CRM_SPONSORSHIP (후원사업 마스터)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SPONSORSHIP (
    SPNSR_BSNS_ID       VARCHAR(20)     NOT NULL,
    SPNSR_BSNS_NM       VARCHAR(50),
    SPNSR_BSNS_ABRV_CD  VARCHAR(3),
    SPNSR_DIV_CD        VARCHAR(3),
    DNTN_TY_CD          VARCHAR(3),
    CPR_DIV_CD          VARCHAR(3),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SPNSR_BSNS_ID)
) COMMENT = '후원사업 마스터 (실측 50개)';

-- CRM 13: CRM_ORG (조직 마스터)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_ORG (
    DEPT_ID                 VARCHAR(20)     NOT NULL,
    DEPT_NM                 VARCHAR(50),
    UPPER_DEPT_ID           VARCHAR(20),
    ACMSLT_UPPER_DEPT_ID    VARCHAR(20),
    ACMSLT_DEPT_YN          VARCHAR(1),
    STATS_DEPT_LVL          NUMBER(3,0),
    USE_YN                  VARCHAR(1),
    SORT_ORDR               NUMBER(10,0),
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL,
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (DEPT_ID)
) COMMENT = '조직 마스터. 실적팀=ACMSLT_UPPER_DEPT_ID 재귀 LVL5. USE_YN·SORT_ORDR 원천 확인';

-- CRM 14: CRM_DEV_TARGET (개발목표)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_DEV_TARGET (
    STDYY               VARCHAR(4)      NOT NULL,
    STDR_MT             VARCHAR(6)      NOT NULL,
    MBER_DVLP_DIV_CD    VARCHAR(1)      NOT NULL,
    DEPT_ID             VARCHAR(20)     NOT NULL,
    GOAL_CNT            NUMBER(10,0),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (STDYY, STDR_MT, MBER_DVLP_DIV_CD, DEPT_ID)
) COMMENT = '회원개발 목표 (월×조직×개발구분)';

-- CRM 15: CRM_SEND_REQUEST (발송요청)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_REQUEST (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL,
    SEND_CHANNEL        VARCHAR,
    SNDNG_TY_CD         VARCHAR(3),
    SEND_GBN_TOP        VARCHAR(255),
    SEND_GBN_TOP_NM     VARCHAR(255),
    SEND_GBN_MID        VARCHAR(255),
    SEND_GBN_MID_NM     VARCHAR(255),
    SEND_GBN_BOT        VARCHAR(255),
    SEND_GBN_BOT_NM     VARCHAR(255),
    TIT                 VARCHAR(100),
    SNDNG_STDR_DE       TIMESTAMP_NTZ,
    REQ_SEQ_NO          NUMBER(19,0),
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SNDNG_KEY)
) COMMENT = '발송요청 마스터. Q5 발송키 이원화. [S-5 G2] SEND_GBN_TOP/MID/BOT(+_NM)=DIM_SERVICE 대/중/소(SND 채널만, 타 채널 NULL)';

-- CRM 16: CRM_SEND_MEMBER (발송×회원)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_MEMBER (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL,
    SNDNG_DTL_KEY       NUMBER(10,0)    NOT NULL,
    MBER_NO             VARCHAR(10),
    SNDNG_DE            TIMESTAMP_NTZ,
    SNDNG_RST_CD        VARCHAR(3),
    SEND_CHANNEL        VARCHAR,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SNDNG_KEY, SNDNG_DTL_KEY)
) COMMENT = '발송×회원 상세';

-- CRM 17: CRM_SEND_RESULT (발송×채널 집계)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_RESULT (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL,
    SEND_CHANNEL        VARCHAR         NOT NULL,
    SNDNG_CNT           NUMBER(10,0),
    SUCCES_CNT          NUMBER(10,0),
    FAILR_CNT           NUMBER(10,0),
    TOT_CLICK_CNT       NUMBER,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (SNDNG_KEY, SEND_CHANNEL)
) COMMENT = '발송×채널 집계';

-- CRM 18: CRM_EVENT (행사 마스터)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_EVENT (
    EVENT_KEY           VARCHAR         NOT NULL,
    EVENT_SOURCE        VARCHAR,
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

-- CRM 19: CRM_EVENT_PARTICIPATION (행사×참여자)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_EVENT_PARTICIPATION (
    EVENT_KEY           VARCHAR         NOT NULL,
    MBER_NO             VARCHAR(10)     NOT NULL,
    PARTCPT_SEQ         NUMBER(10,0)    NOT NULL,
    PARTCPT_STAT_CD     VARCHAR(3),
    PARTCPT_CHNNL_CD    VARCHAR(3),
    PARTCPT_PATH_CD     VARCHAR(3),
    PRZWIN_CD           NUMBER(10,0),
    RCPMNY_AMT          NUMBER(19,0),
    PARTCPT_DT          TIMESTAMP_NTZ,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (EVENT_KEY, MBER_NO, PARTCPT_SEQ)
) COMMENT = '행사×참여자';

-- CRM 20: CRM_RELATION_ACTIVITY (결연활동 · EHGT 제외)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_RELATION_ACTIVITY (
    ACTIVITY_KEY        VARCHAR         NOT NULL,
    ACTIVITY_TYPE       VARCHAR,
    RELATNSP_KEY        NUMBER(10,0),
    MNG_NO              VARCHAR(7),
    GFTMNEY             NUMBER(10,0),
    LETTER_DIV_CD       NUMBER(10,0),
    RCEPT_DE            DATE,
    SNDNG_DE            DATE,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (ACTIVITY_KEY)
) COMMENT = '결연활동(서신∪선물금). EHGT 제외';

-- CRM 21: CRM_CODE (코드 사전)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CODE (
    CD_ID               VARCHAR(20)     NOT NULL,
    DTL_CD_ID           VARCHAR(50)     NOT NULL,
    DTL_CD_NM           VARCHAR(100),
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
-- STEP 4 — ERP (트랙 C, 2차) : BRONZE_ERP.BDGT_ACMSLT_LEDGER → SILVER 3객체
--   근거 : 05_SILVER_작업계획_ERP전용 · 11_SILVER_블로커_triage_Q1-Q16
--   실측(2026-07-14) : 원장 2,041행 = 지출1,875 + 수입165 + TOTAL 1(사전집계 요약행 → 제외).
--                      full-hierarchy DISTINCT = 행수 → 각 행이 유일 예산과목(세세목).
--   원장 구조 : 차원 10 + 총액 4 + 월별 48(편성YEAR_BDGT/추경CHN/조정ADJ/집행EXEC × 12개월).
--   설계 : ITEM(마스터) + BUDGET(월 long 언피벗) + BIZ_TARGET(원천부재 → 스키마-only).
--   키 : BUDGET_ITEM_DK = MD5(연도|수입지출|예산단위|장|관|항|목|목세|세세목|재원) — DIM/FACT 동일식.
-- ============================================================================

-- ERP 1: ERP_BUDGET_ITEM (예산과목 마스터 → DIM_BUDGET_ITEM)
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_BUDGET_ITEM (
    BUDGET_ITEM_DK      VARCHAR         NOT NULL,   -- MD5 해시 대체키
    BUDGET_YEAR         NUMBER(4,0),
    INCOME_EXPENSE_DIV  VARCHAR,                    -- 수입/지출
    BUDGET_UNIT_NM      VARCHAR,                    -- 예산단위(=조직명, 코드 없음)
    JANG_NM             VARCHAR,                    -- 예산과목 1단계 장
    KWAN_NM             VARCHAR,                    -- 2단계 관
    HANG_NM             VARCHAR,                    -- 3단계 항
    MOK_NM              VARCHAR,                    -- 4단계 목
    DTL_ITEM_NM         VARCHAR,                    -- 5단계 세목
    SUBDTL_ITEM_NM      VARCHAR,                    -- 6단계 세세목
    FUND_SOURCE_NM      VARCHAR,                    -- 재원
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (BUDGET_ITEM_DK)
) COMMENT = '예산과목 마스터(예산단위×장/관/항/목/세목/세세목×재원). TOTAL 요약행 제외. → DIM_BUDGET_ITEM';

-- ERP 2: ERP_BUDGET (월별 편성/추경/조정/집행 long → FBD)
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_BUDGET (
    BUDGET_ITEM_DK      VARCHAR         NOT NULL,   -- → ERP_BUDGET_ITEM FK
    BUDGET_YEAR         NUMBER(4,0),
    MONTH_NO            NUMBER(2,0)     NOT NULL,   -- 1~12
    MONTH_KEY           VARCHAR(6),                 -- 'YYYYMM'
    YEAR_BUDGET_AMT     NUMBER(38,0),               -- 편성(연예산) 원단위
    CHN_BUDGET_AMT      NUMBER(38,0),               -- 추경 원단위
    ADJ_BUDGET_AMT      NUMBER(38,0),               -- 조정 원단위
    EXEC_AMT            NUMBER(38,0),               -- 집행 원단위
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (BUDGET_ITEM_DK, MONTH_NO)
) COMMENT = '예산 편성/추경/조정/집행 월 grain(wide→long). 금액 원단위. → FBD(편성/집행). 모금성비용·광고비는 AGENCY 보강(E-1)';

-- ERP 3: ERP_BIZ_TARGET (사업목표 → FTG-B) — ⛔ 원천 부재(E-6): 스키마-only, 적재 보류
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_BIZ_TARGET (
    BIZ_TARGET_DK       VARCHAR         NOT NULL,
    TARGET_YEAR         NUMBER(4,0),
    MONTH_NO            NUMBER(2,0),
    MONTH_KEY           VARCHAR(6),
    ORG_NM              VARCHAR,                    -- 조직(이름, 코드 없음)
    SPONSOR_BIZ_NM      VARCHAR,                    -- 후원사업
    CAMPAIGN_NM         VARCHAR,                    -- 캠페인(연결키 부재 Q10 — nullable)
    TARGET_AMT          NUMBER(38,0),               -- 연/추경 (누계)목표
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (BIZ_TARGET_DK)
) COMMENT = 'FTG-B 사업목표. ⛔원천부재(E-6): 원장≠사업목표 → 스키마-only, 적재 보류(현업 사업계획 원천 대기)';

-- ============================================================================
-- STEP 5 — AGENCY (트랙 D, 3차) : BRONZE_AGENCY 3테이블 → SILVER 2객체 (AGENCY_COST는 리뷰 후 제거→GOLD)
--   근거 : 06_SILVER_작업계획_AGENCY전용 · 11_SILVER_블로커_triage
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
    CREATIVE_DK         VARCHAR         NOT NULL,   -- MD5(소스+매체+소재+유형+CM위치+초수)
    SOURCE_SYSTEM       VARCHAR         NOT NULL,   -- DIGITAL/REBROADCAST/VIDEO
    MEDIA_CHANNEL_NM    VARCHAR,                    -- 매체/채널
    CREATIVE_NM         VARCHAR,                    -- 소재(DGT.MATR/REBRDC.BRDC_NM/VIDEO.MATR_NM)
    CREATIVE_TYPE_NM    VARCHAR,                    -- 소재유형/RT유형/캠페인유형
    CM_AREA_NM          VARCHAR,                    -- CM위치(VIDEO)
    AD_SEC_NM           VARCHAR,                    -- 초수(VIDEO)
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (CREATIVE_DK)
) COMMENT = '광고 소재/매체 차원(3소스 UNION distinct). → DIM_AD_CREATIVE. 소스별 필드 산재→NULL 허용';

-- AGENCY 2: AGENCY_AD_PERFORMANCE (3소스 정제→UNION 광고성과 → FAD)
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_PERFORMANCE (
    SOURCE_SYSTEM       VARCHAR         NOT NULL,   -- DIGITAL/REBROADCAST/VIDEO(②⑤)
    AD_DATE             DATE,
    AD_YEAR             NUMBER(4,0),
    AD_MONTH            NUMBER(2,0),
    CAMPAIGN_NM         VARCHAR,                    -- DGT.CMPGN_NM/VIDEO.MKT_CMPGN_NM/REBRDC=NULL(⑤)
    UPPER_CAMPAIGN_NM   VARCHAR,
    MEDIA_CHANNEL_NM    VARCHAR,
    DEVICE_NM           VARCHAR,                    -- DGT만
    CREATIVE_NM         VARCHAR,
    PROGRAM_NM          VARCHAR,                    -- REBRDC.BRDC_NM/VIDEO.SCHDL_NM
    IMPRESSION_CNT      NUMBER(38,4),               -- 노출: DGT만(④)
    CLICK_CNT           NUMBER(38,4),               -- 클릭: DGT만(④)
    CONV_MEMBER_CNT     NUMBER(38,4),               -- 전환/개발 명(③)
    CONV_UNIT_CNT       NUMBER(38,4),               -- 전환 VU/건(③, 비건수 주의)
    INBOUND_CALL_CNT    NUMBER(38,4),               -- REBRDC(TRY_TO_NUMBER)+VIDEO(②)
    CONV_CALL_CNT       NUMBER(38,4),               -- VIDEO 전환콜(별개 measure)
    AD_CNT              NUMBER(38,4),               -- REBRDC/VIDEO 광고횟수
    AD_COST             NUMBER(38,4),               -- 광고비(소스별 컬럼 상이)
    COST_TYPE           VARCHAR,                    -- GA/편성(REBRDC)/집행(VIDEO)
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR
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
    UTM_SOURCE              VARCHAR,                 -- 센티넬 NULLIF((not set)/(direct))
    UTM_MEDIUM              VARCHAR,                 -- 센티넬 NULLIF((not set)/(none)/(direct))
    UTM_CAMPAIGN            VARCHAR,
    UTM_CONTENT             VARCHAR,
    UTM_TERM                VARCHAR,
    SOURCE_MEDIUM           VARCHAR,                 -- 파생 source / medium
    XCHAN_SOURCE            VARCHAR,                 -- cross_channel_campaign(동일 last-click variant)
    XCHAN_MEDIUM            VARCHAR,
    XCHAN_CAMPAIGN          VARCHAR,
    DEFAULT_CHANNEL_GROUP   VARCHAR,                 -- ⚠️정규화 금지(정상 라벨)
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL,
    DW_SOURCE_TABLE         VARCHAR,
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS            TIMESTAMP_NTZ,
    DW_BATCH_ID             VARCHAR
) COMMENT = 'GA 트래픽소스(session/last-click 한정). 그레인=source/medium/campaign/content/term(+xchan/channel_group) DISTINCT → DIM_GA_SOURCE. first-touch·collected는 grain 상이로 제외(GA4-검토)';

-- ----------------------------------------------------------------------------
-- GA4 2: GA4_EVENT_DIM  (DISTINCT 그레인 — 키 NULL 가능 → PK 없음)
--   ⚠️ GA-2(카디널리티 리스크): event_label 혼합타입(문자+숫자)이 고카디널리티면 전기간 확장 시
--      본 차원이 사실상 팩트化(1일 실측 event_name 49개 대비 3,633행). GOLD DIM_GA_EVENT 는
--      event_name(+안정 category/action) 키로 conform, 변동성 label 은 팩트측(GA4_EVENT.EVENT_LABEL) 유지 권고.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_EVENT_DIM (
    EVENT_NAME          VARCHAR(200)    NOT NULL,
    EVENT_CATEGORY      VARCHAR,
    EVENT_LABEL         VARCHAR,                     -- ⚠️혼합타입 → COALESCE(string,int)
    EVENT_ACTION        VARCHAR,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR
) COMMENT = 'GA 이벤트분류. 그레인=event_name×category×label×action DISTINCT (PK 없음) → DIM_GA_EVENT';

-- ----------------------------------------------------------------------------
-- GA4 3: GA4_DEVICE  (DISTINCT 그레인 — 키 NULL 가능 → PK 없음)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_DEVICE (
    DEVICE_TYPE         VARCHAR(10)     NOT NULL,   -- PC/M/APP(파생) → DIM_DEVICE 핵심
    PLATFORM            VARCHAR(50),                 -- WEB/ANDROID/IOS (O2 conform 대기)
    DEVICE_CATEGORY     VARCHAR,
    OS                  VARCHAR,
    BROWSER             VARCHAR,
    LANGUAGE            VARCHAR,
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR
) COMMENT = 'GA 디바이스. 그레인=device_type×platform×category DISTINCT (PK 없음) → DIM_DEVICE(GA분)';

-- ----------------------------------------------------------------------------
-- GA4 4: GA4_EVENT  (이벤트 팩트 소스 — 복합 PK)
--   ⚠️ GA-1: 원천 샤드에 복합키 중복군 존재(1일 실측 16,187군) → 적재는 PK GROUP BY 로 dedup.
--   ⚠️ 07 §5-A session-fill: 원본 USER_ID 불변 보존 + 파생 USER_ID_FILLED/ID_RESOLUTION 신설.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_EVENT (
    USER_PSEUDO_ID          VARCHAR(200)    NOT NULL,   -- 세션 스파인
    EVENT_TIMESTAMP         NUMBER          NOT NULL,   -- UTC microsec(원본, 불변)
    EVENT_NAME              VARCHAR(200)    NOT NULL,
    BATCH_ORDERING_ID       NUMBER          NOT NULL,
    EVENT_DATE              VARCHAR(8),                  -- 원본 YYYYMMDD(date-shard)
    EVENT_DT                DATE,                        -- 파생: TO_DATE(event_date,'YYYYMMDD')
    EVENT_TS                TIMESTAMP_NTZ,               -- 파생: TO_TIMESTAMP(event_timestamp/1e6)
    USER_ID                 VARCHAR(10),                 -- CRM 회원번호(Q1) ⚠️VARCHAR·원본 불변
    GA_SESSION_ID           NUMBER,                      -- event_params 승격
    GA_SESSION_NUMBER       NUMBER,
    GA_SESSION_KEY          VARCHAR,                     -- 파생: user_pseudo_id∥'-'∥ga_session_id (세션 자연키)
    USER_ID_FILLED          VARCHAR(10),                 -- 파생: 세션 전파 회원번호(07 §5-A) — 회원 귀속용
    ID_RESOLUTION           VARCHAR(20),                 -- DIRECT/SESSION_FILL/UNRESOLVED/CONFLICT
    SESSION_ENGAGED         VARCHAR(5),                  -- ⚠️혼합타입 → COALESCE
    ENGAGEMENT_TIME_MSEC    NUMBER,                      -- 비가산 raw(O1)
    PAGE_LOCATION           VARCHAR,
    PAGE_TITLE              VARCHAR,
    PAGE_REFERRER           VARCHAR,
    EVENT_CATEGORY          VARCHAR,
    EVENT_ACTION            VARCHAR,
    EVENT_LABEL             VARCHAR,                     -- ⚠️혼합타입 → COALESCE
    PERCENT_SCROLLED        NUMBER,
    LINK_URL                VARCHAR,
    LINK_TEXT               VARCHAR,
    DEVICE_TYPE             VARCHAR(10),                 -- 파생 PC/M/APP
    DEVICE_CATEGORY         VARCHAR,
    OS                      VARCHAR,
    GEO_COUNTRY             VARCHAR,
    GEO_CITY                VARCHAR,
    UTM_SOURCE              VARCHAR,                     -- 센티넬 NULLIF
    UTM_MEDIUM              VARCHAR,
    UTM_CAMPAIGN            VARCHAR,
    DEFAULT_CHANNEL_GROUP   VARCHAR,
    PLATFORM                VARCHAR(50),
    IS_ACTIVE_USER          BOOLEAN,
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL,
    DW_SOURCE_TABLE         VARCHAR,
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS            TIMESTAMP_NTZ,
    DW_BATCH_ID             VARCHAR,
    PRIMARY KEY (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, BATCH_ORDERING_ID)
) COMMENT = 'GA 이벤트 팩트 소스 → FACT_GA_BEHAVIOR. 비가산(engagement_time_msec 등)=raw 적재(O1). 원천 PK 중복은 적재 GROUP BY dedup(GA-1)';

-- ----------------------------------------------------------------------------
-- GA4 5: GA4_IDENTITY  (신원 — Q1 접두사 분기, 세션 채움 반영)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_IDENTITY (
    USER_PSEUDO_ID      VARCHAR(200)    NOT NULL,   -- 세션 스파인
    GA_MEMBER_ID        VARCHAR(10),                 -- = user_id_filled(세션 채움 후 회원번호) ⚠️VARCHAR
    MEMBER_TYPE         VARCHAR(10),                 -- 파생: 'S%'→ONCE else FDRM
    MBER_NO             VARCHAR(10),                 -- ※비강제 FK→TM_MM_FDRM_MBER_INFO.MBER_NO(파생)
    ONCE_MBER_NO        VARCHAR(10),                 -- ※비강제 FK→TM_MM_ONCE_MBER_INFO.ONCE_MBER_NO(파생)
    ID_RESOLUTION       VARCHAR(20),                 -- DIRECT/SESSION_FILL (신뢰도 노출)
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
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
    USER_PSEUDO_ID      VARCHAR(200)    NOT NULL,   -- GA 세션 스파인 (PK)
    GA_MEMBER_ID        VARCHAR(10),                 -- GA측 회원번호(=user_id_filled)
    MEMBER_TYPE         VARCHAR(10),                 -- ONCE(S%)/FDRM
    MEMBER_DK           VARCHAR(10),                 -- 매칭된 CRM 불변회원키(미매칭 NULL). ※비강제 FK→CRM_MEMBER.MEMBER_DK
    HOMEPAGE_ID         VARCHAR,                     -- 매칭 CRM 회원의 HMPG_ID(미매칭 NULL)
    ID_RESOLUTION       VARCHAR(20),                 -- GA측 신뢰도 passthrough: DIRECT/SESSION_FILL
    MATCH_METHOD        VARCHAR(30),                 -- MEMBER_ID_EXACT / UNMATCHED
    MATCH_CONFIDENCE    VARCHAR(10),                 -- HIGH(exact+DIRECT) / MEDIUM(exact+SESSION_FILL) / NONE(미매칭)
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (USER_PSEUDO_ID)
) COMMENT = 'S-7 신원 브리지(교차소스 유일예외). GA4_IDENTITY ↔ CRM_MEMBER 자연키 해소 + MATCH_METHOD/CONFIDENCE. SK없음(GOLD 소관). CHILD_CODE 제외(fan-out). 미매칭 보존';

-- STEP 7 (DDL) 완료 — 신원 브리지 1객체. 적재는 09 STEP 7 참조.
