-- GN_DW.GOLD 스키마 전체 DDL(24개 테이블)에 정보성 FK/PK 제약 및 인수인계용 문서 주석 추가.
-- Co-authored with CoCo
/*
================================================================================
  GN_DW.GOLD — 전체 테이블 DDL (24개: DIM 15 + FACT 9)
  작성일   : 2026-07-02 (컬럼 COMMENT 추가: 2026-07-03; 배포·적재: 2026-07-20 GN_DW.GOLD 24테이블 생성·적재 완료)
  참고 문서 : gold 스키마 컬럼 인벤토리_20260629.csv
               GOLD_개발자 전달노트_20260629.md
               03_top-down_gold/03_테이블 설계.md
--------------------------------------------------------------------------------
  실행 규칙
  ─────────────────────────────────────────────────────────────────────────────
  1. DIM 15개를 모두 생성한 뒤 FACT 9개를 생성한다.
  2. DIM_DATE → DIM_ORG → DIM_MEMBER → 나머지 DIM → FACT 순서 준수.
  3. FK_타깃에 '※비강제' 표기된 컬럼은 FOREIGN KEY 제약 없이 일반 컬럼으로 생성.
  4. 타입 길이(VARCHAR 자릿수)는 PENDING — 현재 미정. 운영 후 ALTER 예정.
     단, MEMBER_DK 는 [실측06-30] VARCHAR(10) 확정.
  5. 모든 테이블 공통: DW_SOURCE_SYSTEM / DW_LOAD_TS(최초적재, NOT NULL) /
     DW_UPDATE_TS(최종적재) / DW_BATCH_ID(=dbt invocation_id) 감사 컬럼 포함.
  6. FACT_GA_BEHAVIOR 의 비가산 지표(BOUNCE_RATE·AVG_SESSION_DURATION 등)는
     그레인 기준 값 — 상위 레벨 재합산 금지(테이블 COMMENT 명시).
  7. [2026-07-20 적재 완료] CRM·GA4·ERP·AGENCY SILVER→GOLD 적재 완료(24테이블 + WIDE VIEW 9개).
     단 사업목표(FTG_B, 원천=CRM 신규 목표 테이블 CRM_BIZ_TARGET·데이터 입고 대기)·모금성비용(FBD, ERP 원천 부재)은 미입고, ADMIN(앱푸시·조회수)은 제외 확정 → 해당 컬럼만 생성·미채움(FACT_TARGET_BIZ=0행).
  8. FK/PK 제약은 파일 하단 [관계 제약] 섹션에서 ALTER 로 일괄 선언.
     - 전부 NOT ENFORCED NORELY (정보성) — Snowflake 는 NOT NULL 외 강제 안 함.
       ERD·BI 관계 인식·문서화 용도이며, 데이터 미검증 단계이므로 RELY 는 보류.
     - 참조 대상이 비유일(SCD2 MEMBER_DK / 월conform MONTH_KEY)인 FK 는
       Snowflake 규칙상 선언 불가 → 동일 섹션에 [보류] 사유·조인경로 명문화.
     - FACT PK/UNIQUE 는 grain 미확정으로 보류(설계 문서 준수).
  9. 각 컬럼의 COMMENT 는 gold 스키마 컬럼 인벤토리_20260629.csv 설명 컬럼 기준.
================================================================================
*/

USE DATABASE GN_DW;
CREATE SCHEMA IF NOT EXISTS GN_DW.GOLD 
  COMMENT = 'Gold 레이어 — 킴볼 스타스키마(DIM 15 + FACT 9) 분석 소비 계층. 지표 215개 귀속, WIDE VIEW 9개 제공';
USE SCHEMA GOLD;

-- ============================================================================
-- DIM 1: DIM_DATE — 날짜 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_DATE (
    DATE_SK             NUMBER(8,0)     NOT NULL PRIMARY KEY COMMENT 'YYYYMMDD',
    FULL_DATE           DATE            COMMENT '실제 일자',
    YEAR                NUMBER(4,0)     COMMENT '년',
    MONTH               NUMBER(2,0)     COMMENT '월',
    MONTH_KEY           NUMBER(6,0)     COMMENT 'YYYYMM (월팩트 conform)',
    DAY                 NUMBER(2,0)     COMMENT '일',
    DAY_OF_WEEK         VARCHAR         COMMENT '요일',
    WEEK_OF_YEAR        NUMBER(2,0)     COMMENT '주차',
    QUARTER             NUMBER(1,0)     COMMENT '분기',
    IS_HOLIDAY          BOOLEAN         COMMENT '휴일여부',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '날짜 차원 (1일 grain)';


-- ============================================================================
-- DIM 2: DIM_ORG — 조직 차원 (SCD1)  ※ DEC-2: 조직 변경이력 소스 없음·as-was 요구 없음 → SCD2 예약컬럼 삭제(2026-07-07)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_ORG (
    ORG_SK              NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '조직 대리키 (=hash(DEPT_ID), PK)',
    ORG_DK              NUMBER(38,0)    NOT NULL COMMENT '불변 조직키 (=hash(DEPT_ID); SCD1이라 ORG_SK와 1:1)',
    CORP                VARCHAR         COMMENT '법인(#114)',
    DIVISION            VARCHAR         COMMENT '본부/지부(#115)',
    DEPARTMENT          VARCHAR         COMMENT '부서(#116)',
    TEAM                VARCHAR         COMMENT '팀',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '조직 차원 (SCD1 · 1조직노드)';


-- ============================================================================
-- DIM 3: DIM_MEMBER — 회원 차원 (SCD2)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER (
    MEMBER_SK           NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '버전 대리키',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키(조인용)',  -- SCD2 DK; [실측06-30]VARCHAR(10)
    GENDER              VARCHAR         COMMENT '성별(#130)',
    REGION              VARCHAR         COMMENT '지역(#131)',
    AGE_BAND            VARCHAR         COMMENT '연령대(overview). 원천: 개발/증감 테이블 AGE 스냅샷',
    MEMBER_STATUS       VARCHAR         COMMENT '회원상태(#132)',
    MEMBER_TYPE         VARCHAR         COMMENT '회원구분(05 2-1). 원천: MBER_DIV_CD(MM018 개인/기업/단체)',
    NEW_EXISTING_FLAG   VARCHAR         COMMENT '신규기존구분(#113)',
    FIRST_JOIN_DATE     DATE            COMMENT '최초가입일=회원번호 생성일(#28)',
    FIRST_CAMPAIGN      VARCHAR         COMMENT '최초캠페인(#29)',
    ENROLL_PATH         VARCHAR         COMMENT '가입경로(overview 2-1). 원천: JOIN_PATH_CD(MM014)',
    FIRST_SPONSORSHIP   VARCHAR         COMMENT '최초후원사업(회원 스냅샷). 원천: TM_MM_FDRM_MBER_SPNSR_BSNS',
    LAST_STOP_DATE      DATE            COMMENT '최종중단일(#30)',
    LAST_CAMPAIGN       VARCHAR         COMMENT '최종캠페인(#31)',
    CURRENT_SPONSORSHIP VARCHAR         COMMENT '현재후원사업(회원 스냅샷). 원천: TM_MM_FDRM_MBER_SPNSR_BSNS',
    EFFECTIVE_FROM      DATE            COMMENT 'SCD2 유효시작',
    EFFECTIVE_TO        DATE            COMMENT 'SCD2 유효종료',
    IS_CURRENT          BOOLEAN         COMMENT '현재행 여부',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 차원 (SCD2 · 회원 상태버전)';


-- ============================================================================
-- DIM 4: DIM_MEMBER_IDENTITY — 회원 신원 브리지 (P5 durable key)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER_IDENTITY (
    IDENTITY_SK         NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '회원 식별 대리키 (ETL 일련번호, PK)',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키',  -- ※비강제 FK→DIM_MEMBER(SCD2/비유일)
    MEMBER_NO           VARCHAR         NOT NULL COMMENT '회원번호(#110)',
    MEMNUM              VARCHAR         COMMENT 'memnum(#111)',
    GA_MEMBER_ID        VARCHAR         COMMENT 'member id(#112)',
    HOMEPAGE_ID         VARCHAR         COMMENT '홈페이지/앱 ID. 원천: TM_MM_FDRM_MBER_INFO.HMPG_ID',
    CHILD_CODE          VARCHAR         COMMENT '결연아동코드(#122, URL 파싱)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 신원 브리지 (MEMBER_DK × GA member_id · P5 durable key)';


-- ============================================================================
-- DIM 5: DIM_CAMPAIGN — 캠페인 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_CAMPAIGN (
    CAMPAIGN_SK         NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '캠페인 대리키 (ETL 일련번호, PK)',
    CAMPAIGN_BK         VARCHAR         NOT NULL COMMENT '캠페인 업무키(BK, 자연키)',
    BRAND               VARCHAR         COMMENT '공통브랜드(#117)',
    PARENT_CAMPAIGN     VARCHAR         COMMENT '공통상위캠페인(#119)',
    CAMPAIGN_NAME       VARCHAR         COMMENT '캠페인명(#18·120·147)',
    PROMO_METHOD        VARCHAR         COMMENT '홍보방법(#118)',
    CAMPAIGN_TYPE       VARCHAR         COMMENT '캠페인 유형(#17)',
    DOMESTIC_OVERSEAS   VARCHAR         COMMENT '국내/해외(#15)',
    BIZ_CASE_TYPE       VARCHAR         COMMENT '사업/사례(#16)',
    CAMPAIGN_OPEN_DATE  DATE            COMMENT '오픈일자(#19)',
    ORG_SK              NUMBER(38,0)    COMMENT '캠페인 귀속조직',  -- FK→DIM_ORG
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '캠페인 차원 (1캠페인)';


-- ============================================================================
-- DIM 6: DIM_SPONSORSHIP — 후원사업 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_SPONSORSHIP (
    SPONSORSHIP_SK      NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '후원사업 대리키 (ETL 일련번호, PK)',
    SPONSORSHIP_BK      VARCHAR         NOT NULL COMMENT '후원사업 업무키(BK, 자연키)',
    SPONSORSHIP_NAME    VARCHAR         COMMENT '후원사업 전체(#123)',
    SPONSORSHIP_ABBR    VARCHAR         COMMENT '약칭(#124)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '후원사업 차원 (1후원사업 · 실측 distinct=50)';


-- ============================================================================
-- DIM 7: DIM_AD_CREATIVE — 광고소재/매체 차원 (AGENCY 3테이블 적재·유형별 정제·실측 검토)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_AD_CREATIVE (
    AD_CREATIVE_SK      NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '광고소재 대리키 (ETL 일련번호, PK)',
    AD_CREATIVE_BK      VARCHAR         NOT NULL COMMENT '광고소재 업무키(BK, 자연키)',
    MEDIA_NAME          VARCHAR         COMMENT '매체명/공동브랜드(#11)',
    PLATFORM            VARCHAR         COMMENT '플랫폼(#12)',
    PLATFORM_TYPE       VARCHAR         COMMENT '플랫폼/매체유형(#13)',
    CREATIVE            VARCHAR         COMMENT '소재(#20)',
    CM_POSITION         VARCHAR         COMMENT 'CM위치(#21)',
    DURATION_SEC        NUMBER(9,0)     COMMENT '초수(#22)',
    RT_TYPE             VARCHAR         COMMENT 'RT유형',
    AD_TYPE             VARCHAR         COMMENT '광고유형',
    TARGET_GROUP        VARCHAR         COMMENT '타겟그룹',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '광고소재/매체 차원 (AGENCY 3테이블 적재, 유형별 정제→UNION·실측 검토 게이트 02 §3)';


-- ============================================================================
-- DIM 8: DIM_GA_SOURCE — GA 트래픽소스 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_GA_SOURCE (
    GA_SOURCE_SK        NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT 'GA 트래픽소스 대리키 (ETL 일련번호, PK)',
    UTM_SOURCE          VARCHAR         COMMENT 'source',
    UTM_MEDIUM          VARCHAR         COMMENT 'medium',
    UTM_CONTENT         VARCHAR         COMMENT '세션 수동 광고 콘텐츠(#103)',
    UTM_TERM            VARCHAR         COMMENT '세션 수동 검색어(#104)',
    SOURCE_MEDIUM       VARCHAR         COMMENT '세션 소스/매체(#109)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA 트래픽소스 차원';


-- ============================================================================
-- DIM 9: DIM_GA_EVENT — GA 이벤트분류 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_GA_EVENT (
    GA_EVENT_SK         NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT 'GA 이벤트 대리키 (ETL 일련번호, PK)',
    EVENT_CATEGORY      VARCHAR         COMMENT '이벤트 카테고리(#99)',
    EVENT_LABEL         VARCHAR         COMMENT '이벤트 라벨(#100)',
    EVENT_ACTION        VARCHAR         COMMENT '이벤트 액션(#101)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA 이벤트분류 차원';


-- ============================================================================
-- DIM 10: DIM_SERVICE — 서비스 차원 (발송/참여 유형)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_SERVICE (
    SERVICE_SK          NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '서비스 대리키 (ETL 일련번호, PK)',
    SEND_TYPE_L         VARCHAR         COMMENT '발송구분 대(#133)',
    SEND_TYPE_M         VARCHAR         COMMENT '발송구분 중(#134)',
    SEND_TYPE_S         VARCHAR         COMMENT '발송구분 소(#135)',
    SUBTYPE             VARCHAR         COMMENT '발송/참여 subtype',
    CHANNEL             VARCHAR         COMMENT 'CRM_UMS (ADMIN enum은 어드민 제외로 미사용 2026-07-09)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '서비스 차원 (1서비스 · 발송/참여 유형)';


-- ============================================================================
-- DIM 11: DIM_PAYMENT — 납입/결제/회비유형 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_PAYMENT (
    PAYMENT_SK          NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '납입/결제 대리키 (ETL 일련번호, PK)',
    PAYMENT_METHOD      VARCHAR         COMMENT '납입방식(#125)',
    SETTLE_METHOD       VARCHAR         COMMENT '결제방식',
    FEE_TYPE            VARCHAR         COMMENT '회비유형(정기/일시 — #66~68 분해)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '납입×결제×회비유형 차원';


-- ============================================================================
-- DIM 12: DIM_REASON — 사유코드 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_REASON (
    REASON_SK           NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '사유 대리키 (ETL 일련번호, PK)',
    REASON_CODE         VARCHAR         NOT NULL COMMENT '사유코드(BK, 업무키)',
    REASON_NAME         VARCHAR         COMMENT '중단사유(#162)·미납사유(#82)',
    REASON_TYPE         VARCHAR         COMMENT '중단 / 미납 구분',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '사유코드 차원 (중단/미납)';


-- ============================================================================
-- DIM 13: DIM_DEVICE — 디바이스 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_DEVICE (
    DEVICE_SK           NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '디바이스 대리키 (ETL 일련번호, PK)',
    DEVICE_TYPE         VARCHAR         COMMENT 'PC / M / APP',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '디바이스 차원 (1디바이스)';


-- ============================================================================
-- DIM 14: DIM_EVENT — 행사/이벤트 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_EVENT (
    EVENT_SK            NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '행사 대리키 (ETL 일련번호, PK)',
    EVENT_BK            VARCHAR         NOT NULL COMMENT '행사 업무키(BK, 자연키)',
    EVENT_KIND          VARCHAR         COMMENT '온라인/오프라인',
    EVENT_CATEGORY      VARCHAR         COMMENT '행사구분',
    EVENT_NAME          VARCHAR         COMMENT '행사명',
    EVENT_START_DATE    DATE            COMMENT '행사기간 시작(05 3-6)',
    EVENT_END_DATE      DATE            COMMENT '행사기간 종료(05 3-6)',
    APPLY_CHANNEL       VARCHAR         COMMENT '신청경로',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '행사/이벤트 차원 (1행사)';


-- ============================================================================
-- DIM 15: DIM_BUDGET_ITEM — 예산 세세목 차원 (ERP 원장 적재)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_BUDGET_ITEM (
    BUDGET_ITEM_SK      NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '예산 세세목 대리키 (ETL 일련번호, PK)',
    BUDGET_ITEM_NAME    VARCHAR         COMMENT '세세목명',
    BUDGET_CATEGORY     VARCHAR         COMMENT '예산구분',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '예산 세세목 차원 (ERP 원장 적재 — 예산과목 장/관/항/목/세목/세세목 매핑)';


-- ============================================================================
-- FACT 1: FACT_MEMBER_MONTHLY (FMM) — 회원 월 팩트
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY (
    MONTH_KEY                   NUMBER(6,0)     NOT NULL COMMENT 'YYYYMM',                                -- GRAIN / ※비강제 FK→DIM_DATE
    MEMBER_DK                   VARCHAR(10)     NOT NULL COMMENT '월 스냅샷 대상 회원 (불변키)',           -- GRAIN / ※비강제 FK→DIM_MEMBER
    CAMPAIGN_SK                 NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    SPONSORSHIP_SK              NUMBER(38,0)    COMMENT '후원사업 (FK→DIM_SPONSORSHIP)',
    PAYMENT_SK                  NUMBER(38,0)    COMMENT '납입/결제 유형 (FK→DIM_PAYMENT)',
    REASON_SK                   NUMBER(38,0)    COMMENT '중단/미납 사유 (FK→DIM_REASON)',
    DEV_CNT                     NUMBER(18,4)    COMMENT '개발(건) SUM(금액)/10000 (#4·5·149)',
    DEV_MEMBERS                 NUMBER(38,0)    COMMENT '개발(명) COUNT (#148)',
    STOP_CNT                    NUMBER(18,4)    COMMENT '중단(건) (#35, FME 롤업)',
    UNPAID_CNT                  NUMBER(18,4)    COMMENT '미납(건) (#36)',
    ACTIVE_CNT                  NUMBER(18,4)    COMMENT '활동(건) (#37·157)',
    ACTIVE_MEMBERS              NUMBER(38,0)    COMMENT '활동(명) (#156)',
    ACTIVE_CUM_CNT              NUMBER(18,4)    COMMENT '활동누계(건) (#159)',
    ACTIVE_CUM_MEMBERS          NUMBER(38,0)    COMMENT '활동누계(명) (#158)',
    INCREASE_CNT                NUMBER(18,4)    COMMENT '증액(건) (#151)',
    INCREASE_MEMBERS            NUMBER(38,0)    COMMENT '증액(명) (#150)',
    DECREASE_CNT                NUMBER(18,4)    COMMENT '감액(건) SUM(감액금액)/10000 (#38)',
    CHURN_CNT                   NUMBER(18,4)    COMMENT '이탈(건) SUM(취소+감액)/10000 (신규#20)',
    YEAR_START_ACTIVE_CNT       NUMBER(18,4)    COMMENT '연도초 활동회원(건) (#49)',
    YEAR_END_ACTIVE_CNT         NUMBER(18,4)    COMMENT '연도말 활동회원(건) (#50)',
    MONTH_END_ACTIVE_CNT        NUMBER(18,4)    COMMENT '월말활동회원(건) (#52)',
    PREV_MONTH_END_ACTIVE_CNT   NUMBER(18,4)    COMMENT '전월말 활동회원(건) (#53)',
    CAMPAIGN_UNPAID_CNT         NUMBER(18,4)    COMMENT '캠페인별 미납(건) (#83)',
    STATUS_UNPAID_CNT           NUMBER(18,4)    COMMENT '회원상태별 미납(건) (#84)',
    REGULAR_FEE                 NUMBER(18,2)    COMMENT '정기회비(원) (#66)',
    REGULAR_ONETIME_FEE         NUMBER(18,2)    COMMENT '정기회원 일시회비(원) (#67)',
    ONETIME_ONETIME_FEE         NUMBER(18,2)    COMMENT '일시회원 일시회비(원) (#68)',
    PAID_FEE                    NUMBER(18,2)    COMMENT '납입회비(원) (#69·70 단일화)',
    BILLED_AMT                  NUMBER(18,2)    COMMENT '청구(원) (#71)',
    INBOUND_CALL_CNT            NUMBER(38,0)    COMMENT '인바운드콜수 (overview) — 비-CRM 별도 입력',
    TS_CALL_CNT                 NUMBER(38,0)    COMMENT 'TS콜수 (overview) — 비-CRM 별도 입력',
    DEV_TYPE                    VARCHAR         COMMENT '개발구분(#121)',                                  -- degen
    NEW_FLAG                    BOOLEAN         COMMENT '신규(#32)',                                       -- degen
    INCREASE_FLAG               BOOLEAN         COMMENT '증액(#33)',                                       -- degen
    REDONATE_FLAG               BOOLEAN         COMMENT '재후원(#34)',                                     -- degen
    JOIN_DATE                   DATE            COMMENT '캠페인 가입일(#27)',                               -- degen
    STOP_DATE                   DATE            COMMENT '가입캠페인 중단일(#26)',                           -- degen
    AMOUNT_BAND1                VARCHAR         COMMENT '후원금액대1 5만(#72)',                             -- snapshot
    AMOUNT_BAND2                VARCHAR         COMMENT '후원금액대2 1만(#73)',                             -- snapshot
    PERIOD_BAND1                VARCHAR         COMMENT '후원기간대1 5년(#74)',                             -- snapshot
    PERIOD_BAND2                VARCHAR         COMMENT '후원기간대2 1년(#75)',                             -- snapshot
    SPONSOR_MONTHS              NUMBER(9,2)     COMMENT '후원기간(개월) (#127)',                            -- snapshot
    SPONSOR_YEARS               NUMBER(9,2)     COMMENT '후원기간(년) (#128)',                              -- snapshot
    PAID_MONTHS                 NUMBER(9,0)     COMMENT '납입개월수 (#129)',                                -- snapshot
    NEW_EXISTING_FLAG           VARCHAR         COMMENT '신규/기존(시점귀속, #113) — 04§5 reconcile',       -- snapshot
    UNPAID_FLAG_BOM             BOOLEAN         COMMENT '월초 미납회원 여부(=전월말 상태) — 04§5 reconcile (#80)', -- snapshot
    UNPAID_FLAG_EOM             BOOLEAN         COMMENT '월말 미납회원 여부 — 04§5 reconcile (#80)',         -- snapshot
    DW_SOURCE_SYSTEM            VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS                  TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS                TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 월 팩트 (MONTH_KEY × MEMBER_DK)';


-- ============================================================================
-- FACT 2: FACT_MEMBER_EVENT (FME) — 회원 이벤트 팩트 (일 grain)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_EVENT (
    DATE_SK             NUMBER(8,0)     NOT NULL COMMENT '사건일',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '상태전이 대상 회원 (불변키)',     -- ※비강제 FK→DIM_MEMBER
    EVENT_TYPE          VARCHAR         NOT NULL COMMENT '상태전이 유형(개발/중단/증액/미납중단)',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '후원사업 (FK→DIM_SPONSORSHIP)',
    ORG_SK              NUMBER(38,0)    COMMENT '조직 (FK→DIM_ORG)',
    REASON_SK           NUMBER(38,0)    COMMENT '중단/미납 사유 (FK→DIM_REASON)',
    DEV_CNT             NUMBER(18,4)    COMMENT '개발(건) (#149)',
    DEV_MEMBERS         NUMBER(38,0)    COMMENT '개발(명) (#148)',
    STOP_CNT            NUMBER(18,4)    COMMENT '중단(건) (#35)',
    STOP_MEMBERS        NUMBER(38,0)    COMMENT '중단(명)',
    UNPAID_STOP_CNT     NUMBER(18,4)    COMMENT '미납중단(건)',
    UNPAID_STOP_MEMBERS NUMBER(38,0)    COMMENT '미납중단(명) — 05 2-2 원천 확인(정본 §3 건·명)',
    JOIN_DATE           DATE            COMMENT '가입일',             -- degen
    STOP_DATE           DATE            COMMENT '중단일',             -- degen
    STOP_REASON         VARCHAR         COMMENT '중단사유',            -- degen
    STOP_CHANNEL        VARCHAR         COMMENT '중단채널',            -- degen
    NEW_EXISTING_FLAG   VARCHAR         COMMENT '신규기존',            -- degen
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 이벤트 팩트 (DATE_SK × MEMBER_DK × EVENT_TYPE · 1행=1상태전이)';


-- ============================================================================
-- FACT 3: FACT_TARGET_DEV (FTG_D) — 회원개발 목표 팩트
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_TARGET_DEV (
    MONTH_KEY           NUMBER(6,0)     NOT NULL COMMENT '목표월 YYYYMM (FK→DIM_DATE, 월 conform)', -- GRAIN / ※비강제 FK→DIM_DATE
    ORG_SK              NUMBER(38,0)    NOT NULL COMMENT '조직 (FK→DIM_ORG)',
    DEV_TYPE            VARCHAR         NOT NULL COMMENT '개발구분(#121 conform)',
    GOAL_CNT            NUMBER(18,4)    COMMENT '회원개발목표 (CRM TM_CM_MBER_DVLP_GOAL)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원개발 목표 팩트 (MONTH_KEY × ORG × DEV_TYPE · CRM 소스 확정)';


-- ============================================================================
-- FACT 4: FACT_TARGET_BIZ (FTG_B) — 사업 목표 팩트 (원천=CRM 신규 목표 테이블 CRM_BIZ_TARGET; 예산원장≠사업목표, 데이터 입고 대기·현재 0행)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_TARGET_BIZ (
    MONTH_KEY           NUMBER(6,0)     NOT NULL COMMENT '목표월 YYYYMM (FK→DIM_DATE, 월 conform)', -- GRAIN / ※비강제 FK→DIM_DATE
    ORG_SK              NUMBER(38,0)    NOT NULL COMMENT '조직 (FK→DIM_ORG)',
    SPONSORSHIP_SK      NUMBER(38,0)    NOT NULL COMMENT '후원사업 (FK→DIM_SPONSORSHIP)',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN)',                         -- 선택 grain
    ANNUAL_GOAL_CNT     NUMBER(18,4)    COMMENT '연사업목표(건) (#152)',
    SUPP_GOAL_CNT       NUMBER(18,4)    COMMENT '추경목표(건) (#153)',
    ANNUAL_CUM_GOAL_CNT NUMBER(18,4)    COMMENT '연사업누계목표(건) (#154)',
    SUPP_CUM_GOAL_CNT   NUMBER(18,4)    COMMENT '추경누계목표(건) (#155)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '사업 목표 팩트 (MONTH_KEY × ORG × SPONSORSHIP · 원천=CRM 신규 목표 테이블 CRM_BIZ_TARGET — 데이터 입고 대기, 현재 0행)';


-- ============================================================================
-- FACT 5: FACT_SERVICE_EVENT (FSE) — 서비스/발송 이벤트 팩트
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_SERVICE_EVENT (
    DATE_SK                     NUMBER(8,0)     NOT NULL COMMENT '발송일',
    MEMBER_DK                   VARCHAR(10)     NOT NULL COMMENT '발송 대상 회원 (불변키)',        -- ※비강제 FK→DIM_MEMBER
    SERVICE_SK                  NUMBER(38,0)    NOT NULL COMMENT '발송 서비스 유형 (FK→DIM_SERVICE)',
    CAMPAIGN_SK                 NUMBER(38,0)    NOT NULL COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    SEND_MEMBERS                NUMBER(38,0)    COMMENT '발송수(명) (#85)',
    SUCCESS_MEMBERS             NUMBER(38,0)    COMMENT '성공수(명) (#86)',
    FAIL_MEMBERS                NUMBER(38,0)    COMMENT '실패수(명) (#87)',
    OPEN_MEMBERS                NUMBER(38,0)    COMMENT '오픈(명) (overview)',
    LETTER_PART_MEMBERS         NUMBER(38,0)    COMMENT '서신참여(명) (#88)',
    LETTER_PART_CNT             NUMBER(18,4)    COMMENT '서신참여(건) (#89)',
    GIFT_PART_MEMBERS           NUMBER(38,0)    COMMENT '선물금참여(명) (#90)',
    GIFT_PART_AMT               NUMBER(18,2)    COMMENT '선물금참여(원) (#91)',
    D5_LETTER_PART_MEMBERS      NUMBER(38,0)    COMMENT '+5일차 서신참여(명) (#139)',
    D5_LETTER_PART_CNT          NUMBER(18,4)    COMMENT '+5일차 서신참여(건) (#140)',
    D5_GIFT_PART_MEMBERS        NUMBER(38,0)    COMMENT '+5일차 선물금참여(명) (#141)',
    D5_GIFT_PART_CNT            NUMBER(18,4)    COMMENT '+5일차 선물금참여(건) (#142)',
    D5_INCREASE_PART_MEMBERS    NUMBER(38,0)    COMMENT '+5일차 증액참여(명) (#143)',
    D5_INCREASE_PART_CNT        NUMBER(18,4)    COMMENT '+5일차 증액참여(건) (#144)',
    D5_STOP_MEMBERS             NUMBER(38,0)    COMMENT '+5일차 중단(명) (#145)',
    D5_STOP_CNT                 NUMBER(18,4)    COMMENT '+5일차 중단(건) (#146)',
    SERVICE_MEMBERS             NUMBER(38,0)    COMMENT '서비스(명) (#160)',
    SERVICE_CNT                 NUMBER(18,4)    COMMENT '서비스(건) (#161)',
    -- ❌ APP_PUSH_SEND_CNT/SUCCESS_CNT 삭제(2026-07-09): 어드민 원천 제외 확정. 내년 어드민 구현 시 ADD COLUMN 재추가.
    SEND_TITLE                  VARCHAR         COMMENT '제목(#136)',              -- degen
    SEND_STATUS                 VARCHAR         COMMENT '발송상태(#138)',           -- degen
    SEND_STATUS2                VARCHAR         COMMENT '발송상태2(05 3-1)',        -- degen
    SEND_TYPE                   VARCHAR         COMMENT '발송유형',                 -- degen
    MAIL_RECEIVE_FLAG           BOOLEAN         COMMENT '메일수신여부',             -- degen
    MEMBER_STOP_FLAG            BOOLEAN         COMMENT '결연회원 중단여부',         -- degen
    DW_SOURCE_SYSTEM            VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS                  TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS                TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '서비스/발송 이벤트 팩트 (DATE_SK × MEMBER_DK × SERVICE_SK × CAMPAIGN_SK)';


-- ============================================================================
-- FACT 6: FACT_GA_BEHAVIOR (FGA) — GA 행동 팩트
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR (
    DATE_SK                         NUMBER(8,0)     NOT NULL COMMENT '행동 발생일 YYYYMMDD (FK→DIM_DATE)',
    IDENTITY_SK                     NUMBER(38,0)    NOT NULL COMMENT '방문자 회원식별 (FK→DIM_MEMBER_IDENTITY)',
    GA_EVENT_SK                     NUMBER(38,0)    NOT NULL COMMENT 'GA 이벤트 분류 (FK→DIM_GA_EVENT)',
    GA_SOURCE_SK                    NUMBER(38,0)    NOT NULL COMMENT '유입 트래픽소스 (FK→DIM_GA_SOURCE)',
    DEVICE_SK                       NUMBER(38,0)    NOT NULL COMMENT '접속 디바이스 (FK→DIM_DEVICE)',
    CAMPAIGN_SK                     NUMBER(38,0)    NOT NULL COMMENT '세션캠페인(#102)',
    PAGE_PATH                       VARCHAR         NOT NULL COMMENT '페이지경로+쿼리(#105)',  -- degen(grain)
    PAGE_LOCATION                   VARCHAR         COMMENT '페이지위치(#106)',                -- degen
    VISITS                          NUMBER(38,0)    COMMENT '방문수(명) (#92)',
    EVENT_CNT                       NUMBER(38,0)    COMMENT '이벤트수(명) (#95)',
    VIEW_CNT                        NUMBER(38,0)    COMMENT '조회수(명) (#96)',
    SESSION_CNT                     NUMBER(38,0)    COMMENT '세션수(명) (#97)',
    ENGAGED_SESSIONS                NUMBER(38,0)    COMMENT '참여세션수',
    SCROLL_DEPTH                    NUMBER(9,4)     COMMENT '스크롤깊이 AVG (#107) — 비가산',
    ACTIVE_USERS                    NUMBER(38,0)    COMMENT '활성사용자수(명) (#93) — 비가산',
    TOTAL_USERS                     NUMBER(38,0)    COMMENT '총사용자(명) (#94) — 비가산',
    AVG_SESSION_DURATION            NUMBER(9,4)     COMMENT '평균세션시간 (#98) — 비가산',
    BOUNCE_RATE                     NUMBER(9,4)     COMMENT '이탈율 (#108) — 비가산',
    ENGAGEMENT_RATE                 NUMBER(9,4)     COMMENT '참여율 — 비가산',
    AVG_ENGAGEMENT_TIME_PER_SESSION NUMBER(9,4)     COMMENT '세션당 평균참여시간 — 비가산',
    DW_SOURCE_SYSTEM                VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS                      TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS                    TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA 행동 팩트 (DATE_SK × IDENTITY_SK × GA_EVENT/SOURCE/DEVICE × CAMPAIGN × PAGE) — 비가산 지표 재합산 금지';


-- ============================================================================
-- FACT 7: FACT_AD_PERFORMANCE (FAD) — 광고 성과 팩트 (AGENCY 3테이블 적재·measure 불균일)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE (
    PERF_DATE_SK        NUMBER(8,0)     NOT NULL COMMENT '실적일',
    CAMPAIGN_SK         NUMBER(38,0)    NOT NULL COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    AD_CREATIVE_SK      NUMBER(38,0)    NOT NULL COMMENT '광고소재/매체 (FK→DIM_AD_CREATIVE)',
    DEVICE_SK           NUMBER(38,0)    NOT NULL COMMENT '디바이스 (FK→DIM_DEVICE)',
    AD_COST             NUMBER(18,2)    COMMENT '광고비(원) (#6)',
    IMPRESSIONS         NUMBER(38,0)    COMMENT '노출수 (#23)',
    CLICKS              NUMBER(38,0)    COMMENT '클릭수(행동 횟수, ≠회원명) (#24)',
    INBOUND_CALL        NUMBER(38,0)    COMMENT '인입콜 (#25)',
    GA_CONV_MEMBERS     NUMBER(38,0)    COMMENT 'GA전환수(명)',
    GA_CONV_CNT         NUMBER(18,4)    COMMENT 'GA전환수(건)',
    DAY_OF_WEEK         VARCHAR         COMMENT '요일',             -- degen
    WEEK_OF_YEAR        NUMBER(2,0)     COMMENT '주차',             -- degen
    TIME_BAND           VARCHAR         COMMENT '시간대',            -- degen
    CM_POSITION         VARCHAR         COMMENT 'CM위치',           -- degen
    RT_TYPE             VARCHAR         COMMENT 'RT유형',            -- degen
    AD_START_TIME       VARCHAR         COMMENT '광고시작시간',       -- degen
    BROADCAST_DATE      DATE            COMMENT '송출일(≠실적일)',    -- degen
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '광고 성과 팩트 (PERF_DATE × CAMPAIGN × AD_CREATIVE × DEVICE · AGENCY 3테이블 적재: 인입콜 TEXT/NUMBER 캐스팅·_SOURCE_SYSTEM SILVER 부여·캠페인 이름매칭)';


-- ============================================================================
-- FACT 8: FACT_EVENT_PARTICIPATION (FEP) — 행사 참여 팩트
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION (
    DATE_SK             NUMBER(8,0)     NOT NULL COMMENT '참여일 YYYYMMDD (FK→DIM_DATE)',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '참여 회원 (불변키)',              -- ※비강제 FK→DIM_MEMBER
    EVENT_SK            NUMBER(38,0)    NOT NULL COMMENT '행사 (FK→DIM_EVENT)',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '분석축',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '분석축',
    RECRUIT_CNT         NUMBER(38,0)    COMMENT '모집인원',
    TOTAL_CNT           NUMBER(38,0)    COMMENT '총인원',
    WAIT_CNT            NUMBER(38,0)    COMMENT '대기인원',
    CANCEL_CNT          NUMBER(38,0)    COMMENT '취소인원',
    CONFIRM_CNT         NUMBER(38,0)    COMMENT '신청확정인원',
    PARTICIPATE_CNT     NUMBER(38,0)    COMMENT '참여인원',
    ABSENT_CNT          NUMBER(38,0)    COMMENT '불참인원',
    PARTICIPANT_CNT     NUMBER(38,0)    COMMENT '참여자수',
    PARTICIPATION_TIMES NUMBER(38,0)    COMMENT '참여횟수',
    WAIT_TIMES          NUMBER(38,0)    COMMENT '대기횟수',
    ABSENT_TIMES        NUMBER(38,0)    COMMENT '불참횟수',
    CUM_APPLY_TIMES     NUMBER(38,0)    COMMENT '누적신청 횟수',
    REGULAR_DONATION    NUMBER(18,2)    COMMENT '정기후원금(원)',
    -- ❌ VIEW_CNT(조회수) 삭제(2026-07-09): 어드민 원천 제외 확정. 내년 어드민 구현 시 ADD COLUMN 재추가.
    WIN_FLAG            BOOLEAN         COMMENT '당첨여부',           -- degen
    SELF_PART_FLAG      BOOLEAN         COMMENT '본인참여',           -- degen
    PART_STATUS         VARCHAR         COMMENT '참여상태',           -- degen
    PART_PATH           VARCHAR         COMMENT '참여경로(05 3-5)',   -- degen
    PART_CHANNEL        VARCHAR         COMMENT '참여채널(05 3-5)',   -- degen
    INCREASE_FLAG       BOOLEAN         COMMENT '증액여부',           -- degen
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '행사 참여 팩트 (DATE_SK × MEMBER_DK × EVENT_SK)';


-- ============================================================================
-- FACT 9: FACT_BUDGET (FBD) — 예산 팩트 (ERP 원장 적재: 편성/집행 O·모금성비용 원천 부재)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_BUDGET (
    MONTH_KEY           NUMBER(6,0)     NOT NULL COMMENT '예산월 YYYYMM (FK→DIM_DATE, 월 conform)', -- GRAIN / ※비강제 FK→DIM_DATE
    ORG_SK              NUMBER(38,0)    NOT NULL COMMENT '조직 (FK→DIM_ORG)',
    BUDGET_ITEM_SK      NUMBER(38,0)    NOT NULL COMMENT '예산 세세목 (FK→DIM_BUDGET_ITEM)',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '후원사업 (선택 FK→DIM_SPONSORSHIP)',
    PLAN_BUDGET_MONTH   NUMBER(18,2)    COMMENT '편성예산(월)',
    PLAN_BUDGET_YEAR    NUMBER(18,2)    COMMENT '편성예산(연)',
    EXEC_BUDGET_ERP     NUMBER(18,2)    COMMENT '집행예산(ERP)',
    EXEC_BUDGET_EST     NUMBER(18,2)    COMMENT '집행예산(추정)',
    FUNDRAISING_COST    NUMBER(18,2)    COMMENT '모금성비용',
    AD_COST             NUMBER(18,2)    COMMENT '광고비',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '예산 팩트 (MONTH × ORG × BUDGET_ITEM · ERP 편성/집행 적재 · 모금성비용 원천 부재·광고비 AGENCY 보강)';


-- ============================================================================
-- [관계 제약] 정보성 FK 선언 (NOT ENFORCED NORELY)
-- ----------------------------------------------------------------------------
--  목적   : ERD 자동생성 · BI 관계 인식 · 인수인계 문서화.
--  성격   : Snowflake 는 NOT NULL 외 제약을 강제하지 않음. 아래 FK 는 전부
--           정보성이며 NORELY(옵티마이저가 무결성 가정 안 함) — GOLD 데이터
--           검증 완료 후 RELY 승격 검토(그 전까지 조인제거 오답 위험 차단).
--  전제   : 참조 대상이 실제 PK 인 컬럼만 선언(Snowflake FK 대상 = PK/UNIQUE).
--           본 ALTER 는 24개 테이블 생성 이후 실행.
--  명명   : FK_<자식테이블>_<부모차원>[_<역할>]
--  타입정합: 자식 FK 컬럼 ↔ 부모 PK 타입 일치 검증 완료
--           (DATE_SK=NUMBER(8,0), 그 외 SK=NUMBER(38,0)).
--  ⚠️ 재실행 규칙(중요): 반드시 이 파일을 위→아래로 '전체 일괄' 실행할 것.
--           · CREATE OR REPLACE 가 테이블을 재생성하며 기존 FK 를 모두 제거 →
--             이어지는 ALTER 가 FK 를 다시 부여(전체 실행은 항상 안전·멱등).
--           · [멱등화 2026-07-20] FK 섹션만 부분 재실행해도 안전하도록, 아래 ADD 전에
--             EXECUTE IMMEDIATE 스크립팅 블록으로 35개 제약을 선(先) DROP(미존재 시 EXCEPTION 무시).
--             Snowflake 는 DROP CONSTRAINT IF EXISTS 미지원 → BEGIN...EXCEPTION WHEN OTHER THEN NULL 패턴 사용.
--             (특정 DIM 만 CREATE OR REPLACE 시 자식 FK 소실은 여전 → 그 경우 전체 실행 권장.)
-- ============================================================================

-- [멱등화] FK 부분 재실행 대비 — 기존 동일명 제약 선(先) 제거(미존재 시 무시). Snowflake DROP CONSTRAINT IF EXISTS 미지원 → 스크립팅 EXCEPTION 패턴.
EXECUTE IMMEDIATE $$
BEGIN
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_CAMPAIGN DROP CONSTRAINT FK_DIM_CAMPAIGN_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY DROP CONSTRAINT FK_FMM_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY DROP CONSTRAINT FK_FMM_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY DROP CONSTRAINT FK_FMM_DIM_PAYMENT; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY DROP CONSTRAINT FK_FMM_DIM_REASON; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT DROP CONSTRAINT FK_FME_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT DROP CONSTRAINT FK_FME_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT DROP CONSTRAINT FK_FME_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT DROP CONSTRAINT FK_FME_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT DROP CONSTRAINT FK_FME_DIM_REASON; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_TARGET_DEV DROP CONSTRAINT FK_FTG_D_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_TARGET_BIZ DROP CONSTRAINT FK_FTG_B_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_TARGET_BIZ DROP CONSTRAINT FK_FTG_B_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_TARGET_BIZ DROP CONSTRAINT FK_FTG_B_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_SERVICE_EVENT DROP CONSTRAINT FK_FSE_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_SERVICE_EVENT DROP CONSTRAINT FK_FSE_DIM_SERVICE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_SERVICE_EVENT DROP CONSTRAINT FK_FSE_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR DROP CONSTRAINT FK_FGA_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR DROP CONSTRAINT FK_FGA_DIM_MEMBER_IDENTITY; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR DROP CONSTRAINT FK_FGA_DIM_GA_EVENT; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR DROP CONSTRAINT FK_FGA_DIM_GA_SOURCE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR DROP CONSTRAINT FK_FGA_DIM_DEVICE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR DROP CONSTRAINT FK_FGA_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE DROP CONSTRAINT FK_FAD_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE DROP CONSTRAINT FK_FAD_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE DROP CONSTRAINT FK_FAD_DIM_AD_CREATIVE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE DROP CONSTRAINT FK_FAD_DIM_DEVICE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION DROP CONSTRAINT FK_FEP_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION DROP CONSTRAINT FK_FEP_DIM_EVENT; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION DROP CONSTRAINT FK_FEP_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION DROP CONSTRAINT FK_FEP_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_BUDGET_ITEM; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  RETURN 'FK drop (idempotent) done';
END;
$$;

-- DIM → DIM
ALTER TABLE GN_DW.GOLD.DIM_CAMPAIGN ADD CONSTRAINT FK_DIM_CAMPAIGN_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;

-- FACT_MEMBER_MONTHLY
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY ADD CONSTRAINT FK_FMM_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY ADD CONSTRAINT FK_FMM_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY ADD CONSTRAINT FK_FMM_DIM_PAYMENT
    FOREIGN KEY (PAYMENT_SK) REFERENCES GN_DW.GOLD.DIM_PAYMENT (PAYMENT_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY ADD CONSTRAINT FK_FMM_DIM_REASON
    FOREIGN KEY (REASON_SK) REFERENCES GN_DW.GOLD.DIM_REASON (REASON_SK) NOT ENFORCED NORELY;

-- FACT_MEMBER_EVENT
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT ADD CONSTRAINT FK_FME_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT ADD CONSTRAINT FK_FME_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT ADD CONSTRAINT FK_FME_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT ADD CONSTRAINT FK_FME_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT ADD CONSTRAINT FK_FME_DIM_REASON
    FOREIGN KEY (REASON_SK) REFERENCES GN_DW.GOLD.DIM_REASON (REASON_SK) NOT ENFORCED NORELY;

-- FACT_TARGET_DEV
ALTER TABLE GN_DW.GOLD.FACT_TARGET_DEV ADD CONSTRAINT FK_FTG_D_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;

-- FACT_TARGET_BIZ
ALTER TABLE GN_DW.GOLD.FACT_TARGET_BIZ ADD CONSTRAINT FK_FTG_B_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_TARGET_BIZ ADD CONSTRAINT FK_FTG_B_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_TARGET_BIZ ADD CONSTRAINT FK_FTG_B_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;

-- FACT_SERVICE_EVENT
ALTER TABLE GN_DW.GOLD.FACT_SERVICE_EVENT ADD CONSTRAINT FK_FSE_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_SERVICE_EVENT ADD CONSTRAINT FK_FSE_DIM_SERVICE
    FOREIGN KEY (SERVICE_SK) REFERENCES GN_DW.GOLD.DIM_SERVICE (SERVICE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_SERVICE_EVENT ADD CONSTRAINT FK_FSE_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;

-- FACT_GA_BEHAVIOR
ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR ADD CONSTRAINT FK_FGA_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR ADD CONSTRAINT FK_FGA_DIM_MEMBER_IDENTITY
    FOREIGN KEY (IDENTITY_SK) REFERENCES GN_DW.GOLD.DIM_MEMBER_IDENTITY (IDENTITY_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR ADD CONSTRAINT FK_FGA_DIM_GA_EVENT
    FOREIGN KEY (GA_EVENT_SK) REFERENCES GN_DW.GOLD.DIM_GA_EVENT (GA_EVENT_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR ADD CONSTRAINT FK_FGA_DIM_GA_SOURCE
    FOREIGN KEY (GA_SOURCE_SK) REFERENCES GN_DW.GOLD.DIM_GA_SOURCE (GA_SOURCE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR ADD CONSTRAINT FK_FGA_DIM_DEVICE
    FOREIGN KEY (DEVICE_SK) REFERENCES GN_DW.GOLD.DIM_DEVICE (DEVICE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_GA_BEHAVIOR ADD CONSTRAINT FK_FGA_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;

-- FACT_AD_PERFORMANCE  (PERF_DATE_SK 는 역할차원 → DIM_DATE(DATE_SK) 참조)
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAD_DIM_DATE
    FOREIGN KEY (PERF_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAD_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAD_DIM_AD_CREATIVE
    FOREIGN KEY (AD_CREATIVE_SK) REFERENCES GN_DW.GOLD.DIM_AD_CREATIVE (AD_CREATIVE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAD_DIM_DEVICE
    FOREIGN KEY (DEVICE_SK) REFERENCES GN_DW.GOLD.DIM_DEVICE (DEVICE_SK) NOT ENFORCED NORELY;

-- FACT_EVENT_PARTICIPATION
ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION ADD CONSTRAINT FK_FEP_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION ADD CONSTRAINT FK_FEP_DIM_EVENT
    FOREIGN KEY (EVENT_SK) REFERENCES GN_DW.GOLD.DIM_EVENT (EVENT_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION ADD CONSTRAINT FK_FEP_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION ADD CONSTRAINT FK_FEP_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;

-- FACT_BUDGET
ALTER TABLE GN_DW.GOLD.FACT_BUDGET ADD CONSTRAINT FK_FBD_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET ADD CONSTRAINT FK_FBD_DIM_BUDGET_ITEM
    FOREIGN KEY (BUDGET_ITEM_SK) REFERENCES GN_DW.GOLD.DIM_BUDGET_ITEM (BUDGET_ITEM_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET ADD CONSTRAINT FK_FBD_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET ADD CONSTRAINT FK_FBD_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;

-- ============================================================================
-- [관계 제약 — 보류(FK 미선언)] 인수인계 필독
-- ----------------------------------------------------------------------------
--  아래 컬럼은 논리적으로 차원을 참조하나, 참조 대상이 '비유일'이라
--  Snowflake FK 규칙(대상=PK/UNIQUE)을 만족하지 못해 FK 를 선언하지 않는다.
--  CSV 인벤토리의 '※비강제' 표기와 정확히 일치. 조인은 아래 경로로 수행.
--
--  1) MEMBER_DK  (FMM · FME · FSE · FEP · DIM_MEMBER_IDENTITY)
--       대상 DIM_MEMBER.MEMBER_DK 는 SCD2 다중버전으로 비유일.
--       → 조인 경로: DIM_MEMBER 의 IS_CURRENT=TRUE(현재행) 경유,
--         또는 사건일 기준 EFFECTIVE_FROM~EFFECTIVE_TO 구간 매칭.
--       → PK(MEMBER_SK) 로는 FK 가능하나, 팩트는 불변키 MEMBER_DK 를 보관
--         (시점 정합·재적재 안정성) → 대리키 FK 미도입.
--
--  2) MONTH_KEY  (FMM · FTG_D · FTG_B · FBD)
--       대상 DIM_DATE.MONTH_KEY 는 월당 ~30행으로 비유일(PK=DATE_SK).
--       → 조인 경로: DIM_DATE 월초행 필터(예: DAY=1) 또는 월 conform 뷰 경유.
--       → 월 grain conformed 차원(DIM_MONTH) 신설 시 FK 승격 가능하나,
--         테이블 수 24개 고정 원칙에 따라 현 단계 보류(설계 open O 참조).
--
--  [FACT PK/UNIQUE 보류] grain 미확정·ETL 멱등성 의존(설계문서)으로 미설정.
--       논리 grain 은 각 테이블 COMMENT 에 명시. 확정 후 UNIQUE(NORELY) 검토.
-- ============================================================================


-- ============================================================================
-- [검증 쿼리] DDL 실행 후 24개 테이블 생성 확인
-- ============================================================================
SELECT
    CASE WHEN table_name LIKE 'DIM_%' THEN 'DIM' ELSE 'FACT' END AS category,
    table_name,
    comment
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'GOLD'
ORDER BY category DESC, table_name;
-- 기대값: DIM 15행 + FACT 9행 = 24행

-- ----------------------------------------------------------------------------
-- [검증 쿼리] 정보성 FK 35개 선언 확인
-- ----------------------------------------------------------------------------
SHOW IMPORTED KEYS IN SCHEMA GN_DW.GOLD;
-- 기대값: 35행 (DIM_CAMPAIGN 1 + FMM 4 + FME 5 + FTG_D 1 + FTG_B 3
--          + FSE 3 + FGA 6 + FAD 4 + FEP 4 + FBD 4). 보류 FK(MEMBER_DK·MONTH_KEY) 제외.

-- 자동화용(스크립트 카운트): FOREIGN KEY 제약 수 집계
SELECT COUNT(*) AS fk_count
FROM GN_DW.INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE constraint_schema = 'GOLD'
  AND constraint_type = 'FOREIGN KEY';
-- 기대값: 35

-- ============================================================================
-- [구현 완료 주석]
-- ----------------------------------------------------------------------------
--  · 6단계(DDL 초안): CREATE TABLE 24개(DIM 15 + FACT 9) — compile 기준 완료.
--  · 7단계(메타/제약) 선반영: 위 [관계 제약] 섹션에 정보성 FK 35개 ALTER 구현 +
--    보류 FK(MEMBER_DK·MONTH_KEY)·FACT PK 사유 명문화.
--    → 6/7단계 경계는 각 섹션 헤더 주석으로 구분. 배포 편의를 위해 단일 파일 유지.
--  · 컬럼 COMMENT: gold 스키마 컬럼 인벤토리_20260629.csv 설명 컬럼 기준 (2026-07-03 추가).
--  · 사람 인수인계용 설명 문서: 07_메타.md 참조(제약 정책·미해결 항목 서술형).
--  · PENDING: VARCHAR 길이 등 타입 정밀화(정본 06_지표용어사전)는 미반영 — 운영 후 ALTER.
-- ============================================================================
