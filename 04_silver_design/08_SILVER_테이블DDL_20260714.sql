-- ============================================================================
-- GN_DW.SILVER 테이블 DDL — 구조 정본(타입 · PK · COMMENT)
--   · dbt SILVER 모델과 1:1(구조 = 이 파일 · 데이터 = dbt). 적재 쿼리 = 09_SILVER_적재쿼리.
--   · 실행 = GN_DW_ADMIN · 새 환경은 이 파일 전체 실행 → dbt build.
--   · 🔴 재실행하면 데이터가 비워진다. 증분 모델은 재실행 뒤 반드시 백필한다
--       GA4 = build --select BIGQUERY_BASIC+ --vars '{"bigquery_dt_ranges": [["2024-01-01", "9999-12-31"]]}'
--       그 밖 = build --select <모델>+ --full-refresh
--   · 설계근거·실측 이력 = 08_SILVER_DDL_설계이력_부록.md · 이슈 원장 = 20_issue/00_INDEX_이슈원장.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE DATABASE GN_DW;
CREATE SCHEMA IF NOT EXISTS GN_DW.SILVER
    WITH MANAGED ACCESS
    COMMENT = 'Silver 레이어 — Bronze(CRM·BIGQUERY·ERP·AGENCY) 정제/변환 객체 (GOLD 입력용)';
USE SCHEMA GN_DW.SILVER;

-- ============================================================================
-- CRM
-- ============================================================================

-- CRM_MEMBER — 회원 통합 마스터 (정기∪일시)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER (
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키 (PK, 조인용)',
    MEMBER_TYPE         VARCHAR(10)     COMMENT '회원구분 파생 (정기=FDRM / 일시=ONCE)',
    MBER_DIV_CD         VARCHAR(3)      COMMENT '회원구분코드 (MM018: 개인/기업/단체)',
    MBER_DIV_NM         VARCHAR         COMMENT '회원구분명 (코드 라벨)',
    CPR_DIV_CD          VARCHAR(3)      COMMENT '법인구분코드',
    SEX                     VARCHAR         COMMENT '성별 원천코드 raw. 코드id:CM013',
    SEX_NM                  VARCHAR         COMMENT '성별 원천 라벨. 코드id:CM013',
    MBER_STAT_CD        VARCHAR(3)      COMMENT '회원상태 원천코드 raw (#132). 코드id:MM010',
    MBER_STAT_NM        VARCHAR         COMMENT '회원상태명 (코드 라벨)',
    CMPGN_CD            VARCHAR(20)     COMMENT '가입 캠페인코드 (→CRM_CAMPAIGN)',
    ACT_DEPT_CD         VARCHAR(10)     COMMENT '활동부서코드 (→CRM_ORG)',
    REGIST_DEPT_CD      VARCHAR(10)     COMMENT '등록부서코드 (→CRM_ORG)',
    JOIN_PATH_CD        VARCHAR(3)      COMMENT '가입경로코드 (MM014)',
    HMPG_ID             VARCHAR(30)     COMMENT '홈페이지/앱 ID',
    ENTRPS_NM           VARCHAR(200)    COMMENT '기업/단체명 (법인회원)',
    EMAIL_RECPTN        VARCHAR         COMMENT '이메일 수신동의 여부',
    PSTMTR_RECPTN       VARCHAR         COMMENT '우편물 수신동의 여부',
    FRST_REGIST_DT      TIMESTAMP_NTZ   COMMENT '최초등록일시(가입일시)',
    EMAIL_STAT_CD           VARCHAR         COMMENT 'EMAIL_STAT_CD. 코드id:MM009. [사유:원천 부재]',
    ETC_CTTPC_REL_CD        VARCHAR         COMMENT '기타연락처 관계 코드 raw (정본 MM008). 코드id:MM008.',
    ETC_CTTPC_STAT_CD       VARCHAR         COMMENT 'ETC_CTTPC_STAT_CD. 코드id:MM008.',
    ETC_TSTM_DIV_CD         VARCHAR         COMMENT 'ETC_TSTM_DIV_CD. 코드id:MS026.',
    MOBLPHON_STAT_CD        VARCHAR         COMMENT 'MOBLPHON_STAT_CD. 코드id:MM008.',
    REL_CD                  VARCHAR         COMMENT '관계 코드 raw (정본 CM009). ONCE 전용. 코드id:CM009.',
    RELATNSP_DIV_CD         VARCHAR         COMMENT 'RELATNSP_DIV_CD. 코드id:MM019.',
    SLRCLD_LRR_CD           VARCHAR         COMMENT '양력음력 코드 raw(생일 기준 · CM029 · 1=양력 2=음력 3=불명확 · 0 은 사전에 없음). 코드id:CM029.',
    TSTM_DIV_CD             VARCHAR         COMMENT 'TSTM_DIV_CD. 코드id:MS026.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    CHRCTR_RECPTN_YN    VARCHAR(1)      COMMENT '문자수신여부 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_INFO · BRONZE_CRM.TM_MM_ONCE_MBER_INFO]',
    SPECL_MNG_CD1       VARCHAR(100)    COMMENT '특별관리코드1 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_INFO · BRONZE_CRM.TM_MM_ONCE_MBER_INFO]',
    FDRM_MBER_TRNSFER_FG BOOLEAN         COMMENT '정기회원이관유무 [원천: BRONZE_CRM.TM_MM_ONCE_MBER_INFO]',
    SPECL_MNG_CD2       VARCHAR(100)    COMMENT '특별관리코드2(MM012 · 특별관리코드1 과 같은 코드그룹) [원천: BRONZE_CRM.TM_MM_FDRM_MBER_INFO · BRONZE_CRM.TM_MM_ONCE_MBER_INFO]',
    PRIMARY KEY (MEMBER_DK)
) COMMENT = '회원 통합 마스터 (정기∪일시). [Grain: MBER_NO (1행=1회원)]. [주의: 정기회원과 일시회원 통합]. [원천: CRM → BRONZE_CRM.TM_MM_MBER_MNG].';

-- CRM_MEMBER_STATUS_HIST — 회원 상태전이 이력 (SCD2)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_STATUS_HIST (
    MBER_NO             VARCHAR(10)     NOT NULL COMMENT '회원번호 (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '상태전이 일련번호 (PK)',
    BF_STAT_CD          VARCHAR(3)      COMMENT '변경 전 상태코드',
    BF_STAT_NM          VARCHAR         COMMENT '변경 전 상태명 (코드 라벨)',
    CHN_STAT_CD         VARCHAR(3)      COMMENT '변경 후 상태코드',
    CHN_STAT_NM         VARCHAR         COMMENT '변경 후 상태명 (코드 라벨)',
    EFFECTIVE_FROM      TIMESTAMP_NTZ   COMMENT 'SCD2 유효시작 시각.',
    EFFECTIVE_TO        TIMESTAMP_NTZ   COMMENT 'SCD2 유효종료 시각.',
    IS_CURRENT          BOOLEAN         COMMENT '현재행 여부',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (MBER_NO, SER_NO)
) COMMENT = '회원 상태전이 이력 (SCD2). [Grain: MBER_NO × HIST_SN (1행=1상태버전)]. [주의: 상태변경 시작~종료일 구간 이력 관리]. [원천: CRM → BRONZE_CRM.TH_MM_MBER_STAT_HIST].';

-- CRM_MEMBER_DEV — 개발약정 이력 (신규/증액/재후원/중단)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_DEV (
    SPNSR_NO            VARCHAR(9)      NOT NULL COMMENT '후원번호 (PK)',
    SPNSR_BSNS_NO       NUMBER(19,0)    NOT NULL COMMENT '후원사업번호 (PK)',
    OCCRRNC_DE          VARCHAR(8)      NOT NULL COMMENT '발생일자 YYYYMMDD (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '일련번호 (PK)',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    SPNSR_BSNS_ID       VARCHAR(20)     COMMENT '후원사업ID (→CRM_SPONSORSHIP)',
    SPNSR_AMT           NUMBER(19,0)    COMMENT '약정 후원금액 (원단위)',
    DVLP_DIV_CD         VARCHAR(3)      COMMENT 'DVLP_DIV_CD. 코드id:MM015.',
    DVLP_DIV_NM         VARCHAR         COMMENT '개발구분명. 코드id:MM015.',
    ACT_DEPT_CD         VARCHAR(10)     COMMENT '활동부서코드 (→CRM_ORG)',
    ACMSLT_DEPT_CD      VARCHAR(10)     COMMENT '실적부서코드 (→CRM_ORG)',
    CMPGN_CD            VARCHAR(20)     COMMENT '캠페인코드 (→CRM_CAMPAIGN)',
    SETLE_CD            VARCHAR(3)      COMMENT '결제수단코드',
    AREA_CD             VARCHAR(3)      COMMENT '지역코드 (CM018)',
    AREA_NM             VARCHAR         COMMENT '지역명 (코드 라벨)',
    AGE                 NUMBER(10,0)    COMMENT '연령대 코드(CM014) raw — 1=10대미만·2=10대·3=20대·4=30대·5=40대·6=50대·7=60대·8=70대·9=70대이상·10=단체·11=기업·12=기타. 🔴 연수(나이)가 아니다 ⇒ 평균·합계·구간비교 금지(라벨은 CRM_CODE CD_ID=CM014 조인).',
    CANCL_RDCAMT_RSN_CD     VARCHAR         COMMENT '취소·감액사유 코드 raw (정본 MM002). 코드id:MM002.',
    MBER_DIV_CD             VARCHAR         COMMENT '회원구분 원천코드 raw. 코드id:MM018',
    SEX                     VARCHAR         COMMENT '성별 원천코드 raw. 코드id:CM013',
    SPNSR_AMT_CD            VARCHAR         COMMENT 'SPNSR_AMT_CD. 코드id:CM012.',
    MBER_INFLOW_PATH_CD NUMBER(10,0)    COMMENT 'MBER_INFLOW_PATH_CD. 코드id:MM293.',
    MBER_INFLOW_PATH_NM VARCHAR(200)    COMMENT 'MBER_INFLOW_PATH_NM. 코드id:MM293.',
    CMPGN_CTGR_CD       NUMBER(10,0)    COMMENT 'CMPGN_CTGR_CD. 코드id:MM294.',
    CMPGN_CTGR_NM       VARCHAR(200)    COMMENT 'CMPGN_CTGR_NM. 코드id:MM294.',
    CMPGN_TYPE1_BSN     NUMBER(10,0)    COMMENT 'CMPGN_TYPE1_BSN. 코드id:MM295.',
    CMPGN_TYPE1_NM      VARCHAR(200)    COMMENT 'CMPGN_TYPE1_NM. 코드id:MM295.',
    CMPGN_TYPE2_BSN     NUMBER(10,0)    COMMENT 'CMPGN_TYPE2_BSN. 코드id:MM296.',
    CMPGN_TYPE2_NM      VARCHAR(200)    COMMENT 'CMPGN_TYPE2_NM. 코드id:MM296.',
    MKTG_CMPGN_NM       NUMBER(10,0)    COMMENT 'MKTG_CMPGN_NM.',
    MK_CMPGN_NM         VARCHAR(200)    COMMENT 'MK_CMPGN_NM.',
    CMMN_BRND           NUMBER(10,0)    COMMENT 'MM297 공통브랜드 코드. CRM_CAMPAIGN 비정규화. 코드id:MM297.',
    CMMN_BRND_NM        VARCHAR(100)    COMMENT 'MM297 공통브랜드명. CRM_CAMPAIGN 비정규화. 코드id:MM297.',
    MKTG_UTM            NUMBER(10,0)    COMMENT 'MKTG_UTM.',
    MKTG_UTM_NM         VARCHAR(200)    COMMENT 'MKTG_UTM_NM.',
    MKTG_CHANNEL        NUMBER(10,0)    COMMENT '마케팅 채널 코드. CRM_CAMPAIGN 비정규화',
    MKTG_CHANNEL_NM     VARCHAR(200)    COMMENT '마케팅 채널명. CRM_CAMPAIGN 비정규화',
    SPNSR_DIV_CD        VARCHAR         COMMENT 'SPNSR_DIV_CD. 코드id:CM035.',
    SPNSR_DIV_NM        VARCHAR(100)    COMMENT '후원구분명. CRM_CAMPAIGN 비정규화',
    CPR_DIV_CD          VARCHAR         COMMENT 'CPR_DIV_CD. 코드id:CM019.',
    CPR_DIV_NM          VARCHAR(100)    COMMENT '법인구분명. CRM_CAMPAIGN 비정규화',
    BRND_NM             VARCHAR         COMMENT '브랜드명. CRM_CAMPAIGN 비정규화',
    PARENT_CAMPAIGN_NAME VARCHAR        COMMENT 'PARENT_CAMPAIGN_NAME.',
    PROMO_METHOD_NAME   VARCHAR         COMMENT '홍보방법명 (CM008 라벨). CRM_CAMPAIGN 비정규화. 코드id:CM008.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    SRC_LOAD_DT         TIMESTAMP_NTZ   COMMENT '원천(BRONZE) 적재시각 워터마크.',
    SPNSR_TIME_CO       NUMBER(10,0)    COMMENT '후원시간수 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT]',
    PRIMARY KEY (SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO)
) COMMENT = '개발약정 이력 (신규/증액/재후원/중단). [Grain: SPNSR_NO × SPNSR_BSNS_NO × OCCRRNC_DE × SER_NO (1행=1개발약정)]. [주의: DVLP_DIV_CD(1 신규, 2 증액, 3 감액, 4 재후원, 5 중단)]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT].';

-- CRM_MEMBER_AMT_CHANGE — 약정 금액 변경 이력 (증액/감액)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_AMT_CHANGE (
    OCCRRNC_DE          VARCHAR(8)      NOT NULL COMMENT '발생일자 YYYYMMDD (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '일련번호 (PK)',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    SPNSR_AMT           NUMBER(19,0)    COMMENT '변경 후 약정금액 (원단위)',
    RDCAMT_YN           VARCHAR(1)      COMMENT '감액여부 (Y=감액/N=증액)',
    ACMSLT_DEPT_CD      VARCHAR(10)     COMMENT '실적부서코드 (→CRM_ORG)',
    CMPGN_CD            VARCHAR(20)     COMMENT '캠페인코드 (→CRM_CAMPAIGN)',
    AREA_CD             VARCHAR(3)      COMMENT '지역코드 (CM018)',
    AREA_NM             VARCHAR         COMMENT '지역명 (코드 라벨)',
    AGE                 NUMBER(10,0)    COMMENT '연령대 코드(CM014) raw — 1=10대미만·2=10대·3=20대·4=30대·5=40대·6=50대·7=60대·8=70대·9=70대이상·10=단체·11=기업·12=기타. 🔴 연수(나이)가 아니다 ⇒ 평균·합계·구간비교 금지(라벨은 CRM_CODE CD_ID=CM014 조인).',
    MBER_DIV_CD             VARCHAR         COMMENT '회원구분 원천코드 raw. 코드id:MM018',
    SETLE_CD                VARCHAR         COMMENT '결제수단 코드 raw (정본 PM040). 라벨 미배선. 코드id:PM040.',
    SEX                     VARCHAR         COMMENT '성별 원천코드 raw. 코드id:CM013',
    SPNSR_AMT_CD            VARCHAR         COMMENT 'SPNSR_AMT_CD. 코드id:CM012.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    SPNSR_TIME_CO       NUMBER(10,0)    COMMENT '후원시간수 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_IRSD]',
    PRIMARY KEY (OCCRRNC_DE, SER_NO)
) COMMENT = '약정 금액 변경 이력 (증액/감액). [Grain: MBER_NO × CHG_DE × SER_NO (1행=1금액변경)]. [주의: 약정금액 증감 이력 추적]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_IRSD].';

-- CRM_MEMBER_DISCONTINUE — 후원 중단 사건 이력
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_DISCONTINUE (
    MBER_NO             VARCHAR(10)     NOT NULL COMMENT '회원번호 (PK)',
    SPNSR_DSCNTC_DE     VARCHAR(8)      NOT NULL COMMENT '후원중단일자 YYYYMMDD (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '일련번호 (PK)',
    DSCNTC_RSN_CD       VARCHAR(3)      COMMENT '중단사유코드',
    DSCNTC_RSN_NM       VARCHAR         COMMENT '중단사유명 (코드 라벨)',
    DSCNTC_PATH         VARCHAR(1)      COMMENT '중단경로',
    DSCNTC_PATH_NM          VARCHAR         COMMENT '중단경로명. 코드id:MM287.',
    REGIST_DEPT_CD      VARCHAR(10)     COMMENT '등록부서코드 (→CRM_ORG)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (MBER_NO, SPNSR_DSCNTC_DE, SER_NO)
) COMMENT = '후원 중단 사건 이력. [Grain: MBER_NO × SPNSR_DSCNTC_DE × SPNSR_NO (1행=1중단사건)]. [주의: 중단사유 및 중단채널 관리]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC].';

-- CRM_MEMBER_RESPONSOR — 재후원 사건 이력
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
) COMMENT = '재후원 사건 이력. [Grain: MBER_NO × RSPNSR_DE (1행=1재후원)]. [주의: 중단 후 재후원 전이 관리]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_RSPNSR].';

-- CRM_MEMBER_SPONSOR_BIZ — 회원×후원사업 약정 관계
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
) COMMENT = '회원×후원사업 약정 관계. [Grain: MBER_NO × SPNSR_BSNS_ID (1행=1약정관계)]. [주의: 회원과 후원사업 간 결합]. [원천: CRM → BRONZE_CRM.TM_MM_MBER_SPNSR_BSNS].';

-- CRM_SPONSOR_RELATION — 결연 아동 관계 마스터
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SPONSOR_RELATION (
    RELATNSP_KEY        NUMBER(10,0)    NOT NULL COMMENT '결연키 (PK)',
    SPNSR_NO            VARCHAR(9)      COMMENT '후원번호',
    SPNSR_BSNS_NO       NUMBER(19,0)    COMMENT '후원사업번호',
    SPNSR_BSNS_ID       VARCHAR(20)     COMMENT '후원사업ID (Q15 크로스워크 파생)',
    CHILD_CD            NUMBER(10,0)    COMMENT '결연아동코드',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    RELATNSP_STRT_DE    DATE            COMMENT '결연 시작일',
    RELATNSP_DSCNTC_DE  DATE            COMMENT '결연 중단일',
    RELATNSP_DSCNTC_YN  VARCHAR(1)      COMMENT '결연 중단여부.',
    RELATNSP_DSCNTC_RSN_CD  VARCHAR         COMMENT 'RELATNSP_DSCNTC_RSN_CD. 코드id:MM002.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (RELATNSP_KEY)
) COMMENT = '결연 아동 관계 마스터. [Grain: MBER_NO × CHLDRN_NO (1행=1결연)]. [주의: 결연 후원자와 아동 매핑]. [원천: CRM → BRONZE_CRM.TM_MM_CHLDRN_STLM_INFO].';

-- CRM_PAYMENT_BILLING — 납입 및 청구 통합 원장 (회비∪기부금)
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
    PAY_STAT_CD         VARCHAR(3)      COMMENT '납입상태코드. ★미납 판정축(DEC.',
    SETLE_CD            VARCHAR(3)      COMMENT 'SETLE_CD.',
    GFT_DIV_CD          VARCHAR(3)      COMMENT '기부구분코드',
    RQEST_RST_CD        VARCHAR(30)     COMMENT 'RQEST_RST_CD. 코드id:PM002.',
    PRCS_RST_CD         VARCHAR(10)     COMMENT '처리결과코드.',
    CPR_DIV_CD              VARCHAR         COMMENT 'CPR_DIV_CD. 코드id:CM019.',
    MBER_DIV_CD             VARCHAR         COMMENT '회원구분 원천코드 raw. 코드id:MM018',
    MBRFEE_DIV_CD           VARCHAR         COMMENT 'MBRFEE_DIV_CD. 코드id:PM010.',
    OPERT_DIV_CD            VARCHAR         COMMENT 'OPERT_DIV_CD. 코드id:MM014.',
    MBRFEE_PRCS_STAT_CD     VARCHAR         COMMENT '처리상태 코드 raw (정본 PM013). 코드id:PM013.',
    RETUN_RSN_CD            VARCHAR         COMMENT 'RETUN_RSN_CD. 코드id:PM042.',
    RQEST_DIV_CD            VARCHAR         COMMENT 'RQEST_DIV_CD. 코드id:PM024.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    RQEST_MT            VARCHAR(6)      COMMENT '청구월 [원천: BRONZE_CRM.TM_PM_MBRFEE_ACMSLT]',
    RQEST_SQNC          NUMBER(3,0)     COMMENT '청구차수 [원천: BRONZE_CRM.TM_PM_MBRFEE_ACMSLT]',
    TOGETH_WTDRW_YN     VARCHAR(1)      COMMENT '함께출금여부 [원천: BRONZE_CRM.TM_PM_MBRFEE_ACMSLT]',
    SETLE_ENTRPS_CD     VARCHAR(10)     COMMENT '결제업체코드 [원천: BRONZE_CRM.TM_PM_MBRFEE_ACMSLT · BRONZE_CRM.TM_PM_DNTN_DTLS]',
    ONCE_CMPGN_CD       VARCHAR(20)     COMMENT '일시후원캠페인코드 [원천: BRONZE_CRM.TM_PM_DNTN_DTLS]',
    ACMSLT_DEPT_CD      VARCHAR(10)     COMMENT '실적부서코드 [원천: BRONZE_CRM.TM_PM_DNTN_DTLS]',
    USE_YN              VARCHAR(1)      COMMENT '사용여부 [원천: BRONZE_CRM.TM_PM_MBRFEE_ACMSLT · BRONZE_CRM.TM_PM_DNTN_DTLS]',
    PRIMARY KEY (PAY_KEY)
) COMMENT = '납입 및 청구 통합 원장 (회비∪기부금). [Grain: MBER_NO × MBRFEE_MT × SPNSR_BSNS_ID × SETLE_CD (1행=1납입청구)]. [주의: 회비 납입결과(PAY_STAT_CD) 및 청구/납입액 관리]. [원천: CRM → BRONZE_CRM.TM_PM_MBRFEE_ACMSLT ∪ TM_PM_DNTN_DTLS].';

-- CRM_PAYMENT_METHOD — 회원별 결제수단 마스터
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_PAYMENT_METHOD (
    SETLE_KEY           NUMBER(10,0)    NOT NULL COMMENT '결제수단키 (PK)',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    SETLE_CD            VARCHAR(3)      COMMENT '결제수단코드',
    SETLE_NM            VARCHAR         COMMENT '결제수단명 (코드 라벨)',
    CARD_DIV_CD         VARCHAR(3)      COMMENT '카드구분코드',
    FNLT_CD             VARCHAR(10)     COMMENT '금융기관코드',
    WTDRW_STRT_DE       DATE            COMMENT '출금 시작일',
    SETLE_STAT_CD       VARCHAR(3)      COMMENT '결제상태코드',
    APPLCNT_MBER_REL_CD     VARCHAR         COMMENT '신청자. 코드id:CM009.',
    CPR_DIV_CD              VARCHAR         COMMENT '법인구분 코드 raw (정본 CM019). 코드id:CM019.',
    CRTFC_MTH_CD            VARCHAR         COMMENT '인증방법 코드 raw (정본 MM014). 코드id:MM014.',
    FNLT_DIV_CD             VARCHAR         COMMENT 'FNLT_DIV_CD. 코드id:PM050.',
    RCEPT_DIV_CD            VARCHAR         COMMENT '접수구분 코드 raw (정본 PM003). 코드id:PM003.',
    RQST_DIV_CD             VARCHAR         COMMENT '요청구분 코드 raw (정본 PM004). 코드id:PM004.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    WTDRW_ASMT_SQNC     NUMBER(3,0)     COMMENT '출금지정차수 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    SETLE_ENTRPS_CD     VARCHAR(10)     COMMENT '결제업체코드 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    ACNUT_SER_NO        NUMBER(10,0)    COMMENT '계좌일련번호(기관 계좌 참조 · 계좌번호 아님) [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    PAYER_MBER_REL_CD   VARCHAR(3)      COMMENT '결제자회원관계코드 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    APRV_YN             VARCHAR(1)      COMMENT '승인여부 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    FRST_BEGIN_DE       DATE            COMMENT '최초개시일 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    RQEST_EXCL_YN       VARCHAR(1)      COMMENT '청구제외여부 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    RQEST_EXCL_STRT_DE  DATE            COMMENT '청구제외시작일 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    RQEST_EXCL_END_DE   DATE            COMMENT '청구제외종료일 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    BF_SETLE_KEY        NUMBER(10,0)    COMMENT '이전결제KEY [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    OPERT_DIV_CD        VARCHAR(3)      COMMENT '작업구분코드 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    CRTFC_TY_CD         VARCHAR(3)      COMMENT '인증유형코드 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    USE_YN              VARCHAR(1)      COMMENT '사용여부 [원천: BRONZE_CRM.TM_PM_SETLE_INFO]',
    PRIMARY KEY (SETLE_KEY)
) COMMENT = '회원별 결제수단 마스터. [Grain: MBER_NO × SETLE_CD (1행=1결제수단)]. [주의: CMS/카드 자동이체 등 수납방식 관리]. [원천: CRM → BRONZE_CRM.TM_PM_SETLE_MNG].';

-- CRM_CAMPAIGN — 캠페인 마스터 (비정규화 통합)
--   ⚠️ 유형1 = 국내/통합/해외 · 유형2 = 굿즈/기타/사례/사업 — 혼동 금지.
--   ⚠️ 코드사전 미등재(고아) 코드는 라벨 NULL 로 둔다.
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CAMPAIGN (
    CMPGN_CD            VARCHAR(20)     NOT NULL COMMENT '캠페인코드 (PK)',
    CMPGN_NM            VARCHAR(200)    COMMENT '캠페인명',
    UPPER_CMPGN_CD      VARCHAR(20)     COMMENT '상위캠페인코드 (자기참조)',
    UPPER_CMPGN_YN      VARCHAR(1)      COMMENT '상위캠페인 여부 (Y/N)',
    BRND_ID             VARCHAR(30)     COMMENT '브랜드ID',
    BRND_NM             VARCHAR(200)    COMMENT '브랜드명',
    PR_MTH_CD           VARCHAR(3)      COMMENT '홍보방법코드',
    PROMO_METHOD_NAME   VARCHAR         COMMENT '홍보방법명. 코드id:CM008.',
    PARENT_CAMPAIGN_NAME VARCHAR        COMMENT '상위캠페인명.',
    SPNSR_BSNS_ID       VARCHAR(100)    COMMENT '후원사업ID (Q16 조인키)',
    CMPGN_TRGET_CD          VARCHAR         COMMENT '캠페인대상 코드 raw. 코드id:CM002.',
    CPR_DIV_CD              VARCHAR         COMMENT '법인구분 코드 raw. 코드id:CM019.',
    CPR_DIV_NM          VARCHAR(100)    COMMENT '법인구분명 — CPR_DIV_CD 라벨',
    SPNSR_DIV_CD            VARCHAR         COMMENT '후원구분 코드 raw. 코드id:CM035.',
    SPNSR_DIV_NM        VARCHAR(100)    COMMENT '후원구분명 — SPNSR_DIV_CD 라벨',
    CMPGN_CTGR_CD       NUMBER(10,0)    COMMENT 'CMPGN_CTGR_CD. 코드id:MM294.',
    CMPGN_CTGR_NM       VARCHAR(200)    COMMENT 'CMPGN_CTGR_NM. 코드id:MM294.',
    MBER_INFLOW_PATH_CD NUMBER(10,0)    COMMENT 'MBER_INFLOW_PATH_CD. 코드id:MM293.',
    MBER_INFLOW_PATH_NM VARCHAR(200)    COMMENT 'MBER_INFLOW_PATH_NM. 코드id:MM293.',
    CMPGN_TYPE1_BSN     NUMBER(10,0)    COMMENT 'CMPGN_TYPE1_BSN. 코드id:MM295.',
    CMPGN_TYPE1_NM      VARCHAR(200)    COMMENT '캠페인 유형1명 (MM295 라벨): 국내 / 통합 / 해외. 코드id:MM295.',
    CMPGN_TYPE2_BSN     NUMBER(10,0)    COMMENT 'CMPGN_TYPE2_BSN. 코드id:MM296.',
    CMPGN_TYPE2_NM      VARCHAR(200)    COMMENT 'CMPGN_TYPE2_NM. 코드id:MM296.',
    MKTG_CMPGN_NM       NUMBER(10,0)    COMMENT '마케팅 캠페인코드 (TC_MKTNG_DTL_CD C001 대응 · _NM이나 실제 FK)',
    MK_CMPGN_NM         VARCHAR(200)    COMMENT '마케팅 캠페인명 (TC_MKTNG_DTL_CD C001 라벨)',
    CMMN_BRND           NUMBER(10,0)    COMMENT 'MM297 공통브랜드 코드. 라벨=CMMN_BRND_NM. 코드id:MM297.',
    CMMN_BRND_NM        VARCHAR(100)    COMMENT 'MM297 공통브랜드명',
    MKTG_UTM            NUMBER(10,0)    COMMENT '마케팅 UTM 코드 (TC_MKTNG_DTL_CD U001 대응)',
    MKTG_UTM_NM         VARCHAR(200)    COMMENT '마케팅 UTM 라벨 (TC_MKTNG_DTL_CD U001 라벨)',
    MKTG_CHANNEL        NUMBER(10,0)    COMMENT '마케팅 채널 코드 (TM_CM_CMPGN_MNG.MKTG_CHANNEL · TC_MKTNG_DTL_CD C002 대응)',
    MKTG_CHANNEL_NM     VARCHAR(200)    COMMENT '마케팅 채널명 (TC_MKTNG_DTL_CD C002 라벨)',
    CMPGN_STRT_DE       VARCHAR(8)      COMMENT '캠페인 시작일 YYYYMMDD',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    USE_DEPT_CD         VARCHAR(10)     COMMENT '사용부서코드 [원천: BRONZE_CRM.TM_CM_CMPGN_MNG]',
    USE_SCOPE           VARCHAR(1)      COMMENT '사용범위 [원천: BRONZE_CRM.TM_CM_CMPGN_MNG]',
    USE_YN              VARCHAR(1)      COMMENT '사용여부 [원천: BRONZE_CRM.TM_CM_CMPGN_MNG]',
    CMPGN_PRPT_YN       VARCHAR(1)      COMMENT '캠페인특성여부 [원천: BRONZE_CRM.TM_CM_CMPGN_MNG]',
    SPNSR_ENTRPRS_ID    VARCHAR(20)     COMMENT '후원기업ID [원천: BRONZE_CRM.TM_CM_CMPGN_MNG]',
    EMRGNCY_AID_BPLC_CD NUMBER(10,0)    COMMENT '긴급구호사업장코드 [원천: BRONZE_CRM.TM_CM_CMPGN_MNG]',
    BRND_USE_YN         VARCHAR(1)      COMMENT '사용여부 [원천: BRONZE_CRM.TM_CM_BRND_MNG]',
    PRIMARY KEY (CMPGN_CD)
) COMMENT = '캠페인 마스터 (비정규화 통합). [Grain: CMPGN_CD (1행=1캠페인)]. [주의: 카테고리/인입경로/국내해외/마케팅캠페인 속성 통합]. [원천: CRM → BRONZE_CRM.TM_CM_CMPGN_MNG].';

-- CRM_SPONSORSHIP — 후원사업 마스터
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
    SORT_ORDR           NUMBER(10,0)    COMMENT '정렬순서 [원천: BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO]',
    USE_YN              VARCHAR(1)      COMMENT '사용여부 [원천: BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO]',
    PRIMARY KEY (SPNSR_BSNS_ID)
) COMMENT = '후원사업 마스터. [Grain: SPNSR_BSNS_ID (1행=1후원사업)]. [주의: 정기/일시 사업구분 및 상위 사업분류]. [원천: CRM → BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO].';

-- CRM_ORG — 조직/부서 마스터
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_ORG (
    DEPT_ID                 VARCHAR(20)     NOT NULL COMMENT '부서ID (PK)',
    DEPT_NM                 VARCHAR(50)     COMMENT '부서명',
    UPPER_DEPT_ID           VARCHAR(20)     COMMENT '상위부서ID (조직 계층)',
    ACMSLT_UPPER_DEPT_ID    VARCHAR(20)     COMMENT '실적상위부서ID (실적팀 재귀 LVL5)',
    ACMSLT_DEPT_YN          VARCHAR(1)      COMMENT '실적부서 여부 (Y/N)',
    STATS_DEPT_LVL          NUMBER(3,0)     COMMENT '통계부서 레벨',
    USE_YN                  VARCHAR(1)      COMMENT '사용여부 (Y/N)',
    SORT_ORDR               NUMBER(10,0)    COMMENT '정렬순서',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    LAST_UPDT_DT         TIMESTAMP_NTZ(9) COMMENT '최종수정일시 (원천 그대로) — DIM_ORG 활성 판정(NULL·9999-12-31 제외) 입력',
    PRIMARY KEY (DEPT_ID)
) COMMENT = '조직/부서 마스터. [Grain: DEPT_ID (1행=1부서)]. [주의: 본부/지부 계층 및 실적부서 매핑]. [원천: CRM → BRONZE_CRM.TM_CM_DEPT_MNG].';

-- CRM_DEV_TARGET — 회원개발 부문 목표 마스터
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_DEV_TARGET (
    STDYY               VARCHAR(4)      NOT NULL COMMENT '기준연도 YYYY (PK)',
    STDR_MT             VARCHAR(6)      NOT NULL COMMENT '기준월 YYYYMM (PK)',
    MBER_DVLP_DIV_CD    VARCHAR(1)      NOT NULL COMMENT '회원개발 구분코드 (PK)',
    DEPT_ID             VARCHAR(20)     NOT NULL COMMENT '부서ID (PK, →CRM_ORG)',
    GOAL_CNT            NUMBER(10,0)    COMMENT '목표 건수',
    TARGET_TYPE         VARCHAR(50)     COMMENT '목표 유형 (ORIGINAL/당초 등) [O145-8]',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (STDYY, STDR_MT, MBER_DVLP_DIV_CD, DEPT_ID)
) COMMENT = '회원개발 부문 목표 마스터. [Grain: STDYY × STDR_MT × DEPT_ID × MBER_DVLP_DIV_CD (1행=1개발목표)]. [주의: 부서별 월별 신규/증액/재후원 목표치]. [원천: CRM → BRONZE_CRM.TM_CM_MBER_DVLP_GOAL].';

-- CRM_SEND_REQUEST — 메시지 발송 요청 마스터
--   ⚠️ 복합 PK 전환은 09 적재쿼리 상단 ALTER 가 한다(이 파일은 단일 PK).
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_REQUEST (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL COMMENT '발송키 (PK)',
    SEND_CHANNEL        VARCHAR         COMMENT '발송채널 (SND/SMS/EMAIL 등)',
    SNDNG_TY_CD         VARCHAR(3)      COMMENT '발송유형코드',
    SEND_GBN_TOP        VARCHAR(255)    COMMENT '발송구분 대분류코드',
    SEND_GBN_TOP_NM     VARCHAR(255)    COMMENT '발송구분 대분류명',
    SEND_GBN_MID        VARCHAR(255)    COMMENT '발송구분 중분류코드',
    SEND_GBN_MID_NM     VARCHAR(255)    COMMENT '발송구분 중분류명',
    SEND_GBN_BOT        VARCHAR(255)    COMMENT '발송구분 소분류코드',
    SEND_GBN_BOT_NM     VARCHAR(255)    COMMENT '발송구분 소분류명',
    TIT                 VARCHAR(100)    COMMENT '발송 제목',
    SNDNG_STDR_DE       TIMESTAMP_NTZ   COMMENT '발송 기준일시',
    REQ_SEQ_NO          NUMBER(19,0)    COMMENT '요청 일련번호',
    MSG_DIV_CD              VARCHAR         COMMENT 'MSG_DIV_CD. 코드id:MS010.',
    PSTMTR_PRCS_STAT_CD     VARCHAR         COMMENT 'PSTMTR_PRCS_STAT_CD. 코드id:MS061.',
    SNDNG_TIME_DIV_CD       VARCHAR         COMMENT 'SNDNG_TIME_DIV_CD. 코드id:MS267.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    SNDNG_CD_ID         VARCHAR(20)     COMMENT '발신코드ID [원천: BRONZE_CRM.TM_MS_EMAIL_SNDNG · BRONZE_CRM.TM_MS_MSG_AT_SNDNG · BRONZE_CRM.TM_MS_PSTMTR_SNDNG]',
    SNDNG_DTL_CD_ID     VARCHAR(20)     COMMENT '발신상세코드ID [원천: BRONZE_CRM.TM_MS_EMAIL_SNDNG · BRONZE_CRM.TM_MS_MSG_AT_SNDNG · BRONZE_CRM.TM_MS_PSTMTR_SNDNG]',
    PRCS_DE             TIMESTAMP_NTZ   COMMENT '처리일 [원천: BRONZE_CRM.TM_MS_EMAIL_SNDNG · BRONZE_CRM.TM_MS_MSG_AT_SNDNG · BRONZE_CRM.TM_MS_PSTMTR_SNDNG]',
    PRCS_YN             VARCHAR(1)      COMMENT '처리여부 [원천: BRONZE_CRM.TM_MS_EMAIL_SNDNG]',
    TMPLAT_ID           VARCHAR(255)    COMMENT '템플릿ID [원천: BRONZE_CRM.TM_MS_MSG_AT_SNDNG · BRONZE_CRM.SND_REQ_MST]',
    ALTRTV_MSG_SNDNG_YN VARCHAR(255)    COMMENT '대체메시지발신여부 [원천: BRONZE_CRM.TM_MS_MSG_AT_SNDNG · BRONZE_CRM.SND_REQ_MST]',
    LQY_YN              VARCHAR(1)      COMMENT '대량여부 [원천: BRONZE_CRM.TM_MS_PSTMTR_SNDNG]',
    RE_SNDNG_YN         VARCHAR(1)      COMMENT '재발신여부 [원천: BRONZE_CRM.TM_MS_PSTMTR_SNDNG]',
    MSG_TYPE            VARCHAR(255)    COMMENT '메시지 유형 [원천: BRONZE_CRM.SND_REQ_MST]',
    REGULARLY           VARCHAR(255)    COMMENT '발송 유형 (정기/비정기) [원천: BRONZE_CRM.SND_REQ_MST]',
    SEND_STATUS         VARCHAR(255)    COMMENT '발송 상태 [원천: BRONZE_CRM.SND_REQ_MST]',
    SEND_ROUND          NUMBER(10,0)    COMMENT '발송차수 [원천: BRONZE_CRM.SND_REQ_MST]',
    CONDITION_TITLE     VARCHAR(255)    COMMENT '발송 조건 제목 [원천: BRONZE_CRM.SND_REQ_MST]',
    MENU_CODE           VARCHAR(255)    COMMENT '메뉴코드 [원천: BRONZE_CRM.SND_REQ_MST]',
    SERVICE_MENU_CODE   VARCHAR(100)    COMMENT '서비스메뉴코드 [원천: BRONZE_CRM.SND_REQ_MST]',
    USE_YN              VARCHAR(255)    COMMENT '사용 여부 [원천: BRONZE_CRM.SND_REQ_MST]',
    CORP_TYPE           VARCHAR(10)     COMMENT '법인구분 코드(CM019 · I=사단 S=사복 · SND 요청 전용 · 대다수 NULL) [원천: BRONZE_CRM.SND_REQ_MST]',
    SEND_SPLIT_TYPE     VARCHAR(20)     COMMENT '발송 분할 방식 원천값(once = 일괄 · divide = 분할 · SND 요청 전용) [원천: BRONZE_CRM.SND_REQ_MST]',
    PRIMARY KEY (SNDNG_KEY)
) COMMENT = '메시지 발송 요청 마스터. [Grain: SNDNG_REQ_NO (1행=1발송요청)]. [주의: 발송채널 및 대/중/소 발송구분 보유]. [원천: CRM → BRONZE_CRM.TM_MS_EMAIL/MSG/PSTMTR_SNDNG].';

-- CRM_SEND_MEMBER — 메시지 발송 대상 회원 상세
--   ⚠️ 복합 PK 전환은 09 적재쿼리 상단 ALTER 가 한다(이 파일은 단일 PK).
--   ⚠️ OPEN_DT = SND_MEMBER_OPEN_LOG 의 회원×발송별 MIN(OPEN_DT).
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_MEMBER (
    SNDNG_KEY           NUMBER(10,0)    NOT NULL COMMENT '발송키 (PK, →CRM_SEND_REQUEST)',
    SNDNG_DTL_KEY       NUMBER(10,0)    NOT NULL COMMENT '발송상세키 (PK)',
    MBER_NO             VARCHAR(10)     COMMENT '회원번호',
    SNDNG_DE            TIMESTAMP_NTZ   COMMENT '발송일시',
    SNDNG_RST_CD        VARCHAR(3)      COMMENT '발송결과코드 (축A raw · 채널별 다체계.',
    SEND_CHANNEL        VARCHAR         COMMENT '발송채널 (축A 판별자)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    SEND_STATUS_GROUP   VARCHAR(10)     COMMENT 'SEND_STATUS_GROUP. 코드id:MS282.',
    SEND_STATUS_NAME    VARCHAR         COMMENT '축A 라벨 (CRM_CODE 조인). [사유:원천 부재]',
    SEND_RESULT_CD      VARCHAR(10)     COMMENT '축B(신설) 통신사 결과코드 raw.',
    SEND_RESULT_GROUP   VARCHAR(10)     COMMENT 'SEND_RESULT_GROUP. 코드id:MS283.',
    SEND_RESULT_NAME    VARCHAR         COMMENT 'SEND_RESULT_NAME.',
    OPEN_DT             TIMESTAMP_NTZ   COMMENT '오픈시각 (SND_MEMBER_OPEN_LOG 축약).',
    FRST_BRND_CD         VARCHAR          COMMENT '발송 시점 최초 브랜드 코드 (원천 그대로)',
    FRST_BRND_NM         VARCHAR          COMMENT '발송 시점 최초 브랜드명',
    LST_BRND_CD          VARCHAR          COMMENT '발송 시점 최종 브랜드 코드 (원천 그대로)',
    LST_BRND_NM          VARCHAR          COMMENT '발송 시점 최종 브랜드명',
    CURRENT_BRND         VARCHAR          COMMENT '현재 브랜드 (원천 그대로)',
    ALTRTV_MSG_SNDNG_YN VARCHAR(1)      COMMENT '대체문자 발송 여부 [원천: BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS]',
    RELATNSP_KEY        NUMBER(19,0)    COMMENT '결연KEY [원천: BRONZE_CRM.TD_MS_PSTMTR_SNDNG_DTL · BRONZE_CRM.SND_MEMBER_LIST]',
    MNG_NO              VARCHAR(7)      COMMENT '관리번호 [원천: BRONZE_CRM.TD_MS_PSTMTR_SNDNG_DTL]',
    MSG_KEY             VARCHAR(255)    COMMENT '메세지키 [원천: BRONZE_CRM.SND_MEMBER_LIST]',
    CINFO               VARCHAR(255)    COMMENT '알림톡구분 [원천: BRONZE_CRM.SND_MEMBER_LIST]',
    RESPONSED_YN        VARCHAR(255)    COMMENT '발송확인여부 [원천: BRONZE_CRM.SND_MEMBER_LIST]',
    RESPONSED_DT        TIMESTAMP_NTZ   COMMENT '확인일시 [원천: BRONZE_CRM.SND_MEMBER_LIST]',
    REAL_SEND_DT        TIMESTAMP_NTZ   COMMENT '실제발신일시 [원천: BRONZE_CRM.SND_MEMBER_LIST]',
    SND_SPNSR_NM        VARCHAR         COMMENT '발송 시점 회원 후원사업명(SND 전용 스냅샷 · 타 채널 NULL) [원천: BRONZE_CRM.SND_MEMBER_LIST.SPNSR_NM]',
    SND_DSCNTC_RSN_NM   VARCHAR         COMMENT '발송 시점 중단사유명(SND 전용 · 중단 이력 있는 회원만) [원천: BRONZE_CRM.SND_MEMBER_LIST.DSCNTC_RSN_NM]',
    SND_CHILD_PROJECT_COUNTRY VARCHAR   COMMENT '발송 시점 신규 결연아동 사업국(SND 전용) [원천: BRONZE_CRM.SND_MEMBER_LIST.NEW_CHILD_PROJECT_COUNTRY]',
    SND_CHILD_WORKPLACE_NM VARCHAR      COMMENT '발송 시점 신규 결연아동 사업장명(SND 전용) [원천: BRONZE_CRM.SND_MEMBER_LIST.NEW_CHILD_WORKPLACE_NM]',
    PRIMARY KEY (SNDNG_KEY, SNDNG_DTL_KEY)
) COMMENT = '메시지 발송 대상 회원 상세. [Grain: SNDNG_REQ_NO × MBER_NO (1행=1발송회원)]. [주의: 수신자별 발송결과 및 오픈일시 관리]. [원천: CRM → BRONZE_CRM.TD_MS_*_DTLS].';

-- CRM_SEND_RESULT — 메시지 발송 채널별 성과 집계
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
    RECPTN_CNT          NUMBER(18,0)    COMMENT '수신건수 [원천: BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG]',
    ALTRTV_SNDNG_CNT    NUMBER(18,0)    COMMENT '알림톡대체발송건수 [원천: BRONZE_CRM.TD_MS_MSG_AT_LQY_SNDNG]',
    SNDNG_STRT_DT       TIMESTAMP_NTZ   COMMENT '발신시작일시 [원천: BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG]',
    SNDNG_END_DT        TIMESTAMP_NTZ   COMMENT '발신종료일시 [원천: BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG]',
    RESVE_SNDNG_DE      DATE            COMMENT '예약발신일 [원천: BRONZE_CRM.TD_MS_MSG_AT_LQY_SNDNG]',
    SNDNG_SQNC          NUMBER(3,0)     COMMENT '발신차수 [원천: BRONZE_CRM.TD_MS_PSTMTR_LQY_SNDNG]',
    SNDNG_TIT           VARCHAR(255)    COMMENT '발신제목 [원천: BRONZE_CRM.TD_MS_PSTMTR_LQY_SNDNG]',
    PRIMARY KEY (SNDNG_KEY, SEND_CHANNEL)
) COMMENT = '메시지 발송 채널별 성과 집계. [Grain: SNDNG_REQ_NO × SNDNG_RST_CD (1행=1발송성과)]. [주의: 발송 성공/실패 건수 집계]. [원천: CRM → BRONZE_CRM.TD_MS_*_LQY_SNDNG].';

-- CRM_EVENT — 행사/이벤트 마스터
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_EVENT (
    EVENT_KEY           VARCHAR         NOT NULL COMMENT '행사키 (PK)',
    EVENT_SOURCE        VARCHAR         COMMENT '행사출처 (이벤트/캠페인행사)',
    EVENT_DIV_CD        VARCHAR(3)      COMMENT '행사구분코드 (raw · 원천별 다체계.',
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
    EVENT_DIV_GROUP     VARCHAR(10)     COMMENT 'EVENT_DIV_GROUP. 코드id:MS286.',
    EVENT_DIV_NM        VARCHAR         COMMENT '행사구분 라벨 (CRM_CODE 조인 · 두 체계 겹침 0).',
    PRZWIN_PSNNL_CO     NUMBER(10,0)    COMMENT '당첨인원수 [원천: BRONZE_CRM.TM_MS_EVENT]',
    PRZWIN_GFT_SNDNG_DE VARCHAR(8)      COMMENT '당첨선물발송일 [원천: BRONZE_CRM.TM_MS_EVENT]',
    CRMN_PLACE_NM       VARCHAR(200)    COMMENT '행사장소명 [원천: BRONZE_CRM.TM_MS_CRMN]',
    CRMN_PART_STRT_DE   VARCHAR(8)      COMMENT '캠페인참여시작일자 [원천: BRONZE_CRM.TM_MS_CRMN]',
    CRMN_PART_END_DE    VARCHAR(8)      COMMENT '캠페인참여종료일자 [원천: BRONZE_CRM.TM_MS_CRMN]',
    TAT                 NUMBER(5,0)     COMMENT '소요시간 [원천: BRONZE_CRM.TM_MS_CRMN]',
    RESRCE_SRVC_FG      BOOLEAN         COMMENT '자원봉사유무 [원천: BRONZE_CRM.TM_MS_CRMN]',
    CPR_DIV_CD          VARCHAR(3)      COMMENT '법인구분코드 [원천: BRONZE_CRM.TM_MS_CRMN]',
    ENTRPS_CD           NUMBER(10,0)    COMMENT '업체코드 [원천: BRONZE_CRM.TM_MS_CRMN]',
    USE_YN              VARCHAR(1)      COMMENT '사용여부 [원천: BRONZE_CRM.TM_MS_CRMN]',
    PART_USE_YN         VARCHAR(1)      COMMENT '참여신청 사용여부 Y/N · 일반행사 NULL [원천: BRONZE_CRM.TM_MS_CRMN]',
    PRIMARY KEY (EVENT_KEY)
) COMMENT = '행사/이벤트 마스터. [Grain: EVENT_KEY (1행=1행사)]. [주의: 일반행사 및 캠페인행사 통합]. [원천: CRM → BRONZE_CRM.TM_MS_EVENT ∪ TM_MS_CRMN].';

-- CRM_EVENT_PARTICIPATION — 행사 참여자 상세
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_EVENT_PARTICIPATION (
    EVENT_KEY           VARCHAR         NOT NULL COMMENT '행사키 (PK, →CRM_EVENT)',
    MBER_NO             VARCHAR(10)     NOT NULL COMMENT '회원번호 (PK)',
    PARTCPT_SEQ         NUMBER(10,0)    NOT NULL COMMENT '참여 일련번호 (PK)',
    PARTCPT_STAT_CD     VARCHAR(3)      COMMENT '참여상태코드 (raw · 원천별 2체계 O28.',
    PARTCPT_CHNNL_CD    VARCHAR(3)      COMMENT '참여채널코드 (raw · EVENT 전용.',
    PARTCPT_PATH_CD     VARCHAR(3)      COMMENT '참여경로코드.',
    PRZWIN_CD           NUMBER(10,0)    COMMENT '당첨코드',
    RCPMNY_AMT          NUMBER(19,0)    COMMENT '입금금액 (원단위)',
    PARTCPT_DT          TIMESTAMP_NTZ   COMMENT '참여일시',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PARTCPT_STAT_GROUP  VARCHAR(10)     COMMENT 'PARTCPT_STAT_GROUP. 코드id:MS304.',
    PARTCPT_STAT_NM     VARCHAR         COMMENT '참여상태 라벨 (CRM_CODE 조인).',
    PARTCPT_CHNNL_GROUP VARCHAR(10)     COMMENT 'PARTCPT_CHNNL_GROUP. 코드id:MS302.',
    PARTCPT_CHNNL_NM    VARCHAR         COMMENT '참여채널 라벨 (CRM_CODE 조인)',
    PARTCPT_PATH_GROUP  VARCHAR(10)     COMMENT 'PARTCPT_PATH_GROUP. 코드id:MS303.',
    PARTCPT_PATH_NM     VARCHAR         COMMENT '참여경로 라벨 (CRM_CODE 조인)',
    EVENT_PARTCPT_DIV_CD VARCHAR(3)      COMMENT '이벤트참여구분코드 [원천: BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL]',
    RQST_DATE           VARCHAR(8)      COMMENT '신청일자 [원천: BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    SELF_PARTCPT_CD     VARCHAR(3)      COMMENT '자기참여코드 [원천: BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    ACMPNY_PARTCPT_CO   NUMBER(10,0)    COMMENT '동반참여수 [원천: BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    PARTCPT_TIME_CO     NUMBER(10,0)    COMMENT '참여시간수 [원천: BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    RCPMNY_STAT_CD      VARCHAR(3)      COMMENT '입금상태코드 [원천: BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    RCPMNY_DATE         VARCHAR(8)      COMMENT '입금일자 [원천: BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    REFND_DATE          VARCHAR(8)      COMMENT '환불일자 [원천: BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    PRIMARY KEY (EVENT_KEY, MBER_NO, PARTCPT_SEQ)
) COMMENT = '행사 참여자 상세. [Grain: EVENT_KEY × MBER_NO (1행=1참여)]. [주의: 신청/취소/참석 상태 및 납입금액 관리]. [원천: CRM → BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL ∪ TD_MS_CRMN_PRTCPNT].';

-- CRM_RELATION_ACTIVITY — 결연 활동 내역 (서신∪선물금)
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
    LETTER_STAT_CD      NUMBER(3,0)     COMMENT '편지상태코드 [원천: BRONZE_CRM.TM_RM_RELATNSP_LETTER_INFO]',
    LANG_CD             VARCHAR(10)     COMMENT '언어코드 [원천: BRONZE_CRM.TM_RM_RELATNSP_LETTER_INFO]',
    ONLINE_POST_WRITNG_YN VARCHAR(1)      COMMENT '온라인우편작성여부 [원천: BRONZE_CRM.TM_RM_RELATNSP_LETTER_INFO]',
    ONLINE_INFLOW_CD    NUMBER(10,0)    COMMENT '온라인유입코드 [원천: BRONZE_CRM.TM_RM_RELATNSP_LETTER_INFO]',
    UNREPLY_RSN_CD      NUMBER(10,0)    COMMENT '미답신사유코드 [원천: BRONZE_CRM.TM_RM_RELATNSP_LETTER_INFO · BRONZE_CRM.TM_RM_RELATNSP_GFTMNEY_INFO]',
    MBRFEE_KEY          NUMBER(10,0)    COMMENT '회비KEY [원천: BRONZE_CRM.TM_RM_RELATNSP_GFTMNEY_INFO]',
    SETLE_DE            DATE            COMMENT '결제일 [원천: BRONZE_CRM.TM_RM_RELATNSP_GFTMNEY_INFO]',
    SETLE_CD            VARCHAR(3)      COMMENT '결제코드 [원천: BRONZE_CRM.TM_RM_RELATNSP_GFTMNEY_INFO]',
    GFT_DIV_CD          VARCHAR(3)      COMMENT '선물구분코드 [원천: BRONZE_CRM.TM_RM_RELATNSP_GFTMNEY_INFO]',
    GFTMNEY_DOLLAR_AMT  VARCHAR(30)     COMMENT '선물금미화금액 [원천: BRONZE_CRM.TM_RM_RELATNSP_GFTMNEY_INFO]',
    APRV_DE             DATE            COMMENT '승인일 [원천: BRONZE_CRM.TM_RM_RELATNSP_GFTMNEY_INFO]',
    TRNSFER_YN          VARCHAR(1)      COMMENT '이관여부 [원천: BRONZE_CRM.TM_RM_RELATNSP_GFTMNEY_INFO]',
    SETLE_BANK_CD       VARCHAR(10)     COMMENT '선물금 정산은행 코드(PM039) · 서신 행 NULL [원천: BRONZE_CRM.TM_RM_RELATNSP_GFTMNEY_INFO]',
    PRIMARY KEY (ACTIVITY_KEY)
) COMMENT = '결연 활동 내역 (서신∪선물금). [Grain: ACTV_NO (1행=1활동)]. [주의: 서신교환 및 선물금 전달 이력]. [원천: CRM → BRONZE_CRM.TM_MM_LTR_EXCHG ∪ TM_MM_GIFT_DLVRY].';

-- CRM_CODE — 공통 코드 사전 마스터
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
    DTL_CD_DC           VARCHAR(500)    COMMENT '상세코드설명 [원천: BRONZE_CRM.TC_CMMN_DTL_CD]',
    CD_ATRB1            VARCHAR(100)    COMMENT '코드속성1 [원천: BRONZE_CRM.TC_CMMN_DTL_CD]',
    CD_ATRB2            VARCHAR(100)    COMMENT '코드속성2 [원천: BRONZE_CRM.TC_CMMN_DTL_CD]',
    CD_ATRB3            VARCHAR(100)    COMMENT '코드속성3 [원천: BRONZE_CRM.TC_CMMN_DTL_CD]',
    PRIMARY KEY (CD_ID, DTL_CD_ID)
) COMMENT = '공통 코드 사전 마스터. [Grain: CD_ID × DTL_CD_ID (1행=1코드값)]. [주의: 코드그룹별 상세코드 및 한글 라벨 매핑]. [원천: CRM → BRONZE_CRM.TM_CM_CODE_DTL].';

-- CRM_MKTNG_CODE — 마케팅 통합 코드 사전
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MKTNG_CODE (
    CD_ID               VARCHAR(50)     NOT NULL COMMENT '코드그룹 ID (PK · C001 마케팅캠페인 / C002 채널 / U001 UTM)',
    DTL_CD_ID           VARCHAR(50)     NOT NULL COMMENT '상세코드 ID (PK)',
    CD_NM               VARCHAR(200)    COMMENT '코드그룹명',
    DTL_CD_NM           VARCHAR(200)    COMMENT '상세코드명 (라벨)',
    SORT_ORDR           NUMBER(10,0)    COMMENT '정렬순서',
    USE_YN              VARCHAR(1)      COMMENT '사용여부 (Y/N)',
    RM                  VARCHAR(1000)   COMMENT '비고',
    CD_ATRB1            VARCHAR(100)    COMMENT '코드속성1',
    CD_ATRB2            VARCHAR(100)    COMMENT '코드속성2',
    CD_ATRB3            VARCHAR(100)    COMMENT '코드속성3',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (CD_ID, DTL_CD_ID)
) COMMENT = '마케팅 통합 코드 사전. [Grain: CD_ID × DTL_CD_ID (1행=1코드값)]. [주의: 마케팅캠페인/채널/UTM 코드 통합]. [원천: CRM → BRONZE_CRM.TC_MKTNG_DTL_CD].';

-- CRM_SEND_MEMBER_OPEN_LOG — 메시지 발송 메일 오픈 로그
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_MEMBER_OPEN_LOG (
    LOG_SEQ             NUMBER(19,0)    NOT NULL COMMENT '로그순번 (PK)',
    REQ_SEQ_NO          NUMBER(19,0)    COMMENT '발송요청순번 (→CRM_SEND_REQUEST)',
    R_NUM               NUMBER(19,0)    COMMENT '순번 (→CRM_SEND_MEMBER)',
    MBER_NO             VARCHAR(50)     COMMENT '회원번호',
    OPEN_DT             TIMESTAMP_NTZ   COMMENT '오픈일시',
    FRST_REGIST_DT      TIMESTAMP_NTZ   COMMENT '최초등록일시',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (LOG_SEQ)
) COMMENT = '메시지 발송 메일 오픈 로그. [Grain: LOG_SEQ (1행=1오픈사건)]. [원천: CRM → BRONZE_CRM.SND_MEMBER_OPEN_LOG].';

-- CRM_SEND_MEMBER_LINK_LOG — 메시지 발송 메일 링크 클릭 로그
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SEND_MEMBER_LINK_LOG (
    LOG_SEQ             NUMBER(19,0)    NOT NULL COMMENT '로그순번 (PK)',
    REQ_SEQ_NO          NUMBER(19,0)    COMMENT '발송요청순번 (→CRM_SEND_REQUEST)',
    R_NUM               NUMBER(19,0)    COMMENT '순번 (→CRM_SEND_MEMBER)',
    MBER_NO             VARCHAR(50)     COMMENT '회원번호',
    LINK_ID             VARCHAR(30)     COMMENT '링크ID',
    LINK_NM             VARCHAR(30)     COMMENT '링크명',
    LINK_PAGE           VARCHAR(255)    COMMENT '링크페이지',
    LINK_IMG_URL        VARCHAR(1024)   COMMENT '링크이미지URL',
    AGENT               VARCHAR(5)      COMMENT '접속에이전트',
    CLICK_DT            TIMESTAMP_NTZ   COMMENT '클릭일시',
    FRST_REGIST_DT      TIMESTAMP_NTZ   COMMENT '최초등록일시',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (LOG_SEQ)
) COMMENT = '메시지 발송 메일 링크 클릭 로그. [Grain: LOG_SEQ (1행=1클릭사건)]. [원천: CRM → BRONZE_CRM.SND_MEMBER_MAIL_LINK_LOG].';

-- CRM_MEMBER_CONVERT_HIST — 일시→정기 회원 전환 매핑 이력
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_CONVERT_HIST (
    MBER_NO             VARCHAR(10)     NOT NULL COMMENT '정기회원번호 (전환 후 · PK · →CRM_MEMBER)',
    ONCE_MBER_NO        VARCHAR(10)     NOT NULL COMMENT '일시후원회원번호 (전환 전 · PK)',
    FRST_REGIST_DT      TIMESTAMP_NTZ   COMMENT '전환/최초등록일시',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (MBER_NO, ONCE_MBER_NO)
) COMMENT = '일시→정기 회원 전환 매핑 이력. [Grain: MBER_NO × ONCE_MBER_NO (1행=1전환매핑)]. [주의: 회비이관 발생 건 한정]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_DT_DTLS].';

-- CRM_MEMBER_SPONSOR_SPAN — 회원×후원사업 활동구간 마스터
--   ⚠️ 월말활동회원(#51) as-of 판정용 활동구간.
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_SPONSOR_SPAN (
    MBER_NO             VARCHAR(10)     COMMENT '회원번호.',
    SPNSR_NO            VARCHAR         NOT NULL COMMENT '후원번호 (PK)',
    SPNSR_BSNS_NO       NUMBER          NOT NULL COMMENT 'SPNSR_BSNS_NO (#51).',
    SPNSR_BSNS_ID       VARCHAR         COMMENT '후원사업 ID (→CRM_SPONSORSHIP)',
    SPNSR_AMT           NUMBER(38,0)    COMMENT 'SPNSR_AMT (#52).',
    START_MONTH_KEY     NUMBER(6,0)     COMMENT '활동 개시 월키 YYYYMM.',
    DSCNTC_MONTH_KEY    NUMBER(6,0)     COMMENT '중단 월키 YYYYMM.',
    SPNSR_DSCNTC_DE     VARCHAR(8)      COMMENT '중단일 raw YYYYMMDD (원천 TEXT)',
    SPNSR_DSCNTC_YN     VARCHAR(1)      COMMENT '중단여부 raw',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    JOIN_PATH_CD         VARCHAR(3)       COMMENT '후원 가입경로 코드 raw. 코드id:MM014',
    CMPGN_CD             VARCHAR(20)      COMMENT '후원(SPNSR_NO) 등록 캠페인코드 raw [원천: BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR: 캠페인코드]',
    ACMSLT_DEPT_CD       VARCHAR(10)      COMMENT '후원(SPNSR_NO) 실적부서코드 raw [원천: 실적부서코드 (참조: TM_CM_DEPT_INFO)]',
    PRIMARY KEY (SPNSR_NO, SPNSR_BSNS_NO)
) COMMENT = '회원×후원사업 활동구간 마스터. [Grain: MBER_NO × SPNSR_BSNS_NO (1행=1활동구간)]. [주의: 시작월~중단월 기반 활동회원 as-of 판정]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT/SPNSR_DSCNTC].';

-- CRM_BIZ_TARGET — 사업목표 마스터
--   ⚠️ GOAL_TYPE_NM 유형(연사업·팀)은 같은 목표의 다른 분해다 — 섞어 합산 금지.
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_BIZ_TARGET (
    BIZ_TARGET_DK       VARCHAR         NOT NULL COMMENT '사업목표 대체키 (PK)',
    TARGET_YEAR         NUMBER(4,0)     COMMENT '목표연도 YYYY',
    MONTH_NO            NUMBER(2,0)     COMMENT '월 1~12',
    MONTH_KEY           VARCHAR(6)      COMMENT '월키 YYYYMM',
    ORG_CD              VARCHAR         COMMENT '조직코드 (FK→DIM_ORG)',
    ORG_NM              VARCHAR         COMMENT '조직 (이름조인 보완)',
    SPONSOR_BIZ_NM      VARCHAR         COMMENT '후원사업',
    CAMPAIGN_NM         VARCHAR         COMMENT '캠페인 (연결키 부재 Q10)',
    TARGET_TYPE         VARCHAR         COMMENT '목표 편성 차수: 당초(원천 BDGT_PRCD_NM=연사업) / 추경(추가경정)',
    TARGET_CNT          NUMBER(18,4)    COMMENT '목표값 — 단위는 GOAL_TYPE_NM 에 따른다(건·명·원·비율) · 지표사전 #152~155',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    GOAL_TYPE_NM        VARCHAR         COMMENT '목표 지표 유형 원천 표기 그대로(O190 · 9종): 건 = 후원사업·회원개발 / 명 = 월말활동회원 / 원 = 정기회비 / 비율 = 후원사업활동율·신규기존활동율·후원사업납입율·신규기존납입율·신규기존누계납입율. 🔴 유형마다 단위가 달라 섞어 합산하지 말 것 · 후원사업과 회원개발은 같은 개발 목표의 다른 분해(문서20 N-24)',
    CPR_DIV_NM          VARCHAR         COMMENT '법인구분 (사단/사복)',
    NEW_OLD_DIV_NM      VARCHAR         COMMENT '신규/기존 구분 원천 표기. 🔴 비율 유형에는 소계 행(합계·신규합계)이 있다 — 신규/기존과 함께 합산하면 이중계상. 회원개발 유형은 NULL',
    ORG_DIV_NM          VARCHAR         COMMENT '조직구분 (본부/지부/대면 등)',
    DTL_DIV_NM          VARCHAR         COMMENT '세부구분 원천 표기(채널 등 · 회원개발 유형만 · 그 외 NULL)',
    BDGT_PRCD_NM        VARCHAR         COMMENT '예산절차(편성 차수) 원천 표기 그대로: 연사업/추가경정 [원천: BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV: 예산절차] — TARGET_TYPE 파생 입력',
    PRIMARY KEY (BIZ_TARGET_DK)
) COMMENT = '사업목표 마스터. [Grain: TARGET_YEAR × MONTH_NO × BDGT_PRCD_NM × GOAL_TYPE_NM × 원천 구분축 (1행=1목표값)]. [주의: GOAL_TYPE_NM 별 단위가 다르다(건·명·원·비율) — 유형 필터 필수]. [원천: CRM → BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV].';

-- CRM_MARKETING_CAMPAIGN — 마케팅 캠페인 마스터
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MARKETING_CAMPAIGN (
    MK_CMPGN_CD        VARCHAR       NOT NULL COMMENT 'MK_CMPGN_CD (PK · TC_MKTNG_DTL_CD DTL_CD_ID).',
    MK_CMPGN_NM        VARCHAR       COMMENT 'MK_CMPGN_NM (TC_MKTNG_DTL_CD DTL_CD_NM).',
    USE_YN             VARCHAR       COMMENT '사용여부 Y/N. 고유값:Y,N',
    RM                 VARCHAR       COMMENT '비고',
    DW_SOURCE_SYSTEM   VARCHAR       NOT NULL COMMENT '원천 시스템 (공통감사)',
    DW_LOAD_TS         TIMESTAMP_NTZ NOT NULL COMMENT '적재 시각 (공통감사)',
    DW_UPDATE_TS       TIMESTAMP_NTZ COMMENT '갱신 시각 (공통감사)',
    DW_BATCH_ID        VARCHAR       COMMENT '배치 식별 (공통감사)',
    PRIMARY KEY (MK_CMPGN_CD)
) COMMENT = '마케팅 캠페인 마스터. [Grain: MKTG_CAMPAIGN_BK (1행=1마케팅캠페인)]. [주의: TC_MKTNG_DTL_CD C001 호환 정제]. [원천: CRM → BRONZE_CRM.TC_MKTNG_DTL_CD].';

-- CRM_CAMPAIGN_SPONSOR_BIZ_BRIDGE — 캠페인 ↔ 후원사업 다대다(1:N) 브릿지
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CAMPAIGN_SPONSOR_BIZ_BRIDGE (
    CMPGN_CD            VARCHAR(50)     NOT NULL COMMENT '캠페인코드 (PK, →CRM_CAMPAIGN)',
    SPNSR_BSNS_ID       VARCHAR(50)     NOT NULL COMMENT '후원사업ID (PK, →CRM_SPONSORSHIP)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 (공통감사)',
    PRIMARY KEY (CMPGN_CD, SPNSR_BSNS_ID)
) COMMENT = '캠페인 ↔ 후원사업 다대다(1:N) 브릿지. [Grain: CMPGN_CD × SPNSR_BSNS_ID (1행=1매핑)]. [주의: 캠페인별 복수 후원사업 귀속 해소]. [원천: CRM → BRONZE_CRM.TM_CM_CMPGN_SPNSR_BSNS].';

-- CRM_BIZ_PLACE — CRM_BIZ_PLACE — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_BIZ_PLACE (
    BPLC_CD                  VARCHAR(8)       COMMENT '사업장코드 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    NATION_CD                VARCHAR(3)       COMMENT '국가코드 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    BPLC_KORNM               VARCHAR(200)     COMMENT '사업장한글명 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    BPLC_ENGNM               VARCHAR(200)     COMMENT '사업장영문명 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    BSNS_STRT_DE             DATE             COMMENT '사업시작일 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    BSNS_END_DE              DATE             COMMENT '사업종료일 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    RELATNSP_BSNS_YN         VARCHAR(1)       COMMENT '결연사업여부 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    RELATNSP_BSNS_DSCNTC_DE  DATE             COMMENT '결연사업중단일 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    GFTMNEY_PSBL_YN          VARCHAR(1)       COMMENT '선물금가능여부 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    LETTER_PSBL_YN           VARCHAR(1)       COMMENT '서신가능여부 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    BPLC_DC                  VARCHAR(4000)    COMMENT '사업장설명 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    WTWK_FROM_DSTNC          NUMBER(10,0)     COMMENT '수도부터거리 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    CNCSN_RSN                VARCHAR(100)     COMMENT '종결사유 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    BPLC_MTCHG_MNG_YN        VARCHAR(1)       COMMENT '사업장매칭관리여부 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    FRST_REGIST_DT           TIMESTAMP_NTZ(9) COMMENT '최초등록일시 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    LAST_UPDT_DT             TIMESTAMP_NTZ(9) COMMENT '최종수정일시 [원천: BRONZE_CRM.TM_RM_BPLC_MNG]',
    DW_SOURCE_SYSTEM         VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE          VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS               TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS             TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID              VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_BIZ_PLACE — O188-F 2차-A 신설. [원천: BRONZE_CRM.TM_RM_BPLC_MNG]. [적재: dbt]';

-- CRM_CHILD — CRM_CHILD — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CHILD (
    CHILD_CD           NUMBER(10,0)     COMMENT '아동코드 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    CHILD_NO           VARCHAR(30)      COMMENT '아동번호 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    BPLC_CD            VARCHAR(8)       COMMENT '사업장코드 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    SEX                VARCHAR(2)       COMMENT '성별 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    RELATNSP_STAT_CD   VARCHAR(3)       COMMENT '결연상태코드 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    CHILD_STAT_CD      VARCHAR(3)       COMMENT '아동상태코드 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    CHILD_DTL_STAT_CD  VARCHAR(3)       COMMENT '아동상세상태코드 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    REGIST_DIV_CD      VARCHAR(3)       COMMENT '등록구분코드 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    FRST_REGIST_DT     TIMESTAMP_NTZ(9) COMMENT '최초등록일시 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    LAST_REGIST_DT     TIMESTAMP_NTZ(9) COMMENT '최종등록일시 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    RE_UPDT_DT         TIMESTAMP_NTZ(9) COMMENT '재수정일시 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    MNYRS_NATION_CD    VARCHAR(3)       COMMENT '모금국가코드 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    CMS_CHILD_NO       VARCHAR(30)      COMMENT 'CMS아동번호 [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]',
    DW_SOURCE_SYSTEM   VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE    VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS         TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS       TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID        VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_CHILD — O188-F 2차-A 신설. [원천: BRONZE_CRM.TM_RM_CHILD_MSTR_INFO]. [적재: dbt]';

-- CRM_CODE_GROUP — CRM_CODE_GROUP — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CODE_GROUP (
    CD_ID             VARCHAR(20)      COMMENT '코드ID [원천: BRONZE_CRM.TC_CMMN_CD]',
    CD_NM             VARCHAR(100)     COMMENT '코드명 [원천: BRONZE_CRM.TC_CMMN_CD]',
    CD_DC             VARCHAR(500)     COMMENT '코드설명 [원천: BRONZE_CRM.TC_CMMN_CD]',
    SORT_ORDR         NUMBER(10,0)     COMMENT '정렬순서 [원천: BRONZE_CRM.TC_CMMN_CD]',
    RM                VARCHAR(1000)    COMMENT '비고 [원천: BRONZE_CRM.TC_CMMN_CD]',
    USE_YN            VARCHAR(1)       COMMENT '사용여부 [원천: BRONZE_CRM.TC_CMMN_CD]',
    FRST_REGIST_DT    TIMESTAMP_NTZ(9) COMMENT '최초등록일시 [원천: BRONZE_CRM.TC_CMMN_CD]',
    LAST_UPDT_DT      TIMESTAMP_NTZ(9) COMMENT '최종수정일시 [원천: BRONZE_CRM.TC_CMMN_CD]',
    DW_SOURCE_SYSTEM  VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE   VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_CODE_GROUP — O188-F 2차-A 신설. [원천: BRONZE_CRM.TC_CMMN_CD]. [적재: dbt]';

-- CRM_INSTT_ACCOUNT — CRM_INSTT_ACCOUNT — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_INSTT_ACCOUNT (
    ACNUT_SER_NO      NUMBER(10,0)     COMMENT '계좌일련번호 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    CPR_DIV_CD        VARCHAR(3)       COMMENT '법인구분코드 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    ACNUT_DIV_CD      VARCHAR(3)       COMMENT '계좌구분코드 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    BANK_CD           VARCHAR(10)      COMMENT '은행코드 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    ACNUT_PRP         VARCHAR(100)     COMMENT '계좌용도 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    ACNUT_ABRV        VARCHAR(30)      COMMENT '계좌약칭 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    CHRG_DEPT_CD      VARCHAR(10)      COMMENT '담당부서코드 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    REGIST_USE_YN     VARCHAR(1)       COMMENT '등록사용여부 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    USE_YN            VARCHAR(1)       COMMENT '사용여부 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    FRST_REGIST_DT    TIMESTAMP_NTZ(9) COMMENT '최초등록일시 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    LAST_UPDT_DT      TIMESTAMP_NTZ(9) COMMENT '최종수정일시 [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]',
    DW_SOURCE_SYSTEM  VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE   VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_INSTT_ACCOUNT — O188-F 2차-A 신설. [원천: BRONZE_CRM.TM_PM_INSTT_ACNUT]. [적재: dbt]';

-- CRM_MSG_TEMPLATE — CRM_MSG_TEMPLATE — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MSG_TEMPLATE (
    SEND_CHANNEL            VARCHAR(6)       COMMENT '발송채널 — MSG_AT=알림톡 템플릿(TM_MS_AT_TMPLAT_MNG) · EMAIL=이메일 템플릿(TM_MS_EMAIL_TMPLAT_MNG) · 모델 파생(UNION 분기)',
    TEMPLATE_KEY            VARCHAR          COMMENT '템플릿 키 — 알림톡=템플릿ID(TMPLAT_ID) · 이메일=템플릿KEY(TMPLAT_KEY 문자열화) · SEND_CHANNEL 과 함께 유일',
    CPR_DIV_CD              VARCHAR(3)       COMMENT '법인구분코드 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    SNDNG_CD_ID             VARCHAR(20)      COMMENT '발신코드ID [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    SNDNG_DTL_CD_ID         VARCHAR(20)      COMMENT '발신상세코드ID [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    ATMC_YN                 VARCHAR(1)       COMMENT '자동여부 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    TIT                     VARCHAR(100)     COMMENT '제목 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    TEMPLATE_CTNT           VARCHAR          COMMENT '템플릿 본문 — 알림톡=템플릿내용(TMPLAT_CTNT) · 이메일=이메일내용(EMAIL_CTNT)',
    WRITNG_DEPT_ID          VARCHAR(20)      COMMENT '작성부서ID [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    WRITNG_DEPT_NM          VARCHAR(30)      COMMENT '작성부서명 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    CHRG_DEPT_ID            VARCHAR(20)      COMMENT '담당부서ID [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    APRV_STAT_CD            VARCHAR(3)       COMMENT '승인상태코드 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    APRV_FAILR_CTNT         VARCHAR(4000)    COMMENT '승인실패내용 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    TEMPLATE_RM             VARCHAR(4000)    COMMENT '템플릿비고(TMPLAT_RM) — 알림톡 전용 · 이메일 행은 원천 개념 부재로 NULL',
    ALTRTV_MSG_SNDNG_YN     VARCHAR(1)       COMMENT '대체메시지발신여부 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    ALTRTV_MSG_TMPLAT_KEY   NUMBER(10,0)     COMMENT '대체메시지템플릿KEY [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    ALTRTV_MSG_CTNT         VARCHAR          COMMENT '대체메시지내용 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    ALTRTV_MSG_ATCHFL_ID    VARCHAR(20)      COMMENT '대체메시지첨부파일ID [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    WRITNG_GUIDE_ATCHFL_ID  VARCHAR(20)      COMMENT '작성가이드첨부파일ID [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    USE_YN                  VARCHAR(1)       COMMENT '사용여부 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    FRST_REGIST_DT          TIMESTAMP_NTZ(9) COMMENT '최초등록일시 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    LAST_UPDT_DT            TIMESTAMP_NTZ(9) COMMENT '최종수정일시 [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]',
    DW_SOURCE_SYSTEM        VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE         VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_MSG_TEMPLATE — O188-F 2차-A 신설. [원천: BRONZE_CRM.TM_MS_AT_TMPLAT_MNG]. [적재: dbt]';

-- CRM_MSG_TEMPLATE_BUTTON — CRM_MSG_TEMPLATE_BUTTON — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MSG_TEMPLATE_BUTTON (
    TMPLAT_ID         VARCHAR(30)      COMMENT '템플릿ID [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    BTN_SEQ           NUMBER(10,0)     COMMENT '버튼순번 [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    BTN_TY_CD         VARCHAR(3)       COMMENT '버튼유형코드 [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    BTN_NM            VARCHAR          COMMENT '버튼명 [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    ANDROID_URL       VARCHAR(255)     COMMENT '안드로이드URL [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    IOS_URL           VARCHAR(255)     COMMENT 'IOSURL [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    MOBILE_URL        VARCHAR(255)     COMMENT '모바일URL [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    PC_URL            VARCHAR(255)     COMMENT 'PCURL [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    FRST_REGIST_DT    TIMESTAMP_NTZ(9) COMMENT '최초등록일시 [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    LAST_UPDT_DT      TIMESTAMP_NTZ(9) COMMENT '최종수정일시 [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]',
    DW_SOURCE_SYSTEM  VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE   VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_MSG_TEMPLATE_BUTTON — O188-F 2차-A 신설. [원천: BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST]. [적재: dbt]';

-- CRM_PAYMENT_METHOD_HIST — CRM_PAYMENT_METHOD_HIST — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_PAYMENT_METHOD_HIST (
    SETLE_KEY                 NUMBER(10,0)     COMMENT '결제KEY [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    UPDT_DT                   TIMESTAMP_NTZ(9) COMMENT '수정일시 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    MBER_NO                   VARCHAR(10)      COMMENT '회원번호 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    CPR_DIV_CD                VARCHAR(3)       COMMENT '법인구분코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    SETLE_CD                  VARCHAR(3)       COMMENT '결제코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    WTDRW_STRT_DE             DATE             COMMENT '출금시작일 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    WTDRW_ASMT_SQNC           NUMBER(3,0)      COMMENT '출금지정차수 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    FNLT_DIV_CD               VARCHAR(3)       COMMENT '금융기관구분코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    FNLT_CD                   VARCHAR(10)      COMMENT '금융기관코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    SETLE_ENTRPS_CD           VARCHAR(10)      COMMENT '결제업체코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    ACNUT_SER_NO              NUMBER(10,0)     COMMENT '카드유효기간 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    CARD_DIV_CD               VARCHAR(3)       COMMENT '카드구분코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    ETC_CTTPC_REL_CD          VARCHAR(3)       COMMENT '기타연락처관계코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    PAYER_MBER_REL_CD         VARCHAR(3)       COMMENT '결제자회원관계코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    CRTFC_MTH_CD              VARCHAR(3)       COMMENT '인증방법코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    CRTFC_DE                  DATE             COMMENT '인증일 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    FILE_SIZE                 NUMBER(10,0)     COMMENT '파일크기 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    SETLE_STAT_CD             VARCHAR(3)       COMMENT '결제상태코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    BF_SETLE_STAT_CD          VARCHAR(3)       COMMENT '이전결제상태코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    RQST_DIV_CD               VARCHAR(3)       COMMENT '신청구분코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    RCEPT_DIV_CD              VARCHAR(3)       COMMENT '접수구분코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    APRV_YN                   VARCHAR(1)       COMMENT '승인여부 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    APRV_REQUST_KEY           NUMBER(19,0)     COMMENT '승인요청KEY [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    APRV_RST_KEY              NUMBER(19,0)     COMMENT '승인결과KEY [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    FRST_BEGIN_DE             DATE             COMMENT '최초개시일 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    RQEST_EXCL_YN             VARCHAR(1)       COMMENT '청구제외여부 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    RQEST_EXCL_STRT_DE        DATE             COMMENT '청구제외시작일 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    RQEST_EXCL_END_DE         DATE             COMMENT '청구제외종료일 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    APPLCNT_ETC_CTTPC_REL_CD  VARCHAR(3)       COMMENT '신청자기타연락처관계코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    APPLCNT_MBER_REL_CD       VARCHAR(3)       COMMENT '신청자회원관계코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    BF_SETLE_KEY              NUMBER(10,0)     COMMENT '이전결제KEY [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    OPERT_DIV_CD              VARCHAR(3)       COMMENT '작업구분코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    CRTFC_TY_CD               VARCHAR(3)       COMMENT '인증유형코드 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    USE_YN                    VARCHAR(1)       COMMENT '사용여부 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    REGIST_DT                 TIMESTAMP_NTZ(9) COMMENT '등록일시 [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]',
    DW_SOURCE_SYSTEM          VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE           VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS                TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS              TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID               VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_PAYMENT_METHOD_HIST — O188-F 2차-A 신설. [원천: BRONZE_CRM.TH_PM_SETLE_INFO_HIST]. [적재: dbt]';

-- CRM_RELATION_CHANGE — CRM_RELATION_CHANGE — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_RELATION_CHANGE (
    RELATNSP_KEY      NUMBER(10,0)     COMMENT '결연KEY [원천: BRONZE_CRM.TM_RM_RELATNSP_CHG_INFO]',
    CHG_YN            VARCHAR(1)       COMMENT '교체여부 [원천: BRONZE_CRM.TM_RM_RELATNSP_CHG_INFO]',
    CHG_RSN_CD        NUMBER(10,0)     COMMENT '교체사유코드 [원천: BRONZE_CRM.TM_RM_RELATNSP_CHG_INFO]',
    CHG_RST_CD        NUMBER(10,0)     COMMENT '교체결과코드 [원천: BRONZE_CRM.TM_RM_RELATNSP_CHG_INFO]',
    CHG_PERSON_ID     VARCHAR(20)      COMMENT '교체자ID [원천: BRONZE_CRM.TM_RM_RELATNSP_CHG_INFO]',
    CHG_DE            DATE             COMMENT '교체일 [원천: BRONZE_CRM.TM_RM_RELATNSP_CHG_INFO]',
    CHG_RELATNSP_KEY  NUMBER(10,0)     COMMENT '교체결연KEY [원천: BRONZE_CRM.TM_RM_RELATNSP_CHG_INFO]',
    DW_SOURCE_SYSTEM  VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE   VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_RELATION_CHANGE — O188-F 2차-A 신설. [원천: BRONZE_CRM.TM_RM_RELATNSP_CHG_INFO]. [적재: dbt]';

-- CRM_RELATION_DEV — CRM_RELATION_DEV — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_RELATION_DEV (
    OCCRRNC_DE            VARCHAR(8)       COMMENT '발생일자 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    SER_NO                NUMBER(10,0)     COMMENT '일련번호 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    SPNSR_NO              NUMBER(19,0)     COMMENT '후원번호 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    SPNSR_BSNS_NO         NUMBER(19,0)     COMMENT '후원사업번호 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    MBER_NO               VARCHAR(10)      COMMENT '회원번호 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    SPNSR_AMT             NUMBER(19,0)     COMMENT '후원금액 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    BF_STAT_CD            VARCHAR(3)       COMMENT '이전상태코드 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    AF_STAT_CD            VARCHAR(3)       COMMENT '이후상태코드 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    RELATNSP_DVLP_DIV_CD  VARCHAR(3)       COMMENT '관계개발구분코드 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    ACCNUT_STATS_CD       VARCHAR(3)       COMMENT '회계상태코드 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    CHILD_STATS_CD        VARCHAR(3)       COMMENT '아동상태코드 [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]',
    DW_SOURCE_SYSTEM      VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE       VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS            TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS          TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID           VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_RELATION_DEV — O188-F 2차-A 신설. [원천: BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT]. [적재: dbt]';

-- CRM_SETLE_CMPNY_ACCOUNT — CRM_SETLE_CMPNY_ACCOUNT — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_SETLE_CMPNY_ACCOUNT (
    SETLE_CMPNY_ACNT_NO      NUMBER(10,0)     COMMENT '결제사계좌번호 [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    SETLE_CMPNY_ACNT_DIV_CD  VARCHAR(3)       COMMENT '결제사계좌구분코드 [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    SETLE_CMPNY_ACNT_ID      VARCHAR(20)      COMMENT '결제사계좌ID [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    CPR_DIV_CD               VARCHAR(3)       COMMENT '법인구분코드 [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    ACNT_PRP                 VARCHAR(100)     COMMENT '계좌용도 [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    ACNUT_SER_NO             NUMBER(10,0)     COMMENT '계좌일련번호 (참조: TM_PM_INSTT_ACNUT) [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    RM                       VARCHAR(1000)    COMMENT '비고 [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    USE_YN                   VARCHAR(1)       COMMENT '사용여부 [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    FRST_REGIST_DT           TIMESTAMP_NTZ(9) COMMENT '최초등록일시 [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    LAST_UPDT_DT             TIMESTAMP_NTZ(9) COMMENT '최종수정일시 [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]',
    DW_SOURCE_SYSTEM         VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE          VARCHAR          COMMENT '원천 테이블 (공통감사)',
    DW_LOAD_TS               TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS             TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID              VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'CRM_SETLE_CMPNY_ACCOUNT — O188-F 2차-A 신설. [원천: BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT]. [적재: dbt]';

-- ============================================================================
-- ERP
-- ============================================================================

-- ERP_BUDGET_ITEM — 예산 계정과목 마스터
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_BUDGET_ITEM (
    BUDGET_ITEM_DK      VARCHAR         NOT NULL COMMENT '불변 비즈니스 식별자',
    BUDGET_YEAR         NUMBER(4,0)     COMMENT '예산연도 YYYY',
    INCOME_EXPS_DIV_NM  VARCHAR         COMMENT '수입/지출 구분',
    BDGT_UNIT_NM        VARCHAR         COMMENT '예산단위 (=조직명, 코드 없음)',
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
) COMMENT = '예산 계정과목 마스터. [Grain: BDGT_ITEM_CD (1행=1예산과목)]. [주의: 장/관/항/목/세목/세세목 계층 매핑]. [원천: ERP → BRONZE_ERP.BDGT_ACMSLT_LEDGER].';

-- ERP_BUDGET — 월별 예산 편성 및 집행 원장
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_BUDGET (
    BUDGET_ITEM_DK      VARCHAR         NOT NULL COMMENT '불변 비즈니스 식별자',
    BUDGET_YEAR         NUMBER(4,0)     COMMENT '예산연도 YYYY',
    BUDGET_PROCEDURE    VARCHAR         COMMENT '예산 편성 차수 (연사업 / 추가경정 · DEC-44)',
    DVLP_INBOUND_PATH   VARCHAR         COMMENT '개발 유입경로 (원천 DVLP_INBOUND_PATH 승계)',
    BDGT_UNIT_NM        VARCHAR         COMMENT '예산단위명 (원천 BDGT_UNIT_NM 승계)',
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
    DIRECT_MNYRS_YN_1   VARCHAR         COMMENT '직접모금비1 플래그 원천 그대로 [원천: BRONZE_ERP.BDGT_ACMSLT_LEDGER: 직접모금비1] — 모금성비용 판정 입력 · 🔴 YN_1/YN_2 범위 차이 현업 회신 대기(문서20 -009)',
    DIRECT_MNYRS_YN_2   VARCHAR         COMMENT '직접모금비2 플래그 원천 그대로 [원천: BRONZE_ERP.BDGT_ACMSLT_LEDGER: 직접모금비2] — 모금성비용 판정 입력 · 🔴 YN_1/YN_2 범위 차이 현업 회신 대기(문서20 -009)',
    PRIMARY KEY (BUDGET_ITEM_DK, MONTH_NO)
) COMMENT = '월별 예산 편성 및 집행 원장. [Grain: BDGT_ITEM_CD × DEPT_ID × MONTH_KEY (1행=1월예산)]. [주의: 12개월 wide 컬럼을 월 long으로 언피벗]. [원천: ERP → BRONZE_ERP.BDGT_ACMSLT_LEDGER].';

-- ERP_BUDGET_YEARLY — 연도별 예산 총액 원장
--   ⚠️ 연 총액 grain — 월 grain 인 ERP_BUDGET 에 합치면 12배 과대.
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_BUDGET_YEARLY (
    BUDGET_ITEM_DK      VARCHAR         NOT NULL COMMENT '불변 비즈니스 식별자',
    BUDGET_YEAR         NUMBER(4,0)     NOT NULL COMMENT '예산연도 YYYY . 본 테이블의 grain 은 **연**이다.',
    BUDGET_PROCEDURE    VARCHAR         COMMENT '예산 편성 차수 (연사업 / 추가경정 · DEC.',
    YEAR_BDGT_TOT_AMT   NUMBER(38,0)    COMMENT 'YEAR_BDGT_TOT_AMT.',
    CHN_BDGT_TOT_AMT    NUMBER(38,0)    COMMENT '연 추경예산 총액 원단위 = 원천 CHN_BDGT_TOT_AMT.',
    ADJ_BDGT_TOT_AMT    NUMBER(38,0)    COMMENT '연 조정예산 총액 원단위 = 원천 ADJ_BDGT_TOT_AMT.',
    EXEC_TOT_AMT        NUMBER(38,0)    COMMENT '연 집행 총액 원단위 = 원천 EXEC_TOT_AMT.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (BUDGET_ITEM_DK, BUDGET_YEAR)
) COMMENT = '연도별 예산 총액 원장. [Grain: BDGT_ITEM_CD × DEPT_ID × YEAR (1행=1연예산)]. [주의: 연 총액 편성/집행액 관리]. [원천: ERP → BRONZE_ERP.BDGT_ACMSLT_LEDGER].';

-- ============================================================================
-- AGENCY (코어·staging·위성)
-- ============================================================================
--   ⚠️ AD_PERF_DK 는 staging 3종(AGENCY_AD_ROW_*)에서만 발급한다 — 코어·위성·GOLD 는 승계만(재계산 금지).
--   ⚠️ staging 은 BRONZE 컬럼명·타입을 그대로 보존한다(개명·형변환 금지 · 정제는 코어/위성).
--   ⚠️ 텍스트 시간축(YEAR·MONTH 등) 파싱 금지 — DATE 컬럼에서 파생. 예외 DGT 는 코어에서만 COALESCE(DATE, TRY_TO_DATE(…)) 폴백. DATE_FROM_PARTS 금지(불량 월/일 롤오버).

-- AGENCY_AD_CREATIVE — 광고 소재/매체 통합 차원
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_CREATIVE (
    CREATIVE_DK         VARCHAR         NOT NULL COMMENT '불변 비즈니스 식별자',
    SOURCE_SYSTEM       VARCHAR         NOT NULL COMMENT '소스 시스템 (DIGITAL/REBROADCAST/VIDEO).',
    MEDIA_CHANNEL_NM    VARCHAR         COMMENT '매체/채널명',
    CREATIVE_NM         VARCHAR         COMMENT '소재명',
    CREATIVE_TYPE_NM    VARCHAR         COMMENT '소재유형/RT유형/캠페인유형',
    CM_AREA_NM          VARCHAR         COMMENT 'CM위치 (VIDEO)',
    AD_SEC_NM           VARCHAR         COMMENT '초수 (VIDEO)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (CREATIVE_DK)
) COMMENT = '광고 소재/매체 통합 차원. [Grain: MEDIA_NM × PLATFORM_NM × CREATIVE_NM (1행=1소재)]. [주의: 디지털/비디오/재방송 3소스 소재 결합]. [원천: AGENCY 3소스 → BRONZE_AGENCY].';

-- AGENCY_AD_PERFORMANCE — 광고 성과 통합 원장
--   ⚠️ 상위캠페인 자리에 utm 을 넣지 않는다(utm 은 AGENCY_AD_ROW_DGT 에 보존).
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_PERFORMANCE (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '불변 비즈니스 식별자',
    AD_SOURCE_TYPE      VARCHAR         NOT NULL COMMENT 'AD_SOURCE_TYPE.',
    SOURCE_SYSTEM       VARCHAR         NOT NULL COMMENT '소스 시스템.',
    AD_DATE             DATE            COMMENT '광고 집행일자',
    AD_YEAR             NUMBER(4,0)     COMMENT '광고 집행연도 YYYY',
    AD_MONTH            NUMBER(2,0)     COMMENT '광고 집행월 1~12',
    CAMPAIGN_NM         VARCHAR         COMMENT '캠페인명',
    UPPER_CAMPAIGN_NM   VARCHAR         COMMENT '상위 캠페인명 (VIDEO 전용)',
    MEDIA_CHANNEL_NM    VARCHAR         COMMENT '매체/채널명',
    DEVICE_NM           VARCHAR         COMMENT '디바이스 (DGT만)',
    CREATIVE_NM         VARCHAR         COMMENT '소재명',
    PROGRAM_NM          VARCHAR         COMMENT '프로그램명 (REBRDC/VIDEO)',
    IMPRESSION_CNT      NUMBER(38,4)    COMMENT '노출수 (DGT만)',
    CLICK_CNT           NUMBER(38,4)    COMMENT '클릭수 (DGT만)',
    CONV_MEMBER_CNT     NUMBER(38,4)    COMMENT 'GA 전환 명수 (DIGITAL 전용)',
    CONV_UNIT_CNT       NUMBER(38,4)    COMMENT 'GA 전환 VU/건수 (DIGITAL 전용)',
    INBOUND_CALL_CNT    NUMBER(38,4)    COMMENT '인입콜 수 (REBRDC+VIDEO)',
    CONV_CALL_CNT       NUMBER(38,4)    COMMENT 'VIDEO 전환콜',
    AD_CNT              NUMBER(38,4)    COMMENT '광고횟수 (REBRDC/VIDEO)',
    AD_COST             NUMBER(38,4)    COMMENT '광고비 (소스별 컬럼 상이)',
    COST_TYPE           VARCHAR         COMMENT '비용유형 (GA/편성/집행)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    CONTENTS_PUR_COST   NUMBER(38,4)    COMMENT '콘텐츠구입비(원) (REBROADCAST 전용 · 그 외 원천 개념 부재 NULL)',
    CALL_CTR_OPER_COST  NUMBER(38,4)    COMMENT '콜센터운영비(원) (REBROADCAST 전용 · 그 외 원천 개념 부재 NULL)',
    TOT_COST            NUMBER(38,4)    COMMENT '총비용(원) = 편성비(AD_COST)+콘텐츠구입비+콜센터운영비 (REBROADCAST 전용 · 그 외 NULL)'
) COMMENT = '광고 성과 통합 원장. [Grain: AD_PERF_DK (1행=1광고성과)]. [주의: 디지털/방송 3원천 성과 지표 통합]. [원천: AGENCY 3소스 → BRONZE_AGENCY].';

-- AGENCY_AD_ROW_DGT — 디지털 광고 원천 무손실 Staging
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_ROW_DGT (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '행 식별자 — 본 테이블이 발급 단일지점',
    AD_SOURCE_TYPE      VARCHAR         NOT NULL COMMENT '광고유형 상수 DIGITAL',
    ROW_HASH            VARCHAR(32)     COMMENT '원천 전컬럼 해시',
    DUP_SEQ             NUMBER(9,0)     COMMENT '전컬럼 중복 그룹 내 순번',
    TIME                VARCHAR         COMMENT '[원천보존] 시간',
    YEAR                VARCHAR         COMMENT '[원천보존] 연도 텍스트',
    BDGT_SOURCE_NM      VARCHAR         COMMENT '[원천보존] 예산출처',
    CMPGN_TYPE1_BSN_NM  VARCHAR         COMMENT '[원천보존] 캠페인유형1',
    CMPGN_TYPE2_BSN_NM  VARCHAR         COMMENT '[원천보존] 캠페인유형2',
    CMPGN_TYPE_BSN_NM   VARCHAR         COMMENT '[원천보존] 캠페인유형',
    AD_TY_NM            VARCHAR         COMMENT '[원천보존] 광고유형명',
    MONTH               VARCHAR         COMMENT '[원천보존] 월 텍스트',
    DEVICE              VARCHAR         COMMENT '[원천보존] 기기 M/PC',
    MEDIA_NM            VARCHAR         COMMENT '[원천보존] 매체명',
    WEEK                VARCHAR         COMMENT '[원천보존] 주차 텍스트',
    DAY                 VARCHAR         COMMENT '[원천보존] 일 텍스트',
    DOW                 VARCHAR         COMMENT '[원천보존] 요일 텍스트',
    CMPGN_NM            VARCHAR         COMMENT '[원천보존] 캠페인명',
    MATR                VARCHAR         COMMENT '[원천보존] 소재명',
    MATR_TY_NM          VARCHAR         COMMENT '[원천보존] 소재유형명',
    EXPS_CNT            FLOAT           COMMENT '[원천보존] 노출수',
    CLICK_CNT           FLOAT           COMMENT '[원천보존] 클릭수',
    AD_COST             FLOAT           COMMENT '[원천보존] 광고비 (구 GA_AD_COST · 코어 AD_COST 원천)',
    SPNSER_MBER_CNT     FLOAT           COMMENT '[원천보존] 후원자수(명) (구 GA_CONV_MBER_CNT · 코어 CONV_MEMBER_CNT 원천)',
    CONV_VU_CNT         FLOAT           COMMENT '[원천보존] 전환가치(건)',
    CPA                 FLOAT           COMMENT '[원천보존] 대행사 산정 CPA (비가산)',
    DVLP_UNIT_PRICE     FLOAT           COMMENT '[원천보존] 대행사 산정 개발단가 (비가산 · 구 DEV_UNIT_PRICE)',
    CTR                 FLOAT           COMMENT '[원천보존] 대행사 산정 CTR (비가산)',
    CVR                 FLOAT           COMMENT '[원천보존] 대행사 산정 CVR (비가산)',
    CPC                 FLOAT           COMMENT '[원천보존] 대행사 산정 CPC (비가산)',
    CPM                 FLOAT           COMMENT '[원천보존] 대행사 산정 CPM (비가산)',
    UTM_CMPGN_NM        VARCHAR         COMMENT '[원천보존] utm_campaign (구 CMPGN_UTM_NM)',
    READ_CNT            FLOAT           COMMENT '[원천보존] 조회수',
    MEDIA_PTNT_CUST_CNT FLOAT           COMMENT '[원천보존] 잠재고객수(매체)',
    DATE                DATE            COMMENT '[원천보존] 날짜. ⚠️ 1970-01-01(에포크 기본값) 행이 있다 — 코어가 텍스트축으로 보정',
    VTR                 FLOAT           COMMENT '[원천보존] 대행사 산정 VTR (비가산)',
    PAGE_TYPE_NM        VARCHAR         COMMENT '[원천보존] 지면구분',
    CRM_DVLP_CNT        FLOAT           COMMENT '[원천보존] CRM개발건수',
    AD_GRP_NM           VARCHAR         COMMENT '[원천보존] 광고그룹명',
    GRP_DIV_NM          VARCHAR         COMMENT '[원천보존] 그룹구분',
    MARKUP_AMT          FLOAT           COMMENT '[원천보존] 마크업 (O182 신규 · 코어 광고비 미포함)',
    VAT_AMT             FLOAT           COMMENT '[원천보존] 부가세 (O182 신규 · 코어 광고비 미포함)',
    LAST_STMT_AMT       FLOAT           COMMENT '[원천보존] 최종정산금액 (O182 신규 · 광고비+마크업+부가세)',
    TOTAL_CPA           FLOAT           COMMENT '[원천보존] 통합CPA (O182 신규 · 비가산)',
    TOTAL_DVLP_UNIT_PRICE FLOAT         COMMENT '[원천보존] 통합개발단가 (O182 신규 · 비가산)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = '디지털 광고 원천 무손실 Staging. [Grain: AD_PERF_DK (1행=1디지털광고)]. [주의: 디지털 광고 원천 41컬럼 보존(2026-09-28 원천 재편)]. [원천: AGENCY → BRONZE_AGENCY.DGT_AD_CMPGN_DTLS].';

-- AGENCY_AD_ROW_VIDEO — 비디오 방송 광고 원천 무손실 Staging
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_ROW_VIDEO (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '행 식별자 — 본 테이블이 발급 단일지점',
    AD_SOURCE_TYPE      VARCHAR         NOT NULL COMMENT '광고유형 상수 VIDEO',
    ROW_HASH            VARCHAR(32)     COMMENT '원천 전컬럼 해시',
    DUP_SEQ             NUMBER(9,0)     COMMENT '전컬럼 중복 그룹 내 순번(최대 3중복)',
    CHNNL_NM            VARCHAR         COMMENT '[원천보존] 채널명',
    DOW                 VARCHAR         COMMENT '[원천보존] 요일 텍스트',
    BRDC_DATE           DATE            COMMENT '[원천보존] 송출일. ⚠️ CTV 시트 행은 NULL — 코어가 텍스트축으로 보정',
    TIME_RNG            VARCHAR         COMMENT '[원천보존] 시간대',
    DAY_DIV_NM          VARCHAR         COMMENT '[원천보존] 요일구분(주중/토/일)',
    PRG_STRT_TIME       VARCHAR         COMMENT '[원천보존] 프로그램 시작시간',
    SCHDL_NM            VARCHAR         COMMENT '[원천보존] 편성명',
    CM                  VARCHAR         COMMENT '[원천보존] CM 구분',
    CM_AREA             VARCHAR         COMMENT '[원천보존] CM위치',
    AD_STRT_TIME        VARCHAR         COMMENT '[원천보존] 광고시작시간',
    AD_END_TIME         VARCHAR         COMMENT '[원천보존] 광고종료시간',
    SPOT_TY             VARCHAR         COMMENT '[원천보존] SPOT유형',
    AD_VIEW_RT          FLOAT           COMMENT '[원천보존] 광고시청률 (비가산)',
    AD_CNT              FLOAT           COMMENT '[원천보존] 광고횟수',
    AD_SEC              VARCHAR         COMMENT '[원천보존] 광고 초수(TEXT)',
    LAST_AD_COST        FLOAT           COMMENT '[원천보존] 최종광고비(원) (구 ACTL_PUR_AD_COST_KRW · 코어 AD_COST 원천)',
    INBOUND_CALL_CNT    FLOAT           COMMENT '[원천보존] 인입콜수',
    CPC_CALL_CNT        FLOAT           COMMENT '[원천보존] 대행사 산정 콜당 단가(CPC_CALL · 비가산 · 구 CPC TEXT)',
    UPPER_CMPGN_NM      VARCHAR         COMMENT '[원천보존] 상위 캠페인명',
    MATR_NM             VARCHAR         COMMENT '[원천보존] 소재명',
    DMST_OVSEA_DIV_NM   VARCHAR         COMMENT '[원천보존] 캠페인유형(국내/해외)',
    BSNS_CASE_DIV_NM    VARCHAR         COMMENT '[원천보존] 캠페인유형(사업/사례)',
    CMPGN_TY_NM         VARCHAR         COMMENT '[원천보존] 캠페인유형명',
    CHNNL_CMPNY_TY_NM   VARCHAR         COMMENT '[원천보존] 채널사유형',
    WEEK                VARCHAR         COMMENT '[원천보존] 주차 텍스트',
    MONTH               VARCHAR         COMMENT '[원천보존] 월 텍스트 (O182 신규 · 「03월」 형태 혼재)',
    AD_TY_NM            VARCHAR         COMMENT '[원천보존] 광고유형 TV/CTV/기타/미확인 (O182 신규 · 구 CTV_DIV_NM 자리)',
    BDGT_SOURCE_NM      VARCHAR         COMMENT '[원천보존] 예산출처 (O182 신규)',
    DEVICE_NM           VARCHAR         COMMENT '[원천보존] 기기 (O182 신규)',
    YEAR                VARCHAR         COMMENT '[원천보존] 연도 텍스트',
    DAY                 VARCHAR         COMMENT '[원천보존] 일자 텍스트 (O182 신규)',
    SPNSER_CNT          FLOAT           COMMENT '[원천보존] 후원자수 (O182 신규 · 위성 DVLP_MEMBER_CNT 원천)',
    DVLP_CNT            FLOAT           COMMENT '[원천보존] 개발건수 (O182 신규 · 위성 DVLP_CNT 원천)',
    CMPGN_NM            VARCHAR         COMMENT '[원천보존] 캠페인명 (O182 신규 · 구 MKT_CMPGN_NM 자리 · CTV 시트만 채움)',
    MATR_TY_NM          VARCHAR         COMMENT '[원천보존] 소재유형 (O182 신규)',
    EXPSR_CNT           FLOAT           COMMENT '[원천보존] 노출수 (O182 신규)',
    CLICK_CNT           FLOAT           COMMENT '[원천보존] 클릭수 (O182 신규)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = '비디오 방송 광고 원천 무손실 Staging. [Grain: AD_PERF_DK (1행=1비디오광고)]. [주의: 방송 광고 원천 37컬럼 보존(2026-09-28 원천 재편)]. [원천: AGENCY → BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS].';

-- AGENCY_AD_ROW_REBRDC — 재방송 광고 원천 무손실 Staging
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_ROW_REBRDC (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '행 식별자 — 본 테이블이 발급 단일지점',
    AD_SOURCE_TYPE      VARCHAR         NOT NULL COMMENT '광고유형 상수 REBROADCAST',
    ROW_HASH            VARCHAR(32)     COMMENT '원천 전컬럼 해시',
    DUP_SEQ             NUMBER(9,0)     COMMENT '전컬럼 중복 그룹 내 순번.',
    DIV_NM              VARCHAR         COMMENT '[원천보존] 구분 (재송출/방송 · 하류 RT_TYPE 원천)',
    YEAR                VARCHAR         COMMENT '[원천보존] 연도 텍스트',
    MONTH               VARCHAR         COMMENT '[원천보존] 월 텍스트 (O182 신규)',
    DAY                 VARCHAR         COMMENT '[원천보존] 일 텍스트 (O182 신규)',
    CHNNL_NM            VARCHAR         COMMENT '[원천보존] 채널 (구 CHNNL_CMPNY)',
    BRDC_DATE           DATE            COMMENT '[원천보존] 방송일자 (구 DATE)',
    DOW                 VARCHAR         COMMENT '[원천보존] 요일 텍스트',
    WEEK                VARCHAR         COMMENT '[원천보존] 주차 텍스트',
    BRDC_TIME           VARCHAR         COMMENT '[원천보존] 방송시각',
    BRDC_NM             VARCHAR         COMMENT '[원천보존] 방송명',
    BRDC_DIV_NM         VARCHAR         COMMENT '[원천보존] 방송구분',
    AD_CNT              FLOAT           COMMENT '[원천보존] 횟수',
    INBOUND_CALL_CNT    VARCHAR         COMMENT '[원천보존] 인입콜수(TEXT)',
    DVLP_MBER_CNT       FLOAT           COMMENT '[원천보존] 개발(명)',
    DVLP_CNT            FLOAT           COMMENT '[원천보존] 개발(건)',
    UPPER_CMPGN_CD      VARCHAR         COMMENT '[원천보존] 상위캠페인코드 (O182 신규 · 실측 전건 NULL)',
    CMPGN_CD            VARCHAR         COMMENT '[원천보존] 캠페인코드 (O182 신규 · 실측 전건 NULL)',
    BRDC_SCHDL_COST     FLOAT           COMMENT '[원천보존] 편성비 (코어 AD_COST 원천 · 연속성 유지 결정)',
    CONTENTS_PUR_COST   FLOAT           COMMENT '[원천보존] 콘텐츠구입비 (O182 신규)',
    CALL_CTR_OPER_COST  FLOAT           COMMENT '[원천보존] 콜센터운영비 (O182 신규)',
    TOT_COST            FLOAT           COMMENT '[원천보존] 총비용 = 편성비+콘텐츠구입비+콜센터운영비 (O182 신규 · 실측 전건 일치)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = '재방송 광고 원천 무손실 Staging. [Grain: AD_PERF_DK (1행=1재방송광고)]. [주의: 원천 컬럼 무손실 보존]. [원천: AGENCY → BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS].';

-- AGENCY_AD_DIGITAL — 디지털 광고 고유속성 위성
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_DIGITAL (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '코어 1:1 조인키(staging 발급값 승계)',
    PAGE_TYPE_NM        VARCHAR         COMMENT '페이지유형',
    AD_GRP_NM           VARCHAR         COMMENT '광고그룹명',
    GRP_DIV_NM          VARCHAR         COMMENT '그룹구분',
    MATR_TY_NM          VARCHAR         COMMENT '소재유형',
    AD_TY_NM            VARCHAR         COMMENT '광고유형명(대행사 표기)',
    READ_CNT            FLOAT           COMMENT '읽음수 (가산)',
    MEDIA_PTNT_CUST_CNT FLOAT           COMMENT '매체 잠재고객수 (가산)',
    CRM_DVLP_CNT        FLOAT           COMMENT 'CRM 개발건수 (가산). [사유:규칙 미확정]',
    CTR_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CTR',
    CVR_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CVR',
    CPC_CLICK_SRC      FLOAT           COMMENT '[비가산] 대행사 산정 **클릭당** 단가 (O174 개명)',
    CPM_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CPM',
    CPA_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CPA',
    DEV_UNIT_PRICE_SRC  FLOAT           COMMENT '대행사 산정 개발단가.',
    VTR_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 VTR (재계산 불가)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = '디지털 광고 고유속성 위성. [Grain: AD_PERF_DK (코어 1:1)]. [주의: 매체사 산정 CTR/CVR/CPC 비율 지표]. [원천: AGENCY → BRONZE_AGENCY.DGT_AD_CMPGN_DTLS].';

-- AGENCY_AD_BROADCAST — 방송 광고 고유속성 위성
--   ⚠️ [VIDEO 전용]/[REBRDC 전용] 컬럼의 NULL = 해당 원천에 항목 없음 — 비율 분모는 해당 원천 행만.
--   ⚠️ 시간 파싱에 TRY_TO_TIME 금지(값을 조용히 바꾼다) · 숫자 3종은 단위 미확정이라 NULL.
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_BROADCAST (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '코어 1:1 조인키(staging 발급값 승계)',
    TIME_BAND           VARCHAR         COMMENT '시간대',
    CM_POSITION         VARCHAR         COMMENT 'CM위치 [VIDEO 전용]',
    RT_TYPE             VARCHAR         COMMENT 'RT(재방송)유형 [REBRDC 전용]',
    AD_START_TIME       VARCHAR         COMMENT '광고시작시간 [VIDEO 전용]',
    AD_END_TIME         VARCHAR         COMMENT '광고종료시간 [VIDEO 전용]',
    BROADCAST_DATE      DATE            COMMENT '송출일',
    PROGRAM_NM          VARCHAR         COMMENT '프로그램/편성명',
    CHANNEL_COMPANY     VARCHAR         COMMENT '채널사',
    CHANNEL_COMPANY_TYPE VARCHAR        COMMENT '채널사유형 [VIDEO 전용]',
    SPOT_TYPE           VARCHAR         COMMENT 'SPOT유형 [VIDEO 전용]',
    DURATION_SEC        NUMBER(9,0)     COMMENT '광고 초수. [사유:규칙 미확정]',
    DAY_DIV             VARCHAR         COMMENT '요일구분 평일/주말 [VIDEO 전용]',
    PRG_START_TIME      VARCHAR         COMMENT '프로그램 시작시간 [VIDEO 전용]',
    CTV_DIV             VARCHAR         COMMENT 'CTV구분 [VIDEO 전용]',
    BRDC_DIV            VARCHAR         COMMENT '방송구분 [REBRDC 전용]',
    AD_CNT              FLOAT           COMMENT '광고횟수 (가산)',
    CONV_CALL_CNT       FLOAT           COMMENT '전환콜 [VIDEO 전용]',
    DVLP_MEMBER_CNT     FLOAT           COMMENT '개발회원수 [REBRDC 전용.',
    DVLP_CNT            FLOAT           COMMENT '개발건수 [REBRDC 전용.',
    AD_VIEW_RT_SRC      FLOAT           COMMENT '[비가산] 광고시청률 [VIDEO 전용]',
    CPC_CALL_SRC       FLOAT           COMMENT '[비가산] 대행사 산정 **콜당** 단가 [VIDEO 전용] — 🔴 클릭 분모가 아니다(O174 개명)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = '방송 광고 고유속성 위성. [Grain: AD_PERF_DK (코어 1:1)]. [주의: 시청률/송출시간/SPOT구분 방송 속성]. [원천: AGENCY → BRONZE_AGENCY.VIDEO/REBRDC_AD_CMPGN_DTLS].';

-- AGENCY_AD_BROADCAST_CASE — 재방송 사례 정규화 언피벗 위성
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_BROADCAST_CASE (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '코어 조인키(1:N)',
    CASE_SEQ            NUMBER(2,0)     NOT NULL COMMENT '사례 순번 1~3',
    BIZ_DIV             VARCHAR         COMMENT '사업구분',
    FAMILY_TYPE         VARCHAR         COMMENT '가족유형',
    APPEAL_POINT        VARCHAR         COMMENT '어필포인트',
    CASE_DIV            VARCHAR         COMMENT '사례구분',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK, CASE_SEQ)
) COMMENT = '재방송 사례 정규화 언피벗 위성. [Grain: AD_PERF_DK × CASE_SEQ (1행=1사례)]. [주의: 반복군 15컬럼을 언피벗 정규화]. [원천: AGENCY → BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS].';

-- ============================================================================
-- BIGQUERY (GA4)
-- ============================================================================
--   ⚠️ 입력 = source(silver_external.BIGQUERY_REFINED_DATA) — 외부 Python 적재 테이블이라 이 파일에서 만들지 않는다.

-- BIGQUERY_BASIC — BIGQUERY 웹/앱 이벤트 기본 Staging
--   ⚠️ EVENT_SEQ 는 PK 유일성만 보장 — 재실행 간 순번 안정성은 미보장(GA4-SEQ-1).
--   ⚠️ 적재 = 롤링 윈도우 증분 — [오늘-bigquery_lookback_days, 9999-12-31] 창만 DELETE 후 재적재(멱등) · 창보다 오래 건너뛴 구멍은 OPS.WARN_BIGQUERY_LOAD_GAP 이 감시.
CREATE OR REPLACE TABLE GN_DW.SILVER.BIGQUERY_BASIC (
    USER_PSEUDO_ID          VARCHAR(200)    NOT NULL COMMENT '세션 스파인 (PK)',
    EVENT_TIMESTAMP         NUMBER          NOT NULL COMMENT 'UTC microsec (PK)',
    EVENT_NAME              VARCHAR(200)    NOT NULL COMMENT '이벤트명 (PK)',
    EVENT_SEQ               NUMBER          NOT NULL COMMENT 'EVENT_SEQ.',
    EVENT_DATE              VARCHAR(8)      COMMENT '원본 YYYYMMDD',
    EVENT_DT                DATE            NOT NULL COMMENT '업무일자 DATE.',
    EVENT_TS                TIMESTAMP_NTZ   COMMENT '파생 TIMESTAMP',
    USER_ID                 VARCHAR(64)     COMMENT 'BIGQUERY user_id 원본(불변 보존). USER_ID 사용.',
    ID_SCHEME               VARCHAR(20)     COMMENT 'ID_SCHEME.',
    BIGQUERY_SESSION_ID     NUMBER          COMMENT 'BigQuery 세션ID(EP_GA_SESSION_ID TRY_CAST).',
    BIGQUERY_SESSION_NUMBER NUMBER          COMMENT 'BigQuery 세션 번호(EP_GA_SESSION_NUMBER TRY_CAST).',
    BIGQUERY_SESSION_KEY    VARCHAR         COMMENT '파생 세션 자연키 = user_pseudo_id ∥ ".',
    SESSION_ENGAGED         VARCHAR(5)      COMMENT '세션 engaged 여부(EP_SESSION_ENGAGED).',
    ENGAGEMENT_TIME_MSEC    NUMBER          COMMENT 'ENGAGEMENT_TIME_MSEC.',
    PAGE_LOCATION           VARCHAR         COMMENT '페이지 URL(EP_PAGE_LOCATION)',
    PAGE_TITLE              VARCHAR         COMMENT '페이지 제목(EP_PAGE_TITLE)',
    PAGE_REFERRER           VARCHAR         COMMENT '리퍼러 URL(EP_PAGE_REFERRER)',
    EVENT_CATEGORY          VARCHAR         COMMENT 'EVENT_CATEGORY.',
    EVENT_ACTION            VARCHAR         COMMENT '이벤트 액션(EP_EVENT_ACTION, 센티넬 NULLIF).',
    EVENT_LABEL             VARCHAR         COMMENT '이벤트 라벨(EP_EVENT_LABEL, 센티넬 NULLIF).',
    PERCENT_SCROLLED        NUMBER          COMMENT 'PERCENT_SCROLLED.',
    LINK_URL                VARCHAR         COMMENT '클릭 링크 URL(EP_LINK_URL)',
    LINK_TEXT               VARCHAR         COMMENT '클릭 링크 텍스트(EP_LINK_TEXT)',
    DEVICE_TYPE             VARCHAR(10)     COMMENT 'DEVICE_TYPE.',
    DEVICE_CATEGORY         VARCHAR         COMMENT '디바이스 카테고리(원본)',
    OS                      VARCHAR         COMMENT '운영체제(DEVICE_OPERATING_SYSTEM)',
    BROWSER                 VARCHAR         COMMENT '브라우저(DEVICE_WEB_INFO_BROWSER)',
    LANGUAGE                VARCHAR         COMMENT '언어(DEVICE_LANGUAGE)',
    PLATFORM                VARCHAR(50)     COMMENT '플랫폼(원본)',
    IS_ACTIVE_USER          BOOLEAN         COMMENT '활성 사용자 여부(원본)',
    GEO_COUNTRY             VARCHAR         COMMENT '국가(원본)',
    GEO_CITY                VARCHAR         COMMENT '도시(원본)',
    UTM_SOURCE              VARCHAR         COMMENT 'UTM_SOURCE.',
    UTM_MEDIUM              VARCHAR         COMMENT 'UTM_MEDIUM.',
    UTM_CAMPAIGN            VARCHAR         COMMENT 'UTM_CAMPAIGN.',
    UTM_CONTENT             VARCHAR         COMMENT 'UTM content(STSLC_MC_CONTENT)',
    UTM_TERM                VARCHAR         COMMENT 'UTM term(STSLC_MC_TERM)',
    SOURCE_MEDIUM           VARCHAR         COMMENT 'SOURCE_MEDIUM.',
    XCHAN_SOURCE            VARCHAR         COMMENT 'XCHAN_SOURCE.',
    XCHAN_MEDIUM            VARCHAR         COMMENT 'XCHAN_MEDIUM.',
    XCHAN_CAMPAIGN          VARCHAR         COMMENT 'XCHAN_CAMPAIGN.',
    DEFAULT_CHANNEL_GROUP   VARCHAR         COMMENT 'DEFAULT_CHANNEL_GROUP.',
    GAC_AD_GROUP_ID         VARCHAR         COMMENT 'GAC_AD_GROUP_ID.',
    GAC_AD_GROUP_NAME       VARCHAR         COMMENT 'GAC_AD_GROUP_NAME.',
    GAC_CAMPAIGN_NAME       VARCHAR         COMMENT 'GAC_CAMPAIGN_NAME.',
    BATCH_ORDERING_ID       NUMBER          COMMENT 'BATCH_ORDERING_ID.',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE         VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, EVENT_SEQ)
) COMMENT = 'BIGQUERY 웹/앱 이벤트 기본 Staging. [Grain: EVENT_DT × EVENT_SEQ (1행=1이벤트)]. [주의: 타입 캐스팅 정제 · 롤링 윈도우 증분 적재]. [원천: BIGQUERY → BRONZE_BIGQUERY.EVENTS].';

-- BIGQUERY_TRAFFIC_SOURCE — BIGQUERY 트래픽 소스 차원
CREATE OR REPLACE TABLE GN_DW.SILVER.BIGQUERY_TRAFFIC_SOURCE (
    UTM_SOURCE              VARCHAR         COMMENT 'UTM source',
    UTM_MEDIUM              VARCHAR         COMMENT 'UTM medium',
    UTM_CAMPAIGN            VARCHAR         COMMENT 'UTM campaign',
    UTM_CONTENT             VARCHAR         COMMENT 'UTM content',
    UTM_TERM                VARCHAR         COMMENT 'UTM term',
    SOURCE_MEDIUM           VARCHAR         COMMENT '파생 source / medium',
    XCHAN_SOURCE            VARCHAR         COMMENT 'cross_channel source',
    XCHAN_MEDIUM            VARCHAR         COMMENT 'cross_channel medium',
    XCHAN_CAMPAIGN          VARCHAR         COMMENT 'cross_channel campaign',
    DEFAULT_CHANNEL_GROUP   VARCHAR         COMMENT '기본 채널그룹',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE         VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'BIGQUERY 트래픽 소스 차원. [Grain: SOURCE × MEDIUM × CAMPAIGN (1행=1소스)]. [주의: 세션 획득 채널 분류]. [원천: BIGQUERY → BRONZE_BIGQUERY.EVENTS].';

-- BIGQUERY_EVENT_DIM — BIGQUERY 이벤트 분류 차원
CREATE OR REPLACE TABLE GN_DW.SILVER.BIGQUERY_EVENT_DIM (
    EVENT_NAME          VARCHAR(200)    NOT NULL COMMENT '이벤트명 (그레인 핵심키)',
    EVENT_CATEGORY      VARCHAR         COMMENT '이벤트 카테고리',
    EVENT_LABEL         VARCHAR         COMMENT '이벤트 라벨 (혼합타입)',
    EVENT_ACTION        VARCHAR         COMMENT '이벤트 액션',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'BIGQUERY 이벤트 분류 차원. [Grain: EVENT_NAME × PARAM_NAME (1행=1이벤트분류)]. [주의: 주요 웹/앱 이벤트 정의]. [원천: BIGQUERY → BRONZE_BIGQUERY.EVENTS].';

-- BIGQUERY_DEVICE — BIGQUERY 디바이스 차원
CREATE OR REPLACE TABLE GN_DW.SILVER.BIGQUERY_DEVICE (
    DEVICE_TYPE         VARCHAR(10)     NOT NULL COMMENT '디바이스 유형 파생. 값 = PC / M (APP 휴면·O2).',
    PLATFORM            VARCHAR(50)     COMMENT '플랫폼. 값 = WEB (ANDROID/IOS 미입고). [사유:원천 미입고]',
    DEVICE_CATEGORY     VARCHAR         COMMENT '디바이스 카테고리 (원본)',
    OS                  VARCHAR         COMMENT '운영체제',
    BROWSER             VARCHAR         COMMENT '브라우저',
    LANGUAGE            VARCHAR         COMMENT '언어',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'BIGQUERY 디바이스 차원. [Grain: DEVICE_CATEGORY × OPERATING_SYSTEM (1행=1디바이스)]. [주의: 접속 기기 및 OS 분류]. [원천: BIGQUERY → BRONZE_BIGQUERY.EVENTS].';

-- BIGQUERY_EVENT — BIGQUERY 사용자 행동 팩트 소스
--   ⚠️ EVENT_SEQ 는 PK 유일성만 보장 — 재실행 간 순번 안정성은 미보장(GA4-SEQ-1).
--   ⚠️ 적재 = 롤링 윈도우 증분 — [오늘-bigquery_lookback_days, 9999-12-31] 창만 DELETE 후 재적재(멱등) · 창보다 오래 건너뛴 구멍은 OPS.WARN_BIGQUERY_LOAD_GAP 이 감시.
CREATE OR REPLACE TABLE GN_DW.SILVER.BIGQUERY_EVENT (
    USER_PSEUDO_ID          VARCHAR(200)    NOT NULL COMMENT '세션 스파인 (PK)',
    EVENT_TIMESTAMP         NUMBER          NOT NULL COMMENT 'UTC microsec (PK)',
    EVENT_NAME              VARCHAR(200)    NOT NULL COMMENT '이벤트명 (PK)',
    EVENT_SEQ               NUMBER          NOT NULL COMMENT '동일 3키 내 순번 .  BIGQUERY.',
    EVENT_DATE              VARCHAR(8)      COMMENT '원본 YYYYMMDD',
    EVENT_DT                DATE            NOT NULL COMMENT '파생 DATE.',
    EVENT_TS                TIMESTAMP_NTZ   COMMENT '파생 TIMESTAMP',
    USER_ID                 VARCHAR(64)     COMMENT 'BIGQUERY user_id 원본(불변 보존).  BIGQUERY.',
    ID_SCHEME               VARCHAR(20)     COMMENT 'ID_SCHEME.',
    BIGQUERY_SESSION_ID     NUMBER          COMMENT 'BigQuery 세션ID',
    BIGQUERY_SESSION_NUMBER NUMBER          COMMENT 'BigQuery 세션 번호',
    BIGQUERY_SESSION_KEY    VARCHAR         COMMENT '파생 세션 자연키 (복합 = pseudo ∥ ".',
    USER_ID_FILLED          VARCHAR(64)     COMMENT '파생 세션 전파 회원번호.  BIGQUERY.',
    ID_RESOLUTION           VARCHAR(20)     COMMENT 'ID_RESOLUTION.',
    SESSION_ENGAGED         VARCHAR(5)      COMMENT '세션 engaged 여부',
    ENGAGEMENT_TIME_MSEC    NUMBER          COMMENT '참여시간 msec (비가산 raw)',
    PAGE_LOCATION           VARCHAR         COMMENT '페이지 URL',
    PAGE_TITLE              VARCHAR         COMMENT '페이지 제목',
    PAGE_REFERRER           VARCHAR         COMMENT '리퍼러 URL',
    EVENT_CATEGORY          VARCHAR         COMMENT '이벤트 카테고리',
    EVENT_ACTION            VARCHAR         COMMENT '이벤트 액션',
    EVENT_LABEL             VARCHAR         COMMENT '이벤트 라벨 (혼합타입)',
    PERCENT_SCROLLED        NUMBER          COMMENT '스크롤 비율',
    LINK_URL                VARCHAR         COMMENT '클릭 링크 URL',
    LINK_TEXT               VARCHAR         COMMENT '클릭 링크 텍스트',
    DEVICE_TYPE             VARCHAR(10)     COMMENT '디바이스 유형 파생. 값 = M / PC / (unknown).',
    DEVICE_CATEGORY         VARCHAR         COMMENT 'DEVICE_CATEGORY.',
    OS                      VARCHAR         COMMENT '운영체제',
    GEO_COUNTRY             VARCHAR         COMMENT '국가',
    GEO_CITY                VARCHAR         COMMENT '도시',
    UTM_SOURCE              VARCHAR         COMMENT 'UTM source',
    UTM_MEDIUM              VARCHAR         COMMENT 'UTM medium',
    UTM_CAMPAIGN            VARCHAR         COMMENT 'UTM campaign',
    DEFAULT_CHANNEL_GROUP   VARCHAR         COMMENT '기본 채널그룹',
    PLATFORM                VARCHAR(50)     COMMENT '플랫폼. 값 = WEB (ANDROID/IOS 미입고).',
    IS_ACTIVE_USER          BOOLEAN         COMMENT '활성 사용자 여부',
    BATCH_ORDERING_ID       NUMBER          COMMENT '배치 내 정렬 ID.',
    SRC_TABLE               VARCHAR(64)     COMMENT '원본 일별 테이블명 계보 (기반 테이블 승계)',
    SRC_FILE_NAME           VARCHAR(512)    COMMENT '파일 단위 계보 (기반 테이블 승계)',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE         VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, EVENT_SEQ)
) COMMENT = 'BIGQUERY 사용자 행동 팩트 소스. [Grain: EVENT_DT × EVENT_SEQ (1행=1이벤트)]. [주의: 체류시간/스크롤/이탈률 행동 지표 · 롤링 윈도우 증분 적재]. [원천: BIGQUERY → BRONZE_BIGQUERY.EVENTS].';

-- BIGQUERY_IDENTITY — BIGQUERY 사용자 신원 차원
CREATE OR REPLACE TABLE GN_DW.SILVER.BIGQUERY_IDENTITY (
    USER_PSEUDO_ID      VARCHAR(200)    NOT NULL COMMENT '세션 스파인 (PK)',
    BIGQUERY_MEMBER_ID  VARCHAR(64)     COMMENT 'BigQuery측 회원 식별자(=USER_ID_FILLED).',
    ID_SCHEME           VARCHAR(20)     NOT NULL COMMENT 'ID 체계 (PK) — MBER_NO/ONCE_MBER_NO/APP/EMAIL/INVALID/UNCLASSIFIED',
    MEMBER_TYPE         VARCHAR(10)     COMMENT '회원구분 ONCE(S+8자리) / FDRM(7자리).',
    MBER_NO             VARCHAR(10)     COMMENT '정기 회원번호. ID_SCHEME=MBER_NO 일 때만 채움.',
    ONCE_MBER_NO        VARCHAR(10)     COMMENT '일시 회원번호 (S+8자리)',
    ID_RESOLUTION       VARCHAR(20)     COMMENT 'ID_RESOLUTION.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID, ID_SCHEME)
) COMMENT = 'BIGQUERY 사용자 신원 차원. [Grain: USER_PSEUDO_ID × ID_SCHEME (1행=1사용자)]. [주의: BIGQUERY 쿠키 식별자와 CRM 회원 매핑]. [원천: BIGQUERY → BRONZE_BIGQUERY.EVENTS].';

-- ============================================================================
-- 신원 브리지 (교차소스 유일 예외)
-- ============================================================================

-- IDENTITY_MEMBER_XREF — 온-오프라인 신원 연계 브릿지
--   ⚠️ grain = 1행/USER_PSEUDO_ID(회원 grain 아님) — GOLD 는 MEMBER_DK DISTINCT + UNMATCHED 제외.
--   ⚠️ FACT 결합은 LEFT JOIN(익명 세션이 대부분).
CREATE OR REPLACE TABLE GN_DW.SILVER.IDENTITY_MEMBER_XREF (
    USER_PSEUDO_ID      VARCHAR(200)    NOT NULL COMMENT 'BigQuery 세션 스파인 (PK)',
    BIGQUERY_MEMBER_ID  VARCHAR(64)     COMMENT 'BigQuery측 회원 식별자(원문 보존).',
    ID_SCHEME           VARCHAR(20)     COMMENT 'BigQuery측 ID 체계. 매칭 분모 판정의 정본.',
    MEMBER_TYPE         VARCHAR(10)     COMMENT '회원구분 ONCE/FDRM. 비회원 ID 체계는 NULL.',
    MEMBER_DK           VARCHAR(10)     COMMENT '매칭된 CRM 불변회원키(미매칭 NULL)',
    HOMEPAGE_ID         VARCHAR         COMMENT '매칭 CRM 회원의 HMPG_ID(미매칭 NULL)',
    ID_RESOLUTION       VARCHAR(20)     COMMENT 'GA측 신뢰도: DIRECT/SESSION_FILL',
    MATCH_METHOD        VARCHAR(30)     COMMENT 'MATCH_METHOD.',
    MATCH_CONFIDENCE    VARCHAR(10)     COMMENT '매칭신뢰도 HIGH/MEDIUM/NONE',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID)
) COMMENT = '온-오프라인 신원 연계 브릿지. [Grain: USER_PSEUDO_ID × MEMBER_DK (1행=1연계)]. [주의: BIGQUERY 사용자 식별자와 CRM 회원번호 연결]. [원천: BIGQUERY/CRM → SILVER.BIGQUERY_IDENTITY].';

-- ============================================================================
-- 🆕 [2026-10-08 O213-F Y3-F] GA4 인구통계 · 서치콘솔 (종전 소비 모델 0)
--   🔴 BIGQUERY_SESSION 은 여기서 선생성하지 않는다 — range 모델(silver_purge RANGED_MODELS)은
--      대상 테이블이 있으면 첫 run 이 is_incremental() = 롤링 창(3일)만 적재한다(bigquery_load_window ⓑ).
--      ⇒ 첫 build 가 CTAS 로 전량 생성 · 컬럼 COMMENT 는 build 후 ALTER(§13-1-8).
-- ============================================================================
/* ── 비실행 선언(COMMENT 정본 전용) — 이 블록을 실행하지 마라: range 모델은 선생성 금지 ──
CREATE OR REPLACE TABLE GN_DW.SILVER.BIGQUERY_SESSION (
    EVENT_DT                         DATE            COMMENT '세션 일자(원천 EVENT_DATE YYYYMMDD) · 자정을 넘는 세션은 일자별로 나뉜다.',
    USER_PSEUDO_ID                   VARCHAR(200)    COMMENT 'GA4 가명 사용자 ID(브라우저·앱 단위 · 원천 user_pseudo_id).',
    BIGQUERY_SESSION_ID              NUMBER          COMMENT 'GA4 세션ID(EP_GA_SESSION_ID TRY_CAST) · 세션ID 결측 이벤트는 적재하지 않는다.',
    BIGQUERY_SESSION_KEY             VARCHAR         COMMENT '세션 자연키 = USER_PSEUDO_ID-EP_GA_SESSION_ID · 기간 세션수는 이 키의 COUNT(DISTINCT).',
    BIGQUERY_SESSION_NUMBER          NUMBER          COMMENT '사용자 기준 세션 순번(EP_GA_SESSION_NUMBER 최댓값).',
    SESSION_START_TS                 TIMESTAMP_NTZ   COMMENT '그 일자 안 세션 첫 이벤트 시각(EVENT_TIMESTAMP 마이크로초 최솟값 → TIMESTAMP_NTZ).',
    PLATFORM                         VARCHAR         COMMENT 'GA4 플랫폼(WEB) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    DEVICE_CATEGORY                  VARCHAR         COMMENT '기기 카테고리(mobile·desktop·tablet·smart tv) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    DEVICE_OPERATING_SYSTEM          VARCHAR         COMMENT '운영체제 원값(Android·iOS·Windows·Macintosh·Linux·Chrome OS 등) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    DEVICE_WEB_INFO_BROWSER          VARCHAR         COMMENT '브라우저 원값(Chrome·Android Webview·Edge·Samsung Internet·Safari 등) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    DEVICE_LANGUAGE                  VARCHAR         COMMENT '기기 언어 로캘 원값(ko-kr·ko·en-us 등) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    DEVICE_MOBILE_BRAND_NAME         VARCHAR         COMMENT '기기 제조사 원값(Samsung·Apple 등) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    DEVICE_WEB_INFO_HOSTNAME         VARCHAR         COMMENT '접속 호스트명 원값(www.goodneighbors.kr·m.goodneighbors.kr 등) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    GEO_CONTINENT                    VARCHAR         COMMENT '대륙(Asia·Americas·Europe·Oceania·Africa·(not set)) · (not set) = GA4 위치 미판정 원값 · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    GEO_SUB_CONTINENT                VARCHAR         COMMENT '하위 대륙 GA4 영문 원값(Eastern Asia 등 · (not set) 포함) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    GEO_COUNTRY                      VARCHAR         COMMENT '국가 GA4 영문 원값(South Korea 등) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    GEO_METRO                        VARCHAR         COMMENT '대도시권 GA4 원값((not set) 포함) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    TS_SOURCE                        VARCHAR         COMMENT '사용자 최초 유입 소스(traffic_source.source 원값 · google·(direct)·네이버M 등) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    TS_MEDIUM                        VARCHAR         COMMENT '사용자 최초 유입 매체(traffic_source.medium 원값 · cpc·organic·(none) 등) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    CTS_MANUAL_MEDIUM                VARCHAR         COMMENT '수집 트래픽 수동 매체(collected_traffic_source.manual_medium = utm_medium 원값) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    EP_MEDIUM                        VARCHAR         COMMENT '이벤트 파라미터 medium 원값 · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    STSLC_CRC_DEFAULT_CHANNEL_GROUP  VARCHAR         COMMENT '세션 기본 채널 그룹(last click cross-channel · Display·Cross-network·Direct·Unassigned·Organic Search·Organic Social·Paid Search·Paid Other·Referral·Email·SMS·AI Assistant·Paid Social·Organic Video·Mobile Push Notifications) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    STSLC_CRC_PRIMARY_CHANNEL_GROUP  VARCHAR         COMMENT '세션 주 채널 그룹(값 체계는 기본 채널 그룹과 같다) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    STSLC_CRC_SOURCE_PLATFORM        VARCHAR         COMMENT '세션 소스 플랫폼(Manual·Google Ads·Meta Ads·Other Ads·Unlabeled) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    STSLC_GAC_CAMPAIGN_NAME          VARCHAR         COMMENT 'Google Ads 캠페인명 원값(세션 last click) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    STSLC_GAC_AD_GROUP_NAME          VARCHAR         COMMENT 'Google Ads 광고그룹명 원값((not set) 포함) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    UP_MEMBER_TYPE                   VARCHAR         COMMENT '회원유형 user_property 원값(비로그인·정기회원·일시회원·중단회원·앱회원·활동회원·정기후원·일시후원·후원중단) · 🔴 GTM 미치환 변수명 원문(이중 중괄호로 감싼 값)은 수집 오류다(원값 보존) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    UP_DONOR_TYPE                    VARCHAR         COMMENT '후원자유형 user_property(개인·단체·기업) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    UP_DONATION_TYPE                 VARCHAR         COMMENT '후원유형 user_property 원값(신규후원·증액후원·증액·감액·재후원) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    UP_BIZ_TYPE                      VARCHAR         COMMENT '후원사업유형 user_property 원값(복수 사업은 | 로 이어진 한 문자열) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    UP_LOGIN_STATUS                  VARCHAR         COMMENT '로그인 여부 user_property(y·n) · 🔴 GTM 미치환 변수명 원문은 수집 오류다 · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    EP_PAYMENT_TYPE                  VARCHAR         COMMENT '결제수단 이벤트 파라미터(신용카드·계좌이체·네이버페이) · 첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL).',
    EVENT_CNT                        NUMBER          COMMENT '그 일자·세션의 이벤트 수(가산).',
    PAGE_VIEW_CNT                    NUMBER          COMMENT 'page_view 이벤트 수(가산).',
    IS_ENGAGED                       BOOLEAN         COMMENT 'GA4 참여 세션 여부(EP_SESSION_ENGAGED = 1 이벤트가 하나라도 있으면 TRUE).',
    ENGAGEMENT_TIME_MSEC             NUMBER          COMMENT '참여 시간 합계(밀리초 · EP_ENGAGEMENT_TIME_MSEC 합 · 가산).',
    DW_SOURCE_SYSTEM                 VARCHAR         COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE                  VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS                       TIMESTAMP_NTZ   COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS                     TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID                      VARCHAR         COMMENT '적재 배치 식별자 (공통감사) · 이 모델은 채우지 않아 NULL 이다.'
) COMMENT = 'GA4 세션 속성. [Grain: EVENT_DT × USER_PSEUDO_ID × BIGQUERY_SESSION_ID (자정 경계 세션은 일자별로 나뉜다)]. [주의: 속성 = 세션 첫 non-NULL 값 · 원값 보존 · range 재적재 · 선생성 금지]. [원천: GA4 → SILVER.BIGQUERY_REFINED_DATA].';
── 비실행 선언 끝 */
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_USER_DEMOGRAPHIC (
    EVENT_DT            DATE            COMMENT '집계 일자(원천 DATE YYYYMMDD).',
    DEVICE_CATEGORY     VARCHAR(20)     COMMENT '기기 카테고리 desktop·mobile·tablet (GA4 원값).',
    USER_GENDER         VARCHAR(20)     COMMENT '성별 female·male·unknown (GA4 추정 · unknown = 추정 불가 버킷).',
    USER_AGE_BRACKET    VARCHAR(20)     COMMENT '연령대 18-24·25-34·35-44·45-54·55-64·65+·unknown (GA4 추정).',
    SESSIONS            NUMBER(38,0)    COMMENT '세션수(가산).',
    TOTAL_USERS         NUMBER(38,0)    COMMENT '총 사용자수 — grain 단위 고유값 · 🔴 비가산.',
    NEW_USERS           NUMBER(38,0)    COMMENT '신규 사용자수 — grain 단위 고유값 · 🔴 비가산.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA4 인구통계 일 집계. [Grain: 일 × 기기 × 성별 × 연령대]. [주의: GA4 Data API 집계 · 이벤트 원천(BIGQUERY_*)과 모수 상이 · 사용자수 비가산]. [원천: GA4 → BRONZE_GA4.GA4_USER_DEMOGRAPHIC].';

CREATE OR REPLACE TABLE GN_DW.SILVER.SEARCH_CONSOLE_DATA (
    EVENT_DT            DATE            COMMENT '검색 일자(원천 DATE).',
    QUERY               VARCHAR         COMMENT '검색어(구글 검색창 입력 원문).',
    PAGE                VARCHAR         COMMENT '노출된 페이지 URL.',
    COUNTRY             VARCHAR(10)     COMMENT '검색자 국가 = ISO 3166-1 alpha-3 소문자 코드(예 kor·usa) · 원천에 라벨 없음.',
    DEVICE              VARCHAR(20)     COMMENT '검색 기기 DESKTOP·MOBILE·TABLET.',
    CLICKS              NUMBER(38,0)    COMMENT '클릭수(가산).',
    IMPRESSIONS         NUMBER(38,0)    COMMENT '노출수(가산).',
    CTR                 FLOAT           COMMENT '클릭률(행 단위) · 🔴 합산·평균 금지 — SUM(CLICKS)/SUM(IMPRESSIONS).',
    POSITION            FLOAT           COMMENT '평균 노출순위(행 단위) · 🔴 합산 금지 — 노출 가중 평균.',
    RESPONSE_AGGREGATION_TYPE VARCHAR(20) COMMENT 'GSC 집계 방식(전건 byPage).',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '구글 서치콘솔 검색 성과. [Grain: 일 × 검색어 × 페이지 × 국가 × 기기]. [주의: CTR·POSITION 비가산 · SEARCH_CONSOLE_DATA2 는 중복 복사본이라 미사용]. [원천: GSC → BRONZE_GSC.SEARCH_CONSOLE_DATA].';

-- 🆕 [2026-10-08 O213-F Y3-K] ERP_EXPENSE_RESOLUTION — 지출결의 명세(종전 소비 모델 0 · 원천 1행 = 1행)
--   🔴 예산 원장(ERP_BUDGET)과 합산·조인 금지 · 전 컬럼 동일 행 7,287 보존(문서20 N-29 ⑧) · 물리 = GN_DW_ADMIN CTAS LIMIT 0 후 감사컬럼 VARCHAR 확장.
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_EXPENSE_RESOLUTION (
    RESOLUTION_NO       VARCHAR         COMMENT '결의번호(1결의 = 여러 명세행).',
    ROW_SEQ             NUMBER(18,0)    COMMENT '결의번호 내 행 일련(결정적 정렬 · 원천 키 부재로 DW 부여).',
    RESOLUTION_YEAR     NUMBER(38,0)    COMMENT '회계연도.',
    WRITE_DATE          DATE            COMMENT '결의 작성일.',
    RESOLUTION_DEPT_NM  VARCHAR         COMMENT '결의부서명(원값) — 부서별 지출 축.',
    EXPS_RESOLUTION_NM  VARCHAR         COMMENT '지출결의명(자유문).',
    SOURCE_DIV_NM       VARCHAR         COMMENT '출처구분명(원값 = 가지급금정산서·구매품의·기안서·대체결의·외화출장품의서·품의서).',
    SOURCE_NO           VARCHAR         COMMENT '출처번호.',
    BDGT_UNIT_NM        VARCHAR         COMMENT '예산단위명.',
    MOK_NM              VARCHAR         COMMENT '목명(예산 과목).',
    DTL_ITEM_NM         VARCHAR         COMMENT '세목명.',
    SUBDTL_ITEM_NM      VARCHAR         COMMENT '세세목명.',
    FUND_SOURCE_NM      VARCHAR         COMMENT '재원명(원값).',
    BDGT_ITEM_NM        VARCHAR         COMMENT '예산항목명(원값).',
    DESCRIPTION         VARCHAR         COMMENT '적요(원천 DESCRIPTIONVARCHAR).',
    SUM_AMT             NUMBER(38,0)    COMMENT '금액(원 · 가산).',
    CONTENTS_DELIMITER  VARCHAR         COMMENT '내용 구분자(원천 문서번호형 값).',
    DW_SOURCE_SYSTEM    VARCHAR         COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '지출결의 명세. [Grain: RESOLUTION_NO × ROW_SEQ (원천 1행)]. [주의: 예산 원장과 합산·조인 금지 · 전 컬럼 동일 행 보존]. [원천: ERP → BRONZE_ERP.EXPENSE_RESOLUTION].';
