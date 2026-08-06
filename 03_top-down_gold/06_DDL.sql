-- GN_DW.GOLD 스키마 전체 DDL(27개 테이블)에 정보성 FK/PK 제약 및 인수인계용 문서 주석 추가.
-- Co-authored with CoCo
/*
================================================================================
  GN_DW.GOLD — 전체 테이블 DDL (27개: DIM 15 + FACT 12)
  작성일   : 2026-07-02 (컬럼 COMMENT: 2026-07-03 / 배포·적재: 2026-07-20 / 광고 위성 3종 증설: 2026-07-28 순서9-I)
  실측대조 : 2026-07-29 — INFORMATION_SCHEMA GOLD = BASE TABLE 27 + VIEW 12, FK 38 · 본 파일과 전 컬럼 일치.
  참고 문서 : 03_top-down_gold/03_테이블 설계.md(DEC-8~13) · 09_빅테이블 VIEW.md(WIDE VIEW 12)
               05_필드 인벤토리.md · 08_silver의존.md
--------------------------------------------------------------------------------
  실행 규칙
  ─────────────────────────────────────────────────────────────────────────────
  1. DIM 15개를 모두 생성한 뒤 FACT 12개를 생성한다.
  2. DIM_DATE → DIM_ORG → DIM_MEMBER → 나머지 DIM → FACT 순서 준수.
     FACT 내부는 코어 FACT_AD_PERFORMANCE 를 위성 3종(FAD_B·FAD_D·FAD_BC)보다 먼저 생성.
  3. FK_타깃에 '※비강제' 표기된 컬럼은 FOREIGN KEY 제약 없이 일반 컬럼으로 생성.
  4. 타입 길이(VARCHAR 자릿수)는 대부분 PENDING — 실측 376컬럼이 기본길이, 명시 19컬럼.
     운영 후 ALTER 예정. 단, MEMBER_DK 는 [실측06-30] VARCHAR(10) 확정.
  5. 모든 테이블 공통: DW_SOURCE_SYSTEM / DW_LOAD_TS(최초적재, NOT NULL) /
     DW_UPDATE_TS(최종적재) / DW_BATCH_ID(=dbt invocation_id) 감사 컬럼 포함.
  6. FACT_GA_BEHAVIOR 의 비가산 지표(BOUNCE_RATE·AVG_SESSION_DURATION 등)는
     그레인 기준 값 — 상위 레벨 재합산 금지(테이블 COMMENT 명시).
  7. [적재 상태] CRM·GA4·ERP·AGENCY SILVER→GOLD 적재 완료(27테이블 + WIDE VIEW 12개).
     단 사업목표(FTG_B, 원천=CRM 신규 목표 테이블 CRM_BIZ_TARGET·데이터 입고 대기 E-6)·
     모금성비용(FBD, ERP 원천 부재 E-1)은 미입고, ADMIN(앱푸시·조회수)은 제외 확정
     → 해당 컬럼만 생성·미채움(FACT_TARGET_BIZ=0행).
  8. FK/PK 제약은 파일 하단 [관계 제약] 섹션에서 ALTER 로 일괄 선언(현행 42개).
     - 전부 NOT ENFORCED NORELY (정보성) — Snowflake 는 NOT NULL 외 강제 안 함.
       ERD·BI 관계 인식·문서화 용도이며, 데이터 미검증 단계이므로 RELY 는 보류.
     - 참조 대상이 비유일(SCD2 MEMBER_DK / 월conform MONTH_KEY)인 FK 는
       Snowflake 규칙상 선언 불가 → 동일 섹션에 [보류] 사유·조인경로 명문화.
     - FACT PK/UNIQUE 는 grain 미확정으로 보류. 단 광고 팩트군은 AD_PERF_DK 를
       PK 로 선언(코어·1:1 위성) / FAD_BC 는 (AD_PERF_DK, CASE_SEQ) 복합 PK.
  9. 각 컬럼의 COMMENT 는 gold 스키마 컬럼 인벤토리_20260629.csv 설명 컬럼 기준.
 10. ⚠️ 센티넬 규약 = **SK=0 '(미매핑)'**. 13개 DIM 에 Unknown 시드행을 두고 팩트는
     LEFT JOIN + COALESCE(...,0). 설계 초안의 `-1 UNKNOWN` 표기는 폐기됨(2026-07-16).
================================================================================
*/

-- 실행 컨텍스트(role 설계 정합, 01_환경 Role.md §2.2): 스키마·테이블 DDL = GN_DW_ADMIN · 기본 WH = DEV_WH
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE DATABASE GN_DW;
CREATE SCHEMA IF NOT EXISTS GN_DW.GOLD
    WITH MANAGED ACCESS
    COMMENT = '분석 View + Semantic View + Agent + 예측 테이블 + Streamlit';
GRANT CREATE VIEW ON SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;

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
    -- CONF-4(2026-07-31 정본대조): D6 4단 중 CORP·TEAM은 부서 차원에서 산출 불가/보류. DIVISION은 "실적지부"로 재정의.
    CORP                VARCHAR         COMMENT '법인(#114) — 🔴 부서 차원에서 산출 불가(CONF-4). 부서→법인 1:1 아님: 200부서에 복수법인 혼재(2종 69부서/23,130명 · 3종 131부서/1,544,005명=98.6%). 부서트리 LVL1도 부적합(ZA 구조노드 587부서가 법인 루트 미연결 + 직위 B000007 + 회원0 재단법인 2개 혼재). 법인 축의 정본 원천 = 회원 속성 CPR_DIV_CD(CM019: I=사단/S=사복/A=통합) → DIM_MEMBER 또는 팩트 degen 배속 판단 필요. 값 NULL 유지',
    DIVISION            VARCHAR         COMMENT '실적지부 — 정본 용어사전 430(실적 지부 명)·431(실적지부(본부/지부) 구분). 🔴 재정의(CONF-4): 정본 보고서는 "본부/지부" 단독 사용 0건이고 "실적지부(본부/지부)"(05:275)·"실적지부"(05:311) 형태로만 쓴다 → 조직트리(UPPER_DEPT_ID)가 아니라 실적트리(ACMSLT_UPPER_DEPT_ID) 기반. ⚠️ 산출 규칙 미확정 — 실적부서 455개 중 명칭기반 최근접 본부/지부 도달 418개(91.9%)·미도달 37개이고 명칭 판정은 범주오류 위험 → 규칙 확정까지 값 NULL 유지',
    DEPARTMENT          VARCHAR         COMMENT '부서(#116) — ✅ 정본 정합(용어사전 121·390·391 · 회원보고서 4개 · 마케팅보고서 2개). DEPT_NM 직접 대입(695종)',
    TEAM                VARCHAR         COMMENT '팀 — 🔴 보류(CONF-4). 정본 근거 = 지표 #152~155(연사업/추경 목표) "각 팀별" 뿐이고 용어사전·회원보고서·마케팅보고서 실질 0건(검출된 3건은 전부 "원천팀/원본팀" 편집주석). 그 원천 CRM_BIZ_TARGET은 미입고(E-6) → 소비처 부재. E-6 입고 시 재개. 값 NULL 유지',
    -- 원천 계통 컬럼 노출(추론 0) — O16/CONF-4 후속 규칙 확정 시 즉시 활용. SILVER CRM_ORG 에 이미 전파돼 있음.
    ACMSLT_UPPER_DEPT_ID VARCHAR        COMMENT '실적상위부서ID (원천 그대로) — 실적트리 부모. 조직트리 UPPER_DEPT_ID 와 441건 상이·573건 동일·NULL 300. 실적부서 455개 중 446개(98.0%)가 이 트리 LVL5 → DEC-5 "5th=실적부서" 근거',
    ACMSLT_DEPT_YN      VARCHAR         COMMENT '실적부서 여부 Y/N (원천 그대로) — Y 455개',
    USE_YN              VARCHAR         COMMENT '사용여부 Y/N (원천 그대로) — 🔴 N이 764개(58.1%)지만 제외 금지(O16): 팩트가 대량 참조(CRM_MEMBER.ACT_DEPT_CD 미사용 156부서에 410,506명 · AMT_CHANGE 미사용 189부서에 100,931건) + 필터 시 트리 파편화(LVL1 9→42). 소비 측 필터용으로만 사용',
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
    -- 🔴 [O27 2026-08-04 정본 동기화] 본 블록 = _archive/O27_DIM_MEMBER_ALTER.sql §2·§3·§4 와 일치.
    --   ADD 4(AREA_CD·AGE·PREV_MBER_STAT_CD·PREV_MEMBER_STATUS_NAME) · DROP 3(NEW_EXISTING_FLAG·
    --   LAST_CAMPAIGN·CURRENT_SPONSORSHIP) · COMMENT 8컬럼. 🔴 종전에는 물리 ALTER 만 하고 이 파일을
    --   갱신하지 않아 2026-08-03 전체 재구축(TEARDOWN+setup)에서 O27 이 통째로 소실됐다(O30/P57).
    -- [2026-08-03 O26] 코드 컬럼 = BRONZE 원천명 / 라벨 컬럼 = 분석 용어.
    --   개명: GENDER→SEX · MEMBER_STATUS→MBER_STAT_CD · MEMBER_TYPE→MBER_DIV_CD · ENROLL_PATH→JOIN_PATH_CD
    --   (ALTER TABLE RENAME COLUMN 으로 물리 반영. CREATE OR REPLACE 금지 — FK·GRANT 파괴)
    SEX                 VARCHAR         COMMENT '성별 원천코드 raw — BRONZE TM_MM_FDRM_MBER_INFO.SEX(정본 코드그룹 CM013). 1국내남·2국내여·3외국남·4외국여·5외국기타·6단체·7기업·8기타(+0 사전부재). 🔴 정본 비고가 ''성별만으로는 사용하지는 않음''을 명시 — 성별 단일축은 GENDER_NAME 을 쓴다. 라벨=SEX_NM(원천)·GENDER_NAME(분석)',
    SEX_NM              VARCHAR         COMMENT 'CM013 원천 라벨 그대로(국내(남자)/국내(여자)/외국인(남자)/외국인(여자)/외국인(기타)/단체/기업/기타). 국내·외국인 축 보존용 — 이 축은 CM013 만 보유한다',
    GENDER_NAME         VARCHAR         COMMENT '성별(#130) 분석 라벨 — 코드사전 CM017 라벨 그대로: 남자/여자/기타/단체/기업. 정본 공#130 값 정의 ''남/여/기업/단체/기타'' 와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹(현업 확인 대상). ⚠️종전 하드코딩 ''여성/남성/미상''은 정본 5종을 3종으로 축약하고 법인·단체를 ''미상''으로 오라벨했다(O26 교정)',
    AREA_CD                 VARCHAR(10)     COMMENT '지역 코드 raw — CM018(18종) + sentinel ''0''(라벨 없음). 라벨=REGION. [O27] 개발약정(CRM_MEMBER_DEV) **시점 스냅샷**이며 SCD2 버전별로 다를 수 있다. 판정근거: CM018 사전 18종 × 실적재 distinct 18종 = 18/18 일치 · 정본 공#131 지역정의가 약칭이라 CM011(정식명) 아님',
    REGION                  VARCHAR         COMMENT '지역 (#131) — CM018 약칭 라벨(서울/경기/인천/강원…). 코드=AREA_CD. [O27] 시점귀속(as-of): 그 버전 EFFECTIVE_FROM 이하 최근 개발약정의 값. 적중 96.91%(7,681,020/7,925,716). ⚠️ONCE(일시회원) 175,722행은 개발약정에 행이 없어 NULL — ''(해당없음)''이 아니다(개념은 있고 원천이 없다). sentinel AREA_CD=''0'' 도 라벨 NULL',
    AGE                     NUMBER(2,0)     COMMENT '연령대 코드 raw — CM014(1~12). 🔴**연속형 나이가 아니다**: 1=10대미만·2=10대·3=20대·4=30대·5=40대·6=50대·7=60대·8=70대·9=70대이상·10=단체·11=기업·12=기타. 라벨=AGE_BAND. 판정근거: CM014 12종 × 실적재 12종 = 12/12 일치 · 독립 교차검증 AGE=''10''(단체) 21,920행 전건 SEX=''6''(단체) · AGE=''11''(기업) 64,581행 전건 SEX=''7''(기업). ⚠️BRONZE TM_MM_FDRM_MBER_DVLP_AMT.AGE COMMENT ''연령''(NUMBER)은 오류다',
    AGE_BAND                VARCHAR         COMMENT '연령대 — CM014 라벨. 코드=AGE. [O27] 시점귀속(as-of) · 적중 97.63%. 🔴구간을 우리가 만든 것이 아니라 **원천이 이미 구간화**해 제공한다(DEC-28 §18-B 로 DEC-27 §17-C ''구간 정의 없음→보류'' 판정을 정정). ⚠️생년월일(MBER_BIRTHDAY) 입고는 이 컬럼의 선행조건이 아니다 — 시점정확 연령에만 필요. ⚠️ONCE 는 NULL',
    MBER_STAT_CD        VARCHAR         COMMENT '회원상태 원천코드 raw(#132, MM010) — 정본 명칭 ''회원상태코드''. SCD2 버전행은 TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD(변경상태코드), 무이력행은 TM_MM_FDRM_MBER_INFO.MBER_STAT_CD 에서 온다(둘 다 MM010). 라벨=MEMBER_STATUS_NAME',
    MBER_DIV_CD         VARCHAR         COMMENT '회원구분 원천코드 raw — BRONZE MBER_DIV_CD(MM018 1개인·2기업·3단체). 라벨=MEMBER_TYPE_NAME',
    MEMBER_TYPE_NAME    VARCHAR         COMMENT '회원구분명(라벨). 원천 CRM_CODE MM018: 1개인·2기업·3단체. 미매핑→미상',
    MEMBER_STATUS_NAME  VARCHAR         COMMENT '회원상태명(라벨). 원천 CRM_CODE MM010: 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단. 미매핑→미상',
    MEMBER_STATUS_GROUP VARCHAR         COMMENT '회원상태 대분류(파생). 1→정상·2~11→미납·12→중단·NULL→미상',
    PREV_MBER_STAT_CD       VARCHAR(10)     COMMENT '상태전이 **이전상태** 코드 raw — MM010. 현재상태=MBER_STAT_CD 와 짝지어 전이를 표현한다(이 SCD2 버전행이 곧 전이 사건이므로 fan-out 0). 원천=CRM_MEMBER_STATUS_HIST.BF_STAT_CD(채움 100%·7,501,761·12종 = MM010 12/12 일치). ⚠️이력 미보유행(FDRM 무이력·ONCE 전체)은 NULL — ''이전상태가 없다''가 아니라 ''이력이 없다''. ⚠️동일자 다중전이는 최종 전이로 축약된다(중간 단계 소실)',
    PREV_MEMBER_STATUS_NAME VARCHAR(100)    COMMENT '이전상태 라벨 — MM010. 코드=PREV_MBER_STAT_CD. 하드코딩 아니라 CRM_CODE 조인(P31). 원천 라벨 BF_STAT_NM 도 MM010 과 100% 일치하나 사전 조인을 정본으로 쓴다. ⚠️개발구분(MM015)은 다른 축 — FACT_MEMBER_EVENT.DVLP_DIV_NM',
    FIRST_JOIN_DATE     DATE            COMMENT '최초가입일=회원번호 생성일(#28)',
    FIRST_CAMPAIGN      VARCHAR         COMMENT '최초캠페인(#29)',
    JOIN_PATH_CD        VARCHAR         COMMENT '가입경로 원천코드 raw — BRONZE JOIN_PATH_CD(MM014). 라벨=ENROLL_PATH_NAME',
    ENROLL_PATH_NAME    VARCHAR         COMMENT '가입경로명(라벨). 원천 CRM_CODE MM014: 홈페이지/CRM/모바일웹/희망TV/외주콜센터/모바일앱/REG/EDU. 미매핑→미상',
    FIRST_SPONSORSHIP       VARCHAR         COMMENT '최초 후원사업 — CRM_MEMBER_DEV 최소 발생일(OCCRRNC_DE)의 SPNSR_BSNS_ID. ''최초''는 시점 불변이라 as-of 불요(SCD1). 적중 97.76%. ⚠️ONCE 는 개발약정 부재로 NULL. ⚠️**현재 후원사업**은 제공하지 않는다 — 동시 다중후원이 정상(14.2%·최대 14)이라 단일값이 성립하지 않아 CURRENT_SPONSORSHIP 을 DROP 했다(O13 계열)',
    LAST_STOP_DATE          DATE            COMMENT '최종 중단일 — 원천 CRM_MEMBER_DISCONTINUE.SPNSR_DSCNTC_DE. 🔴**그 버전 시점까지의 as-of max** 다(단순 max 아님). 단순 max 는 미래 정보를 과거 버전에 누설해 예측 피처(LTV·유지기간 신4·6~8)를 오염시킨다. 적중 19.73%(1,563,872/7,925,716) — 중단 이력이 없는 회원·중단 이전 버전은 NULL',
    EFFECTIVE_FROM      DATE            COMMENT 'SCD2 유효시작',
    EFFECTIVE_TO        DATE            COMMENT 'SCD2 유효종료',
    IS_CURRENT          BOOLEAN         COMMENT '현재행 여부',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-03 DEC-27] SILVER CRM_MEMBER.MEMBER_TYPE 이 존재했는데 GOLD 모델 CTE 컬럼열거에서
    --   탈락해 있던 것을 복원(G3 결손 유형 — "모델O·SELECT 탈락"). ALTER TABLE ADD COLUMN 으로 물리 반영.
    MEMBER_TYPE         VARCHAR         COMMENT '회원 등록계통 구분 — SILVER CRM_MEMBER.MEMBER_TYPE 전파: FDRM=정기회원(TM_MM_FDRM_MBER_INFO 1,587,343명) / ONCE=일시회원(TM_MM_ONCE_MBER_INFO 175,722명). 🔴 일시회원은 회원상태(MM010)·가입경로(MM014) 개념이 원천에 없다 — 상태 기반 분포·이탈률·예측 모집단은 FDRM 으로 한정할 것. ⚠️ MEMBER_TYPE_NAME(개인/기업/단체, MM018)은 이 컬럼의 라벨이 아니다 — 완전히 다른 축이며 코드는 MBER_DIV_CD 다'
) COMMENT = '회원 차원 (SCD2 · 회원 상태버전)';


-- ============================================================================
-- DIM 3-V: DIM_MEMBER_CURRENT — 분석가 기본 진입점 (현재행 뷰) [2026-08-03 신설 · DEC-27 §17-A]
-- ============================================================================
-- 🔴 본 파일은 **테이블 구조 소유주**이며 뷰는 소유하지 않는다.
--    `DIM_MEMBER_CURRENT` 정본 = dbt 모델 `10_dbt_pipeline/models/gold/dim/DIM_MEMBER_CURRENT.sql`
--    (materialized='view' · `ref('DIM_MEMBER')` · COMMENT 는 post_hook).
--
-- ▶ 왜 dbt 가 소유하는가 (`dbt_project.yml` §67~72 확립 원칙)
--    "ref() 로 GOLD 모델 참조 → 거버넌스·리니지·build 게이트 확보
--     (BLOCKING-4 해소, **미거버넌스 객체 재발방지**)" — WIDE 소비뷰와 동일 근거다.
--    ⚠️ 2026-08-03 초판이 이 뷰를 본 파일에 CREATE VIEW + GRANT 로 넣었다가 위 원칙 위반으로 철회했다.
--       GRANT 도 불요다 — GOLD 스키마에 VIEW future grant(SELECT → ANALYST/VIEWER/SERVICE)가
--       이미 있어 매 build 시 자동 부여된다(실측 확인).
--
-- ▶ 존재 이유(요약): 회원 FACT 4개가 전부 MEMBER_DK 로 조인하는데 DIM_MEMBER 는 SCD2(평균 4.50버전)라
--    순진한 조인이 조용히 팬아웃한다 — 실측 202606 단월 3.60배 · 납입회비 171.3억→507.5억(2.96배 과대).
--    상세·전건 NULL 7컬럼 미노출 판정 = 문서30 DEC-27 §17-A·§17-C.


-- ============================================================================
-- DIM 4: DIM_MEMBER_IDENTITY — 회원 신원 브리지 (P5 durable key)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER_IDENTITY (
    IDENTITY_SK         NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '회원 식별 대리키 (ETL 일련번호, PK)',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키',  -- ※비강제 FK→DIM_MEMBER(SCD2/비유일)
    MEMBER_NO           VARCHAR         NOT NULL COMMENT '회원번호(#110)',
    MEMNUM              VARCHAR         COMMENT 'memnum(#111) — 🔴 전건 NULL(미배선). 원천 실재 = SILVER.GA4_EVENT.PAGE_LOCATION 의 memnum= (17,795행·1,589종). 조회 시 항상 0행',
    GA_MEMBER_ID        VARCHAR         COMMENT 'member id(#112)',
    HOMEPAGE_ID         VARCHAR         COMMENT '홈페이지/앱 ID. 원천: TM_MM_FDRM_MBER_INFO.HMPG_ID',
    CHILD_CODE          VARCHAR         COMMENT '결연아동코드(#122, URL 파싱) — 🔴 전건 NULL(미배선). 원천 실재 = SILVER.GA4_EVENT.PAGE_LOCATION 의 childnum= (6,827행·594종). 조회 시 항상 0행',
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
    PARENT_CAMPAIGN     VARCHAR         COMMENT '상위캠페인 코드(#119) — 자기참조 키(값 도메인 = CAMPAIGN_BK). 🔴 라벨이 아니다. 사람이 읽는 이름은 PARENT_CAMPAIGN_NAME 을 쓴다(O37 신설)',
    CAMPAIGN_NAME       VARCHAR         COMMENT '캠페인명(#18·120·147)',
    PROMO_METHOD        VARCHAR         COMMENT '홍보방법 원천코드(#118, 원천 PR_MTH_CD · 코드사전 CM008). 🔴 라벨이 아니라 숫자 코드다 — 사람·Agent 가 읽는 이름은 PROMO_METHOD_NAME 을 쓴다(O37 신설)',
    CAMPAIGN_TYPE       VARCHAR         COMMENT '캠페인 유형(#17) = 캠페인 카테고리 라벨(SILVER MM294, 56종). 예: 국내사례캠페인·굿즈캠페인·해외캠페인. ⚠️숫자코드 아님(2026-07-16 라벨화)',
    DOMESTIC_OVERSEAS   VARCHAR         COMMENT '국내/해외(#15) = SILVER CMPGN_TYPE1_NM(MM295): 국내 / 통합 / 해외. (종전 전건 NULL — 2026-07-16 BRONZE 재입고로 채움)',
    BIZ_CASE_TYPE       VARCHAR         COMMENT '사업/사례(#16) = SILVER CMPGN_TYPE2_NM(MM296): 굿즈 / 기타 / 사례 / 사업. ⚠️종전 모델이 유형1(국내/해외)을 여기 매핑한 의미혼입을 2026-07-16 교정',
    INFLOW_PATH         VARCHAR         COMMENT '개발인입경로 라벨(SILVER MM293). 예: 디지털·방송·영상광고·지역개발·마케팅콜개발·대면모금·직원개발. 🔴 이 축은 **모집 채널**이다 — 2026-07-16 신설 시 「현업 주요캠페인 분류축」이라 적었던 표기는 거짓이므로 회수한다(O37). 캠페인 카테고리 = CAMPAIGN_TYPE(MM294) · 상위캠페인 = PARENT_CAMPAIGN_NAME',
    MARKETING_CAMPAIGN  VARCHAR         COMMENT '마케팅캠페인명(SILVER MK_CMPGN_NM). Q16 해소(2026-07-16 신설)',
    CAMPAIGN_OPEN_DATE  DATE            COMMENT '오픈일자(#19)',
    ORG_SK              NUMBER(38,0)    COMMENT '캠페인 귀속조직',  -- FK→DIM_ORG
    -- [2026-08-05 O37] 상위캠페인 라벨 신설(ALTER TABLE ADD COLUMN 으로 물리 반영, 위치=맨 끝).
    --   PARENT_CAMPAIGN 이 자기참조 **코드**여서 현업이 말하는 "주요캠페인"을 코드로만 보고 있었다.
    --   DIM_CAMPAIGN 자기조인(PARENT_CAMPAIGN = CAMPAIGN_BK)으로 전건 해소된다(O25/G3 동일 패턴).
    PARENT_CAMPAIGN_NAME VARCHAR        COMMENT '상위캠페인명 — 코드 PARENT_CAMPAIGN(자기참조 CAMPAIGN_BK)을 DIM_CAMPAIGN 자기조인으로 해소한 라벨. 현업 "주요캠페인" 계열 축. ⚠️ 상위가 없는 캠페인은 NULL 이며 ''(미매핑)''으로 창작하지 않는다(P21). ⚠️ 캠페인 카테고리 축과 다르다 — 카테고리는 CAMPAIGN_TYPE(MM294)이다',
    -- [2026-08-05 O37] 홍보방법 라벨 신설. PROMO_METHOD(원천 PR_MTH_CD)는 **숫자 코드**이고
    --   SILVER CRM_CAMPAIGN 에 `PR_MTH_NM` 이 없었다(카테고리·유입경로는 코드/라벨 쌍이 있는데 홍보방법만
    --   코드뿐이었다). 코드사전 탐색으로 **CM008 이 도메인을 전량 덮는 것**을 확인해 배선했다.
    --   🔴 라벨 없이 이 축을 SV 에 노출하면 Analyst 가 코드를 추측해 0행 무증상 오답을 낸다(§6.9-(5)·AD-4 유형).
    PROMO_METHOD_NAME   VARCHAR         COMMENT '홍보방법명 — 코드 PROMO_METHOD(원천 PR_MTH_CD)를 코드사전 CM008 로 해소한 라벨. 실제값 계열: PC배너광고(DA)·M배너광고(DA)·PC검색광고(SA)·M검색광고(SA)·TM·TS·PC캠페인-홈페이지·M캠페인-홈페이지·온라인·오프라인·APP캠페인·기존회원메일·기타 등. ⚠️ 원천 PR_MTH_CD 가 없는 캠페인은 NULL 이며 ''(미매핑)''으로 창작하지 않는다(P21). ⚠️ USE_YN 무필터 조인',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '캠페인 차원 (1캠페인). 분류축 = CAMPAIGN_TYPE(카테고리 = 현업 「주요캠페인」)·PARENT_CAMPAIGN_NAME(상위캠페인)·PROMO_METHOD_NAME(홍보방법)·INFLOW_PATH(모집채널)·DOMESTIC_OVERSEAS(국내해외)·BIZ_CASE_TYPE(사업사례)·MARKETING_CAMPAIGN. PARENT_CAMPAIGN·PROMO_METHOD 는 코드이고 나머지는 라벨(각 라벨 컬럼 병설)';


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
    -- 🔴 [DEC-30 2026-08-04] DURATION_SEC 제거 — 초수는 **소재 속성이 아니다**(실측: 소재 41종 중
    --   19종이 복수 초수를 가져 함수종속 53.7% 뿐 · 같은 소재가 30/60/90초 편집본으로 송출).
    --   정본 소재지 = FACT_AD_BROADCAST.DURATION_SEC(방송 grain). 본 컬럼은 오배치 중복축이었다.
    RT_TYPE             VARCHAR         COMMENT 'RT유형',
    AD_TYPE             VARCHAR         COMMENT '소재 광고유형. ⚠️코어 FACT_AD_PERFORMANCE.AD_SOURCE_TYPE(원천 출처축 DIGITAL/VIDEO/REBROADCAST)과 다른 개념 — WIDE 에서는 AD_CREATIVE_TYPE 으로 노출',
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
    DEFAULT_CHANNEL_GROUP VARCHAR       COMMENT '[DEC-30] GA4 표준 채널그룹 ← GA4_TRAFFIC_SOURCE.DEFAULT_CHANNEL_GROUP. 채움 100%(2,167)·14종 · grain 에 93.8% 함수종속(다중 9/146·최대 4)이라 MAX() 대표값. ⚠️SOURCE_MEDIUM(파생 문자열)과 다른 개념 — GA4 가 산정한 표준 분류다',
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
    -- 🔴 [DEC-30 2026-08-04] SEND_TYPE_L/M/S 3컬럼 제거 → **DIM_SEND_TYPE 으로 이관**했다.
    --   본 차원 grain 은 (CHANNEL,SUBTYPE) 10행인데 대/중/소를 넣으면 74행이 되어 함수종속이 깨지고
    --   SERVICE_SK 산식이 바뀌어 이미 99.97% 적재된 FSE.SERVICE_SK 를 파괴한다.
    --   정본 지표 #133·#134·#135 는 소멸하지 않는다 — 소재지만 DIM_SEND_TYPE 으로 옮겼다.
    SUBTYPE             VARCHAR         COMMENT '발송/참여 subtype',
    CHANNEL             VARCHAR         COMMENT 'CRM_UMS (ADMIN enum은 어드민 제외로 미사용 2026-07-09)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '서비스 차원 (1서비스 · 발송/참여 유형)';


-- ============================================================================
-- DIM 10-B: DIM_SEND_TYPE — 발송구분 차원 (대/중/소 3단 계층) [DEC-30 2026-08-04 신설]
-- ============================================================================
-- 🟢 신설 근거 = DEC-28 §18-C 의 "②차원 분리" 안 실행. DIM_SERVICE grain 확장(①안)은
--    SERVICE_SK 산식을 바꿔 이미 99.97% 적재된 FSE.SERVICE_SK 를 파괴하므로 기각됐다.
-- 🟢 커버리지 재측정 = 소비 grain(FSE)에서 21.58%(8,300,272/38,470,780).
--    DEC-28 이 인용한 0.106%(1,707/1,614,397)는 **요청 grain 분모**로 가치를 200배 과소평가했다(P39)
--    — send-type 이 붙은 요청은 평균 4,862.5명 발송 vs 없는 요청 18.7명(260배 차).
-- 🔴 자연키 = (대,중,소) 전체 경로. 중분류 코드 단독은 모호하다(코드 16종 vs 라벨 26종).
--    실측 (TOP,MID,BOT) 65조합 = 라벨 결합 65 · 계층 NULL 0 → 라벨이 경로에 100% 함수종속.
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
) COMMENT = '발송구분 차원 — 대/중/소 3단 계층 평탄화 (정본 지표 #133·#134·#135). grain=(대,중,소) 코드 경로 65조합 + 센티넬. 🟢FACT_SERVICE_EVENT 소비 커버리지 실측 21.58%(8,300,272/38,470,780) — 요청 grain 0.106% 는 잘못된 분모다(P39). ⚠️DEC-28 §18-C 가 DIM_SERVICE grain 확장 대신 차원 분리를 택한 이유 = SERVICE_SK(FSE 99.97% 적재) 보존.';


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
    REASON_TYPE         VARCHAR         COMMENT '사유 코드그룹 ID. ⚠️주석상 "중단/미납 구분"이었으나 실제값은 CRM 코드그룹 ID 336종(PM019·MS049·PM018·PM002·PM032·PM033 등) — ''중단''/''미납'' 리터럴 0건(전체 5,839행). 중단/미납 구분 필터가 필요하면 별도 분류 컬럼 신설 필요(O21, 2026-07-31 실측 교정)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '사유코드 차원 (중단/미납)';


-- ============================================================================
-- DIM 13: DIM_DEVICE — 디바이스 차원
--   ⚠️ [2026-07-28 순서9-I DEC-10] 멤버 `(해당없음)` 신설 + DEVICE_SCOPE_DESC 컬럼 신설.
--      방송광고(VIDEO·REBRDC)는 기기 개념이 없다(실측 37,886행 전량 NULL) → `(unknown)`(진짜 미상)과
--      의미를 분리한다. `(해당없음)`은 값이 확정된 정상 멤버이므로 **해시 SK**, `0`=Unknown 정본 유지.
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_DEVICE (
    DEVICE_SK           NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '디바이스 대리키 (해시 SK, PK). 단 (unknown)=0 센티넬 · -1 미사용',
    DEVICE_TYPE         VARCHAR         COMMENT 'PC / M / APP / (해당없음) / (unknown). (해당없음)=방송광고(기기개념 부재, DEC-10) · APP=GA4 platform=WEB 단일로 현 데이터 미생성(G-5)',
    DEVICE_SCOPE_DESC   VARCHAR         COMMENT '멤버 의미 자기설명(DEC-10). 팩트 조인·문서 참조 없이 차원만 조회해도 (해당없음)의 뜻을 알 수 있게 하는 장치',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '디바이스 차원 (1디바이스). 멤버 = PC·M·(APP 미생성)·(해당없음)방송·(unknown)센티넬0';


-- ============================================================================
-- DIM 14: DIM_EVENT — 행사/이벤트 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_EVENT (
    EVENT_SK            NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '행사 대리키 (ETL 일련번호, PK)',
    EVENT_BK            VARCHAR         NOT NULL COMMENT '행사 업무키(BK, 자연키)',
    EVENT_KIND          VARCHAR         COMMENT '행사종류 코드 raw(EVENT/CRMN). 라벨=EVENT_KIND_NAME',
    EVENT_KIND_NAME     VARCHAR         COMMENT '행사종류명(라벨). EVENT→일반행사·CRMN→캠페인행사',
    EVENT_CATEGORY      VARCHAR         COMMENT '행사구분',
    EVENT_NAME          VARCHAR         COMMENT '행사명',
    EVENT_START_DATE    DATE            COMMENT '행사기간 시작(05 3-6)',
    EVENT_END_DATE      DATE            COMMENT '행사기간 종료(05 3-6)',
    APPLY_CHANNEL       VARCHAR         COMMENT '신청경로',
    RECRUIT_HEADCOUNT   NUMBER(38,0)    COMMENT '[DEC-30] 모집인원 ← CRM_EVENT.RCRIT_PSNNL_CO. 채움 3,361/3,786=88.8%·74종. 🔴행사 속성이므로 참여 팩트가 아니라 행사 차원이 정본 — 참여행 반복 시 SUM 이 101.0배 과대계상(행사 참값 4,513,184 vs 456,007,553). 행사 단위로만 합산',
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
    REASON_SK                   NUMBER(38,0)    COMMENT '미납 대표사유 (FK→DIM_REASON) — ✅ W3(DEC-24, 2026-07-31) 배선 완료. 🔴 미납(PAY_STAT_CD=''F'') 행 한정 — 최종차수(MBRFEE_SQNC 최대)의 RQEST_RST_CD를 (코드그룹, 코드) 복합키로 DIM_REASON 조인. 코드그룹 = SETLE_CD 1&2자리→PM002 / 1&4자리→PM032 / 2→PM018 / 12→PM033 / 5→PM019. 실측 미납 월×회원 3,302,535 중 3,164,724(95.83%) 매핑 · 0=비미납 또는 구조적 사유부재 137,811(수기처리 127,155 + F코드부재 10,623 + DIM미존재 33). ⚠️ 대표 1개로 축약 — 복수사유 분포는 SILVER 직접 조회. ⚠️ 중단사유는 별도 트랙(FME)',
    DEV_CNT                     NUMBER(18,4)    COMMENT '개발(건) — A1: FME(CRM_MEMBER_DEV) 사건수 롤업. ⚠️금액/10000 의미는 원천 금액컬럼+FME 변경 필요(별도트랙, #4·5·149)',
    DEV_MEMBERS                 NUMBER(38,0)    COMMENT '개발(명)(#148) — A1: 월×회원 개발발생=1. 🟢이 컬럼은 **옳다**: grain 이 월×회원이라 SUM 이 곧 개발(명)이며 466개월 전부 COUNT(DISTINCT MEMBER_DK) 와 일치 실측(O39). ⚠️동명의 FACT_MEMBER_EVENT.DEV_MEMBERS 는 사건 플래그로 SUM 이 건수다 — 혼용 금지.',
    STOP_CNT                    NUMBER(18,4)    COMMENT '중단(건) — A1: FME(CRM_MEMBER_DISCONTINUE) 사건수 롤업 (#35)',
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
    PAID_FEE                    NUMBER(18,2)    COMMENT '납입 **총액**(원) = 회비+기부금 (#69·70 단일화). 🔴「납입회비」가 아니다(O40) — 회비만은 PAID_FEE_BILLABLE. 납부율 분자로 쓰지 말 것(분모 BILLED_AMT 는 회비 청구만이라 모집단 불일치).',
    BILLED_AMT                  NUMBER(18,2)    COMMENT '회비 청구액(원) (#71). 기부금은 원천에 청구 컬럼이 없어 포함되지 않는다(O40).',
    -- [2026-08-05 O40] 납부율·미납금액 모집단 일치 컬럼 2종
    PAID_FEE_BILLABLE           NUMBER(18,2)    COMMENT '회비만 납입액(원) — 납부율 분자 **정본**(O40). `PAYMENT_TYPE=''회비''` 행의 PAY_AMT 합. 🔴`PAID_FEE` 와 다르다: 그쪽은 회비+기부금 총수납액이고 기부금은 원천에 청구 컬럼이 없어 분모에 못 들어간다. 납부율 = PAID_FEE_BILLABLE / BILLED_AMT 로 계산할 것.',
    UNPAID_BILLED_AMT           NUMBER(18,2)    COMMENT '미납 청구액(원) — 정본 **DEC-3** 정의(O40): `PAY_STAT_CD IN (''F'', NULL)` 인 행의 **RQEST_AMT** 합. 🔴차감식(BILLED−PAID)을 쓰지 말 것 — 기부금이 미납을 상쇄해 2.37배 과소해진다(2025 실측 123억 vs 정본 293억).',
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
    -- W4(DEC-22, 2026-07-31): ML 전용 파생. 🔴 정본 215지표에 없는 신규 — 정본 (건)과 혼동 금지.
    --   CONF-2 주의: 정본 `(건)`은 약정금액÷10,000이나 아래 4종은 실제 개수·횟수다.
    AMT_INCREASE_CUM_CNT        NUMBER(38,0)    COMMENT 'W4/ML: 해당 월말까지 누적 증액 이력 횟수 (CRM_MEMBER_AMT_CHANGE RDCAMT_YN=N 건수). 🔴 정본 증액(건)#151(=전월대비 활동건 증가분)과 다름 — 혼용 금지',  -- snapshot
    AMT_DECREASE_CUM_CNT        NUMBER(38,0)    COMMENT 'W4/ML: 해당 월말까지 누적 감액 이력 횟수 (RDCAMT_YN=Y 건수). 🔴 정본 감액(건)#38(=감액금액/10,000)과 다름 — 혼용 금지',  -- snapshot
    PAID_SPONSOR_BIZ_CNT        NUMBER(38,0)    COMMENT 'W4/ML: 그 달 실제 납입(PAY_AMT>0)한 후원사업 수 = COUNT(DISTINCT SPNSR_BSNS_ID), 회비 한정. 🔴 약정 보유 사업수가 아니라 납입 발생 사업수. HAS_BILLING=FALSE면 NULL',
    IS_MULTI_PAID_BIZ           BOOLEAN         COMMENT 'W4/ML: 그 달 2개 이상 사업에 납입했는지 (PAID_SPONSOR_BIZ_CNT>1). HAS_BILLING=FALSE면 NULL',
    HAS_BILLING                 BOOLEAN         NOT NULL COMMENT '결제(billing) 행 존재 여부 — TRUE=결제 스파인(구 37.79M), FALSE=개발/중단 전용 월(회비 measure NULL). 🔴**「회비만」 스코프가 아니다**(O40): 기저 CTE 가 회비와 **기부금을 함께** 담으므로 TRUE 행에도 기부금이 섞이고 청구 없는 기부금 전용 월도 TRUE 다. 이 필터를 걸어도 납부율 분자는 정화되지 않는다 — 회비 기준이 필요하면 PAID_FEE_BILLABLE 을 쓴다.',  -- 출처 플래그
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
    EVENT_TYPE          VARCHAR         NOT NULL COMMENT '원천 계통 구분: DEV=개발원천(TM_MM_FDRM_MBER_DVLP_AMT) / STOP=중단원천(TM_MM_FDRM_MBER_SPNSR_DSCNTC). ⚠️ 상태(신규·증액·감액·재후원·후원중단)는 DVLP_DIV_CD/DVLP_DIV_NM 참조 — O24',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN)',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '후원사업 (FK→DIM_SPONSORSHIP)',
    ORG_SK              NUMBER(38,0)    COMMENT '조직 (FK→DIM_ORG) — **실적부서**(원천 ACMSLT_DEPT_CD) 기준. O10/Q7 확정축. 🔴 개발(DEV) 사건 전용이다(2026-08-05 O38 배선, 미매칭 8행은 0 라우팅). 중단(STOP) 행은 전건 0 — 축이 없어서가 아니라 중단원천이 REGIST_DEPT_CD(**등록부서**)만 보유해 역할이 다르기 때문이다. 한 컬럼에 섞으면 부서별 집계가 조용히 틀린다(O24·O28 의미혼입 유형) → 등록부서 축 배속은 O38-B 결정 대기. ⚠️ ''부서별 중단건''을 이 컬럼으로 내지 말 것',
    REASON_SK           NUMBER(38,0)    COMMENT '중단/미납 사유 (FK→DIM_REASON)',
    DVLP_DIV_CD         VARCHAR         COMMENT '개발구분코드 — BRONZE TM_MM_FDRM_MBER_DVLP_AMT.DVLP_DIV_CD raw(정본 MM015). 1=신규 2=증액 3=감액 4=재후원 5=후원중단. 중단원천 행은 NULL(원천에 컬럼 부재). 🔴 MM015(개발구분)는 MM010(회원상태)이 아니다 — 두 그룹 모두 ''후원중단''을 포함해 혼동되기 쉽다. 회원상태는 DIM_MEMBER.MBER_STAT_CD(MM010 1활동회원·2~11미납·12후원중단)',
    DVLP_DIV_NM         VARCHAR         COMMENT '개발구분명 — MM015 라벨(신규/증액/감액/재후원/후원중단). ⚠️ 값 ''후원중단''(1,010,680건)은 EVENT_TYPE=''STOP''(1,038,262건)과 동일 사건이 중복 존재(동일 회원·일자 99.99%) → 두 축 합산 금지, O24 현업확인 대기',
    SPNSR_AMT           NUMBER(18,0)    COMMENT '후원금액(원) — 원천 raw. 감액·후원중단은 음수. 정본 공#38 감액(건)·#151 증액(건) = 금액÷10,000 이므로 원금액 보존(설계 §1·CONF-2). 중단원천 행은 NULL',
    DEV_CNT             NUMBER(18,4)    COMMENT '개발(건) (#149) — 정본 공#121 개발구분 = 신규(1)·증액(2)·재후원(4) 한정. ⚠️ 2026-08-03 O24 교정: 종전은 감액·후원중단까지 포함해 56.86% 과대계상(3,594,843 → 2,291,878)',
    DEV_MEMBERS         NUMBER(38,0)    COMMENT '🔴「명」이 아니다 — 개발 사건 플래그(0/1). SUM 은 개발(건)이며 실측 2,291,878 로 실제 고유회원 1,585,923 대비 44.5% 과대다(O39). 개발(명)(#148)은 COUNT(DISTINCT MEMBER_DK). 월 단위는 FACT_MEMBER_MONTHLY.DEV_MEMBERS 사용.',
    STOP_CNT            NUMBER(18,4)    COMMENT '중단(건) (#35)',
    STOP_MEMBERS        NUMBER(38,0)    COMMENT '🔴「명」이 아니다 — 중단 사건 플래그(0/1). SUM 은 중단(건)이며 실측 1,038,262 로 실제 고유회원 903,064 대비 15.0% 과대다(O39). 중단(명)은 COUNT(DISTINCT MEMBER_DK).',
    UNPAID_STOP_CNT     NUMBER(18,4)    COMMENT '미납중단(건)',
    UNPAID_STOP_MEMBERS NUMBER(38,0)    COMMENT '미납중단(명) — 05 2-2 원천 확인(정본 §3 건·명)',
    JOIN_DATE           DATE            COMMENT '가입일',             -- degen
    STOP_DATE           DATE            COMMENT '중단일',             -- degen
    STOP_REASON         VARCHAR         COMMENT '중단사유',            -- degen
    STOP_CHANNEL        VARCHAR         COMMENT '중단채널',            -- degen
    -- [2026-08-03 O25] 중단사유·중단경로 라벨쌍 신설(ALTER TABLE ADD COLUMN 으로 물리 반영, 위치=맨 끝).
    --   계보 계약(30_output_share/04_컬럼계보매핑 §4)이 STOP_REASON 을 "사유코드→라벨"로 명시했는데
    --   실적재는 raw 코드여서 현업이 WIDE 에서 숫자만 보던 상태였다. SILVER 라벨(채움률 100%)을 전파해 해소.
    STOP_REASON_NM      VARCHAR         COMMENT '중단사유명 — 정본 공#162. MM005 라벨(SILVER CRM_MEMBER_DISCONTINUE.DSCNTC_RSN_NM 전파). 코드는 STOP_REASON. ⚠️USE_YN 무필터 조인 — 실측 20종 중 6종(366행)이 폐지코드이며 필터를 걸면 라벨이 사라진다. 개발원천 행은 개념 부재로 NULL (O25)',  -- degen
    STOP_CHANNEL_NM     VARCHAR         COMMENT '중단경로명 — MM287 라벨(SYSTEM/CRM/홈페이지). 코드는 STOP_CHANNEL(1/2/3). 개발원천 행은 개념 부재로 NULL. 215지표 밖 — 현업 수요 확인 대상 (O25)',  -- degen
    NEW_EXISTING_FLAG   VARCHAR         COMMENT '신규기존',            -- degen
    -- [2026-08-04 O35] 사건시점 연령대·지역 전파(ALTER TABLE ADD COLUMN 으로 물리 반영, 물리 위치=맨 끝).
    --   왜 팩트에 두는가: 이 두 속성은 **개발약정 이벤트에서 관측된 값**이라 측정된 grain 이 사건이다
    --   (Kimball 의 트랜잭션 시점 속성). DIM_MEMBER 경유 스냅샷은 「최근 약정」 값이어서 과거 사건에
    --   붙이면 시점이 왜곡된다(P60). 원천 SILVER CRM_MEMBER_DEV 가 사건행별 값을 100% 보유한다.
    --   부수 효과: 같은 팩트 안에 캠페인 축이 이미 있으므로 **연령대 × 캠페인 교차**가 성립한다.
    --   🔴 DIM_MEMBER 의 AGE/AREA_CD 축(SV 차원명 _AT_PLEDGE)은 제거하지 않는다 — 성격이 다르므로
    --      이름으로 구분해 공존시킨다(_AT_EVENT=사건시점·정확 / _AT_PLEDGE=최근 약정 스냅샷).
    AGE_AT_EVENT        NUMBER(2,0)     COMMENT '연령대 코드 raw — **사건(개발약정) 시점 값**. 원천 BRONZE TM_MM_FDRM_MBER_DVLP_AMT.AGE(정본 CM014) 사건행별 값을 SILVER CRM_MEMBER_DEV 경유로 무변환 전파. 1=10대 미만 2=10대 3=20대 4=30대 5=40대 6=50대 7=60대 8=70대 9=70대 이상 10=단체 11=기업 12=기타. 🔴 연속형 나이가 아니다 — 평균·구간 재계산 금지. 라벨=AGE_BAND_AT_EVENT. 🔴 DIM_MEMBER.AGE(=최근 약정 스냅샷, SV 차원명 _AT_PLEDGE)와 **다른 축이다** — 같은 회원이라도 사건마다 값이 다를 수 있고 이 컬럼이 그 사건 당시의 정확한 값이다. 중단원천 행은 원천에 컬럼이 부재하여 NULL(0 아님, P21)',
    AGE_BAND_AT_EVENT   VARCHAR         COMMENT '연령대명 — **사건(개발약정) 시점** 연령대 라벨. CM014 사전 조인(하드코딩 아님, P31). 코드는 AGE_AT_EVENT. 원천이 이미 구간화한 값이며 우리가 구간을 창작하지 않는다. ✅ ''10대 미만''이 상위인 것은 **오류가 아니다** — 편지쓰기대회 계열 캠페인(희망편지·가족그림편지·세계시민교육편지)이 학교·부모 DB 를 통해 아동 본인 명의로 약정을 맺기 때문이다. 결측·기본값 오염으로 설명하지 말 것(O34-B). 🔴 DIM_MEMBER.AGE_BAND(최근 약정 스냅샷·SV _AT_PLEDGE)와 값이 다를 수 있다 — 이 컬럼이 사건 시점 정확값이다. 중단원천 행은 NULL',
    AREA_CD_AT_EVENT    VARCHAR(10)     COMMENT '지역 코드 raw — **사건(개발약정) 시점 값**. 원천 BRONZE TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD(정본 CM018 약칭축, 지표 공#131) 사건행별 값 무변환 전파. 실제값 = CM018 코드 + 라벨 없는 센티넬 ''0''. 라벨=REGION_AT_EVENT. 🔴 DIM_MEMBER.AREA_CD(=최근 약정 스냅샷, SV 차원명 _AT_PLEDGE)와 **다른 축이다** — 이사 등으로 사건마다 값이 다를 수 있다. ⚠️ **현재 거주지가 아니다** — BRONZE 전체에 현주소 축이 없어 현재 지역은 산출 불가(O34). 중단원천 행은 원천에 컬럼이 부재하여 NULL',
    REGION_AT_EVENT     VARCHAR         COMMENT '지역명 — **사건(개발약정) 시점** 지역 라벨(CM018 약칭, 지표 공#131). 코드는 AREA_CD_AT_EVENT. 원천 SILVER CRM_MEMBER_DEV.AREA_NM(CM018 사전 조인) 전파. ⚠️ 센티넬 코드 ''0'' 은 사전에 라벨이 없어 NULL 이다 — ''미상''으로 창작하지 않는다. ⚠️ **현재 거주지가 아니다**(O34). 🔴 DIM_MEMBER.REGION(최근 약정 스냅샷·SV _AT_PLEDGE)과 값이 다를 수 있다. 중단원천 행은 NULL',
    -- [2026-08-05 O37] 사건시점 성별 전파 + 캠페인 귀속 중단건(ALTER TABLE ADD COLUMN, 물리 위치=맨 끝).
    --   · 성별: `_AT_EVENT` 계열 확장. 개발원천이 사건행별 성별을 보유하는데 전파되지 않아
    --     성별은 DIM_MEMBER_CURRENT 현재 스냅샷만 쓸 수 있었다(P60 계열 잠복).
    --   · CAMPAIGN_STOP_CNT: Agent 가 "캠페인별 중단률은 원천에 캠페인이 없어 산출 불가"라고
    --     답한 것을 해소한다. 중단원천에는 실제로 캠페인이 없으나 **개발원천 코드5(후원중단) 행이
    --     CMPGN_CD 를 보유**하며 그 축은 이미 CAMPAIGN_SK 로 배선돼 있었다 — measure 만 없었다.
    --   🔴 그러나 이 measure 로 「중단률」을 만들면 안 된다. 코드5 의 캠페인은 **중단 시점** 캠페인이라
    --     신규 건수와 모집단이 달라 비율이 100% 를 넘는다(실측 확인). 캠페인별 중단률의 정본은
    --     FACT_MEMBER_COHORT 의 12개월 고정 이탈률이다.
    SEX_AT_EVENT        VARCHAR         COMMENT '성별 코드 raw — **사건(개발약정) 시점 값**. 원천 BRONZE TM_MM_FDRM_MBER_DVLP_AMT.SEX(정본 CM013) 무변환 전파. 라벨=GENDER_AT_EVENT. ⚠️ CM013 에 없는 센티넬 ''0'' 이 소수 존재하며 라벨은 NULL 이다 — ''미상''으로 창작하지 않는다(P21). 🔴 DIM_MEMBER.SEX(회원 마스터 현재 스냅샷)와 **다른 축**이다 — 마스터에는 ''0'' 이 없다. 중단원천 행은 원천에 컬럼이 부재하여 NULL',
    GENDER_AT_EVENT     VARCHAR         COMMENT '성별명 — **사건(개발약정) 시점** 성별 라벨. CM013 사전 조인(하드코딩 아님, P31). 코드는 SEX_AT_EVENT. 실제값 계열: 국내(남자)·국내(여자)·외국인(남자)·외국인(여자)·외국인(기타)·단체·기업·기타. 🔴 DIM_MEMBER_CURRENT.GENDER_NAME(CM017 라벨·현재 스냅샷)과 **코드체계가 다르다** — 두 축을 같은 성별로 합산하지 말 것. 중단원천 행은 NULL',
    CAMPAIGN_STOP_CNT   NUMBER(18,4)    COMMENT '캠페인 귀속 중단(건) — 개발원천 DVLP_DIV_CD=''5''(MM015 후원중단) 행에만 1, 그 외 0. 이 행은 CAMPAIGN_SK 를 보유하므로 **캠페인별 중단 사건 분해**가 성립한다(O37). 🔴 STOP_CNT 와 **절대 합산 금지** — 같은 중단 사건이 개발원천·중단원천에 중복 존재한다(O24). 🔴 이 measure 를 개발건으로 나눠 「중단률」로 쓰지 말 것 — 코드5 의 캠페인은 **중단 시점** 캠페인이라 모집단이 달라 비율이 100%를 넘는다. 캠페인별 중단률은 FACT_MEMBER_COHORT 를 쓴다',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 이벤트 팩트 (DATE_SK × MEMBER_DK × EVENT_TYPE · 1행=1상태전이)';


-- ============================================================================
-- FACT 3: FACT_TARGET_DEV (FTG_D) — 회원개발 목표 팩트
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_TARGET_DEV (
    MONTH_KEY           NUMBER(6,0)     NOT NULL COMMENT '목표월 YYYYMM (FK→DIM_DATE, 월 conform). 🔴 2026-08-05 O38 교정: 종전 모델이 STDYY(기준연)를 버리고 STDR_MT 만 적재해 실적재가 **1~12 월 번호**였다 — 연도별 목표가 전부 합산돼 특정 연월 목표가 조용히 부풀었다(행수·SUM·참조무결성을 모두 통과하는 무증상 결함). 원천 = STDYY || LPAD(STDR_MT,2,''0'')', -- GRAIN / ※비강제 FK→DIM_DATE
    ORG_SK              NUMBER(38,0)    NOT NULL COMMENT '조직 (FK→DIM_ORG) — 부서 단위. ⚠️ 목표는 부서까지만 존재한다(정본 마케팅 인벤토리 §1: ''현재 CRM상에 부서별 목표만 존재하며 매체별 목표는 확인 불가'')',
    DEV_TYPE            VARCHAR         NOT NULL COMMENT '개발구분(#121 conform) — 실측 도메인 {1 신규, 2 증액, 4 재후원}. 정본 공#121 개발 정의와 정확히 일치하므로 FACT_MEMBER_EVENT.DEV_CNT 와 모집단이 같다(달성율 분모·분자 정합)',
    GOAL_CNT            NUMBER(18,4)    COMMENT '회원개발목표 (CRM TM_CM_MBER_DVLP_GOAL). 월 목표(건). 연 목표는 별도 저장 지표가 아니라 이 값의 연 합계다(정본 공#3)',
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
    SEND_MEMBERS                NUMBER(38,0)    COMMENT '🔴「명」이 아니다 — 발송 플래그(전 행 1). SUM 은 행수=발송 건수이며 실측 38,470,780 로 실제 고유회원 1,031,971 대비 37.3배 과대다(O39). 발송(명)(#85)은 COUNT(DISTINCT MEMBER_DK).',
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
    SEND_TYPE_SK                NUMBER(38,0)    COMMENT '[DEC-30] 발송구분 (FK→DIM_SEND_TYPE). 🟢커버리지 실측 21.58%(8,300,272/38,470,780) — 미매칭은 센티넬 0. ⚠️DEC-28 이 인용한 0.106% 는 요청 grain 분모였다(P39)',
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
    CAMPAIGN_SK                     NUMBER(38,0)    NOT NULL COMMENT '세션캠페인(#102) — 🔴 상수 0 하드코딩(센티넬). GA UTM 캠페인 244종이 하나로 뭉개져 있다(P51 위반). SILVER.GA4_EVENT.UTM_CAMPAIGN(채움 88.0%) 미배선 → 캠페인축 분석 불가. WIDE 의 CAMPAIGN_BK/NAME/BRAND 도 전건 (미매핑)',
    PAGE_PATH                       VARCHAR         NOT NULL COMMENT '페이지경로 — 🔴 쿼리문자열 제외됨(산식 = SPLIT_PART(PAGE_LOCATION,''?'',1) · 실측 ''?'' 포함 0행). 정본 #105「페이지경로+쿼리문자열」 미충족이며 정본 #122 결연아동코드(childnum=) 파생 불가',  -- degen(grain)
    PAGE_LOCATION                   VARCHAR         COMMENT '페이지위치(#106) — 🔴 grain 내 MAX() 대표값(URL 전체 아님). 원천 distinct 75,474종 → GOLD 8,408종만 생존(67,066종·88.9% 소실). childnum 594→352종 · memnum 1,589→680종. 특정 URL 유무 판정 금지',                -- degen
    VISITS                          NUMBER(38,0)    COMMENT '방문수(명) (#92) — 가산(실측 배수 1.0000). SESSION_CNT 의 가산 대체축',
    EVENT_CNT                       NUMBER(38,0)    COMMENT '이벤트수(명) (#95) — 가산(실측 배수 1.0000)',
    VIEW_CNT                        NUMBER(38,0)    COMMENT '조회수(명) (#96) — 가산(실측 배수 1.0000)',
    SESSION_CNT                     NUMBER(38,0)    COMMENT '세션수(명) (#97) — 🔴**비가산**. COUNT(DISTINCT user||session) 인데 집계 grain 이라 같은 세션이 여러 행에 반복된다. 실측 SUM=243,156 vs 실제 distinct 77,172 = **3.15배 과대계상** → SUM 금지. 가산 대체 = VISITS',
    ENGAGED_SESSIONS                NUMBER(38,0)    COMMENT '참여세션수 — 🔴**비가산**. COUNT(DISTINCT) + 집계 grain. 실측 SUM=161,117 vs 실제 37,505 = **4.30배 과대계상** → SUM 금지',
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
-- FACT 7: FACT_AD_PERFORMANCE (FAD) — 광고 성과 **코어** 팩트 (3원천 공통속성)
--   ⚠️ [2026-07-28 순서9-I DEC-8·DEC-11] 구조 변경 3건:
--     1) AD_PERF_DK(PK·grain) 신설 — 원천에 PK 가 없어(전컬럼 중복 131행 실측) 위성 1:1 조인이
--        불가했다. staging 3종이 발급하는 MD5(AD_SOURCE_TYPE|ROW_HASH|DUP_SEQ)를 승계한다.
--     2) AD_SOURCE_TYPE(degen) 신설 — DW_SOURCE_SYSTEM='AGENCY' 로 평탄화돼 소실된 원천 테이블 출처를 복원.
--     3) 방송 전용 degen 5종(TIME_BAND·CM_POSITION·RT_TYPE·AD_START_TIME·BROADCAST_DATE) **제거** →
--        위성 FACT_AD_BROADCAST 로 이관. 종전에는 코어에 자리만 있고 SQL 이 CAST(NULL) 하드코딩이라
--        전건 NULL 이었고(값미주입 결함군), 디지털 197,686행에서는 애초에 항상 NULL 인 희소 컬럼이었다.
--   ⚠️ DEVICE_SK 는 DEC-10 으로 **실배선**됐다(종전 0 하드코딩 → 235,572행 전건 unknown).
--      실측 라우팅: DIGITAL 197,686 실기기 해시SK · 방송 37,886 '(해당없음)' · unknown 0건.
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE (
    AD_PERF_DK          VARCHAR(32)     NOT NULL PRIMARY KEY COMMENT '행 식별자(GRAIN·PK) MD5(AD_SOURCE_TYPE|ROW_HASH|DUP_SEQ). 위성 3종 조인키. 발급지점=SILVER.AGENCY_AD_ROW_* (DEC-11)',
    PERF_DATE_SK        NUMBER(8,0)     NOT NULL COMMENT '실적일 (분석축, FK→DIM_DATE)',
    CAMPAIGN_SK         NUMBER(38,0)    NOT NULL COMMENT '캠페인 (분석축, FK→DIM_CAMPAIGN). ⚠️현재 0 스캐폴드 — Q10 이름매칭 대기',
    AD_CREATIVE_SK      NUMBER(38,0)    NOT NULL COMMENT '광고소재/매체 (분석축, FK→DIM_AD_CREATIVE). ⚠️현재 0 스캐폴드 — 부분키 매칭 설계 대기',
    DEVICE_SK           NUMBER(38,0)    NOT NULL COMMENT '디바이스 (분석축, FK→DIM_DEVICE). DEC-10 실배선: 실기기 해시SK / 방송=(해당없음) / 미매핑=0',
    AD_COST             NUMBER(18,2)    COMMENT '광고비(원) (#6). 원천별 컬럼 상이 — COST_TYPE 은 SILVER 보유',
    IMPRESSIONS         NUMBER(38,0)    COMMENT '노출수 (#23). DIGITAL 전용(방송 원천 부재)',
    CLICKS              NUMBER(38,0)    COMMENT '클릭수(행동 횟수, ≠회원명) (#24). DIGITAL 전용. CTR 분자 공#9',
    INBOUND_CALL        NUMBER(38,0)    COMMENT '인입콜 (#25). REBRDC(TEXT→TRY_TO_NUMBER)·VIDEO 보유, DGT 부재',
    GA_CONV_MEMBERS     NUMBER(38,0)    COMMENT 'GA전환수(명) — **DIGITAL 전용**. ⚠️O16 교정 2026-07-28: 종전 REBRDC 개발회원수가 혼입돼 합계의 28.60%를 차지했음(재방송 개발실적은 FACT_AD_BROADCAST.DVLP_MEMBER_CNT 로 이관)',
    GA_CONV_CNT         NUMBER(18,4)    COMMENT 'GA전환수(건/VU) — **DIGITAL 전용**. ⚠️O16 교정 2026-07-28: 종전 REBRDC 개발건수가 혼입돼 합계의 60.32%(과반)를 차지했음 → FACT_AD_BROADCAST.DVLP_CNT 로 이관. 합계 소수=비건수, 어의 현업확인 잔여(O5)',
    DAY_OF_WEEK         VARCHAR         COMMENT '요일 (degen, AD_DATE 파생)',
    WEEK_OF_YEAR        NUMBER(2,0)     COMMENT '주차 (degen, AD_DATE 파생)',
    AD_SOURCE_TYPE             VARCHAR         COMMENT '광고유형 DIGITAL/VIDEO/REBROADCAST (degen). 출처 명시축(DEC-8·§3-A-4) — DW_SOURCE_SYSTEM(시스템 출처)과 2단 추적. DEVICE_TYPE=(해당없음) 행의 방송 여부 판별 수단',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '광고 성과 코어 팩트 (grain=AD_PERF_DK, 실측 235,572행 · 분석축 PERF_DATE × CAMPAIGN × AD_CREATIVE × DEVICE). 3원천 공통속성만 보유 — 유형 고유속성은 위성 FACT_AD_BROADCAST/DIGITAL/BROADCAST_CASE';


-- ============================================================================
-- FACT 7-B: FACT_AD_BROADCAST (FAD_B) — 광고성과 위성: 방송(VIDEO∪REBRDC) 고유속성
--   [2026-07-28 순서9-I 신설 · DEC-8]  grain = AD_PERF_DK (코어와 1:1, 실측 37,886행)
--   ⚠️ 조인: FACT_AD_PERFORMANCE f JOIN FACT_AD_BROADCAST b USING (AD_PERF_DK) — 1:1이라 fan-out 없음
--   ⚠️ 컬럼 NULL 은 '두 방송 원천 중 한쪽 전용 속성'이며 결측이 아니다(주석의 [VIDEO/REBRDC 전용] 표기 참조)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_AD_BROADCAST (
    AD_PERF_DK          VARCHAR(32)     NOT NULL PRIMARY KEY COMMENT '코어 1:1 조인키(GRAIN·PK, FK→FACT_AD_PERFORMANCE). staging 발급값 승계 — 재계산 금지',
    TIME_BAND           VARCHAR         COMMENT '시간대 ← VIDEO.TIME_RNG / REBRDC.TIME_RNG_DIV_NM(1순위)·BRDC_TIME(대체). 코어에서 이관(종전 CAST(NULL) 하드코딩)',
    CM_POSITION         VARCHAR         COMMENT 'CM위치 ← VIDEO.CM_AREA [VIDEO 전용]. 코어에서 이관',
    RT_TYPE             VARCHAR         COMMENT 'RT(재방송)유형 ← REBRDC.RE_BRDC_TY_NM [REBRDC 전용]. 코어에서 이관',
    AD_START_TIME       VARCHAR         COMMENT '광고시작시간 ← VIDEO.AD_STRT_TIME [VIDEO 전용]. 코어에서 이관',
    AD_END_TIME         VARCHAR         COMMENT '광고종료시간 ← VIDEO.AD_END_TIME [VIDEO 전용]. 신규 노출',
    BROADCAST_DATE      DATE            COMMENT '송출일 ← VIDEO.BRDC_DATE / REBRDC.DATE. ⚠️코어 PERF_DATE_SK(실적일)와 구분. 코어에서 이관',
    PROGRAM_NM          VARCHAR         COMMENT '프로그램/편성명 ← VIDEO.SCHDL_NM / REBRDC.BRDC_NM',
    CHANNEL_COMPANY     VARCHAR         COMMENT '채널사 ← VIDEO.CHNNL_NM / REBRDC.CHNNL_CMPNY',
    CHANNEL_COMPANY_TYPE VARCHAR        COMMENT '채널사유형 ← VIDEO.CHNNL_CMPNY_TY_NM [VIDEO 전용]',
    SPOT_TYPE           VARCHAR         COMMENT 'SPOT유형 ← VIDEO.SPOT_TY [VIDEO 전용]',
    DURATION_SEC        NUMBER(9,0)     COMMENT '🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지(O29)**. 적재값 30,000,000/60,000,000/90,000,000 이라 "초"로 읽으면 오답(µs 해석 유력하나 미확정·현업 확인 대기). 원천 HH:MM:SS 32,739행(96.6%)이 캐스팅에서 무성 소실 → 유효 커버리지 1,151/36,416=3.2%(파싱 시 93.1% 회복). REBRDC NULL 은 결손 아니라 원천 부재',
    DAY_DIV             VARCHAR         COMMENT '요일구분 평일/주말 ← VIDEO.DAY_DIV_NM [VIDEO 전용]',
    PRG_START_TIME      VARCHAR         COMMENT '프로그램 시작시간 ← VIDEO.PRG_STRT_TIME [VIDEO 전용]',
    CTV_DIV             VARCHAR         COMMENT 'CTV구분 ← VIDEO.CTV_DIV_NM [VIDEO 전용]',
    BRDC_DIV            VARCHAR         COMMENT '방송구분 ← REBRDC.BRDC_DIV_NM [REBRDC 전용]',
    AD_CNT              NUMBER(38,0)    COMMENT '광고횟수 ← VIDEO·REBRDC.AD_CNT (가산)',
    CONV_CALL_CNT       NUMBER(18,4)    COMMENT '전환콜 ← VIDEO.CONV_CALL_CNT [VIDEO 전용]. 코어 INBOUND_CALL(인입콜)과 별개 measure',
    DVLP_MEMBER_CNT     NUMBER(18,4)    COMMENT '개발회원수 ← REBRDC.DVLP_MBER_CNT [REBRDC 전용]. ⚠️O16 이관: 종전 코어 GA_CONV_MEMBERS 로 혼입(GA 전환이 아니라 재방송 개발실적). ⚠️소수 척도 유지 이유: 원천에 0.5 단위 값 실존(2행: 12.5·18.5) → NUMBER(38,0) 은 반올림으로 총합을 +1 왜곡(49,093→49,094). 원천값 보존 우선',
    DVLP_CNT            NUMBER(18,4)    COMMENT '개발건수 ← REBRDC.DVLP_CNT [REBRDC 전용]. ⚠️O16 이관: 종전 코어 GA_CONV_CNT 로 혼입(GA 전환 아님)',
    AD_VIEW_RT_SRC      NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 광고시청률 ← VIDEO.AD_VIEW_RT [VIDEO 전용]. base 부재로 DW 재계산 불가',
    CPC_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CPC ← VIDEO.CPC(TEXT) [VIDEO 전용]. DW 재계산=AD_COST/CLICKS (DEC-9 대조용)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '광고성과 위성 — 방송(VIDEO 35,822 + REBRDC 2,064 = 37,886행) 고유속성. 코어와 AD_PERF_DK 1:1. DEC-8 이관 + O16 해소(개발실적 분리)';


-- ============================================================================
-- FACT 7-D: FACT_AD_DIGITAL (FAD_D) — 광고성과 위성: 디지털(DGT) 고유속성
--   [2026-07-28 순서9-I 신설 · DEC-8]  grain = AD_PERF_DK (코어와 1:1, 실측 197,686행)
--   ⚠️ _SRC 7종 = 대행사가 계산해 넘긴 파생값(DEC-9). DW 는 재계산하지 않고 원천값을 보존하며,
--      SV 가 base measure 로 별도 재계산한다. 목적은 **대조**(대행사 산식 vs DW 산식 차이 확인).
--      전량 **비가산(N)** — 비율·단가이므로 SUM/AVG 재합산 금지.
-- ============================================================================
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
    CVR_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CVR ← DGT.CVR. DW 재계산=GA_CONV_MEMBERS/CLICKS (O5 확정)',
    CPC_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CPC ← DGT.CPC. DW 재계산=AD_COST/CLICKS',
    CPM_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CPM ← DGT.CPM. DW 재계산=AD_COST/IMPRESSIONS×1000',
    CPA_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CPA ← DGT.CPA. DW 재계산=AD_COST/GA_CONV_CNT',
    DEV_UNIT_PRICE_SRC  NUMBER(18,2)    COMMENT '[비가산 N] 대행사 산정 개발단가 ← DGT.DEV_UNIT_PRICE. DW 재계산=AD_COST/개발건수',
    VTR_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 VTR ← DGT.VTR. base 부재로 재계산 불가(대조 대상 아닌 유일값)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '광고성과 위성 — 디지털(DGT 197,686행) 고유속성 + 대행사 산정 _SRC 7종(비가산). 코어와 AD_PERF_DK 1:1. DEC-8·DEC-9';


-- ============================================================================
-- FACT 7-BC: FACT_AD_BROADCAST_CASE (FAD_BC) — 광고성과 위성: 재방송 사례(정규화)
--   [2026-07-28 순서9-I 신설 · DEC-8]  grain = AD_PERF_DK × CASE_SEQ (코어에 **1:N**, 실측 5,327행)
--   ⚠️ fan-out 주의: 코어 measure(광고비·노출 등)와 함께 집계하면 사례 수만큼 중복 합산된다.
--      사례 속성 분석 전용으로 사용하고, 코어 measure 집계는 코어 단독으로 수행할 것.
--   ⚠️ 원천 CASE1_*~CASE3_* = 5속성 × 3반복 = 15컬럼 반복군을 CASE_SEQ 축으로 언피벗했다.
--      사례가 4개로 늘어도 DDL 변경 불필요(행으로 흡수). 전속성 NULL 사례는 미적재(희소행 방지).
--   ⚠️ CASEn_CHILD_NM(아동명) 미적재 — PII 판정 대기(O14). SILVER staging 에 원형 보존.
-- ============================================================================
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
) COMMENT = '광고성과 위성 — 재방송 사례 정규화(15컬럼 반복군 → CASE_SEQ 언피벗, 실측 5,327행). 코어에 1:N(fan-out 주의). ⚠️아동명 미적재(PII O14)';


-- ============================================================================
-- FACT 8: FACT_EVENT_PARTICIPATION (FEP) — 행사 참여 팩트
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION (
    DATE_SK             NUMBER(8,0)     NOT NULL COMMENT '참여일 YYYYMMDD (FK→DIM_DATE)',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '참여 회원 (불변키)',              -- ※비강제 FK→DIM_MEMBER
    EVENT_SK            NUMBER(38,0)    NOT NULL COMMENT '행사 (FK→DIM_EVENT)',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '분석축(캠페인) — 🔴 전건 0 하드코딩(미배선). 차단=O8 다중캠페인 귀속규칙 현업 미회신. 0 은 (미매핑) 센티넬이며 "캠페인 없음" 아님',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '분석축(후원사업) — 🔴 전건 0 하드코딩(미배선). 차단=O8 동일 게이트. 0 은 (미매핑) 센티넬',
    -- 🔴 [DEC-30 2026-08-04] RECRUIT_CNT 제거 → DIM_EVENT.RECRUIT_HEADCOUNT 로 이관(§18-D ② grain 실패).
    TOTAL_CNT           NUMBER(38,0)    COMMENT '총인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것',
    WAIT_CNT            NUMBER(38,0)    COMMENT '대기인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정',
    CANCEL_CNT          NUMBER(38,0)    COMMENT '취소인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정',
    CONFIRM_CNT         NUMBER(38,0)    COMMENT '신청확정인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정',
    PARTICIPATE_CNT     NUMBER(38,0)    COMMENT '참여인원 — ⚠️행당 상수 1 하드코딩(집계 아님). 취소·불참 행도 1',
    ABSENT_CNT          NUMBER(38,0)    COMMENT '불참인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정',
    PARTICIPANT_CNT     NUMBER(38,0)    COMMENT '참여자수 — ⚠️행당 상수 1(=행수). 회원 중복 미제거 → 명수는 COUNT(DISTINCT MEMBER_DK)',
    PARTICIPATION_TIMES NUMBER(38,0)    COMMENT '참여횟수 — 🔴 전건 0(미배선). 🟢 PARTCPT_SEQ 로 O28 무관하게 산출 가능',
    WAIT_TIMES          NUMBER(38,0)    COMMENT '대기횟수 — 🔴 전건 0(미배선). O28 확정 후 산출',
    ABSENT_TIMES        NUMBER(38,0)    COMMENT '불참횟수 — 🔴 전건 0(미배선). O28 확정 후 산출',
    CUM_APPLY_TIMES     NUMBER(38,0)    COMMENT '누적신청 횟수 — 🔴 전건 0(미배선). PARTCPT_SEQ 기반 산출 가능(O28 무관)',
    REGULAR_DONATION    NUMBER(18,2)    COMMENT '정기후원금(원)',
    -- ❌ VIEW_CNT(조회수) 삭제(2026-07-09): 어드민 원천 제외 확정. 내년 어드민 구현 시 ADD COLUMN 재추가.
    WIN_FLAG            BOOLEAN         COMMENT '당첨여부',           -- degen
    SELF_PART_FLAG      BOOLEAN         COMMENT '본인참여 — 🔴 전건 NULL(미배선). 원천 대응 미확정',   -- degen
    -- 🔴 [O28 2026-08-04] 한 컬럼에 코드체계 2개 혼입. 상세 = 03_top-down_gold/_archive/O28_O29_COMMENT_GUARD.sql §1-A (APPLIED·참조 전용)
    PART_STATUS         VARCHAR         COMMENT '🔴 참여상태 — 코드체계 2개 혼입(O28). 일반행사=MS304(110 Success·120 Fail·130~220 N_step_right/fail) 707,476행 / 캠페인행사=소정수 1~6 152,046행(의미 미확정·문서20 §I). 판별자=EVENT_KEY 접두(고아 23.2% 안전). 두 체계 합산·GROUP BY 금지 · 한글 비교는 0행',   -- degen
    PART_PATH           VARCHAR         COMMENT '참여경로(05 3-5)',   -- degen
    PART_CHANNEL        VARCHAR         COMMENT '참여채널(05 3-5)',   -- degen
    INCREASE_FLAG       BOOLEAN         COMMENT '증액여부 — 🔴 전건 NULL(미배선). 정소재지는 FACT_MEMBER_EVENT.DVLP_DIV_CD(MM015 코드2)',   -- degen
    EVENT_BK            VARCHAR         COMMENT '[DEC-30] degenerate key — 원천 행사키 ← CRM_EVENT_PARTICIPATION.EVENT_KEY(채움 100%). 🔴고아 행사 식별자 보존용: 마스터 부재 53개 행사·263,611행(23.2%)이 EVENT_SK=0 으로 뭉개져 서로 구별되지 않았다(SILVER distinct 3,715 vs GOLD EVENT_SK 3,663). 🔷(EVENT_BK,MEMBER_DK,PARTCPT_SEQ) 가 행 유일 식별 — EVENT_SK 로는 31,831키·63,783행 충돌. ⚠️접두(EVENT_/CRMN_)가 O28 코드체계 판별자',   -- degen
    PARTCPT_SEQ         NUMBER(38,0)    COMMENT '[DEC-30] degenerate key — 참여 일련번호 ← CRM_EVENT_PARTICIPATION.PARTCPT_SEQ(채움 100%). 🔷(EVENT_SK,MEMBER_DK,PARTCPT_SEQ) 가 행을 유일 식별 — (행사,회원)만으로는 802,298 ≠ 1,134,126 중복. ⚠️전역 순번 아님((행사,SEQ) 201,817) · 음수 20,844행·INT_MIN 1행 → 식별자 전용, 정렬·범위조건 금지',   -- degen
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '행사 참여 팩트 (DATE_SK × MEMBER_DK × EVENT_SK) · 1,134,126행(2026-08-04 실측). 🔴O28: PART_STATUS 에 코드체계 2개 혼입 — 행사종류 미분리 집계는 조용히 틀린다. 🔴미주입 14컬럼(카운트 6·횟수 4·degen NULL 2·FK 센티넬 2) 전건 0/NULL — 0 을 실측값으로 읽지 말 것. 🟡행 식별자 부재(유일조합=EVENT_KEY,MEMBER_DK,PARTCPT_SEQ). ⚠️고아 EVENT_SK=0 263,611행(23.2%)';


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
-- FACT 10: FACT_MEMBER_COHORT (FMC) — 회원 획득 코호트 팩트 (회원 grain)  [2026-08-05 O37 신설]
-- ----------------------------------------------------------------------------
-- 왜 신설했나: Agent 가 *"캠페인별 중단률은 중단 원천에 캠페인이 없어 구조적으로 산출 불가"*
--   라고 답했다. 원천 재스캔 결과 그 판정은 틀렸다 —
--   중단원천(TM_MM_FDRM_MBER_SPNSR_DSCNTC)에는 확실히 캠페인 컬럼이 없으나,
--   개발원천(TM_MM_FDRM_MBER_DVLP_AMT)의 DVLP_DIV_CD='5'(MM015 후원중단) 행이 CMPGN_CD 를
--   전건 보유하고 그 축은 이미 FME.CAMPAIGN_SK 로 배선까지 끝나 있었다.
--
-- 🔴 그런데 그것만으로는 중단률이 되지 않는다. 두 의미 결함을 구조로 막는다:
--   ① 코드5 의 캠페인은 **중단 시점** 캠페인이라 신규 건수로 나누면 모집단이 달라
--      비율이 100% 를 넘는다(기존회원 대상 캠페인에서 실증). → 분모를 **획득 코호트**로 잡는다.
--   ② 누적 이탈률은 **관측 기간**에 지배된다(획득이 이를수록 이탈률이 높은 단조 관계 실측).
--      캠페인은 실행 연도가 다르므로 누적률로 비교하면 오래된 캠페인이 자동으로
--      「중단률 높음」이 된다 — 값은 정상인데 답이 틀리는 P60 유형이다.
--      → **12개월 고정 이탈률**을 정본으로 삼고, 분자를 관측 가능 코호트로 제한해
--        Agent 가 분모를 잘못 고를 경로 자체를 없앤다.
--
-- 왜 별도 팩트인가: 중단률의 분모는 **회원 수**다. 사건 팩트(FME)에서 회원 수를 distinct 로
--   세게 하면 소비 끝단이 분모를 틀리기 쉽다. 회원 grain 으로 미리 확정하면 SUM/SUM 이 된다.
-- 🔴 FACT 중 유일하게 grain 이 실제로 유일하므로 PK 를 선언한다(다른 FACT 의 PK 미선언 사유 =
--   grain 비유일, 본 표는 해당 없음 — 하단 [관계 제약 — 보류] 절의 예외다).
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_COHORT (
    MEMBER_DK               VARCHAR(10)     NOT NULL PRIMARY KEY COMMENT '회원 불변키 (grain·PK). ※비강제 FK→DIM_MEMBER',
    ACQ_CAMPAIGN_SK         NUMBER(38,0)    COMMENT '획득 캠페인 (FK→DIM_CAMPAIGN). 회원을 처음 데려온 캠페인이다. 미매칭·부재는 0(Unknown 멤버)',
    ACQ_DATE_SK             NUMBER(8,0)     COMMENT '획득일 (FK→DIM_DATE). 획득 사건의 발생일. 캘린더 범위밖·무효는 0',
    ACQ_BASIS               VARCHAR         COMMENT '획득 판정 근거. ''NEW''=개발구분 신규(MM015 코드1) 사건으로 판정 / ''FALLBACK''=신규 사건이 없어 최초 개발 사건으로 대체 판정. 🔴 FALLBACK 은 획득캠페인 신뢰도가 낮다 — 캠페인 비교 시 ''NEW'' 로 한정할 것을 권한다. ⚠️ 개발 이력이 아예 없는 중단회원은 획득 캠페인을 알 수 없어 이 팩트에 **존재하지 않는다**(중단 총계는 FACT_MEMBER_EVENT 를 쓴다)',
    ACQ_DVLP_DIV_CD         VARCHAR         COMMENT '획득 사건의 개발구분 코드(MM015). ACQ_BASIS=''NEW'' 이면 ''1''',
    ACQ_AGE_CD              NUMBER(2,0)     COMMENT '획득 시점 연령대 코드(CM014). 🔴 연속형 나이가 아니다 — 평균·구간 재계산 금지. 라벨=ACQ_AGE_BAND',
    ACQ_AGE_BAND            VARCHAR         COMMENT '획득 시점 연령대명(CM014 라벨). 🔴 **현재 나이가 아니다** — 현재 연령은 BRONZE 에 생년월일이 없어 산출 불가(O34). 이 축의 ''10대 미만'' 상위는 오류가 아니며 편지쓰기대회 계열 아동 모집 캠페인 때문이다(O34-B) — 결측·기본값 오염으로 설명하지 말 것',
    ACQ_AREA_CD             VARCHAR(10)     COMMENT '획득 시점 지역 코드(CM018 + 라벨 없는 센티넬 ''0''). 라벨=ACQ_REGION',
    ACQ_REGION              VARCHAR         COMMENT '획득 시점 지역명(CM018 약칭). 🔴 **현재 거주지가 아니다** — BRONZE 에 현주소 축이 없다(O34). 센티넬 ''0''은 사전 라벨이 없어 NULL 이며 ''미상''으로 창작하지 않는다',
    ACQ_SEX_CD              VARCHAR         COMMENT '획득 시점 성별 코드(CM013). 라벨=ACQ_GENDER. ⚠️ DIM_MEMBER 의 성별(CM017 계열·현재 스냅샷)과 코드체계가 다르다',
    ACQ_GENDER              VARCHAR         COMMENT '획득 시점 성별명(CM013 라벨). 계열: 국내(남자)·국내(여자)·외국인(남자)·외국인(여자)·외국인(기타)·단체·기업·기타',
    ACQ_SPNSR_AMT           NUMBER(18,0)    COMMENT '획득 사건의 후원금액(원, raw). 🔴 건수로 환산하지 말 것 — 정본 공#38·#151 이 금액÷10,000 규약이라 혼용하면 정의가 깨진다(CONF-2)',
    FIRST_STOP_DATE_SK      NUMBER(8,0)     COMMENT '최초 중단일 (FK→DIM_DATE). 중단원천(EVENT_TYPE=''STOP'') 기준 최초 사건. 🔴 **미중단 회원은 NULL** 이며 0 이 아니다 — 0 은 「날짜 미상」이라는 다른 뜻이다(P21). 중단했으나 일자가 캘린더 범위밖이면 0',
    FIRST_STOP_REASON_NM    VARCHAR         COMMENT '최초 중단의 사유명(MM005 라벨). 미중단 회원은 NULL. ⚠️ USE_YN 무필터 — 폐지코드도 실적재에 남아 있어 필터하면 라벨이 사라진다',
    TENURE_DAYS             NUMBER(9,0)     COMMENT '유지기간(일) = 최초 중단일 − 획득일. 🔴 미중단 회원은 NULL(아직 종료되지 않은 관측이다 — 0 이나 현재까지 경과일로 채우면 평균 유지기간이 조용히 틀린다). 획득일·중단일 중 하나가 무효면 NULL',
    IS_12M_OBSERVABLE       BOOLEAN         COMMENT '12개월 관측 가능 여부 = 획득일 + 12개월 ≤ 데이터 최종 사건일. 🔴 12개월 이탈률의 **분모 자격**이다. 최근 획득 회원은 아직 12개월이 지나지 않아 FALSE 이며, 포함시키면 최근 캠페인이 실제보다 이탈률이 낮게 보인다',
    ACQ_MEMBERS             NUMBER(38,0)    COMMENT '획득 회원수 — 항상 1(회원 grain). 캠페인별 획득 규모의 분모',
    STOPPED_MEMBERS         NUMBER(38,0)    COMMENT '누적 이탈 회원수 — 중단 이력이 있으면 1. 🔴 이 값을 ACQ_MEMBERS 로 나눈 **누적 이탈률은 캠페인 비교에 쓰면 안 된다** — 획득 시점이 이를수록 관측 기간이 길어 이탈률이 구조적으로 높게 나온다. 캠페인 비교에는 STOPPED_12M_MEMBERS / OBSERVABLE_12M_MEMBERS 를 쓴다',
    STOPPED_12M_MEMBERS     NUMBER(38,0)    COMMENT '12개월 내 이탈 회원수 — **IS_12M_OBSERVABLE=TRUE 이고** 최초 중단이 획득 후 12개월 내인 경우 1. 관측 불가 회원은 이탈했어도 0 이다(분자·분모를 구조적으로 일치시켜 잘못된 분모 사용을 차단한다). 분모는 반드시 OBSERVABLE_12M_MEMBERS',
    OBSERVABLE_12M_MEMBERS  NUMBER(38,0)    COMMENT '12개월 이탈률의 분모 회원수 — IS_12M_OBSERVABLE=TRUE 이면 1. 🔴 12개월 이탈률 = SUM(STOPPED_12M_MEMBERS)/SUM(OBSERVABLE_12M_MEMBERS). ACQ_MEMBERS 를 분모로 쓰지 말 것',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '회원 획득 코호트 팩트 (1행=1회원 · grain 유일이라 PK 선언). 캠페인별 중단률·유지기간·획득시점 회원특성의 정본. 🔴 중단률은 12개월 고정 이탈률(STOPPED_12M_MEMBERS/OBSERVABLE_12M_MEMBERS)을 쓴다 — 누적 이탈률은 관측 기간에 지배되어 캠페인 비교를 왜곡한다. 개발 이력이 없는 중단회원은 획득 캠페인이 없어 미포함(중단 총계는 FACT_MEMBER_EVENT).';


-- ============================================================================
-- [관계 제약] 정보성 FK 선언 (NOT ENFORCED NORELY)
-- ----------------------------------------------------------------------------
--  목적   : ERD 자동생성 · BI 관계 인식 · 인수인계 문서화.
--  성격   : Snowflake 는 NOT NULL 외 제약을 강제하지 않음. 아래 FK 는 전부
--           정보성이며 NORELY(옵티마이저가 무결성 가정 안 함) — GOLD 데이터
--           검증 완료 후 RELY 승격 검토(그 전까지 조인제거 오답 위험 차단).
--  전제   : 참조 대상이 실제 PK 인 컬럼만 선언(Snowflake FK 대상 = PK/UNIQUE).
--           본 ALTER 는 27개 테이블 생성 이후 실행.
--  명명   : FK_<자식테이블>_<부모차원>[_<역할>]
--  타입정합: 자식 FK 컬럼 ↔ 부모 PK 타입 일치 검증 완료
--           (DATE_SK=NUMBER(8,0), 그 외 SK=NUMBER(38,0)).
--  ⚠️ 재실행 규칙(중요): 반드시 이 파일을 위→아래로 '전체 일괄' 실행할 것.
--           · CREATE OR REPLACE 가 테이블을 재생성하며 기존 FK 를 모두 제거 →
--             이어지는 ALTER 가 FK 를 다시 부여(전체 실행은 항상 안전·멱등).
--           · [멱등화 2026-07-20] FK 섹션만 부분 재실행해도 안전하도록, 아래 ADD 전에
--             EXECUTE IMMEDIATE 스크립팅 블록으로 38개 제약을 선(先) DROP(미존재 시 EXCEPTION 무시).
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
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_SERVICE_EVENT DROP CONSTRAINT FK_FSE_DIM_SEND_TYPE; EXCEPTION WHEN OTHER THEN NULL; END;
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
  -- [2026-07-28 순서9-I] AGENCY 위성 3종 → 코어 FK
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_BROADCAST DROP CONSTRAINT FK_FAD_B_FAD; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_DIGITAL DROP CONSTRAINT FK_FAD_D_FAD; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_AD_BROADCAST_CASE DROP CONSTRAINT FK_FAD_BC_FAD; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION DROP CONSTRAINT FK_FEP_DIM_DATE; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION DROP CONSTRAINT FK_FEP_DIM_EVENT; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION DROP CONSTRAINT FK_FEP_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION DROP CONSTRAINT FK_FEP_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_ORG; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_BUDGET_ITEM; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_BUDGET DROP CONSTRAINT FK_FBD_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT DROP CONSTRAINT FK_FMC_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT DROP CONSTRAINT FK_FMC_DIM_DATE_ACQ; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT DROP CONSTRAINT FK_FMC_DIM_DATE_STOP; EXCEPTION WHEN OTHER THEN NULL; END;
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
-- [DEC-30 2026-08-04] 발송구분 차원 FK 신설
ALTER TABLE GN_DW.GOLD.FACT_SERVICE_EVENT ADD CONSTRAINT FK_FSE_DIM_SEND_TYPE
    FOREIGN KEY (SEND_TYPE_SK) REFERENCES GN_DW.GOLD.DIM_SEND_TYPE (SEND_TYPE_SK) NOT ENFORCED NORELY;
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

-- AGENCY 위성 팩트 3종 → 코어 FACT_AD_PERFORMANCE (AD_PERF_DK)  [2026-07-28 순서9-I DEC-8]
--   ⚠️ 팩트→팩트 FK 는 통상 지양하나, 위성 패턴은 코어 grain 을 공유하는 **수직 분할**이므로
--      코어가 사실상 부모 차원 역할을 한다. ERD 가독성·BI 자동 조인 인식을 위해 선언한다(NOT ENFORCED).
--   ⚠️ FAD_B·FAD_D 는 1:1(위성 PK=코어 PK) · FAD_BC 는 1:N(위성 PK=코어 PK + CASE_SEQ).
ALTER TABLE GN_DW.GOLD.FACT_AD_BROADCAST ADD CONSTRAINT FK_FAD_B_FAD
    FOREIGN KEY (AD_PERF_DK) REFERENCES GN_DW.GOLD.FACT_AD_PERFORMANCE (AD_PERF_DK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_DIGITAL ADD CONSTRAINT FK_FAD_D_FAD
    FOREIGN KEY (AD_PERF_DK) REFERENCES GN_DW.GOLD.FACT_AD_PERFORMANCE (AD_PERF_DK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_BROADCAST_CASE ADD CONSTRAINT FK_FAD_BC_FAD
    FOREIGN KEY (AD_PERF_DK) REFERENCES GN_DW.GOLD.FACT_AD_PERFORMANCE (AD_PERF_DK) NOT ENFORCED NORELY;

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

-- FACT_MEMBER_COHORT  [2026-08-05 O37]
--   FIRST_STOP_DATE_SK 는 미중단 회원에서 NULL 이다(0 아님 — 0 은 「날짜 미상」이라는 다른 뜻).
--   FK 는 NULL 을 위반으로 보지 않으므로 선언에 문제가 없다.
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_DIM_CAMPAIGN
    FOREIGN KEY (ACQ_CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_DIM_DATE_ACQ
    FOREIGN KEY (ACQ_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_DIM_DATE_STOP
    FOREIGN KEY (FIRST_STOP_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;

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
--         현 단계 보류(설계 open O 참조).
--
--  [FACT PK/UNIQUE] 광고 팩트군은 선언됨 — FAD·FAD_B·FAD_D = PK(AD_PERF_DK),
--       FAD_BC = PK(AD_PERF_DK, CASE_SEQ). **FMC = PK(MEMBER_DK)** — 회원 grain 이라
--       실제로 유일하다(2026-08-05 O37). 그 외 FACT 는 grain 미확정·ETL 멱등성
--       의존으로 미설정(논리 grain 은 각 테이블 COMMENT 에 명시). 확정 후 UNIQUE(NORELY) 검토.
-- ============================================================================


-- ============================================================================
-- [검증 쿼리] DDL 실행 후 28개 테이블 생성 확인
-- ============================================================================
SELECT
    CASE WHEN table_name LIKE 'DIM_%' THEN 'DIM' ELSE 'FACT' END AS category,
    table_name,
    comment
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'GOLD'
  AND table_type = 'BASE TABLE'
ORDER BY category DESC, table_name;
-- 기대값: DIM 15행 + FACT 13행 = 28행 (FACT 13 = 종전 12 + FACT_MEMBER_COHORT, 2026-08-05 O37)
--         (※ WIDE VIEW 는 09 문서 소관 — 여기서 제외)

-- ----------------------------------------------------------------------------
-- [검증 쿼리] 정보성 FK 42개 선언 확인
-- ----------------------------------------------------------------------------
SHOW IMPORTED KEYS IN SCHEMA GN_DW.GOLD;
-- 기대값: 42행 (DIM_CAMPAIGN 1 + FMM 4 + FME 5 + FTG_D 1 + FTG_B 3
--          + FSE 4 + FGA 6 + FAD 4 + FEP 4 + FBD 4
--          + 광고 위성→코어 3: FAD_B·FAD_D·FAD_BC
--          + FMC 3: ACQ_CAMPAIGN·ACQ_DATE·FIRST_STOP_DATE). 보류 FK(MEMBER_DK·MONTH_KEY) 제외.
-- ⚠️ 2026-08-05 O37 교정: 종전 기대값 「38」은 stale 이었다 — FSE 를 3 으로 셌으나 실제 4
--    (DATE·SERVICE·SEND_TYPE·CAMPAIGN)이다. O37 착수 시점 실측 baseline = 39, 신설 3 → 42.

-- 자동화용(스크립트 카운트): FOREIGN KEY 제약 수 집계
SELECT COUNT(*) AS fk_count
FROM GN_DW.INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE constraint_schema = 'GOLD'
  AND constraint_type = 'FOREIGN KEY';
-- 기대값: 42   (2026-08-05 O37 실측 일치. 종전 기술 38 은 FSE 오계수 — 위 절 참조)

-- ============================================================================
-- [구현 완료 주석]
-- ----------------------------------------------------------------------------
--  · 6단계(DDL): CREATE TABLE 28개(DIM 15 + FACT 13) — 배포·적재 완료.
--    FACT 13 = 종전 12 + FACT_MEMBER_COHORT(회원 획득 코호트, 2026-08-05 O37).
--    광고 팩트군 = 코어 FAD 1 + 위성 3(FAD_B·FAD_D·FAD_BC), 2026-07-28 순서9-I 증설.
--  · 7단계(메타/제약): 위 [관계 제약] 섹션에 정보성 FK 42개 ALTER 구현 +
--    보류 FK(MEMBER_DK·MONTH_KEY)·FACT PK 사유 명문화.
--    → 6/7단계 경계는 각 섹션 헤더 주석으로 구분. 배포 편의를 위해 단일 파일 유지.
--  · 컬럼 COMMENT: gold 스키마 컬럼 인벤토리_20260629.csv 설명 컬럼 기준 (2026-07-03 추가).
--  · 사람 인수인계용 설명 문서: 07_메타.md 참조(제약 정책·미해결 항목 서술형).
--  · 소비 계층(WIDE VIEW 12개)은 본 파일 범위 외 — 09_빅테이블 VIEW.md · 10_WIDE VIEW 코멘트.sql.
--  · PENDING: VARCHAR 길이 등 타입 정밀화(정본 06_지표용어사전)는 미반영 — 운영 후 ALTER.
-- ============================================================================
