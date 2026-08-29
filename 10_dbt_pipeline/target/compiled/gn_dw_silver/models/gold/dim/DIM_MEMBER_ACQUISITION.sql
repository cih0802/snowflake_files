-- DIM_MEMBER_ACQUISITION: 회원 획득 귀속 차원 (1행=1회원) — `FACT_MEMBER_COHORT` 파생 테이블 [O53 뷰→테이블]
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-08-06 O45] 신설 — O8(다중후원 귀속 규칙 미확정)의 우회로
-- ----------------------------------------------------------------------------
-- 🔴 문제: `FACT_MEMBER_MONTHLY` 의 `CAMPAIGN_SK`·`SPONSORSHIP_SK` 는 **전건 센티넬**이다.
--    원천에 캠페인이 없어서가 아니다 — 회원-월 grain 에서 다중캠페인 후원(7.98% · 단일
--    회원-월 최대 60개)을 어디에 귀속시킬지 규칙이 없어서 0 으로 둔 것이다.
--    그 결과 보고서필드 **41필드 · 11섹션**이 「브랜드·상위캠페인·캠페인명·홍보방법·후원사업·부서」를
--    분해할 수 없었다(O44 실측).
--
-- 🟢 해법: **임의 귀속을 하지 말고 「획득 시점」이라는 명시된 규칙**을 쓴다.
--    `FACT_MEMBER_COHORT` 는 이미 회원 1행이고 획득 사건의 캠페인·연령·지역·성별을 갖고 있다.
--    거기에 **획득 부서·획득 후원사업 2축만** 더하면 회원 귀속 차원이 완성된다.
--
-- 🔴 왜 테이블이 아니라 뷰인가: 같은 사실을 두 곳에 저장하면 반드시 어긋난다(O43 P85 교훈).
--    FMC 가 단일 정의 지점이고 이 뷰는 **차원으로서의 의미만 부여**한다(저장 중복 0).
--    SV 에서는 이 뷰를 dimension 으로 선언해 팩트-팩트 조인처럼 보이지 않게 한다.
--
-- ── 조인 안전성 실측(2026-08-06) — 팬아웃 0 ────────────────────────────────────
--   `FACT_MEMBER_COHORT` 1,585,949행 = 1,585,949 고유회원 → **1행/회원 확인**
--   ⋈ `FACT_MEMBER_MONTHLY`      40,054,883 → 39,409,747  (미매칭 1.61%)
--   ⋈ `FACT_SERVICE_EVENT`       38,470,780 → 38,339,810  (99.66%)
--   ⋈ `FACT_EVENT_PARTICIPATION`  1,134,126 →  1,119,559  (98.70%)
--   ⇒ 반드시 **LEFT JOIN** 할 것. INNER 로 걸면 개발 사건이 없는 회원(일시회원 등)이 사라진다.
--
-- 🔴 네이밍 규약 — O34 교훈(`_AT_PLEDGE` vs `_AT_EVENT`)의 재적용:
--    「부서」라는 같은 라벨이 보고서마다 다른 축을 뜻한다.
--      · **개발실적보고**의 부서 = **사건 부서** → `FACT_MEMBER_EVENT.ORG_SK` 를 쓴다
--      · **연간분석(회비)**의 부서 = **획득 부서** → 이 차원의 `ACQ_ORG_*` 를 쓴다
--    두 값은 다르다. 이름으로 구분되지 않으면 소비 측이 조용히 틀린다.
-- ============================================================================
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.
-- 🔴🔴 [2026-08-10 O53] **뷰 → 테이블 전환.**
--   ① 컬럼 COMMENT 정본이 `03_top-down_gold/06_DDL.sql` 인라인 COMMENT 로 이동했다(사용자 결정).
--      schema.yml `columns[]` 는 제거 — 같은 사실을 두 곳에 두면 갈라진다(P85).
--   ② `incremental` + `append` + `pre_hook TRUNCATE` — merge 금지(완전 재산출 차원에서 grain 이동 시
--      구 행 잔존 · 문서50 §300 R1 · P131). base 인 FACT_MEMBER_COHORT 가 회원 집합을 매 build 재산출한다.
--   ③ 감사컬럼 4종을 신설했다(GOLD 35테이블 전수 관례 · 뷰 시절에는 없었다).
--   🔴 SELECT 컬럼 변경 시 06_DDL 블록을 동시에 재생성할 것(`scripts/gen_o53_gold_ddl.py`).


select
    c.MEMBER_DK                                     as MEMBER_DK,          -- 자연키(= 팩트 조인키)
    -- ── 획득 귀속 축 ─────────────────────────────────────────────────────────
    c.ACQ_CAMPAIGN_SK                               as ACQ_CAMPAIGN_SK,
    c.ACQ_ORG_SK                                    as ACQ_ORG_SK,
    c.ACQ_SPONSORSHIP_SK                            as ACQ_SPONSORSHIP_SK,
    c.ACQ_DATE_SK                                   as ACQ_DATE_SK,
    c.ACQ_BASIS                                     as ACQ_BASIS,          -- NEW=신규사건 / FALLBACK=최초개발사건
    c.ACQ_DVLP_DIV_CD                               as ACQ_DVLP_DIV_CD,
    -- ── 획득 시점 회원 속성 (현재 값이 아니다 — O34) ──────────────────────────
    c.ACQ_AGE_CD                                    as ACQ_AGE_CD,
    c.ACQ_AGE_BAND                                  as ACQ_AGE_BAND,
    c.ACQ_AREA_CD                                   as ACQ_AREA_CD,
    c.ACQ_REGION                                    as ACQ_REGION,
    c.ACQ_SEX_CD                                    as ACQ_SEX_CD,
    c.ACQ_GENDER                                    as ACQ_GENDER,
    c.ACQ_SPNSR_AMT                                 as ACQ_SPNSR_AMT,
    -- ── 라벨(차원 단독 조회로도 뜻이 통하게 — DEC-10 전제) ────────────────────
    -- [DEC-43] `DIM_CAMPAIGN` 실시간 조인(cmp.*) → `FACT_MEMBER_COHORT.ACQ_*` 동결값으로 전환.
    --   캠페인 마스터가 이후 정정돼도 과거 획득 회원의 값은 바뀌지 않는다(O99 설계부채 해소).
    c.ACQ_BRAND                                     as ACQ_BRAND,
    cmp.CAMPAIGN_NAME                               as ACQ_CAMPAIGN_NAME,
    c.ACQ_PARENT_CAMPAIGN_NAME                      as ACQ_PARENT_CAMPAIGN_NAME,
    c.ACQ_PROMO_METHOD_NAME                         as ACQ_PROMO_METHOD_NAME,
    c.ACQ_MKTG_CMPGN_NM                             as ACQ_MARKETING_CAMPAIGN,
    org.DEPARTMENT                                  as ACQ_DEPARTMENT,
    spb.SPONSORSHIP_NAME                            as ACQ_SPONSORSHIP_NAME,
    -- [DEC-43] 잔여 8속성(9속성 중 나머지 5 + 후원/법인구분 2 + UTM 1) 신규 노출.
    c.ACQ_MBER_INFLOW_PATH_NM                       as ACQ_INFLOW_PATH,
    c.ACQ_CMPGN_CTGR_NM                             as ACQ_CAMPAIGN_TYPE,
    c.ACQ_CMPGN_TYPE1_NM                            as ACQ_DOMESTIC_OVERSEAS,
    c.ACQ_CMPGN_TYPE2_NM                            as ACQ_BIZ_CASE_TYPE,
    c.ACQ_CMMN_BRND_NM                              as ACQ_CMMN_BRND_NM,
    c.ACQ_MKTG_UTM_NM                               as ACQ_MKTG_UTM_NM,
    c.ACQ_SPNSR_DIV_NM                              as ACQ_SPNSR_DIV_NM,
    c.ACQ_CPR_DIV_NM                                as ACQ_CPR_DIV_NM,
    -- ── 코호트 결과 measure (중단률·유지기간은 이 차원이 아니라 FMC 에서 집계) ──
    c.FIRST_STOP_DATE_SK                            as FIRST_STOP_DATE_SK,
    c.FIRST_STOP_REASON_NM                          as FIRST_STOP_REASON_NM,
    c.TENURE_DAYS                                   as TENURE_DAYS,
    c.IS_12M_OBSERVABLE                             as IS_12M_OBSERVABLE,
    -- [O53] 감사컬럼 — GOLD 테이블 전수 관례. 원천계통은 base(FMC)와 동일한 CRM.
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '22ac85e6-6bb3-416e-b393-feaee28af165'                    AS DW_BATCH_ID
from GN_DW.GOLD.FACT_MEMBER_COHORT c
left join GN_DW.GOLD.DIM_CAMPAIGN     cmp on cmp.CAMPAIGN_SK     = c.ACQ_CAMPAIGN_SK
left join GN_DW.GOLD.DIM_ORG          org on org.ORG_SK          = c.ACQ_ORG_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP  spb on spb.SPONSORSHIP_SK  = c.ACQ_SPONSORSHIP_SK