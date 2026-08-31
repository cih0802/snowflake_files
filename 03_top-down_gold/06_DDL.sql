-- GN_DW.GOLD 스키마 전체 테이블 DDL에 정보성 FK/PK 제약 및 인수인계용 문서 주석 추가.
-- Co-authored with CoCo
/*
================================================================================
  GN_DW.GOLD — 전체 테이블 DDL
  🔴🔴 **[2026-08-31 O126] 테이블 수·FK 수를 이 헤더에 적지 않는다** — 적으면 stale 이 된다
     (`R3-9 ㉦` 「내가 만든 수를 문서에 박아 넣지 마라」). 실제로 두 곳이 낡아 있었다:
       · 종전 표제 「35개: DIM 20 + FACT 15」  ↔ 실측 **파일 선언 37 = DIM 20 + FACT 17**
       · 종전 실측대조 「선언 FOREIGN KEY 50 = 라이브 50」 ↔ 실측 **파일 실행 FK 56 = 라이브 56**
     ⚠️ 파일 본문은 정상이었다 — **틀린 것은 헤더 산문뿐**이다(본문 신뢰도와 무관하게 오도한다).
  🟢 **현재 값을 재는 방법**(값이 아니라 방법이 정본이다):
       · 파일 선언 테이블  = `grep -oE 'CREATE OR REPLACE TABLE GN_DW\.GOLD\.[A-Z_]+' 06_DDL.sql | sort -u | wc -l`
       · 파일 실행 FK      = `grep -cE '^\s+FOREIGN KEY' 06_DDL.sql`
         🔴 `grep -c 'FOREIGN KEY'` 를 쓰지 마라 — 헤더 산문·주석·집계 SQL 이 섞여 **과대**해진다
            (O126 실측: 전체 매칭 60 vs 실행 56 · 차이 4건이 전부 비실행 줄이었다).
       · 라이브 대조       = `python3 scripts/gold_erd_coverage_gate.py` (FK 3소스 + 고립 키 컬럼 판정)
       · ERD 문서 재발행   = `python3 scripts/gen_gold_erd.py` → `30_output_share/GOLD_ERD_테이블별.html`
  작성일   : 2026-07-02 (컬럼 COMMENT: 2026-07-03 / 배포·적재: 2026-07-20 / 광고 위성 3종 증설: 2026-07-28 순서9-I
             / **O45 조립축 증설: 2026-08-06** — DIM_MARKETING_CAMPAIGN·FACT_MEMBER_FEE 신설 + 신규 컬럼 3 + FK 8
             / **O53 GOLD 최종형: 2026-08-10** — DIM_MONTH 신설 + DIM_MEMBER_CURRENT·DIM_MEMBER_ACQUISITION 뷰→테이블
               + FACT_DEV_ACHIEVEMENT 신설(구 WIDE_DEV_ACHIEVEMENT 개명) · 신규 84컬럼)
  실측대조 : 2026-07-29 — INFORMATION_SCHEMA GOLD = BASE TABLE 27 + VIEW 12, FK 38 · 본 파일과 전 컬럼 일치.
             **2026-08-06 재대조 — BASE TABLE 31 + VIEW 16 · 본 파일과 전 컬럼·순서 일치(기계 대조).**
             (대조 방법: 06_DDL 파싱 결과 vs INFORMATION_SCHEMA · 컬럼명·순서 불일치 0.
              ⚠️ 초안에 「FK 53」이라 적었던 것은 미측정 오기였다 → 교정.
              🔴 이 절의 과거 수치는 **그 시점의 기록**이다 — 현재 값으로 인용하지 마라. 위 「재는 방법」을 써라.)
             **2026-08-10 O53 — 물리 반영·COMMENT 커버리지는 O53 2단계 스캔으로 판정한다.**
             🆕 **2026-08-31 O126 재대조 — 파일 선언 37테이블(DIM 20 + FACT 17) = 라이브 BASE TABLE 37 ·
                파일 실행 FK 56 = 라이브 56 · 불일치 0.** 도구 = `scripts/gold_erd_coverage_gate.py`.
                🔴 **다만 「FK 56 이 전량」이 아니다** — 월 conform 축(→ DIM_MONTH) **7건은 FK 선언이
                   불가하고**(비유일 참조 · 아래 [관계 제약] [보류] 참조) dbt relationships 테스트도 없다
                   ⇒ **선언 FK 만 근거로 ERD·BI 관계를 만들면 그 축이 통째로 빠진다.**
                   🟢 그 축의 정본 = `scripts/gold_erd_coverage_gate.py` 의 `LOGICAL_FK`(사람 판정 등재부).
  🔴 O53 신규 4블록은 **COMMENT 정본이 본 파일로 이동**했다(종전 정본 = dbt schema.yml `columns[]`).
     근거 = 사용자 결정(2026-08-10) + 재구축 시 본 파일이 replay 스크립트이므로 여기서 빠진 문안은 영구 소실된다.
     생성기 = `scripts/gen_o53_gold_ddl.py`(손 편집 금지 · 문안은 yml 에서 기계 이관 · 게이트 자기검사 9/9).
  ⛔ **부분 실행 규칙(O53)**: 이미 적재된 환경에서 본 파일을 **전체 재실행하지 말 것** — `CREATE OR REPLACE`
     가 기존 31테이블의 데이터를 날린다. 신규 블록만 실행하려면 `scripts/run_o53_new_tables.py` 를 쓴다.
     (신규 환경 재구축 시에는 전체 실행이 정상 경로다.)
  🔴 재현성 : 이 파일 + `04_silver_design/08_SILVER_테이블DDL_20260714.sql` + `dbt build` 만으로
             신규 환경이 현재 구조와 동일하게 재현된다. O45 임시 스크립트(`O45_ASSEMBLY_AXES.sql`)는
             본 파일에 **전량 이관 완료**되어 `_archive/` 로 이관했다(2026-08-06).
  참고 문서 : 03_top-down_gold/03_테이블 설계.md(DEC-8~13) · 09_빅테이블 VIEW.md(WIDE VIEW 12)
               05_필드 인벤토리.md · 08_silver의존.md
--------------------------------------------------------------------------------
  실행 규칙
  ─────────────────────────────────────────────────────────────────────────────
  1. **모든 DIM 을 생성한 뒤 FACT 를 생성한다**(개수는 위 「재는 방법」으로 재라 · O126).
     🔴 종전 문안 「DIM 20개를 모두 생성한 뒤 FACT 15개를 생성한다 … O53 로 20/15」의 **FACT 15 는 stale**
        이었다 — 실측 **FACT 17**(O126). 개수를 적어 둔 탓에 O53 이후 증설이 반영되지 않았다.
     이력: [2026-08-06 O45 로 15/12 → 17/14 · 2026-08-10 O53 로 DIM 20]
     O45 신규 DIM = DIM_MARKETING_CAMPAIGN · 신규 FACT = FACT_MEMBER_FEE.
     O53 신규 DIM = DIM_MONTH·DIM_MEMBER_CURRENT·DIM_MEMBER_ACQUISITION · 신규 FACT = FACT_DEV_ACHIEVEMENT.
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
-- DIM 18: DIM_MONTH — 월 차원 (DIM_DATE 월 축 사영 · 월팩트 fan-out 차단)
--   [2026-08-10 O53] 신설. 구조·COMMENT 소유주 = 본 파일 / 적재 = dbt(incremental append + pre-hook TRUNCATE).
--   🔴 merge 금지: 완전 재산출 차원에 merge 를 쓰면 grain 이동 시 구 행이 잔존한다(문서50 §300 R1 · P131).
--   PK(정보성) = MONTH_KEY
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MONTH (
    MONTH_KEY        NUMBER(6,0)     NOT NULL PRIMARY KEY COMMENT '월 conform 키 YYYYMM. 🔴🔴**월 팩트는 DIM_DATE 를 직접 조인하지 말고 이 차원을 쓴다** — DIM_DATE 는 일 grain 이라 월팩트와 조인하면 월당 일수만큼 행이 증폭되고 금액·건수가 그 배수로 과대해진다(SV 설계 원칙10·R1 fan-out 차단). 대상 팩트 = FACT_MEMBER_MONTHLY·FACT_BUDGET·FACT_TARGET_DEV·FACT_TARGET_BIZ. 🟢본 차원은 DIM_DATE 의 **월 축 사영**이므로 별도 원천이 없고 값이 갈라질 수 없다. ⚠️월키가 YYYYMM 규약을 벗어난 원천 행은 팩트에서 0 으로 라우팅된다 — 이 차원에는 그 멤버가 없다.',
    YEAR             NUMBER(4,0)     COMMENT '연도 — MONTH_KEY 의 연 부분. DIM_DATE.YEAR 와 동일 정의. 🔴연 집계의 축이며 회계연도가 아니라 역년이다.',
    MONTH            NUMBER(2,0)     COMMENT '월(1~12) — MONTH_KEY 의 월 부분. DIM_DATE.MONTH 와 동일 정의. ⚠️연을 가로질러 이 축만으로 집계하면 서로 다른 해의 같은 달이 합쳐진다 — 계절성 분석 외에는 MONTH_KEY 를 쓴다.',
    QUARTER          NUMBER(1,0)     COMMENT '분기(1~4) — DIM_DATE.QUARTER 와 동일 정의. 역년 기준이다.',
    DW_SOURCE_SYSTEM VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS       TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS     TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID      VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '월 차원 — DIM_DATE 의 **월 축 사영**(1행 = 1개월). 🔴🔴존재 이유는 **fan-out 차단**이다: 월 팩트(FACT_MEMBER_MONTHLY·FACT_BUDGET·FACT_TARGET_DEV·FACT_TARGET_BIZ)를 일 grain 인 DIM_DATE 에 직접 조인하면 월당 일수만큼 행이 증폭되고 금액·건수가 그 배수로 과대해진다(SV 설계 원칙10·R1). 월 팩트의 시간축은 **반드시 이 차원**을 쓴다. 🟢DIM_DATE 파생이라 별도 원천이 없고 값이 갈라질 수 없다 — 캘린더 범위는 DIM_DATE 와 동일하다. 🔴 [O53] 종전에는 SERVING.DIM_MONTH(helper 뷰)만 있었다. SV 가 GOLD 만 참조하도록 GOLD 로 올렸다 — SERVING helper 정리는 로드맵 7단계 소관이다.';


-- ============================================================================
-- DIM 2: DIM_ORG — 조직 차원 (SCD1)  ※ DEC-2: 조직 변경이력 소스 없음·as-was 요구 없음 → SCD2 예약컬럼 삭제(2026-07-07)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_ORG (
    ORG_SK              NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '조직 대리키 (=hash(DEPT_ID), PK)',
    ORG_DK              NUMBER(38,0)    NOT NULL COMMENT '불변 조직키 (=hash(DEPT_ID); SCD1이라 ORG_SK와 1:1)',
    -- CONF-4(2026-07-31 정본대조): D6 4단 중 CORP·TEAM은 부서 차원에서 산출 불가/보류. DIVISION은 "실적지부"로 재정의.
    CORP                VARCHAR         COMMENT '법인(#114) — 🔴 부서 차원에서 산출 불가(CONF-4). 부서→법인 1:1 아님: 한 부서에 복수 법인이 혼재한다(규모는 문서10 §26). 부서트리 LVL1도 부적합(ZA 구조노드가 법인 루트 미연결 + 직위 B000007 + 회원 없는 재단법인 혼재). 법인 축의 정본 원천 = 회원 속성 CPR_DIV_CD(CM019: I=사단/S=사복/A=통합) → DIM_MEMBER 또는 팩트 degen 배속 판단 필요. 값 NULL 유지',
    DIVISION            VARCHAR         COMMENT '실적지부 — 정본 용어사전 430(실적 지부 명)·431(실적지부(본부/지부) 구분). 🔴 재정의(CONF-4): 정본 보고서는 「본부/지부」 단독 사용이 없고 「실적지부(본부/지부)」·「실적지부」 형태로만 쓴다 → 조직트리(UPPER_DEPT_ID)가 아니라 실적트리(ACMSLT_UPPER_DEPT_ID) 기반. ⚠️ 산출 규칙 미확정 — 명칭기반 최근접 본부/지부 도달·미도달 규모는 문서10 §26 이며 명칭 판정은 범주오류 위험 → 규칙 확정까지 값 NULL 유지',
    DEPARTMENT          VARCHAR         COMMENT '부서(#116) — ✅ 정본 정합(용어사전 121·390·391 · 회원보고서 4개 · 마케팅보고서 2개). DEPT_NM 직접 대입(695종)',
    TEAM                VARCHAR         COMMENT '팀 — 🔴 보류(CONF-4). 정본 근거 = 지표 #152~155(연사업/추경 목표) "각 팀별" 뿐이고 용어사전·회원보고서·마케팅보고서 실질 0건(검출된 3건은 전부 "원천팀/원본팀" 편집주석). 그 원천 CRM_BIZ_TARGET은 미입고(E-6) → 소비처 부재. E-6 입고 시 재개. 값 NULL 유지',
    -- 원천 계통 컬럼 노출(추론 0) — O16/CONF-4 후속 규칙 확정 시 즉시 활용. SILVER CRM_ORG 에 이미 전파돼 있음.
    ACMSLT_UPPER_DEPT_ID VARCHAR        COMMENT '실적상위부서ID (원천 그대로) — 실적트리 부모. 조직트리 UPPER_DEPT_ID 와의 상이·동일·NULL 분포는 문서10 §26. 실적부서 대부분이 이 트리 LVL5 → DEC-5 「5th=실적부서」 근거',
    ACMSLT_DEPT_YN      VARCHAR         COMMENT '실적부서 여부 Y/N (원천 그대로) — Y 455개',
    USE_YN              VARCHAR         COMMENT '사용여부 Y/N (원천 그대로) — 🔴 N 이 과반이지만 제외 금지(O16): 팩트가 대량 참조(CRM_MEMBER.ACT_DEPT_CD 미사용 부서 · AMT_CHANGE 미사용 부서 — 규모는 문서10 §26) + 필터 시 트리 파편화(LVL1 종수 급증). 소비 측 필터용으로만 사용',
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
    REGION                  VARCHAR         COMMENT '지역 (#131) — CM018 약칭 라벨(서울/경기/인천/강원…). 코드=AREA_CD. [O27] 시점귀속(as-of): 그 버전 EFFECTIVE_FROM 이하 최근 개발약정의 값. 적중 규모는 문서10 §26. ⚠️ONCE(일시회원)는 개발약정에 행이 없어 NULL — ''(해당없음)''이 아니다(개념은 있고 원천이 없다). sentinel AREA_CD=''0'' 도 라벨 NULL',
    AGE                     NUMBER(2,0)     COMMENT '연령대 코드 raw — CM014(1~12). 🔴**연속형 나이가 아니다**: 1=10대미만·2=10대·3=20대·4=30대·5=40대·6=50대·7=60대·8=70대·9=70대이상·10=단체·11=기업·12=기타. 라벨=AGE_BAND. 판정근거: CM014 사전 종수 = 실적재 종수 전건 일치 · 독립 교차검증 AGE=''10''(단체)는 전건 SEX=''6''(단체) · AGE=''11''(기업)은 전건 SEX=''7''(기업) — 규모는 문서10 §26. ⚠️BRONZE TM_MM_FDRM_MBER_DVLP_AMT.AGE COMMENT ''연령''(NUMBER)은 오류다',
    AGE_BAND                VARCHAR         COMMENT '연령대 — CM014 라벨. 코드=AGE. [O27] 시점귀속(as-of) · 적중 규모는 문서10 §26. 🔴구간을 우리가 만든 것이 아니라 **원천이 이미 구간화**해 제공한다(DEC-28 §18-B 로 DEC-27 §17-C ''구간 정의 없음→보류'' 판정을 정정). ⚠️생년월일(MBER_BIRTHDAY) 입고는 이 컬럼의 선행조건이 아니다 — 시점정확 연령에만 필요. ⚠️ONCE 는 NULL',
    MBER_STAT_CD        VARCHAR         COMMENT '회원상태 원천코드 raw(#132, MM010) — 정본 명칭 ''회원상태코드''. SCD2 버전행은 TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD(변경상태코드), 무이력행은 TM_MM_FDRM_MBER_INFO.MBER_STAT_CD 에서 온다(둘 다 MM010). 라벨=MEMBER_STATUS_NAME',
    MBER_DIV_CD         VARCHAR         COMMENT '회원구분 원천코드 raw — BRONZE MBER_DIV_CD(MM018 1개인·2기업·3단체). 라벨=MEMBER_TYPE_NAME',
    MEMBER_TYPE_NAME    VARCHAR         COMMENT '회원구분명(라벨). 원천 CRM_CODE MM018: 1개인·2기업·3단체. 🟢**결측 경로가 없다** — 정기·일시 양쪽 원천이 이 코드를 갖고 사전 미등재 코드도 없어 전건 라벨화된다(빈 값·센티넬 없음). ⚠️앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러난다** — ''미상'' 같은 값을 만들어 덮지 않는다(R2-7-1)',
    MEMBER_STATUS_NAME  VARCHAR         COMMENT '회원상태명(라벨). 원천 CRM_CODE MM010: 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단. 🔴**빈 값이 두 가지 뜻으로 갈린다**: ①일시회원(MEMBER_TYPE=''ONCE'')은 회원상태 개념이 **원천에 없어** 센티넬 ''(해당없음)'' 이다 ②정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 🟢미매핑(코드는 있는데 사전에 없음)은 없다 — MM010 은 폐지코드가 없고 실적재가 사전과 일치한다. ⚠️''미상''은 쓰지 않는다 — 위 두 사건을 한 값으로 뭉개기 때문이다(R2-7-1·O26 교정)',
    MEMBER_STATUS_GROUP VARCHAR         COMMENT '회원상태 대분류(파생). MM010 코드 1→정상·2~11→미납·12→중단. 🔴빈 값의 뜻은 **상류 MEMBER_STATUS_NAME 에서 그대로 상속**된다: 일시회원(''ONCE'')은 ''(해당없음)'' · 정기회원 중 상태코드 결손 행은 NULL. ⚠️종전 규약(코드가 없으면 대분류를 문자열로 창작)은 폐기됐다 — 코드가 없는 자리에 대분류를 **만들지 않는다**(R2-7-1). 🔴원천 코드그룹이 아니라 DW 파생 축이다',
    PREV_MBER_STAT_CD       VARCHAR(10)     COMMENT '상태전이 **이전상태** 코드 raw — MM010. 현재상태=MBER_STAT_CD 와 짝지어 전이를 표현한다(이 SCD2 버전행이 곧 전이 사건이므로 fan-out 0). 원천=CRM_MEMBER_STATUS_HIST.BF_STAT_CD(전건 채움 · 종수 MM010 일치 · 규모는 문서10 §26). ⚠️이력 미보유행(FDRM 무이력·ONCE 전체)은 NULL — ''이전상태가 없다''가 아니라 ''이력이 없다''. ⚠️동일자 다중전이는 최종 전이로 축약된다(중간 단계 소실)',
    PREV_MEMBER_STATUS_NAME VARCHAR(100)    COMMENT '이전상태 라벨 — MM010. 코드=PREV_MBER_STAT_CD. 하드코딩 아니라 CRM_CODE 조인(P31). 원천 라벨 BF_STAT_NM 도 MM010 과 100% 일치하나 사전 조인을 정본으로 쓴다. ⚠️개발구분(MM015)은 다른 축 — FACT_MEMBER_EVENT.DVLP_DIV_NM',
    FIRST_JOIN_DATE     DATE            COMMENT '최초가입일=회원번호 생성일(#28)',
    FIRST_CAMPAIGN      VARCHAR         COMMENT '최초캠페인(#29)',
    JOIN_PATH_CD        VARCHAR         COMMENT '가입경로 원천코드 raw — BRONZE JOIN_PATH_CD(MM014). 라벨=ENROLL_PATH_NAME',
    ENROLL_PATH_NAME    VARCHAR         COMMENT '가입경로명(라벨). 원천 CRM_CODE MM014: 홈페이지/CRM/모바일웹/희망TV/외주콜센터/모바일앱/REG/EDU. 🔴**빈 값이 두 가지 뜻으로 갈린다**: ①일시회원(MEMBER_TYPE=''ONCE'')은 가입경로 개념이 **원천에 없어** 센티넬 ''(해당없음)'' ②정기회원(FDRM) 중 가입경로 코드만 결손인 행은 **NULL**. 🔴②는 회원상태 결손 행과 **같은 행이 아니다** — 상태는 정상인데 경로만 비어 있는 행이 따로 있다(두 컬럼의 NULL 을 한 사건으로 묶지 말 것). 🟢미매핑은 없다. ⚠️''미상''으로 채우지 않는다(R2-7-1)',
    FIRST_SPONSORSHIP       VARCHAR         COMMENT '최초 후원사업 — CRM_MEMBER_DEV 최소 발생일(OCCRRNC_DE)의 SPNSR_BSNS_ID. ''최초''는 시점 불변이라 as-of 불요(SCD1). 적중 규모는 문서10 §26. ⚠️ONCE 는 개발약정 부재로 NULL. ⚠️**현재 후원사업**은 제공하지 않는다 — 동시 다중후원이 정상이라(비중·최대는 문서10 §26) 단일값이 성립하지 않아 CURRENT_SPONSORSHIP 을 DROP 했다(O13 계열)',
    LAST_STOP_DATE          DATE            COMMENT '최종 중단일 — 원천 CRM_MEMBER_DISCONTINUE.SPNSR_DSCNTC_DE. 🔴**그 버전 시점까지의 as-of max** 다(단순 max 아님). 단순 max 는 미래 정보를 과거 버전에 누설해 예측 피처(LTV·유지기간 신4·6~8)를 오염시킨다. 적중 규모는 문서10 §26 — 중단 이력이 없는 회원·중단 이전 버전은 NULL',
    EFFECTIVE_FROM      DATE            COMMENT 'SCD2 유효시작',
    EFFECTIVE_TO        DATE            COMMENT 'SCD2 유효종료',
    IS_CURRENT          BOOLEAN         COMMENT '현재행 여부',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-03 DEC-27] SILVER CRM_MEMBER.MEMBER_TYPE 이 존재했는데 GOLD 모델 CTE 컬럼열거에서
    --   탈락해 있던 것을 복원(G3 결손 유형 — "모델O·SELECT 탈락"). ALTER TABLE ADD COLUMN 으로 물리 반영.
    MEMBER_TYPE         VARCHAR         COMMENT '회원 등록계통 구분 — SILVER CRM_MEMBER.MEMBER_TYPE 전파: FDRM=정기회원(TM_MM_FDRM_MBER_INFO) / ONCE=일시회원(TM_MM_ONCE_MBER_INFO) — 모집단 규모는 문서10 §26. 🔴 일시회원은 회원상태(MM010)·가입경로(MM014) 개념이 원천에 없다 — 상태 기반 분포·이탈률·예측 모집단은 FDRM 으로 한정할 것. ⚠️ MEMBER_TYPE_NAME(개인/기업/단체, MM018)은 이 컬럼의 라벨이 아니다 — 완전히 다른 축이며 코드는 MBER_DIV_CD 다'
) COMMENT = '회원 차원 (SCD2 · 회원 상태버전)';


-- ============================================================================
-- DIM 19: DIM_MEMBER_CURRENT — 회원 현재행 차원 (SCD2 IS_CURRENT 투영 · 분석가 기본 진입점)
--   [2026-08-10 O53] 신설. 구조·COMMENT 소유주 = 본 파일 / 적재 = dbt(incremental append + pre-hook TRUNCATE).
--   🔴 merge 금지: 완전 재산출 차원에 merge 를 쓰면 grain 이동 시 구 행이 잔존한다(문서50 §300 R1 · P131).
--   PK(정보성) = MEMBER_DK
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER_CURRENT (
    MEMBER_SK           NUMBER(38,0)    NOT NULL COMMENT 'DIM_MEMBER 의 **버전 대리키**. ⚠️이 테이블은 IS_CURRENT 행만 담으므로 회원 1명당 1값이지만, 그 의미는 여전히 ''현재 버전 행의 키''다 — 회원 식별에는 MEMBER_DK 를 쓴다(MEMBER_SK 는 재빌드 시 달라질 수 있다).',
    MEMBER_DK           VARCHAR(10)     NOT NULL PRIMARY KEY COMMENT '불변 회원키(조인용 자연키). 🔴모든 회원 팩트(FMM·FME·FSE·FEP·FMF)가 이 키로 조인한다. 🔴VARCHAR(10) 규약(O12/AC-1) — 원천 MBER_NO 최대길이 9 실측.',
    MEMBER_TYPE         VARCHAR         COMMENT '회원 **등록계통** 구분 — FDRM=정기회원(원천 `BRONZE_CRM.TM_MM_FDRM_MBER_INFO`) / ONCE=일시회원(원천 `TM_MM_ONCE_MBER_INFO`). 🔴🔴일시회원은 회원상태(MM010)·가입경로(MM014) 개념이 **원천에 없다** — 상태 기반 분포·이탈률·예측 모집단은 MEMBER_TYPE=''FDRM'' 으로 한정할 것. ⚠️MEMBER_TYPE_NAME(개인/기업/단체, MM018)은 이 컬럼의 라벨이 **아니다** — 완전히 다른 축이며 코드는 MBER_DIV_CD 다.',
    SEX                 VARCHAR         COMMENT '성별 원천코드 raw. 코드그룹 **CM013(성별)**. 코드사전 = 1국내(남자)·2국내(여자)·3외국인(남자)·4외국인(여자)·5외국인(기타)·6단체·7기업·8기타. 정기회원·일시회원 **양쪽 원천 모두 사전 전종이 등장**한다(일시회원은 소수의 NULL 이 있다). 🔴정본 비고가 ''성별만으로는 사용하지 않음''을 명시한다 — 성별 단일축은 GENDER_NAME 을 쓴다. 라벨 = SEX_NM·GENDER_NAME.',
    SEX_NM              VARCHAR         COMMENT 'CM013 **원천 라벨 그대로**(국내(남자)/국내(여자)/외국인(남자)/외국인(여자)/외국인(기타)/단체/기업/기타). 코드 = SEX. 🔴이 컬럼만이 **국내·외국인 축**을 보존한다 — GENDER_NAME(CM017)은 그 축을 지운다.',
    GENDER_NAME         VARCHAR         COMMENT '성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. [O51-D BRONZE 실측] CM017 은 CM013 과 코드 도메인이 동일(1~8)한 재라벨 그룹이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **라벨 5종**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 ''여성/남성/미상''은 5종을 3종으로 축약하고 법인·단체를 ''미상''으로 오라벨했다(O26 교정).',
    MBER_STAT_CD        VARCHAR         COMMENT '회원상태 원천코드 raw(정본 공#132 ''회원상태코드''). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · `TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD` 와 `TM_MM_FDRM_MBER_INFO.MBER_STAT_CD` **양쪽 모두 사전 전종이 등장**한다. SCD2 버전행은 CHN_STAT_CD, 무이력행은 MBER_STAT_CD 에서 온다. 🔴개발구분 MM015 가 아니다(두 그룹 모두 ''후원중단''을 포함한다). 🔴일시회원(ONCE)은 NULL. 라벨 = MEMBER_STATUS_NAME.',
    MEMBER_STATUS_NAME  VARCHAR         COMMENT '회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴**빈 값이 두 가지 뜻으로 갈린다 — 같은 값으로 읽으면 틀린다**: ①일시회원(MEMBER_TYPE=''ONCE'')은 회원상태 개념이 **원천에 없어** 센티넬 ''(해당없음)'' 이다(결측이 아니다) ②정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 🟢미매핑(코드는 있는데 사전에 없음)은 없다 — MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). ⚠️''미상''은 쓰지 않는다 — 개념 부재와 코드 결손을 한 값으로 뭉개기 때문이다(R2-7-1). ⚠️미납 단계(1~5)는 경과 차수이며 금액 규모가 아니다.',
    MEMBER_STATUS_GROUP VARCHAR         COMMENT '회원상태 **대분류**(파생): MM010 코드 1→''정상'' · 2~11→''미납'' · 12→''중단''. 🔴빈 값의 뜻은 **상류 MEMBER_STATUS_NAME 에서 그대로 상속**된다 — 일시회원(''ONCE'')은 ''(해당없음)''(상태 개념 부재) · 정기회원 중 상태코드 결손 행은 **NULL**. ⚠️종전 규약(코드가 없으면 대분류를 문자열로 창작)은 폐기됐다: 코드가 없는 자리에 대분류를 **만들지 않는다**(R2-7-1). 🔴신규미납(2~6)과 장기미납(7~11)을 한 값으로 묶는다 — 두 단계를 구분해야 하면 MEMBER_STATUS_NAME 을 쓴다. ⚠️원천 코드그룹이 아니라 DW 파생 축이다(DIM_MEMBER.sql 단일 소유).',
    MBER_DIV_CD         VARCHAR         COMMENT '회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**: 1개인·2기업·3단체. 정기회원·일시회원 **양쪽 모두 사전 전종이 등장**한다. 🟢독립 교차검증: `2`(기업)·`3`(단체) 의 행수가 `SEX`=''7''(기업)·''6''(단체) 와 **완전히 일치**한다. 🔴MEMBER_TYPE(FDRM/ONCE)과 다른 축이다. 라벨 = MEMBER_TYPE_NAME.',
    MEMBER_TYPE_NAME    VARCHAR         COMMENT '회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. 🟢**빈 값이 없는 축이다** — 정기·일시 양쪽 원천이 이 코드를 갖고 사전 미등재 코드도 없어 전건 라벨화된다(센티넬 ''(해당없음)''·NULL 모두 없다). ⚠️앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러난다** — ''미상'' 같은 값을 만들어 덮지 않는다(R2-7-1). 🔴🔴이름이 비슷한 MEMBER_TYPE(FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 이 테이블에 두 컬럼이 나란히 있어 특히 혼동되기 쉽다.',
    JOIN_PATH_CD        VARCHAR         COMMENT '가입경로 원천코드 raw. 코드그룹 **MM014(가입경로)**. 코드사전 = 1홈페이지·2CRM·3모바일웹·4희망TV·5외주콜센터·6모바일앱·7REG·8EDU 이나 실적재에는 **1·2·3·5·6·7 만 나타난다** — 🔴**4(희망TV)·8(EDU)는 실적재에 없다.** 🔴일시회원(ONCE)은 가입경로 개념이 원천에 없어 NULL. 라벨 = ENROLL_PATH_NAME.',
    ENROLL_PATH_NAME    VARCHAR         COMMENT '가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 🔴**빈 값이 두 가지 뜻으로 갈린다**: ①일시회원(MEMBER_TYPE=''ONCE'')은 가입경로 개념이 **원천에 없어** 센티넬 ''(해당없음)'' 이다 ②정기회원(FDRM) 중 가입경로 코드만 결손인 행은 **NULL** 이다. 🔴②는 MEMBER_STATUS_NAME 이 NULL 인 행과 **같은 행이 아니다** — 회원상태는 정상인데 경로만 비어 있는 행이 따로 있으므로 두 컬럼의 NULL 을 한 사건으로 설명하지 말 것. 🟢미매핑은 없다(실적재 코드가 모두 사전에 있다). ⚠️''미상''으로 채우지 않는다(R2-7-1).',
    FIRST_JOIN_DATE     DATE            COMMENT '최초가입일 = 회원번호 생성일(정본 공#28). ⚠️후원 개시일이 아니다 — 첫 개발약정일은 DIM_MEMBER_ACQUISITION.ACQ_DATE_SK 로 답한다.',
    FIRST_CAMPAIGN      VARCHAR         COMMENT '최초캠페인(정본 공#29). ⚠️획득 귀속 캠페인(DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_NAME)과 **판정 규칙이 다르다** — 획득 축은 개발구분 ''신규'' 사건(없으면 최초 개발 사건)을 근거로 정한다(ACQ_BASIS).',
    REGION              VARCHAR         COMMENT '지역명 — 코드그룹 **CM018** 약칭 라벨(정본 공#131). 코드 raw 는 DIM_MEMBER.AREA_CD. 🔴🔴**현재 거주지가 아니다** — 원천이 `CRM_MEMBER_DEV`(BRONZE `TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD`)의 **개발약정 시점 스냅샷**이다. 현주소 축은 BRONZE 에 없다(O34). 🔴**SCD2 축**이다 — 회원의 버전이 바뀌면 값이 달라질 수 있고, 이 테이블은 현재 버전 행의 값만 담는다. 🔴일시회원(MEMBER_TYPE=''ONCE'')은 개발약정 개념이 원천에 없어 **NULL** 이다 — 지역 분포는 MEMBER_TYPE=''FDRM'' 으로 스코프할 것(ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다 · P128). ⚠️센티넬 ''0'' 은 사전에 라벨이 없어 NULL 이며 ''미상''으로 창작하지 않는다. ⚠️획득 시점 지역축(DIM_MEMBER_ACQUISITION.ACQ_REGION)과 같은 원천이나 축의 이름과 용도가 다르다.',
    AGE_BAND            VARCHAR         COMMENT '연령대명 — 코드그룹 **CM014** 라벨. 코드 raw 는 DIM_MEMBER.AGE. 🔴🔴**연속형 나이가 아니다** — CM014 는 코드 12종(''10대 미만''·''10대''~''70대''·''70대 이상''·단체·기업·기타)이며 평균·구간 재계산을 하면 뜻이 깨진다. BRONZE `TM_MM_FDRM_MBER_DVLP_AMT.AGE` 의 원천 COMMENT ''연령''은 오류다. 🔴🔴**현재 나이가 아니다** — `CRM_MEMBER_DEV` 의 **개발약정 시점 스냅샷**이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). 🔴**SCD2 축**이다. 🔴일시회원(MEMBER_TYPE=''ONCE'')은 **NULL** — 연령 분포는 MEMBER_TYPE=''FDRM'' 으로 스코프할 것(P128). 🟢독립 교차검증으로 코드 해석이 확정됐다 — 단체 코드는 SEX 단체와, 기업 코드는 SEX 기업과 전건 일치한다. ⚠️사전 자체에 ''70대''와 ''70대 이상''이 의미 중복으로 공존한다.',
    FIRST_SPONSORSHIP   VARCHAR         COMMENT '최초 후원사업 식별자 raw ← `CRM_MEMBER_DEV.SPNSR_BSNS_ID`(BRONZE `TM_MM_FDRM_MBER_DVLP_AMT`). 🔴**라벨이 아니라 사업 ID** 다 — 사업명이 필요하면 DIM_SPONSORSHIP 을 조인하거나 DIM_MEMBER_ACQUISITION.ACQ_SPONSORSHIP_NAME 을 쓴다. 🔴🔴회비 **납입 대상** 후원사업(FACT_MEMBER_FEE.SPONSORSHIP_SK)과 **의미가 다르다** — 한 회원이 A 사업으로 가입한 뒤 B 사업에 낼 수 있다. 🔴일시회원(MEMBER_TYPE=''ONCE'')은 **NULL**(P128 스코프 주의). ⚠️최초 약정 기준이며 이후 사업 변경은 반영되지 않는다.',
    LAST_STOP_DATE      DATE            COMMENT '최종 중단일 ← `CRM_MEMBER_DISCONTINUE.STOP_DT`. 🔴**미중단 회원은 NULL** 이며 0 이나 특정 날짜로 채우지 않는다 — NULL 은 「아직 중단하지 않았다」는 1급 정보다(P21). 🔴**SCD2 축**이다 — 재후원·재중단이 있으면 버전마다 값이 다르고 이 테이블은 현재 버전 행의 값만 담는다. 🔴🔴**최초** 중단일이 아니다 — 최초 중단은 DIM_MEMBER_ACQUISITION.FIRST_STOP_DATE_SK 이고, 유지기간(TENURE_DAYS)의 분자는 그쪽이다. 두 축을 섞으면 재후원 회원의 유지기간이 조용히 늘어난다. 🔴일시회원(MEMBER_TYPE=''ONCE'')은 **NULL**(P128 스코프 주의). ⚠️중단 총계·중단 사유는 FACT_MEMBER_EVENT 를 쓴다 — 이 컬럼은 회원 단위 최종 상태다.',
    EFFECTIVE_FROM      DATE            COMMENT 'SCD2 유효 시작 시각. 🔴이 테이블은 현재행만 담으므로 이 값은 ''현재 상태가 시작된 시점''이다. 🔴과거 시점 상태가 필요하면 이 테이블이 아니라 DIM_MEMBER 를 EFFECTIVE_FROM/EFFECTIVE_TO 로 시점조인할 것 — 예측·피처 생성은 그 시점조인이 정답이며 현재값을 과거 행에 붙이면 정답 누설이다.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별(공통감사). 업무 축이 아니다 — GROUP BY 대상이 아니다.',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각(공통감사). 업무 축이 아니다.',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각(공통감사). ⚠️원천 변경 시각이 아니라 DW 적재 시각이다.',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id(공통감사). 재현·감사 추적용.'
) COMMENT = '🟢 GOLD 직접조회 분석가의 기본 진입점 — 회원 1명 = 1행. DIM_MEMBER 는 **SCD2 다버전**이므로 FACT 와 MEMBER_DK 직접 조인 시 팬아웃한다(단월·회비 측정에서 배수 과대 실측 — 규모는 이슈원장 §O51-D). 과거 시점 상태가 필요할 때만 DIM_MEMBER 를 EFFECTIVE_FROM/EFFECTIVE_TO 로 시점조인할 것 — 예측·피처 생성은 이 시점조인이 정답이며 현재값을 과거 행에 붙이면 정답 누설이다. 🔴 상태 기반 분포·이탈률·예측 모집단은 MEMBER_TYPE=''FDRM'' 으로 한정할 것(일시회원 ONCE 는 회원상태·가입경로 개념이 원천에 없고 REGION·AGE_BAND·FIRST_SPONSORSHIP·LAST_STOP_DATE 도 전건 NULL 이다). 본 테이블은 DIM_MEMBER 의 순수 투영이며 라벨 정의는 DIM_MEMBER.sql 단일 소유. 🔴 [O53] REGION·AGE_BAND·FIRST_SPONSORSHIP·LAST_STOP_DATE 를 노출한다 — 종전 미노출 근거였던 「전건 NULL 7컬럼」은 stale 이다(DEC-28 §18-B 가 이미 정정 · 3컬럼은 DIM_MEMBER 에 부재하고 4컬럼은 채워져 있다). ⚠️네 컬럼 전부 **개발약정 시점 스냅샷**이고 SCD2 축이다 — 현재 거주지·현재 나이로 읽으면 틀린다. ⚠️SERVING.DIM_MEMBER_CURRENT 와 동명이나 컬럼 집합이 다르다.';


-- ============================================================================
-- DIM 20: DIM_MEMBER_ACQUISITION — 회원 획득 귀속 차원 (1행 = 1회원)
--   [2026-08-10 O53] 신설. 구조·COMMENT 소유주 = 본 파일 / 적재 = dbt(incremental append + pre-hook TRUNCATE).
--   🔴 merge 금지: 완전 재산출 차원에 merge 를 쓰면 grain 이동 시 구 행이 잔존한다(문서50 §300 R1 · P131).
--   PK(정보성) = MEMBER_DK
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER_ACQUISITION (
    MEMBER_DK                VARCHAR(10)     NOT NULL PRIMARY KEY COMMENT '회원 자연키(= 팩트 조인키). 🔴이 테이블은 **1행 = 1회원**이다(O51-D 실측: base FACT_MEMBER_COHORT 의 행수 = 고유회원 수) ⇒ 팩트와 조인해도 팬아웃 0. 🔴단 **LEFT JOIN 필수** — 개발 사건이 없는 회원은 이 테이블에 존재하지 않는다🔴🔴[O51-D 실측] 손실 규모는 **분모를 무엇으로 잡느냐로 크게 달라진다** — INNER 조인이 잃는 것은 **회원**이므로 **회원 기준 비율이 정본**이다(FMM·FSE·FEP 실측치는 이슈원장 §O51-D-B). ⚠️종전 문안이 쓰던 비율은 **행 가중**이어서 손실을 크게 축소해 보이게 했다(O51-D 정정).',
    ACQ_CAMPAIGN_SK          NUMBER(38,0)    COMMENT '획득 캠페인 대리키(FK→DIM_CAMPAIGN). 0=미매핑·부재. 🔴**회원을 처음 데려온** 캠페인이다 — 회비·월실적 팩트의 캠페인 축은 전건 센티넬인데, 그 이유는 원천 부재가 아니라 **다중캠페인 후원의 귀속 규칙이 없었다**는 것이다(O45 판정) 이 테이블가 「획득 시점」이라는 명시된 규칙으로 대체한다(O45·O8 우회).',
    ACQ_ORG_SK               NUMBER(38,0)    COMMENT '획득 시점 담당조직 대리키(FK→DIM_ORG). 0=미매핑. 🔴「현재 소속」이 아니다. 🔴🔴「부서」는 축이 둘이다 — 개발실적보고의 부서 = **사건 부서**(FACT_MEMBER_EVENT.ORG_SK) · 연간분석(회비)의 부서 = **획득 부서**(이 축). 이름으로 구분되지 않으면 소비 측이 조용히 틀린다(O34 규약).',
    ACQ_SPONSORSHIP_SK       NUMBER(38,0)    COMMENT '획득 시점 후원사업 대리키(FK→DIM_SPONSORSHIP). 0=미매핑. 🔴🔴회비 **납입 대상** 후원사업(FACT_MEMBER_FEE.SPONSORSHIP_SK)과 **의미가 다르다** — 같은 라벨로 두 축이다. 한 회원이 A 사업으로 가입한 뒤 B 사업에 낼 수 있다.',
    ACQ_DATE_SK              NUMBER(8,0)     COMMENT '획득일 대리키(FK→DIM_DATE) — 획득 사건의 발생일. 0=캘린더 범위밖·무효. ⚠️회원번호 생성일(DIM_MEMBER_CURRENT.FIRST_JOIN_DATE)과 다르다 — 이 값은 **개발약정 사건일**이다.',
    ACQ_BASIS                VARCHAR         COMMENT '획득 판정 근거. ''NEW''=개발구분 **신규**(MM015 코드 ''1'') 사건으로 판정 / ''FALLBACK''=신규 사건이 없어 **최초 개발 사건**으로 대체 판정. 🔴FALLBACK 은 획득캠페인 신뢰도가 낮다 — 캠페인·브랜드 비교 시 ACQ_BASIS=''NEW'' 로 한정할 것을 권한다. ⚠️개발 이력이 아예 없는 중단회원은 획득 캠페인을 알 수 없어 이 테이블에 **존재하지 않는다**(중단 총계는 FACT_MEMBER_EVENT 를 쓴다).',
    ACQ_DVLP_DIV_CD          VARCHAR         COMMENT '획득 사건의 개발구분 코드. 코드그룹 **MM015(개발구분)**. 코드사전 = 1신규·2증액·3감액·4재후원·5후원중단 · 실적재에 **사전 전종이 등장**한다. ⚠️ACQ_BASIS=''NEW'' 이면 이 값은 항상 ''1''이다 — 그 외 값은 FALLBACK 경로를 뜻한다. 🔴MM015 는 회원상태 MM010 이 아니다(두 그룹 모두 ''후원중단''을 포함한다).',
    ACQ_AGE_CD               NUMBER(2,0)     COMMENT '획득 시점 연령대 코드. 코드그룹 **CM014(나이)**. 코드사전 = 1''10대 미만''·2''10대''·3''20대''·4''30대''·5''40대''·6''50대''·7''60대''·8''70대''·9''70대 이상''·10단체·11기업·12기타 · 실적재에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. ⚠️사전 자체에 8''70대''·9''70대 이상''이 의미 중복으로 공존한다. 라벨 = ACQ_AGE_BAND.',
    ACQ_AGE_BAND             VARCHAR         COMMENT '획득 시점 연령대명(CM014 라벨, 사전 조인 — 하드코딩 아님 P31). 코드 = ACQ_AGE_CD. 🔴**현재 나이가 아니다** — BRONZE 에 생년월일이 없어 현재 연령은 산출 불가(O34). ✅''10대 미만''이 상위인 것은 오류가 아니다 — 편지쓰기대회 계열 캠페인이 학교·부모 DB 를 통해 아동 본인 명의로 약정을 맺기 때문이다. 결측·기본값 오염으로 설명하지 말 것(O34-B).',
    ACQ_AREA_CD              VARCHAR         COMMENT '획득 시점 지역 코드. 코드그룹 **CM018**. 코드사전은 시·도 목록이고 실적재에 **사전 전종 + 라벨 없는 센티넬 ''0''** 이 나타난다. ⚠️CM018 의 그룹명은 ''신규시도구분''이지만 상세코드는 전부 시·도다. 라벨 = ACQ_REGION.',
    ACQ_REGION               VARCHAR         COMMENT '획득 시점 지역명(CM018 약칭 라벨, 정본 공#131). 코드 = ACQ_AREA_CD. 🔴**현재 거주지가 아니다** — BRONZE 에 현주소 축이 없다(O34). ⚠️센티넬 ''0'' 은 사전에 라벨이 없어 NULL 이며 ''미상''으로 창작하지 않는다.',
    ACQ_SEX_CD               VARCHAR         COMMENT '획득 시점 성별 코드. 코드그룹 **CM013(성별)**. 실적재(`TM_MM_FDRM_MBER_DVLP_AMT.SEX`)에 **사전 전종 + 사전에 없는 센티넬 ''0''** 이 나타난다. 🔴DIM_MEMBER 의 분석 성별(GENDER_NAME·CM017 계열)과 **라벨 체계가 다르다** — 이 축은 국내/외국인 구분을 보존한다. 라벨 = ACQ_GENDER.',
    ACQ_GENDER               VARCHAR         COMMENT '획득 시점 성별명(CM013 라벨): 국내(남자)·국내(여자)·외국인(남자)·외국인(여자)·외국인(기타)·단체·기업·기타. 코드 = ACQ_SEX_CD. 🔴DIM_MEMBER_CURRENT.GENDER_NAME(CM017 · 5종)과 값 집합이 다르다 — 두 축을 같은 표에서 비교하지 말 것. ⚠️센티넬 ''0'' 은 사전 라벨이 없어 NULL.',
    ACQ_SPNSR_AMT            NUMBER(18,0)    COMMENT '획득 사건의 후원금액(원, raw) ← TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT. 🔴**건수로 환산하지 말 것** — 정본 공#38·#151 이 **금액을 만원 단위로 나눈 값**이라는 규약이라 혼용하면 정의가 깨진다(CONF-2). ⚠️획득 시점 약정액이며 이후 증액·감액은 반영되지 않는다(현재 약정액이 아니다).',
    ACQ_BRAND                VARCHAR         COMMENT '획득 캠페인의 브랜드. 🔴[DEC-43] 적재 시점 동결값 ← FACT_MEMBER_COHORT.ACQ_BRAND(구 DIM_CAMPAIGN.BRAND 실시간 조인 대체). 차원 단독 조회로도 뜻이 통하게 라벨을 비정규화했다(DEC-10). ⚠️ACQ_BASIS=''FALLBACK'' 인 회원은 귀속 신뢰도가 낮다.',
    ACQ_CAMPAIGN_NAME        VARCHAR         COMMENT '획득 캠페인명 ← DIM_CAMPAIGN.CAMPAIGN_NAME(실시간 조인 — 12속성 범위 밖, 캠페인 자신의 이름이라 동결 대상이 아니다). ⚠️광고비와 결합할 때는 이 축이 아니라 ACQ_MARKETING_CAMPAIGN 을 쓴다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃).',
    ACQ_PARENT_CAMPAIGN_NAME VARCHAR         COMMENT '획득 캠페인의 **상위캠페인**명(원천 UPPER_CMPGN_CD 계층). 🔴[DEC-43] 적재 시점 동결값 ← FACT_MEMBER_COHORT.ACQ_PARENT_CAMPAIGN_NAME(구 DIM_CAMPAIGN.PARENT_CAMPAIGN_NAME 실시간 조인 대체). 캠페인 카테고리(MM294)와 다른 축이다 — 카테고리는 코드 기반 분류, 상위캠페인은 캠페인 자체의 부모다.',
    ACQ_PROMO_METHOD_NAME    VARCHAR         COMMENT '획득 캠페인의 홍보방법명. 코드그룹 **CM008(홍보방법)**. 🔴[DEC-43] 적재 시점 동결값 ← FACT_MEMBER_COHORT.ACQ_PROMO_METHOD_NAME(구 DIM_CAMPAIGN.PROMO_METHOD_NAME 실시간 조인 대체). [O51-D BRONZE 실측] CM008 사전은 100종을 넘는 대형 그룹이며 채널·랜딩·매체가 한 축에 섞여 있다(PC캠페인-홈페이지·M배너광고(DA)·TM·TS·가두·교회개발·직원개발·서신 등) — 🔴상위 집계가 필요하면 이 축이 아니라 개발인입경로(MM293 · ACQ_INFLOW_PATH)를 쓴다.',
    ACQ_MARKETING_CAMPAIGN   VARCHAR         COMMENT '획득 캠페인의 마케팅캠페인(O45 conformed 축, 원천 MKTG_CMPGN_NM). 🔴[DEC-43] 적재 시점 동결값 ← FACT_MEMBER_COHORT.ACQ_MKTG_CMPGN_NM(구 DIM_CAMPAIGN.MARKETING_CAMPAIGN 실시간 조인 대체). 🟢**광고비와 결합하는 정본 축**이다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃).',
    ACQ_DEPARTMENT           VARCHAR         COMMENT '획득 시점 부서명 ← DIM_ORG.DEPARTMENT. 코드 = ACQ_ORG_SK. 🔴**획득(최초개발) 시점 부서**다 — 개발실적보고의 「부서」(=사건 부서)와 다르다. 사건 부서는 WIDE_MEMBER_EVENT.ORG_DEPARTMENT 를 쓴다(O34 _AT_PLEDGE/_AT_EVENT 규약의 재적용). ⚠️DIM_ORG 는 SCD1(DEC-2)이라 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다.',
    ACQ_SPONSORSHIP_NAME     VARCHAR         COMMENT '획득 시점 후원사업명 ← DIM_SPONSORSHIP.SPONSORSHIP_NAME(정본 공#123). 코드 = ACQ_SPONSORSHIP_SK. 🔴회비 **납입 대상** 후원사업명(WIDE_MEMBER_FEE.SPONSORSHIP_NAME)과 다른 축이다.',
    FIRST_STOP_DATE_SK       NUMBER(8,0)     COMMENT '최초 중단일 대리키(FK→DIM_DATE) — 중단원천(EVENT_TYPE=''STOP'') 기준 최초 사건. 🔴**미중단 회원은 NULL** 이며 0 이 아니다 — 0 은 「날짜 미상」이라는 다른 뜻이다(P21). 중단했으나 일자가 캘린더 범위밖이면 0.',
    FIRST_STOP_REASON_NM     VARCHAR         COMMENT '최초 중단의 사유명. 코드그룹 **MM005(후원중단사유)**. 미중단 회원은 NULL. 코드사전에는 **폐지코드(USE_YN=''N'')가 다수 섞여** 있고 실적재는 사전의 일부만 쓴다. 🔴🔴**USE_YN 필터 금지** — 실적재 종 중 일부가 폐지코드이며 필터를 걸면 그 라벨이 사라진다(종수·규모는 문서10 §26).',
    TENURE_DAYS              NUMBER(9,0)     COMMENT '유지기간(일) = 최초 중단일 − 획득일. 🔴**미중단 회원은 NULL** 이다 — 아직 종료되지 않은 관측(우측 절단)이며 0 이나 ''현재까지 경과일''로 채우면 평균 유지기간이 조용히 틀린다. 획득일·중단일 중 하나가 무효면 NULL. ⇒ 평균 유지기간은 중단 회원만으로 계산하거나 생존분석을 쓸 것.',
    IS_12M_OBSERVABLE        BOOLEAN         COMMENT '12개월 관측 가능 여부 = 획득일 + 12개월 ≤ 데이터 최종 사건일. 🔴🔴**12개월 이탈률의 분모 자격**이다 — 최근 획득 회원은 아직 12개월이 지나지 않아 FALSE 이며, 포함시키면 최근 캠페인이 실제보다 이탈률이 낮게 보인다(분모에 아직 이탈할 시간이 없는 회원이 섞인다).',
    DW_SOURCE_SYSTEM         VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS               TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS             TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID              VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [DEC-43 2026-08-25] 캠페인 12속성 중 잔여 8속성(라벨만 노출 — 코드는 FACT_MEMBER_COHORT 소관).
    --   전부 획득 시점 동결값 ← FACT_MEMBER_COHORT.ACQ_*(SILVER CRM_MEMBER_DEV 적재 시점 값 승계).
    ACQ_INFLOW_PATH          VARCHAR         COMMENT '획득 캠페인의 모집 채널명(MM293 라벨). ⚠️채널이며 「주요캠페인」이 아니다 — 주요캠페인은 ACQ_CAMPAIGN_TYPE 이다.',
    ACQ_CAMPAIGN_TYPE        VARCHAR         COMMENT '획득 캠페인의 카테고리 라벨(MM294) — 현업이 말하는 ''주요캠페인'' 축.',
    ACQ_DOMESTIC_OVERSEAS    VARCHAR         COMMENT '획득 캠페인의 국내/해외 구분(MM295 라벨: 국내/통합/해외).',
    ACQ_BIZ_CASE_TYPE        VARCHAR         COMMENT '획득 캠페인의 사업/사례 구분(MM296 라벨: 굿즈/기타/사례/사업).',
    ACQ_CMMN_BRND_NM         VARCHAR         COMMENT '획득 캠페인의 공통브랜드명(MM297 라벨). ⚠️라벨이 MM293(개발인입경로)과 상당 중복되나 현업 확인상 별도 축으로 유지.',
    ACQ_MKTG_UTM_NM          VARCHAR         COMMENT '획득 캠페인의 UTM 라벨(TM_CM_MKTNG_UTM.MK_UTM_NM).',
    ACQ_SPNSR_DIV_NM         VARCHAR         COMMENT '획득 캠페인의 후원구분명(CM035 라벨: 정기후원/일시후원).',
    ACQ_CPR_DIV_NM           VARCHAR         COMMENT '획득 캠페인의 법인구분명(CM019 라벨: 통합/사단/사복).'
) COMMENT = '회원 획득(가입) 귀속 차원 — 1행=1회원. 원천 = FACT_MEMBER_COHORT(단일 정의 지점). 🔴모든 ACQ_* 는 **획득 시점** 값이며 현재 속성이 아니다(현재 연령·현주소는 BRONZE 에 축이 없어 산출 불가·O34). 🔴「부서」·「후원사업」은 같은 라벨로 두 축이 존재한다 — 사건 부서=FACT_MEMBER_EVENT.ORG_SK · 납입 대상 후원사업=FACT_MEMBER_FEE.SPONSORSHIP_SK. 🔴팩트와는 반드시 LEFT JOIN — 개발 사건이 없는 회원이 사라진다 — 🔴손실은 **회원 기준**으로 읽어야 한다(행 가중 비율은 손실을 축소해 보이게 한다 · 규모는 이슈원장 §O51-D-B). 신설 경위(O45): FMM 의 CAMPAIGN_SK·SPONSORSHIP_SK 가 전건 센티넬인 것은 원천 부재가 아니라 **다중캠페인 후원의 귀속 규칙이 없어서**였고, 임의 귀속 대신 「획득 시점」이라는 명시된 규칙을 채택했다(O8 우회). 🔴 [O53] 뷰 → 테이블 전환. 적재는 dbt(append + pre-hook TRUNCATE)가 하고 구조·COMMENT 는 06_DDL.sql 이 소유한다. [DEC-43 2026-08-25] 캠페인 12속성 중 12/12(ACQ_BRAND·ACQ_PARENT_CAMPAIGN_NAME·ACQ_PROMO_METHOD_NAME·ACQ_MARKETING_CAMPAIGN·ACQ_INFLOW_PATH·ACQ_CAMPAIGN_TYPE·ACQ_DOMESTIC_OVERSEAS·ACQ_BIZ_CASE_TYPE·ACQ_CMMN_BRND_NM·ACQ_MKTG_UTM_NM·ACQ_SPNSR_DIV_NM·ACQ_CPR_DIV_NM)이 DIM_CAMPAIGN 실시간 조인 → FACT_MEMBER_COHORT 적재시점 동결값으로 전환됐다. ACQ_CAMPAIGN_NAME 만 실시간 조인 잔존(캠페인 자신의 이름, 12속성 범위 밖).';


-- ============================================================================
-- DIM 4: DIM_MEMBER_IDENTITY — 회원 신원 브리지 (P5 durable key)
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MEMBER_IDENTITY (
    IDENTITY_SK         NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '회원 식별 대리키 (ETL 일련번호, PK)',
    MEMBER_DK           VARCHAR(10)     NOT NULL COMMENT '불변 회원키',  -- ※비강제 FK→DIM_MEMBER(SCD2/비유일)
    MEMBER_NO           VARCHAR         NOT NULL COMMENT '회원번호(#110)',
    MEMNUM              VARCHAR         COMMENT 'memnum(#111) — 🔴 전건 NULL(미배선). 원천 실재 = SILVER.GA4_EVENT.PAGE_LOCATION 의 memnum= (규모·종수는 문서10 §26). 조회 시 항상 0행',
    GA_MEMBER_ID        VARCHAR         COMMENT 'member id(#112)',
    HOMEPAGE_ID         VARCHAR         COMMENT '홈페이지/앱 ID. 원천: TM_MM_FDRM_MBER_INFO.HMPG_ID',
    CHILD_CODE          VARCHAR         COMMENT '결연아동코드(#122, URL 파싱) — 🔴 전건 NULL(미배선). 원천 실재 = SILVER.GA4_EVENT.PAGE_LOCATION 의 childnum= (규모·종수는 문서10 §26). 조회 시 항상 0행',
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
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-06 O45] 마케팅캠페인 conformed FK.
    --   🔴 **선언 위치가 감사컬럼 뒤인 것은 의도다** — 라이브 환경에서는 `ALTER TABLE ADD COLUMN`
    --      으로 추가되어 물리 ordinal 이 **맨 끝(20)** 이 되었다(실측). 이 파일에서 감사컬럼 앞에
    --      적으면 신규 환경 재구축 시 컬럼 순서가 라이브와 달라져 dbt 모델 SELECT 순서와 어긋난다.
    --      ⚠️ 2026-08-06 최초 작성 시 감사컬럼 **앞**에 적어 두었던 것을 실측(ordinal 20) 후 교정했다.
    --   🔴 MARKETING_CAMPAIGN 은 **라벨**이라 광고 팩트가 참조할 수 없었다 → 광고↔CRM 결합 전면 불가(O44).
    --   실측: 브리지 조인 `MK_CMPGN_CD = MKTG_CMPGN_NM::varchar` 33,915/33,915 = **100% 해소** ·
    --         개발실적 커버리지 2,278,685/2,291,878 = **99.42%**.
    MKTG_CAMPAIGN_SK    NUMBER(38,0)    COMMENT '[O45] 마케팅캠페인 대리키 (FK→DIM_MARKETING_CAMPAIGN). 광고(AGENCY)와 개발실적(CRM)을 잇는 conformed 축. 0=미매핑. 🔴개발캠페인 grain 으로 광고비를 내리면 대규모 팬아웃이 발생한다(팬아웃 배수·마케팅캠페인당 개발캠페인 분포·광고 도달 범위는 문서10 §26) — 결합은 마케팅캠페인 grain 에서만 할 것',
    -- [2026-08-25 안내2] 세부캠페인 후원구분·법인구분 신설(현업 요건 — Gold 까지 적재). 물리 위치=맨 끝(ALTER TABLE ADD COLUMN 규약).
    --   컬럼명은 SILVER CRM_CAMPAIGN 과 1:1 동일 — DIM 은 개발자·AI 추적성 우선(현업 가독성은 WIDE_MEMBER_EVENT 가 담당).
    SPNSR_DIV_CD        VARCHAR         COMMENT '후원구분 원천코드(CM035): 1=정기후원 · 2=일시후원. 🔴 라벨이 아니다 — 사람이 읽는 이름은 SPNSR_DIV_NM.',
    SPNSR_DIV_NM        VARCHAR         COMMENT '후원구분명 — SPNSR_DIV_CD 를 코드사전 CM035 로 해소한 라벨(정기후원/일시후원).',
    CPR_DIV_CD          VARCHAR         COMMENT '법인구분 원천코드(CM019): A=통합 · I=사단 · S=사복. 🔴 라벨이 아니다 — 사람이 읽는 이름은 CPR_DIV_NM.',
    CPR_DIV_NM          VARCHAR         COMMENT '법인구분명 — CPR_DIV_CD 를 코드사전 CM019 로 해소한 라벨(통합/사단/사복).',
    -- [2026-08-25 안내1 후속] 회원 개발이력 비정규화 요건의 잔여 2컬럼(공통브랜드·UTM) 신설. 물리 위치=맨 끝(ALTER TABLE ADD COLUMN 규약).
    --   컬럼명은 SILVER CRM_CAMPAIGN 과 1:1 동일 — DIM 은 개발자·AI 추적성 우선(현업 가독성은 WIDE_MEMBER_EVENT 가 담당).
    CMMN_BRND           VARCHAR         COMMENT '공통브랜드 원천코드(MM297, 14종). 🔴 라벨이 아니다 — 사람이 읽는 이름은 CMMN_BRND_NM.',
    CMMN_BRND_NM        VARCHAR         COMMENT '공통브랜드명 — CMMN_BRND 를 코드사전 MM297 로 해소한 라벨. ⚠️라벨이 MM293(개발인입경로)과 상당 중복되나 현업 확인상 별도 축으로 유지.',
    MKTG_UTM            NUMBER(38,0)    COMMENT 'UTM 원천코드 — 코드사전이 아니라 SILVER 신설 원천 TM_CM_MKTNG_UTM(MK_UTM)과 연동. 🔴 라벨이 아니다 — 사람이 읽는 이름은 MKTG_UTM_NM.',
    MKTG_UTM_NM         VARCHAR         COMMENT 'UTM 라벨 — MKTG_UTM 을 TM_CM_MKTNG_UTM(MK_UTM_NM)으로 해소한 값.'
) COMMENT = '캠페인 차원 (1캠페인). 분류축 = CAMPAIGN_TYPE(카테고리 = 현업 「주요캠페인」)·PARENT_CAMPAIGN_NAME(상위캠페인)·PROMO_METHOD_NAME(홍보방법)·INFLOW_PATH(모집채널)·DOMESTIC_OVERSEAS(국내해외)·BIZ_CASE_TYPE(사업사례)·MARKETING_CAMPAIGN·SPNSR_DIV_NM(후원구분)·CPR_DIV_NM(법인구분)·CMMN_BRND_NM(공통브랜드)·MKTG_UTM_NM(UTM). PARENT_CAMPAIGN·PROMO_METHOD·SPNSR_DIV_CD·CPR_DIV_CD·CMMN_BRND·MKTG_UTM 는 코드이고 나머지는 라벨(각 라벨 컬럼 병설)';


-- ============================================================================
-- DIM 17: DIM_MARKETING_CAMPAIGN — 마케팅캠페인 conformed 차원 [2026-08-06 O45 신설]
-- ----------------------------------------------------------------------------
-- 🔴 AGENCY(광고) ↔ CRM(개발실적) 결합이 성립하는 **유일한 grain**. `DIM_CAMPAIGN.MARKETING_CAMPAIGN`
--    은 라벨이라 광고 팩트가 참조할 수 없었다 → 독립 차원으로 승격해 양측이 같은 SK 를 쓰게 한다.
-- ⚠️ 생성 순서: `DIM_CAMPAIGN`·`FACT_AD_PERFORMANCE` 가 이 차원을 FK 참조하지만 FK 는 하단
--    [관계 제약] 에서 ALTER 로 선언하므로 생성 순서 제약은 없다. 다만 논리상 DIM 구간에 둔다.
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_MARKETING_CAMPAIGN (
    MKTG_CAMPAIGN_SK    NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '대리키 = gold_sk(MK_CMPGN_CD). 0 = (미매핑) Unknown 멤버',
    MKTG_CAMPAIGN_BK    VARCHAR         COMMENT '업무키 = 원천 MK_CMPGN_CD (SILVER.CRM_MARKETING_CAMPAIGN)',
    MKTG_CAMPAIGN_NAME  VARCHAR         COMMENT '마케팅캠페인명. 🔴광고측(AGENCY CAMPAIGN_NM)과의 **조인 키**다 — 이름매칭이 유일 경로다(AGENCY 원천 3종에 캠페인 코드 컬럼이 없다). 광고 도달·미도달 커버리지는 문서10 §26 이며 미도달은 SK=0 으로 간다',
    USE_YN              VARCHAR         COMMENT '사용여부(원천 그대로 — 폐지분도 과거 실적에 붙으므로 제외하지 않는다)',
    DEV_CAMPAIGN_CNT    NUMBER(38,0)    COMMENT '🔴**팬아웃 경고축**: 이 마케팅캠페인에 매달린 개발캠페인 수. 1 보다 크면 개발캠페인 단위로 광고비를 내릴 때 그 배수만큼 복제된다. 모집단별(마스터 전체 / 광고 도달분 한정) 평균·최대·합과 naive 조인 팬아웃 배수는 문서10 §26. 결합은 마케팅캠페인 grain 에서만 할 것',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '[O45] 마케팅캠페인 conformed 차원 (마스터 전량 + Unknown 센티넬). 광고 ↔ CRM 후원 결합이 성립하는 **유일한 grain**. 🔴개발캠페인 grain 으로 내리면 대규모 팬아웃이 일어난다 — 결합은 마케팅캠페인 grain 에서만 할 것이고 현업 광고비 배분 규칙이 필요하다(Q10 재정의). 광고·개발실적 도달률 · 개발단가 · 팬아웃 배수 실측치는 문서10 §26-B 참조';


-- ============================================================================
-- DIM 6: DIM_SPONSORSHIP — 후원사업 차원
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_SPONSORSHIP (
    SPONSORSHIP_SK      NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '후원사업 대리키 (ETL 일련번호, PK)',
    SPONSORSHIP_BK      VARCHAR         NOT NULL COMMENT '후원사업 업무키(BK, 자연키)',
    SPONSORSHIP_NAME    VARCHAR         COMMENT '후원사업 전체(#123)',
    SPONSORSHIP_ABBR    VARCHAR         COMMENT '약칭(#124) — 코드 raw ← 원천 SPNSR_BSNS_ABRV_CD. 🔴**코드다(1~6)**, 라벨은 SPONSORSHIP_GROUP_NAME(코드사전 CM003 · O89). 종전 SPB-G 의 "약칭인지 분류코드인지 불명"은 O89 로 해소 — CM003 그룹명이 「후원약칭」이므로 컬럼명은 오명이 아니었다',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-19 O89] 후원사업 분류 3계층 라벨 신설(ALTER TABLE ADD COLUMN 으로 물리 반영, 위치=맨 끝).
    --   🔴 **선언 위치가 감사컬럼 뒤인 것은 의도다** — 라이브 환경에서는 `ALTER TABLE ADD COLUMN` 으로
    --      붙어 물리 ordinal 이 맨 끝이 된다. 앞에 적으면 신규 환경 재구축 시 순서가 갈라진다(O45 선례).
    --   현업 요구 = "후원사업 상위분류/하위분류를 각각 라벨로 GOLD 에서 보고 싶다".
    --   🔴 **요구가 지목한 컬럼은 실측으로 교정됐다** — 현업은 `SPNSR_BSNS_ID`(상위)/`SPNSR_BSNS_NO`(하위)
    --      라고 말했으나 `SPNSR_BSNS_NO` 는 분류가 아니라 **회원별 후원약정 일련번호**다:
    --      distinct **2,170,574**(vs ID 29) · 범위 4~2,638,655 · **99.999%(2,170,544/2,170,574)가 단일
    --      회원 전속** · 동일 `SPNSR_BSNS_ID` 아래 한 회원이 복수 `NO` 보유(실측 예: MBER_NO 0853739 가
    --      ID=4 아래 NO 3개). 분류라면 다수 회원이 공유해야 하므로 성립하지 않는다. 코드사전 대응 그룹도 없다.
    --      ⇒ `NO` 하위의 실체는 결연 아동(`TM_RM_RELATNSP_MSTR_INFO.CHILD_CD` 469,402)이고 라벨 가능한 축은
    --        사업장(`TM_RM_BPLC_MNG.BPLC_KORNM` 220종)·국가(`NATION_CD` 34종)다. 단 **해외아동결연(ID=1)
    --        99.99% 한정**이고 나머지 27개 사업은 0.00% 이며, 회원이 아동 복수 결연을 하므로 이 디멘션(50행)에
    --        넣을 수 없다(O8 과 동일한 fan-out 구조) → **별건 설계 대기**.
    --   ✅ 실재하며 즉시 라벨 가능한 3계층 = SPONSORSHIP_DIV_CD(CM035 정기/일시 2종)
    --      → SPONSORSHIP_ABBR(CM003 약칭 6종) → SPONSORSHIP_NAME(사업명 29 사용/50 정의).
    --      `SPONSORSHIP_ABBR` 은 기존 컬럼이고 **라벨만 없었다** → GROUP_NAME 병설로 해소(O25/G3/O37 동일 패턴).
    --   🟡 **SPB-G 근거 확보 · 라이브 대조 대기** — "ABBR 값 1~6, 약칭인지 분류코드인지 불명 · 코드사전 미특정 ·
    --      현업 라벨 회신 대기"가 코드사전 **CM003(그룹명 「후원약칭」)** 으로 특정됐다(사업수 분포가 SPB-G 실측과 일치).
    --      🔴 **「종결」이라고 적었던 것은 오판정이라 격하했다** — 라이브 DIM_SPONSORSHIP 이 0행이어서 값 대조가
    --      불가하다(R2-8-4-c). 계정 = NX55103 · dbt build 후 확정. 상세·수치는 원장 02 §O89.
    --   🔴 **`SPNSR_BSNS_NO` 는 Q15 가 이미 닫은 항목이다** — 정본 결론 = "ID=DIM 키(마스터 50) · NO=관계번호 ·
    --      크로스워크"(크로스워크 = SILVER.CRM_SPONSOR_RELATION). 위 기술은 Q15 와 일치하며 신규 발견이 아니다.
    --      현업이 NO 를 「하위 분류」로 재요구하면 Q15 를 먼저 제시할 것.
    --   🔴 라벨 없이 이 축을 SV 에 노출하면 Analyst 가 코드를 추측해 0행 무증상 오답을 낸다(O37 PROMO_METHOD 선례).
    SPONSORSHIP_DIV_CD     VARCHAR      COMMENT '[O89] 정기일시후원구분 코드 raw ← 원천 TM_CM_SPNSR_BSNS_INFO.SPNSR_DIV_CD (SILVER CRM_SPONSORSHIP.SPNSR_DIV_CD). 코드사전 CM035. 실측 2종(1·2) · 50개 사업 전건 채움. 🔴**최상위 분류축**이다 — 라벨은 SPONSORSHIP_DIV_NAME. ⚠️회비/기부금 지류 구분(FEE_DIV)과 다른 축이다',
    SPONSORSHIP_DIV_NAME   VARCHAR      COMMENT '[O89] 정기일시후원구분명 — 코드 SPONSORSHIP_DIV_CD 를 코드사전 CM035(정기일시후원구분코드)로 해소한 라벨. 값 = 1→정기후원 · 2→일시후원. 🔴**후원사업 분류 3계층의 최상위**(정기일시 → 약칭 → 사업명). ⚠️원천 코드 부재 시 NULL 이며 ''(미매핑)''으로 창작하지 않는다(P21). ⚠️USE_YN 무필터 조인',
    SPONSORSHIP_GROUP_NAME VARCHAR      COMMENT '[O89] 후원약칭명 — 기존 코드컬럼 SPONSORSHIP_ABBR(원천 SPNSR_BSNS_ABRV_CD)을 코드사전 CM003(후원약칭)으로 해소한 라벨. 값 = 1→국내 · 2→결연 · 3→해외구호 · 4→북한 · 5→기타 · 6→해외 · 7→선물금(7은 미사용). 사업수 17/1/6/3/21/2 = 50. 🔴**3계층의 중위**다 — 상위는 SPONSORSHIP_DIV_NAME, 하위는 SPONSORSHIP_NAME. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 3(해외구호)과 6(해외)이 둘 다 해외이고 6은 SPONSORSHIP_DIV_CD=2(일시후원)에서만 나타난다(실측) ⇒ 정확한 분류축은 **(DIV, ABBR) 쌍**이다. ⚠️원천 코드 부재 시 NULL(P21)'
) COMMENT = '후원사업 차원 (1후원사업 · 실측 distinct=50). 분류 3계층 = SPONSORSHIP_DIV_NAME(정기일시 CM035) → SPONSORSHIP_GROUP_NAME(약칭 CM003) → SPONSORSHIP_NAME(사업명). DIV_CD·ABBR 은 코드이고 각 라벨 컬럼을 병설한다(O89). 🔴 SPNSR_BSNS_NO 는 분류가 아니라 회원별 약정 일련번호여서 이 차원에 없다 — 상세는 O89 주석';


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
    DEFAULT_CHANNEL_GROUP VARCHAR       COMMENT '[DEC-30] GA4 표준 채널그룹 ← GA4_TRAFFIC_SOURCE.DEFAULT_CHANNEL_GROUP. 전건 채움 · grain 에 대한 함수종속률과 다중 사례는 문서10 §26 이라 MAX() 대표값. ⚠️SOURCE_MEDIUM(파생 문자열)과 다른 개념 — GA4 가 산정한 표준 분류다',
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
) COMMENT = '발송구분 차원 — 대/중/소 3단 계층 평탄화 (정본 지표 #133·#134·#135). grain=(대,중,소) 코드 경로 + 센티넬. 🟢FACT_SERVICE_EVENT 소비 커버리지 실측치는 문서10 §26 — 요청 grain 을 분모로 잡은 종전 값은 **잘못된 분모**였다(P39). 미매칭은 센티넬 0. ⚠️DEC-28 §18-C 가 DIM_SERVICE grain 확장 대신 차원 분리를 택한 이유 = SERVICE_SK 보존.';


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
    REASON_TYPE         VARCHAR         COMMENT '사유 코드그룹 ID. ⚠️주석상 「중단/미납 구분」이었으나 실제값은 CRM 코드그룹 ID 다수(PM019·MS049·PM018·PM002·PM032·PM033 등) — ''중단''/''미납'' 리터럴 0건(종수·행 규모는 문서10 §26). 중단/미납 구분 필터가 필요하면 별도 분류 컬럼 신설 필요(O21, 2026-07-31 실측 교정)',
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
    RECRUIT_HEADCOUNT   NUMBER(38,0)    COMMENT '[DEC-30] 모집인원 ← CRM_EVENT.RCRIT_PSNNL_CO. 채움 규모·종수는 문서10 §26. 🔴행사 속성이므로 참여 팩트가 아니라 행사 차원이 정본 — 참여행 반복 시 SUM 이 대규모 과대계상된다(배수·행사 참값은 문서10 §26). 행사 단위로만 합산',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-11 O59-N · DEC-35 2단계] 코드→라벨 계층화 (형상 = 문서30 §23-G · 결정 = §23-J · 매핑 = 문서31).
    --   🔴 **선언 위치가 감사컬럼 뒤인 것은 의도다**(이 파일 line 298 과 동일 근거) — 라이브에는
    --      `ALTER TABLE ADD COLUMN` 으로 붙어 물리 ordinal 이 맨 끝이 된다. 앞에 적으면 재구축 시 순서가 갈라진다.
    --   ⚠️ 규칙7: 이 문안에 실측 수치를 넣지 않는다 — 규모는 문서10 §26·원장 참조(게이트 `audit_ddl_rule7.py`).
    EVENT_CATEGORY_GROUP VARCHAR(10)    COMMENT '행사구분 코드군 ID (조인키 · EVENT_KIND=일반행사→MS286 · 캠페인행사→MS002). 🔴원천별로 코드체계가 완전히 다르다(겹침 없음) — EVENT_CATEGORY 를 단독 필터·GROUP BY 하면 두 체계가 섞인다. 이 컬럼 또는 EVENT_KIND 를 동반할 것',
    EVENT_CATEGORY_NAME  VARCHAR        COMMENT '행사구분 라벨 (코드사전 CRM_CODE 조인 산물 · 등급 B 배타 확정). 사전 미등재 코드는 NULL 유지(라벨 창작 금지 · DEC-17-B)'
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
    REASON_SK                   NUMBER(38,0)    COMMENT '미납 대표사유 (FK→DIM_REASON) — ✅ W3(DEC-24, 2026-07-31) 배선 완료. 🔴 미납(PAY_STAT_CD=''F'') 행 한정 — 최종차수(MBRFEE_SQNC 최대)의 RQEST_RST_CD를 (코드그룹, 코드) 복합키로 DIM_REASON 조인. 코드그룹 = SETLE_CD 1&2자리→PM002 / 1&4자리→PM032 / 2→PM018 / 12→PM033 / 5→PM019. 매핑 커버리지와 0(비미납 또는 구조적 사유부재 = 수기처리·F코드부재·DIM미존재) 내역은 문서10 §26. ⚠️ 대표 1개로 축약 — 복수사유 분포는 SILVER 직접 조회. ⚠️ 중단사유는 별도 트랙(FME)',
    DEV_CNT                     NUMBER(18,4)    COMMENT '개발(건) — A1: FME(CRM_MEMBER_DEV) 사건수 롤업. ⚠️금액/10000 의미는 원천 금액컬럼+FME 변경 필요(별도트랙, #4·5·149)',
    DEV_MEMBERS                 NUMBER(38,0)    COMMENT '개발(명)(#148) — A1: 월×회원 개발발생=1. 🟢이 컬럼은 **옳다**: grain 이 월×회원이라 SUM 이 곧 개발(명)이며 466개월 전부 COUNT(DISTINCT MEMBER_DK) 와 일치 실측(O39). ⚠️동명의 FACT_MEMBER_EVENT.DEV_MEMBERS 는 사건 플래그로 SUM 이 건수다 — 혼용 금지.',
    STOP_CNT                    NUMBER(18,4)    COMMENT '중단(건) — A1: FME(CRM_MEMBER_DISCONTINUE) 사건수 롤업 (#35)',
    UNPAID_CNT                  NUMBER(18,4)    COMMENT '미납(건) (#36)',
    ACTIVE_CNT                  NUMBER(18,4)    COMMENT '활동(건) (#37·157) — 🟢 [O93] 배선 완료. 정본 #52 = 활동회원의 전체후원사업금액/10,000. 판정축 = **as-of 월말 미중단 후원사업 보유**(상태코드가 아니다 — 상태는 현재값이라 과거 월을 평가할 수 없다). 🔴 NULL = 판정 불가(Unknown 월 또는 후원사업 이력 없음)이고 0 = 활동 아님이다 — 둘을 같게 읽지 말 것. ⚠️ ACTIVE_MEMBERS 와 단위가 달라 서로 더하면 안 된다.',
    ACTIVE_MEMBERS              NUMBER(38,0)    COMMENT '활동(명) (#156) — 🟢 [O93] 배선 완료. 정본 #51 월말활동회원. 행당 1/0 이므로 회원수는 SUM 으로 구한다. 🔴 NULL = 판정 불가 · 0 = 활동 아님. ⚠️ 정본 #42 미납회원은 활동회원의 **부분집합**이라 활동+미납 합산은 이중계상이다(CONF-1).',
    ACTIVE_CUM_CNT              NUMBER(18,4)    COMMENT '활동누계(건) (#159) — 🔴 전건 NULL(미배선). 원인 = 정본에 「활동 누계」의 정의가 없다(누적 개월수·누적 금액·기수 누계 중 무엇인지 미확정). 임의 선택은 정의 창작이므로 보류한다. NULL 을 0 으로 읽지 말 것.',
    ACTIVE_CUM_MEMBERS          NUMBER(38,0)    COMMENT '활동누계(명) (#158) — 🔴 전건 NULL(미배선). 사유는 ACTIVE_CUM_CNT 와 동일(정본 정의 부재).',
    INCREASE_CNT                NUMBER(18,4)    COMMENT '증액(건) (#151)',
    INCREASE_MEMBERS            NUMBER(38,0)    COMMENT '증액(명) (#150)',
    DECREASE_CNT                NUMBER(18,4)    COMMENT '감액(건) SUM(감액금액)/10000 (#38)',
    CHURN_CNT                   NUMBER(18,4)    COMMENT '이탈(건) SUM(취소+감액)/10000 (신규#20)',
    YEAR_START_ACTIVE_CNT       NUMBER(18,4)    COMMENT '연도초 활동회원(건) (#49) — 🟢 [O93] 배선 완료. 해당 연도 YYYY01 시점 as-of 재평가값이다(당월값의 복제가 아니다).',
    YEAR_END_ACTIVE_CNT         NUMBER(18,4)    COMMENT '연도말 활동회원(건) (#50) — 🟢 [O93] 배선 완료. 해당 연도 YYYY12 시점 as-of. ⚠️ 미래 연도 행에서는 아직 오지 않은 시점이라 당월값과 같아질 수 있다.',
    MONTH_END_ACTIVE_CNT        NUMBER(18,4)    COMMENT '월말활동회원(건) (#52) — 🟢 [O93] 배선 완료. 🟢 ACTIVE_CNT 와 **같은 값이다** — 판정 자체가 as-of 월말이라 축이 하나다. 두 컬럼 병존은 소비 호환 목적이며 불일치가 아니다.',
    PREV_MONTH_END_ACTIVE_CNT   NUMBER(18,4)    COMMENT '전월말 활동회원(건) (#53) — 🟢 [O93] 배선 완료(DEC-19 (d) 해소). 🔴 LAG 가 아니라 **달력상 전월을 직접 as-of 재평가**한 값이다 — 팩트 스파인이 sparse 해서 LAG 는 직전 「존재하는」 행을 집어 전월이 아닐 수 있다.',
    CAMPAIGN_UNPAID_CNT         NUMBER(18,4)    COMMENT '캠페인별 미납(건) (#83)',
    STATUS_UNPAID_CNT           NUMBER(18,4)    COMMENT '회원상태별 미납(건) (#84)',
    REGULAR_FEE                 NUMBER(18,2)    COMMENT '정기회비(원) (#66)',
    REGULAR_ONETIME_FEE         NUMBER(18,2)    COMMENT '정기회원 일시회비(원) (#67)',
    ONETIME_ONETIME_FEE         NUMBER(18,2)    COMMENT '일시회원 일시회비(원) (#68)',
    PAID_FEE                    NUMBER(18,2)    COMMENT '납입 **총액**(원) = 회비+기부금 (#69·70 단일화). 🔴「납입회비」가 아니다(O40) — 회비만은 PAID_FEE_BILLABLE. 납부율 분자로 쓰지 말 것(분모 BILLED_AMT 는 회비 청구만이라 모집단 불일치).',
    BILLED_AMT                  NUMBER(18,2)    COMMENT '회비 청구액(원) (#71). 기부금은 원천에 청구 컬럼이 없어 포함되지 않는다(O40).',
    -- [2026-08-05 O40] 납부율·미납금액 모집단 일치 컬럼 2종
    PAID_FEE_BILLABLE           NUMBER(18,2)    COMMENT '회비만 납입액(원) — 납부율 분자 **정본**(O40). `PAYMENT_TYPE=''회비''` 행의 PAY_AMT 합. 🔴`PAID_FEE` 와 다르다: 그쪽은 회비+기부금 총수납액이고 기부금은 원천에 청구 컬럼이 없어 분모에 못 들어간다. 납부율 = PAID_FEE_BILLABLE / BILLED_AMT 로 계산할 것.',
    UNPAID_BILLED_AMT           NUMBER(18,2)    COMMENT '미납 청구액(원) — 정본 **DEC-3** 정의(O40): `PAY_STAT_CD IN (''F'', NULL)` 인 행의 **RQEST_AMT** 합. 🔴차감식(BILLED−PAID)을 쓰지 말 것 — 기부금이 미납을 상쇄해 과소해진다(과소 배수·연도 실측치는 문서10 §26).',
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
    IS_MULTI_SPONSORSHIP        BOOLEAN         COMMENT '[DEC-41] 그 달 회비 행이 귀속된 후원사업이 2개 이상인지 = SPONSORSHIP_SK 가 0 인 사유의 구분자. 🔴 SPONSORSHIP_SK=0 에는 두 사유가 섞인다: TRUE=다중 사업이라 대표를 고르지 않았다(정책) / FALSE=회비 행에 후원사업이 없거나 회비 행 자체가 없다. 이 플래그가 없으면 두 사유를 가를 수 없다. 🔴 IS_MULTI_PAID_BIZ 와 **모집단이 다르다**: 그쪽은 회비·PAY_AMT>0 한정 「납입 발생」 사업수이고 이 컬럼은 청구·기부금 포함 전 행의 「귀속」 사업이다 ⇒ 두 값이 어긋나는 것은 결함이 아니다. 규칙·실측 근거 = 20_issue/30_설계_의사결정.md §28(DEC-41)',
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
    DVLP_DIV_NM         VARCHAR         COMMENT '개발구분명 — MM015 라벨(신규/증액/감액/재후원/후원중단). ⚠️ 값 ''후원중단''은 EVENT_TYPE=''STOP''과 동일 사건이 중복 존재한다(동일 회원·일자 기준 거의 전건 일치 · 규모·일치율은 문서10 §26) → 두 축 합산 금지, O24 현업확인 대기',
    SPNSR_AMT           NUMBER(18,0)    COMMENT '후원금액(원) — 원천 raw. 감액·후원중단은 음수. 정본 공#38 감액(건)·#151 증액(건) = 금액÷10,000 이므로 원금액 보존(설계 §1·CONF-2). 중단원천 행은 NULL',
    DEV_CNT             NUMBER(18,4)    COMMENT '개발(건) (#149) — 정본 공#121 개발구분 = 신규(1)·증액(2)·재후원(4) 한정. ⚠️ 2026-08-03 O24 교정: 종전은 감액·후원중단까지 포함해 과대계상이었다(교정 전후 값·과대율은 문서10 §26)',
    DEV_MEMBERS         NUMBER(38,0)    COMMENT '🔴「명」이 아니다 — 개발 사건 플래그(0/1). SUM 은 개발(건)이며 실제 고유회원 대비 과대다(규모·과대율은 문서10 §26 · O39). 개발(명)(#148)은 COUNT(DISTINCT MEMBER_DK). 월 단위는 FACT_MEMBER_MONTHLY.DEV_MEMBERS 사용.',
    STOP_CNT            NUMBER(18,4)    COMMENT '중단(건) (#35)',
    STOP_MEMBERS        NUMBER(38,0)    COMMENT '🔴「명」이 아니다 — 중단 사건 플래그(0/1). SUM 은 중단(건)이며 실제 고유회원 대비 과대다(규모·과대율은 문서10 §26 · O39). 중단(명)은 COUNT(DISTINCT MEMBER_DK).',
    UNPAID_STOP_CNT     NUMBER(18,4)    COMMENT '미납중단(건)',
    UNPAID_STOP_MEMBERS NUMBER(38,0)    COMMENT '미납중단(명) — 05 2-2 원천 확인(정본 §3 건·명)',
    JOIN_DATE           DATE            COMMENT '가입일',             -- degen
    STOP_DATE           DATE            COMMENT '중단일',             -- degen
    STOP_REASON         VARCHAR         COMMENT '중단사유',            -- degen
    STOP_CHANNEL        VARCHAR         COMMENT '중단채널',            -- degen
    -- [2026-08-03 O25] 중단사유·중단경로 라벨쌍 신설(ALTER TABLE ADD COLUMN 으로 물리 반영, 위치=맨 끝).
    --   계보 계약(30_output_share/04_컬럼계보매핑 §4)이 STOP_REASON 을 "사유코드→라벨"로 명시했는데
    --   실적재는 raw 코드여서 현업이 WIDE 에서 숫자만 보던 상태였다. SILVER 라벨(채움률 100%)을 전파해 해소.
    STOP_REASON_NM      VARCHAR         COMMENT '중단사유명 — 정본 공#162. MM005 라벨(SILVER CRM_MEMBER_DISCONTINUE.DSCNTC_RSN_NM 전파). 코드는 STOP_REASON. ⚠️USE_YN 무필터 조인 — 실적재 종 중 일부가 폐지코드이며 필터를 걸면 그 라벨이 사라진다(종수·규모는 문서10 §26). 개발원천 행은 개념 부재로 NULL (O25)',  -- degen
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
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-25 안내1/DEC-43] 회원 개발이력 비정규화 12속성 전파(ALTER TABLE ADD COLUMN, 물리 위치=맨 끝).
    --   원천 = SILVER CRM_MEMBER_DEV(개발원천 행만 보유 — 중단원천 행은 개념 부재로 NULL, O34 규약과 동일).
    --   적재 시점 값으로 고정(SCD 없음) — 캠페인 마스터가 이후 정정돼도 이 사건의 값은 바뀌지 않는다.
    MBER_INFLOW_PATH_CD_AT_EVENT NUMBER(10,0) COMMENT '개발인입경로코드(MM293) — 사건 시점 동결값. 라벨=MBER_INFLOW_PATH_NM_AT_EVENT. 중단원천 행은 NULL',
    MBER_INFLOW_PATH_NM_AT_EVENT VARCHAR      COMMENT '개발인입경로명(MM293 라벨) — 사건 시점 동결값. 중단원천 행은 NULL',
    CMPGN_CTGR_CD_AT_EVENT       NUMBER(10,0) COMMENT '캠페인 카테고리코드(MM294) — 사건 시점 동결값. 라벨=CMPGN_CTGR_NM_AT_EVENT. 중단원천 행은 NULL',
    CMPGN_CTGR_NM_AT_EVENT       VARCHAR      COMMENT '캠페인 카테고리명(MM294 라벨, 현업 ''주요캠페인'' 축) — 사건 시점 동결값. 중단원천 행은 NULL',
    CMPGN_TYPE1_BSN_AT_EVENT     NUMBER(10,0) COMMENT '캠페인 유형1 코드(MM295, 국내/통합/해외) — 사건 시점 동결값. 라벨=CMPGN_TYPE1_NM_AT_EVENT. 중단원천 행은 NULL',
    CMPGN_TYPE1_NM_AT_EVENT      VARCHAR      COMMENT '캠페인 유형1명(MM295 라벨: 국내/통합/해외) — 사건 시점 동결값. 중단원천 행은 NULL',
    CMPGN_TYPE2_BSN_AT_EVENT     NUMBER(10,0) COMMENT '캠페인 유형2 코드(MM296, 굿즈/기타/사례/사업) — 사건 시점 동결값. 라벨=CMPGN_TYPE2_NM_AT_EVENT. 중단원천 행은 NULL',
    CMPGN_TYPE2_NM_AT_EVENT      VARCHAR      COMMENT '캠페인 유형2명(MM296 라벨: 굿즈/기타/사례/사업) — 사건 시점 동결값. 중단원천 행은 NULL',
    MKTG_CMPGN_CD_AT_EVENT       NUMBER(10,0) COMMENT '마케팅캠페인 코드(FK→TM_CM_MKTNG_CMPGN_MNG.MK_CMPGN_CD) — 사건 시점 동결값. 라벨=MKTG_CMPGN_NM_AT_EVENT. 중단원천 행은 NULL',
    MKTG_CMPGN_NM_AT_EVENT       VARCHAR      COMMENT '마케팅 캠페인명(Q16 라벨) — 사건 시점 동결값. 중단원천 행은 NULL',
    CMMN_BRND_AT_EVENT           NUMBER(10,0) COMMENT 'MM297 공통브랜드 코드 — 사건 시점 동결값. 라벨=CMMN_BRND_NM_AT_EVENT. 중단원천 행은 NULL',
    CMMN_BRND_NM_AT_EVENT        VARCHAR      COMMENT 'MM297 공통브랜드명 — 사건 시점 동결값. ⚠️라벨이 MM293(개발인입경로)과 상당 중복되나 현업 확인상 별도 축으로 유지. 중단원천 행은 NULL',
    MKTG_UTM_AT_EVENT            NUMBER(10,0) COMMENT 'UTM 코드(TM_CM_MKTNG_UTM.MK_UTM) — 사건 시점 동결값. 라벨=MKTG_UTM_NM_AT_EVENT. 중단원천 행은 NULL',
    MKTG_UTM_NM_AT_EVENT         VARCHAR      COMMENT 'UTM 라벨(TM_CM_MKTNG_UTM.MK_UTM_NM) — 사건 시점 동결값. 중단원천 행은 NULL',
    SPNSR_DIV_CD_AT_EVENT        VARCHAR      COMMENT '후원구분 코드(CM035: 1=정기후원·2=일시후원) — 사건 시점 동결값. 라벨=SPNSR_DIV_NM_AT_EVENT. 중단원천 행은 NULL',
    SPNSR_DIV_NM_AT_EVENT        VARCHAR      COMMENT '후원구분명(CM035 라벨) — 사건 시점 동결값. 중단원천 행은 NULL',
    CPR_DIV_CD_AT_EVENT          VARCHAR      COMMENT '법인구분 코드(CM019: A=통합·I=사단·S=사복) — 사건 시점 동결값. 라벨=CPR_DIV_NM_AT_EVENT. 중단원천 행은 NULL',
    CPR_DIV_NM_AT_EVENT          VARCHAR      COMMENT '법인구분명(CM019 라벨) — 사건 시점 동결값. 중단원천 행은 NULL',
    -- [DEC-43 2026-08-25] 캠페인 SV 3종 스냅샷 동결 잔여 3속성.
    BRAND_AT_EVENT               VARCHAR      COMMENT '브랜드명 — 사건 시점 동결값. 중단원천 행은 NULL',
    PARENT_CAMPAIGN_NAME_AT_EVENT VARCHAR     COMMENT '상위캠페인명(UPPER_CMPGN_CD 자기조인 라벨) — 사건 시점 동결값. 중단원천 행은 NULL',
    PROMO_METHOD_NAME_AT_EVENT   VARCHAR      COMMENT '홍보방법명(CM008 라벨) — 사건 시점 동결값. 중단원천 행은 NULL'
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
    SEND_MEMBERS                NUMBER(38,0)    COMMENT '🔴「명」이 아니다 — 발송 플래그(전 행 1). SUM 은 행수=발송 건수이며 실제 고유회원 대비 크게 과대다(규모·배수는 문서10 §26 · O39). 발송(명)(#85)은 COUNT(DISTINCT MEMBER_DK).',
    SUCCESS_MEMBERS             NUMBER(38,0)    COMMENT '성공수(명) (#86) — 🟢 [O93] 배선 완료(부분). 🔴 **채널별 근거 강도가 다르다**: EMAIL = 원천 집계와 교차검증해 확정(1=성공) · MSG_AT = 사전 MS282 라벨(발송완료) · **SND·PSTMTR = 0(판정 보류)**. SND 는 요청 마스터의 집계 컬럼이 전건 0 이라 교차검증 대상이 없고 SND_YN 은 사전 라벨이 없다(「발송 여부」일 가능성). PSTMTR 은 상태 컬럼 자체가 없다. ⇒ 이 컬럼의 0 은 「실패」가 아니라 채널에 따라 「판정 보류」다. 판별자 = SEND_TYPE. 채널 무시 합산은 과소집계.',
    FAIL_MEMBERS                NUMBER(38,0)    COMMENT '실패수(명) (#87) — 🟢 [O93] 배선 완료(부분). 채널별 근거는 SUCCESS_MEMBERS 주석과 동일. EMAIL 0=실패 · MSG_AT 사전 라벨 「에러」 · SND·PSTMTR = 0(판정 보류). ⚠️ MSG_AT 「예약취소」는 성공도 실패도 아니다(발송 미발생) — 양쪽 0.',
    OPEN_MEMBERS                NUMBER(38,0)    COMMENT '오픈(명) (overview) — 🟢 [O93] 배선 · 🔴 [O95 자기시정] 종전 O93 은 값 없음을 0 으로 뒀는데 그것은 「미주입 0 스캐폴드」를 새로 만든 것이었다(자기모순) ⇒ **0 과 NULL 을 의미로 분리했다**: SND 아닌 채널 = NULL(원천에 오픈 컬럼 자체가 없다) · SND 값 있음 = 1 · SND 추적개시 이후 미오픈 = 0(진짜 0) · SND 추적개시 이전 = NULL(측정 자체가 없다). 추적 개시 시점은 모델이 데이터에서 유도한다(리터럴 아님 · P31). 🔴 오픈율 = SUM(OPEN_MEMBERS)/COUNT(OPEN_MEMBERS) — 분모에 COUNT(*) 를 쓰면 NULL 구간이 섞여 과소해진다. ⚠️ 이메일·알림톡 오픈/클릭은 원천 전건 NULL 이라 NULL 이다(진짜 입고 대기 · C-9-R).',
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
    SEND_TYPE_SK                NUMBER(38,0)    COMMENT '[DEC-30] 발송구분 (FK→DIM_SEND_TYPE). 🟢커버리지 실측치는 문서10 §26 — 미매칭은 센티넬 0. ⚠️DEC-28 이 인용한 커버리지는 요청 grain 분모였다(P39)',
    DW_SOURCE_SYSTEM            VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS                  TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS                TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-11 O59-N · DEC-35 2단계] 코드→라벨 계층화 (형상 = 문서30 §23-G · 결정 = §23-J · 매핑 = 문서31).
    --   🔴 **선언 위치가 감사컬럼 뒤인 것은 의도다**(이 파일 line 298 과 동일 근거) — 라이브에는
    --      `ALTER TABLE ADD COLUMN` 으로 붙어 물리 ordinal 이 맨 끝이 된다. 앞에 적으면 재구축 시 순서가 갈라진다.
    --   ⚠️ 규칙7: 이 문안에 실측 수치를 넣지 않는다 — 규모는 문서10 §26·원장 참조(게이트 `audit_ddl_rule7.py`).
    SEND_STATUS_GROUP   VARCHAR(10)     COMMENT '축A(채널상태) 코드군 ID (조인키 · MSG_AT→MS282). 🔴SEND_STATUS 는 채널별로 다른 코드체계가 한 컬럼에 모여 있다 — **SEND_TYPE 또는 이 컬럼 동반 필수**(단독 필터는 채널 간 오조인). 🟢운영서버 코드사전 대조로 확정(2026-08-11 · 등급 C→B). EMAIL·SND·PSTMTR 은 NULL',
    SEND_STATUS_NAME    VARCHAR         COMMENT '축A 라벨 (CRM_CODE 조인). 🔴EMAIL·SND 는 **의도적 NULL** 이다 — 코드값은 있으나 코드사전에 라벨 문자열이 없어(코드군 미특정·Y/N 플래그) 조인으로 얻을 수 없고, 의미 해석을 라벨로 넣는 것은 창작이다(문서30 §23-J 결정 3 · 현업 문서20 §M-4). PSTMTR 은 원천 컬럼 부재',
    SEND_RESULT_CD      VARCHAR(10)     COMMENT '축B(통신사 결과) 코드 raw — MSG_AT 은 전송실패코드 · SND 는 통화상태. 🟢**conformed 축**이다: 두 채널이 같은 코드공간을 공유하므로 채널이 늘어도 체계가 유지된다(축A 와 대비). 원천에 값이 없는 채널은 NULL',
    SEND_RESULT_GROUP   VARCHAR(10)     COMMENT '축B 코드군 ID — 코드사전 MS283 이 정의한 4종(공통·알림톡·SMS·MMS). 🟢**리터럴 지정이 아니라 조인 결과에서 얻는다**: 4그룹에 걸쳐 코드값 중복이 없어 값 자체가 그룹을 결정한다(실측). 사전에 값이 추가되면 게이트가 잡는다',
    SEND_RESULT_NAME    VARCHAR         COMMENT '축B 라벨 (CRM_CODE 조인). 사전 초과값은 NULL 유지 + dbt warn 관측(DEC-17-B · 센티넬 창작 금지)'
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
    CAMPAIGN_SK                     NUMBER(38,0)    NOT NULL COMMENT '세션캠페인(#102) — 🔴 상수 0 하드코딩(센티넬). GA UTM 캠페인이 여러 종인데 하나로 뭉개져 있다(P51 위반 · 종수는 문서10 §26). SILVER.GA4_EVENT.UTM_CAMPAIGN(채움 규모는 문서10 §26) 미배선 → 캠페인축 분석 불가. WIDE 의 CAMPAIGN_BK/NAME/BRAND 도 전건 (미매핑)',
    PAGE_PATH                       VARCHAR         NOT NULL COMMENT '페이지경로 — 🔴 쿼리문자열 제외됨(산식 = SPLIT_PART(PAGE_LOCATION,''?'',1) · 실측 ''?'' 포함 0행). 정본 #105「페이지경로+쿼리문자열」 미충족이며 정본 #122 결연아동코드(childnum=) 파생 불가',  -- degen(grain)
    PAGE_LOCATION                   VARCHAR         COMMENT '페이지위치(#106) — 🔴 grain 내 MAX() 대표값(URL 전체 아님). 원천 distinct 대비 GOLD 생존 종수가 크게 줄어든다(소실 규모·childnum·memnum 종수는 문서10 §26). 특정 URL 유무 판정 금지',                -- degen
    VISITS                          NUMBER(38,0)    COMMENT '방문수(명) (#92) — 가산(실측 배수 1.0000). SESSION_CNT 의 가산 대체축',
    EVENT_CNT                       NUMBER(38,0)    COMMENT '이벤트수(명) (#95) — 가산(실측 배수 1.0000)',
    VIEW_CNT                        NUMBER(38,0)    COMMENT '조회수(명) (#96) — 가산(실측 배수 1.0000)',
    SESSION_CNT                     NUMBER(38,0)    COMMENT '세션수(명) (#97) — 🔴**비가산**. COUNT(DISTINCT user||session) 인데 집계 grain 이라 같은 세션이 여러 행에 반복된다. SUM 과 실제 distinct 의 격차(과대 배수)는 문서10 §26 → SUM 금지. 가산 대체 = VISITS',
    ENGAGED_SESSIONS                NUMBER(38,0)    COMMENT '참여세션수 — 🔴**비가산**. COUNT(DISTINCT) + 집계 grain. SUM 과 실제 distinct 의 격차(과대 배수)는 문서10 §26 → SUM 금지',
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
    GA_CONV_MEMBERS     NUMBER(38,0)    COMMENT 'GA전환수(명) — **DIGITAL 전용**. ⚠️O16 교정 2026-07-28: 종전 REBRDC 개발회원수가 혼입돼 합계의 상당 부분을 차지했다(혼입 비중은 문서10 §26 · 재방송 개발실적은 FACT_AD_BROADCAST.DVLP_MEMBER_CNT 로 이관)',
    GA_CONV_CNT         NUMBER(18,4)    COMMENT 'GA전환수(건/VU) — **DIGITAL 전용**. ⚠️O16 교정 2026-07-28: 종전 REBRDC 개발건수가 혼입돼 합계의 과반을 차지했다(혼입 비중은 문서10 §26) → FACT_AD_BROADCAST.DVLP_CNT 로 이관. 합계 소수=비건수, 어의 현업확인 잔여(O5)',
    DAY_OF_WEEK         VARCHAR         COMMENT '요일 (degen, AD_DATE 파생)',
    WEEK_OF_YEAR        NUMBER(2,0)     COMMENT '주차 (degen, AD_DATE 파생)',
    AD_SOURCE_TYPE             VARCHAR         COMMENT '광고유형 DIGITAL/VIDEO/REBROADCAST (degen). 출처 명시축(DEC-8·§3-A-4) — DW_SOURCE_SYSTEM(시스템 출처)과 2단 추적. DEVICE_TYPE=(해당없음) 행의 방송 여부 판별 수단',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-06 O45] 마케팅캠페인 축. **선언 위치 = 감사컬럼 뒤**(라이브 물리 ordinal 19 실측).
    --   🟢 원천은 살아 있었다: `SILVER.AGENCY_AD_PERFORMANCE.CAMPAIGN_NM` 채움 240,291/243,545(98.7%)·110종.
    --      GOLD 로 전파되지 않은 **배선 누락**이었다(원천 부재가 아니다 — Q10 과 별개다).
    --   ⚠️ `CAMPAIGN_SK`(개발캠페인)는 여전히 전건 센티넬이다. 이 컬럼이 그 대체가 아니라 **다른 grain** 이다.
    MKTG_CAMPAIGN_SK    NUMBER(38,0)    COMMENT '[O45] 마케팅캠페인 대리키 (FK→DIM_MARKETING_CAMPAIGN). 광고↔CRM 결합축. 도달·미도달 커버리지는 문서10 §26 이며 미도달은 0(미매핑) — 이 버킷을 「미집행」으로 읽지 말 것. 🔴개발캠페인(CAMPAIGN_SK) grain 결합 금지 — 대규모 팬아웃(배수·행수는 문서10 §26)'
) COMMENT = '광고 성과 코어 팩트 (grain=AD_PERF_DK · 분석축 PERF_DATE × MKTG_CAMPAIGN × AD_CREATIVE × DEVICE). 3원천 공통속성만 보유 — 유형 고유속성은 위성 FACT_AD_BROADCAST/DIGITAL/BROADCAST_CASE. 행수는 문서10 §26-B 참조';


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
    DURATION_SEC        NUMBER(9,0)     COMMENT '🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지(O29)**. 적재값이 초로 읽을 수 없는 크기라 「초」로 해석하면 오답이다(µs 해석 유력하나 미확정·현업 확인 대기 · 실측값은 문서10 §26). 원천 HH:MM:SS 표기가 캐스팅에서 무성 소실 → 유효 커버리지와 파싱 시 회복률은 문서10 §26. REBRDC NULL 은 결손 아니라 원천 부재',
    DAY_DIV             VARCHAR         COMMENT '요일구분 평일/주말 ← VIDEO.DAY_DIV_NM [VIDEO 전용]',
    PRG_START_TIME      VARCHAR         COMMENT '프로그램 시작시간 ← VIDEO.PRG_STRT_TIME [VIDEO 전용]',
    CTV_DIV             VARCHAR         COMMENT 'CTV구분 ← VIDEO.CTV_DIV_NM [VIDEO 전용]',
    BRDC_DIV            VARCHAR         COMMENT '방송구분 ← REBRDC.BRDC_DIV_NM [REBRDC 전용]',
    AD_CNT              NUMBER(38,0)    COMMENT '광고횟수 ← VIDEO·REBRDC.AD_CNT (가산)',
    CONV_CALL_CNT       NUMBER(18,4)    COMMENT '전환콜 ← VIDEO.CONV_CALL_CNT [VIDEO 전용]. 코어 INBOUND_CALL(인입콜)과 별개 measure',
    DVLP_MEMBER_CNT     NUMBER(18,4)    COMMENT '개발회원수 ← REBRDC.DVLP_MBER_CNT [REBRDC 전용]. ⚠️O16 이관: 종전 코어 GA_CONV_MEMBERS 로 혼입(GA 전환이 아니라 재방송 개발실적). ⚠️소수 척도 유지 이유: 원천에 0.5 단위 값이 실존해 NUMBER(38,0) 은 반올림으로 총합을 왜곡한다(해당 행·왜곡 규모는 문서10 §26). 원천값 보존 우선',
    DVLP_CNT            NUMBER(18,4)    COMMENT '개발건수 ← REBRDC.DVLP_CNT [REBRDC 전용]. ⚠️O16 이관: 종전 코어 GA_CONV_CNT 로 혼입(GA 전환 아님)',
    AD_VIEW_RT_SRC      NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 광고시청률 ← VIDEO.AD_VIEW_RT [VIDEO 전용]. base 부재로 DW 재계산 불가',
    CPC_SRC             NUMBER(18,6)    COMMENT '[비가산 N] 대행사 산정 CPC ← VIDEO.CPC(TEXT) [VIDEO 전용]. DW 재계산=AD_COST/CLICKS (DEC-9 대조용)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '광고성과 위성 — 방송(VIDEO ∪ REBRDC) 고유속성. 코어와 AD_PERF_DK 1:1. DEC-8 이관 + O16 해소(개발실적 분리). 원천별·합계 행수는 문서10 §26-B 참조';


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
) COMMENT = '광고성과 위성 — 디지털(DGT) 고유속성 + 대행사 산정 _SRC 7종(비가산). 코어와 AD_PERF_DK 1:1. DEC-8·DEC-9. 행수는 문서10 §26-B 참조';


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
) COMMENT = '광고성과 위성 — 재방송 사례 정규화(15컬럼 반복군 → CASE_SEQ 언피벗). 코어에 1:N(fan-out 주의). ⚠️아동명 미적재(PII O14). 행수는 문서10 §26-B 참조';


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
    TOTAL_CNT           NUMBER(38,0)    COMMENT '총인원 — 🟢 [O93] 배선 완료. 참여행 1건 = 1 이며 상태 무관이라 코드체계와 독립적이다(전건 유효).',
    WAIT_CNT            NUMBER(38,0)    COMMENT '대기인원 — 🟢 [O93] **캠페인행사(EVENT_KIND=CRMN) 구간만** 배선. MS006 라벨 「대기」·「대기(결제)」 합. 🔴 일반행사 구간의 0 은 「대기 0명」이 아니라 **「해당 없음」**이다 — 일반행사 코드체계(MS304)는 퍼널 단계 축이라 대기 상태가 없다. 판별자 = EVENT_KIND.',
    CANCEL_CNT          NUMBER(38,0)    COMMENT '취소인원 — 🟢 [O93] **캠페인행사 구간만** 배선(MS006 라벨 「취소」). 🔴 일반행사 구간의 0 = 해당 없음. 판별자 = EVENT_KIND.',
    CONFIRM_CNT         NUMBER(38,0)    COMMENT '신청확정인원 — 🔴 전건 0(미배선). 원인 = 코드사전에 「신청확정」 라벨이 없다. 있는 것은 「신청」·「참여」뿐이고 어느 쪽이 신청확정인지는 업무 정의라 임의 선택 불가(라벨 창작 금지). 현업 회신 대기(문서20 §I). 0 을 실측값으로 읽지 말 것.',
    PARTICIPATE_CNT     NUMBER(38,0)    COMMENT '참여인원 — ⚠️행당 상수 1 하드코딩(집계 아님). 취소·불참 행도 1. 🟢 [O93] 정확한 참여수는 PART_STATUS_NAME=''참여'' 로 필터할 것(캠페인행사 구간). 이 컬럼 값은 기존 소비 호환을 위해 유지한다.',
    ABSENT_CNT          NUMBER(38,0)    COMMENT '불참인원 — 🟢 [O93] **캠페인행사 구간만** 배선(MS006 라벨 「불참」). 🔴 일반행사 구간의 0 = 해당 없음. 판별자 = EVENT_KIND.',
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
    PART_STATUS         VARCHAR         COMMENT '🔴 참여상태 — 코드체계 2개 혼입(O28). 일반행사=MS304(110 Success·120 Fail·130~220 N_step_right/fail) / 캠페인행사=소정수 1~6(의미 미확정·문서20 §I) — 체계별 규모는 문서10 §26. 판별자=EVENT_KEY 접두(고아가 있어도 안전). 두 체계 합산·GROUP BY 금지 · 한글 비교는 0행',   -- degen
    PART_PATH           VARCHAR         COMMENT '참여경로(05 3-5)',   -- degen
    PART_CHANNEL        VARCHAR         COMMENT '참여채널(05 3-5)',   -- degen
    INCREASE_FLAG       BOOLEAN         COMMENT '증액여부 — 🔴 전건 NULL(미배선). 정소재지는 FACT_MEMBER_EVENT.DVLP_DIV_CD(MM015 코드2)',   -- degen
    EVENT_BK            VARCHAR         COMMENT '[DEC-30] degenerate key — 원천 행사키 ← CRM_EVENT_PARTICIPATION.EVENT_KEY(전건 채움). 🔴고아 행사 식별자 보존용: 마스터 부재 행사의 행이 EVENT_SK=0 으로 뭉개져 서로 구별되지 않았다(고아 규모·SILVER 대비 종수는 문서10 §26). 🔷(EVENT_BK,MEMBER_DK,PARTCPT_SEQ) 가 행 유일 식별 — EVENT_SK 로는 키 충돌이 발생한다(규모는 문서10 §26). ⚠️접두(EVENT_/CRMN_)가 O28 코드체계 판별자',   -- degen
    PARTCPT_SEQ         NUMBER(38,0)    COMMENT '[DEC-30] degenerate key — 참여 일련번호 ← CRM_EVENT_PARTICIPATION.PARTCPT_SEQ(전건 채움). 🔷(EVENT_SK,MEMBER_DK,PARTCPT_SEQ) 가 행을 유일 식별 — (행사,회원)만으로는 중복이 남는다(규모는 문서10 §26). ⚠️전역 순번 아님 · 음수와 INT_MIN 값이 실존한다(규모는 문서10 §26) → 식별자 전용, 정렬·범위조건 금지',   -- degen
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-11 O59-N · DEC-35 2단계] 코드→라벨 계층화 (형상 = 문서30 §23-G · 결정 = §23-J · 매핑 = 문서31).
    --   🔴 **선언 위치가 감사컬럼 뒤인 것은 의도다**(이 파일 line 298 과 동일 근거) — 라이브에는
    --      `ALTER TABLE ADD COLUMN` 으로 붙어 물리 ordinal 이 맨 끝이 된다. 앞에 적으면 재구축 시 순서가 갈라진다.
    --   ⚠️ 규칙7: 이 문안에 실측 수치를 넣지 않는다 — 규모는 문서10 §26·원장 참조(게이트 `audit_ddl_rule7.py`).
    PART_STATUS_GROUP   VARCHAR(10)     COMMENT '참여상태 코드군 ID (조인키 · 일반행사→MS304 · 캠페인행사→MS006). 🔴O28 다체계의 **구조적 해소축**이다 — PART_STATUS 단독 필터·GROUP BY 는 두 체계를 섞는다(판별자 = 이 컬럼 또는 EVENT_BK 접두). 🔴두 원천의 「참여」 정의 자체가 다르므로 합산 금지',
    PART_STATUS_NAME    VARCHAR         COMMENT '참여상태 라벨 (CRM_CODE 조인). ⚠️일반행사(MS304) 라벨은 코드사전에 **영문**으로 등록돼 있다(Success·N_step_right 계열) — 현업 한글 표기 회신 대기(문서20 §M-1)이며 우리가 창작하지 않았다. 미등재·오염 코드는 NULL',
    PART_PATH_GROUP     VARCHAR(10)     COMMENT '참여경로 코드군 ID (조인키 · 일반행사→MS303 · 캠페인행사→MS004=신청경로). 🟢운영서버 코드사전 대조로 확정(2026-08-11 · 등급 C→B) — 조건부 적용은 해소됐고 롤백은 발동하지 않았다',
    PART_PATH_NAME      VARCHAR         COMMENT '참여경로 라벨 (CRM_CODE 조인 · 코드군 확정). 미등재·오염 코드는 NULL 유지',
    PART_CHANNEL_GROUP  VARCHAR(10)     COMMENT '참여채널 코드군 ID (조인키 · 일반행사→MS302 · 등급 B 배타 확정). 캠페인행사는 원천에 채널 축이 없어 NULL(구조적 부재 · P21)',
    PART_CHANNEL_NAME   VARCHAR         COMMENT '참여채널 라벨 (CRM_CODE 조인). 미등재·오염 코드는 NULL 유지',
    -- [2026-08-12 O61 · D2 구조 처방] 원천 계열 판별 2컬럼 (근거 = 원장 §O59-S ③④ · 명세 = 99 §0-Y-1).
    --   🔴 **왜 팩트에 두는가**: 종전 판별자는 `DIM_EVENT.EVENT_KIND(_NAME)` 하나였고 그것은 **차원에서 온다** ⇒
    --      행사 마스터 미매칭 구간(EVENT_SK=0)에서 `'(미매핑)'` 이 되어 **가장 큰 단일 버킷에서 계열을 알려주지 못했다.**
    --      이 2컬럼은 SILVER `DW_SOURCE_TABLE`(원천 분기) 에서 오므로 **조인과 무관하게 전건 값을 갖는다.**
    --   🔴 어휘는 `DIM_EVENT.EVENT_KIND`/`EVENT_KIND_NAME` 과 **conform**(같은 값을 써야 두 축의 교차 검증이 성립).
    --   ⚠️ 규칙7: 이 문안에 실측 수치를 넣지 않는다 — 규모는 문서10 §26·원장 참조.
    EVENT_KIND          VARCHAR(10)     COMMENT '원천 계열 판별 **코드** — 팩트 자체 보유(SILVER.CRM_EVENT_PARTICIPATION.DW_SOURCE_TABLE 분기). 값 2종: EVENT=일반행사 원천 · CRMN=캠페인행사 원천. 🔴DIM_EVENT.EVENT_KIND 와 어휘가 같지만 **조인과 무관하게 전건 값을 갖는다** — 행사 미매칭(EVENT_SK=0) 구간에서도 계열을 가른다(차원축은 그 구간이 (미매핑) 이라 무력하다). ⇒ O28 다체계 축(PART_STATUS·PART_PATH·PART_CHANNEL)의 판별자는 **이 컬럼**을 쓴다. ⚠️등재 매핑에 없는 원천이 인입되면 NULL 로 드러난다(ELSE 절 금지 · P31)',
    EVENT_KIND_NAME     VARCHAR         COMMENT '원천 계열 판별 **라벨** — 현업 응답·분해용 정본 축. 값 2종: 일반행사 · 캠페인행사. DIM_EVENT.EVENT_KIND_NAME 과 어휘 conform. 🔴차원축과 달리 **(미매핑) 사각지대가 없다**(전건 채움). 🔴이 라벨은 업무 분류가 아니라 **참여 행이 어느 원천에서 왔는지**를 뜻한다 — 온·오프라인 구분이 아니다. ⚠️코드사전에 대응 그룹이 없는 **파생 라벨**이므로 CRM_CODE 조인 대상이 아니다'
) COMMENT = '행사 참여 팩트 (DATE_SK × MEMBER_DK × EVENT_SK). 🔴O28: PART_STATUS 에 코드체계 2개 혼입 — 행사종류 미분리 집계는 조용히 틀린다. 🔴미주입 14컬럼(카운트 6·횟수 4·degen NULL 2·FK 센티넬 2) 전건 0/NULL — 0 을 실측값으로 읽지 말 것. 🟡행 식별자 부재(유일조합=EVENT_KEY,MEMBER_DK,PARTCPT_SEQ). ⚠️마스터 부재로 고아 EVENT_SK=0 이 존재한다 — 총행수·고아 규모는 문서10 §26·§26-B 참조';


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
    -- 🔴 [2026-08-20 O96 · DEC42] 아래 컬럼은 **의도적 영구 NULL** 이다 — 폐기(deprecated) 슬롯.
    --    생성 근거는 실재했다(필드인벤토리 「편성예산(연)」 · 지표 「연 편성예산」 매핑 교정 2026-07-27)
    --    그러나 O93 에서 연 grain 을 `FACT_BUDGET_YEARLY` 로 분리해 **근거가 대체**됐다.
    --    ⚠️ 이 컬럼에 값을 넣지 마라 — 월 grain 에 연값을 넣으면 SUM 이 12배로 부풀고 조용히 틀린다.
    PLAN_BUDGET_YEAR    NUMBER(18,2)    COMMENT '🔴폐기 슬롯 — **의도적 영구 NULL**(값 없음이 정상). 연 편성예산은 **`FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR`(연 grain)** 를 쓴다. 🔴원천 부재가 아니다 — 원천 `YEAR_BDGT_TOT_AMT` 는 실재하며 연 팩트에 적재돼 있다(종전의 「원천 부재」 주장은 O96 에서 철회). 이 컬럼을 월 팩트에 채우면 grain 혼입으로 SUM 이 12배 부푼다. 처분 결정 = DEC42.',
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
-- FACT 16: FACT_BUDGET_YEARLY (FBY) — 연 예산 팩트  [2026-08-20 O93 신설]
-- ----------------------------------------------------------------------------
-- 왜 신설했나: ERP 원장 `BDGT_ACMSLT_LEDGER` 는 **연 총액 4종**(편성·추경·조정·집행)과
--   **월별 12벌**을 한 행에 함께 담는다. 종전에는 월 12벌만 언피벗해 `FACT_BUDGET` 에 넣고
--   연 총액은 버렸다 ⇒ `FACT_BUDGET.PLAN_BUDGET_YEAR` 가 **전건 NULL** 이었다.
-- 🔴 연 총액을 월 팩트에 넣지 않는 이유 = **grain 혼입**이다. 연값을 12개월에 복제하면
--    `SUM(PLAN_BUDGET_YEAR)` 이 **12배**로 부풀고, 그 오류는 에러 없이 조용히 나온다.
--    (같은 함정을 DIM_MONTH COMMENT 가 fan-out 으로 이미 경고한다 — 이건 그 반대 방향이다.)
--    ⇒ 사용자 결정(2026-08-20) = **연 grain 을 별도 팩트로 분리**한다.
-- 🟢 그래서 이 팩트는 SUM 이 항상 안전하다 — 1행 = 1(연 × 조직 × 예산과목)이고 중복이 없다.
-- ⚠️ `FACT_BUDGET.PLAN_BUDGET_YEAR` 는 **NULL 로 남긴다**(값을 두 곳에 두지 않는다).
--    소비는 이 팩트를 쓰고, 월 편성은 `FACT_BUDGET.PLAN_BUDGET_MONTH` 를 쓴다.
-- ⚠️ ORG_SK=0 고정 — ERP 원장에 조직 귀속 축이 없다(월 팩트와 같은 사유).
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY (
    BUDGET_YEAR         NUMBER(4,0)     NOT NULL COMMENT '예산연도 YYYY. 🔴본 팩트의 시간 grain 은 **연**이다 — 월 팩트(FACT_BUDGET)와 조인해 합산하지 말 것(연값이 월수만큼 증폭된다).', -- GRAIN
    ORG_SK              NUMBER(38,0)    NOT NULL COMMENT '조직 (FK→DIM_ORG). ⚠️ERP 원장에 조직 귀속이 없어 전건 0(Unknown) 이다.',
    BUDGET_ITEM_SK      NUMBER(38,0)    NOT NULL COMMENT '예산 세세목 (FK→DIM_BUDGET_ITEM). 월 팩트와 **동일 MD5 산식**이라 두 팩트가 같은 과목축으로 대조된다.',
    CAMPAIGN_SK         NUMBER(38,0)    COMMENT '캠페인 (FK→DIM_CAMPAIGN). ⚠️원천 연결 없음 → 0.',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '후원사업 (선택 FK→DIM_SPONSORSHIP). ⚠️원천 연결 없음 → NULL.',
    PLAN_BUDGET_YEAR    NUMBER(18,2)    COMMENT '연 편성예산 = 원천 YEAR_BDGT_TOT_AMT. 🟢SUM 안전(연 grain).',
    CHN_BUDGET_YEAR     NUMBER(18,2)    COMMENT '연 추경예산 = 원천 CHN_BDGT_TOT_AMT.',
    ADJ_BUDGET_YEAR     NUMBER(18,2)    COMMENT '연 조정예산 = 원천 ADJ_BDGT_TOT_AMT. ⚠️편성보다 클 수 있다(추경·전용 반영분).',
    EXEC_BUDGET_YEAR    NUMBER(18,2)    COMMENT '연 집행예산 = 원천 EXEC_TOT_AMT. ⚠️월 팩트 EXEC_BUDGET_ERP 의 12개월 합과 반드시 일치하지는 않는다 — 원천이 두 값을 따로 관리한다. 불일치 자체가 원천 상태이므로 맞추지 말 것.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '연 예산 팩트 (YEAR × ORG × BUDGET_ITEM · ERP 연 총액 4종) — 🔴 [O93] FACT_BUDGET 은 월 grain 이라 연 총액을 담으면 SUM 이 12배가 된다. 그래서 연축을 분리했다. 🟢 이 팩트는 SUM 이 항상 안전하다. ⚠️ 월 편성·월 집행은 FACT_BUDGET 을 쓴다.';


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
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [2026-08-06 O45] 획득 귀속축 2종. **선언 위치 = 감사컬럼 뒤**(라이브 물리 ordinal 25·26 실측).
    --   🔴 이 팩트가 뷰 `GOLD.DIM_MEMBER_ACQUISITION` 을 통해 **회원 귀속 차원**으로 소비된다 —
    --      FMM·FSE·FEP·FME 가 `MEMBER_DK` 1:1 조인으로 캠페인·부서·후원사업을 분해한다.
    --      팬아웃 0 실측(FMM 40,054,883 · FSE 38,470,780 · FEP 1,134,126 · FME 4,633,105 전부 불변).
    --   🔴 O8(다중귀속 규칙 미확정)을 임의로 푼 것이 아니라 **「획득 시점」 명시 규칙**을 쓴 것이다.
    ACQ_ORG_SK              NUMBER(38,0)    COMMENT '[O45] 획득 시점 담당조직 대리키 (FK→DIM_ORG). 0=미매핑. ⚠️ 「현재 소속」이 아니라 **획득 시점** 값이다',
    ACQ_SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '[O45] 획득 시점 후원사업 대리키 (FK→DIM_SPONSORSHIP). 0=미매핑. ⚠️ 회비 납입 대상 후원사업(`FACT_MEMBER_FEE.SPONSORSHIP_SK`)과 **의미가 다르다** — 같은 라벨이 두 축이다',
    -- [DEC-43 2026-08-25] 회원 개발이력 비정규화 12속성. 원천 = 획득 사건(ACQ_BASIS 채택 행)의
    --   SILVER CRM_MEMBER_DEV 값을 그대로 승계(FACT_MEMBER_EVENT._AT_EVENT 경유 — SILVER 재조회 금지).
    --   적재 시점 값으로 고정(SCD 없음) — 캠페인 마스터가 이후 정정돼도 이 회원의 획득 속성은 바뀌지 않는다.
    --   🔴 `GOLD.DIM_MEMBER_ACQUISITION` 이 이 12속성 중 8속성(라벨만)을 그대로 승계해 노출한다.
    ACQ_MBER_INFLOW_PATH_CD NUMBER(10,0)    COMMENT '획득 캠페인의 모집채널 코드(MM293) — 적재 시점 동결값. 라벨=ACQ_MBER_INFLOW_PATH_NM',
    ACQ_MBER_INFLOW_PATH_NM VARCHAR         COMMENT '획득 캠페인의 모집채널명(MM293 라벨) — 적재 시점 동결값. ⚠️채널이며 「주요캠페인」이 아니다 — 주요캠페인은 ACQ_CMPGN_CTGR_NM 이다',
    ACQ_CMPGN_CTGR_CD       NUMBER(10,0)    COMMENT '획득 캠페인의 카테고리 코드(MM294) — 적재 시점 동결값. 라벨=ACQ_CMPGN_CTGR_NM',
    ACQ_CMPGN_CTGR_NM       VARCHAR         COMMENT '획득 캠페인의 카테고리 라벨(MM294, 현업 ''주요캠페인'' 축) — 적재 시점 동결값',
    ACQ_CMPGN_TYPE1_BSN     NUMBER(10,0)    COMMENT '획득 캠페인 유형1 코드(MM295, 국내/통합/해외) — 적재 시점 동결값. 라벨=ACQ_CMPGN_TYPE1_NM',
    ACQ_CMPGN_TYPE1_NM      VARCHAR         COMMENT '획득 캠페인 유형1명(MM295 라벨: 국내/통합/해외) — 적재 시점 동결값',
    ACQ_CMPGN_TYPE2_BSN     NUMBER(10,0)    COMMENT '획득 캠페인 유형2 코드(MM296, 굿즈/기타/사례/사업) — 적재 시점 동결값. 라벨=ACQ_CMPGN_TYPE2_NM',
    ACQ_CMPGN_TYPE2_NM      VARCHAR         COMMENT '획득 캠페인 유형2명(MM296 라벨: 굿즈/기타/사례/사업) — 적재 시점 동결값',
    ACQ_MKTG_CMPGN_CD       NUMBER(10,0)    COMMENT '획득 캠페인의 마케팅캠페인 코드(FK→TM_CM_MKTNG_CMPGN_MNG.MK_CMPGN_CD) — 적재 시점 동결값. 라벨=ACQ_MKTG_CMPGN_NM',
    ACQ_MKTG_CMPGN_NM       VARCHAR         COMMENT '획득 캠페인의 마케팅 캠페인명(Q16 라벨) — 적재 시점 동결값',
    ACQ_CMMN_BRND           NUMBER(10,0)    COMMENT '획득 캠페인의 MM297 공통브랜드 코드 — 적재 시점 동결값. 라벨=ACQ_CMMN_BRND_NM',
    ACQ_CMMN_BRND_NM        VARCHAR         COMMENT '획득 캠페인의 MM297 공통브랜드명 — 적재 시점 동결값. ⚠️라벨이 MM293(개발인입경로)과 상당 중복되나 현업 확인상 별도 축으로 유지',
    ACQ_MKTG_UTM            NUMBER(10,0)    COMMENT '획득 캠페인의 UTM 코드(TM_CM_MKTNG_UTM.MK_UTM) — 적재 시점 동결값. 라벨=ACQ_MKTG_UTM_NM',
    ACQ_MKTG_UTM_NM         VARCHAR         COMMENT '획득 캠페인의 UTM 라벨(TM_CM_MKTNG_UTM.MK_UTM_NM) — 적재 시점 동결값',
    ACQ_SPNSR_DIV_CD        VARCHAR         COMMENT '획득 캠페인의 후원구분 코드(CM035: 1=정기후원·2=일시후원) — 적재 시점 동결값. 라벨=ACQ_SPNSR_DIV_NM',
    ACQ_SPNSR_DIV_NM        VARCHAR         COMMENT '획득 캠페인의 후원구분명(CM035 라벨) — 적재 시점 동결값',
    ACQ_CPR_DIV_CD          VARCHAR         COMMENT '획득 캠페인의 법인구분 코드(CM019: A=통합·I=사단·S=사복) — 적재 시점 동결값. 라벨=ACQ_CPR_DIV_NM',
    ACQ_CPR_DIV_NM          VARCHAR         COMMENT '획득 캠페인의 법인구분명(CM019 라벨) — 적재 시점 동결값',
    -- [DEC-43] 캠페인 SV 3종 스냅샷 동결 잔여 3속성.
    ACQ_BRAND               VARCHAR         COMMENT '획득 캠페인의 브랜드명 — 적재 시점 동결값',
    ACQ_PARENT_CAMPAIGN_NAME VARCHAR        COMMENT '획득 캠페인의 상위캠페인명(UPPER_CMPGN_CD 자기조인 라벨) — 적재 시점 동결값',
    ACQ_PROMO_METHOD_NAME   VARCHAR         COMMENT '획득 캠페인의 홍보방법명(CM008 라벨) — 적재 시점 동결값'
) COMMENT = '회원 획득 코호트 팩트 (1행=1회원 · grain 유일이라 PK 선언). 캠페인별 중단률·유지기간·획득시점 회원특성의 정본. 🔴 중단률은 12개월 고정 이탈률(STOPPED_12M_MEMBERS/OBSERVABLE_12M_MEMBERS)을 쓴다 — 누적 이탈률은 관측 기간에 지배되어 캠페인 비교를 왜곡한다. 개발 이력이 없는 중단회원은 획득 캠페인이 없어 미포함(중단 총계는 FACT_MEMBER_EVENT). [DEC-43 2026-08-25] 캠페인 12속성(ACQ_MBER_INFLOW_PATH_*·ACQ_CMPGN_CTGR_*·ACQ_CMPGN_TYPE1/2_*·ACQ_MKTG_CMPGN_*·ACQ_CMMN_BRND*·ACQ_MKTG_UTM*·ACQ_SPNSR_DIV_*·ACQ_CPR_DIV_*·ACQ_BRAND·ACQ_PARENT_CAMPAIGN_NAME·ACQ_PROMO_METHOD_NAME)을 획득 사건의 SILVER CRM_MEMBER_DEV 적재시점 값으로 신설 — DIM_MEMBER_ACQUISITION 이 이를 승계한다.';


-- ============================================================================
-- FACT 14: FACT_MEMBER_FEE — 회비 분해 팩트 [2026-08-06 O45 신설]
-- ----------------------------------------------------------------------------
-- grain = MEMBER_DK × MONTH_KEY × SPONSORSHIP_SK × PAYMENT_SK × FEE_DIV_CD × PAYMENT_TYPE × SETLE_CD
--         (실측 40,262,076행 · 중복 그룹 0 = GATE-D2 · 2026-08-07 O45-C 재빌드 후)
-- 🔴 왜 FMM 에 컬럼 추가가 아닌가: FMM grain = 회원×월 정확히 1행(40,054,883 = distinct member-month).
--    후원사업을 붙이면 회원-월-후원사업 39,563,730 vs 회원-월 37,148,615 = 6.5% 증가로 **grain 이 깨진다.**
--    **grain 이 다르면 팩트를 나눈다.**
-- 🔴 **FMM 과 같은 표에서 합산 금지 — 동일 원천(SILVER.CRM_PAYMENT_BILLING) 이중계상이다.**
--    실측 증거: `FMM ⋈ FMF (MEMBER_DK, MONTH_KEY)` → 행 40,054,883 → 40,262,076 이고
--    `SUM(FMM.BILLED_AMT)` 891,959,790,888 → **1,056,821,121,099 (+18.5% 과대계상)**.
--    ⇒ 회원-월 요약이면 FMM, 회비 분해(납입방식·회비구분·납입일)면 FMF **중 하나만** 앵커로 쓴다.
-- 🔴 PK 미선언이 의도다: grain 7종 중 `FEE_DIV_CD` 가 기부금 행에서 원천 NULL 이라 PK(=NOT NULL 의미)
--    선언은 사실과 어긋난다. 유일성은 dbt GROUP BY + O45_VERIFY GATE-D2 로 보증한다.
-- ✅ O45-C 해소(2026-08-06 · 사용자 결정 = FMF 에 필터 적용): 모델에 `where MBER_NO is not null` 을
--    적용해 **FMM 규약과 일치**시켰다. 제외 대상 = 회원 미귀속 불량 5행(`SUM(PAY_AMT)` 34,672,700 ·
--    2011-03/04 납입 · `RQEST_AMT` NULL). 회원 grain 팩트에서 `MEMBER_DK` NULL 행은 `DIM_MEMBER` 로
--    조인되지 않아 어차피 소비 불가이며, 총계만 SILVER 원표와 맞아 보이게 만든다.
--    ✅ [2026-08-07 재빌드 완료 · 기대값 전부 재현] 행 40,262,078 → **40,262,076** · `PAID_FEE` 895,212,981,808 →
--    **895,178,309,108** (= FMM 과 동일) · `BILLED_AMT`·`PAID_FEE_BILLABLE`·`UNPAID_BILLED_AMT` 불변.
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_FEE (
    MONTH_KEY           NUMBER(6,0)     COMMENT '회비월 YYYYMM (FK→DIM_DATE.MONTH_KEY 개념축). 무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월 — FMM 과 동일 규칙',
    MEMBER_DK           VARCHAR(10)     COMMENT '회원 자연키 (FK→DIM_MEMBER.MEMBER_DK). 🔴VARCHAR(10) 규약(O12/AC-1) — 원천 MBER_NO 최대길이 9 실측',
    SPONSORSHIP_SK      NUMBER(38,0)    COMMENT '🔴**납입 대상** 후원사업 대리키 (FK→DIM_SPONSORSHIP). 원천 채움 커버리지는 문서10 §26. 획득 후원사업(FMC.ACQ_SPONSORSHIP_SK)과 **의미가 다르다**',
    PAYMENT_SK          NUMBER(38,0)    COMMENT '결제수단 대리키 (FK→DIM_PAYMENT). ⚠️라벨 커버리지는 문서10 §26 — 원천 종 중 일부는 코드그룹 미특정으로 0(미매핑). 원본은 SETLE_CD 참조(O45-B)',
    FEE_DIV_CD          VARCHAR         COMMENT '회비구분 코드(PM010). 🔴기부금 행은 원천이 NULL — **결측이 아니라 해당없음**',
    FEE_DIV_NAME        VARCHAR         COMMENT '회비구분명: 정기·선물금·일시·긴급구호 (PM010 라벨)',
    PAYMENT_TYPE        VARCHAR         COMMENT '납입유형 = 회비/기부금. 🔴납부율·미납 분석은 회비만으로 스코프 — 기부금은 청구(RQEST_AMT)가 전건 NULL 이라 분모에 못 들어간다(O40)',
    SETLE_CD            VARCHAR         COMMENT 'degen: 결제수단 원본 코드. 라벨 없는 코드(3·10·6·13·7)를 잃지 않기 위해 보존 — 규모는 문서10 §26 · 현업 코드그룹 확인 대상(O45-B)',
    LAST_PAY_DATE_SK    NUMBER(8,0)     COMMENT '해당 조합의 **최종 납입일** (FK→DIM_DATE). 🔴시점 축이며 합계가 아니다. FMM 은 월 팩트라 「기준일(납입일)」은 이 팩트에서만 답한다',
    LAST_BILL_DATE_SK   NUMBER(8,0)     COMMENT '해당 조합의 최종 청구일 (FK→DIM_DATE)',
    BILLED_AMT          NUMBER(38,2)    COMMENT '청구액(원) = SUM(RQEST_AMT). FMM·SILVER 와 총계 일치 실측(GATE-D · 값은 문서10 §26)',
    PAID_FEE            NUMBER(38,2)    COMMENT '납입 총액(원) = 회비 + 기부금. 🔴납부율 분자로 쓰지 말 것(O40). ⚠️O45-C: FMM 대비 차이가 있고 원인은 회원번호 부재 행이 FMM 규약으로 제외되는 것이다(금액·행 규모는 문서10 §26 · O57-B 규명완료 · 결함 아님)',
    PAID_FEE_BILLABLE   NUMBER(38,2)    COMMENT '회비 납입액(원) — 납부율 분자 **정본**(O40). FMM 과 완전일치 실측(값은 문서10 §26)',
    UNPAID_BILLED_AMT   NUMBER(38,2)    COMMENT '미납 청구액(원) — DEC-3 정본 = PAY_STAT_CD IN (F, NULL) 인 청구액. 🔴차감식 아님. ⚠️조회 시점 스냅샷. FMM 과 완전일치(값은 문서10 §26)',
    BILLING_ROWS        NUMBER(38,0)    COMMENT '집계된 원천 회비행 수. 🔴금액도 「건수」도 아니다(정본 (건) 정의는 CONF-2 미결)',
    UNPAID_FLAG         BOOLEAN         COMMENT '해당 조합에 미납 청구행이 하나라도 있는가(BOOLOR_AGG)',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '[O45] 회비 분해 팩트. grain = 회원 × 회비월 × 후원사업 × 납입방식 × 회비구분 × 납입유형 × 결제수단. 🔴FACT_MEMBER_MONTHLY 와 **동일 원천**(SILVER.CRM_PAYMENT_BILLING)이므로 두 팩트를 같은 표에서 SUM 하면 이중계상이다 — 실측 조인 시 청구액이 부풀며 그 규모는 문서10 §26·§26-B 참조. 납입방식·회비구분·납입일 축이 필요할 때만 이 팩트를 앵커로 쓰고, 그 외에는 FACT_MEMBER_MONTHLY 를 정본으로 쓸 것. measure 식은 FMM 과 동일(O40 정본).';


-- ============================================================================
-- FACT 15: FACT_DEV_ACHIEVEMENT — 회원개발 목표 대비 실적 (월 conform · 구 WIDE_DEV_ACHIEVEMENT)
--   [2026-08-10 O53] 신설. 구조·COMMENT 소유주 = 본 파일 / 적재 = dbt(incremental append + pre-hook TRUNCATE).
--   🔴 merge 금지: 완전 재산출 차원에 merge 를 쓰면 grain 이동 시 구 행이 잔존한다(문서50 §300 R1 · P131).
--   PK(정보성) = MONTH_KEY, ORG_SK, DEV_TYPE
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_DEV_ACHIEVEMENT (
    MONTH_KEY         NUMBER(6,0)     NOT NULL COMMENT '목표·실적 공통 월키 YYYYMM (월 conform 축)',
    CAL_YEAR          NUMBER(4,0)     COMMENT 'FLOOR(MONTH_KEY/100) — 연도',
    CAL_MONTH         NUMBER(2,0)     COMMENT 'MOD(MONTH_KEY,100) — 월',
    ORG_SK            NUMBER(38,0)    NOT NULL COMMENT '조직 대리키 (FK→DIM_ORG). 실적측은 실적부서(ACMSLT_DEPT_CD) 기준',
    ORG_DEPARTMENT    VARCHAR         COMMENT '부서명 (정본 #116) — 장표 첫 축. DIM_ORG.DEPARTMENT',
    ORG_DIVISION      VARCHAR         COMMENT 'DIM_ORG.DIVISION — 실적지부. ⚠️산출규칙 미확정으로 전건 NULL (CONF-4)',
    ORG_TEAM          VARCHAR         COMMENT 'DIM_ORG.TEAM — 팀. ⚠️보류로 전건 NULL (CONF-4)',
    ORG_CORP          VARCHAR         COMMENT 'DIM_ORG.CORP — 법인. ⚠️부서 차원에서 산출 불가로 전건 NULL (CONF-4)',
    DEV_TYPE          VARCHAR         NOT NULL COMMENT '개발구분 코드 (MM015 중 1신규·2증액·4재후원). 정본 공#121 개발 정의와 일치하는 축 — 목표·실적 공통',
    DEV_TYPE_NAME     VARCHAR(100)    COMMENT '개발구분명 (MM015 라벨). 코드는 DEV_TYPE',
    GOAL_CNT          NUMBER(18,4)    COMMENT '월 회원개발목표(건) — 장표 「월 목표」. 원천 CRM TM_CM_MBER_DVLP_GOAL',
    ACTUAL_CNT        NUMBER(18,4)    COMMENT '월 개발실적(건) — 장표 「월 실적」. FME.DEV_CNT 월 롤업(코드 1·2·4 한정)',
    GOAL_CNT_YTD      NUMBER(18,4)    COMMENT '(누계)월 목표(건) — 당해년 1월~당월 누적. 🔴월 비가산 — 월을 가로질러 합산 금지',
    ACTUAL_CNT_YTD    NUMBER(18,4)    COMMENT '(누계)월 실적(건) — 당해년 1월~당월 누적. 🔴월 비가산',
    GOAL_CNT_YEAR     NUMBER(18,4)    COMMENT '연 목표(건) — 당해년 12개월 합. 별도 저장 지표가 아니라 월 목표의 연 합계다(정본 공#3). 🔴월 비가산',
    ACTUAL_CNT_YEAR   NUMBER(18,4)    COMMENT '연 실적(건) — 당해년 12개월 합. 🔴월 비가산',
    HAS_GOAL_ROW      BOOLEAN         COMMENT '목표 **행**의 존재 여부 — 값이 0 이거나 NULL 이어도 TRUE 다. 🔴**달성율 스코프로 쓰지 말 것**: 원천이 2020년부터 부서×월×개발구분 조합을 전량 행 생성하고 미편성분을 0 으로 채우므로 목표 행의 과반이 0 이다. 이 플래그로 분자를 스코프하면 목표 0 행의 실적이 분모 없이 분자에 들어가 달성율이 폭증한다(실측 확인 후 교정). 달성율은 HAS_POSITIVE_GOAL 을 쓴다. 이 컬럼의 용도는 「목표 행 자체가 없는 조합」(=FALSE)을 찾는 것이다',
    HAS_POSITIVE_GOAL BOOLEAN         COMMENT '🟢**목표가 실제로 편성됐는지**(GOAL_CNT>0) — 달성율 분모·분자 스코프의 **정본**이다. 목표 미편성 부서·월의 실적이 분자에 섞이면 달성율이 조용히 과대해진다(P18·P63). SV_DEV_ACHIEVEMENT.ACHIEVEMENT_RATE 는 이 조건을 식에 못박아 두었으므로 소비 시 별도 필터가 불필요하다. ⚠️FALSE 는 「목표 0 건으로 명시」와 「목표 미입력(원천 NULL)」을 함께 담는다 — 구분이 필요하면 FACT_TARGET_DEV.GOAL_CNT IS NULL 로 팩트에서 본다',
    HAS_ACTUAL        BOOLEAN         COMMENT '실적 발생 여부. FALSE 는 목표만 편성된 월(미래월 포함)이다 — 실적 0 으로 읽되 「미달」로 단정하지 말 것',
    DW_SOURCE_SYSTEM  VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    PRIMARY KEY (MONTH_KEY, ORG_SK, DEV_TYPE)
) COMMENT = '회원개발 **목표 대비 실적** 월 conform 팩트 — FACT_TARGET_DEV(목표) × FACT_MEMBER_EVENT(실적) FULL OUTER. grain=MONTH_KEY×ORG_SK×DEV_TYPE. 마케팅 장표 「1. 개발현황(목표,실적)」의 정본이며 정본 지표 공#1(월 목표 달성율)·#2(누계)·#3(연)의 산출 base 다. 🔴달성율 컬럼은 두지 않는다 — SUM(실적)/SUM(목표) 로 재계산할 것(행 단위 비율의 평균은 항상 틀린다). 🔴달성율 분모·분자는 **HAS_POSITIVE_GOAL=TRUE**(=GOAL_CNT>0) 로 스코프해야 한다 — 목표 미편성분의 실적이 분자에 섞이면 조용히 과대해진다(P18·P63). ⚠️**HAS_GOAL_ROW(목표 행 존재)로 스코프하면 안 된다**: 원천이 부서×월×개발구분 조합을 전량 행 생성하고 미편성분을 0 으로 채워 목표 행의 과반이 0 이므로, 그 행들의 실적이 분모 없이 분자에 들어가 비율이 폭증한다. ⚠️_YTD·_YEAR 컬럼은 월에 대해 비가산 — 월을 가로질러 합산 금지. ⚠️일별 실적은 WIDE_MEMBER_EVENT(일 grain) 소관 — 월 목표를 일자에 반복하면 이중계상된다. ⚠️매체(브랜드2)별 목표는 원천에 없다(정본 마케팅 인벤토리 §1 「부서별 목표만 존재·매체별 목표 확인 불가」). 🔴 [O53] 종전 이름 = GOLD.WIDE_DEV_ACHIEVEMENT(뷰). 팩트를 재구성하는 객체이므로 WIDE_ 접두가 아니라 FACT_ 로 개명하고 테이블화했다 — SV_DEV_ACHIEVEMENT 의 base 다.';


-- ============================================================================
-- FACT 17: FACT_MEMBER_SPONSOR_BIZ (FMSB) — 회원×후원약정 팩트 [2026-08-21 신설]
--   목적 = "캠페인별/후원사업별 활동회원" 질의. FMM.CAMPAIGN_SK 는 회원grain 다중캠페인
--   (19.0%·최대690, O8 미결)이라 전건 센티넬(0)인데, 약정(SPNSR_BSNS_NO) grain 에서는
--   캠페인이 거의 1:1(다중 137건=0.01%·최대2, 실측)이라 이 grain 에서는 O8 이 사실상 무해하다.
--   grain = MEMBER_DK × SPNSR_BSNS_NO(2,170,572행, 실측). PK 는 SPNSR_BSNS_NO 단독이 아니다 —
--   28건이 서로 다른 두 회원(공동후원 쌍)에 공유된다(실측). (MEMBER_DK,SPNSR_BSNS_NO) 쌍은 전건 유일.
--   월 확장(B안) 대신 이 span grain(A안)을 채택 — B안 실측 105,428,370행(FMM 40,054,883의 2.6배)은
--   비용 대비 이점이 없다. as-of 활동판정은 소비 계층(SV)에서 START_MONTH_KEY~DSCNTC_MONTH_KEY 로 계산.
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ (
    MEMBER_DK         VARCHAR(10)     NOT NULL COMMENT '회원 (불변키). ※비강제 FK→DIM_MEMBER',
    SPNSR_NO          VARCHAR(9)      NOT NULL COMMENT '후원번호(Q15) — 한 회원이 여러 SPNSR_NO 를 가질 수 있고, 한 SPNSR_NO 가 여러 SPNSR_BSNS_NO 를 가질 수 있다(다대다, distinct 2,103,041 vs 총행 2,170,572, 실측)',
    SPNSR_BSNS_NO     NUMBER(19,0)    NOT NULL COMMENT '후원사업번호(회원별 약정 일련번호, Q15) — 🔴 분류축이 아니다(DIM_SPONSORSHIP 참조). 🔴 단독 유일키 아님 — 실측 28건이 공동후원 쌍(부부 등) 2개 회원에 공유된다',
    SPONSORSHIP_SK    NUMBER(38,0)    COMMENT '후원사업 (FK→DIM_SPONSORSHIP, SPNSR_BSNS_ID 경유). 0=미매핑',
    CAMPAIGN_SK       NUMBER(38,0)    COMMENT '대표캠페인 (FK→DIM_CAMPAIGN). 판정 규칙 = CRM_MEMBER_DEV 사건 중 ①신규(DVLP_DIV_CD=1) ②그 외, 그 안에서 최초일자·최소일련번호 1건. 실측: 신규사건 보유 1,687,546건 · 신규사건 부재 483,028건(22.3%)은 전체사건 최초사건으로 대체(동률 0, 100% 클린) · 사건 자체가 없는 6건은 0(미매핑)',
    IS_MULTI_CAMPAIGN BOOLEAN         COMMENT '참고용 투명성 플래그 — 이 SPNSR_BSNS_NO 의 전체 사건에서 distinct CMPGN_CD>1 인지(실측 137건=0.01%·최대2). 대표캠페인 채택 규칙과 별개로 다중이었다는 사실을 감추지 않는다',
    START_MONTH_KEY   NUMBER(6,0)     COMMENT '활동 개시 월키 YYYYMM(CRM_MEMBER_SPONSOR_SPAN 원값 그대로) — 후원(SPNSR_NO) 등록월의 근사',
    DSCNTC_MONTH_KEY  NUMBER(6,0)     COMMENT '중단 월키 YYYYMM. 🔴 NULL=미중단(현재까지 활동)이며 결측이 아니다',
    SPNSR_AMT         NUMBER(38,0)    COMMENT '후원사업 약정금액 원단위(CRM_MEMBER_SPONSOR_SPAN 원값)',
    DW_SOURCE_SYSTEM  VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
    -- [DEC-43 2026-08-25] 대표캠페인(CAMPAIGN_SK 판정에 쓰인 그 사건)의 캠페인 12속성 동결 승계.
    --   원천 = SILVER CRM_MEMBER_DEV(대표사건 판정 행 그대로) — DIM_CAMPAIGN 실시간 조인 없이
    --   대표 사건과 결정적으로 함께 딸려온다. 캠페인 마스터가 이후 정정돼도 이 약정의 값은 불변.
    ACQ_MBER_INFLOW_PATH_CD NUMBER(10,0) COMMENT '대표캠페인의 모집채널 코드(MM293) — 동결값. 라벨=ACQ_MBER_INFLOW_PATH_NM',
    ACQ_MBER_INFLOW_PATH_NM VARCHAR      COMMENT '대표캠페인의 모집채널명(MM293 라벨) — 동결값',
    ACQ_CMPGN_CTGR_CD       NUMBER(10,0) COMMENT '대표캠페인의 카테고리 코드(MM294) — 동결값. 라벨=ACQ_CMPGN_CTGR_NM',
    ACQ_CMPGN_CTGR_NM       VARCHAR      COMMENT '대표캠페인의 카테고리 라벨(MM294, 현업 ''주요캠페인'' 축) — 동결값',
    ACQ_CMPGN_TYPE1_BSN     NUMBER(10,0) COMMENT '대표캠페인 유형1 코드(MM295, 국내/통합/해외) — 동결값. 라벨=ACQ_CMPGN_TYPE1_NM',
    ACQ_CMPGN_TYPE1_NM      VARCHAR      COMMENT '대표캠페인 유형1명(MM295 라벨) — 동결값',
    ACQ_CMPGN_TYPE2_BSN     NUMBER(10,0) COMMENT '대표캠페인 유형2 코드(MM296, 굿즈/기타/사례/사업) — 동결값. 라벨=ACQ_CMPGN_TYPE2_NM',
    ACQ_CMPGN_TYPE2_NM      VARCHAR      COMMENT '대표캠페인 유형2명(MM296 라벨) — 동결값',
    ACQ_MKTG_CMPGN_CD       NUMBER(10,0) COMMENT '대표캠페인의 마케팅캠페인 코드(FK→TM_CM_MKTNG_CMPGN_MNG.MK_CMPGN_CD) — 동결값. 라벨=ACQ_MKTG_CMPGN_NM',
    ACQ_MKTG_CMPGN_NM       VARCHAR      COMMENT '대표캠페인의 마케팅 캠페인명(Q16 라벨) — 동결값',
    ACQ_CMMN_BRND           NUMBER(10,0) COMMENT '대표캠페인의 MM297 공통브랜드 코드 — 동결값. 라벨=ACQ_CMMN_BRND_NM',
    ACQ_CMMN_BRND_NM        VARCHAR      COMMENT '대표캠페인의 MM297 공통브랜드명 — 동결값',
    ACQ_MKTG_UTM            NUMBER(10,0) COMMENT '대표캠페인의 UTM 코드(TM_CM_MKTNG_UTM.MK_UTM) — 동결값. 라벨=ACQ_MKTG_UTM_NM',
    ACQ_MKTG_UTM_NM         VARCHAR      COMMENT '대표캠페인의 UTM 라벨(TM_CM_MKTNG_UTM.MK_UTM_NM) — 동결값',
    ACQ_SPNSR_DIV_CD        VARCHAR      COMMENT '대표캠페인의 후원구분 코드(CM035) — 동결값. 라벨=ACQ_SPNSR_DIV_NM',
    ACQ_SPNSR_DIV_NM        VARCHAR      COMMENT '대표캠페인의 후원구분명(CM035 라벨) — 동결값',
    ACQ_CPR_DIV_CD          VARCHAR      COMMENT '대표캠페인의 법인구분 코드(CM019) — 동결값. 라벨=ACQ_CPR_DIV_NM',
    ACQ_CPR_DIV_NM          VARCHAR      COMMENT '대표캠페인의 법인구분명(CM019 라벨) — 동결값',
    ACQ_BRAND               VARCHAR      COMMENT '대표캠페인의 브랜드명 — 동결값',
    ACQ_PARENT_CAMPAIGN_NAME VARCHAR     COMMENT '대표캠페인의 상위캠페인명(UPPER_CMPGN_CD 자기조인 라벨) — 동결값',
    ACQ_PROMO_METHOD_NAME   VARCHAR      COMMENT '대표캠페인의 홍보방법명(CM008 라벨) — 동결값'
) COMMENT = '회원×후원약정 팩트 (MEMBER_DK × SPNSR_BSNS_NO). "캠페인별/후원사업별 활동회원" 질의 전용 — 약정grain 에서는 캠페인이 거의 1:1 이라 FMM.CAMPAIGN_SK 를 막고 있는 O8(회원grain 다중귀속 미결)이 이 테이블에는 적용되지 않는다. as-of 활동판정은 START_MONTH_KEY~DSCNTC_MONTH_KEY 로 소비 계층에서 계산한다(FMM#51 과 동일 철학, 월 확장 없음). [DEC-43 2026-08-25] 대표캠페인의 캠페인 12속성 동결값 신설(CAMPAIGN_TYPE 등) — SV_MEMBER_SPONSOR_BIZ 의 DIM_CAMPAIGN 실시간 조인을 대체한다.';


-- ============================================================================
-- [관계 제약] 정보성 FK 선언 (NOT ENFORCED NORELY)
-- ----------------------------------------------------------------------------
--  목적   : ERD 자동생성 · BI 관계 인식 · 인수인계 문서화.
--  성격   : Snowflake 는 NOT NULL 외 제약을 강제하지 않음. 아래 FK 는 전부
--           정보성이며 NORELY(옵티마이저가 무결성 가정 안 함) — GOLD 데이터
--           검증 완료 후 RELY 승격 검토(그 전까지 조인제거 오답 위험 차단).
--  전제   : 참조 대상이 실제 PK 인 컬럼만 선언(Snowflake FK 대상 = PK/UNIQUE).
--           본 ALTER 는 전체 테이블 생성 이후 실행. 🔴 [2026-08-21] 종전 "27개"는 본 편집 이전부터
--           이미 stale 이었다(실측 CREATE TABLE 37개 + 이번 신설 FACT_MEMBER_SPONSOR_BIZ = 38개).
--           개수를 하드코딩하면 다시 stale 이 된다 — 정확한 개수는 항상 재라:
--           grep -c '^CREATE OR REPLACE TABLE GN_DW.GOLD' 06_DDL.sql
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
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ DROP CONSTRAINT FK_FMSB_DIM_SPONSORSHIP; EXCEPTION WHEN OTHER THEN NULL; END;
  BEGIN ALTER TABLE GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ DROP CONSTRAINT FK_FMSB_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;
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

-- FACT_BUDGET_YEARLY  [2026-08-20 O93]
ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY ADD CONSTRAINT FK_FBY_DIM_ORG
    FOREIGN KEY (ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY ADD CONSTRAINT FK_FBY_DIM_BUDGET_ITEM
    FOREIGN KEY (BUDGET_ITEM_SK) REFERENCES GN_DW.GOLD.DIM_BUDGET_ITEM (BUDGET_ITEM_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY ADD CONSTRAINT FK_FBY_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_BUDGET_YEARLY ADD CONSTRAINT FK_FBY_DIM_SPONSORSHIP
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

-- ----------------------------------------------------------------------------
-- [2026-08-06 O45] 조립 축 신설분 FK 8종
--   🔴 타입 정합 필수(P88): 참조 PK 와 **정확히 같은 타입**이어야 한다. 폭이 넓어도 실패한다.
--      DIM_DATE.DATE_SK = NUMBER(8,0) · 그 외 대리키 = NUMBER(38,0).
--      실제 실패 사례: `LAST_PAY_DATE_SK` 를 맨 NUMBER(=38,0)로 두어
--      "Primary key and foreign key data type does not match" 발생.
--   ⚠️ 라이브 환경 적용 시에는 `ADD CONSTRAINT` 만 실행한다(테이블 재생성 금지).
-- ----------------------------------------------------------------------------
-- FACT_MEMBER_FEE → 차원 4종
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_PAYMENT
    FOREIGN KEY (PAYMENT_SK) REFERENCES GN_DW.GOLD.DIM_PAYMENT (PAYMENT_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_PAY_DATE
    FOREIGN KEY (LAST_PAY_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_BILL_DATE
    FOREIGN KEY (LAST_BILL_DATE_SK) REFERENCES GN_DW.GOLD.DIM_DATE (DATE_SK) NOT ENFORCED NORELY;

-- FACT_MEMBER_COHORT 획득 귀속축 2종
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_ACQ_ORG
    FOREIGN KEY (ACQ_ORG_SK) REFERENCES GN_DW.GOLD.DIM_ORG (ORG_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_ACQ_SPONSORSHIP
    FOREIGN KEY (ACQ_SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;

-- 마케팅캠페인 conformed 축 2종 (광고 ↔ CRM 결합의 유일 경로)
ALTER TABLE GN_DW.GOLD.DIM_CAMPAIGN ADD CONSTRAINT FK_DIM_CAMPAIGN_MKTG
    FOREIGN KEY (MKTG_CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_MARKETING_CAMPAIGN (MKTG_CAMPAIGN_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAP_MKTG_CAMPAIGN
    FOREIGN KEY (MKTG_CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_MARKETING_CAMPAIGN (MKTG_CAMPAIGN_SK) NOT ENFORCED NORELY;

-- FACT_MEMBER_SPONSOR_BIZ → 차원 2종  [2026-08-21 신설]
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ ADD CONSTRAINT FK_FMSB_DIM_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ ADD CONSTRAINT FK_FMSB_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;

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


-- ############################################################################
-- [2026-08-06 O45] 보고서 섹션 조립 가능화 — 축 3종 + 팩트 1종
-- ----------------------------------------------------------------------------
-- 정본 이슈 = 20_issue/00_INDEX_이슈원장.md §O45 · 실행 스크립트 = 03_top-down_gold/O45_ASSEMBLY_AXES.sql
-- 사후 검증 = 03_top-down_gold/O45_VERIFY.sql (build 후 필수)
--
-- 🔴 아래 4개는 `CREATE OR REPLACE` 로 만들지 않는다 — FK·GRANT·COMMENT 소실(순서9 G-1/G-2).
--    신규 = CREATE TABLE IF NOT EXISTS · 기존 = ALTER TABLE ADD COLUMN(물리 위치 = 맨 끝).
--    ⚠️ [2026-08-06 갱신] 종전 이 줄은 *"실제 DDL 본문은 O45_ASSEMBLY_AXES.sql 이 정본"* 이라고
--    적혀 있었다 — 그 상태로 O45 스크립트를 아카이브하면 신규 테이블 2종·신규 컬럼 3종·FK 8종의
--    DDL 이 **정본에서 사라진다**(실측: 이 파일에 CREATE 문 0건이었다). 따라서 **전량 이 파일로
--    이관 완료**했고 이제 이 파일이 유일한 정본이다. 아래는 이관 내역 요약이다.
--
--  신규 GOLD.DIM_MARKETING_CAMPAIGN  (차원 17번째)
--      MKTG_CAMPAIGN_SK(PK) · MKTG_CAMPAIGN_BK · MKTG_CAMPAIGN_NAME · USE_YN
--      · DEV_CAMPAIGN_CNT(팬아웃 경고축) · 감사 4종
--      → AGENCY(광고) ↔ CRM(개발실적) 결합이 성립하는 유일한 grain. 실측 광고 도달 89.7%.
--
--  신규 GOLD.FACT_MEMBER_FEE  (팩트 14번째)
--      grain = MEMBER_DK × MONTH_KEY × SPONSORSHIP_SK × FEE_DIV_CD × PAYMENT_TYPE × PAYMENT_SK
--      measure = BILLED_AMT · PAID_FEE · PAID_FEE_BILLABLE · UNPAID_BILLED_AMT · BILLING_ROWS
--      🔴 FMM 에 컬럼을 붙이지 않은 이유: FMM grain = 회원×월 정확히 1행(40,054,883 = distinct
--         member-month)이고 후원사업을 붙이면 회원-월-후원사업 39,563,730 vs 회원-월 37,148,615
--         = 6.5% 증가로 grain 이 깨진다. **grain 이 다르면 팩트를 나눈다.**
--      🔴 measure 식은 FMM 과 동일하다(O40 정본) → 총계 일치가 검증 관문이다(GATE-D).
--         ⚠️ **이 서술은 2026-08-06 O45-C 해소로 비로소 참이 됐다** — 그전에는 불량 5행 취급이 갈려
--            `PAID_FEE` 만 어긋났는데도 「완전 동일」이라 단정하고 있었다. 단정하는 서술은 검증과 함께 쓴다.
--
--  변경 GOLD.FACT_MEMBER_COHORT  +2 컬럼
--      ACQ_ORG_SK · ACQ_SPONSORSHIP_SK  (물리 위치 = 맨 끝)
--      → 이 팩트가 뷰 GOLD.DIM_MEMBER_ACQUISITION 을 통해 **회원 귀속 차원**으로 소비된다.
--        FMM·FSE·FEP 가 MEMBER_DK 1:1 조인으로 캠페인·부서·후원사업을 분해한다(팬아웃 0 실측).
--      🔴 O8(다중귀속 규칙 미확정)을 임의로 푼 것이 아니라 **「획득 시점」 명시 규칙**을 쓴 것이다.
--
--  변경 GOLD.DIM_CAMPAIGN  +1 컬럼 = MKTG_CAMPAIGN_SK
--  변경 GOLD.FACT_AD_PERFORMANCE +1 컬럼 = MKTG_CAMPAIGN_SK
--
--  🔴 배선 교정(컬럼 추가 아님): GOLD.FACT_MEMBER_EVENT.SPONSORSHIP_SK
--      종전 `0 as SPONSORSHIP_SK` 하드코딩 → 실배선. **O8 문제가 아니라 배선 누락**이었다:
--      사건 grain 에서는 후원사업이 하나로 확정되므로 귀속 규칙이 필요 없고,
--      원천 SILVER.CRM_MEMBER_DEV.SPNSR_BSNS_ID 는 채움 100% · DIM_SPONSORSHIP 고아 0 이다.
--
--  신규 뷰(구조 소유주 = dbt 모델. 이 파일에서 만들지 않는다)
--      GOLD.DIM_MEMBER_ACQUISITION  — FACT_MEMBER_COHORT 위의 회원 귀속 차원 뷰
--      GOLD.WIDE_MEMBER_FEE         — 회비 분해 소비뷰
--
--  🔴 타입 규약(2026-08-06 실행 중 발견 → 교정, P88)
--      Snowflake FK 는 참조 PK 와 **타입이 정확히 일치**해야 한다. 폭이 넓기만 해도 실패한다:
--        ALTER TABLE GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_PAY_DATE ...
--          → "SQL compilation error: Primary key and foreign key data type does not match"
--        원인 = FMF.LAST_PAY_DATE_SK 를 맨 NUMBER(=NUMBER(38,0))로 선언했는데
--               DIM_DATE.DATE_SK 는 NUMBER(8,0) 이다.
--      따라서 신규 팩트/차원 작성 시 다음 4개는 **반드시 명시 폭**으로 쓴다:
--        *_DATE_SK   NUMBER(8,0)    (= DIM_DATE.DATE_SK)
--        MONTH_KEY   NUMBER(6,0)    (= DIM_DATE.MONTH_KEY · FMM·FBD·FTG-D/B 전부 동일)
--        *_SK        NUMBER(38,0)   (= 전 차원 대리키)
--        MEMBER_DK   VARCHAR(10)    (= DIM_MEMBER.MEMBER_DK · 전 팩트 동일)
--      🔴 맨 `NUMBER`·맨 `VARCHAR` 는 각각 NUMBER(38,0)·VARCHAR(16777216) 으로 굳는다.
--         컬럼 COMMENT 에 "VARCHAR(10) 규약"이라 써 두고 정작 선언은 맨 VARCHAR 였던 사례가
--         이번에 실제로 발생했다 — **주석이 아니라 선언이 물리 타입을 만든다.**
--
--  🔴 FMF 는 PK 를 선언하지 않는다: grain 7종 중 FEE_DIV_CD 가 기부금 행에서 원천 NULL 이므로
--      PK(=NOT NULL 의미) 선언은 사실과 어긋난다. 유일성은 dbt GROUP BY + GATE-D2 로 보증한다.
-- ############################################################################
