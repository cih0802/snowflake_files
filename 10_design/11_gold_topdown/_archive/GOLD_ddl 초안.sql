-- GN_DW GOLD star schema DDL 초안 (5단계 산출물, compile 검증용)
-- Co-authored with CoCo
-- 입력: GOLD_차원 설계.md(12 DIM) + GOLD_팩트 설계.md(6 FACT: 목표 CRM/ERP 2분할) + GOLD_파생지표 매핑.md(base measure 60+GOAL_CNT).
-- 명명: DIM_*/FACT_*, 차원 대리키 *_SK, 회원 불변키 MEMBER_DK. 측정값 컬럼 주석에 지표#.
-- PK/FK는 Snowflake 정보성(미강제). derived 81은 물리컬럼 아님(SV metric).
-- 보수성: 전부 CREATE TABLE IF NOT EXISTS(비파괴·재실행 안전), DB/스키마 IF NOT EXISTS 선행,
--          팩트 PK는 단일 대리키(*_ID)로 grain 확장·NULL FK에도 PK 위반 없음(자연 grain은 COMMENT).

CREATE DATABASE IF NOT EXISTS GN_DW;
CREATE SCHEMA IF NOT EXISTS GN_DW.GOLD;

-- =====================================================================
-- DIMENSIONS (12) — 생성순서: DATE → ORG → CAMPAIGN → MEMBER → … 
--   (DIM_MEMBER가 최초/최종 캠페인 FK로 DIM_CAMPAIGN 참조, DIM_CAMPAIGN이 DIM_ORG 참조 →
--    REFERENCES 대상 선존재 보장을 위해 ORG·CAMPAIGN을 MEMBER보다 먼저 생성)
-- =====================================================================

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_DATE (
    DATE_SK         NUMBER(8,0)   NOT NULL COMMENT '일자 대리키(YYYYMMDD)',
    FULL_DATE       DATE          NOT NULL,
    YEAR_NO         NUMBER(4,0),
    QUARTER_NO      NUMBER(1,0),
    MONTH_NO        NUMBER(2,0),
    YEAR_MONTH      NUMBER(6,0)   COMMENT '월 자연키(YYYYMM) = 월 grain 팩트의 MONTH_KEY 조인 대상',
    WEEK_NO         NUMBER(2,0),
    DAY_NO          NUMBER(2,0),
    DAY_OF_WEEK     VARCHAR       COMMENT '요일',
    IS_MONTH_END    BOOLEAN       COMMENT '월말 여부(#52 월말활동회원)',
    IS_YEAR_END     BOOLEAN       COMMENT '연말 여부(#50 연도말활동회원 판정)',
    CONSTRAINT PK_DIM_DATE PRIMARY KEY (DATE_SK)
) COMMENT='조회년월/일자 차원. 월 팩트는 YEAR_MONTH로 롤업 조인';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_ORG (
    ORG_SK          NUMBER(18,0)  NOT NULL COMMENT '조직 대리키',
    ORG_BK          VARCHAR       COMMENT '부서 업무키=DEPT_ID(#116). FTG-D/FTG-B/DIM_CAMPAIGN의 ORG_SK 조인 해소키(소스 DEPT_ID/*_DEPT_CD → ORG_SK)',
    ORG_LEVEL       VARCHAR       COMMENT '통계부서레벨(소스 STATS_DEPT_LVL). 각 노드의 계층레벨 기록 → 보류된 레벨/롤업 정책 확정 시 입력. NULL 허용',
    CORP_NAME       VARCHAR       COMMENT '법인(#114)',
    HQ_BRANCH       VARCHAR       COMMENT '본부/지부(#115)',
    DEPARTMENT      VARCHAR       COMMENT '부서(#116)',
    TEAM            VARCHAR       COMMENT '팀(존재 미확정, NULL 허용)',
    CONSTRAINT PK_DIM_ORG PRIMARY KEY (ORG_SK)
) COMMENT='조직 차원(목표·캠페인 귀속용). grain=1행/1 조직노드(소스 DEPT_ID). 소스 TM_CM_DEPT_INFO 전 노드 적재 → 어느 레벨 DEPT_ID든 ORG_BK로 조인 해소. 조인키=ORG_BK(DEPT_ID). ⚠️목표/캠페인 참조 레벨(최하위 전용 여부)·계층 롤업 정책은 보류(SILVER 실데이터 확정)';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_CAMPAIGN (
    CAMPAIGN_SK     NUMBER(18,0)  NOT NULL COMMENT '캠페인 대리키',
    CAMPAIGN_BK     VARCHAR       COMMENT '캠페인 업무키(#120)',
    CAMPAIGN_NAME   VARCHAR       COMMENT '캠페인명(#18)',
    CAMPAIGN_TYPE   VARCHAR       COMMENT '캠페인 유형(#17)',
    DOMESTIC_OVERSEAS VARCHAR     COMMENT '국내/해외 구분(#15)',
    BUSINESS_CASE   VARCHAR       COMMENT '사업/사례 구분(#16)',
    CAMPAIGN_OPEN_DATE DATE       COMMENT '캠페인 오픈일자(#19)',
    COMMON_CAMPAIGN VARCHAR       COMMENT '공통캠페인(#147)',
    PARENT_CAMPAIGN VARCHAR       COMMENT '공통상위캠페인(#119)',
    COMMON_BRAND    VARCHAR       COMMENT '공통브랜드(#117)',
    PROMO_METHOD    VARCHAR       COMMENT '홍보방법(#118)',
    ORG_SK          NUMBER(18,0)  COMMENT '운영조직 FK',
    CONSTRAINT PK_DIM_CAMPAIGN PRIMARY KEY (CAMPAIGN_SK),
    CONSTRAINT FK_CAMPAIGN_ORG FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK)
) COMMENT='캠페인 차원. 실적팩트는 ORG를 캠페인 경유 정렬. 계층(잠정): 공통브랜드>공통상위캠페인>공통캠페인>캠페인';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_MEMBER (
    MEMBER_SK       NUMBER(18,0)  NOT NULL COMMENT 'SCD2 대리키(시점버전)',
    MEMBER_DK       NUMBER(18,0)  NOT NULL COMMENT '불변 durable key(회원번호 기반)',
    MEMBER_BK       VARCHAR       COMMENT '회원번호 업무키(#110)',
    GENDER          VARCHAR       COMMENT '성별(#130)',
    REGION          VARCHAR       COMMENT '지역(#131)',
    MEMBER_STATUS   VARCHAR       COMMENT '회원상태(#132)',
    NEW_EXIST_FLAG  VARCHAR       COMMENT '신규/기존 구분(#113)',
    FIRST_JOIN_DATE DATE          COMMENT '최초가입일=회원번호 생성일(#28)',
    FIRST_CAMPAIGN_SK NUMBER(18,0) COMMENT '최초캠페인 FK(#29) → DIM_CAMPAIGN(정규화)',
    LAST_STOP_DATE  DATE          COMMENT '최종중단일(#30)',
    LAST_CAMPAIGN_SK NUMBER(18,0) COMMENT '최종캠페인 FK(#31) → DIM_CAMPAIGN(정규화)',
    EFFECTIVE_FROM  DATE          NOT NULL,
    EFFECTIVE_TO    DATE,
    IS_CURRENT      BOOLEAN       NOT NULL,
    CONSTRAINT PK_DIM_MEMBER PRIMARY KEY (MEMBER_SK),
    CONSTRAINT FK_MEMBER_FIRST_CAMPAIGN FOREIGN KEY (FIRST_CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK),
    CONSTRAINT FK_MEMBER_LAST_CAMPAIGN FOREIGN KEY (LAST_CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK)
) COMMENT='회원 느린 범주형(SCD2). 시변속성(후원기간/금액대/납입개월)은 FMM 이관';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_MEMBER_IDENTITY (
    IDENTITY_SK     NUMBER(18,0)  NOT NULL COMMENT '신원매핑 대리키',
    MEMBER_DK       NUMBER(18,0)  COMMENT '회원 불변 durable key(DIM_MEMBER.MEMBER_DK)',
    MEMBER_NO       VARCHAR       COMMENT 'CRM 회원번호(#110)',
    MEMNUM          VARCHAR       COMMENT 'memnum 링크키(#111)',
    GA_MEMBER_ID    VARCHAR       COMMENT 'GA member id(#112)',
    SPONSORED_CHILD_CODE VARCHAR  COMMENT '결연아동코드(#122, URL 파싱)',
    MATCH_METHOD    VARCHAR       COMMENT '매핑 알고리즘(SILVER 설계)',
    MATCH_CONFIDENCE NUMBER(5,4)  COMMENT '매핑 신뢰도',
    CONSTRAINT PK_DIM_MEMBER_IDENTITY PRIMARY KEY (IDENTITY_SK)
) COMMENT='GA↔CRM 신원 매핑 브리지(1:N). 쌍단위 grain';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_SPONSORSHIP (
    SPONSORSHIP_SK  NUMBER(18,0)  NOT NULL COMMENT '후원사업 대리키',
    SPONSORSHIP_BK  VARCHAR       COMMENT '후원사업 업무키=후원사업코드 SPNSR_BSNS_ID(#123, FMM·FTG-B SPONSORSHIP_SK 조인키)',
    SPONSORSHIP_NAME VARCHAR      COMMENT '후원사업명(#123)',
    SPONSORSHIP_ABBR VARCHAR      COMMENT '후원사업 약칭(#124)',
    CONSTRAINT PK_DIM_SPONSORSHIP PRIMARY KEY (SPONSORSHIP_SK)
) COMMENT='후원사업 차원(캠페인과 분리)';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_AD_CREATIVE (
    AD_CREATIVE_SK  NUMBER(18,0)  NOT NULL COMMENT '광고소재 대리키',
    MEDIA           VARCHAR       COMMENT '매체명/공동브랜드(#11)',
    PLATFORM        VARCHAR       COMMENT '플랫폼(#12)',
    PLATFORM_TYPE   VARCHAR       COMMENT '플랫폼 유형(#13)',
    DEVICE          VARCHAR       COMMENT '기기(#14)',
    CREATIVE        VARCHAR       COMMENT '소재(#20)',
    CM_POSITION     VARCHAR       COMMENT 'CM 위치(#21)',
    DURATION_SEC    NUMBER(6,0)   COMMENT '초수(#22)',
    CONSTRAINT PK_DIM_AD_CREATIVE PRIMARY KEY (AD_CREATIVE_SK)
) COMMENT='AGENCY 광고 소재 차원';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_GA_SOURCE (
    GA_SOURCE_SK    NUMBER(18,0)  NOT NULL COMMENT 'GA 세션소스 대리키',
    UTM_SOURCE_MEDIUM VARCHAR     COMMENT '세션 소스/매체(#109)',
    UTM_CONTENT     VARCHAR       COMMENT '세션 수동 광고 콘텐츠(#103)',
    SEARCH_KEYWORD  VARCHAR       COMMENT '세션 수동 검색어(#104)',
    CONSTRAINT PK_DIM_GA_SOURCE PRIMARY KEY (GA_SOURCE_SK)
) COMMENT='GA 세션 소스/매체 차원';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_SERVICE (
    SERVICE_SK      NUMBER(18,0)  NOT NULL COMMENT '서비스 대리키',
    SEND_TYPE_L     VARCHAR       COMMENT '발송구분 대(#133)',
    SEND_TYPE_M     VARCHAR       COMMENT '발송구분 중(#134)',
    SEND_TYPE_S     VARCHAR       COMMENT '발송구분 소(#135)',
    SERVICE_TYPE    VARCHAR       COMMENT '발송/참여 subtype',
    SERVICE_NAME    VARCHAR       COMMENT '서비스명',
    PARTICIPATION_DEF VARCHAR     COMMENT '참여 정의(현업 확인)',
    CONSTRAINT PK_DIM_SERVICE PRIMARY KEY (SERVICE_SK)
) COMMENT='발송/참여 서비스 차원(구 SEND_TYPE 통합)';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_PAYMENT (
    PAYMENT_SK      NUMBER(18,0)  NOT NULL COMMENT '납입 대리키',
    PAYMENT_METHOD  VARCHAR       COMMENT '납입방식(#125)',
    FEE_TYPE        VARCHAR       COMMENT '회비유형 정기/일시(보류 컬럼, #66~68 measure와 이중표현 → 5단계 단일화)',
    CONSTRAINT PK_DIM_PAYMENT PRIMARY KEY (PAYMENT_SK)
) COMMENT='납입 차원. FMM은 납입방식 grain만 참조(결정8)';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_GA_EVENT (
    GA_EVENT_SK     NUMBER(18,0)  NOT NULL COMMENT 'GA 이벤트 대리키',
    EVENT_CATEGORY  VARCHAR       COMMENT 'event_category(#99)',
    EVENT_LABEL     VARCHAR       COMMENT 'event_label(#100)',
    EVENT_ACTION    VARCHAR       COMMENT 'event_action(#101)',
    CONSTRAINT PK_DIM_GA_EVENT PRIMARY KEY (GA_EVENT_SK)
) COMMENT='GA4 이벤트 분류 차원';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_REASON (
    REASON_SK       NUMBER(18,0)  NOT NULL COMMENT '사유 대리키',
    REASON_TYPE     VARCHAR       COMMENT '미납/중단 구분',
    REASON_NAME     VARCHAR       COMMENT '미납사유(#82)·중단사유(#162)',
    CONSTRAINT PK_DIM_REASON PRIMARY KEY (REASON_SK)
) COMMENT='미납/중단 사유 차원';

-- =====================================================================
-- FACTS (6) — FMM·FTG_DEV·FTG_BIZ·FSE·FGA·FAD. 팩트 PK는 단일 대리키(*_ID); 자연 grain은 COMMENT에 보존
-- =====================================================================

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_MEMBER_MONTHLY (
    FMM_ID                  NUMBER(38,0) NOT NULL COMMENT '팩트 대리키(grain 확장에도 PK 불변)',
    MONTH_KEY               NUMBER(6,0)  NOT NULL COMMENT '조회년월 YYYYMM → DIM_DATE.YEAR_MONTH 조인(비FK; YEAR_MONTH가 PK 아님). 결정7, DATE_SK 미사용',
    MEMBER_DK               NUMBER(18,0) NOT NULL COMMENT '회원 불변키 → DIM_MEMBER.MEMBER_DK 조인(비FK, durable; PK=MEMBER_SK이라 FK 불가). 시점버전은 (MEMBER_DK, MONTH_KEY)로 MEMBER_SK 해소',
    CAMPAIGN_SK             NUMBER(18,0) COMMENT '가입 캠페인 FK',
    SPONSORSHIP_SK          NUMBER(18,0) COMMENT '후원사업 FK',
    PAYMENT_SK              NUMBER(18,0) COMMENT '납입방식 FK(회비유형 제외)',
    REASON_SK               NUMBER(18,0) COMMENT '중단/미납 사유 FK(NULL 허용)',
    -- measures (28)
    DEV_CRM_CNT             NUMBER(38,4) COMMENT 'CRM 개발(건) #4 = SUM(금액)/10000',
    DEV_GA_CNT              NUMBER(38,4) COMMENT 'GA 개발(건) #5 = SUM(금액)/10000',
    STOP_CNT                NUMBER(38,4) COMMENT '중단(건) #35',
    UNPAID_CNT              NUMBER(38,4) COMMENT '미납(건) #36',
    ACTIVE_CNT              NUMBER(38,4) COMMENT '활동(건) #37 (준가산)',
    DECREASE_CNT            NUMBER(38,4) COMMENT '감액(건) #38',
    ACTIVE_YEARSTART_CNT    NUMBER(38,4) COMMENT '연도초 활동회원(건) #49 (준가산)',
    ACTIVE_YEAREND_CNT      NUMBER(38,4) COMMENT '연도말 활동회원(건) #50 (준가산)',
    ACTIVE_MONTHEND_CNT     NUMBER(38,4) COMMENT '월말활동회원(건) #52 (준가산)',
    ACTIVE_PREVMONTH_CNT    NUMBER(38,4) COMMENT '전월말 활동회원(건) #53 (준가산)',
    REGULAR_FEE             NUMBER(38,4) COMMENT '정기회비(원) #66',
    REGULAR_ONETIME_FEE     NUMBER(38,4) COMMENT '정기회원 일시회비(원) #67',
    ONETIME_ONETIME_FEE     NUMBER(38,4) COMMENT '일시회원 일시회비(원) #68',
    PAID_FEE                NUMBER(38,4) COMMENT '납입회비(원) #69',
    PAID_AMT                NUMBER(38,4) COMMENT '납입(원) #70 (#69와 중복 의심)',
    BILLED_AMT              NUMBER(38,4) COMMENT '청구(원) #71',
    UNPAID_BY_CAMPAIGN_CNT  NUMBER(38,4) COMMENT '캠페인별 미납(건) #83',
    UNPAID_BY_STATUS_CNT    NUMBER(38,4) COMMENT '회원상태별 미납(건) #84',
    DEV_MEMBER_CNT          NUMBER(38,0) COMMENT '개발(명) #148',
    DEV_CNT                 NUMBER(38,4) COMMENT '개발(건) #149',
    INCREASE_MEMBER_CNT     NUMBER(38,0) COMMENT '증액(명) #150',
    INCREASE_CNT            NUMBER(38,4) COMMENT '증액(건) #151',
    ACTIVE_MEMBER_CNT       NUMBER(38,0) COMMENT '활동(명) #156 (준가산)',
    ACTIVE_CNT_V2           NUMBER(38,4) COMMENT '활동(건) #157 (#37 중복 의심, 준가산)',
    ACTIVE_CUM_MEMBER_CNT   NUMBER(38,0) COMMENT '활동누계(명) #158 (비가산)',
    ACTIVE_CUM_CNT          NUMBER(38,4) COMMENT '활동누계(건) #159 (비가산)',
    PAID_FEE_BY_DEVCAMP     NUMBER(38,4) COMMENT '개발캠페인별 납입회비(원) 신규#1',
    CHURN_CNT               NUMBER(38,4) COMMENT '캠페인별 이탈(건) 신규#20',
    -- degenerate / snapshot (13)
    DEV_TYPE                VARCHAR      COMMENT '개발구분 #121',
    IS_NEW                  BOOLEAN      COMMENT '신규 #32',
    IS_INCREASE             BOOLEAN      COMMENT '증액 #33',
    IS_REDONATION           BOOLEAN      COMMENT '재후원 #34',
    CAMPAIGN_JOIN_DATE      DATE         COMMENT '캠페인 가입일 #27',
    CAMPAIGN_STOP_DATE      DATE         COMMENT '가입캠페인 중단일 #26',
    DONATION_AMT_BAND1      VARCHAR      COMMENT '후원금액대1(5만) #72',
    DONATION_AMT_BAND2      VARCHAR      COMMENT '후원금액대2(1만) #73',
    DONATION_PERIOD_BAND1   VARCHAR      COMMENT '후원기간대1(5년) #74',
    DONATION_PERIOD_BAND2   VARCHAR      COMMENT '후원기간대2(1년) #75',
    DONATION_MONTHS         NUMBER(6,0)  COMMENT '후원기간(개월) #127',
    DONATION_YEARS          NUMBER(4,0)  COMMENT '후원기간(년) #128',
    PAID_MONTHS             NUMBER(6,0)  COMMENT '납입개월수 #129',
    CONSTRAINT PK_FMM PRIMARY KEY (FMM_ID),
    CONSTRAINT FK_FMM_CAMPAIGN FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK),
    CONSTRAINT FK_FMM_SPONSOR FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK),
    CONSTRAINT FK_FMM_PAYMENT FOREIGN KEY (PAYMENT_SK) REFERENCES GN_DW.GOLD.DIM_PAYMENT (PAYMENT_SK),
    CONSTRAINT FK_FMM_REASON FOREIGN KEY (REASON_SK) REFERENCES GN_DW.GOLD.DIM_REASON (REASON_SK)
) COMMENT='핵심 팩트: 회원·월 스냅샷. 업무 grain=(MONTH_KEY, MEMBER_DK); Q1 확장시 +CAMPAIGN/SPONSORSHIP. PK=대리키';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_TARGET_DEV (
    FTG_DEV_ID              NUMBER(38,0) NOT NULL COMMENT '팩트 대리키',
    MONTH_KEY               NUMBER(6,0)  NOT NULL COMMENT '조회년월 YYYYMM(STDYY+STDR_MT) → DIM_DATE.YEAR_MONTH 조인(비FK)',
    ORG_SK                  NUMBER(18,0) NOT NULL COMMENT '조직 FK(직접, 목표 전용). 소스 DEPT_ID → DIM_ORG.ORG_BK 해소(레벨 무관)',
    DEV_TYPE                VARCHAR      NOT NULL COMMENT '개발구분(MM015, MBER_DVLP_DIV_CD). FMM #121 conform. degenerate',
    GOAL_CNT                NUMBER(38,4) COMMENT '회원개발목표수(파생 #1~3 목표대비개발율 분모). 가산 A',
    CONSTRAINT PK_FTG_DEV PRIMARY KEY (FTG_DEV_ID),
    CONSTRAINT FK_FTG_DEV_ORG FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK)
) COMMENT='목표 팩트(CRM 회원개발목표): 업무 grain=(MONTH_KEY, ORG, DEV_TYPE). 소스=CRM TM_CM_MBER_DVLP_GOAL(확정). 회원 grain 아님. PK=대리키';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_TARGET_BIZ (
    FTG_BIZ_ID              NUMBER(38,0) NOT NULL COMMENT '팩트 대리키',
    MONTH_KEY               NUMBER(6,0)  NOT NULL COMMENT '조회년월 YYYYMM → DIM_DATE.YEAR_MONTH 조인(비FK)',
    ORG_SK                  NUMBER(18,0) NOT NULL COMMENT '조직 FK(직접, 목표 전용)',
    SPONSORSHIP_SK          NUMBER(18,0) NOT NULL COMMENT '후원사업 FK',
    CAMPAIGN_SK             NUMBER(18,0) COMMENT '캠페인 FK(캠페인별 목표시, NULL 허용)',
    TARGET_ANNUAL_CNT       NUMBER(38,4) COMMENT '연사업목표(건) #152',
    TARGET_SUPP_CNT         NUMBER(38,4) COMMENT '추경목표(건) #153',
    TARGET_ANNUAL_CUM_CNT   NUMBER(38,4) COMMENT '연사업누계목표(건) #154 (비가산)',
    TARGET_SUPP_CUM_CNT     NUMBER(38,4) COMMENT '추경누계목표(건) #155 (비가산)',
    CONSTRAINT PK_FTG_BIZ PRIMARY KEY (FTG_BIZ_ID),
    CONSTRAINT FK_FTG_BIZ_ORG FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK),
    CONSTRAINT FK_FTG_BIZ_SPONSOR FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK),
    CONSTRAINT FK_FTG_BIZ_CAMPAIGN FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK)
) COMMENT='목표 팩트(ERP 사업목표): 업무 grain=(MONTH_KEY, ORG, SPONSORSHIP[, CAMPAIGN]). 소스 미수령(ERP/사업계획)→적재예약. 회원 grain 아님. PK=대리키';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_SERVICE_EVENT (
    EVENT_ID                NUMBER(38,0) NOT NULL COMMENT '발송 이벤트 대리키',
    DATE_SK                 NUMBER(8,0)  NOT NULL COMMENT '발송일 #137',
    MEMBER_DK               NUMBER(18,0) NOT NULL COMMENT '회원 불변키 → DIM_MEMBER.MEMBER_DK 조인(비FK, durable)',
    SERVICE_SK              NUMBER(18,0) NOT NULL COMMENT '서비스 FK',
    CAMPAIGN_SK             NUMBER(18,0) COMMENT '캠페인 FK',
    SPONSORSHIP_SK          NUMBER(18,0) COMMENT '후원사업 FK(NULL 허용)',
    -- measures (17)
    SEND_CNT                NUMBER(38,0) COMMENT '발송수(명) #85 (중복포함)',
    SUCCESS_CNT             NUMBER(38,0) COMMENT '성공수(명) #86',
    FAIL_CNT                NUMBER(38,0) COMMENT '실패수(명) #87',
    LETTER_PART_MEMBER      NUMBER(38,0) COMMENT '서신참여(명) #88',
    LETTER_PART_CNT         NUMBER(38,4) COMMENT '서신참여(건) #89',
    GIFT_PART_MEMBER        NUMBER(38,0) COMMENT '선물금참여(명) #90',
    GIFT_PART_AMT           NUMBER(38,4) COMMENT '선물금참여(원) #91',
    D5_LETTER_MEMBER        NUMBER(38,0) COMMENT '+5일차 서신참여(명) #139',
    D5_LETTER_CNT           NUMBER(38,4) COMMENT '+5일차 서신참여(건) #140',
    D5_GIFT_MEMBER          NUMBER(38,0) COMMENT '+5일차 선물금참여(명) #141',
    D5_GIFT_CNT             NUMBER(38,4) COMMENT '+5일차 선물금참여(건) #142',
    D5_INCREASE_MEMBER      NUMBER(38,0) COMMENT '+5일차 증액참여(명) #143',
    D5_INCREASE_CNT         NUMBER(38,4) COMMENT '+5일차 증액참여(건) #144',
    D5_STOP_MEMBER          NUMBER(38,0) COMMENT '+5일차 중단(명) #145',
    D5_STOP_CNT             NUMBER(38,4) COMMENT '+5일차 중단(건) #146',
    SERVICE_MEMBER          NUMBER(38,0) COMMENT '서비스(명) #160',
    SERVICE_CNT             NUMBER(38,4) COMMENT '서비스(건) #161',
    -- degenerate (2)
    SEND_TITLE              VARCHAR      COMMENT '제목(발송) #136',
    SEND_STATUS             VARCHAR      COMMENT '발송상태 #138',
    CONSTRAINT PK_FSE PRIMARY KEY (EVENT_ID),
    CONSTRAINT FK_FSE_SERVICE FOREIGN KEY (SERVICE_SK) REFERENCES GN_DW.GOLD.DIM_SERVICE (SERVICE_SK),
    CONSTRAINT FK_FSE_CAMPAIGN FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK),
    CONSTRAINT FK_FSE_SPONSOR FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK),
    CONSTRAINT FK_FSE_DATE FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK)
) COMMENT='발송/참여 이벤트 팩트. 업무 grain=(발송일×회원×서비스×캠페인). PK=대리키';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_GA_BEHAVIOR (
    FGA_ID                  NUMBER(38,0) NOT NULL COMMENT '팩트 대리키(grain 컬럼 NULL 허용 대비)',
    DATE_SK                 NUMBER(8,0)  NOT NULL COMMENT '일자',
    IDENTITY_SK             NUMBER(18,0) NOT NULL COMMENT '신원매핑 FK(ga_member_id→MEMBER_DK)',
    GA_EVENT_SK             NUMBER(18,0) NOT NULL COMMENT 'GA 이벤트 FK',
    GA_SOURCE_SK            NUMBER(18,0) NOT NULL COMMENT 'GA 세션소스 FK',
    CAMPAIGN_SK             NUMBER(18,0) COMMENT '세션캠페인 FK(#102, NULL 허용)',
    PAGE_PATH_QUERY         VARCHAR      COMMENT '페이지경로+쿼리 #105(고카디널리티 attr, NULL 허용)',
    -- measures (7)
    VISIT_CNT               NUMBER(38,0) COMMENT '방문수(명) #92',
    ACTIVE_USER_CNT         NUMBER(38,0) COMMENT '활성사용자수(명) #93 (비가산: GA 고유추정)',
    TOTAL_USER_CNT          NUMBER(38,0) COMMENT '총사용자(명) #94 (비가산)',
    EVENT_CNT               NUMBER(38,0) COMMENT '이벤트수(명) #95',
    VIEW_CNT                NUMBER(38,0) COMMENT '조회수(명) #96',
    SESSION_CNT             NUMBER(38,0) COMMENT '세션수(명) #97 (비가산)',
    SCROLL_DEPTH            NUMBER(18,4) COMMENT '스크롤깊이 #107 (비가산, 단위 미확정)',
    -- attr (1)
    PAGE_LOCATION           VARCHAR      COMMENT '페이지위치 #106(결연아동코드 파싱원천)',
    CONSTRAINT PK_FGA PRIMARY KEY (FGA_ID),
    CONSTRAINT FK_FGA_IDENTITY FOREIGN KEY (IDENTITY_SK) REFERENCES GN_DW.GOLD.DIM_MEMBER_IDENTITY (IDENTITY_SK),
    CONSTRAINT FK_FGA_EVENT FOREIGN KEY (GA_EVENT_SK) REFERENCES GN_DW.GOLD.DIM_GA_EVENT (GA_EVENT_SK),
    CONSTRAINT FK_FGA_SOURCE FOREIGN KEY (GA_SOURCE_SK) REFERENCES GN_DW.GOLD.DIM_GA_SOURCE (GA_SOURCE_SK),
    CONSTRAINT FK_FGA_CAMPAIGN FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK),
    CONSTRAINT FK_FGA_DATE FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK)
) COMMENT='GA4 행동 팩트. 업무 grain=GA4 export(일×member×event×source×page). 사용자/세션 distinct는 비가산. PK=대리키(page NULL 대비)';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_AD_PERFORMANCE (
    AD_PERF_ID              NUMBER(38,0) NOT NULL COMMENT '팩트 대리키(AD_CREATIVE_SK NULL 행 대비)',
    DATE_SK                 NUMBER(8,0)  NOT NULL COMMENT '일자',
    CAMPAIGN_SK             NUMBER(18,0) NOT NULL COMMENT '캠페인 FK',
    AD_CREATIVE_SK          NUMBER(18,0) COMMENT '광고소재 FK(GA광고비 행은 NULL)',
    SOURCE_SYSTEM           VARCHAR      NOT NULL COMMENT 'GA/AGENCY/GADS 출처 구분(degenerate, 2026-06-24 GADS 추가)',
    -- measures (4)
    GA_AD_COST              NUMBER(38,4) COMMENT 'GA 광고비(원) #6',
    IMPRESSION_CNT          NUMBER(38,0) COMMENT '노출수 #23',
    CLICK_CNT               NUMBER(38,0) COMMENT '클릭수 #24',
    INBOUND_CALL_CNT        NUMBER(38,0) COMMENT '인입콜 #25',
    -- reserved (미적재, BRONZE 컨트랙트 입고 후 활성)
    PLACEMENT_COST          NUMBER(38,4) COMMENT '[예약] AGENCY 편성비(원) — raw 부재',
    FUNDRAISING_COST        NUMBER(38,4) COMMENT '[예약] ERP 모금성비용(원) — raw 부재',
    -- reserved (2026-06-24 정의서 반영, 미수령→예약. 정본 GOLD_정의서_업데이트 20260624.md)
    GA_CONVERSION_PERSON    NUMBER(38,0) COMMENT '[예약] GA 전환수(명) — AGENCY∪GA4 (H3)',
    GA_CONVERSION_CASE      NUMBER(38,0) COMMENT '[예약] GA 전환수(건) — AGENCY∪GA4 (H3, 공10 CVR 분자)',
    EXEC_BUDGET_ERP         NUMBER(38,4) COMMENT '[예약] 집행예산 확정(ERP 마감값) (H4)',
    EXEC_BUDGET_EST         NUMBER(38,4) COMMENT '[예약] 집행예산 추정치(대행사) (H4)',
    PLANNED_BUDGET          NUMBER(38,4) COMMENT '[예약] 편성예산(월/연/누계, ERP) (H4)',
    TARGET_GROUP            VARCHAR      COMMENT '[예약] 잠재고객 이름=타겟그룹(원천표기 GA4) (M5)',
    CONSTRAINT PK_FAD PRIMARY KEY (AD_PERF_ID),
    CONSTRAINT FK_FAD_CAMPAIGN FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK),
    CONSTRAINT FK_FAD_CREATIVE FOREIGN KEY (AD_CREATIVE_SK) REFERENCES GN_DW.GOLD.DIM_AD_CREATIVE (AD_CREATIVE_SK),
    CONSTRAINT FK_FAD_DATE FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK)
) COMMENT='광고성과 팩트. 업무 grain=(일×캠페인×소재×출처). 비용 raw 부재→예약컬럼. PK=대리키(소재 NULL 대비)';

-- =====================================================================
-- 키 컬럼 매핑 레퍼런스 (Key 컬럼 → 참조 테이블.컬럼)
--   [PK]=기본키(대리키, ETL 생성)  [FK]=외래키(제약으로 강제표기됨)  [JOIN]=비FK 조인(대상이 PK 아님)  [BK]=업무키(원천 지표#)
-- =====================================================================
-- DIM_DATE            : DATE_SK [PK·생성, =YYYYMMDD] | YEAR_MONTH [BK, =YYYYMM]
-- DIM_MEMBER          : MEMBER_SK [PK·생성, SCD2] | MEMBER_DK [DK, 회원번호기반 불변] | MEMBER_BK [BK, =CRM 회원번호 #110]
--                       FIRST_CAMPAIGN_SK [FK → DIM_CAMPAIGN.CAMPAIGN_SK (#29)] | LAST_CAMPAIGN_SK [FK → DIM_CAMPAIGN.CAMPAIGN_SK (#31)]
-- DIM_MEMBER_IDENTITY : IDENTITY_SK [PK·생성] | MEMBER_DK[DK] | MEMBER_NO[BK #110] | MEMNUM[BK #111] | GA_MEMBER_ID[BK #112]
-- DIM_ORG             : ORG_SK [PK·생성]
-- DIM_CAMPAIGN        : CAMPAIGN_SK [PK·생성] | ORG_SK [FK → DIM_ORG.ORG_SK]
-- DIM_SPONSORSHIP     : SPONSORSHIP_SK [PK·생성]
-- DIM_AD_CREATIVE     : AD_CREATIVE_SK [PK·생성]
-- DIM_GA_SOURCE       : GA_SOURCE_SK [PK·생성]
-- DIM_SERVICE         : SERVICE_SK [PK·생성]
-- DIM_PAYMENT         : PAYMENT_SK [PK·생성]
-- DIM_GA_EVENT        : GA_EVENT_SK [PK·생성]
-- DIM_REASON          : REASON_SK [PK·생성]
-- FACT_MEMBER_MONTHLY : FMM_ID [PK·생성]
--                       MONTH_KEY     [JOIN → DIM_DATE.YEAR_MONTH]
--                       MEMBER_DK     [JOIN → DIM_MEMBER.MEMBER_DK (durable; 시점=+MONTH_KEY로 MEMBER_SK 해소)]
--                       CAMPAIGN_SK   [FK → DIM_CAMPAIGN.CAMPAIGN_SK]
--                       SPONSORSHIP_SK[FK → DIM_SPONSORSHIP.SPONSORSHIP_SK]
--                       PAYMENT_SK    [FK → DIM_PAYMENT.PAYMENT_SK]
--                       REASON_SK     [FK → DIM_REASON.REASON_SK]
-- FACT_TARGET_DEV     : FTG_DEV_ID [PK·생성]  (CRM 회원개발목표·확정)
--                       MONTH_KEY     [JOIN → DIM_DATE.YEAR_MONTH]
--                       ORG_SK        [FK → DIM_ORG.ORG_SK]
--                       DEV_TYPE      [degenerate 개발구분 MM015, FMM #121 conform]
-- FACT_TARGET_BIZ     : FTG_BIZ_ID [PK·생성]  (ERP 사업목표·적재예약)
--                       MONTH_KEY     [JOIN → DIM_DATE.YEAR_MONTH]
--                       ORG_SK        [FK → DIM_ORG.ORG_SK]
--                       SPONSORSHIP_SK[FK → DIM_SPONSORSHIP.SPONSORSHIP_SK]
--                       CAMPAIGN_SK   [FK → DIM_CAMPAIGN.CAMPAIGN_SK]
-- FACT_SERVICE_EVENT  : EVENT_ID [PK·생성]
--                       DATE_SK       [FK → DIM_DATE.DATE_SK]
--                       MEMBER_DK     [JOIN → DIM_MEMBER.MEMBER_DK (durable)]
--                       SERVICE_SK    [FK → DIM_SERVICE.SERVICE_SK]
--                       CAMPAIGN_SK   [FK → DIM_CAMPAIGN.CAMPAIGN_SK]
--                       SPONSORSHIP_SK[FK → DIM_SPONSORSHIP.SPONSORSHIP_SK]
-- FACT_GA_BEHAVIOR    : FGA_ID [PK·생성]
--                       DATE_SK       [FK → DIM_DATE.DATE_SK]
--                       IDENTITY_SK   [FK → DIM_MEMBER_IDENTITY.IDENTITY_SK (→MEMBER_DK 해소)]
--                       GA_EVENT_SK   [FK → DIM_GA_EVENT.GA_EVENT_SK]
--                       GA_SOURCE_SK  [FK → DIM_GA_SOURCE.GA_SOURCE_SK]
--                       CAMPAIGN_SK   [FK → DIM_CAMPAIGN.CAMPAIGN_SK]
-- FACT_AD_PERFORMANCE : AD_PERF_ID [PK·생성]
--                       DATE_SK       [FK → DIM_DATE.DATE_SK]
--                       CAMPAIGN_SK   [FK → DIM_CAMPAIGN.CAMPAIGN_SK]
--                       AD_CREATIVE_SK[FK → DIM_AD_CREATIVE.AD_CREATIVE_SK (GA광고비 행 NULL)]
--                       SOURCE_SYSTEM [degenerate, FK 없음]
-- =====================================================================
