-- WIDE_MEMBER_MONTHLY: 회원 월 팩트(FMM) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.1)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100)   as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)      as CAL_MONTH,
    f.MEMBER_DK,
    f.DEV_CNT, f.DEV_MEMBERS,
    f.STOP_CNT, f.UNPAID_CNT,
    f.ACTIVE_CNT, f.ACTIVE_MEMBERS,
    f.ACTIVE_CUM_CNT, f.ACTIVE_CUM_MEMBERS,
    f.INCREASE_CNT, f.INCREASE_MEMBERS,
    f.DECREASE_CNT, f.CHURN_CNT,
    f.YEAR_START_ACTIVE_CNT, f.YEAR_END_ACTIVE_CNT,
    f.MONTH_END_ACTIVE_CNT, f.PREV_MONTH_END_ACTIVE_CNT,
    f.CAMPAIGN_UNPAID_CNT, f.STATUS_UNPAID_CNT,
    f.REGULAR_FEE, f.REGULAR_ONETIME_FEE, f.ONETIME_ONETIME_FEE,
    f.PAID_FEE, f.BILLED_AMT,
    f.INBOUND_CALL_CNT, f.TS_CALL_CNT,
    f.DEV_TYPE, f.NEW_FLAG, f.INCREASE_FLAG, f.REDONATE_FLAG,
    f.JOIN_DATE, f.STOP_DATE,
    f.AMOUNT_BAND1, f.AMOUNT_BAND2, f.PERIOD_BAND1, f.PERIOD_BAND2,
    f.SPONSOR_MONTHS, f.SPONSOR_YEARS, f.PAID_MONTHS,
    f.NEW_EXISTING_FLAG, f.UNPAID_FLAG_BOM, f.UNPAID_FLAG_EOM,
    f.DW_SOURCE_SYSTEM,
    -- [2026-08-03 O26] 회원 속성 노출 재구성 — 코드=BRONZE 원천명 · 라벨=분석 용어.
    --   종전은 코드만(`MEMBER_GENDER`=M/F/U 등) 노출해 현업이 WIDE 에서 코드만 보던 상태였다.
    m.SEX                 as SEX,                     -- CM013 코드 raw
    m.SEX_NM              as SEX_NM,                  -- CM013 원천 라벨(국내/외국인 축)
    m.GENDER_NAME         as MEMBER_GENDER_NAME,      -- CM017 분석 라벨 = 정본 공#130
    m.AREA_CD             as MEMBER_AREA_CD,          -- [O27] CM018 코드 raw (라벨=MEMBER_REGION)
    m.REGION              as MEMBER_REGION,
    m.AGE                 as MEMBER_AGE_CD,           -- [O27] CM014 코드 raw. ⚠️연속형 나이 아님
    m.AGE_BAND            as MEMBER_AGE_BAND,
    m.MBER_STAT_CD        as MBER_STAT_CD,            -- MM010 코드 raw
    m.MEMBER_STATUS_NAME  as MEMBER_STATUS_NAME,      -- MM010 분석 라벨(#132)
    m.PREV_MBER_STAT_CD   as PREV_MBER_STAT_CD,       -- [O27] 상태전이 이전상태 코드(MM010)
    m.PREV_MEMBER_STATUS_NAME as PREV_MEMBER_STATUS_NAME,  -- [O27] 이전상태 라벨(MM010)
    m.MBER_DIV_CD         as MBER_DIV_CD,             -- MM018 코드 raw
    m.MEMBER_TYPE_NAME    as MEMBER_TYPE_NAME,        -- MM018 분석 라벨
    m.FIRST_JOIN_DATE     as MEMBER_FIRST_JOIN_DATE,
    m.FIRST_CAMPAIGN      as MEMBER_FIRST_CAMPAIGN,
    m.JOIN_PATH_CD        as JOIN_PATH_CD,            -- MM014 코드 raw
    m.ENROLL_PATH_NAME    as MEMBER_ENROLL_PATH_NAME, -- MM014 분석 라벨
    m.FIRST_SPONSORSHIP   as MEMBER_FIRST_SPONSORSHIP,
    m.LAST_STOP_DATE      as MEMBER_LAST_STOP_DATE,   -- [O27] as-of 최종중단일(그 시점까지)
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     as CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    c.PROMO_METHOD        as CAMPAIGN_PROMO_METHOD,
    c.CAMPAIGN_TYPE       as CAMPAIGN_TYPE,
    s.SPONSORSHIP_BK      as SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    as SPONSORSHIP_NAME,
    s.SPONSORSHIP_ABBR    as SPONSORSHIP_ABBR,
    p.PAYMENT_METHOD      as PAYMENT_METHOD,
    p.SETTLE_METHOD       as PAYMENT_SETTLE_METHOD,
    p.FEE_TYPE            as PAYMENT_FEE_TYPE,
    r.REASON_CODE         as REASON_CODE,
    r.REASON_NAME         as REASON_NAME,
    r.REASON_TYPE         as REASON_TYPE
from GN_DW.GOLD.FACT_MEMBER_MONTHLY f
left join (
    select MEMBER_DK, SEX, SEX_NM, GENDER_NAME, AREA_CD, REGION, AGE, AGE_BAND, MBER_STAT_CD, MEMBER_STATUS_NAME, PREV_MBER_STAT_CD, PREV_MEMBER_STATUS_NAME, MBER_DIV_CD, MEMBER_TYPE_NAME, JOIN_PATH_CD, ENROLL_PATH_NAME,
           FIRST_JOIN_DATE, FIRST_CAMPAIGN, FIRST_SPONSORSHIP, LAST_STOP_DATE
    from GN_DW.GOLD.DIM_MEMBER
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join GN_DW.GOLD.DIM_CAMPAIGN     c on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP  s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
left join GN_DW.GOLD.DIM_PAYMENT      p on f.PAYMENT_SK     = p.PAYMENT_SK
left join GN_DW.GOLD.DIM_REASON       r on f.REASON_SK      = r.REASON_SK