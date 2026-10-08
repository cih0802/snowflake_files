-- ============================================================================
-- GN_DW.GOLD 테이블 DDL — 구조 정본(타입 · COMMENT · PK/FK)
--   · 구성 = CREATE(DIM → FACT) → 제약 절(PK 보강 · 정보성 FK · NOT ENFORCED).
--   · 실행 = GN_DW_ADMIN · 새 환경은 이 파일 전체 실행 → dbt build.
--   · 🔴 적재된 환경에서 전체 재실행 금지 — CREATE OR REPLACE 가 데이터·FK·GRANT 를 지운다.
--       FK 만 다시 걸 때는 제약 절만 실행한다(선삭제 블록이 있어 멱등).
--   · 🔴🔴 [2026-10-06 O202-B 실사고] 2026-10-05 19:49 PDT 이 파일 전체 실행 → GOLD 48 중 41 테이블 0행 →
--       FK 테스트 11 FAIL · ROLLING 팩트(FACT_BIGQUERY_BEHAVIOR)는 전량 build 로도 복구 안 됨(백필 별도 필요).
--       ⇒ **컬럼 1개 추가는 이 파일을 돌리지 말고** ① 이 파일 선언 수정 ② 그 컬럼만 `ALTER TABLE … ADD COLUMN IF NOT EXISTS`
--         ③ `SHOW COLUMNS` 확인(INFORMATION_SCHEMA 는 반영이 늦다) ④ dbt build — 이 순서뿐이다.
--   · 🔴 FK 는 참조 PK 와 타입이 정확히 같아야 한다(폭이 넓어도 실패):
--       *_DATE_SK NUMBER(8,0) · MONTH_KEY NUMBER(6,0) · *_SK NUMBER(38,0) · MEMBER_DK VARCHAR(10).
--   · 뷰(WIDE_* · DIM_MEMBER_ACQUISITION 계열 뷰)는 dbt 모델 소관 — 이 파일에서 만들지 않는다.
--   · 설계근거·실측 이력 = 06_DDL_설계이력_부록.md · 이슈 원장 = 20_issue/00_INDEX_이슈원장.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE DATABASE GN_DW;
CREATE SCHEMA IF NOT EXISTS GN_DW.GOLD
    WITH MANAGED ACCESS
    COMMENT = '분석 View + Semantic View + Agent + 예측 테이블 + Streamlit';
GRANT CREATE VIEW ON SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;
USE SCHEMA GOLD;

-- ============================================================================
-- DIM — 차원
-- ============================================================================
--   ⚠️ 완전 재산출 차원(DIM_MONTH·DIM_MEMBER·DIM_MEMBER_ACQUISITION 등)에 merge 금지 — grain 이동 시 구 행이 남는다.

-- DIM_DATE — 날짜 차원
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
) COMMENT = '날짜 차원. [Grain: DATE_SK (1행=1일)]. [주의: 월/연 집계 시 팬아웃 방지를 위해 월팩트는 DIM_MONTH 조인 권장]. [원천: DW 생성 → BRONZE_CALENDAR → SILVER_DATE].';

-- DIM_MONTH — 월 차원
--   ⚠️ 월 팩트는 DIM_DATE 를 직접 조인하지 말고 이 차원을 쓴다(일 grain 증폭 방지).
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MONTH (
    MONTH_KEY        NUMBER(6,0)     NOT NULL PRIMARY KEY COMMENT '월 conform 키 YYYYMM.',
    YEAR             NUMBER(4,0)     COMMENT '연도.',
    MONTH            NUMBER(2,0)     COMMENT '월 (1~12).',
    QUARTER          NUMBER(1,0)     COMMENT '분기 (1~4).',
    DW_SOURCE_SYSTEM VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS       TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS     TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID      VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '월 차원. [Grain: MONTH_KEY (1행=1월)]. [주의: 월 단위 팩트와 일 차원(DIM_DATE) 직접 조인 시 팬아웃 방지 전용]. [원천: DW 생성 → DIM_DATE 사영].';

-- DIM_ORG — 조직/부서 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_ORG (
    ORG_SK              NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '조직 대리키 (=hash(DEPT_ID), PK)',
    ORG_DK              NUMBER(38,0)    NOT NULL COMMENT '불변 비즈니스 식별자',
    CORP                VARCHAR         COMMENT '법인 (#114). [사유:부서차원 산출불가]',
    DIVISION            VARCHAR         COMMENT '실적지부 (#430). [사유:규칙 미확정]',
    DEPARTMENT          VARCHAR         COMMENT '부서 (#116).',
    TEAM                VARCHAR         COMMENT '팀 (#152). [사유:원천 미입고]',
    ACMSLT_UPPER_DEPT_ID VARCHAR        COMMENT '실적상위부서ID (원천 그대로).',
    ACMSLT_DEPT_YN      VARCHAR         COMMENT '실적부서 여부 Y/N (원천 그대로) — Y 455개',
    USE_YN              VARCHAR         COMMENT '사용여부 Y/N. 고유값:Y,N',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    IS_ACTIVE_ORG        BOOLEAN          COMMENT '활성 조직 트리 소속 여부 — 자기와 모든 상위가 USE_YN=Y 이고 LAST_UPDT_DT 유효 · 행은 지우지 않는다(O16)',
    ORG_PATH             VARCHAR          COMMENT '조직표 부서 경로(루트 제외) · 순환 노드는 NULL',
    ORG_LEVEL            NUMBER(38,0)     COMMENT '조직 트리 깊이 · 루트=0',
    ACMSLT_DIV_GROUP_ID  VARCHAR          COMMENT '실적트리 상위 중 부서코드 접두 ZB 노드 = 본부/지부 구분 · 자기가 ZB 면 자기 · 미도달 NULL',
    ACMSLT_DIV_GROUP_NM  VARCHAR          COMMENT '실적 본부/지부 구분명(ZB 노드 DEPT_NM)',
    ACMSLT_DIV_ID        VARCHAR          COMMENT '실적트리 상위 중 부서코드 접두 ZC 노드 = 본부/지부 단위 · 자기가 ZC 면 자기 · 미도달 NULL · DIVISION 은 현업 확인 전 NULL 유지',
    ACMSLT_DIV_NM        VARCHAR          COMMENT '실적 본부/지부 단위명(ZC 노드 DEPT_NM) · 같은 이름이 여러 ZB 아래 존재'
) COMMENT = '조직/부서 차원. [Grain: ORG_SK (1행=1부서, SCD1)]. [주의: 과거 소속 이력 미관리(현재 부서 기준)]. [원천: CRM → BRONZE_CRM.TM_CM_DEPT_MNG → SILVER.CRM_ORG].';

-- DIM_MEMBER_STATUS_HISTORY — 회원 상태전이 이력 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER_STATUS_HISTORY (
    MEMBER_SK           NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '버전 대리키',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키(조인용)',
    SEX                 VARCHAR         COMMENT '성별 원천코드 raw. 코드id:CM013',
    SEX_NM              VARCHAR         COMMENT '성별 원천 라벨. 코드id:CM013',
    GENDER_NAME         VARCHAR         COMMENT '성별 (#130). 고유값:남자,여자,기타,단체,기업',
    AREA_CD                 VARCHAR(10)     COMMENT '지역 코드 raw. 코드id:CM018',
    REGION                  VARCHAR         COMMENT '지역 (#131). 코드id:CM018',
    AGE                     NUMBER(2,0)     COMMENT '연령대 코드 raw. 코드id:CM014',
    AGE_BAND                VARCHAR         COMMENT '연령대. 코드id:CM014',
    MBER_STAT_CD        VARCHAR         COMMENT '회원상태 원천코드 raw (#132). 코드id:MM010',
    MBER_DIV_CD         VARCHAR         COMMENT '회원구분 원천코드 raw. 코드id:MM018',
    MEMBER_TYPE_NAME    VARCHAR         COMMENT '회원구분명 (라벨). 고유값:개인,기업,단체',
    MEMBER_STATUS_NAME  VARCHAR         COMMENT '회원상태명 (라벨). 코드id:MM010',
    MEMBER_STATUS_GROUP VARCHAR         COMMENT 'MEMBER_STATUS_GROUP. 코드id:MM010.',
    PREV_MBER_STAT_CD       VARCHAR(10)     COMMENT '상태전이 **이전상태** 코드 raw. 코드id:MM010.',
    PREV_MEMBER_STATUS_NAME VARCHAR(100)    COMMENT '이전상태 라벨. 코드id:MM010.',
    FIRST_JOIN_DATE     DATE            COMMENT '최초가입일=회원번호 생성일(#28)',
    FIRST_CAMPAIGN      VARCHAR         COMMENT '최초캠페인(#29)',
    JOIN_PATH_CD        VARCHAR         COMMENT '가입경로코드. 코드id:MM014',
    ENROLL_PATH_NAME    VARCHAR         COMMENT 'ENROLL_PATH_NAME. 코드id:MM014. [사유:원천 부재]',
    FIRST_SPONSORSHIP       VARCHAR         COMMENT '최초 후원사업.',
    LAST_STOP_DATE          DATE            COMMENT '최종 중단일.',
    EFFECTIVE_FROM      DATE            COMMENT 'SCD2 유효시작.',
    EFFECTIVE_TO        DATE            COMMENT 'SCD2 유효종료.',
    IS_CURRENT          BOOLEAN         COMMENT '현재행 여부',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    MEMBER_TYPE         VARCHAR         COMMENT '회원 등록계통 구분. 코드id:MM010.'
) COMMENT = '회원 상태전이 이력 차원. [Grain: MEMBER_SK (1행=1회원상태버전, SCD2)]. [주의: 팩트와 MEMBER_DK 직접 조인 시 팬아웃 발생, 시점조인 필수]. [원천: CRM → BRONZE_CRM.TM_MM_MBER_MNG → SILVER.CRM_MEMBER_STATUS_HIST].';

-- DIM_MEMBER — 정규 회원 마스터 차원 (분석 기본 진입점)
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER (
    MEMBER_SK           NUMBER(38,0)    NOT NULL COMMENT '대리키 (PK)',
    MEMBER_DK           VARCHAR(10)     NOT NULL PRIMARY KEY COMMENT '불변 비즈니스 식별자',
    MEMBER_TYPE         VARCHAR         COMMENT '회원 **등록계통** 구분. 코드id:MM010.',
    SEX                 VARCHAR         COMMENT '성별 원천코드 raw. 코드id:CM013',
    SEX_NM              VARCHAR         COMMENT '성별 원천 라벨. 코드id:CM013',
    GENDER_NAME         VARCHAR         COMMENT '성별 (#130). 고유값:남자,여자,기타,단체,기업',
    MBER_STAT_CD        VARCHAR         COMMENT '회원상태 원천코드 raw (#132). 코드id:MM010',
    MEMBER_STATUS_NAME  VARCHAR         COMMENT '회원상태명 (라벨). 코드id:MM010',
    MEMBER_STATUS_GROUP VARCHAR         COMMENT 'MEMBER_STATUS_GROUP. 코드id:MM010.',
    MBER_DIV_CD         VARCHAR         COMMENT '회원구분 원천코드 raw. 코드id:MM018',
    MEMBER_TYPE_NAME    VARCHAR         COMMENT '회원구분명 (라벨). 고유값:개인,기업,단체',
    JOIN_PATH_CD        VARCHAR         COMMENT '가입경로코드. 코드id:MM014',
    ENROLL_PATH_NAME    VARCHAR         COMMENT 'ENROLL_PATH_NAME. 코드id:MM014. [사유:원천 부재]',
    FIRST_JOIN_DATE     DATE            COMMENT '최초가입일 = 회원번호 생성일(정본 공#28) (#28).',
    FIRST_CAMPAIGN      VARCHAR         COMMENT '최초캠페인(정본 공#29) (#29).',
    REGION              VARCHAR         COMMENT '지역 (#131). 코드id:CM018',
    AGE_BAND            VARCHAR         COMMENT '연령대. 코드id:CM014',
    FIRST_SPONSORSHIP   VARCHAR         COMMENT 'FIRST_SPONSORSHIP.',
    LAST_STOP_DATE      DATE            COMMENT 'LAST_STOP_DATE.',
    EFFECTIVE_FROM      DATE            COMMENT 'SCD2 유효 시작 시각.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각(공통감사). 업무 축이 아니다.',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    JOIN_CMMN_BRND       NUMBER(10,0)     COMMENT '가입 공통브랜드 코드. 코드id:MM297',
    JOIN_CMMN_BRND_NM    VARCHAR(100)     COMMENT '가입 공통브랜드명. 코드id:MM297',
    CHRCTR_RECPTN_YN       VARCHAR(1)      COMMENT '문자수신여부 [SILVER.CRM_MEMBER 승계 · 원천 BRONZE_CRM.TM_MM_FDRM_MBER_INFO · BRONZE_CRM.TM_MM_ONCE_MBER_INFO]',
    SPECL_MNG_CD1          VARCHAR(100)    COMMENT '특별관리코드1 [SILVER.CRM_MEMBER 승계 · 원천 BRONZE_CRM.TM_MM_FDRM_MBER_INFO · BRONZE_CRM.TM_MM_ONCE_MBER_INFO]',
    FDRM_MBER_TRNSFER_FG   BOOLEAN         COMMENT '정기회원이관유무 [SILVER.CRM_MEMBER 승계 · 원천 BRONZE_CRM.TM_MM_ONCE_MBER_INFO]'
) COMMENT = '정규 회원 마스터 차원 (분석 기본 진입점). [Grain: MEMBER_DK (1행=1회원, IS_CURRENT 투영)]. [주의: 과거 시점 상태 분석은 DIM_MEMBER_STATUS_HISTORY 시점조인 사용]. [원천: SILVER.CRM_MEMBER_STATUS_HIST(IS_CURRENT)].';

-- DIM_MEMBER_ACQUISITION — 회원 획득(가입) 귀속 차원
--   ⚠️ 1행 = 1회원 — 팩트 조인은 MEMBER_DK LEFT JOIN(INNER 는 회원을 잃는다).
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER_ACQUISITION (
    MEMBER_DK                VARCHAR(10)     NOT NULL PRIMARY KEY COMMENT '불변 비즈니스 식별자',
    ACQ_CAMPAIGN_SK          NUMBER(38,0)    COMMENT '대리키 (PK)',
    ACQ_ORG_SK               NUMBER(38,0)    COMMENT '대리키 (PK)',
    ACQ_SPONSORSHIP_SK       NUMBER(38,0)    COMMENT '대리키 (PK)',
    ACQ_DATE_SK              NUMBER(8,0)     COMMENT '대리키 (PK)',
    ACQ_BASIS                VARCHAR         COMMENT 'ACQ_BASIS. 코드id:MM015.',
    ACQ_DVLP_DIV_CD          VARCHAR         COMMENT 'ACQ_DVLP_DIV_CD. 코드id:MM015.',
    ACQ_AGE_CD               NUMBER(2,0)     COMMENT 'ACQ_AGE_CD. 코드id:CM014.',
    ACQ_AGE_BAND             VARCHAR         COMMENT '획득 시점 연령대명(CM014 라벨, 사전 조인. 코드id:CM014. [사유:부서차원 산출불가]',
    ACQ_AREA_CD              VARCHAR         COMMENT 'ACQ_AREA_CD. 코드id:CM018.',
    ACQ_REGION               VARCHAR         COMMENT 'ACQ_REGION (#131). 코드id:CM018.',
    ACQ_SEX_CD               VARCHAR         COMMENT 'ACQ_SEX_CD. 코드id:CM013.',
    ACQ_GENDER               VARCHAR         COMMENT 'ACQ_GENDER. 코드id:CM013.',
    ACQ_SPNSR_AMT            NUMBER(18,0)    COMMENT 'ACQ_SPNSR_AMT (#38).',
    ACQ_BRAND                VARCHAR         COMMENT '획득 캠페인의 브랜드.',
    ACQ_CAMPAIGN_NAME        VARCHAR         COMMENT '현재 최신 캠페인명 (Master 실시간 조인 · MSTR 대조용).',
    ACQ_PARENT_CAMPAIGN_NAME VARCHAR         COMMENT '획득 캠페인의 **상위캠페인**명. 코드id:MM294.',
    ACQ_PROMO_METHOD_NAME    VARCHAR         COMMENT '획득 캠페인의 홍보방법명. 코드그룹 **CM008(홍보방법)**. 코드id:CM008.',
    ACQ_MARKETING_CAMPAIGN   VARCHAR         COMMENT '획득 캠페인의 마케팅캠페인.',
    ACQ_DEPARTMENT           VARCHAR         COMMENT '현재 최신 부서명 (Master 실시간 조인 · MSTR 대조용).',
    ACQ_SPONSORSHIP_NAME     VARCHAR         COMMENT 'ACQ_SPONSORSHIP_NAME (#123).',
    ACQ_INFLOW_PATH          VARCHAR         COMMENT '획득 캠페인의 모집 채널명(MM293 라벨). 코드id:MM293.',
    ACQ_CAMPAIGN_TYPE        VARCHAR         COMMENT '획득 캠페인의 카테고리 라벨(MM294). 코드id:MM294.',
    ACQ_DOMESTIC_OVERSEAS    VARCHAR         COMMENT 'ACQ_DOMESTIC_OVERSEAS. 코드id:MM295.',
    ACQ_BIZ_CASE_TYPE        VARCHAR         COMMENT 'ACQ_BIZ_CASE_TYPE. 코드id:MM296.',
    ACQ_CMMN_BRND_NM         VARCHAR         COMMENT '획득 캠페인의 공통브랜드명(MM297 라벨). 코드id:MM297.',
    ACQ_MKTG_UTM_NM          VARCHAR         COMMENT 'ACQ_MKTG_UTM_NM.',
    ACQ_SPNSR_DIV_NM         VARCHAR         COMMENT '획득 캠페인의 후원구분명(CM035 라벨: 정기후원/일시후원). 코드id:CM035.',
    ACQ_CPR_DIV_NM           VARCHAR         COMMENT '획득 캠페인의 법인구분명(CM019 라벨: 통합/사단/사복). 코드id:CM019.',
    FIRST_STOP_DATE_SK       NUMBER(8,0)     COMMENT '대리키 (PK)',
    FIRST_STOP_REASON_NM     VARCHAR         COMMENT 'FIRST_STOP_REASON_NM. 코드id:MM005.',
    TENURE_DAYS              NUMBER(9,0)     COMMENT '유지기간(일) = 최초 중단일 − 획득일.',
    IS_12M_OBSERVABLE        BOOLEAN         COMMENT 'IS_12M_OBSERVABLE.',
    DW_SOURCE_SYSTEM         VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS               TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS             TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID              VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 획득(가입) 귀속 차원. [Grain: MEMBER_DK (1행=1회원)]. [주의: 팩트와 LEFT JOIN 필수(개발사건 없는 회원 유실 방지)]. [원천: GOLD.FACT_MEMBER_COHORT].';

-- DIM_MEMBER_IDENTITY — 회원 신원 식별 브릿지 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER_IDENTITY (
    IDENTITY_SK         NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '회원 식별 대리키 (ETL 일련번호, PK)',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키',
    MEMBER_NO           VARCHAR         NOT NULL COMMENT '회원번호(#110)',
    MEMNUM              VARCHAR         COMMENT 'memnum (#111).',
    BIGQUERY_MEMBER_ID  VARCHAR         COMMENT 'BigQuery member id(#112)',
    HOMEPAGE_ID         VARCHAR         COMMENT 'HOMEPAGE_ID.',
    CHILD_CODE          VARCHAR         COMMENT '결연아동코드(#122, URL 파싱) (#122).',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 신원 식별 브릿지 차원. [Grain: IDENTITY_SK (1행=1식별키)]. [주의: 웹/앱 행동과 CRM 회원 연계용]. [원천: BIGQUERY/CRM → SILVER.IDENTITY_MEMBER_XREF].';

-- DIM_CAMPAIGN — 캠페인 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_CAMPAIGN (
    CAMPAIGN_SK         NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '캠페인 대리키 (ETL 일련번호, PK)',
    CAMPAIGN_BK         VARCHAR         NOT NULL COMMENT '캠페인 업무키(BK, 자연키)',
    BRAND               VARCHAR         COMMENT '공통브랜드(#117)',
    PARENT_CAMPAIGN     VARCHAR         COMMENT '상위캠페인 코드 (#119).',
    CAMPAIGN_NAME       VARCHAR         COMMENT '캠페인명(#18·120·147)',
    PROMO_METHOD        VARCHAR         COMMENT '홍보방법 원천코드 (#118). 코드id:CM008.',
    CAMPAIGN_TYPE       VARCHAR         COMMENT 'CAMPAIGN_TYPE (#17). 코드id:MM294.',
    DOMESTIC_OVERSEAS   VARCHAR         COMMENT 'DOMESTIC_OVERSEAS (#15). 코드id:MM295.',
    BIZ_CASE_TYPE       VARCHAR         COMMENT 'BIZ_CASE_TYPE (#16). 코드id:MM296.',
    INFLOW_PATH         VARCHAR         COMMENT 'INFLOW_PATH. 코드id:MM293.',
    MARKETING_CAMPAIGN  VARCHAR         COMMENT 'MARKETING_CAMPAIGN.',
    CAMPAIGN_OPEN_DATE  DATE            COMMENT '오픈일자(#19)',
    ORG_SK              NUMBER(38,0)    COMMENT '캠페인 귀속조직',
    PARENT_CAMPAIGN_NAME VARCHAR        COMMENT '상위캠페인명. 코드id:MM294.',
    PROMO_METHOD_NAME   VARCHAR         COMMENT '홍보방법명. 코드id:CM008.',
    MKTG_CAMPAIGN_SK    NUMBER(38,0)    COMMENT '대리키 (PK)',
    SPNSR_DIV_CD        VARCHAR         COMMENT '후원구분 원천코드(CM035): 1=정기후원 · 2=일시후원. 코드id:CM035.',
    SPNSR_DIV_NM        VARCHAR         COMMENT '후원구분명. 코드id:CM035.',
    CPR_DIV_CD          VARCHAR         COMMENT 'CPR_DIV_CD. 코드id:CM019.',
    CPR_DIV_NM          VARCHAR         COMMENT '법인구분명. 코드id:CM019.',
    CMMN_BRND           VARCHAR         COMMENT '공통브랜드 원천코드(MM297, 14종). 코드id:MM297.',
    CMMN_BRND_NM        VARCHAR         COMMENT '공통브랜드명. 코드id:MM297.',
    MKTG_UTM            NUMBER(38,0)    COMMENT '마케팅 UTM 원천코드 (TC_MKTNG_DTL_CD U001 대응).',
    MKTG_UTM_NM         VARCHAR         COMMENT '마케팅 UTM 라벨 (TC_MKTNG_DTL_CD U001 라벨).',
    MKTG_CHANNEL        NUMBER(38,0)    COMMENT '마케팅 채널 원천코드 (TC_MKTNG_DTL_CD C002 대응).',
    MKTG_CHANNEL_NM     VARCHAR         COMMENT '마케팅 채널명 (TC_MKTNG_DTL_CD C002 라벨).',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    USE_DEPT_CD            VARCHAR(10)     COMMENT '사용부서코드 [SILVER.CRM_CAMPAIGN 승계 · 원천 BRONZE_CRM.TM_CM_CMPGN_MNG]',
    USE_SCOPE              VARCHAR(1)      COMMENT '사용범위 [SILVER.CRM_CAMPAIGN 승계 · 원천 BRONZE_CRM.TM_CM_CMPGN_MNG]',
    USE_YN                 VARCHAR(1)      COMMENT '사용여부 [SILVER.CRM_CAMPAIGN 승계 · 원천 BRONZE_CRM.TM_CM_CMPGN_MNG]',
    CMPGN_PRPT_YN          VARCHAR(1)      COMMENT '캠페인특성여부 [SILVER.CRM_CAMPAIGN 승계 · 원천 BRONZE_CRM.TM_CM_CMPGN_MNG]',
    SPNSR_ENTRPRS_ID       VARCHAR(20)     COMMENT '후원기업ID [SILVER.CRM_CAMPAIGN 승계 · 원천 BRONZE_CRM.TM_CM_CMPGN_MNG]',
    EMRGNCY_AID_BPLC_CD    NUMBER(10,0)    COMMENT '긴급구호사업장코드 [SILVER.CRM_CAMPAIGN 승계 · 원천 BRONZE_CRM.TM_CM_CMPGN_MNG]',
    BRND_USE_YN            VARCHAR(1)      COMMENT '사용여부 [SILVER.CRM_CAMPAIGN 승계 · 원천 BRONZE_CRM.TM_CM_BRND_MNG]'
) COMMENT = '캠페인 차원. [Grain: CAMPAIGN_SK (1행=1캠페인)]. [주의: 분류체계 카테고리/상위/홍보방법 매핑]. [원천: CRM → BRONZE_CRM.TM_CM_CMPGN_MNG → SILVER.CRM_CAMPAIGN].';

-- DIM_MARKETING_CAMPAIGN — 마케팅 캠페인 Conformed 차원
--   ⚠️ 광고(AGENCY) ↔ CRM 결합이 성립하는 유일한 grain.
--   ⚠️ DEV_CAMPAIGN_CNT > 1 이면 개발캠페인 단위로 광고비를 내릴 때 그 배수만큼 복제된다.
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MARKETING_CAMPAIGN (
    MKTG_CAMPAIGN_SK    NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '대리키 (PK)',
    MKTG_CAMPAIGN_BK    VARCHAR         COMMENT 'MKTG_CAMPAIGN_BK.',
    MKTG_CAMPAIGN_NAME  VARCHAR         COMMENT '마케팅캠페인명.',
    USE_YN              VARCHAR         COMMENT '사용여부 Y/N. 고유값:Y,N',
    DEV_CAMPAIGN_CNT    NUMBER(38,0)    COMMENT 'DEV_CAMPAIGN_CNT.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '마케팅 캠페인 Conformed 차원. [Grain: MKTG_CAMPAIGN_SK (1행=1마케팅캠페인)]. [주의: 광고(AGENCY)와 CRM 개발 결합의 유일 결합축]. [원천: SILVER.CRM_MARKETING_CAMPAIGN].';

-- DIM_SPONSORSHIP — 후원사업 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_SPONSORSHIP (
    SPONSORSHIP_SK      NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '후원사업 대리키 (ETL 일련번호, PK)',
    SPONSORSHIP_BK      VARCHAR         NOT NULL COMMENT '후원사업 업무키(BK, 자연키)',
    SPONSORSHIP_NAME    VARCHAR         COMMENT '후원사업 전체(#123)',
    SPONSORSHIP_ABBR    VARCHAR         COMMENT '약칭 (#124). 코드id:CM003.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    SPONSORSHIP_DIV_CD     VARCHAR      COMMENT 'SPONSORSHIP_DIV_CD. 코드id:CM035.',
    SPONSORSHIP_DIV_NAME   VARCHAR      COMMENT '정기일시후원구분명. 코드id:CM035.',
    SPONSORSHIP_GROUP_NAME VARCHAR      COMMENT '후원약칭명. 코드id:CM003.',
    SPONSORSHIP_GROUP4_NAME VARCHAR     COMMENT '후원사업 4그룹(ML 요건 · 국내/결연/해외프로젝트/기타) — CM003 라벨 접기: 해외구호·해외→해외프로젝트 · 북한→기타(사용자 결정 §4 #2 · 문서20 F-2). 규칙 밖 라벨은 NULL',
    SORT_ORDR              NUMBER(10,0)    COMMENT '정렬순서 [SILVER.CRM_SPONSORSHIP 승계 · 원천 BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO]',
    USE_YN                 VARCHAR(1)      COMMENT '사용여부 [SILVER.CRM_SPONSORSHIP 승계 · 원천 BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO]',
    CPR_DIV_CD             VARCHAR         COMMENT '[O202] 후원사업 법인구분 코드(CM019: A 통합 · I 사단 · S 사복) — MSTR 법인 축. 코드id:CM019. [SILVER.CRM_SPONSORSHIP 승계]',
    CPR_DIV_NM             VARCHAR         COMMENT '[O202] 후원사업 법인구분명(통합/사단/사복). 코드id:CM019. 🔴 세부캠페인 법인(FACT_MEMBER_EVENT.CPR_DIV_*_AT_EVENT)과 다른 축.'
) COMMENT = '후원사업 차원. [Grain: SPONSORSHIP_SK (1행=1후원사업)]. [주의: 정기/일시 구분 및 상위 사업군 분류]. [원천: CRM → BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO → SILVER.CRM_SPONSORSHIP].';

-- DIM_AD_CREATIVE — 광고 소재/매체 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_AD_CREATIVE (
    AD_CREATIVE_SK      NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '광고소재 대리키 (ETL 일련번호, PK)',
    AD_CREATIVE_BK      VARCHAR         NOT NULL COMMENT '광고소재 업무키(BK, 자연키)',
    MEDIA_NAME          VARCHAR         COMMENT '매체명/공동브랜드(#11)',
    PLATFORM            VARCHAR         COMMENT '플랫폼(#12)',
    PLATFORM_TYPE       VARCHAR         COMMENT '플랫폼/매체유형 (#13). [사유:원천 부재]',
    CREATIVE            VARCHAR         COMMENT '소재(#20)',
    CM_POSITION         VARCHAR         COMMENT 'CM위치(#21)',
    AD_TYPE             VARCHAR         COMMENT '소재 광고유형.',
    TARGET_GROUP        VARCHAR         COMMENT 'TARGET_GROUP.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '광고 소재/매체 차원. [Grain: AD_CREATIVE_SK (1행=1소재)]. [주의: 대행사 3원천 소재 통합]. [원천: AGENCY 3소스 → SILVER.AGENCY_AD_CREATIVE].';

-- DIM_BIGQUERY_SOURCE — BigQuery 트래픽소스 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_BIGQUERY_SOURCE (
    BIGQUERY_SOURCE_SK  NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT 'BigQuery 트래픽소스 대리키 (ETL 일련번호, PK)',
    UTM_SOURCE          VARCHAR         COMMENT 'source',
    UTM_MEDIUM          VARCHAR         COMMENT 'medium',
    UTM_CONTENT         VARCHAR         COMMENT '세션 수동 광고 콘텐츠(#103)',
    UTM_TERM            VARCHAR         COMMENT '세션 수동 검색어(#104)',
    SOURCE_MEDIUM       VARCHAR         COMMENT '세션 소스/매체(#109)',
    DEFAULT_CHANNEL_GROUP VARCHAR       COMMENT '[DEC.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'BigQuery 트래픽소스 차원. [Grain: BIGQUERY_SOURCE_SK (1행=1트래픽소스)]. [주의: 세션 소스/매체/캠페인 결합]. [원천: BIGQUERY → SILVER.BIGQUERY_TRAFFIC_SOURCE].';

-- DIM_BIGQUERY_EVENT — BigQuery 이벤트분류 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_BIGQUERY_EVENT (
    BIGQUERY_EVENT_SK   NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT 'BigQuery 이벤트 대리키 (ETL 일련번호, PK)',
    EVENT_CATEGORY      VARCHAR         COMMENT '이벤트 카테고리(#99)',
    EVENT_LABEL         VARCHAR         COMMENT '이벤트 라벨(#100)',
    EVENT_ACTION        VARCHAR         COMMENT '이벤트 액션(#101)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'BigQuery 이벤트분류 차원. [Grain: BIGQUERY_EVENT_SK (1행=1이벤트)]. [주의: GA4 이벤트명 및 주요 파라미터 매핑]. [원천: BIGQUERY → SILVER.BIGQUERY_EVENT_DIM].';

-- DIM_SERVICE — 발송 서비스 채널 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_SERVICE (
    SERVICE_SK          NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '서비스 대리키 (ETL 일련번호, PK)',
    SUBTYPE             VARCHAR         COMMENT '발송/참여 subtype',
    CHANNEL             VARCHAR         COMMENT 'CHANNEL.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '발송 서비스 채널 차원. [Grain: SERVICE_SK (1행=1채널유형)]. [주의: 대/중/소 상세분류는 DIM_SEND_TYPE 참조]. [원천: CRM → BRONZE_CRM.TM_MS_* → SILVER.CRM_SEND_REQUEST].';

-- DIM_SEND_TYPE — 발송구분 대/중/소 차원
--   ⚠️ 자연키 = (대,중,소) 전체 경로 — 중분류 코드 단독은 모호하다.
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_SEND_TYPE (
    SEND_TYPE_SK        NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '발송구분 대리키 (ETL 해시, PK)',
    SEND_TYPE_BK        VARCHAR         NOT NULL COMMENT '발송구분 업무키 = 대>중>소 코드 경로(자연키). ⚠️중분류 코드는 단독으로 모호하다(코드 16종 vs 라벨 26종) → 반드시 전체 경로로 식별한다',
    SEND_GBN_TOP        VARCHAR         COMMENT '발송구분 대 코드 raw ← CRM_SEND_REQUEST.SEND_GBN_TOP. ⚠️이 값은 코드가 아니라 CRM_CODE.CD_ID(코드그룹 ID) 자체다 — MS046 결연·MS047 회원·MS048 회비·MS049 서비스·MS050 사업보고 등 12종. 라벨=SEND_TYPE_L',
    SEND_TYPE_L         VARCHAR         COMMENT '발송구분(대) (#133) 분석 라벨 ← SEND_GBN_TOP_NM. 🔴정본 #133 과 불일치(2026-08-04 실측): #133 은 6종(결연/회비/서비스/사업보고/참여/기타)인데 실측 라벨 **9종** — 추가 3종 = 회원만족(MS052)·회원서비스(MS054)·회원(MS047+MS053). #133 은 생략기호가 없어 완전열거로 읽힌다 → 불일치 실재. 문서20 §L 현업 확인 · 데이터 우선 보존(DEC-26). ⚠️대분류는 코드그룹과 1:1 이 아니다 — 결연=MS046+MS051 · 기타=MS0505+MS055 · 회원=MS047+MS053 (코드그룹 12종 → 라벨 9종). 🟢SEND_GBN_TOP 12종 전부 CRM_CODE.CD_ID 실재 확인',
    SEND_GBN_MID        VARCHAR         COMMENT '발송구분 중 코드 raw ← SEND_GBN_MID. 🔴 코드 단독 사용 금지 — 실측 코드 16종에 라벨 26종이 대응한다(부모 그룹에 따라 의미가 달라짐). 반드시 (대,중) 쌍으로 해석',
    SEND_TYPE_M         VARCHAR         COMMENT '발송구분(중) (#134) 분석 라벨 ← SEND_GBN_MID_NM. 정본 값정의: 선물금/신규결연회원발송/회원서신/만18세아동종결/일반퇴소 등',
    SEND_GBN_BOT        VARCHAR         COMMENT '발송구분 소 코드 raw ← SEND_GBN_BOT (CRM_CODE.UPPER_CD_ID 계층 하위). 🔴 코드 단독 모호(코드 42종 vs 라벨 56종) → (대,중,소) 경로로 해석',
    SEND_TYPE_S         VARCHAR         COMMENT '발송구분(소) (#135) 분석 라벨 ← SEND_GBN_BOT_NM. 정본 값정의: 선물금접수확인/신규결연우편물(PF)/결연100일/서신접수확인/첫출금안내(사단) 등',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '발송구분 대/중/소 차원. [Grain: SEND_TYPE_SK (1행=1분류경로)]. [주의: 발송 메시지 세부 카테고리 매핑]. [원천: CRM → BRONZE_CRM.TM_MS_EMAIL/MSG/PSTMTR → SILVER.CRM_SEND_REQUEST].';

-- DIM_PAYMENT — 납입 결제수단 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_PAYMENT (
    PAYMENT_SK          NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '납입/결제 대리키 (ETL 일련번호, PK)',
    PAYMENT_METHOD      VARCHAR         COMMENT '납입방식(#125)',
    SETTLE_METHOD       VARCHAR         COMMENT '결제방식',
    FEE_TYPE            VARCHAR         COMMENT '회비유형(정기/일시 — #66~68 분해)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '납입 결제수단 차원. [Grain: PAYMENT_SK (1행=1결제유형)]. [주의: 금융결제원/카드사 수납방식 분류]. [원천: CRM → SILVER.CRM_PAYMENT_METHOD].';

-- DIM_REASON — 중단/미납 사유코드 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_REASON (
    REASON_SK           NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '사유 대리키 (ETL 일련번호, PK)',
    REASON_CODE         VARCHAR         NOT NULL COMMENT '사유코드(BK, 업무키)',
    REASON_NAME         VARCHAR         COMMENT '중단사유(#162)·미납사유(#82)',
    REASON_TYPE         VARCHAR         COMMENT '사유 코드그룹 ID. 코드id:PM019.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '중단/미납 사유코드 차원. [Grain: REASON_SK (1행=1사유)]. [주의: 후원중단 및 청구미납 사유 통합]. [원천: CRM → BRONZE_CRM.TM_CM_CODE_DTL → SILVER.CRM_CODE].';

-- DIM_DEVICE — 디바이스/기기 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_DEVICE (
    DEVICE_SK           NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '대리키 (PK)',
    DEVICE_TYPE         VARCHAR         COMMENT 'DEVICE_TYPE.',
    DEVICE_SCOPE_DESC   VARCHAR         COMMENT '멤버 의미 자기설명(DEC.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '디바이스/기기 차원. [Grain: DEVICE_SK (1행=1디바이스)]. [주의: PC/모바일/방송(해당없음) 분류]. [원천: BIGQUERY/AGENCY → SILVER.BIGQUERY_DEVICE].';

-- DIM_EVENT — 행사/이벤트 마스터 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_EVENT (
    EVENT_SK            NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '행사 대리키 (ETL 일련번호, PK)',
    EVENT_BK            VARCHAR         NOT NULL COMMENT '행사 업무키(BK, 자연키)',
    EVENT_KIND          VARCHAR         COMMENT 'EVENT_KIND.',
    EVENT_KIND_NAME     VARCHAR         COMMENT '행사종류명(라벨). EVENT→일반행사·CRMN→캠페인행사.',
    EVENT_CATEGORY      VARCHAR         COMMENT '행사구분',
    EVENT_NAME          VARCHAR         COMMENT '행사명',
    EVENT_START_DATE    DATE            COMMENT '행사기간 시작(05 3-6)',
    EVENT_END_DATE      DATE            COMMENT '행사기간 종료(05 3-6)',
    APPLY_CHANNEL       VARCHAR         COMMENT '신청경로',
    RECRUIT_HEADCOUNT   NUMBER(38,0)    COMMENT '[DEC.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    EVENT_CATEGORY_GROUP VARCHAR(10)    COMMENT 'EVENT_CATEGORY_GROUP. 코드id:MS286.',
    EVENT_CATEGORY_NAME  VARCHAR        COMMENT 'EVENT_CATEGORY_NAME.',
    PRZWIN_PSNNL_CO        NUMBER(10,0)    COMMENT '당첨인원수 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_EVENT]',
    PRZWIN_GFT_SNDNG_DE    VARCHAR(8)      COMMENT '당첨선물발송일 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_EVENT]',
    CRMN_PLACE_NM          VARCHAR(200)    COMMENT '행사장소명 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_CRMN]',
    CRMN_PART_STRT_DE      VARCHAR(8)      COMMENT '캠페인참여시작일자 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_CRMN]',
    CRMN_PART_END_DE       VARCHAR(8)      COMMENT '캠페인참여종료일자 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_CRMN]',
    TAT                    NUMBER(5,0)     COMMENT '소요시간 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_CRMN]',
    RESRCE_SRVC_FG         BOOLEAN         COMMENT '자원봉사유무 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_CRMN]',
    CPR_DIV_CD             VARCHAR(3)      COMMENT '법인구분코드 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_CRMN]',
    ENTRPS_CD              NUMBER(10,0)    COMMENT '업체코드 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_CRMN]',
    USE_YN                 VARCHAR(1)      COMMENT '사용여부 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_CRMN]'
) COMMENT = '행사/이벤트 마스터 차원. [Grain: EVENT_SK (1행=1행사)]. [주의: 일반행사 및 캠페인행사 통합]. [원천: CRM → BRONZE_CRM.TM_MS_EVENT/CRMN → SILVER.CRM_EVENT].';

-- DIM_BUDGET_ITEM — 예산 세세목 차원
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_BUDGET_ITEM (
    BUDGET_ITEM_SK      NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '예산 세세목 대리키 (ETL 일련번호, PK)',
    BUDGET_ITEM_NAME    VARCHAR         COMMENT '세세목명',
    BUDGET_CATEGORY     VARCHAR         COMMENT '예산구분',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    BDGT_UNIT_NM        VARCHAR         COMMENT '예산단위명(ERP 원천 BDGT_UNIT_NM 그대로 · 조직명 표기 · 코드 없음). 세세목에 1:1 종속(2026-10-02 O198 실측 179/179). 🔴 DIM_ORG(CRM 조직)와 다른 체계다 — 같은 이름의 팀이라도 ORG_SK 로 조인하지 말 것. 실측 값 6종(ERP 표기 그대로)'
) COMMENT = '예산 세세목 차원. [Grain: BUDGET_ITEM_SK (1행=1세세목)]. [주의: 장/관/항/목/세목/세세목 계층 매핑]. [원천: ERP → BRONZE_ERP → SILVER.ERP_BUDGET_ITEM].';

-- DIM_BIZ_PLACE — DIM_BIZ_PLACE — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_BIZ_PLACE (
    BIZ_PLACE_SK             NUMBER(38,0)     COMMENT '대리키 = hash(BPLC_CD) · 0=미매핑 시드 · PK(정보성)',
    BPLC_CD                  VARCHAR(8)       COMMENT '사업장코드 [원천: SILVER.CRM_BIZ_PLACE]',
    NATION_CD                VARCHAR(3)       COMMENT '국가코드 [원천: SILVER.CRM_BIZ_PLACE]',
    BPLC_KORNM               VARCHAR(200)     COMMENT '사업장한글명 [원천: SILVER.CRM_BIZ_PLACE]',
    BPLC_ENGNM               VARCHAR(200)     COMMENT '사업장영문명 [원천: SILVER.CRM_BIZ_PLACE]',
    BSNS_STRT_DE             DATE             COMMENT '사업시작일 [원천: SILVER.CRM_BIZ_PLACE]',
    BSNS_END_DE              DATE             COMMENT '사업종료일 [원천: SILVER.CRM_BIZ_PLACE]',
    RELATNSP_BSNS_YN         VARCHAR(1)       COMMENT '결연사업여부 [원천: SILVER.CRM_BIZ_PLACE]',
    RELATNSP_BSNS_DSCNTC_DE  DATE             COMMENT '결연사업중단일 [원천: SILVER.CRM_BIZ_PLACE]',
    GFTMNEY_PSBL_YN          VARCHAR(1)       COMMENT '선물금가능여부 [원천: SILVER.CRM_BIZ_PLACE]',
    LETTER_PSBL_YN           VARCHAR(1)       COMMENT '서신가능여부 [원천: SILVER.CRM_BIZ_PLACE]',
    BPLC_DC                  VARCHAR(4000)    COMMENT '사업장설명 [원천: SILVER.CRM_BIZ_PLACE]',
    WTWK_FROM_DSTNC          NUMBER(10,0)     COMMENT '수도부터거리 [원천: SILVER.CRM_BIZ_PLACE]',
    CNCSN_RSN                VARCHAR(100)     COMMENT '종결사유 [원천: SILVER.CRM_BIZ_PLACE]',
    BPLC_MTCHG_MNG_YN        VARCHAR(1)       COMMENT '사업장매칭관리여부 [원천: SILVER.CRM_BIZ_PLACE]',
    DW_SOURCE_SYSTEM         VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS               TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS             TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID              VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'DIM_BIZ_PLACE — O188-F 2차-A 신설. [원천: SILVER.CRM_BIZ_PLACE]. [적재: dbt]';

-- DIM_CHILD — DIM_CHILD — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_CHILD (
    CHILD_SK           NUMBER(38,0)     COMMENT '대리키 = hash(아동코드) · PK(정보성)',
    CHILD_CD           NUMBER(10,0)     COMMENT '아동코드 [원천: SILVER.CRM_CHILD]',
    CHILD_NO           VARCHAR(30)      COMMENT '아동번호 [원천: SILVER.CRM_CHILD]',
    CMS_CHILD_NO       VARCHAR(30)      COMMENT 'CMS아동번호 [원천: SILVER.CRM_CHILD]',
    BIZ_PLACE_SK       NUMBER(38,0)     COMMENT '사업장 대리키 → DIM_BIZ_PLACE.BIZ_PLACE_SK(FK 정보성 · 미해소 0 실측) · 0=미매핑',
    BPLC_CD            VARCHAR(8)       COMMENT '사업장코드 [원천: SILVER.CRM_CHILD]',
    MNYRS_NATION_CD    VARCHAR(3)       COMMENT '모금국가코드 [원천: SILVER.CRM_CHILD]',
    SEX                VARCHAR(2)       COMMENT '성별 [원천: SILVER.CRM_CHILD]',
    RELATNSP_STAT_CD   VARCHAR(3)       COMMENT '결연상태코드 [원천: SILVER.CRM_CHILD]',
    CHILD_STAT_CD      VARCHAR(3)       COMMENT '아동상태코드 [원천: SILVER.CRM_CHILD]',
    CHILD_DTL_STAT_CD  VARCHAR(3)       COMMENT '아동상세상태코드 [원천: SILVER.CRM_CHILD]',
    REGIST_DIV_CD      VARCHAR(3)       COMMENT '등록구분코드 [원천: SILVER.CRM_CHILD]',
    FRST_REGIST_DT     TIMESTAMP_NTZ(9) COMMENT '최초등록일시 [원천: SILVER.CRM_CHILD]',
    LAST_REGIST_DT     TIMESTAMP_NTZ(9) COMMENT '최종등록일시 [원천: SILVER.CRM_CHILD]',
    RE_UPDT_DT         TIMESTAMP_NTZ(9) COMMENT '재수정일시 [원천: SILVER.CRM_CHILD]',
    DW_SOURCE_SYSTEM   VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS         TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS       TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID        VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'DIM_CHILD — O188-F 2차-A 신설. [원천: SILVER.CRM_CHILD]. [적재: dbt]';

-- DIM_CODE_GROUP — DIM_CODE_GROUP — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_CODE_GROUP (
    CD_ID             VARCHAR(20)      COMMENT '코드ID [원천: SILVER.CRM_CODE_GROUP]',
    CD_NM             VARCHAR(100)     COMMENT '코드명 [원천: SILVER.CRM_CODE_GROUP]',
    CD_DC             VARCHAR(500)     COMMENT '코드설명 [원천: SILVER.CRM_CODE_GROUP]',
    SORT_ORDR         NUMBER(10,0)     COMMENT '정렬순서 [원천: SILVER.CRM_CODE_GROUP]',
    RM                VARCHAR(1000)    COMMENT '비고 [원천: SILVER.CRM_CODE_GROUP]',
    USE_YN            VARCHAR(1)       COMMENT '사용여부 [원천: SILVER.CRM_CODE_GROUP]',
    DTL_CODE_CNT      NUMBER(18,0)     COMMENT '세부코드 수 — 이 코드그룹(CD_ID)에 속한 상세코드 행 수(CRM_CODE) · 없으면 0 · 모델 파생',
    DW_SOURCE_SYSTEM  VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'DIM_CODE_GROUP — O188-F 2차-A 신설. [원천: SILVER.CRM_CODE_GROUP]. [적재: dbt]';

-- DIM_MSG_TEMPLATE — DIM_MSG_TEMPLATE — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MSG_TEMPLATE (
    TEMPLATE_SK             NUMBER(38,0)     COMMENT '대리키 = hash(템플릿키) · PK(정보성)',
    SEND_CHANNEL            VARCHAR(6)       COMMENT '발송채널 — MSG_AT=알림톡 템플릿(TM_MS_AT_TMPLAT_MNG) · EMAIL=이메일 템플릿(TM_MS_EMAIL_TMPLAT_MNG) · 모델 파생(UNION 분기)',
    TEMPLATE_KEY            VARCHAR          COMMENT '템플릿 키 — 알림톡=템플릿ID(TMPLAT_ID) · 이메일=템플릿KEY(TMPLAT_KEY 문자열화) · SEND_CHANNEL 과 함께 유일',
    CPR_DIV_CD              VARCHAR(3)       COMMENT '법인구분코드 [원천: SILVER.CRM_MSG_TEMPLATE]',
    SNDNG_CD_ID             VARCHAR(20)      COMMENT '발신코드ID [원천: SILVER.CRM_MSG_TEMPLATE]',
    SNDNG_DTL_CD_ID         VARCHAR(20)      COMMENT '발신상세코드ID [원천: SILVER.CRM_MSG_TEMPLATE]',
    ATMC_YN                 VARCHAR(1)       COMMENT '자동여부 [원천: SILVER.CRM_MSG_TEMPLATE]',
    TIT                     VARCHAR(100)     COMMENT '제목 [원천: SILVER.CRM_MSG_TEMPLATE]',
    TEMPLATE_CTNT           VARCHAR          COMMENT '템플릿 본문 — 알림톡=템플릿내용(TMPLAT_CTNT) · 이메일=이메일내용(EMAIL_CTNT)',
    WRITNG_DEPT_ID          VARCHAR(20)      COMMENT '작성부서ID [원천: SILVER.CRM_MSG_TEMPLATE]',
    WRITNG_DEPT_NM          VARCHAR(30)      COMMENT '작성부서명 [원천: SILVER.CRM_MSG_TEMPLATE]',
    CHRG_DEPT_ID            VARCHAR(20)      COMMENT '담당부서ID [원천: SILVER.CRM_MSG_TEMPLATE]',
    APRV_STAT_CD            VARCHAR(3)       COMMENT '승인상태코드 [원천: SILVER.CRM_MSG_TEMPLATE]',
    APRV_FAILR_CTNT         VARCHAR(4000)    COMMENT '승인실패내용 [원천: SILVER.CRM_MSG_TEMPLATE]',
    TEMPLATE_RM             VARCHAR(4000)    COMMENT '템플릿비고(TMPLAT_RM) — 알림톡 전용 · 이메일 행은 원천 개념 부재로 NULL',
    ALTRTV_MSG_SNDNG_YN     VARCHAR(1)       COMMENT '대체메시지발신여부 [원천: SILVER.CRM_MSG_TEMPLATE]',
    ALTRTV_MSG_TMPLAT_KEY   NUMBER(10,0)     COMMENT '대체메시지템플릿KEY [원천: SILVER.CRM_MSG_TEMPLATE]',
    ALTRTV_MSG_CTNT         VARCHAR          COMMENT '대체메시지내용 [원천: SILVER.CRM_MSG_TEMPLATE]',
    ALTRTV_MSG_ATCHFL_ID    VARCHAR(20)      COMMENT '대체메시지첨부파일ID [원천: SILVER.CRM_MSG_TEMPLATE]',
    WRITNG_GUIDE_ATCHFL_ID  VARCHAR(20)      COMMENT '작성가이드첨부파일ID [원천: SILVER.CRM_MSG_TEMPLATE]',
    USE_YN                  VARCHAR(1)       COMMENT '사용여부 [원천: SILVER.CRM_MSG_TEMPLATE]',
    FRST_REGIST_DT          TIMESTAMP_NTZ(9) COMMENT '최초등록일시 [원천: SILVER.CRM_MSG_TEMPLATE]',
    LAST_UPDT_DT            TIMESTAMP_NTZ(9) COMMENT '최종수정일시 [원천: SILVER.CRM_MSG_TEMPLATE]',
    BUTTON_CNT              NUMBER(18,0)     COMMENT '버튼 수 — 알림톡 템플릿의 버튼 행 수(CRM_MSG_TEMPLATE_BUTTON) · 버튼 없으면 0 · 이메일은 개념 부재로 NULL · 모델 파생',
    DW_SOURCE_SYSTEM        VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'DIM_MSG_TEMPLATE — O188-F 2차-A 신설. [원천: SILVER.CRM_MSG_TEMPLATE]. [적재: dbt]';

-- DIM_MSG_TEMPLATE_BUTTON — DIM_MSG_TEMPLATE_BUTTON — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MSG_TEMPLATE_BUTTON (
    TEMPLATE_BUTTON_SK  NUMBER(38,0)     COMMENT '대리키 · PK(정보성)',
    TEMPLATE_SK         NUMBER(38,0)     COMMENT '템플릿 대리키 → DIM_MSG_TEMPLATE.TEMPLATE_SK(FK 정보성 · 🟠 미해소 21행 = 버튼만 있고 템플릿 마스터에 없는 행)',
    TMPLAT_ID           VARCHAR(30)      COMMENT '템플릿ID [원천: SILVER.CRM_MSG_TEMPLATE_BUTTON]',
    BTN_SEQ             NUMBER(10,0)     COMMENT '버튼순번 [원천: SILVER.CRM_MSG_TEMPLATE_BUTTON]',
    BTN_TY_CD           VARCHAR(3)       COMMENT '버튼유형코드 [원천: SILVER.CRM_MSG_TEMPLATE_BUTTON]',
    BTN_NM              VARCHAR          COMMENT '버튼명 [원천: SILVER.CRM_MSG_TEMPLATE_BUTTON]',
    ANDROID_URL         VARCHAR(255)     COMMENT '안드로이드URL [원천: SILVER.CRM_MSG_TEMPLATE_BUTTON]',
    IOS_URL             VARCHAR(255)     COMMENT 'IOSURL [원천: SILVER.CRM_MSG_TEMPLATE_BUTTON]',
    MOBILE_URL          VARCHAR(255)     COMMENT '모바일URL [원천: SILVER.CRM_MSG_TEMPLATE_BUTTON]',
    PC_URL              VARCHAR(255)     COMMENT 'PCURL [원천: SILVER.CRM_MSG_TEMPLATE_BUTTON]',
    DW_SOURCE_SYSTEM    VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'DIM_MSG_TEMPLATE_BUTTON — O188-F 2차-A 신설. [원천: SILVER.CRM_MSG_TEMPLATE_BUTTON]. [적재: dbt]';

-- DIM_PAYMENT_ACCOUNT — DIM_PAYMENT_ACCOUNT — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_PAYMENT_ACCOUNT (
    PAYMENT_ACCOUNT_SK   NUMBER(38,0)     COMMENT '대리키 · PK(정보성)',
    ACCOUNT_KIND         VARCHAR(11)      COMMENT '계정 종류 — INSTT=기관 계좌(TM_PM_INSTT_ACNUT) · SETLE_CMPNY=결제사 계정(TM_PM_SETLE_CMPNY_ACNT) · 모델 파생(UNION 분기)',
    ACCOUNT_KEY          VARCHAR          COMMENT '계정 키 — INSTT=계좌일련번호(ACNUT_SER_NO) · SETLE_CMPNY=결제사계좌번호(SETLE_CMPNY_ACNT_NO) 문자열화 · ACCOUNT_KIND 와 함께 유일',
    CPR_DIV_CD           VARCHAR(3)       COMMENT '법인구분코드 [원천: SILVER.CRM_INSTT_ACCOUNT]',
    ACCOUNT_DIV_CD       VARCHAR(3)       COMMENT '계좌구분코드 — INSTT=계좌구분코드(ACNUT_DIV_CD · 실제값 1·2) · SETLE_CMPNY=결제사계좌구분코드(SETLE_CMPNY_ACNT_DIV_CD · 실제값 1·2·3·4 + NULL) · 🔴 두 원천의 코드 도메인이 달라 같은 체계로 보장되지 않는다 — 반드시 ACCOUNT_KIND 와 함께 본다',
    BANK_CD              VARCHAR(10)      COMMENT '은행코드 [원천: SILVER.CRM_INSTT_ACCOUNT]',
    ACCOUNT_PURPOSE      VARCHAR(100)     COMMENT '계좌용도(ACNUT_PRP · ACNT_PRP)',
    ACCOUNT_ABBR         VARCHAR(30)      COMMENT '계좌약칭(ACNUT_ABRV) — 기관 계좌 전용 · 결제사 행 NULL',
    CHRG_DEPT_CD         VARCHAR(10)      COMMENT '담당부서코드 [원천: SILVER.CRM_INSTT_ACCOUNT]',
    REGIST_USE_YN        VARCHAR(1)       COMMENT '등록사용여부 [원천: SILVER.CRM_INSTT_ACCOUNT]',
    USE_YN               VARCHAR(1)       COMMENT '사용여부 [원천: SILVER.CRM_INSTT_ACCOUNT]',
    SETLE_CMPNY_ACNT_ID  VARCHAR          COMMENT '결제사계좌ID [원천: SILVER.CRM_INSTT_ACCOUNT]',
    INSTT_ACNUT_SER_NO   NUMBER(10,0)     COMMENT '기관계좌 일련번호(ACNUT_SER_NO · 참조 TM_PM_INSTT_ACNUT) — 결제사 계정이 연결된 기관 계좌 · INSTT 행은 자기 자신',
    RM                   VARCHAR          COMMENT '비고 [원천: SILVER.CRM_INSTT_ACCOUNT]',
    DW_SOURCE_SYSTEM     VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS           TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS         TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID          VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'DIM_PAYMENT_ACCOUNT — O188-F 2차-A 신설. [원천: SILVER.CRM_INSTT_ACCOUNT]. [적재: dbt]';

-- ============================================================================
-- FACT — 팩트
-- ============================================================================
--   ⚠️ 분석축 SK 의 0 = (미매핑) 센티넬 멤버다 — 「없음」이 아니다.

-- FACT_MEMBER_MONTHLY — 회원 월별 스냅샷 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY (
    MONTH_KEY                   NUMBER(6,0)     NOT NULL COMMENT 'YYYYMM',
    MEMBER_DK                   VARCHAR(10)     NOT NULL COMMENT '월 스냅샷 대상 회원 (불변키)',
    CAMPAIGN_SK                 NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    SPONSORSHIP_SK              NUMBER(38,0)    COMMENT '후원사업 (FK→DIM_SPONSORSHIP)',
    PAYMENT_SK                  NUMBER(38,0)    COMMENT '납입/결제 유형 (FK→DIM_PAYMENT)',
    REASON_SK                   NUMBER(38,0)    COMMENT '대리키',
    DEV_CNT                     NUMBER(18,4)    COMMENT '개발(건) (#4) = [O202] MSTR 개발(건)(인정금액 ÷ 10,000) 월 합.',
    DEV_MEMBERS                 NUMBER(38,0)    COMMENT '개발(명) (#148) = [O202] 그 달 MSTR 개발 인정 행 보유 1/0.',
    STOP_CNT                    NUMBER(18,4)    COMMENT '중단(건) (#35).',
    UNPAID_CNT                  NUMBER(18,4)    COMMENT '미납(건) (#36)',
    ACTIVE_CNT                  NUMBER(18,4)    COMMENT '활동(건) (#37·157) (#37).',
    ACTIVE_MEMBERS              NUMBER(38,0)    COMMENT '활동(명) (#156).',
    ACTIVE_CUM_CNT              NUMBER(18,4)    COMMENT '활동누계(건) (#159). 당해년도 1월~조회월 활동(건) 누계.',
    ACTIVE_CUM_MEMBERS          NUMBER(38,0)    COMMENT '활동누계(명) (#158).',
    INCREASE_CNT                NUMBER(18,4)    COMMENT '증액(건) (#151)',
    INCREASE_MEMBERS            NUMBER(38,0)    COMMENT '증액(명) (#150)',
    DECREASE_CNT                NUMBER(18,4)    COMMENT '감액(건) SUM(감액금액)/10000 (#38)',
    CHURN_CNT                   NUMBER(18,4)    COMMENT '이탈(건) SUM(취소+감액)/10000 (신규#20)',
    STOP_AMT_CNT                NUMBER(18,4)    COMMENT '[O202] 중단(건) (#35) = 그 달 중단 후원사업 약정금액 ÷ 10,000. 공54~57 분자(DEV_CNT 와 같은 단위). STOP_CNT(사건 수)와 다르다.',
    YEAR_START_ACTIVE_CNT       NUMBER(18,4)    COMMENT '연도초 활동회원(건) (#49).',
    YEAR_END_ACTIVE_CNT         NUMBER(18,4)    COMMENT '연도말 활동회원(건) (#50).',
    MONTH_END_ACTIVE_CNT        NUMBER(18,4)    COMMENT '월말활동회원(건) (#52).',
    PREV_MONTH_END_ACTIVE_CNT   NUMBER(18,4)    COMMENT '전월말 활동회원(건) (#53).',
    CAMPAIGN_UNPAID_CNT         NUMBER(18,4)    COMMENT '캠페인별 미납(건) (#83)',
    STATUS_UNPAID_CNT           NUMBER(18,4)    COMMENT '회원상태별 미납(건) (#84)',
    REGULAR_FEE                 NUMBER(18,2)    COMMENT '정기회비(원) (#66)',
    REGULAR_ONETIME_FEE         NUMBER(18,2)    COMMENT '정기회원 일시회비(원) (#67)',
    ONETIME_ONETIME_FEE         NUMBER(18,2)    COMMENT '일시회원 일시회비(원) (#68)',
    PAID_FEE                    NUMBER(18,2)    COMMENT '납입 **총액**(원) = 회비+기부금 (#69·70 단일화) (#69).',
    BILLED_AMT                  NUMBER(18,2)    COMMENT 'BILLED_AMT (#71).',
    PAID_FEE_BILLABLE           NUMBER(18,2)    COMMENT '회비만 납입액(원).',
    UNPAID_BILLED_AMT           NUMBER(18,2)    COMMENT '미납 청구액(원).',
    INBOUND_CALL_CNT            NUMBER(38,0)    COMMENT '인바운드콜수 (overview).',
    TS_CALL_CNT                 NUMBER(38,0)    COMMENT 'TS콜수 (overview) — 비-CRM 별도 입력',
    DEV_TYPE                    VARCHAR         COMMENT '개발구분 (#121). 그 달 개발구분이 하나로 확정될 때만 값. 코드id:MM015.',
    NEW_FLAG                    BOOLEAN         COMMENT '신규 (#32). 최초가입 연도 = 조회년도.',
    INCREASE_FLAG               BOOLEAN         COMMENT '증액 (#33). 그 달 증액 개발 사건 존재.',
    REDONATE_FLAG               BOOLEAN         COMMENT '재후원 (#34). 그 달 재후원 개발 사건 존재.',
    JOIN_DATE                   DATE            COMMENT '최초가입일 (#28) = LEAST(회원 등록일, 최초 개발일, 첫 청구월). 가입 전 월은 NULL.',
    STOP_DATE                   DATE            COMMENT '최종중단일 as-of (#30). 조회월까지의 최대 중단일.',
    AMOUNT_BAND1                VARCHAR         COMMENT '후원금액대1 5만 (#72). 약정 없음 NULL.',
    AMOUNT_BAND2                VARCHAR         COMMENT '후원금액대2 1만 (#73). 약정 없음 NULL.',
    PERIOD_BAND1                VARCHAR         COMMENT '후원기간대1 5년 (#74). 기준일 없음 NULL.',
    PERIOD_BAND2                VARCHAR         COMMENT '후원기간대2 1년 (#75). 기준일 없음 NULL.',
    SPONSOR_MONTHS              NUMBER(9,2)     COMMENT '후원기간(개월) (#127)',
    SPONSOR_YEARS               NUMBER(9,2)     COMMENT '후원기간(년) (#128)',
    PAID_MONTHS                 NUMBER(9,0)     COMMENT '납입개월수 (#129)',
    NEW_EXISTING_FLAG           VARCHAR         COMMENT '신규/기존 구분 (#113). 기준일 없음 NULL.',
    UNPAID_FLAG_EOM             BOOLEAN         COMMENT '월말 미납회원 여부 (#80).',
    AMT_INCREASE_CUM_CNT        NUMBER(38,0)    COMMENT 'AMT_INCREASE_CUM_CNT (#151).',
    AMT_DECREASE_CUM_CNT        NUMBER(38,0)    COMMENT 'AMT_DECREASE_CUM_CNT (#38).',
    PAID_SPONSOR_BIZ_CNT        NUMBER(38,0)    COMMENT 'PAID_SPONSOR_BIZ_CNT.',
    IS_MULTI_PAID_BIZ           BOOLEAN         COMMENT 'IS_MULTI_PAID_BIZ.',
    IS_MULTI_SPONSORSHIP        BOOLEAN         COMMENT '[DEC.',
    HAS_BILLING                 BOOLEAN         NOT NULL COMMENT '결제(billing) 행 존재 여부.',
    DW_SOURCE_SYSTEM            VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS                  TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS                TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    UNPAID_FLAG_BOM             BOOLEAN         COMMENT '월초 미납회원 여부(=전월말 상태) (#80).'
) COMMENT = '회원 월별 스냅샷 팩트. [Grain: MONTH_KEY × MEMBER_DK (1행=1회원월)]. [주의: FACT_MEMBER_FEE와 합산 시 회비 과대계상 위험(형제팩트중복)]. [원천: SILVER.CRM_PAYMENT_BILLING ∪ CRM_MEMBER_DEV/DISCONTINUE].';

-- FACT_MEMBER_EVENT — 회원 생애주기 전이 팩트
--   ⚠️ ORG_SK 는 DEV 사건 전용 배선 — STOP 행은 0(부서별 중단건을 이 축으로 내지 않는다).
--   ⚠️ SPONSORSHIP_SK(STOP) = 중단일 기준 중단 후원사업 1건 귀속(다중사업이면 시작월 최신 → 최근 후원 · DEC-59) · 미매칭만 0.
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_EVENT (
    DATE_SK             NUMBER(8,0)     NOT NULL COMMENT '사건일',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '상태전이 대상 회원 (불변키)',
    EVENT_TYPE          VARCHAR         NOT NULL COMMENT 'EVENT_TYPE.',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '후원사업 (FK→DIM_SPONSORSHIP)',
    ORG_SK              NUMBER(38,0)    COMMENT '대리키',
    REASON_SK           NUMBER(38,0)    COMMENT '중단/미납 사유 (FK→DIM_REASON)',
    DVLP_DIV_CD         VARCHAR         COMMENT '개발구분코드. 코드id:MM015.',
    DVLP_DIV_NM         VARCHAR         COMMENT '개발구분명. 코드id:MM015.',
    SPNSR_AMT           NUMBER(18,0)    COMMENT '후원금액(원) (#38).',
    DEV_CNT             NUMBER(18,4)    COMMENT '개발(건) (#149) = [O202 사용자 결정] MSTR 정의: 사건의 MSTR 인정금액 ÷ 10,000(신규·재후원 = 미중단 후원사업·월합>0 · 증액 = 감액 상계 순증액). 원본 FN_MM_SPNSR_DVLP B1·B2.',
    DEV_MEMBERS         NUMBER(38,0)    COMMENT '「명」이 아니다 (#148) — [O202] MSTR 개발 인정 행이면 1 · 기간 개발(명) = COUNT DISTINCT 회원.',
    STOP_CNT            NUMBER(18,4)    COMMENT '중단(건) (#35)',
    STOP_MEMBERS        NUMBER(38,0)    COMMENT '「명」이 아니다.',
    UNPAID_STOP_CNT     NUMBER(18,4)    COMMENT '미납중단(건)',
    UNPAID_STOP_MEMBERS NUMBER(38,0)    COMMENT '미납중단(명).',
    JOIN_DATE           DATE            COMMENT '가입일',
    STOP_DATE           DATE            COMMENT '중단일',
    STOP_REASON         VARCHAR         COMMENT '중단사유',
    STOP_CHANNEL        VARCHAR         COMMENT '중단채널',
    STOP_REASON_NM      VARCHAR         COMMENT '중단사유명 (#162). 코드id:MM005.',
    STOP_CHANNEL_NM     VARCHAR         COMMENT '중단경로명. 코드id:MM287.',
    NEW_EXISTING_FLAG   VARCHAR         COMMENT '신규기존 (#113). 사건연도 = 최초가입연도 신규. 기준일 없음 NULL.',
    AGE_AT_EVENT        NUMBER(2,0)     COMMENT '연령대 코드 raw. 코드id:CM014.',
    AGE_BAND_AT_EVENT   VARCHAR         COMMENT '연령대명. 코드id:CM014.',
    AREA_CD_AT_EVENT    VARCHAR(10)     COMMENT '지역 코드 raw (#131). 코드id:CM018. [사유:부서차원 산출불가]',
    REGION_AT_EVENT     VARCHAR         COMMENT '지역명 (#131). 코드id:CM018.',
    SEX_AT_EVENT        VARCHAR         COMMENT '성별 코드 raw. 코드id:CM013.',
    GENDER_AT_EVENT     VARCHAR         COMMENT '성별명. 코드id:CM013.',
    CAMPAIGN_STOP_CNT   NUMBER(18,4)    COMMENT '캠페인 귀속 중단(건). 코드id:MM015.',
    MBER_INFLOW_PATH_CD_AT_EVENT NUMBER(10,0) COMMENT '개발인입경로코드(MM293). 코드id:MM293.',
    MBER_INFLOW_PATH_NM_AT_EVENT VARCHAR      COMMENT '개발인입경로명(MM293 라벨). 코드id:MM293.',
    CMPGN_CTGR_CD_AT_EVENT       NUMBER(10,0) COMMENT '캠페인 카테고리코드(MM294). 코드id:MM294.',
    CMPGN_CTGR_NM_AT_EVENT       VARCHAR      COMMENT '캠페인 카테고리명(MM294 라벨, 현업 ''주요캠페인'' 축). 코드id:MM294.',
    CMPGN_TYPE1_BSN_AT_EVENT     NUMBER(10,0) COMMENT '캠페인 유형1 코드(MM295, 국내/통합/해외). 코드id:MM295.',
    CMPGN_TYPE1_NM_AT_EVENT      VARCHAR      COMMENT '캠페인 유형1명(MM295 라벨: 국내/통합/해외). 코드id:MM295.',
    CMPGN_TYPE2_BSN_AT_EVENT     NUMBER(10,0) COMMENT '캠페인 유형2 코드(MM296, 굿즈/기타/사례/사업). 코드id:MM296.',
    CMPGN_TYPE2_NM_AT_EVENT      VARCHAR      COMMENT '캠페인 유형2명(MM296 라벨: 굿즈/기타/사례/사업). 코드id:MM296.',
    MKTG_CMPGN_CD_AT_EVENT       NUMBER(10,0) COMMENT 'MKTG_CMPGN_CD_AT_EVENT.',
    MKTG_CMPGN_NM_AT_EVENT       VARCHAR      COMMENT '마케팅 캠페인명(Q16 라벨).',
    CMMN_BRND_AT_EVENT           NUMBER(10,0) COMMENT 'MM297 공통브랜드 코드. 코드id:MM297.',
    CMMN_BRND_NM_AT_EVENT        VARCHAR      COMMENT 'MM297 공통브랜드명. 코드id:MM297.',
    MKTG_UTM_AT_EVENT            NUMBER(10,0) COMMENT 'UTM 코드(TC_MKTNG_DTL_CD U001).',
    MKTG_UTM_NM_AT_EVENT         VARCHAR      COMMENT 'UTM 라벨(TC_MKTNG_DTL_CD U001).',
    MKTG_CHANNEL_AT_EVENT        NUMBER(10,0) COMMENT '마케팅 채널 코드 — 사건 시점 동결값.',
    MKTG_CHANNEL_NM_AT_EVENT     VARCHAR      COMMENT '마케팅 채널명 — 사건 시점 동결값.',
    SPNSR_DIV_CD_AT_EVENT        VARCHAR      COMMENT '후원구분 코드(CM035: 1=정기후원·2=일시후원). 코드id:CM035.',
    SPNSR_DIV_NM_AT_EVENT        VARCHAR      COMMENT '후원구분명(CM035 라벨). 코드id:CM035.',
    CPR_DIV_CD_AT_EVENT          VARCHAR      COMMENT '법인구분 코드(CM019: A=통합·I=사단·S=사복). 코드id:CM019.',
    CPR_DIV_NM_AT_EVENT          VARCHAR      COMMENT '법인구분명(CM019 라벨). 코드id:CM019.',
    BRAND_AT_EVENT               VARCHAR      COMMENT '브랜드명 — 사건 시점 동결값. 중단원천 행은 NULL',
    PARENT_CAMPAIGN_NAME_AT_EVENT VARCHAR     COMMENT '상위캠페인명(UPPER_CMPGN_CD 자기조인 라벨).',
    PROMO_METHOD_NAME_AT_EVENT   VARCHAR      COMMENT '홍보방법명(CM008 라벨). 코드id:CM008.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 생애주기 전이 팩트. [Grain: DATE_SK × MEMBER_DK × EVENT_TYPE (1행=1상태전이)]. [주의: 개발(신규/증액/재후원)과 중단 사건의 통합 이력]. [원천: SILVER.CRM_MEMBER_DEV ∪ CRM_MEMBER_DISCONTINUE].';

-- FACT_TARGET_MEMBER_DEV — 회원개발 부문 목표 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_TARGET_MEMBER_DEV (
    MONTH_KEY           NUMBER(6,0)     NOT NULL COMMENT '월 conform 키 YYYYMM.',
    ORG_SK              NUMBER(38,0)    NOT NULL COMMENT '대리키',
    DEV_TYPE            VARCHAR         NOT NULL COMMENT '개발구분(#121 conform) (#121).',
    GOAL_CNT            NUMBER(18,4)    COMMENT 'GOAL_CNT (#3).',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원개발 부문 목표 팩트. [Grain: MONTH_KEY × ORG_SK × DEV_TYPE (1행=1목표)]. [주의: 부서별 신규/증액/재후원 목표 관리]. [원천: CRM → BRONZE_CRM.TM_CM_MBER_DVLP_GOAL → SILVER.CRM_DEV_TARGET].';

-- FACT_TARGET_PROJECT — 사업/프로젝트 목표 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_TARGET_PROJECT (
    MONTH_KEY           NUMBER(6,0)     NOT NULL COMMENT '월 conform 키 YYYYMM.',
    ORG_SK              NUMBER(38,0)    NOT NULL COMMENT '조직 (FK→DIM_ORG)',
    SPONSORSHIP_SK      NUMBER(38,0)    NOT NULL COMMENT '후원사업 (FK→DIM_SPONSORSHIP)',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    ANNUAL_GOAL_CNT     NUMBER(18,4)    COMMENT '당초 목표값(#152). 🔴 단위는 GOAL_TYPE_NM 에 따른다(건·명·원·비율) — 유형 필터 없이 합산 금지',
    SUPP_GOAL_CNT       NUMBER(18,4)    COMMENT '추경목표(건) (#153)',
    ANNUAL_CUM_GOAL_CNT NUMBER(18,4)    COMMENT '연사업누계목표(건) (#154)',
    SUPP_CUM_GOAL_CNT   NUMBER(18,4)    COMMENT '추경누계목표(건) (#155)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    GOAL_TYPE_NM        VARCHAR         COMMENT '목표 지표 유형 원천 표기 그대로(O190 · 9종): 건 = 후원사업·회원개발 / 명 = 월말활동회원 / 원 = 정기회비 / 비율 = 후원사업활동율·신규기존활동율·후원사업납입율·신규기존납입율·신규기존누계납입율. 🔴 유형마다 단위가 달라 섞어 합산하지 말 것 · 후원사업과 회원개발은 같은 개발 목표의 다른 분해(문서20 N-24)',
    CPR_DIV_NM          VARCHAR         COMMENT '법인구분 (사단/사복)',
    SRC_TEAM_NM          VARCHAR          COMMENT '원천 목표표의 팀명 (CRM_BIZ_TARGET.ORG_NM 그대로)',
    SRC_SPONSOR_BIZ_NM   VARCHAR          COMMENT '원천 후원사업 표기 그대로 — 후원사업 유형 = 사업명 · 회원개발 유형 = 4그룹(국내/결연/해외프로젝트/기타)',
    NEW_OLD_DIV_NM       VARCHAR          COMMENT '신규/기존 구분 원천 표기. 🔴 비율 유형에는 소계 행(합계·신규합계)이 있다 — 신규/기존과 함께 합산하면 이중계상. 회원개발 유형은 NULL',
    ORG_DIV_NM           VARCHAR          COMMENT '조직 구분명 (원천 그대로)',
    DTL_DIV_NM           VARCHAR          COMMENT '세부구분 원천 표기(채널 등 · 회원개발 유형만 · 그 외 NULL)'
) COMMENT = '사업/프로젝트 목표 팩트. [Grain: MONTH_KEY × ORG_SK × SPONSORSHIP_SK × CAMPAIGN_SK × GOAL_TYPE_NM × CPR_DIV_NM]. [주의: GOAL_TYPE_NM 으로 반드시 필터(9종 · 단위 상이 · 후원사업·회원개발 합산 금지)]. [원천: CRM TM_CM_MBER_DVLP_GOAL_DIV → SILVER.CRM_BIZ_TARGET].';

-- FACT_MESSAGE_DISPATCH — 메시지 발송 및 결과 팩트
--   ⚠️ SEND_STATUS 는 채널별 코드체계가 한 컬럼에 섞여 있다 — SEND_TYPE 동반 필수.
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH (
    DATE_SK                     NUMBER(8,0)     NOT NULL COMMENT '발송일',
    MEMBER_DK                   VARCHAR(10)     NOT NULL COMMENT '발송 대상 회원 (불변키)',
    SERVICE_SK                  NUMBER(38,0)    NOT NULL COMMENT '발송 서비스 유형 (FK→DIM_SERVICE)',
    CAMPAIGN_SK                 NUMBER(38,0)    NOT NULL COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    SEND_MEMBERS                NUMBER(38,0)    COMMENT '「명」이 아니다 (#85).',
    SUCCESS_MEMBERS             NUMBER(38,0)    COMMENT '성공수(명) (#86). 코드id:MS282. [사유:산출보류]',
    FAIL_MEMBERS                NUMBER(38,0)    COMMENT '실패수(명) (#87). [사유:산출보류]',
    OPEN_MEMBERS                NUMBER(38,0)    COMMENT '오픈(명) (overview · SND_MEMBER_OPEN_LOG 축약).',
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
    SEND_TITLE                  VARCHAR         COMMENT '제목(#136)',
    SEND_STATUS                 VARCHAR         COMMENT '발송상태(#138)',
    -- 🗑 [2026-10-06 O202-C · 사용자 결정 처분 ①] SEND_STATUS2 제거 — 발송상태2 = SEND_RESULT_CD·SEND_RESULT_NAME(축B).
    SEND_TYPE                   VARCHAR         COMMENT '발송유형.',
    MAIL_RECEIVE_FLAG           BOOLEAN         COMMENT '메일수신여부. [사유:원천 미보유]',
    MEMBER_STOP_FLAG            BOOLEAN         COMMENT '결연회원 중단여부. [사유:원천 미보유]',
    SEND_TYPE_SK                NUMBER(38,0)    COMMENT '대리키',
    DW_SOURCE_SYSTEM            VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS                  TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS                TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    SEND_STATUS_GROUP   VARCHAR(10)     COMMENT 'SEND_STATUS_GROUP. 코드id:MS282.',
    SEND_STATUS_NAME    VARCHAR         COMMENT '축A 라벨 (CRM_CODE 조인).',
    SEND_RESULT_CD      VARCHAR(10)     COMMENT '축B(통신사 결과) 코드 raw.',
    SEND_RESULT_GROUP   VARCHAR(10)     COMMENT '축B 코드군 ID. 코드id:MS283.',
    SEND_RESULT_NAME    VARCHAR         COMMENT 'SEND_RESULT_NAME.',
    FRST_BRND_CD         VARCHAR          COMMENT '발송 시점 최초 브랜드 코드 ← SILVER.CRM_SEND_MEMBER',
    FRST_BRND_NM         VARCHAR          COMMENT '발송 시점 최초 브랜드명 ← SILVER.CRM_SEND_MEMBER',
    LST_BRND_CD          VARCHAR          COMMENT '발송 시점 최종 브랜드 코드 ← SILVER.CRM_SEND_MEMBER',
    LST_BRND_NM          VARCHAR          COMMENT '발송 시점 최종 브랜드명 ← SILVER.CRM_SEND_MEMBER',
    CURRENT_BRND         VARCHAR          COMMENT '현재 브랜드 ← SILVER.CRM_SEND_MEMBER',
    ALTRTV_MSG_SNDNG_YN    VARCHAR(1)      COMMENT '대체문자 발송 여부 [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS]',
    RELATNSP_KEY           NUMBER(19,0)    COMMENT '결연KEY [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.TD_MS_PSTMTR_SNDNG_DTL · BRONZE_CRM.SND_MEMBER_LIST]',
    MNG_NO                 VARCHAR(7)      COMMENT '관리번호 [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.TD_MS_PSTMTR_SNDNG_DTL]',
    MSG_KEY                VARCHAR(255)    COMMENT '메세지키 [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.SND_MEMBER_LIST]',
    CINFO                  VARCHAR(255)    COMMENT '알림톡구분 [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.SND_MEMBER_LIST]',
    RESPONSED_YN           VARCHAR(255)    COMMENT '발송확인여부 [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.SND_MEMBER_LIST]',
    RESPONSED_DT           TIMESTAMP_NTZ   COMMENT '확인일시 [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.SND_MEMBER_LIST]',
    REAL_SEND_DT           TIMESTAMP_NTZ   COMMENT '실제발신일시 [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.SND_MEMBER_LIST]',
    SEND_REQUEST_SK        NUMBER(38,0)    COMMENT '발송 요청 (FK→DIM_SEND_REQUEST) · 0=요청 미매칭 [O196-D DEC-58]'
) COMMENT = '메시지 발송 및 결과 팩트. [Grain: DATE_SK × MEMBER_DK × SERVICE_SK × CAMPAIGN_SK (1행=1발송)]. [주의: 이메일/문자/알림톡/우편 발송 성공·실패 이력]. [원천: CRM → SILVER.CRM_SEND_MEMBER/REQUEST].';

-- FACT_BIGQUERY_BEHAVIOR — BigQuery 웹/앱 사용자 행동 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR (
    DATE_SK                         NUMBER(8,0)     NOT NULL COMMENT '행동 발생일 YYYYMMDD (FK→DIM_DATE)',
    IDENTITY_SK                     NUMBER(38,0)    NOT NULL COMMENT '대리키',
    BIGQUERY_EVENT_SK               NUMBER(38,0)    NOT NULL COMMENT 'BigQuery 이벤트 분류 (FK→DIM_BIGQUERY_EVENT)',
    BIGQUERY_SOURCE_SK              NUMBER(38,0)    NOT NULL COMMENT '유입 트래픽소스 (FK→DIM_BIGQUERY_SOURCE)',
    DEVICE_SK                       NUMBER(38,0)    NOT NULL COMMENT '접속 디바이스 (FK→DIM_DEVICE)',
    CAMPAIGN_SK                     NUMBER(38,0)    NOT NULL COMMENT '대리키',
    PAGE_PATH                       VARCHAR         NOT NULL COMMENT '페이지경로 (#105).',
    PAGE_LOCATION                   VARCHAR         COMMENT '페이지위치 (#106).',
    VISITS                          NUMBER(38,0)    COMMENT '방문수(명) (#92).',
    EVENT_CNT                       NUMBER(38,0)    COMMENT '이벤트수(명) (#95).',
    VIEW_CNT                        NUMBER(38,0)    COMMENT '조회수(명) (#96).',
    SESSION_CNT                     NUMBER(38,0)    COMMENT '세션수(명) (#97).',
    ENGAGED_SESSIONS                NUMBER(38,0)    COMMENT '참여세션수.',
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
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    UTM_CAMPAIGN        VARCHAR         COMMENT 'UTM 캠페인 원값(SILVER.BIGQUERY_EVENT.UTM_CAMPAIGN 그대로 · 차원 없음). 🔴 캠페인 키가 아니다 — 1 UTM 이 다수 캠페인에 걸려 CAMPAIGN_SK 로 조인하면 팬아웃한다(문서20 W-1) · (not set)·(organic) 등 비캠페인 값 포함'
) COMMENT = 'BigQuery 웹/앱 사용자 행동 팩트. [Grain: DATE_SK × IDENTITY_SK × EVENT/SOURCE/DEVICE × PAGE × UTM_CAMPAIGN (1행=1행동)]. [주의: 비가산 지표(활성사용자/이탈률) 단순 합산 금지]. [원천: BIGQUERY → SILVER.BIGQUERY_EVENT]. [적재: 롤링 윈도우 증분 — 창 [오늘-bigquery_lookback_days, 9999-12-31] 만 DELETE 후 재적재(멱등). 원천은 지연도착 종료 후 동결(freeze)돼 입고되므로 lookback 은 지연도착 방어가 아니고 실제 역할은 부분적재·중단 run 의 재처리다. 지연도착 재처리 요건이 생기면 dbt_project.yml vars.bigquery_lookback_days 값만 올려 대응 가능하다(개념 구현 상주 · 현재 3). 창보다 오래 run 을 건너뛴 구멍은 OPS.WARN_BIGQUERY_LOAD_GAP 이 감시한다].';

-- FACT_AD_PERFORMANCE — 광고 성과 코어 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE (
    AD_PERF_DK          VARCHAR(32)     NOT NULL PRIMARY KEY COMMENT '불변 비즈니스 식별자',
    PERF_DATE_SK        NUMBER(8,0)     NOT NULL COMMENT '실적일 (분석축, FK→DIM_DATE)',
    CAMPAIGN_SK         NUMBER(38,0)    NOT NULL COMMENT '대리키',
    AD_CREATIVE_SK      NUMBER(38,0)    NOT NULL COMMENT '대리키',
    DEVICE_SK           NUMBER(38,0)    NOT NULL COMMENT '대리키',
    AD_COST             NUMBER(18,2)    COMMENT '광고비(원) . 원천별 컬럼 상이 (#6).',
    IMPRESSIONS         NUMBER(38,0)    COMMENT '노출수 . DIGITAL 전용 (#23). [사유:원천 부재]',
    CLICKS              NUMBER(38,0)    COMMENT 'CLICKS (#24).',
    INBOUND_CALL        NUMBER(38,0)    COMMENT 'INBOUND_CALL (#25).',
    AGENCY_CONV_MEMBERS NUMBER(38,0)    COMMENT '대행사 전환수(명).',
    AGENCY_CONV_CNT     NUMBER(18,4)    COMMENT '대행사 전환수(건/VU).',
    DAY_OF_WEEK         VARCHAR         COMMENT '요일 (degen, AD_DATE 파생)',
    WEEK_OF_YEAR        NUMBER(2,0)     COMMENT '주차 (degen, AD_DATE 파생)',
    AD_SOURCE_TYPE             VARCHAR         COMMENT 'AD_SOURCE_TYPE.',
    MKTG_CAMPAIGN_SK    NUMBER(38,0)    COMMENT '대리키 (PK)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
    ,
    CONTENTS_PUR_COST   NUMBER(38,4)    COMMENT '콘텐츠구입비(원) (REBROADCAST 전용 · 그 외 원천 개념 부재 NULL)',
    CALL_CTR_OPER_COST  NUMBER(38,4)    COMMENT '콜센터운영비(원) (REBROADCAST 전용 · 그 외 원천 개념 부재 NULL)',
    TOT_COST            NUMBER(38,4)    COMMENT '총비용(원) = 편성비(AD_COST)+콘텐츠구입비+콜센터운영비 (REBROADCAST 전용 · 그 외 NULL)'
) COMMENT = '광고 성과 코어 팩트. [Grain: AD_PERF_DK (1행=1광고집행)]. [주의: 디지털/방송 3원천 공통 지표(비용/노출/클릭)]. [원천: AGENCY 3소스 → SILVER.AGENCY_AD_PERFORMANCE].';

-- FACT_AD_BROADCAST — 방송광고 성과 위성 팩트
--   ⚠️ 코어와 1:1(AD_PERF_DK) · NULL = 두 방송 원천 중 한쪽 전용 속성(결측 아님).
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_AD_BROADCAST (
    AD_PERF_DK          VARCHAR(32)     NOT NULL PRIMARY KEY COMMENT '코어 1:1 조인키(GRAIN·PK, FK→FACT_AD_PERFORMANCE). staging 발급값 승계 — 재계산 금지',
    TIME_BAND           VARCHAR         COMMENT '시간대 ← VIDEO.TIME_RNG / REBRDC.TIME_RNG_DIV_NM(1순위)·BRDC_TIME(대체). 코어에서 이관(종전 CAST(NULL) 하드코딩)',
    CM_POSITION         VARCHAR         COMMENT 'CM위치 ← VIDEO.CM_AREA [VIDEO 전용]. 코어에서 이관',
    RT_TYPE             VARCHAR         COMMENT 'RT(재방송)유형 ← REBRDC.DIV_NM(재송출/방송',
    AD_START_TIME       VARCHAR         COMMENT '광고시작시간 ← VIDEO.AD_STRT_TIME [VIDEO 전용]. 코어에서 이관',
    AD_END_TIME         VARCHAR         COMMENT '광고종료시간 ← VIDEO.AD_END_TIME [VIDEO 전용]. 신규 노출',
    BROADCAST_DATE      DATE            COMMENT '송출일 ← VIDEO.BRDC_DATE / REBRDC.DATE. ⚠️코어 PERF_DATE_SK(실적일)와 구분. 코어에서 이관',
    PROGRAM_NM          VARCHAR         COMMENT '프로그램/편성명 ← VIDEO.SCHDL_NM / REBRDC.BRDC_NM',
    CHANNEL_COMPANY     VARCHAR         COMMENT '채널사 ← VIDEO.CHNNL_NM / REBRDC.CHNNL_CMPNY',
    CHANNEL_COMPANY_TYPE VARCHAR        COMMENT '채널사유형 ← VIDEO.CHNNL_CMPNY_TY_NM [VIDEO 전용]',
    SPOT_TYPE           VARCHAR         COMMENT 'SPOT유형 ← VIDEO.SPOT_TY [VIDEO 전용]',
    DURATION_SEC        NUMBER(9,0)     COMMENT '🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지(O29)**. 적재값이 초로 읽을 수 없는 크기라 「초」로 해석하면 오답이다(µs 해석 유력하나 미확정·현업 확인 대기 · 실측값은 문서10 §26). 원천 HH:MM:SS 표기가 캐스팅에서 무성 소실 → 유효 커버리지와 파싱 시 회복률은 문서10 §26. REBRDC NULL 은 결손 아니라 원천 부재',
    DAY_DIV             VARCHAR         COMMENT '요일구분 평일/주말 ← VIDEO.DAY_DIV_NM [VIDEO 전용]',
    PRG_START_TIME      VARCHAR         COMMENT '프로그램 시작시간 ← VIDEO.PRG_STRT_TIME [VIDEO 전용]',
    CTV_DIV             VARCHAR         COMMENT 'CTV구분 ← VIDEO.CTV_DIV_NM [VIDEO 전용]',
    BRDC_DIV            VARCHAR         COMMENT '방송구분 ← REBRDC.BRDC_DIV_NM [REBRDC 전용]',
    AD_CNT              NUMBER(38,0)    COMMENT '광고횟수 ← VIDEO·REBRDC.AD_CNT (가산)',
    CONV_CALL_CNT       NUMBER(18,4)    COMMENT '전환콜 ← VIDEO.CONV_CALL_CNT [VIDEO 전용]. 코어 INBOUND_CALL(인입콜)과 별개 measure',
    DVLP_MEMBER_CNT     NUMBER(18,4)    COMMENT '개발회원수 ← REBRDC.DVLP_MBER_CNT [VIDEO·REBRDC · O185 정정: O182 원천 재편 후 VIDEO 도 일부 행 보고 · 출처별 집계]. ⚠️O16 이관: 종전 코어 AGENCY_CONV_MEMBERS 로 혼입(대행사 전환이 아니라 재방송 개발실적). ⚠️소수 척도 유지 이유: 원천에 0.5 단위 값이 실존해 NUMBER(38,0) 은 반올림으로 총합을 왜곡한다(해당 행·왜곡 규모는 문서10 §26). 원천값 보존 우선',
    DVLP_CNT            NUMBER(18,4)    COMMENT '개발건수 ← REBRDC.DVLP_CNT [VIDEO·REBRDC · O185 정정: O182 원천 재편 후 VIDEO 도 일부 행 보고 · 출처별 집계]. ⚠️O16 이관: 종전 코어 AGENCY_CONV_CNT 로 혼입(대행사 전환 아님)',
    AD_VIEW_RT_SRC      NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 광고시청률 ← VIDEO.AD_VIEW_RT [VIDEO 전용]. base 부재로 DW 재계산 불가',
    CPC_CALL_SRC       NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 **콜당** 단가 ← VIDEO.CPC(TEXT) [VIDEO 전용]. 🔴 클릭 분모가 아니다 — 디지털 CPC_CLICK_SRC 와 합산 금지 (O174 개명)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '방송광고 성과 위성 팩트. [Grain: AD_PERF_DK (코어 1:1)]. [주의: TV/케이블 방송 송출 고유 속성]. [원천: AGENCY → SILVER.AGENCY_AD_BROADCAST].';

-- FACT_AD_DIGITAL — 디지털광고 성과 위성 팩트
--   ⚠️ 코어와 1:1(AD_PERF_DK) · _SRC 컬럼 = 대행사 계산값(비율·단가) — 재합산 금지.
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_AD_DIGITAL (
    AD_PERF_DK          VARCHAR(32)     NOT NULL PRIMARY KEY COMMENT '코어 1:1 조인키(GRAIN·PK, FK→FACT_AD_PERFORMANCE). staging 발급값 승계 — 재계산 금지',
    PAGE_TYPE           VARCHAR         COMMENT '페이지유형 ← DGT.PAGE_TYPE_NM',
    AD_GROUP_NM         VARCHAR         COMMENT '광고그룹명 ← DGT.AD_GRP_NM',
    GROUP_DIV           VARCHAR         COMMENT '그룹구분 ← DGT.GRP_DIV_NM',
    CREATIVE_TYPE       VARCHAR         COMMENT '소재유형 ← DGT.MATR_TY_NM',
    AD_TYPE_NM          VARCHAR         COMMENT '광고유형명(대행사 표기) ← DGT.AD_TY_NM. ⚠️코어 AD_SOURCE_TYPE(원천 출처축 DIGITAL/VIDEO/REBROADCAST)과 다른 개념',
    READ_CNT            NUMBER(38,0)    COMMENT '읽음수 ← DGT.READ_CNT (가산)',
    MEDIA_POTENTIAL_CUST_CNT NUMBER(38,0) COMMENT '매체 잠재고객수 ← DGT.MEDIA_PTNT_CUST_CNT (가산)',
    CRM_DEV_CNT         NUMBER(18,4)    COMMENT 'CRM 개발건수 ← DGT.CRM_DVLP_CNT (가산)',
    CTR_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CTR ← DGT.CTR. DW 재계산=CLICKS/IMPRESSIONS',
    CVR_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CVR ← DGT.CVR. DW 재계산=AGENCY_CONV_MEMBERS/CLICKS (O5 확정)',
    CPC_CLICK_SRC      NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 **클릭당** 단가 ← DGT.CPC. DW 재계산=AD_COST/CLICKS. 🔴 방송 CPC_CALL_SRC 와 합산 금지 (O174 개명)',
    CPM_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CPM ← DGT.CPM. DW 재계산=AD_COST/IMPRESSIONS×1000',
    CPA_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CPA ← DGT.CPA. DW 재계산=AD_COST/AGENCY_CONV_CNT',
    DEV_UNIT_PRICE_SRC  NUMBER(18,2)    COMMENT '[비가산 N] 대행사 산정 개발단가 ← DGT.DEV_UNIT_PRICE. DW 재계산=AD_COST/개발건수',
    VTR_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 VTR ← DGT.VTR. base 부재로 재계산 불가(대조 대상 아닌 유일값)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '디지털광고 성과 위성 팩트. [Grain: AD_PERF_DK (코어 1:1)]. [주의: 매체별 성과 및 대행사 산정 비율 지표]. [원천: AGENCY → SILVER.AGENCY_AD_DIGITAL].';

-- FACT_AD_BROADCAST_CASE — 방송광고 사례 정규화 위성 팩트
--   ⚠️ 코어에 1:N(AD_PERF_DK × CASE_SEQ) — 코어 measure 와 함께 집계하면 사례 수만큼 중복.
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_AD_BROADCAST_CASE (
    AD_PERF_DK          VARCHAR(32)     NOT NULL COMMENT 'GRAIN 1/2 · 코어 조인키(FK→FACT_AD_PERFORMANCE). staging 발급값 승계 — 재계산 금지',
    CASE_SEQ            NUMBER(2,0)     NOT NULL COMMENT 'GRAIN 2/2 · 사례 순번 1~3 (원천 CASE1_*~CASE3_* 언피벗축)',
    BIZ_DIV             VARCHAR         COMMENT '사업구분 ← REBRDC.CASEn_BSNS_DIV_NM',
    FAMILY_TYPE         VARCHAR         COMMENT '가족유형 ← REBRDC.CASEn_FAM_TY_NM',
    APPEAL_POINT        VARCHAR         COMMENT '어필포인트 ← REBRDC.CASEn_APPEAL_POINT_NM',
    CASE_DIV            VARCHAR         COMMENT '사례구분 ← REBRDC.CASEn_CASE_DIV_NM',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (AD_PERF_DK, CASE_SEQ)
) COMMENT = '방송광고 사례 정규화 위성 팩트. [Grain: AD_PERF_DK × CASE_SEQ (1행=1사례)]. [주의: 코어 대비 1:N 조인 팬아웃 주의]. [원천: AGENCY → SILVER.AGENCY_AD_BROADCAST_CASE].';

-- FACT_EVENT_ATTENDANCE — 행사 출석/참여 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_EVENT_ATTENDANCE (
    DATE_SK             NUMBER(8,0)     NOT NULL COMMENT '참여일 YYYYMMDD (FK→DIM_DATE)',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '참여 회원 (불변키)',
    EVENT_SK            NUMBER(38,0)    NOT NULL COMMENT '행사 (FK→DIM_EVENT)',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '대리키',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '대리키',
    TOTAL_CNT           NUMBER(38,0)    COMMENT '총인원.',
    WAIT_CNT            NUMBER(38,0)    COMMENT '대기인원. 코드id:MS006.',
    CANCEL_CNT          NUMBER(38,0)    COMMENT '취소인원. 코드id:MS006.',
    CONFIRM_CNT         NUMBER(38,0)    COMMENT '신청확정인원.',
    PARTICIPATE_CNT     NUMBER(38,0)    COMMENT '참여인원.',
    PARTICIPANT_CNT     NUMBER(38,0)    COMMENT '참여자수.',
    ABSENT_CNT          NUMBER(38,0)    COMMENT '불참인원. 코드id:MS006.',
    PARTICIPATION_TIMES NUMBER(38,0)    COMMENT '참여횟수.',
    WAIT_TIMES          NUMBER(38,0)    COMMENT '대기횟수.',
    ABSENT_TIMES        NUMBER(38,0)    COMMENT '불참횟수.',
    CUM_APPLY_TIMES     NUMBER(38,0)    COMMENT '누적신청 횟수.',
    REGULAR_DONATION    NUMBER(18,2)    COMMENT '정기후원금(원)',
    WIN_FLAG            BOOLEAN         COMMENT '당첨여부',
    SELF_PART_FLAG      BOOLEAN         COMMENT '본인참여 여부. 캠페인행사 자기참여코드(MS060) 파생: 1(본인만)·2(함께)=TRUE · 0(동반자만)=FALSE. 일반행사는 원천 컬럼 부재로 NULL(구조적 부재)',
    PART_STATUS         VARCHAR         COMMENT '참여상태. 코드id:MS304. [사유:규칙 미확정]',
    PART_PATH           VARCHAR         COMMENT '참여경로(05 3-5)',
    PART_CHANNEL        VARCHAR         COMMENT '참여채널(05 3-5)',
    EVENT_BK            VARCHAR         COMMENT '[DEC.',
    PARTCPT_SEQ         NUMBER(38,0)    COMMENT '[DEC.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PART_STATUS_GROUP   VARCHAR(10)     COMMENT 'PART_STATUS_GROUP. 코드id:MS304.',
    PART_STATUS_NAME    VARCHAR         COMMENT '참여상태 라벨 (CRM_CODE 조인). 코드id:MS304.',
    PART_PATH_GROUP     VARCHAR(10)     COMMENT 'PART_PATH_GROUP. 코드id:MS303.',
    PART_PATH_NAME      VARCHAR         COMMENT 'PART_PATH_NAME.',
    PART_CHANNEL_GROUP  VARCHAR(10)     COMMENT 'PART_CHANNEL_GROUP. 코드id:MS302. [사유:원천 부재]',
    PART_CHANNEL_NAME   VARCHAR         COMMENT 'PART_CHANNEL_NAME.',
    EVENT_KIND          VARCHAR(10)     COMMENT '원천 계열 판별 **코드**.',
    EVENT_KIND_NAME     VARCHAR         COMMENT '원천 계열 판별 **라벨**.',
    EVENT_PARTCPT_DIV_CD   VARCHAR(3)      COMMENT '이벤트참여구분코드 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL]',
    RQST_DATE              VARCHAR(8)      COMMENT '신청일자 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    SELF_PARTCPT_CD        VARCHAR(3)      COMMENT '자기참여코드 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    ACMPNY_PARTCPT_CO      NUMBER(10,0)    COMMENT '동반참여수 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    PARTCPT_TIME_CO        NUMBER(10,0)    COMMENT '참여시간수 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    RCPMNY_STAT_CD         VARCHAR(3)      COMMENT '입금상태코드 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    RCPMNY_DATE            VARCHAR(8)      COMMENT '입금일자 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_CRMN_PRTCPNT]',
    REFND_DATE             VARCHAR(8)      COMMENT '환불일자 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_CRMN_PRTCPNT]'
) COMMENT = '행사 출석/참여 팩트. [Grain: DATE_SK × MEMBER_DK × EVENT_SK (1행=1참여)]. [주의: 신청/대기/취소/참석 상태별 집계]. [원천: CRM → SILVER.CRM_EVENT_PARTICIPATION].';

-- FACT_BUDGET — 월 예산 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_BUDGET (
    MONTH_KEY           NUMBER(6,0)     NOT NULL COMMENT '월 conform 키 YYYYMM.',
    ORG_SK              NUMBER(38,0)    NOT NULL COMMENT '조직 (FK→DIM_ORG)',
    BUDGET_ITEM_SK      NUMBER(38,0)    NOT NULL COMMENT '예산 세세목 (FK→DIM_BUDGET_ITEM)',
    BUDGET_PROCEDURE    VARCHAR         COMMENT '예산 편성 차수 (연사업 / 추가경정 · DEC.',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '후원사업 (선택 FK→DIM_SPONSORSHIP)',
    PLAN_BUDGET_MONTH   NUMBER(18,2)    COMMENT '편성예산(월 · 원). 🔴🔴 [2026-08-29 O114-B] 12개월 합산해도 FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR 와 일치하지 않는다 — 원천 원장의 월 배분이 부분적이어서 연 총액의 상당 부분이 월 컬럼에 배분되지 않는다(원천 특성 · 모델 결함 아님 · 실측 규모는 이슈원장·이력 소관 R2-6). ⇒ 🔴 「편성예산」을 답할 때 월·연 중 어느 축인지 밝혀라 — 밝히지 않으면 두 답이 갈린다. 🟢 대비: 집행은 연=월 정합이다(EXEC_BUDGET_ERP 월합 = FACT_BUDGET_YEARLY.EXEC_BUDGET_YEAR). 🔴 예산 편성 차수(「연사업」 / 「추가경정」)를 GROUP BY 에 넣지 않으면 본예산과 추경이 합산된다 — 다만 이 테이블은 BUDGET_PROCEDURE 컬럼을 보유하므로 차수별 분해가 가능하다(2026-09-22 O176 실측 · 규모는 이슈원장 소관 R2-6). ⚠️ WIDE_BUDGET 은 이 컬럼을 노출하지 않으므로 거기서는 분해가 불가능하다 — 「차수별 분해 불가」는 뷰 축의 사실이며 이 테이블에는 적용되지 않는다.',
    EXEC_BUDGET_ERP     NUMBER(18,2)    COMMENT '집행예산(ERP · 월 · 원). 🟢 연=월 정합이다 — 월합 = FACT_BUDGET_YEARLY.EXEC_BUDGET_YEAR(편성과 달리 월 배분 누락이 없다). 🔴 다만 예산 편성 차수(「연사업」/「추가경정」) 취급은 편성과 같다 — BUDGET_PROCEDURE 를 GROUP BY 에 넣지 않으면 본예산과 추경이 합쳐진다(합쳐질 뿐이며 분해는 가능하다).',
    EXEC_BUDGET_EST     NUMBER(18,2)    COMMENT '집행예산(추정 · 원) 🔴🔴 [O51-F 실측] 전건 NULL — 원천 자체가 비어 있다(ERP 집행 추정 원천). 결측이 아니라 대행사가 항목을 보고하지 않는다: 0 이나 「해당없음」 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴 외부 원천 미입고(E-1 소관 · ⚠️ 종전 문안의 E-4 병기는 O175 가 철회했다 — 광고비는 원천 부재가 아니다). 실측 규모는 이슈원장 §O51-F.',
    FUNDRAISING_COST    NUMBER(18,2)    COMMENT '모금성비용(원) 🔴🔴 [O51-F 실측] 전건 NULL — 원천 자체가 비어 있다(ERP 모금성비용 원천). 결측이 아니라 대행사가 항목을 보고하지 않는다: 0 이나 「해당없음」 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴 외부 원천 미입고(E-1 하드블로커) — 모금성비용은 원천 확정 대기다. 실측 규모는 이슈원장 §O51-F.',
    AD_COST             NUMBER(18,2)    COMMENT '광고비(원) 🔴🔴 폐기 슬롯이다 — 의도적 영구 NULL(외부 입고 대기가 아니다 · 2026-09-21 O175 판정). 예산 원장에는 광고비 예산항목이 없고, 대행사 원천의 광고비는 이미 GOLD.FACT_AD_PERFORMANCE.AD_COST 로 일 grain 배선돼 있다. 🔴 광고비를 이 컬럼으로 묻지 말 것 — 정본은 SERVING.SV_AD.TOTAL_AD_COST(base GOLD.WIDE_AD_COMBINED)다. 🔴 예산과 같은 표에 합산하지 말 것(원천·grain 이 다르고 광고 팩트와 이중계상이 된다 · 순서9-K 표 분리 근거). ⚠️ 종전 문안의 「원천 자체가 비어 있다 · 대행사가 항목을 보고하지 않는다」는 거짓이었다(경위·규모는 이슈원장 §O175).',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    EXEC_DIRECT_MNYRS_1 NUMBER(18,2)    COMMENT '직접모금비1(원천 DIRECT_MNYRS_YN_1=Y) 원장행의 집행액(원) — 🔴 모금성비용 **후보 A**(판정 중립). YN_1/YN_2 중 무엇이 모금성비용인지 현업 회신 전이다(문서20 -009) ⇒ FUNDRAISING_COST 로 부르지 말고 두 후보를 병기한다. 부분집합이며 EXEC_BUDGET_ERP 이하',
    EXEC_DIRECT_MNYRS_2 NUMBER(18,2)    COMMENT '직접모금비2(원천 DIRECT_MNYRS_YN_2=Y) 원장행의 집행액(원) — 🔴 모금성비용 **후보 B**(판정 중립 · YN_1 을 포함하는 더 넓은 범위로 보인다). 현업 회신 전이다(문서20 -009)',
    DVLP_INBOUND_PATH   VARCHAR         COMMENT '개발 유입경로(ERP 원천 DVLP_INBOUND_PATH 그대로 · 퇴화 차원 · 2026-10-02 O198 DEC-60). 실측 값 7종(디지털·방송·재송출·영상광고·뉴미디어·모금시스템·콜개발). 🔴 NULL = ERP 원장행에 유입경로가 기재되지 않은 예산(개발 비용이 아닌 과목이 대부분 · 집행액 0) — 창작 라벨로 채우지 않는다(R2-7). 🔴 grain 키의 일부다 — 같은 월·세세목에 경로가 2~3종 있다'
) COMMENT = '월 예산 팩트. [Grain: MONTH_KEY × BUDGET_ITEM_SK × DVLP_INBOUND_PATH (1행=1예산 · 2026-10-02 O198 DEC-60 확장 · 원천 원장 grain 과 일치)]. [주의: 부서/계정별 편성·집행액 관리]. [원천: ERP → BRONZE_ERP.BDGT_ACMSLT_LEDGER → SILVER.ERP_BUDGET].';

-- FACT_BUDGET_YEARLY — 연 예산 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY (
    BUDGET_YEAR         NUMBER(4,0)     NOT NULL COMMENT '예산연도 YYYY.',
    ORG_SK              NUMBER(38,0)    NOT NULL COMMENT '대리키',
    BUDGET_ITEM_SK      NUMBER(38,0)    NOT NULL COMMENT '대리키',
    BUDGET_PROCEDURE    VARCHAR         COMMENT '예산 편성 차수 (연사업 / 추가경정 · DEC.',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '대리키',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '대리키',
    PLAN_BUDGET_YEAR    NUMBER(18,2)    COMMENT 'PLAN_BUDGET_YEAR.',
    CHN_BUDGET_YEAR     NUMBER(18,2)    COMMENT '연 추경예산 = 원천 CHN_BDGT_TOT_AMT.',
    ADJ_BUDGET_YEAR     NUMBER(18,2)    COMMENT '연 조정예산 = 원천 ADJ_BDGT_TOT_AMT.',
    EXEC_BUDGET_YEAR    NUMBER(18,2)    COMMENT '연 집행예산 = 원천 EXEC_TOT_AMT.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '연 예산 팩트. [Grain: YEAR × ORG_SK × BUDGET_ITEM_SK (1행=1연예산)]. [주의: 연 총액 관리 전용(월 팩트와 합산 금지)]. [원천: ERP → SILVER.ERP_BUDGET_YEARLY].';

-- FACT_MEMBER_COHORT — 회원 획득 코호트 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_COHORT (
    MEMBER_DK               VARCHAR(10)     NOT NULL PRIMARY KEY COMMENT '불변 비즈니스 식별자',
    ACQ_CAMPAIGN_SK         NUMBER(38,0)    COMMENT '대리키',
    ACQ_DATE_SK             NUMBER(8,0)     COMMENT '대리키',
    ACQ_BASIS               VARCHAR         COMMENT 'ACQ_BASIS. 코드id:MM015.',
    ACQ_DVLP_DIV_CD         VARCHAR         COMMENT 'ACQ_DVLP_DIV_CD. 코드id:MM015.',
    ACQ_AGE_CD              NUMBER(2,0)     COMMENT '획득 시점 연령대 코드(CM014). 코드id:CM014.',
    ACQ_AGE_BAND            VARCHAR         COMMENT '획득 시점 연령대명(CM014 라벨). 코드id:CM014. [사유:부서차원 산출불가]',
    ACQ_AREA_CD             VARCHAR(10)     COMMENT 'ACQ_AREA_CD. 코드id:CM018.',
    ACQ_REGION              VARCHAR         COMMENT '획득 시점 지역명(CM018 약칭). 코드id:CM018.',
    ACQ_SEX_CD              VARCHAR         COMMENT '획득 시점 성별 코드(CM013). 라벨=ACQ_GENDER. 코드id:CM013.',
    ACQ_GENDER              VARCHAR         COMMENT 'ACQ_GENDER. 코드id:CM013.',
    ACQ_SPNSR_AMT           NUMBER(18,0)    COMMENT '획득 사건의 후원금액 (#38).',
    FIRST_STOP_DATE_SK      NUMBER(8,0)     COMMENT '대리키',
    FIRST_STOP_REASON_NM    VARCHAR         COMMENT '최초 중단의 사유명(MM005 라벨). 미중단 회원은 NULL. 코드id:MM005.',
    TENURE_DAYS             NUMBER(9,0)     COMMENT '유지기간(일) = 최초 중단일 − 획득일.',
    IS_12M_OBSERVABLE       BOOLEAN         COMMENT 'IS_12M_OBSERVABLE.',
    ACQ_MEMBERS             NUMBER(38,0)    COMMENT '획득 회원수.',
    STOPPED_MEMBERS         NUMBER(38,0)    COMMENT '누적 이탈 회원수.',
    STOPPED_12M_MEMBERS     NUMBER(38,0)    COMMENT '12개월 내 이탈 회원수.',
    OBSERVABLE_12M_MEMBERS  NUMBER(38,0)    COMMENT '12개월 이탈률의 분모 회원수.',
    ACQ_ORG_SK              NUMBER(38,0)    COMMENT '대리키 (PK)',
    ACQ_SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '대리키 (PK)',
    ACQ_MBER_INFLOW_PATH_CD NUMBER(10,0)    COMMENT '획득 캠페인의 모집채널 코드(MM293). 코드id:MM293.',
    ACQ_MBER_INFLOW_PATH_NM VARCHAR         COMMENT '획득 캠페인의 모집채널명(MM293 라벨). 코드id:MM293.',
    ACQ_CMPGN_CTGR_CD       NUMBER(10,0)    COMMENT '획득 캠페인의 카테고리 코드(MM294). 코드id:MM294.',
    ACQ_CMPGN_CTGR_NM       VARCHAR         COMMENT 'ACQ_CMPGN_CTGR_NM. 코드id:MM294.',
    ACQ_CMPGN_TYPE1_BSN     NUMBER(10,0)    COMMENT '획득 캠페인 유형1 코드(MM295, 국내/통합/해외). 코드id:MM295.',
    ACQ_CMPGN_TYPE1_NM      VARCHAR         COMMENT '획득 캠페인 유형1명(MM295 라벨: 국내/통합/해외). 코드id:MM295.',
    ACQ_CMPGN_TYPE2_BSN     NUMBER(10,0)    COMMENT '획득 캠페인 유형2 코드(MM296, 굿즈/기타/사례/사업). 코드id:MM296.',
    ACQ_CMPGN_TYPE2_NM      VARCHAR         COMMENT '획득 캠페인 유형2명(MM296 라벨: 굿즈/기타/사례/사업). 코드id:MM296.',
    ACQ_MKTG_CMPGN_CD       NUMBER(10,0)    COMMENT 'ACQ_MKTG_CMPGN_CD.',
    ACQ_MKTG_CMPGN_NM       VARCHAR         COMMENT '획득 캠페인의 마케팅 캠페인명(Q16 라벨).',
    ACQ_CMMN_BRND           NUMBER(10,0)    COMMENT '획득 캠페인의 MM297 공통브랜드 코드. 코드id:MM297.',
    ACQ_CMMN_BRND_NM        VARCHAR         COMMENT '획득 캠페인의 MM297 공통브랜드명. 코드id:MM297.',
    ACQ_MKTG_UTM            NUMBER(10,0)    COMMENT 'ACQ_MKTG_UTM.',
    ACQ_MKTG_UTM_NM         VARCHAR         COMMENT 'ACQ_MKTG_UTM_NM.',
    ACQ_SPNSR_DIV_CD        VARCHAR         COMMENT 'ACQ_SPNSR_DIV_CD. 코드id:CM035.',
    ACQ_SPNSR_DIV_NM        VARCHAR         COMMENT '획득 캠페인의 후원구분명(CM035 라벨). 코드id:CM035.',
    ACQ_CPR_DIV_CD          VARCHAR         COMMENT 'ACQ_CPR_DIV_CD. 코드id:CM019.',
    ACQ_CPR_DIV_NM          VARCHAR         COMMENT '획득 캠페인의 법인구분명(CM019 라벨). 코드id:CM019.',
    ACQ_BRAND               VARCHAR         COMMENT '획득 캠페인의 브랜드명 — 적재 시점 동결값',
    ACQ_PARENT_CAMPAIGN_NAME VARCHAR        COMMENT 'ACQ_PARENT_CAMPAIGN_NAME.',
    ACQ_PROMO_METHOD_NAME   VARCHAR         COMMENT '획득 캠페인의 홍보방법명(CM008 라벨). 코드id:CM008.',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 획득 코호트 팩트. [Grain: MEMBER_DK (1행=1회원)]. [주의: 캠페인별 12개월 고정 이탈률 및 유지기간 정본]. [원천: GOLD.FACT_MEMBER_EVENT].';

-- FACT_MEMBER_FEE — 회비 분해 팩트
--   ⚠️ PK 미선언 — grain 키 FEE_DIV_CD 가 기부금 행에서 NULL. 유일성은 dbt GROUP BY 가 보증.
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_FEE (
    MONTH_KEY           NUMBER(6,0)     COMMENT '월 conform 키 YYYYMM.',
    MEMBER_DK           VARCHAR(10)     COMMENT '불변 비즈니스 식별자',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '대리키 (PK)',
    PAYMENT_SK          NUMBER(38,0)    COMMENT '대리키 (PK)',
    FEE_DIV_CD          VARCHAR         COMMENT '회비구분 코드(PM010). 코드id:PM010.',
    FEE_DIV_NAME        VARCHAR         COMMENT '회비구분명: 정기·선물금·일시·긴급구호 (PM010 라벨). 코드id:PM010.',
    PAYMENT_TYPE        VARCHAR         COMMENT '납입유형 = 회비/기부금.',
    SETLE_CD            VARCHAR         COMMENT 'SETLE_CD.',
    LAST_PAY_DATE_SK    NUMBER(8,0)     COMMENT '대리키',
    LAST_BILL_DATE_SK   NUMBER(8,0)     COMMENT '해당 조합의 최종 청구일 (FK→DIM_DATE)',
    BILLED_AMT          NUMBER(38,2)    COMMENT 'BILLED_AMT.',
    PAID_FEE            NUMBER(38,2)    COMMENT '납입 총액(원) = 회비 + 기부금.',
    PAID_FEE_BILLABLE   NUMBER(38,2)    COMMENT '회비 납입액(원).',
    UNPAID_BILLED_AMT   NUMBER(38,2)    COMMENT '미납 청구액(원).',
    BILLING_ROWS        NUMBER(38,0)    COMMENT '집계된 원천 회비행 수.',
    UNPAID_FLAG         BOOLEAN         COMMENT '해당 조합에 미납 청구행이 하나라도 있는가(BOOLOR_AGG).',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회비 분해 팩트. [Grain: MEMBER_DK × MONTH_KEY × SPONSORSHIP_SK × FEE_DIV × PAYMENT × SETLE (1행=1납입)]. [주의: FACT_MEMBER_MONTHLY와 동일 원천 다른 Grain, 합산 금지]. [원천: CRM → SILVER.CRM_PAYMENT_BILLING].';

-- 🆕 [2026-10-08 O213 Y3-D] FACT_PAYMENT_BILLING_STATUS — 회비 청구 처리 상태 팩트(FACT_MEMBER_FEE 와 grain 이 달라 분리 · O45 선례)
--   ⚠️ PK 미선언 — grain 키 FEE_DIV_CD·RQEST_DIV_CD·PRCS_STAT_CD·RETUN_RSN_CD 가 NULL 일 수 있다. 유일성은 dbt GROUP BY 가 보증.
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_PAYMENT_BILLING_STATUS (
    MONTH_KEY           NUMBER(6,0)     COMMENT '월 conform 키 YYYYMM(회비월 우선 · 납입월 폴백 · 0 = Unknown월 · FACT_MEMBER_FEE 와 같은 규칙).',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '납입 대상 후원사업 대리키(FK→DIM_SPONSORSHIP · 0 = 미매핑).',
    FEE_DIV_CD          VARCHAR         COMMENT '회비구분 코드(PM010). 기부금 행은 원천 NULL. 코드id:PM010.',
    FEE_DIV_NAME        VARCHAR         COMMENT '회비구분명: 정기·선물금·일시·긴급구호 (PM010 라벨). 기부금 행은 NULL.',
    PAYMENT_TYPE        VARCHAR         COMMENT '납입유형 = 회비/기부금.',
    RQEST_DIV_CD        VARCHAR         COMMENT '청구구분 코드(PM024). 코드id:PM024.',
    RQEST_DIV_NAME      VARCHAR         COMMENT '청구구분명(PM024 라벨: 정기청구·OCR신규·개별청구). 원천 코드 Y 는 코드사전에 없어 NULL(2026-10-08 실측 · 현업 확인 대상).',
    PRCS_STAT_CD        VARCHAR         COMMENT '회비 처리상태 코드(PM013). 코드id:PM013.',
    PRCS_STAT_NAME      VARCHAR         COMMENT '회비 처리상태명(PM013 라벨: 청구·완료). 원천 코드 F 는 코드사전에 없어 NULL(2026-10-08 실측 · 현업 확인 대상).',
    RETUN_RSN_CD        VARCHAR         COMMENT '환급사유 코드(PM042). 환급이 아닌 청구행은 원천 NULL. 코드id:PM042.',
    RETUN_RSN_NAME      VARCHAR         COMMENT '환급사유명(PM042 라벨 11종). 환급이 아닌 청구행은 NULL(개념 없음).',
    BILLING_ROWS        NUMBER(38,0)    COMMENT '집계된 원천 청구행 수(건).',
    BILLED_MEMBERS      NUMBER(38,0)    COMMENT '청구 대상 고유 회원수(명). 🔴 비가산 — 다른 축으로 다시 묶어 합하지 않는다.',
    BILLED_AMT          NUMBER(38,2)    COMMENT '청구액(원) = SUM(RQEST_AMT) · FACT_MEMBER_FEE 와 같은 식.',
    PAID_FEE            NUMBER(38,2)    COMMENT '납입 총액(원) = 회비 + 기부금 · FACT_MEMBER_FEE 와 같은 식.',
    UNPAID_BILLED_AMT   NUMBER(38,2)    COMMENT '미납 청구액(원) = 결제상태 F 또는 NULL 인 청구액(DEC-3) · FACT_MEMBER_FEE 와 같은 식.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회비 청구 처리 상태 팩트. [Grain: MONTH_KEY × SPONSORSHIP_SK × FEE_DIV × PAYMENT_TYPE × 청구구분 × 처리상태 × 환급사유]. [주의: 회원 축 없음 · FACT_MEMBER_FEE·FACT_MEMBER_MONTHLY 와 동일 원천 다른 Grain, 합산 금지]. [원천: CRM → SILVER.CRM_PAYMENT_BILLING].';

-- FACT_MEMBER_DEV_ACHIEVEMENT — 회원개발 목표 대비 실적 월 Conform 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_DEV_ACHIEVEMENT (
    MONTH_KEY         NUMBER(6,0)     NOT NULL COMMENT '월 conform 키 YYYYMM.',
    CAL_YEAR          NUMBER(4,0)     COMMENT 'FLOOR(MONTH_KEY/100) — 연도',
    CAL_MONTH         NUMBER(2,0)     COMMENT 'MOD(MONTH_KEY,100) — 월',
    ORG_SK            NUMBER(38,0)    NOT NULL COMMENT '대리키 (PK)',
    ORG_DEPARTMENT    VARCHAR         COMMENT '부서명 (정본 #116) (#116).',
    ORG_DIVISION      VARCHAR         COMMENT 'DIM_ORG.DIVISION. [사유:규칙 미확정]',
    ORG_TEAM          VARCHAR         COMMENT 'DIM_ORG.TEAM. [사유:산출보류]',
    ORG_CORP          VARCHAR         COMMENT 'DIM_ORG.CORP. [사유:부서차원 산출불가]',
    DEV_TYPE          VARCHAR         NOT NULL COMMENT 'DEV_TYPE (#121). 코드id:MM015.',
    DEV_TYPE_NAME     VARCHAR(100)    COMMENT '개발구분명 (MM015 라벨). 코드는 DEV_TYPE',
    GOAL_CNT          NUMBER(18,4)    COMMENT '월 회원개발목표(건).',
    ACTUAL_CNT        NUMBER(18,4)    COMMENT '월 개발실적(건).',
    GOAL_CNT_YTD      NUMBER(18,4)    COMMENT '(누계)월 목표(건).',
    ACTUAL_CNT_YTD    NUMBER(18,4)    COMMENT '(누계)월 실적(건).',
    GOAL_CNT_YEAR     NUMBER(18,4)    COMMENT '연 목표(건) (#3).',
    ACTUAL_CNT_YEAR   NUMBER(18,4)    COMMENT '연 실적(건).',
    HAS_GOAL_ROW      BOOLEAN         COMMENT '목표 **행**의 존재 여부.',
    HAS_POSITIVE_GOAL BOOLEAN         COMMENT '**목표가 실제로 편성됐는지**(GOAL_CNT>0).',
    HAS_ACTUAL        BOOLEAN         COMMENT 'HAS_ACTUAL.',
    DW_SOURCE_SYSTEM  VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (MONTH_KEY, ORG_SK, DEV_TYPE)
) COMMENT = '회원개발 목표 대비 실적 월 Conform 팩트. [Grain: MONTH_KEY × ORG_SK × DEV_TYPE (1행=1달성)]. [주의: 목표(FTG_D) × 실적(FME) FULL OUTER 조인, 달성률은 분모·분자 재계산]. [원천: GOLD.FACT_TARGET_MEMBER_DEV × FACT_MEMBER_EVENT].';

-- FACT_MEMBER_SPONSORSHIP_SPAN — 회원×후원약정 기간 팩트
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN (
    MEMBER_DK         VARCHAR(10)     NOT NULL COMMENT '회원 (불변키). ※비강제 FK→DIM_MEMBER',
    SPNSR_NO          VARCHAR(9)      NOT NULL COMMENT '후원번호(Q15).',
    SPNSR_BSNS_NO     NUMBER(19,0)    NOT NULL COMMENT '후원사업번호(회원별 약정 일련번호, Q15).',
    SPONSORSHIP_SK    NUMBER(38,0)    COMMENT '대리키',
    CAMPAIGN_SK       NUMBER(38,0)    COMMENT '대리키',
    IS_MULTI_CAMPAIGN BOOLEAN         COMMENT '참고용 투명성 플래그.',
    START_MONTH_KEY   NUMBER(6,0)     COMMENT 'START_MONTH_KEY.',
    DSCNTC_MONTH_KEY  NUMBER(6,0)     COMMENT '중단 월키 YYYYMM.',
    SPNSR_AMT         NUMBER(38,0)    COMMENT 'SPNSR_AMT.',
    ACQ_MBER_INFLOW_PATH_CD NUMBER(10,0) COMMENT '대표캠페인의 모집채널 코드(MM293). 코드id:MM293.',
    ACQ_MBER_INFLOW_PATH_NM VARCHAR      COMMENT '대표캠페인의 모집채널명(MM293 라벨) — 동결값',
    ACQ_CMPGN_CTGR_CD       NUMBER(10,0) COMMENT '대표캠페인의 카테고리 코드(MM294). 코드id:MM294.',
    ACQ_CMPGN_CTGR_NM       VARCHAR      COMMENT 'ACQ_CMPGN_CTGR_NM. 코드id:MM294.',
    ACQ_CMPGN_TYPE1_BSN     NUMBER(10,0) COMMENT '대표캠페인 유형1 코드(MM295, 국내/통합/해외). 코드id:MM295.',
    ACQ_CMPGN_TYPE1_NM      VARCHAR      COMMENT '대표캠페인 유형1명(MM295 라벨) — 동결값',
    ACQ_CMPGN_TYPE2_BSN     NUMBER(10,0) COMMENT '대표캠페인 유형2 코드(MM296, 굿즈/기타/사례/사업). 코드id:MM296.',
    ACQ_CMPGN_TYPE2_NM      VARCHAR      COMMENT '대표캠페인 유형2명(MM296 라벨) — 동결값',
    ACQ_MKTG_CMPGN_CD       NUMBER(10,0) COMMENT 'ACQ_MKTG_CMPGN_CD.',
    ACQ_MKTG_CMPGN_NM       VARCHAR      COMMENT '대표캠페인의 마케팅 캠페인명(Q16 라벨) — 동결값',
    ACQ_CMMN_BRND           NUMBER(10,0) COMMENT '대표캠페인의 MM297 공통브랜드 코드. 코드id:MM297.',
    ACQ_CMMN_BRND_NM        VARCHAR      COMMENT '대표캠페인의 MM297 공통브랜드명 — 동결값',
    ACQ_MKTG_UTM            NUMBER(10,0) COMMENT 'ACQ_MKTG_UTM.',
    ACQ_MKTG_UTM_NM         VARCHAR      COMMENT 'ACQ_MKTG_UTM_NM.',
    ACQ_SPNSR_DIV_CD        VARCHAR      COMMENT '대표캠페인의 후원구분 코드(CM035). 코드id:CM035.',
    ACQ_SPNSR_DIV_NM        VARCHAR      COMMENT '대표캠페인의 후원구분명(CM035 라벨) — 동결값',
    ACQ_CPR_DIV_CD          VARCHAR      COMMENT '대표캠페인의 법인구분 코드(CM019). 코드id:CM019.',
    ACQ_CPR_DIV_NM          VARCHAR      COMMENT '대표캠페인의 법인구분명(CM019 라벨) — 동결값',
    ACQ_BRAND               VARCHAR      COMMENT '대표캠페인의 브랜드명 — 동결값',
    ACQ_PARENT_CAMPAIGN_NAME VARCHAR     COMMENT 'ACQ_PARENT_CAMPAIGN_NAME.',
    ACQ_PROMO_METHOD_NAME   VARCHAR      COMMENT '대표캠페인의 홍보방법명(CM008 라벨) — 동결값',
    DW_SOURCE_SYSTEM  VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    SPNSR_JOIN_PATH_CD   VARCHAR(3)       COMMENT '후원(SPNSR_NO) 단위 가입경로 코드 raw. 코드id:MM014',
    SPNSR_JOIN_PATH_NM   VARCHAR(100)     COMMENT '후원 단위 가입경로명. 코드id:MM014',
    SPNSR_CMPGN_CD       VARCHAR(20)      COMMENT '후원(SPNSR_NO) 등록 캠페인코드 raw ← SILVER.CRM_MEMBER_SPONSOR_SPAN.CMPGN_CD · 🔴 대표캠페인(CAMPAIGN_SK · 개발사건 규칙)과 다른 축',
    SPNSR_ACMSLT_DEPT_CD VARCHAR(10)      COMMENT '후원(SPNSR_NO) 실적부서코드 raw ← SILVER.CRM_MEMBER_SPONSOR_SPAN.ACMSLT_DEPT_CD'
) COMMENT = '회원×후원약정 기간 팩트. [Grain: MEMBER_DK × SPNSR_BSNS_NO (1행=1약정)]. [주의: 캠페인별/후원사업별 활동회원 질의 전용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN].';

-- FACT_RELATION_DEV — FACT_RELATION_DEV — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_RELATION_DEV (
    DATE_SK               NUMBER(8,0)      COMMENT '일자 YYYYMMDD → DIM_DATE.DATE_SK(FK 정보성) · 0=일자 무효',
    MEMBER_DK             VARCHAR(10)      COMMENT '회원번호(원천 MBER_NO · degenerate)',
    OCCRRNC_DE            VARCHAR(8)       COMMENT '발생일자 [원천: SILVER.CRM_RELATION_DEV]',
    SER_NO                NUMBER(10,0)     COMMENT '일련번호 [원천: SILVER.CRM_RELATION_DEV]',
    SPNSR_NO              NUMBER(19,0)     COMMENT '후원번호 [원천: SILVER.CRM_RELATION_DEV]',
    SPNSR_BSNS_NO         NUMBER(19,0)     COMMENT '후원사업번호 [원천: SILVER.CRM_RELATION_DEV]',
    SPNSR_AMT             NUMBER(19,0)     COMMENT '후원금액 [원천: SILVER.CRM_RELATION_DEV]',
    BF_STAT_CD            VARCHAR(3)       COMMENT '이전상태코드 [원천: SILVER.CRM_RELATION_DEV]',
    AF_STAT_CD            VARCHAR(3)       COMMENT '이후상태코드 [원천: SILVER.CRM_RELATION_DEV]',
    RELATNSP_DVLP_DIV_CD  VARCHAR(3)       COMMENT '관계개발구분코드 [원천: SILVER.CRM_RELATION_DEV]',
    ACCNUT_STATS_CD       VARCHAR(3)       COMMENT '회계상태코드 [원천: SILVER.CRM_RELATION_DEV]',
    CHILD_STATS_CD        VARCHAR(3)       COMMENT '아동상태코드 [원천: SILVER.CRM_RELATION_DEV]',
    DW_SOURCE_SYSTEM      VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS            TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS          TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID           VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'FACT_RELATION_DEV — O188-F 2차-A 신설. [원천: SILVER.CRM_RELATION_DEV]. [적재: dbt]';

-- FACT_RELATION_CHANGE — FACT_RELATION_CHANGE — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_RELATION_CHANGE (
    DATE_SK           NUMBER(8,0)      COMMENT '일자 YYYYMMDD → DIM_DATE.DATE_SK(FK 정보성) · 0=일자 무효',
    MEMBER_DK         VARCHAR(10)      COMMENT '회원번호 — 결연키로 결연 마스터(CRM_SPONSOR_RELATION)를 조회해 얻은 MBER_NO · 매칭 실패(고아 결연)는 NULL',
    RELATNSP_KEY      NUMBER(10,0)     COMMENT '결연KEY [원천: SILVER.CRM_RELATION_CHANGE]',
    CHG_RELATNSP_KEY  NUMBER(10,0)     COMMENT '교체결연KEY [원천: SILVER.CRM_RELATION_CHANGE]',
    CHG_YN            VARCHAR(1)       COMMENT '교체여부 [원천: SILVER.CRM_RELATION_CHANGE]',
    CHG_RSN_CD        NUMBER(10,0)     COMMENT '교체사유코드 [원천: SILVER.CRM_RELATION_CHANGE]',
    CHG_RST_CD        NUMBER(10,0)     COMMENT '교체결과코드 [원천: SILVER.CRM_RELATION_CHANGE]',
    CHG_PERSON_ID     VARCHAR(20)      COMMENT '교체자ID [원천: SILVER.CRM_RELATION_CHANGE]',
    CHG_DE            DATE             COMMENT '교체일 [원천: SILVER.CRM_RELATION_CHANGE]',
    DW_SOURCE_SYSTEM  VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'FACT_RELATION_CHANGE — O188-F 2차-A 신설. [원천: SILVER.CRM_RELATION_CHANGE]. [적재: dbt]';

-- DIM_SEND_REQUEST — 발송 요청 차원 · O196-D DEC-58 #1 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_SEND_REQUEST (
    SEND_REQUEST_SK         NUMBER(38,0)    NOT NULL COMMENT '대리키 = HASH(SNDNG_KEY) · FACT_MESSAGE_DISPATCH.SEND_REQUEST_SK 가 참조',
    SNDNG_KEY               NUMBER(10,0)    COMMENT '발송키 (PK) [원천: SILVER.CRM_SEND_REQUEST]',
    SEND_CHANNEL            VARCHAR         COMMENT '발송채널 (SND/SMS/EMAIL 등) [원천: SILVER.CRM_SEND_REQUEST]',
    SNDNG_TY_CD             VARCHAR(3)      COMMENT '발송유형코드 [원천: SILVER.CRM_SEND_REQUEST]',
    SEND_GBN_TOP            VARCHAR(255)    COMMENT '발송구분 대분류코드 [원천: SILVER.CRM_SEND_REQUEST]',
    SEND_GBN_TOP_NM         VARCHAR(255)    COMMENT '발송구분 대분류명 [원천: SILVER.CRM_SEND_REQUEST]',
    SEND_GBN_MID            VARCHAR(255)    COMMENT '발송구분 중분류코드 [원천: SILVER.CRM_SEND_REQUEST]',
    SEND_GBN_MID_NM         VARCHAR(255)    COMMENT '발송구분 중분류명 [원천: SILVER.CRM_SEND_REQUEST]',
    SEND_GBN_BOT            VARCHAR(255)    COMMENT '발송구분 소분류코드 [원천: SILVER.CRM_SEND_REQUEST]',
    SEND_GBN_BOT_NM         VARCHAR(255)    COMMENT '발송구분 소분류명 [원천: SILVER.CRM_SEND_REQUEST]',
    TIT                     VARCHAR(100)    COMMENT '발송 제목 [원천: SILVER.CRM_SEND_REQUEST]',
    SNDNG_STDR_DE           TIMESTAMP_NTZ   COMMENT '발송 기준일시 [원천: SILVER.CRM_SEND_REQUEST]',
    REQ_SEQ_NO              NUMBER(19,0)    COMMENT '요청 일련번호 [원천: SILVER.CRM_SEND_REQUEST]',
    SNDNG_CD_ID             VARCHAR(20)     COMMENT '발신코드ID [원천: SILVER.CRM_SEND_REQUEST]',
    SNDNG_DTL_CD_ID         VARCHAR(20)     COMMENT '발신상세코드ID [원천: SILVER.CRM_SEND_REQUEST]',
    PRCS_DE                 TIMESTAMP_NTZ   COMMENT '처리일 [원천: SILVER.CRM_SEND_REQUEST]',
    PRCS_YN                 VARCHAR(1)      COMMENT '처리여부 [원천: SILVER.CRM_SEND_REQUEST]',
    TMPLAT_ID               VARCHAR(255)    COMMENT '템플릿ID [원천: SILVER.CRM_SEND_REQUEST]',
    ALTRTV_MSG_SNDNG_YN     VARCHAR(255)    COMMENT '대체메시지발신여부 [원천: SILVER.CRM_SEND_REQUEST]',
    LQY_YN                  VARCHAR(1)      COMMENT '대량여부 [원천: SILVER.CRM_SEND_REQUEST]',
    RE_SNDNG_YN             VARCHAR(1)      COMMENT '재발신여부 [원천: SILVER.CRM_SEND_REQUEST]',
    MSG_TYPE                VARCHAR(255)    COMMENT '메시지 유형 [원천: SILVER.CRM_SEND_REQUEST]',
    REGULARLY               VARCHAR(255)    COMMENT '발송 유형 (정기/비정기) [원천: SILVER.CRM_SEND_REQUEST]',
    SEND_STATUS             VARCHAR(255)    COMMENT '발송 상태 [원천: SILVER.CRM_SEND_REQUEST]',
    SEND_ROUND              NUMBER(10,0)    COMMENT '발송차수 [원천: SILVER.CRM_SEND_REQUEST]',
    CONDITION_TITLE         VARCHAR(255)    COMMENT '발송 조건 제목 [원천: SILVER.CRM_SEND_REQUEST]',
    MENU_CODE               VARCHAR(255)    COMMENT '메뉴코드 [원천: SILVER.CRM_SEND_REQUEST]',
    SERVICE_MENU_CODE       VARCHAR(100)    COMMENT '서비스메뉴코드 [원천: SILVER.CRM_SEND_REQUEST]',
    USE_YN                  VARCHAR(255)    COMMENT '사용 여부 [원천: SILVER.CRM_SEND_REQUEST]',
    RECPTN_CNT              NUMBER(18,0)    COMMENT '수신건수 [원천: SILVER.CRM_SEND_RESULT]',
    ALTRTV_SNDNG_CNT        NUMBER(18,0)    COMMENT '알림톡대체발송건수 [원천: SILVER.CRM_SEND_RESULT]',
    SNDNG_STRT_DT           TIMESTAMP_NTZ   COMMENT '발신시작일시 [원천: SILVER.CRM_SEND_RESULT]',
    SNDNG_END_DT            TIMESTAMP_NTZ   COMMENT '발신종료일시 [원천: SILVER.CRM_SEND_RESULT]',
    RESVE_SNDNG_DE          DATE            COMMENT '예약발신일 [원천: SILVER.CRM_SEND_RESULT]',
    SNDNG_SQNC              NUMBER(3,0)     COMMENT '발신차수 [원천: SILVER.CRM_SEND_RESULT]',
    SNDNG_TIT               VARCHAR(255)    COMMENT '발신제목 [원천: SILVER.CRM_SEND_RESULT]',
    DW_SOURCE_SYSTEM        VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '발송 요청 차원. [Grain: SNDNG_KEY (1행=1발송요청)]. [주의: 발송×회원 팩트 FACT_MESSAGE_DISPATCH 와 SEND_REQUEST_SK 로 조인 · 요청 속성을 팩트에 degen 하지 않는다(DEC-58)]. [원천: SILVER.CRM_SEND_REQUEST + CRM_SEND_RESULT(1:1)]. [적재: dbt]';

-- FACT_RELATION_ACTIVITY — 결연활동 팩트 · O196-D DEC-58 #2 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_RELATION_ACTIVITY (
    DATE_SK                 NUMBER(8,0)     COMMENT '활동일 YYYYMMDD(서신 = 접수일 · 선물금 = 발송일) → DIM_DATE · 0=일자 무효',
    MEMBER_DK               VARCHAR(10)     COMMENT '회원번호 — 결연키로 결연 마스터(CRM_SPONSOR_RELATION)를 조회한 MBER_NO · 매칭 실패(고아 결연)는 NULL',
    ACTIVITY_KEY            VARCHAR         COMMENT '결연활동 대체키 (PK) [원천: SILVER.CRM_RELATION_ACTIVITY]',
    ACTIVITY_TYPE           VARCHAR         COMMENT '활동유형 파생 (서신/선물금) [원천: SILVER.CRM_RELATION_ACTIVITY]',
    RELATNSP_KEY            NUMBER(10,0)    COMMENT '결연키 (→CRM_SPONSOR_RELATION) [원천: SILVER.CRM_RELATION_ACTIVITY]',
    MNG_NO                  VARCHAR(7)      COMMENT '관리번호 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    ACTIVITY_CNT            NUMBER(1,0)     COMMENT '활동(건) = 1 · 회원수는 MEMBER_DK 중복제거로 센다',
    GFTMNEY                 NUMBER(10,0)    COMMENT '선물금 (원단위) [원천: SILVER.CRM_RELATION_ACTIVITY]',
    LETTER_DIV_CD           NUMBER(10,0)    COMMENT '서신구분코드 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    RCEPT_DE                DATE            COMMENT '접수일자 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    SNDNG_DE                DATE            COMMENT '발송일자 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    LETTER_STAT_CD          NUMBER(3,0)     COMMENT '편지상태코드 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    LANG_CD                 VARCHAR(10)     COMMENT '언어코드 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    ONLINE_POST_WRITNG_YN   VARCHAR(1)      COMMENT '온라인우편작성여부 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    ONLINE_INFLOW_CD        NUMBER(10,0)    COMMENT '온라인유입코드 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    UNREPLY_RSN_CD          NUMBER(10,0)    COMMENT '미답신사유코드 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    MBRFEE_KEY              NUMBER(10,0)    COMMENT '회비KEY [원천: SILVER.CRM_RELATION_ACTIVITY]',
    SETLE_DE                DATE            COMMENT '결제일 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    SETLE_CD                VARCHAR(3)      COMMENT '결제코드 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    GFT_DIV_CD              VARCHAR(3)      COMMENT '선물구분코드 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    GFTMNEY_DOLLAR_AMT      VARCHAR(30)     COMMENT '선물금미화금액 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    APRV_DE                 DATE            COMMENT '승인일 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    TRNSFER_YN              VARCHAR(1)      COMMENT '이관여부 [원천: SILVER.CRM_RELATION_ACTIVITY]',
    DW_SOURCE_SYSTEM        VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '결연활동 팩트(서신·선물금). [Grain: ACTIVITY_KEY (1행=1활동)]. [주의: 선물금(GFTMNEY)은 선물금 행만 값 · 서신/선물금 계열 속성은 비해당 NULL]. [원천: SILVER.CRM_RELATION_ACTIVITY × CRM_SPONSOR_RELATION]. [적재: dbt]';

-- FACT_PAYMENT_METHOD_CHANGE — FACT_PAYMENT_METHOD_CHANGE — O188-F 2차-A 신설
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_PAYMENT_METHOD_CHANGE (
    DATE_SK                   NUMBER(8,0)      COMMENT '일자 YYYYMMDD → DIM_DATE.DATE_SK(FK 정보성) · 0=일자 무효',
    MEMBER_DK                 VARCHAR(10)      COMMENT '회원번호(원천 MBER_NO · degenerate)',
    SETLE_KEY                 NUMBER(10,0)     COMMENT '결제KEY [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    UPDT_DT                   TIMESTAMP_NTZ(9) COMMENT '수정일시 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    CPR_DIV_CD                VARCHAR(3)       COMMENT '법인구분코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    SETLE_CD                  VARCHAR(3)       COMMENT '결제코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    WTDRW_STRT_DE             DATE             COMMENT '출금시작일 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    WTDRW_ASMT_SQNC           NUMBER(3,0)      COMMENT '출금지정차수 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    FNLT_DIV_CD               VARCHAR(3)       COMMENT '금융기관구분코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    FNLT_CD                   VARCHAR(10)      COMMENT '금융기관코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    SETLE_ENTRPS_CD           VARCHAR(10)      COMMENT '결제업체코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    ACNUT_SER_NO              NUMBER(10,0)     COMMENT '계좌일련번호 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    CARD_DIV_CD               VARCHAR(3)       COMMENT '카드구분코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    ETC_CTTPC_REL_CD          VARCHAR(3)       COMMENT '기타연락처관계코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    PAYER_MBER_REL_CD         VARCHAR(3)       COMMENT '결제자회원관계코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    CRTFC_MTH_CD              VARCHAR(3)       COMMENT '인증방법코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    CRTFC_DE                  DATE             COMMENT '인증일 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    FILE_SIZE                 NUMBER(10,0)     COMMENT '파일크기 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    SETLE_STAT_CD             VARCHAR(3)       COMMENT '결제상태코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    BF_SETLE_STAT_CD          VARCHAR(3)       COMMENT '이전결제상태코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    RQST_DIV_CD               VARCHAR(3)       COMMENT '신청구분코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    RCEPT_DIV_CD              VARCHAR(3)       COMMENT '접수구분코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    APRV_YN                   VARCHAR(1)       COMMENT '승인여부 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    APRV_REQUST_KEY           NUMBER(19,0)     COMMENT '승인요청KEY [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    APRV_RST_KEY              NUMBER(19,0)     COMMENT '승인결과KEY [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    FRST_BEGIN_DE             DATE             COMMENT '최초개시일 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    RQEST_EXCL_YN             VARCHAR(1)       COMMENT '청구제외여부 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    RQEST_EXCL_STRT_DE        DATE             COMMENT '청구제외시작일 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    RQEST_EXCL_END_DE         DATE             COMMENT '청구제외종료일 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    APPLCNT_ETC_CTTPC_REL_CD  VARCHAR(3)       COMMENT '신청자기타연락처관계코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    APPLCNT_MBER_REL_CD       VARCHAR(3)       COMMENT '신청자회원관계코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    BF_SETLE_KEY              NUMBER(10,0)     COMMENT '이전결제KEY [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    OPERT_DIV_CD              VARCHAR(3)       COMMENT '작업구분코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    CRTFC_TY_CD               VARCHAR(3)       COMMENT '인증유형코드 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    USE_YN                    VARCHAR(1)       COMMENT '사용여부 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    REGIST_DT                 TIMESTAMP_NTZ(9) COMMENT '등록일시 [원천: SILVER.CRM_PAYMENT_METHOD_HIST]',
    DW_SOURCE_SYSTEM          VARCHAR NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS                TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS              TIMESTAMP_NTZ    COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID               VARCHAR          COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'FACT_PAYMENT_METHOD_CHANGE — O188-F 2차-A 신설. [원천: SILVER.CRM_PAYMENT_METHOD_HIST]. [적재: dbt]';

-- ============================================================================
-- 제약 — PK 보강 · 정보성 FK (NOT ENFORCED · CREATE 전량 뒤에 실행)
-- ============================================================================
--   ⚠️ FK 미선언 축(참조 대상이 비유일) — 조인 경로를 지킨다:
--     · MEMBER_DK → DIM_MEMBER_STATUS_HISTORY(SCD2 다중버전) = IS_CURRENT 또는 유효구간 매칭. 현재행은 DIM_MEMBER.
--     · MONTH_KEY → DIM_MONTH(월 conform). DIM_DATE 직접 조인은 월당 일수만큼 증폭된다.
--     · 이 축의 논리 관계 정본 = scripts/gold_erd_coverage_gate.py 의 LOGICAL_FK.
--   ⚠️ 위성 광고 팩트 → 코어 FACT_AD_PERFORMANCE FK 는 수직 분할이라 선언한다(FAD_B·FAD_D 1:1 · FAD_BC 1:N).

-- 멱등화: 같은 이름 제약을 먼저 지운다(Snowflake 는 DROP CONSTRAINT IF EXISTS 미지원 · 목록 = 아래 ADD 전건)
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
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_TARGET_MEMBER_DEV DROP CONSTRAINT FK_FTG_D_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_TARGET_PROJECT DROP CONSTRAINT FK_FTG_B_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_TARGET_PROJECT DROP CONSTRAINT FK_FTG_B_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_TARGET_PROJECT DROP CONSTRAINT FK_FTG_B_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH DROP CONSTRAINT FK_FSE_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH DROP CONSTRAINT FK_FSE_DIM_SERVICE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH DROP CONSTRAINT FK_FSE_DIM_SEND_TYPE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH DROP CONSTRAINT FK_FSE_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR DROP CONSTRAINT FK_FBQ_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR DROP CONSTRAINT FK_FBQ_DIM_MEMBER_IDENTITY; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR DROP CONSTRAINT FK_FBQ_DIM_BIGQUERY_EVENT; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR DROP CONSTRAINT FK_FBQ_DIM_BIGQUERY_SOURCE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR DROP CONSTRAINT FK_FBQ_DIM_DEVICE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR DROP CONSTRAINT FK_FBQ_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE DROP CONSTRAINT FK_FAD_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE DROP CONSTRAINT FK_FAD_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE DROP CONSTRAINT FK_FAD_DIM_AD_CREATIVE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE DROP CONSTRAINT FK_FAD_DIM_DEVICE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_BROADCAST DROP CONSTRAINT FK_FAD_B_FAD; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_DIGITAL DROP CONSTRAINT FK_FAD_D_FAD; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_BROADCAST_CASE DROP CONSTRAINT FK_FAD_BC_FAD; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_ATTENDANCE DROP CONSTRAINT FK_FEP_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_ATTENDANCE DROP CONSTRAINT FK_FEP_DIM_EVENT; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_ATTENDANCE DROP CONSTRAINT FK_FEP_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_ATTENDANCE DROP CONSTRAINT FK_FEP_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_BUDGET_ITEM; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY DROP CONSTRAINT FK_FBY_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY DROP CONSTRAINT FK_FBY_DIM_BUDGET_ITEM; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY DROP CONSTRAINT FK_FBY_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY DROP CONSTRAINT FK_FBY_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT DROP CONSTRAINT FK_FMC_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT DROP CONSTRAINT FK_FMC_DIM_DATE_ACQ; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT DROP CONSTRAINT FK_FMC_DIM_DATE_STOP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE DROP CONSTRAINT FK_FMF_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE DROP CONSTRAINT FK_FMF_PAYMENT; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE DROP CONSTRAINT FK_FMF_PAY_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE DROP CONSTRAINT FK_FMF_BILL_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT DROP CONSTRAINT FK_FMC_ACQ_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT DROP CONSTRAINT FK_FMC_ACQ_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_CAMPAIGN DROP CONSTRAINT FK_DIM_CAMPAIGN_MKTG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE DROP CONSTRAINT FK_FAP_MKTG_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN DROP CONSTRAINT FK_FMSB_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN DROP CONSTRAINT FK_FMSB_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_BIZ_PLACE DROP CONSTRAINT PK_DIM_BIZ_PLACE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_CHILD DROP CONSTRAINT PK_DIM_CHILD; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_MSG_TEMPLATE DROP CONSTRAINT PK_DIM_MSG_TEMPLATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_MSG_TEMPLATE_BUTTON DROP CONSTRAINT PK_DIM_MSG_TEMPLATE_BUTTON; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_PAYMENT_ACCOUNT DROP CONSTRAINT PK_DIM_PAYMENT_ACCOUNT; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_CHILD DROP CONSTRAINT FK_DCH_DIM_BIZ_PLACE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_MSG_TEMPLATE_BUTTON DROP CONSTRAINT FK_DMTB_DIM_MSG_TEMPLATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_RELATION_DEV DROP CONSTRAINT FK_FRD_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_RELATION_DEV DROP CONSTRAINT FK_FRD_DIM_MEMBER; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_RELATION_CHANGE DROP CONSTRAINT FK_FRC_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_RELATION_CHANGE DROP CONSTRAINT FK_FRC_DIM_MEMBER; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_PAYMENT_METHOD_CHANGE DROP CONSTRAINT FK_FPMC_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_PAYMENT_METHOD_CHANGE DROP CONSTRAINT FK_FPMC_DIM_MEMBER; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.DIM_SEND_REQUEST DROP CONSTRAINT PK_DIM_SEND_REQUEST; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH DROP CONSTRAINT FK_FMD_DIM_SEND_REQUEST; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_RELATION_ACTIVITY DROP CONSTRAINT FK_FRA_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_RELATION_ACTIVITY DROP CONSTRAINT FK_FRA_DIM_MEMBER; EXCEPTION WHEN OTHER THEN NULL; END;
  RETURN 'constraint drop (idempotent) done';
END;
$$;

ALTER TABLE GN_DW.GOLD.DIM_CAMPAIGN ADD CONSTRAINT FK_DIM_CAMPAIGN_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY ADD CONSTRAINT FK_FMM_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY ADD CONSTRAINT FK_FMM_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY ADD CONSTRAINT FK_FMM_DIM_PAYMENT
    FOREIGN KEY (PAYMENT_SK) REFERENCES GN_DW.GOLD.DIM_PAYMENT (PAYMENT_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY ADD CONSTRAINT FK_FMM_DIM_REASON
    FOREIGN KEY (REASON_SK) REFERENCES GN_DW.GOLD.DIM_REASON (REASON_SK) NOT ENFORCED NORELY;
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
ALTER TABLE GN_DW.GOLD.FACT_TARGET_MEMBER_DEV ADD CONSTRAINT FK_FTG_D_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_TARGET_PROJECT ADD CONSTRAINT FK_FTG_B_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_TARGET_PROJECT ADD CONSTRAINT FK_FTG_B_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_TARGET_PROJECT ADD CONSTRAINT FK_FTG_B_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD CONSTRAINT FK_FSE_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD CONSTRAINT FK_FSE_DIM_SERVICE
    FOREIGN KEY (SERVICE_SK) REFERENCES GN_DW.GOLD.DIM_SERVICE (SERVICE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD CONSTRAINT FK_FSE_DIM_SEND_TYPE
    FOREIGN KEY (SEND_TYPE_SK) REFERENCES GN_DW.GOLD.DIM_SEND_TYPE (SEND_TYPE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD CONSTRAINT FK_FSE_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR ADD CONSTRAINT FK_FBQ_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR ADD CONSTRAINT FK_FBQ_DIM_MEMBER_IDENTITY
    FOREIGN KEY (IDENTITY_SK) REFERENCES GN_DW.GOLD.DIM_MEMBER_IDENTITY (IDENTITY_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR ADD CONSTRAINT FK_FBQ_DIM_BIGQUERY_EVENT
    FOREIGN KEY (BIGQUERY_EVENT_SK) REFERENCES GN_DW.GOLD.DIM_BIGQUERY_EVENT (BIGQUERY_EVENT_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR ADD CONSTRAINT FK_FBQ_DIM_BIGQUERY_SOURCE
    FOREIGN KEY (BIGQUERY_SOURCE_SK) REFERENCES GN_DW.GOLD.DIM_BIGQUERY_SOURCE (BIGQUERY_SOURCE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR ADD CONSTRAINT FK_FBQ_DIM_DEVICE
    FOREIGN KEY (DEVICE_SK) REFERENCES GN_DW.GOLD.DIM_DEVICE (DEVICE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR ADD CONSTRAINT FK_FBQ_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAD_DIM_DATE
    FOREIGN KEY (PERF_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAD_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAD_DIM_AD_CREATIVE
    FOREIGN KEY (AD_CREATIVE_SK) REFERENCES GN_DW.GOLD.DIM_AD_CREATIVE (AD_CREATIVE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAD_DIM_DEVICE
    FOREIGN KEY (DEVICE_SK) REFERENCES GN_DW.GOLD.DIM_DEVICE (DEVICE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_BROADCAST ADD CONSTRAINT FK_FAD_B_FAD
    FOREIGN KEY (AD_PERF_DK) REFERENCES GN_DW.GOLD.FACT_AD_PERFORMANCE (AD_PERF_DK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_DIGITAL ADD CONSTRAINT FK_FAD_D_FAD
    FOREIGN KEY (AD_PERF_DK) REFERENCES GN_DW.GOLD.FACT_AD_PERFORMANCE (AD_PERF_DK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_BROADCAST_CASE ADD CONSTRAINT FK_FAD_BC_FAD
    FOREIGN KEY (AD_PERF_DK) REFERENCES GN_DW.GOLD.FACT_AD_PERFORMANCE (AD_PERF_DK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_EVENT_ATTENDANCE ADD CONSTRAINT FK_FEP_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_EVENT_ATTENDANCE ADD CONSTRAINT FK_FEP_DIM_EVENT
    FOREIGN KEY (EVENT_SK) REFERENCES GN_DW.GOLD.DIM_EVENT (EVENT_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_EVENT_ATTENDANCE ADD CONSTRAINT FK_FEP_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_EVENT_ATTENDANCE ADD CONSTRAINT FK_FEP_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET ADD CONSTRAINT FK_FBD_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET ADD CONSTRAINT FK_FBD_DIM_BUDGET_ITEM
    FOREIGN KEY (BUDGET_ITEM_SK) REFERENCES GN_DW.GOLD.DIM_BUDGET_ITEM (BUDGET_ITEM_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET ADD CONSTRAINT FK_FBD_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET ADD CONSTRAINT FK_FBD_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY ADD CONSTRAINT FK_FBY_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY ADD CONSTRAINT FK_FBY_DIM_BUDGET_ITEM
    FOREIGN KEY (BUDGET_ITEM_SK) REFERENCES GN_DW.GOLD.DIM_BUDGET_ITEM (BUDGET_ITEM_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY ADD CONSTRAINT FK_FBY_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY ADD CONSTRAINT FK_FBY_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_DIM_CAMPAIGN
    FOREIGN KEY (ACQ_CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_DIM_DATE_ACQ
    FOREIGN KEY (ACQ_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_DIM_DATE_STOP
    FOREIGN KEY (FIRST_STOP_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_PAYMENT
    FOREIGN KEY (PAYMENT_SK) REFERENCES GN_DW.GOLD.DIM_PAYMENT (PAYMENT_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_PAY_DATE
    FOREIGN KEY (LAST_PAY_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_BILL_DATE
    FOREIGN KEY (LAST_BILL_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_ACQ_ORG
    FOREIGN KEY (ACQ_ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_ACQ_SPONSORSHIP
    FOREIGN KEY (ACQ_SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.DIM_CAMPAIGN ADD CONSTRAINT FK_DIM_CAMPAIGN_MKTG
    FOREIGN KEY (MKTG_CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_MARKETING_CAMPAIGN (MKTG_CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAP_MKTG_CAMPAIGN
    FOREIGN KEY (MKTG_CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_MARKETING_CAMPAIGN (MKTG_CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN ADD CONSTRAINT FK_FMSB_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN ADD CONSTRAINT FK_FMSB_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.DIM_BIZ_PLACE ADD CONSTRAINT PK_DIM_BIZ_PLACE PRIMARY KEY (BIZ_PLACE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.DIM_CHILD ADD CONSTRAINT PK_DIM_CHILD PRIMARY KEY (CHILD_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.DIM_MSG_TEMPLATE ADD CONSTRAINT PK_DIM_MSG_TEMPLATE PRIMARY KEY (TEMPLATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.DIM_MSG_TEMPLATE_BUTTON ADD CONSTRAINT PK_DIM_MSG_TEMPLATE_BUTTON PRIMARY KEY (TEMPLATE_BUTTON_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.DIM_PAYMENT_ACCOUNT ADD CONSTRAINT PK_DIM_PAYMENT_ACCOUNT PRIMARY KEY (PAYMENT_ACCOUNT_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.DIM_CHILD ADD CONSTRAINT FK_DCH_DIM_BIZ_PLACE
    FOREIGN KEY (BIZ_PLACE_SK) REFERENCES GN_DW.GOLD.DIM_BIZ_PLACE (BIZ_PLACE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.DIM_MSG_TEMPLATE_BUTTON ADD CONSTRAINT FK_DMTB_DIM_MSG_TEMPLATE
    FOREIGN KEY (TEMPLATE_SK) REFERENCES GN_DW.GOLD.DIM_MSG_TEMPLATE (TEMPLATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_RELATION_DEV ADD CONSTRAINT FK_FRD_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_RELATION_DEV ADD CONSTRAINT FK_FRD_DIM_MEMBER
    FOREIGN KEY (MEMBER_DK) REFERENCES GN_DW.GOLD.DIM_MEMBER (MEMBER_DK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_RELATION_CHANGE ADD CONSTRAINT FK_FRC_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_RELATION_CHANGE ADD CONSTRAINT FK_FRC_DIM_MEMBER
    FOREIGN KEY (MEMBER_DK) REFERENCES GN_DW.GOLD.DIM_MEMBER (MEMBER_DK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_PAYMENT_METHOD_CHANGE ADD CONSTRAINT FK_FPMC_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_PAYMENT_METHOD_CHANGE ADD CONSTRAINT FK_FPMC_DIM_MEMBER
    FOREIGN KEY (MEMBER_DK) REFERENCES GN_DW.GOLD.DIM_MEMBER (MEMBER_DK) NOT ENFORCED NORELY;

ALTER TABLE GN_DW.GOLD.DIM_SEND_REQUEST ADD CONSTRAINT PK_DIM_SEND_REQUEST PRIMARY KEY (SEND_REQUEST_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD CONSTRAINT FK_FMD_DIM_SEND_REQUEST
    FOREIGN KEY (SEND_REQUEST_SK) REFERENCES GN_DW.GOLD.DIM_SEND_REQUEST (SEND_REQUEST_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_RELATION_ACTIVITY ADD CONSTRAINT FK_FRA_DIM_DATE
    FOREIGN KEY (DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_RELATION_ACTIVITY ADD CONSTRAINT FK_FRA_DIM_MEMBER
    FOREIGN KEY (MEMBER_DK) REFERENCES GN_DW.GOLD.DIM_MEMBER (MEMBER_DK) NOT ENFORCED NORELY;

-- 검증(값이 아니라 방법이 정본이다 — 기대 건수를 여기 적지 않는다)
--   파일 선언 테이블 = grep -oE 'CREATE OR REPLACE TABLE GN_DW\.GOLD\.[A-Z_]+' 06_DDL.sql | sort -u | wc -l
--   파일 FK/PK      = grep -cE '^ALTER TABLE GN_DW\.GOLD\.[A-Z_]+ ADD CONSTRAINT' 06_DDL.sql
--   라이브 대조     = python3 scripts/gold_erd_coverage_gate.py
SHOW IMPORTED KEYS IN SCHEMA GN_DW.GOLD;
