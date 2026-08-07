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
{{ config(
    materialized='view',
    tags=['gold_ready'],
    post_hook=[
      "COMMENT ON VIEW {{ this }} IS '회원 획득(가입) 귀속 차원 — 1행=1회원. base=FACT_MEMBER_COHORT(단일 정의 지점). 🔴모든 ACQ_* 는 **획득 시점** 값이며 현재 속성이 아니다(현재 연령·현주소는 BRONZE 에 축이 없어 산출 불가). 🔴「부서」·「후원사업」은 같은 라벨로 두 축이 존재한다 — 사건 부서=FACT_MEMBER_EVENT.ORG_SK · 납입 대상 후원사업=FACT_MEMBER_FEE.SPONSORSHIP_SK. 팩트와는 반드시 LEFT JOIN(개발 사건이 없는 회원이 사라진다).'",
      "ALTER VIEW {{ this }} ALTER COLUMN MEMBER_DK COMMENT '회원 불변키 — 팩트 조인키(VARCHAR(10) 규약)', COLUMN ACQ_CAMPAIGN_SK COMMENT '획득 캠페인 대리키 (FK→DIM_CAMPAIGN). 미매칭·부재는 0(Unknown 멤버)', COLUMN ACQ_DATE_SK COMMENT '획득일 (FK→DIM_DATE). 캘린더 범위밖·무효는 0', COLUMN ACQ_BASIS COMMENT '획득 판정 근거. NEW=개발구분 신규(MM015 코드1) 사건으로 판정 / FALLBACK=신규 사건이 없어 최초 개발 사건으로 대체. 🔴캠페인 비교 시 NEW 한정을 권한다', COLUMN ACQ_CAMPAIGN_NAME COMMENT '가입캠페인명. 🔴FACT_MEMBER_MONTHLY.CAMPAIGN_SK 는 다중귀속 규칙 미확정(O8)으로 센티넬이다 — 회원 단위 캠페인 분해는 이 축으로 한다', COLUMN ACQ_PARENT_CAMPAIGN_NAME COMMENT '획득 캠페인의 상위캠페인명', COLUMN ACQ_PROMO_METHOD_NAME COMMENT '획득 캠페인의 홍보방법명(CM008 라벨)', COLUMN ACQ_MARKETING_CAMPAIGN COMMENT '획득 캠페인의 마케팅캠페인명(광고↔CRM conformed 축). 광고비와 결합할 때 이 축을 쓴다 — 개발캠페인 grain 으로 내리면 광고비가 복제된다', COLUMN ACQ_BRAND COMMENT '획득 캠페인의 공통브랜드명', COLUMN ACQ_ORG_SK COMMENT '획득 시점 실적부서 대리키 (FK→DIM_ORG)', COLUMN ACQ_DEPARTMENT COMMENT '🔴**획득 시점 부서명**이다. 개발실적보고의 「부서」(=사건 부서, WIDE_MEMBER_EVENT.ORG_DEPARTMENT)와 다른 축이다', COLUMN ACQ_SPONSORSHIP_SK COMMENT '획득 시점 후원사업 대리키 (FK→DIM_SPONSORSHIP)', COLUMN ACQ_SPONSORSHIP_NAME COMMENT '🔴**획득 시점 후원사업명**(그 회원을 데려온 사업)이다. 납입 대상 후원사업(FACT_MEMBER_FEE.SPONSORSHIP_SK)과 다른 축 — 한 회원이 여러 후원사업에 낸다', COLUMN ACQ_AGE_CD COMMENT '획득 시점 연령대 코드(CM014). 🔴연속형 나이가 아니다 — 평균·구간 재계산 금지', COLUMN ACQ_AGE_BAND COMMENT '획득 시점 연령대명(CM014 라벨). 🔴현재 나이가 아니다. 이 축의 ''10대 미만'' 상위는 오류가 아니며 편지쓰기대회 계열 아동 모집 캠페인 때문이다 — 결측·기본값 오염으로 설명하지 말 것', COLUMN ACQ_AREA_CD COMMENT '획득 시점 지역 코드(CM018 + 라벨 없는 센티넬 0)', COLUMN ACQ_REGION COMMENT '획득 시점 지역명(CM018 약칭). 🔴현재 거주지가 아니다. 센티넬은 사전 라벨이 없어 NULL 이며 ''미상''으로 창작하지 않는다', COLUMN ACQ_SEX_CD COMMENT '획득 시점 성별 코드(CM013). ⚠️DIM_MEMBER 의 성별(CM017 계열·현재 스냅샷)과 코드체계가 다르다', COLUMN ACQ_GENDER COMMENT '획득 시점 성별명(CM013 라벨)', COLUMN ACQ_DVLP_DIV_CD COMMENT '획득 사건의 개발구분 코드(MM015)', COLUMN ACQ_SPNSR_AMT COMMENT '획득 사건의 후원금액(원, raw). 🔴건수로 환산하지 말 것 — 정본 (건) 은 금액÷10,000 규약이다(CONF-2)', COLUMN FIRST_STOP_DATE_SK COMMENT '최초 중단일 (FK→DIM_DATE). 🔴미중단 회원은 NULL 이며 0 이 아니다 — 0 은 「날짜 미상」이라는 다른 뜻이다', COLUMN FIRST_STOP_REASON_NM COMMENT '최초 중단사유명(MM005 라벨). 미중단은 NULL. ⚠️USE_YN 무필터 — 폐지코드도 실적재에 남아 있다', COLUMN TENURE_DAYS COMMENT '유지기간(일) = 최초 중단일 − 획득일. 🔴미중단 회원은 NULL(아직 종료되지 않은 관측이다 — 0 이나 경과일로 채우면 평균 유지기간이 조용히 틀린다)', COLUMN IS_12M_OBSERVABLE COMMENT '12개월 관측 가능 여부 = 획득일 + 12개월 ≤ 데이터 최종 사건일. 🔴12개월 이탈률의 **분모 자격**이다 — 최근 획득 회원을 포함시키면 최근 캠페인의 이탈률이 실제보다 낮게 보인다'"
    ]
) }}

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
from {{ ref('FACT_MEMBER_COHORT') }} c
left join {{ ref('DIM_CAMPAIGN') }}     cmp on cmp.CAMPAIGN_SK     = c.ACQ_CAMPAIGN_SK
left join {{ ref('DIM_ORG') }}          org on org.ORG_SK          = c.ACQ_ORG_SK
left join {{ ref('DIM_SPONSORSHIP') }}  spb on spb.SPONSORSHIP_SK  = c.ACQ_SPONSORSHIP_SK
