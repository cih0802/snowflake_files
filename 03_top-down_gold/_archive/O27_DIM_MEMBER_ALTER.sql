-- ============================================================================
-- 🔴 [APPLIED 2026-08-05 · 아카이브 이관 · 재실행 금지] — O41 판정
--   §2·§3·§4 는 **정본 `03_top-down_gold/06_DDL.sql` 100~120 행에 접혔다**(O30 세션 동기화).
--   물리 실측(2026-08-05 재구축 후): `GOLD.DIM_MEMBER` **정확히 30컬럼** = ADD 4 반영
--   (`AREA_CD`·`AGE`·`PREV_MBER_STAT_CD`·`PREV_MEMBER_STATUS_NAME`) · DROP 3 소멸
--   (`NEW_EXISTING_FLAG`·`LAST_CAMPAIGN`·`CURRENT_SPONSORSHIP`) → 스크립트 없이 복원된다.
--
-- 🟢 §5 의 경고("정본 DDL 도 같은 세션에 고쳐라")는 **지켜졌다** — 이것이 O30 사고의 직접 원인이었고
--   이번 재구축에서는 소실이 재발하지 않았다(P57 실효성 실증).
--
-- 🟢 살아 있는 자산 = **§6 검증 9종**.
--   ⚠️ 기대값(7,925,716행·적중률 96.91% 등)은 **재구축 이전** 측정치다. BRONZE 재적재 후 값이
--      같다는 보장이 없으므로 어긋나면 원인 규명 전 인용 금지(PROC-3 c).
-- ============================================================================

-- O27/DEC-28 DIM_MEMBER 물리 스키마 변경 + COMMENT DoD — dbt build 전 1회 실행
-- Co-authored with CoCo
-- ============================================================================
-- 실행 역할 = GN_DW_ADMIN · 실행 순서 = 【본 스크립트】 → dbt build → §4 검증
--
-- 🔴 `CREATE OR REPLACE TABLE` 금지 — FK·GRANT 가 파괴된다(DEC-25 §15-D). ALTER 만 쓴다.
-- 🔴 본 스크립트를 먼저 실행하지 않으면 `dbt build` 가 실패한다:
--    DIM_MEMBER 는 `incremental + append + pre-hook TRUNCATE` 라 **구조를 dbt 가 만들지 않는다**.
--    모델이 출력하는 신규 4컬럼이 물리에 없으면 append 가 컬럼 부재로 실패한다(A1 선례, 문서50).
-- 🟢 dbt append 는 **이름 기반**임이 O25 에서 실측 확증됐다 → 컬럼 순서는 무관하다.
--
-- 근거 정본 = 문서30 **DEC-28 §18** · 진단 정본 = 문서10 **§14**
-- 변경 요약: ADD 4 (AREA_CD·AGE·PREV_MBER_STAT_CD·PREV_MEMBER_STATUS_NAME)
--            DROP 3 (NEW_EXISTING_FLAG·LAST_CAMPAIGN·CURRENT_SPONSORSHIP)
--            채움 4 (REGION·AGE_BAND·LAST_STOP_DATE·FIRST_SPONSORSHIP — 기존 컬럼, DDL 무변경)
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE DATABASE GN_DW;
USE SCHEMA GOLD;

-- ─────────────────────────────────────────────────────────────────────────────
-- §1. 사전 확인 — 현재 상태 스냅샷(실행 전 기록용)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'BEFORE' AS PHASE, COUNT(*) AS ROWS_,
       COUNT(DISTINCT MEMBER_DK) AS MEMBERS,
       COUNT_IF(IS_CURRENT) AS CUR_ROWS
FROM GN_DW.GOLD.DIM_MEMBER;   -- 기대: 7,925,716 / 1,763,065 / 1,763,065

SELECT COLUMN_NAME, DATA_TYPE
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='DIM_MEMBER'
  AND COLUMN_NAME IN ('AREA_CD','AGE','PREV_MBER_STAT_CD','PREV_MEMBER_STATUS_NAME',
                      'NEW_EXISTING_FLAG','LAST_CAMPAIGN','CURRENT_SPONSORSHIP')
ORDER BY COLUMN_NAME;         -- 기대: DROP 대상 3개만 조회됨

-- ─────────────────────────────────────────────────────────────────────────────
-- §2. ADD COLUMN 4건 — 코드 컬럼 2 + 상태전이 축 2
--     ⚠️ 타입은 SILVER 원천을 따른다(DEC-25 "코드 값 = 원천 raw 무변환").
--        `CRM_MEMBER_DEV.AREA_CD` = TEXT · `.AGE` = NUMBER · `STATUS_HIST.BF_STAT_CD` = TEXT
--     ⚠️ `AGE` 를 NUMBER 로 두는 것은 원천 충실이며 **연속형이라는 뜻이 아니다**(CM014 코드).
--        CM014 조인 시 `TO_VARCHAR(AGE) = CRM_CODE.DTL_CD_ID` 가 필요하다.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ADD COLUMN IF NOT EXISTS AREA_CD                 VARCHAR(10);
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ADD COLUMN IF NOT EXISTS AGE                     NUMBER(2,0);
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ADD COLUMN IF NOT EXISTS PREV_MBER_STAT_CD       VARCHAR(10);
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ADD COLUMN IF NOT EXISTS PREV_MEMBER_STATUS_NAME VARCHAR(100);

-- ─────────────────────────────────────────────────────────────────────────────
-- §3. DROP COLUMN 3건
--     판정 근거 = DEC-28 §18-D 판정순서 ②(대상 grain 에 함수종속하는가) 에서 탈락.
--     🔴 소비처 선행 제거 필수 — WIDE 뷰가 참조 중이면 DROP 이 실패하거나 다음 빌드가 깨진다.
--        본 세션에서 WIDE 4종 모델을 이미 수정했으므로, 순서는
--        ① 이 DROP → ② dbt build(WIDE 재생성) 가 아니라
--        ① 이 DROP → ② dbt build 로 진행해도 안전하다(뷰는 build 시 재생성되며 DROP 후 첫 조회 전까지
--        기존 뷰 정의가 살아 있으나 조회되지 않는다). ⚠️ DROP 직후 기존 WIDE 뷰를 조회하면
--        `invalid identifier` 가 난다 — build 를 지체 없이 이어서 실행할 것.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE GN_DW.GOLD.DIM_MEMBER DROP COLUMN IF EXISTS NEW_EXISTING_FLAG;    -- 시점귀속(#113) → 정소재지 FMM
ALTER TABLE GN_DW.GOLD.DIM_MEMBER DROP COLUMN IF EXISTS LAST_CAMPAIGN;        -- 대표규칙 = O8 현업 미결 · 소비처 0
ALTER TABLE GN_DW.GOLD.DIM_MEMBER DROP COLUMN IF EXISTS CURRENT_SPONSORSHIP;  -- 동시 다중후원 정상(14.2%·최대14)

-- ─────────────────────────────────────────────────────────────────────────────
-- §4. COMMENT DoD (P33 ①물리 ALTER COMMENT / ②소유산출물 / ③거짓 경고문 회수)
--     ② 뷰 COMMENT 는 WIDE 모델 `post_hook` 이 소유한다(본 세션 수정 완료) — 물리만 고치면
--        다음 빌드가 되돌린다. ③ 거짓이 된 문구는 아래에서 회수한다.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ALTER
  COLUMN AREA_CD COMMENT '지역 코드 raw — CM018(18종) + sentinel ''0''(라벨 없음). 라벨=REGION. [O27] 개발약정(CRM_MEMBER_DEV) **시점 스냅샷**이며 SCD2 버전별로 다를 수 있다. 판정근거: CM018 사전 18종 × 실적재 distinct 18종 = 18/18 일치 · 정본 공#131 지역정의가 약칭이라 CM011(정식명) 아님',
  COLUMN REGION COMMENT '지역 (#131) — CM018 약칭 라벨(서울/경기/인천/강원…). 코드=AREA_CD. [O27] 시점귀속(as-of): 그 버전 EFFECTIVE_FROM 이하 최근 개발약정의 값. 적중 96.91%(7,681,020/7,925,716). ⚠️ONCE(일시회원) 175,722행은 개발약정에 행이 없어 NULL — ''(해당없음)''이 아니다(개념은 있고 원천이 없다). sentinel AREA_CD=''0'' 도 라벨 NULL',
  COLUMN AGE COMMENT '연령대 코드 raw — CM014(1~12). 🔴**연속형 나이가 아니다**: 1=10대미만·2=10대·3=20대·4=30대·5=40대·6=50대·7=60대·8=70대·9=70대이상·10=단체·11=기업·12=기타. 라벨=AGE_BAND. 판정근거: CM014 12종 × 실적재 12종 = 12/12 일치 · 독립 교차검증 AGE=''10''(단체) 21,920행 전건 SEX=''6''(단체) · AGE=''11''(기업) 64,581행 전건 SEX=''7''(기업). ⚠️BRONZE TM_MM_FDRM_MBER_DVLP_AMT.AGE COMMENT ''연령''(NUMBER)은 오류다',
  COLUMN AGE_BAND COMMENT '연령대 — CM014 라벨. 코드=AGE. [O27] 시점귀속(as-of) · 적중 97.63%. 🔴구간을 우리가 만든 것이 아니라 **원천이 이미 구간화**해 제공한다(DEC-28 §18-B 로 DEC-27 §17-C ''구간 정의 없음→보류'' 판정을 정정). ⚠️생년월일(MBER_BIRTHDAY) 입고는 이 컬럼의 선행조건이 아니다 — 시점정확 연령에만 필요. ⚠️ONCE 는 NULL',
  COLUMN PREV_MBER_STAT_CD COMMENT '상태전이 **이전상태** 코드 raw — MM010. 현재상태=MBER_STAT_CD 와 짝지어 전이를 표현한다(이 SCD2 버전행이 곧 전이 사건이므로 fan-out 0). 원천=CRM_MEMBER_STATUS_HIST.BF_STAT_CD(채움 100%·7,501,761·12종 = MM010 12/12 일치). ⚠️이력 미보유행(FDRM 무이력·ONCE 전체)은 NULL — ''이전상태가 없다''가 아니라 ''이력이 없다''. ⚠️동일자 다중전이는 최종 전이로 축약된다(중간 단계 소실)',
  COLUMN PREV_MEMBER_STATUS_NAME COMMENT '이전상태 라벨 — MM010. 코드=PREV_MBER_STAT_CD. 하드코딩 아니라 CRM_CODE 조인(P31). 원천 라벨 BF_STAT_NM 도 MM010 과 100% 일치하나 사전 조인을 정본으로 쓴다. ⚠️개발구분(MM015)은 다른 축 — FACT_MEMBER_EVENT.DVLP_DIV_NM',
  COLUMN LAST_STOP_DATE COMMENT '최종 중단일 — 원천 CRM_MEMBER_DISCONTINUE.SPNSR_DSCNTC_DE. 🔴**그 버전 시점까지의 as-of max** 다(단순 max 아님). 단순 max 는 미래 정보를 과거 버전에 누설해 예측 피처(LTV·유지기간 신4·6~8)를 오염시킨다. 적중 19.73%(1,563,872/7,925,716) — 중단 이력이 없는 회원·중단 이전 버전은 NULL',
  COLUMN FIRST_SPONSORSHIP COMMENT '최초 후원사업 — CRM_MEMBER_DEV 최소 발생일(OCCRRNC_DE)의 SPNSR_BSNS_ID. ''최초''는 시점 불변이라 as-of 불요(SCD1). 적중 97.76%. ⚠️ONCE 는 개발약정 부재로 NULL. ⚠️**현재 후원사업**은 제공하지 않는다 — 동시 다중후원이 정상(14.2%·최대 14)이라 단일값이 성립하지 않아 CURRENT_SPONSORSHIP 을 DROP 했다(O13 계열)';

-- ─────────────────────────────────────────────────────────────────────────────
-- §5. 정본 DDL 동기화 안내 (실행 아님)
--     `03_top-down_gold/06_DDL.sql` 의 DIM_MEMBER 블록도 본 변경과 일치시켜야 한다.
--     ⚠️ 그 파일은 `CREATE OR REPLACE TABLE` 이므로 **재실행 금지**(FK·GRANT 파괴).
--        정본은 "다음 신규 환경 구축 시의 설계도" 역할이며, 물리 반영은 본 스크립트가 담당한다.
--        → 정본↔물리 drift 방지를 위해 둘을 같은 세션에 함께 수정한다(P33).
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- §6. dbt build 후 검증 (사용자 실행 · 기대값은 본 세션 사전 실측치)
-- ─────────────────────────────────────────────────────────────────────────────
-- (6-1) fan-out 0 · grain 유일 — 가장 중요
SELECT COUNT(*)                       AS ROWS_          -- 기대 7,925,716 (불변)
     , COUNT(DISTINCT MEMBER_SK)      AS SK_NDV         -- 기대 7,925,716 (= ROWS_)
     , COUNT(DISTINCT MEMBER_DK)      AS MEMBERS        -- 기대 1,763,065
     , COUNT_IF(IS_CURRENT)           AS CUR_ROWS       -- 기대 1,763,065 (= MEMBERS, 1인1행)
FROM GN_DW.GOLD.DIM_MEMBER;

-- (6-2) O27 신규·채움 컬럼 적중률
SELECT COUNT(AREA_CD)                 AS AREA_CD_NN     -- 기대 7,738,245 (97.63%)
     , COUNT(REGION)                  AS REGION_NN      -- 기대 7,681,020 (96.91%)
     , COUNT(AGE)                     AS AGE_NN         -- 기대 7,738,250
     , COUNT(AGE_BAND)                AS AGE_BAND_NN    -- 기대 7,738,250 (= AGE_NN, 라벨 100% 매칭)
     , COUNT(PREV_MBER_STAT_CD)       AS PREV_CD_NN     -- 기대 7,427,404
     , COUNT(PREV_MEMBER_STATUS_NAME) AS PREV_NM_NN     -- 기대 7,427,404 (= PREV_CD_NN)
     , COUNT(LAST_STOP_DATE)          AS STOP_NN        -- 기대 1,563,872 (19.73%)
     , COUNT(FIRST_SPONSORSHIP)       AS FIRSTBIZ_NN    -- 기대 7,748,482 (97.76%)
FROM GN_DW.GOLD.DIM_MEMBER;

-- (6-3) 라벨 도메인 = 사전과 일치하는가 (창작 0 확인)
SELECT AGE_BAND, COUNT(*) N FROM GN_DW.GOLD.DIM_MEMBER GROUP BY 1 ORDER BY N DESC;
-- 기대: CM014 12종 + NULL 만. '미상' 등 사전에 없는 라벨이 나오면 즉시 중단
SELECT REGION, COUNT(*) N FROM GN_DW.GOLD.DIM_MEMBER GROUP BY 1 ORDER BY N DESC;
-- 기대: CM018 18종 + NULL 만

-- (6-4) '미상' 창작 0 (O26/DEC-17-B 회귀 가드)
SELECT COUNT_IF(GENDER_NAME='미상')       AS MISANG_SEX    -- 기대 0
     , COUNT_IF(MEMBER_STATUS_NAME='미상') AS MISANG_STAT   -- 기대 0
     , COUNT_IF(AGE_BAND='미상')           AS MISANG_AGE    -- 기대 0
     , COUNT_IF(REGION='미상')             AS MISANG_REGION -- 기대 0
FROM GN_DW.GOLD.DIM_MEMBER;

-- (6-5) ONCE 는 지역·연령대·최초후원사업이 NULL 이어야 한다(원천 미보유)
SELECT MEMBER_TYPE, COUNT(*) ROWS_,
       COUNT(REGION) REGION_NN, COUNT(AGE_BAND) AGEBAND_NN, COUNT(FIRST_SPONSORSHIP) FIRSTBIZ_NN
FROM GN_DW.GOLD.DIM_MEMBER GROUP BY 1;
-- 기대: ONCE 175,722행 전부 0 / FDRM 은 각 99.85% 수준

-- (6-6) DROP 3컬럼 소멸 + 신규 4컬럼 존재 (INFORMATION_SCHEMA 스캔 = P33 완료판정)
SELECT COLUMN_NAME, DATA_TYPE, COMMENT
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='DIM_MEMBER'
  AND COLUMN_NAME IN ('AREA_CD','AGE','PREV_MBER_STAT_CD','PREV_MEMBER_STATUS_NAME',
                      'REGION','AGE_BAND','LAST_STOP_DATE','FIRST_SPONSORSHIP',
                      'NEW_EXISTING_FLAG','LAST_CAMPAIGN','CURRENT_SPONSORSHIP')
ORDER BY COLUMN_NAME;
-- 기대: 8행(신규4+채움4) · DROP 3건은 **조회되지 않아야** 한다

-- (6-7) WIDE 전파 확인 — 4뷰가 신규 컬럼을 노출하는가
SELECT TABLE_NAME, COLUMN_NAME
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME LIKE 'WIDE_%'
  AND COLUMN_NAME IN ('MEMBER_AREA_CD','MEMBER_AGE_CD','PREV_MBER_STAT_CD',
                      'PREV_MEMBER_STATUS_NAME','MEMBER_LAST_STOP_DATE','MEMBER_NEW_EXISTING',
                      'MEMBER_CURRENT_SPONSORSHIP')
ORDER BY TABLE_NAME, COLUMN_NAME;
-- 기대: MEMBER_AREA_CD·MEMBER_AGE_CD = 4뷰 / PREV_* = WIDE_MEMBER_MONTHLY·WIDE_MEMBER_EVENT 2뷰
--       MEMBER_LAST_STOP_DATE = WIDE_MEMBER_MONTHLY / **MEMBER_NEW_EXISTING·MEMBER_CURRENT_SPONSORSHIP 은 0행**

-- (6-8) 낡은 COMMENT 잔존 스캔 (P33 — 거짓이 된 문구 회수 확인)
SELECT TABLE_NAME, COLUMN_NAME, LEFT(COMMENT,120) AS C
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='GOLD'
  AND (COMMENT ILIKE '%개발·증감%대기%' OR COMMENT ILIKE '%AREA_CD 대기%' OR COMMENT ILIKE '%AGE 대기%'
       OR COMMENT ILIKE '%CURRENT_SPONSORSHIP%' OR COMMENT ILIKE '%NEW_EXISTING_FLAG — 신규기존%')
ORDER BY TABLE_NAME, COLUMN_NAME;
-- 기대: 0행. FMM.NEW_EXISTING_FLAG(팩트 자체 컬럼)는 유지 대상이므로 위 패턴에 걸리지 않아야 한다
