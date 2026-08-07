
  create or replace   view GN_DW.GOLD.DIM_MEMBER_ACQUISITION
  
   as (
    -- DIM_MEMBER_ACQUISITION: 회원 획득 귀속 차원 (1행=1회원) — `FACT_MEMBER_COHORT` 위의 뷰
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
    cmp.BRAND                                       as ACQ_BRAND,
    cmp.CAMPAIGN_NAME                               as ACQ_CAMPAIGN_NAME,
    cmp.PARENT_CAMPAIGN_NAME                        as ACQ_PARENT_CAMPAIGN_NAME,
    cmp.PROMO_METHOD_NAME                           as ACQ_PROMO_METHOD_NAME,
    cmp.MARKETING_CAMPAIGN                          as ACQ_MARKETING_CAMPAIGN,
    org.DEPARTMENT                                  as ACQ_DEPARTMENT,
    spb.SPONSORSHIP_NAME                            as ACQ_SPONSORSHIP_NAME,
    -- ── 코호트 결과 measure (중단률·유지기간은 이 차원이 아니라 FMC 에서 집계) ──
    c.FIRST_STOP_DATE_SK                            as FIRST_STOP_DATE_SK,
    c.FIRST_STOP_REASON_NM                          as FIRST_STOP_REASON_NM,
    c.TENURE_DAYS                                   as TENURE_DAYS,
    c.IS_12M_OBSERVABLE                             as IS_12M_OBSERVABLE
from GN_DW.GOLD.FACT_MEMBER_COHORT c
left join GN_DW.GOLD.DIM_CAMPAIGN     cmp on cmp.CAMPAIGN_SK     = c.ACQ_CAMPAIGN_SK
left join GN_DW.GOLD.DIM_ORG          org on org.ORG_SK          = c.ACQ_ORG_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP  spb on spb.SPONSORSHIP_SK  = c.ACQ_SPONSORSHIP_SK
  );

