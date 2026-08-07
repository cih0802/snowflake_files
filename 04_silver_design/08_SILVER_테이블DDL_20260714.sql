-- GN_DW SILVER 테이블 정의 DDL (STEP 1 스키마 + 38테이블 CREATE). 적재쿼리는 09 참조.
-- Co-authored with CoCo
/*
  GN_DW.SILVER — 38테이블 정의 DDL (테이블 구조 정본)
    구성: CRM 22 + ERP 2 + AGENCY 8 + GA4 5 + bridge 1 = 38.
    dbt SILVER 모델 38개와 1:1 대응(구조 소유주 = 이 파일, dbt 는 데이터만 갱신).
    ※ 2026-07-29 실측 대조 완료 — INFORMATION_SCHEMA 38테이블·전 컬럼 일치.
  실행 순서: 08 먼저(테이블 생성) → 09(적재). CREATE OR REPLACE 로 안전 재실행.
  ⚠️ 발송 2테이블(CRM_SEND_REQUEST·CRM_SEND_MEMBER)의 복합 PK 전환은 09 상단 ALTER 로 수행 —
     본 파일 CREATE 는 단일 PK 상태다(멱등 로드 흐름 유지). 이 파일만 실행하면 PK 미완성.

  ▣ 본 파일의 범위 = 구조 계약(타입·PK·COMMENT)만. 설계근거·실측이력·리뷰기록은 이관됨:
      CRM        → 03_SILVER_작업계획_CRM전용 20260714.md
      ERP        → 05_SILVER_작업계획_ERP전용 20260714.md §6
      AGENCY     → 06_SILVER_작업계획_AGENCY전용 20260714.md §6
      GA4        → 07_GA4_SILVER_샤드통합 설계결정.md §7
      S-7 브리지 → 02_SILVER_작업계획_BRONZE-GOLD연결 20260714.md §6
    이슈·결정 ID(Q*/--O*/AD-*/DEC-*/E-*/P*) 원장 = 20_issue/00_INDEX_이슈원장.md
-- */
-- ============================================================================
-- STEP 1 — 스키마 생성
-- ============================================================================
;
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE DATABASE GN_DW;
CREATE SCHEMA IF NOT EXISTS GN_DW.SILVER
    WITH MANAGED ACCESS
    COMMENT = 'Silver 레이어 — Bronze(CRM·GA4·ERP·AGENCY) 정제/변환 객체 (GOLD 입력용)';

USE SCHEMA GN_DW.SILVER;

-- ============================================================================
-- STEP 2 — CRM 22테이블
-- ============================================================================

-- CRM 1: CRM_MEMBER (회원 통합 — 정기 ∪ 일시)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER (
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키 (PK, 조인용)',
    MEMBER_TYPE         VARCHAR(10)     COMMENT '회원구분 파생 (정기=FDRM / 일시=ONCE)',
    MBER_DIV_CD         VARCHAR(3)      COMMENT '회원구분코드 (MM018: 개인/기업/단체)',
    MBER_DIV_NM         VARCHAR         COMMENT '회원구분명 (코드 라벨)',
    CPR_DIV_CD          VARCHAR(3)      COMMENT '법인구분코드',
    SEX                     VARCHAR         COMMENT '성별 원천코드 raw(정본 CM013) — BRONZE TM_MM_FDRM_MBER_INFO/ONCE_MBER_INFO.SEX 무변환. 1국내남·2국내여·3외국남·4외국여·5외국기타·6단체·7기업·8기타. ⚠️[O26] 종전 M/F/U 축약을 폐기했다 — 정본 비고가 ''성별만으로는 사용하지는 않음''을 경고했고 축약이 원천 8종을 3종으로 파괴했다. 라벨=SEX_NM',
    SEX_NM                  VARCHAR         COMMENT 'CM013 라벨 그대로(국내(남자)/외국인(여자)/단체/기업 등 8종). USE_YN 무필터 조인. [O26 신설]',
    MBER_STAT_CD        VARCHAR(3)      COMMENT '회원상태코드 원천 raw (정본 MM010): 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단. 라벨 미배선(GOLD DIM_MEMBER.MEMBER_STATUS_NAME 이 보유). ⚠️미납 판정은 PAY_STAT_CD(DEC-3) 소관 — 이 컬럼과 혼용 금지',
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
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    EMAIL_STAT_CD           VARCHAR         COMMENT '이메일상태 코드 raw (정본 MM009). ONCE 원천 부재 → NULL',
    ETC_CTTPC_REL_CD        VARCHAR         COMMENT '기타연락처 관계 코드 raw (정본 MM008). ⚠️사전 심각 불완전(활성 3 vs 원천 distinct 14) → 라벨 불가·현업 사전보완 대기. ONCE 부재 → NULL',
    ETC_CTTPC_STAT_CD       VARCHAR         COMMENT '기타연락처 상태 코드 raw (정본 MM008). ONCE 부재 → NULL',
    ETC_TSTM_DIV_CD         VARCHAR         COMMENT '기타 증서구분 코드 raw (정본 MS026). 원천 타입 NUMBER → TO_VARCHAR 정규화. FDRM∪ONCE 양쪽 존재',
    MOBLPHON_STAT_CD        VARCHAR         COMMENT '휴대폰상태 코드 raw (정본 MM008). ONCE 부재 → NULL',
    REL_CD                  VARCHAR         COMMENT '관계 코드 raw (정본 CM009). ONCE 전용 — FDRM 부재 → NULL',
    RELATNSP_DIV_CD         VARCHAR         COMMENT '결연구분 코드 raw (정본 MM019). ONCE 부재 → NULL',
    SLRCLD_LRR_CD           VARCHAR         COMMENT '급여공제 코드 raw (정본 CM029). ⚠️폐지코드 사용중(활성2·폐지1) → 라벨 조인시 USE_YN 무필터 필수. ONCE 부재 → NULL',
    TSTM_DIV_CD             VARCHAR         COMMENT '증서구분 코드 raw (정본 MS026). 원천 타입 NUMBER → TO_VARCHAR 정규화. FDRM∪ONCE 양쪽 존재',
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
    DVLP_DIV_CD         VARCHAR(3)      COMMENT '개발구분코드 (정본 MM015: 1신규 2증액 3감액 4재후원 5후원중단). 라벨=DVLP_DIV_NM. 🔴 MM015(개발구분) ≠ MM010(회원상태) — 두 그룹 모두 ''후원중단''을 포함해 혼동되기 쉽다. 회원상태는 CRM_MEMBER.MBER_STAT_CD(MM010)',
    DVLP_DIV_NM         VARCHAR         COMMENT '개발구분명 — 정본 MM015 라벨(1신규/2증액/3감액/4재후원/5후원중단). CRM_CODE 빌드시점 조인. 컬럼명은 정본 컬럼정의서 504행 현업 용어쌍 (O24)',
    ACT_DEPT_CD         VARCHAR(10)     COMMENT '활동부서코드 (→CRM_ORG)',
    ACMSLT_DEPT_CD      VARCHAR(10)     COMMENT '실적부서코드 (→CRM_ORG)',
    CMPGN_CD            VARCHAR(20)     COMMENT '캠페인코드 (→CRM_CAMPAIGN)',
    SETLE_CD            VARCHAR(3)      COMMENT '결제수단코드',
    AREA_CD             VARCHAR(3)      COMMENT '지역코드 (CM018)',
    AREA_NM             VARCHAR         COMMENT '지역명 (코드 라벨)',
    AGE                 NUMBER(10,0)    COMMENT '연령',
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    CANCL_RDCAMT_RSN_CD     VARCHAR         COMMENT '취소·감액사유 코드 raw (정본 MM002). ⚠️31종 중 18종이 폐지코드 → 라벨 조인시 USE_YN 무필터 필수',
    MBER_DIV_CD             VARCHAR         COMMENT '회원구분 코드 raw (정본 MM018). 라벨 미배선',
    SEX                     VARCHAR         COMMENT '성별 코드 raw (정본 CM013). ✅[O26] CRM_MEMBER.SEX 도 CM013 raw 로 복원되어 동명이의 해소 — 비교·UNION 가능(종전 ''M/F/U 정규화값이라 금지'' 경고 폐기)',
    SPNSR_AMT_CD            VARCHAR         COMMENT '후원금액구분 코드 raw (정본 CM012). 금액 원값은 SPNSR_AMT',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO)
) COMMENT = '개발약정 (Q13 스파인). AREA_CD·AGE = DIM_MEMBER REGION/AGE_BAND 스냅샷 소스';

-- CRM 4: CRM_MEMBER_AMT_CHANGE (증감)
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
    AGE                 NUMBER(10,0)    COMMENT '연령',
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    MBER_DIV_CD             VARCHAR         COMMENT '회원구분 코드 raw (정본 MM018: 1개인/2기업/3단체). 라벨 미배선',
    SETLE_CD                VARCHAR         COMMENT '결제수단 코드 raw (정본 PM040). 라벨 미배선',
    SEX                     VARCHAR         COMMENT '성별 코드 raw (정본 CM013). ✅[O26] CRM_MEMBER.SEX 도 CM013 raw 로 복원되어 동명이의 해소 — 비교·UNION 가능(종전 ''M/F/U 정규화값이라 금지'' 경고 폐기)',
    SPNSR_AMT_CD            VARCHAR         COMMENT '후원금액구분 코드 raw (정본 CM012). 금액 원값은 SPNSR_AMT',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (OCCRRNC_DE, SER_NO)
) COMMENT = '약정 증감(증액/감액). AREA_CD·AGE = DIM_MEMBER REGION/AGE_BAND 스냅샷 소스';

-- CRM 5: CRM_MEMBER_DISCONTINUE (중단)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_MEMBER_DISCONTINUE (
    MBER_NO             VARCHAR(10)     NOT NULL COMMENT '회원번호 (PK)',
    SPNSR_DSCNTC_DE     VARCHAR(8)      NOT NULL COMMENT '후원중단일자 YYYYMMDD (PK)',
    SER_NO              NUMBER(10,0)    NOT NULL COMMENT '일련번호 (PK)',
    DSCNTC_RSN_CD       VARCHAR(3)      COMMENT '중단사유코드',
    DSCNTC_RSN_NM       VARCHAR         COMMENT '중단사유명 (코드 라벨)',
    DSCNTC_PATH         VARCHAR(1)      COMMENT '중단경로',
    REGIST_DEPT_CD      VARCHAR(10)     COMMENT '등록부서코드 (→CRM_ORG)',
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    DSCNTC_PATH_NM          VARCHAR         COMMENT '중단경로명 — MM287 라벨(1=SYSTEM/2=CRM/3=홈페이지). 코드는 DSCNTC_PATH. USE_YN 무필터 조인 (O25)',
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
    RELATNSP_DSCNTC_YN  VARCHAR(1)      COMMENT '결연 중단여부. ⚠️값은 Y/N 이 아니라 0/1 — 현업 정의서 명시 "0=후원중;1=후원중단". 실측 1=667,278(전건 중단일 보유)/0=195,332(전건 미보유). ★''Y'' 로 필터하면 전건 0 반환(O20 교정 2026-07-31)',
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    RELATNSP_DSCNTC_RSN_CD  VARCHAR         COMMENT '결연중단사유 코드 raw (정본 MM002). 원천 타입 NUMBER → TO_VARCHAR 정규화. ⚠️30종 중 16종 폐지코드 → 라벨 조인시 USE_YN 무필터 필수',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (RELATNSP_KEY)
) COMMENT = '결연(아동). Q15 SPNSR_BSNS_ID 크로스워크 파생';

-- CRM 9: CRM_PAYMENT_BILLING (납입·청구)
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
    PAY_STAT_CD         VARCHAR(3)      COMMENT '납입상태코드. ★미납 판정축(DEC-3): 미납 = F OR NULL. 판정은 이 컬럼 단독',
    SETLE_CD            VARCHAR(3)      COMMENT '결제수단코드. ★RQEST_RST_CD 코드그룹 결정자(W1/DEC-17) — 단독 조인 금지',
    GFT_DIV_CD          VARCHAR(3)      COMMENT '기부구분코드',
    -- W1(DEC-17, 2026-07-31): 결제결과코드 2종 추가. ★사유축 전용 — 미납 판정은 DEC-3(PAY_STAT_CD) 불변.
    --   기존 테이블에는 ALTER TABLE ADD COLUMN 으로 반영 → 물리 컬럼 위치는 맨 끝(공통감사 뒤).
    --   신규 재생성 시에는 이 위치. dbt append 는 컬럼명 기준 INSERT 라 순서 무관(동작 영향 없음).
    RQEST_RST_CD        VARCHAR(30)     COMMENT '청구결과코드(PG 결과). ★사유축. 실측 101종·채움 99.67%·최대길이 28. ⚠️PG사별 이종 네임스페이스 → 코드 단독 조인 금지(''01''=41개·''02''=43개·''03''=36개 코드그룹에 동시 존재, SETLE_CD=1 실패/=8 성공으로 의미 상반). 조인키 = (코드그룹, 코드) 복합. 코드그룹 = SETLE_CD+자릿수: 1&2자리→PM002 / 1&4자리→PM032 / 2→PM018 / 12→PM033 / 5→PM019. ★★REASON_SK 배선은 미납(PAY_STAT_CD=''F'') 행에 한정 — 성공행에 매핑하면 라벨이 반대로 붙는다(SETLE_CD=8, 1,374행). F 한정 시 의미 모순 0 검증. 기부금 branch 는 원천 컬럼 부재로 NULL',
    PRCS_RST_CD         VARCHAR(10)     COMMENT '처리결과코드. ⚠️PAY_STAT_CD 의 거울 컬럼 — 실측 F↔F 6,262,245 / S↔S 39,805,846, 불일치 179,052행(0.386%), 사유 분해력 없음(7종). ★미납 판정·사유 분해에 사용 금지. 원천 보존·감사 목적. 기부금 branch 는 원천 컬럼 부재로 NULL',
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    CPR_DIV_CD              VARCHAR         COMMENT '법인구분 코드 raw (정본 CM019). 회비∪기부금 양쪽 존재',
    MBER_DIV_CD             VARCHAR         COMMENT '회원구분 코드 raw (정본 MM018). 회비 전용 — 기부금 부재 → NULL',
    MBRFEE_DIV_CD           VARCHAR         COMMENT '회비구분 코드 raw (정본 PM010). 회비 전용 → 기부금 NULL',
    OPERT_DIV_CD            VARCHAR         COMMENT '작업구분 코드 raw (정본 MM014). 회비 전용 → 기부금 NULL',
    MBRFEE_PRCS_STAT_CD     VARCHAR         COMMENT '처리상태 코드 raw (정본 PM013). 🔴회비 전용 — 기부금 원천에도 동명 컬럼이 있으나 정본이 코드그룹 미지정이라 O16형 의미혼입 방지를 위해 NULL 유지. 미납 판정은 PAY_STAT_CD(DEC-3) 불변. [O26] MBRFEE_ 접두 = 원천 테이블 TM_PM_MBRFEE_ACMSLT 변별토큰 — CRM_SEND_REQUEST.PSTMTR_PRCS_STAT_CD(MS061)와 동명이의였다. BRONZE 실측 도메인 완전 분리: 여기 R 144,028·S 46,247,143·F 449 vs PSTMTR 0/1 (2026-08-04 재확인)',
    RETUN_RSN_CD            VARCHAR         COMMENT '반환사유 코드 raw (정본 PM042). 회비∪기부금 양쪽 존재',
    RQEST_DIV_CD            VARCHAR         COMMENT '청구구분 코드 raw (정본 PM024). 회비 전용 → 기부금 NULL',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (PAY_KEY)
) COMMENT = '납입/청구(회비∪기부금). Q14 납입 dedup·청구 행기준. W1(DEC-17): 결제결과코드 2종 = 사유축 전용, 판정축은 PAY_STAT_CD(DEC-3) 불변';

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
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    APPLCNT_MBER_REL_CD     VARCHAR         COMMENT '신청자-회원 관계 코드 raw (정본 CM009)',
    CPR_DIV_CD              VARCHAR         COMMENT '법인구분 코드 raw (정본 CM019)',
    CRTFC_MTH_CD            VARCHAR         COMMENT '인증방법 코드 raw (정본 MM014)',
    FNLT_DIV_CD             VARCHAR         COMMENT '금융기관구분 코드 raw (정본 PM050). 기관코드 원값은 FNLT_CD',
    RCEPT_DIV_CD            VARCHAR         COMMENT '접수구분 코드 raw (정본 PM003)',
    RQST_DIV_CD             VARCHAR         COMMENT '요청구분 코드 raw (정본 PM004)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SETLE_KEY)
) COMMENT = '결제수단 (현재상태)';

-- CRM 11: CRM_CAMPAIGN (캠페인 마스터)
--   [2026-07-16 BRONZE 재입고] 캠페인 분류 5컬럼이 원천에서 채워짐(33,915/36,143 = 93.8%) →
--     코드→라벨 병행보존(master §3) 적용. Q2·Q3(캠페인 라벨)·Q16(마케팅캠페인 연결) 해소.
--   코드군: 카테고리=MM294(56) · 인입경로=MM293(16) · 유형1=MM295(3) · 유형2=MM296(4)
--   ⚠️ 유형1/유형2 의미 주의 — 유형1=국내/통합/해외, 유형2=굿즈/기타/사례/사업. 혼동 금지.
--   ⚠️ 고아 코드(코드사전 미등재, 라벨 NULL로 남김): CMPGN_CTGR_CD=58(23행) · CMPGN_TYPE1_BSN=4(740행)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_CAMPAIGN (
    CMPGN_CD            VARCHAR(20)     NOT NULL COMMENT '캠페인코드 (PK)',
    CMPGN_NM            VARCHAR(200)    COMMENT '캠페인명',
    UPPER_CMPGN_CD      VARCHAR(20)     COMMENT '상위캠페인코드 (자기참조)',
    UPPER_CMPGN_YN      VARCHAR(1)      COMMENT '상위캠페인 여부 (Y/N)',
    BRND_ID             VARCHAR(30)     COMMENT '브랜드ID',
    BRND_NM             VARCHAR(200)    COMMENT '브랜드명',
    PR_MTH_CD           VARCHAR(3)      COMMENT '홍보방법코드',
    SPNSR_BSNS_ID       VARCHAR(100)    COMMENT '후원사업ID (Q16 조인키)',
    CMPGN_CTGR_CD       NUMBER(10,0)    COMMENT '캠페인 카테고리코드 (MM294). 라벨=CMPGN_CTGR_NM',
    CMPGN_CTGR_NM       VARCHAR(200)    COMMENT '캠페인 카테고리명 (MM294 라벨). 예: 국내사례캠페인·굿즈캠페인·해외캠페인',
    MBER_INFLOW_PATH_CD NUMBER(10,0)    COMMENT '개발인입경로코드 (MM293). 라벨=MBER_INFLOW_PATH_NM',
    MBER_INFLOW_PATH_NM VARCHAR(200)    COMMENT '개발인입경로명 (MM293 라벨). 예: 디지털·방송·영상광고·지역개발·마케팅콜개발',
    CMPGN_TYPE1_BSN     NUMBER(10,0)    COMMENT '캠페인 유형1 코드 (MM295) = 국내/통합/해외 축. 라벨=CMPGN_TYPE1_NM',
    CMPGN_TYPE1_NM      VARCHAR(200)    COMMENT '캠페인 유형1명 (MM295 라벨): 국내 / 통합 / 해외',
    CMPGN_TYPE2_BSN     NUMBER(10,0)    COMMENT '캠페인 유형2 코드 (MM296) = 굿즈/기타/사례/사업 축. 라벨=CMPGN_TYPE2_NM',
    CMPGN_TYPE2_NM      VARCHAR(200)    COMMENT '캠페인 유형2명 (MM296 라벨): 굿즈 / 기타 / 사례 / 사업',
    MKTG_CMPGN_NM       NUMBER(10,0)    COMMENT '마케팅캠페인 코드 (※_NM 접미이나 실제는 FK→TM_CM_MKTNG_CMPGN_MNG.MK_CMPGN_CD, 323종·고아 0)',
    MK_CMPGN_NM         VARCHAR(200)    COMMENT '마케팅 캠페인명 (라벨, Q16 해소)',
    CMPGN_STRT_DE       VARCHAR(8)      COMMENT '캠페인 시작일 YYYYMMDD',
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    CMPGN_TRGET_CD          VARCHAR         COMMENT '캠페인대상 코드 raw — TM_CM_CMPGN_MNG.CMPGN_TRGET_CD (정본 CM002). 라벨 미배선',
    CPR_DIV_CD              VARCHAR         COMMENT '법인구분 코드 raw — TM_CM_CMPGN_MNG.CPR_DIV_CD (정본 CM019: I=사단/S=사복/A=통합). 라벨 미배선',
    SPNSR_DIV_CD            VARCHAR         COMMENT '후원구분 코드 raw — TM_CM_CMPGN_MNG.SPNSR_DIV_CD (정본 CM035). 라벨 미배선',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (CMPGN_CD)
) COMMENT = '캠페인 마스터. 분류 4축(카테고리 MM294·인입경로 MM293·유형1 국내해외 MM295·유형2 사업사례 MM296) 코드+라벨 병행보존 + 마케팅캠페인 라벨';

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
    USE_YN                  VARCHAR(1)      COMMENT '사용여부 (Y/N)',
    SORT_ORDR               NUMBER(10,0)    COMMENT '정렬순서',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (DEPT_ID)
) COMMENT = '조직 마스터. 실적팀=ACMSLT_UPPER_DEPT_ID 재귀 LVL5';

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
    SEND_GBN_TOP        VARCHAR(255)    COMMENT '발송구분 대분류코드',
    SEND_GBN_TOP_NM     VARCHAR(255)    COMMENT '발송구분 대분류명',
    SEND_GBN_MID        VARCHAR(255)    COMMENT '발송구분 중분류코드',
    SEND_GBN_MID_NM     VARCHAR(255)    COMMENT '발송구분 중분류명',
    SEND_GBN_BOT        VARCHAR(255)    COMMENT '발송구분 소분류코드',
    SEND_GBN_BOT_NM     VARCHAR(255)    COMMENT '발송구분 소분류명',
    TIT                 VARCHAR(100)    COMMENT '발송 제목',
    SNDNG_STDR_DE       TIMESTAMP_NTZ   COMMENT '발송 기준일시',
    REQ_SEQ_NO          NUMBER(19,0)    COMMENT '요청 일련번호',
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    MSG_DIV_CD              VARCHAR         COMMENT '메시지구분 코드 raw (정본 MS010). MSG_AT 채널 전용 — 그 외 채널은 개념 부재로 NULL',
    PSTMTR_PRCS_STAT_CD     VARCHAR         COMMENT '처리상태 코드 raw (정본 MS061). PSTMTR 채널 전용 — 그 외 NULL. [O26] PSTMTR_ 접두 = 원천 테이블 TM_MS_PSTMTR_SNDNG 변별토큰 — CRM_PAYMENT_BILLING.MBRFEE_PRCS_STAT_CD(PM013)와 동명이의였다. BRONZE 실측 도메인 완전 분리: 여기 0=170·1=3,631 vs MBRFEE R/S/F (2026-08-04 재확인)',
    SNDNG_TIME_DIV_CD       VARCHAR         COMMENT '발송시간구분 코드 raw (정본 MS267). MSG_AT 채널 전용 — 그 외 NULL',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (SNDNG_KEY)
) COMMENT = '발송요청 마스터. SEND_GBN_TOP/MID/BOT = DIM_SERVICE 대/중/소(SND 채널만)';

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
-- STEP 3 — ERP 2테이블 + CRM_BIZ_TARGET (원천=CRM, E-6 입고대기)
-- ============================================================================

-- ERP 1: ERP_BUDGET_ITEM (예산과목 마스터)
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
) COMMENT = '예산과목 마스터(예산단위×6단계×재원). TOTAL 요약행 제외. → DIM_BUDGET_ITEM';

-- ERP 2: ERP_BUDGET (월별 편성/추경/조정/집행)
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
) COMMENT = '예산 편성/추경/조정/집행 월 grain(wide→long). → FACT_BUDGET';

-- CRM 22: CRM_BIZ_TARGET (사업목표 — ⛔ 입고 대기)
CREATE OR REPLACE TABLE GN_DW.SILVER.CRM_BIZ_TARGET (
    BIZ_TARGET_DK       VARCHAR         NOT NULL COMMENT '사업목표 대체키 (PK)',
    TARGET_YEAR         NUMBER(4,0)     COMMENT '목표연도 YYYY',
    MONTH_NO            NUMBER(2,0)     COMMENT '월 1~12',
    MONTH_KEY           VARCHAR(6)      COMMENT '월키 YYYYMM',
    ORG_CD              VARCHAR         COMMENT '조직코드 (FK→DIM_ORG)',
    ORG_NM              VARCHAR         COMMENT '조직 (이름조인 보완)',
    SPONSOR_BIZ_NM      VARCHAR         COMMENT '후원사업',
    CAMPAIGN_NM         VARCHAR         COMMENT '캠페인 (연결키 부재 Q10)',
    TARGET_TYPE         VARCHAR         COMMENT '목표유형: 당초/추경1차/추경2차',
    TARGET_CNT          NUMBER(18,4)    COMMENT '목표 건수(건) — 지표사전 #152~155',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (BIZ_TARGET_DK)
) COMMENT = 'FTG-B 사업목표. 원천=CRM 확정(2026-07-20). ⛔CRM 신규 목표 테이블 입고 대기(E-6) → 스키마-only, 적재 보류';

-- ============================================================================
-- STEP 4 — AGENCY 8테이블 (코어 2 + staging 3 + 위성 3)
--   ⚠️ AD_PERF_DK 는 staging 3종(AGENCY_AD_ROW_*)이 **발급 단일지점**이다.
--      코어·위성·GOLD 는 값을 승계만 하며 재계산 금지(재계산 시 위성 조인 붕괴).
--   ⚠️ staging 은 BRONZE 컬럼명·타입을 그대로 보존한다(개명·형변환 금지). 정제는 코어/위성 담당.
--   ⚠️ staging 의 YEAR·MONTH·WEEK·DOW·BRDC_MT 는 '2025년'·'03월' 형태의 텍스트다 —
--      숫자 파싱 금지, 시간축은 DATE 컬럼에서 파생할 것(과거 96% NULL 결함 원인).
-- ============================================================================

-- AGENCY 1: AGENCY_AD_CREATIVE (매체·소재 차원)
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_CREATIVE (
    CREATIVE_DK         VARCHAR         NOT NULL COMMENT 'MD5(소스+매체+소재+유형+CM위치+초수) 대체키 (PK)',
    SOURCE_SYSTEM       VARCHAR         NOT NULL COMMENT '소스 시스템 (DIGITAL/REBROADCAST/VIDEO)',
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
) COMMENT = '광고 소재/매체 차원(3소스 UNION distinct). → DIM_AD_CREATIVE';

-- AGENCY 2: AGENCY_AD_PERFORMANCE (3소스 UNION 광고성과)
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_PERFORMANCE (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '행 식별자 MD5(AD_SOURCE_TYPE|ROW_HASH|DUP_SEQ). 위성 조인키',
    AD_SOURCE_TYPE      VARCHAR         NOT NULL COMMENT '광고유형 출처축. 실측값 DIGITAL/VIDEO/REBROADCAST. GOLD FAD degenerate 로 승격',
    SOURCE_SYSTEM       VARCHAR         NOT NULL COMMENT '소스 시스템. ⚠️실측 AD_SOURCE_TYPE 와 전건 동일값(불일치 0) — 중복 컬럼, 신규 소비는 AD_SOURCE_TYPE 사용',
    AD_DATE             DATE            COMMENT '광고 집행일자',
    AD_YEAR             NUMBER(4,0)     COMMENT '광고 집행연도 YYYY',
    AD_MONTH            NUMBER(2,0)     COMMENT '광고 집행월 1~12',
    CAMPAIGN_NM         VARCHAR         COMMENT '캠페인명',
    UPPER_CAMPAIGN_NM   VARCHAR         COMMENT '상위 캠페인명',
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
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '광고성과 3소스 UNION(235,572행). 파생 미적재. → FACT_AD_PERFORMANCE';

-- AGENCY 3: AGENCY_AD_ROW_DGT (DGT 무손실 staging + AD_PERF_DK 발급)
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_ROW_DGT (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '행 식별자 — 본 테이블이 발급 단일지점',
    AD_SOURCE_TYPE      VARCHAR         NOT NULL COMMENT '광고유형 상수 DIGITAL',
    ROW_HASH            VARCHAR(32)     COMMENT '원천 전컬럼 해시',
    DUP_SEQ             NUMBER(9,0)     COMMENT '전컬럼 중복 그룹 내 순번',
    TIME                VARCHAR         COMMENT '[원천보존] 시각 텍스트',
    YEAR                VARCHAR         COMMENT '[원천보존] 연도 텍스트',
    CPR_NM              VARCHAR         COMMENT '[원천보존] 협력사명',
    DMST_OVSEA_DIV_NM   VARCHAR         COMMENT '[원천보존] 국내/해외 구분',
    BSNS_CASE_DIV_NM    VARCHAR         COMMENT '[원천보존] 사업/사례 구분',
    CMPGN_TY_NM         VARCHAR         COMMENT '[원천보존] 캠페인유형명',
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
    GA_AD_COST          FLOAT           COMMENT '[원천보존] GA 광고비',
    GA_CONV_MBER_CNT    FLOAT           COMMENT '[원천보존] GA 전환 회원수',
    CONV_VU_CNT         FLOAT           COMMENT '[원천보존] GA 전환 VU수',
    CPA                 FLOAT           COMMENT '[원천보존] 대행사 산정 CPA (비가산)',
    DEV_UNIT_PRICE      FLOAT           COMMENT '[원천보존] 대행사 산정 개발단가 (비가산)',
    CTR                 FLOAT           COMMENT '[원천보존] 대행사 산정 CTR (비가산)',
    CVR                 FLOAT           COMMENT '[원천보존] 대행사 산정 CVR (비가산)',
    CPC                 FLOAT           COMMENT '[원천보존] 대행사 산정 CPC (비가산)',
    CPM                 FLOAT           COMMENT '[원천보존] 대행사 산정 CPM (비가산)',
    UPPER_CMPGN_NM      VARCHAR         COMMENT '[원천보존] 상위 캠페인명',
    READ_CNT            FLOAT           COMMENT '[원천보존] 읽음수',
    MEDIA_PTNT_CUST_CNT FLOAT           COMMENT '[원천보존] 매체 잠재고객수',
    DATE                DATE            COMMENT '[원천보존] 실적일',
    VTR                 FLOAT           COMMENT '[원천보존] 대행사 산정 VTR (비가산)',
    PAGE_TYPE_NM        VARCHAR         COMMENT '[원천보존] 페이지유형',
    CRM_DVLP_CNT        FLOAT           COMMENT '[원천보존] CRM 개발건수',
    AD_GRP_NM           VARCHAR         COMMENT '[원천보존] 광고그룹명',
    GRP_DIV_NM          VARCHAR         COMMENT '[원천보존] 그룹구분',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = 'DGT 디지털광고 원천 무손실 staging(36컬럼) + AD_PERF_DK 발급. 197,686행';

-- AGENCY 4: AGENCY_AD_ROW_VIDEO (VIDEO 무손실 staging + AD_PERF_DK 발급)
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_ROW_VIDEO (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '행 식별자 — 본 테이블이 발급 단일지점',
    AD_SOURCE_TYPE      VARCHAR         NOT NULL COMMENT '광고유형 상수 VIDEO',
    ROW_HASH            VARCHAR(32)     COMMENT '원천 전컬럼 해시',
    DUP_SEQ             NUMBER(9,0)     COMMENT '전컬럼 중복 그룹 내 순번(최대 3중복)',
    CHNNL_NM            VARCHAR         COMMENT '[원천보존] 채널명',
    DOW                 VARCHAR         COMMENT '[원천보존] 요일 텍스트',
    BRDC_DATE           DATE            COMMENT '[원천보존] 송출일',
    TIME_RNG            VARCHAR         COMMENT '[원천보존] 시간대',
    DAY_DIV_NM          VARCHAR         COMMENT '[원천보존] 요일구분(평일/주말)',
    PRG_STRT_TIME       VARCHAR         COMMENT '[원천보존] 프로그램 시작시간',
    SCHDL_NM            VARCHAR         COMMENT '[원천보존] 편성명',
    CM                  VARCHAR         COMMENT '[원천보존] CM 구분',
    CM_AREA             VARCHAR         COMMENT '[원천보존] CM위치',
    AD_STRT_TIME        VARCHAR         COMMENT '[원천보존] 광고시작시간',
    AD_END_TIME         VARCHAR         COMMENT '[원천보존] 광고종료시간',
    SPOT_TY             VARCHAR         COMMENT '[원천보존] SPOT유형',
    AD_VIEW_RT          FLOAT           COMMENT '[원천보존] 광고시청률 (비가산)',
    AD_CNT              NUMBER          COMMENT '[원천보존] 광고횟수',
    AD_SEC              VARCHAR         COMMENT '[원천보존] 광고 초수(TEXT)',
    ACTL_PUR_AD_COST_KRW NUMBER         COMMENT '[원천보존] 실집행 광고비(원)',
    INBOUND_CALL_CNT    NUMBER          COMMENT '[원천보존] 인입콜수',
    CPC                 VARCHAR         COMMENT '[원천보존] 대행사 산정 CPC(TEXT, 비가산)',
    UPPER_CMPGN_NM      VARCHAR         COMMENT '[원천보존] 상위 캠페인명',
    MATR_NM             VARCHAR         COMMENT '[원천보존] 소재명',
    CMPGN_TY_NM         VARCHAR         COMMENT '[원천보존] 캠페인유형명',
    DUR_PD_MATR_CHN     VARCHAR         COMMENT '[원천보존] 기간/소재 채널',
    CHNNL_CMPNY_TY_NM   VARCHAR         COMMENT '[원천보존] 채널사유형',
    WEEK                VARCHAR         COMMENT '[원천보존] 주차 텍스트',
    CONV_CALL_CNT       FLOAT           COMMENT '[원천보존] 전환콜',
    BRDC_MT             VARCHAR         COMMENT '[원천보존] 방송월 텍스트',
    YEAR                VARCHAR         COMMENT '[원천보존] 연도 텍스트',
    CTV_DIV_NM          VARCHAR         COMMENT '[원천보존] CTV구분',
    MKT_CMPGN_NM        VARCHAR         COMMENT '[원천보존] 마케팅 캠페인명',
    SPNSR_BSNS_NM       VARCHAR         COMMENT '[원천보존] 후원사업명',
    DMST_OVSEA_DIV_NM   VARCHAR         COMMENT '[원천보존] 국내/해외 구분',
    BSNS_CASE_DIV_NM    VARCHAR         COMMENT '[원천보존] 사업/사례 구분',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = 'VIDEO 방송광고 원천 무손실 staging(32컬럼) + AD_PERF_DK 발급. 35,822행';

-- AGENCY 5: AGENCY_AD_ROW_REBRDC (REBRDC 무손실 staging + AD_PERF_DK 발급)
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_ROW_REBRDC (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '행 식별자 — 본 테이블이 발급 단일지점',
    AD_SOURCE_TYPE      VARCHAR         NOT NULL COMMENT '광고유형 상수 REBROADCAST',
    ROW_HASH            VARCHAR(32)     COMMENT '원천 전컬럼 해시',
    DUP_SEQ             NUMBER(9,0)     COMMENT '전컬럼 중복 그룹 내 순번(실측 중복 0)',
    RE_BRDC_TY_NM       VARCHAR         COMMENT '[원천보존] 재방송유형명',
    DIV_NM              VARCHAR         COMMENT '[원천보존] 구분명',
    YEAR                VARCHAR         COMMENT '[원천보존] 연도 텍스트',
    BRDC_MT             VARCHAR         COMMENT '[원천보존] 방송월 텍스트',
    CHNNL_CMPNY         VARCHAR         COMMENT '[원천보존] 채널사',
    BRDC_NM             VARCHAR         COMMENT '[원천보존] 방송명',
    BRDC_DIV_NM         VARCHAR         COMMENT '[원천보존] 방송구분',
    DATE                DATE            COMMENT '[원천보존] 실적일/송출일',
    DOW                 VARCHAR         COMMENT '[원천보존] 요일 텍스트',
    BRDC_TIME           VARCHAR         COMMENT '[원천보존] 방송시각',
    INBOUND_CALL_CNT    VARCHAR         COMMENT '[원천보존] 인입콜수(TEXT)',
    DVLP_MBER_CNT       FLOAT           COMMENT '[원천보존] 개발회원수',
    DVLP_CNT            FLOAT           COMMENT '[원천보존] 개발건수',
    BRDC_SCHDL_COST     FLOAT           COMMENT '[원천보존] 편성비용',
    WEEK                VARCHAR         COMMENT '[원천보존] 주차 텍스트',
    AD_CNT              FLOAT           COMMENT '[원천보존] 광고횟수',
    TIME_RNG_DIV_NM     VARCHAR         COMMENT '[원천보존] 시간대구분명',
    CELEB_NM            VARCHAR         COMMENT '[원천보존] 출연자명 (PII 판정 대기 O14)',
    DMST_OVSEA_DIV_NM   VARCHAR         COMMENT '[원천보존] 국내/해외 구분',
    CASE1_BSNS_DIV_NM   VARCHAR         COMMENT '[원천보존] 사례1 사업구분',
    CASE1_FAM_TY_NM     VARCHAR         COMMENT '[원천보존] 사례1 가족유형',
    CASE1_APPEAL_POINT_NM VARCHAR       COMMENT '[원천보존] 사례1 어필포인트',
    CASE1_CHILD_NM      VARCHAR         COMMENT '[원천보존] 사례1 아동명 (PII 미적재)',
    CASE1_CASE_DIV_NM   VARCHAR         COMMENT '[원천보존] 사례1 사례구분',
    CASE2_BSNS_DIV_NM   VARCHAR         COMMENT '[원천보존] 사례2 사업구분',
    CASE2_FAM_TY_NM     VARCHAR         COMMENT '[원천보존] 사례2 가족유형',
    CASE2_APPEAL_POINT_NM VARCHAR       COMMENT '[원천보존] 사례2 어필포인트',
    CASE2_CHILD_NM      VARCHAR         COMMENT '[원천보존] 사례2 아동명 (PII 미적재)',
    CASE2_CASE_DIV_NM   VARCHAR         COMMENT '[원천보존] 사례2 사례구분',
    CASE3_BSNS_DIV_NM   VARCHAR         COMMENT '[원천보존] 사례3 사업구분',
    CASE3_FAM_TY_NM     VARCHAR         COMMENT '[원천보존] 사례3 가족유형',
    CASE3_APPEAL_POINT_NM VARCHAR       COMMENT '[원천보존] 사례3 어필포인트',
    CASE3_CHILD_NM      VARCHAR         COMMENT '[원천보존] 사례3 아동명 (PII 미적재)',
    CASE3_CASE_DIV_NM   VARCHAR         COMMENT '[원천보존] 사례3 사례구분',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = 'REBRDC 재방송광고 원천 무손실 staging(34컬럼, CASE 반복군 포함) + AD_PERF_DK 발급. 2,064행';

-- AGENCY 6: AGENCY_AD_DIGITAL (디지털 고유속성 위성)
CREATE OR REPLACE TABLE GN_DW.SILVER.AGENCY_AD_DIGITAL (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT '코어 1:1 조인키(staging 발급값 승계)',
    PAGE_TYPE           VARCHAR         COMMENT '페이지유형',
    AD_GROUP_NM         VARCHAR         COMMENT '광고그룹명',
    GROUP_DIV           VARCHAR         COMMENT '그룹구분',
    CREATIVE_TYPE       VARCHAR         COMMENT '소재유형',
    AD_TYPE_NM          VARCHAR         COMMENT '광고유형명(대행사 표기)',
    READ_CNT            FLOAT           COMMENT '읽음수 (가산)',
    MEDIA_POTENTIAL_CUST_CNT FLOAT      COMMENT '매체 잠재고객수 (가산)',
    CRM_DEV_CNT         FLOAT           COMMENT 'CRM 개발건수 (가산). ⚠️실측 189,252행 중 13.0%가 비정수(기여도 배분 추정·어의 미확정 AD-2) · ⚠️2026-05 이후 원천 제공 중단(AD-3) → DEV_UNIT_PRICE_SRC 와 상호배타',
    CTR_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CTR',
    CVR_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CVR',
    CPC_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CPC',
    CPM_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CPM',
    CPA_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CPA',
    DEV_UNIT_PRICE_SRC  FLOAT           COMMENT '[비가산] 대행사 산정 개발단가. ⚠️2026-06부터 전건 제공(8,401행) — CRM_DEV_CNT 와 겹치는 행 0건, 검증관계 아닌 기간보완 관계(AD-3)',
    VTR_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 VTR (재계산 불가)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = '디지털광고 고유속성 위성(197,686행, 코어 1:1). → FACT_AD_DIGITAL';

-- AGENCY 7: AGENCY_AD_BROADCAST (방송 고유속성 위성)
--   ⚠️ [VIDEO 전용]/[REBRDC 전용] 표기 컬럼의 NULL 은 결측이 아니라 **해당 원천에 항목이 없음**이다.
--      비율지표 분모로 쓸 때 전체 37,886행을 모집단으로 잡으면 과대계상된다(AD-5·P21).
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
    -- 🟢 [DEC-30 2026-08-04] HH:MM:SS 파싱 배선 — 96.6% 무성 소실 복구(3.2%→93.1%).
    --   ⚠️ 숫자 3종(30/60/90 ×10^6)은 단위 미확정이라 의도적 NULL(문서20 §J 회신 대기).
    --   ⚠️ TRY_TO_TIME 금지 — '30000000' 을 05:20:00(19,200초)로 조용히 바꾼다(P48).
    DURATION_SEC        NUMBER(9,0)     COMMENT '광고 초수 [VIDEO 전용] — HH:MM:SS 파싱값(초). 값 집합 {30,60,90,120}. 숫자표기 1,151행은 단위 미확정으로 NULL 유지. REBRDC 는 원천 부재',
    DAY_DIV             VARCHAR         COMMENT '요일구분 평일/주말 [VIDEO 전용]',
    PRG_START_TIME      VARCHAR         COMMENT '프로그램 시작시간 [VIDEO 전용]',
    CTV_DIV             VARCHAR         COMMENT 'CTV구분 [VIDEO 전용]',
    BRDC_DIV            VARCHAR         COMMENT '방송구분 [REBRDC 전용]',
    AD_CNT              FLOAT           COMMENT '광고횟수 (가산)',
    CONV_CALL_CNT       FLOAT           COMMENT '전환콜 [VIDEO 전용]',
    DVLP_MEMBER_CNT     FLOAT           COMMENT '개발회원수 [REBRDC 전용 — VIDEO 원천에 항목 부재]. 유효 모집단 = REBRDC 2,064행',
    DVLP_CNT            FLOAT           COMMENT '개발건수 [REBRDC 전용 — VIDEO 원천에 항목 부재]. 실측 1,982/2,064(96.0%). 개발단가 분모는 REBRDC 단독으로 한정(AD-5)',
    AD_VIEW_RT_SRC      FLOAT           COMMENT '[비가산] 광고시청률 [VIDEO 전용]',
    CPC_SRC             FLOAT           COMMENT '[비가산] 대행사 산정 CPC [VIDEO 전용]',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK)
) COMMENT = '방송광고 고유속성 위성(VIDEO+REBRDC 37,886행, 코어 1:1). → FACT_AD_BROADCAST';

-- AGENCY 8: AGENCY_AD_BROADCAST_CASE (REBRDC 사례 언피벗)
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
) COMMENT = '재방송 사례 언피벗 위성(5,327행, 코어에 1:N). → FACT_AD_BROADCAST_CASE. CHILD_NM 미적재(PII)';

-- ============================================================================
-- STEP 5 — GA4 5테이블 (트랙 B)
--   ⚠️ 현재 BRONZE 는 1일 샤드(events_20260501)만 입고된 PoC 상태다(G-5 하드블로커).
--      전기간 샤드 입고 후 본 DDL·적재를 그대로 멱등 재실행한다 — 구조 변경 불요.
-- ============================================================================

-- GA4 1: GA4_TRAFFIC_SOURCE (트래픽소스 차원)
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_TRAFFIC_SOURCE (
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
) COMMENT = 'GA 트래픽소스(session/last-click 한정). DISTINCT 그레인(PK 없음) → DIM_GA_SOURCE';

-- GA4 2: GA4_EVENT_DIM (이벤트분류 차원)
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_EVENT_DIM (
    EVENT_NAME          VARCHAR(200)    NOT NULL COMMENT '이벤트명 (그레인 핵심키)',
    EVENT_CATEGORY      VARCHAR         COMMENT '이벤트 카테고리',
    EVENT_LABEL         VARCHAR         COMMENT '이벤트 라벨 (혼합타입)',
    EVENT_ACTION        VARCHAR         COMMENT '이벤트 액션',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA 이벤트분류. DISTINCT 그레인(PK 없음) → DIM_GA_EVENT';

-- GA4 3: GA4_DEVICE (디바이스 차원)
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_DEVICE (
    DEVICE_TYPE         VARCHAR(10)     NOT NULL COMMENT '디바이스 유형 파생. 실측값 PC/M 2종만(APP 휴면·O2)',
    PLATFORM            VARCHAR(50)     COMMENT '플랫폼. 실측값 WEB 단일(ANDROID/IOS 미입고)',
    DEVICE_CATEGORY     VARCHAR         COMMENT '디바이스 카테고리 (원본)',
    OS                  VARCHAR         COMMENT '운영체제',
    BROWSER             VARCHAR         COMMENT '브라우저',
    LANGUAGE            VARCHAR         COMMENT '언어',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA 디바이스. DISTINCT 그레인(PK 없음) → DIM_DEVICE(GA분)';

-- GA4 4: GA4_EVENT (이벤트 팩트 소스)
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_EVENT (
    USER_PSEUDO_ID          VARCHAR(200)    NOT NULL COMMENT '세션 스파인 (PK)',
    EVENT_TIMESTAMP         NUMBER          NOT NULL COMMENT 'UTC microsec (PK)',
    EVENT_NAME              VARCHAR(200)    NOT NULL COMMENT '이벤트명 (PK)',
    BATCH_ORDERING_ID       NUMBER          NOT NULL COMMENT '배치 내 정렬 ID (PK)',
    EVENT_DATE              VARCHAR(8)      COMMENT '원본 YYYYMMDD',
    EVENT_DT                DATE            COMMENT '파생 DATE',
    EVENT_TS                TIMESTAMP_NTZ   COMMENT '파생 TIMESTAMP',
    USER_ID                 VARCHAR(10)     COMMENT 'CRM 회원번호(원본 불변)',
    GA_SESSION_ID           NUMBER          COMMENT 'GA 세션ID',
    GA_SESSION_NUMBER       NUMBER          COMMENT 'GA 세션 번호',
    GA_SESSION_KEY          VARCHAR         COMMENT '파생 세션 자연키',
    USER_ID_FILLED          VARCHAR(10)     COMMENT '파생 세션 전파 회원번호',
    ID_RESOLUTION           VARCHAR(20)     COMMENT '신원해소 DIRECT/SESSION_FILL/UNRESOLVED/CONFLICT',
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
    DEVICE_TYPE             VARCHAR(10)     COMMENT '디바이스 유형 파생. 실측값 PC/M 2종만(APP 휴면·O2)',
    DEVICE_CATEGORY         VARCHAR         COMMENT '디바이스 카테고리 (원본)',
    OS                      VARCHAR         COMMENT '운영체제',
    GEO_COUNTRY             VARCHAR         COMMENT '국가',
    GEO_CITY                VARCHAR         COMMENT '도시',
    UTM_SOURCE              VARCHAR         COMMENT 'UTM source',
    UTM_MEDIUM              VARCHAR         COMMENT 'UTM medium',
    UTM_CAMPAIGN            VARCHAR         COMMENT 'UTM campaign',
    DEFAULT_CHANNEL_GROUP   VARCHAR         COMMENT '기본 채널그룹',
    PLATFORM                VARCHAR(50)     COMMENT '플랫폼. 실측값 WEB 단일(ANDROID/IOS 미입고)',
    IS_ACTIVE_USER          BOOLEAN         COMMENT '활성 사용자 여부',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE         VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, BATCH_ORDERING_ID)
) COMMENT = 'GA 이벤트 팩트 소스 → FACT_GA_BEHAVIOR. 원천 PK 중복은 적재 GROUP BY dedup';

-- GA4 5: GA4_IDENTITY (신원)
CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_IDENTITY (
    USER_PSEUDO_ID      VARCHAR(200)    NOT NULL COMMENT '세션 스파인 (PK)',
    GA_MEMBER_ID        VARCHAR(10)     COMMENT '= user_id_filled(세션 채움 후 회원번호)',
    MEMBER_TYPE         VARCHAR(10)     COMMENT '파생: S%→ONCE else FDRM',
    MBER_NO             VARCHAR(10)     COMMENT '정기 회원번호',
    ONCE_MBER_NO        VARCHAR(10)     COMMENT '일시 회원번호',
    ID_RESOLUTION       VARCHAR(20)     COMMENT '신원해소 DIRECT/SESSION_FILL',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID)
) COMMENT = 'GA 신원(Q1 확정) → S-7 IDENTITY_MEMBER_XREF. 접두사 분기: S%→ONCE / else→정기';

-- ============================================================================
-- STEP 6 — 신원 브리지 (교차소스 유일 예외)
-- ============================================================================

-- IDENTITY_MEMBER_XREF: GA4_IDENTITY ↔ CRM_MEMBER 해소 브리지
--   ★GOLD 소비계약: grain = 1행/USER_PSEUDO_ID(GA 스파인) ≠ 회원 grain.
--     DIM_MEMBER_IDENTITY 구축 시 MEMBER_DK DISTINCT + UNMATCHED 제외(MEMBER_DK NOT NULL) 필수.
--     FACT 결합은 LEFT JOIN — 익명 세션이 95%다(실측 커버리지 4.84%).
CREATE OR REPLACE TABLE GN_DW.SILVER.IDENTITY_MEMBER_XREF (
    USER_PSEUDO_ID      VARCHAR(200)    NOT NULL COMMENT 'GA 세션 스파인 (PK)',
    GA_MEMBER_ID        VARCHAR(10)     COMMENT 'GA측 회원번호(=user_id_filled)',
    MEMBER_TYPE         VARCHAR(10)     COMMENT '회원구분 ONCE(S%)/FDRM',
    MEMBER_DK           VARCHAR(10)     COMMENT '매칭된 CRM 불변회원키(미매칭 NULL)',
    HOMEPAGE_ID         VARCHAR         COMMENT '매칭 CRM 회원의 HMPG_ID(미매칭 NULL)',
    ID_RESOLUTION       VARCHAR(20)     COMMENT 'GA측 신뢰도: DIRECT/SESSION_FILL',
    MATCH_METHOD        VARCHAR(30)     COMMENT '매칭방법 MEMBER_ID_EXACT / UNMATCHED',
    MATCH_CONFIDENCE    VARCHAR(10)     COMMENT '매칭신뢰도 HIGH/MEDIUM/NONE',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (USER_PSEUDO_ID)
) COMMENT = 'S-7 신원 브리지(교차소스 유일예외). GA4_IDENTITY ↔ CRM_MEMBER 자연키 해소. SK없음(GOLD 소관). 미매칭 보존';


-- ############################################################################
-- [2026-08-06 O45] 신규 SILVER 테이블 1종 — 마케팅캠페인 마스터
-- ----------------------------------------------------------------------------
-- Q16 「MKTG_CMPGN_NM 전건 NULL」 오진 철회의 산물. 실측: 브리지 조인 100% 해소 ·
-- AGENCY 광고 캠페인명과 이름 일치 76/105(72.4%) → 광고행 89.7% 도달.
-- 실행 스크립트 정본 = 03_top-down_gold/O45_ASSEMBLY_AXES.sql §1
-- ############################################################################
CREATE TABLE IF NOT EXISTS GN_DW.SILVER.CRM_MARKETING_CAMPAIGN (
    MK_CMPGN_CD        VARCHAR       COMMENT 'PK. 마케팅캠페인 코드. TM_CM_CMPGN_MNG.MKTG_CMPGN_NM(NUMBER)의 문자 표현과 조인된다',
    MK_CMPGN_NM        VARCHAR       COMMENT '마케팅캠페인명. AGENCY 광고 CAMPAIGN_NM 과 이름 매칭되는 축',
    USE_YN             VARCHAR       COMMENT '사용여부(원천 그대로 — 폐지분도 과거 실적에 붙으므로 제외하지 않는다)',
    RM                 VARCHAR       COMMENT '비고',
    DW_SOURCE_SYSTEM   VARCHAR       COMMENT '원천 시스템',
    DW_LOAD_TS         TIMESTAMP_NTZ COMMENT '적재 시각',
    DW_UPDATE_TS       TIMESTAMP_NTZ COMMENT '갱신 시각',
    DW_BATCH_ID        VARCHAR       COMMENT '배치 식별'
)
COMMENT = '[O45] 마케팅캠페인 마스터(323행). AGENCY(광고) ↔ CRM(개발실적) conformed 축의 원천.';
