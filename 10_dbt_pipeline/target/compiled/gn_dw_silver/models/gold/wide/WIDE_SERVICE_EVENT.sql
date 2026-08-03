-- WIDE_SERVICE_EVENT: 서비스/발송 팩트(FSE) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.5)
-- Co-authored with CoCo


select
    f.DATE_SK, f.MEMBER_DK,
    f.SEND_MEMBERS, f.SUCCESS_MEMBERS, f.FAIL_MEMBERS, f.OPEN_MEMBERS,
    f.LETTER_PART_MEMBERS, f.LETTER_PART_CNT,
    f.GIFT_PART_MEMBERS, f.GIFT_PART_AMT,
    f.D5_LETTER_PART_MEMBERS, f.D5_LETTER_PART_CNT,
    f.D5_GIFT_PART_MEMBERS, f.D5_GIFT_PART_CNT,
    f.D5_INCREASE_PART_MEMBERS, f.D5_INCREASE_PART_CNT,
    f.D5_STOP_MEMBERS, f.D5_STOP_CNT,
    f.SERVICE_MEMBERS, f.SERVICE_CNT,
    f.SEND_TITLE, f.SEND_STATUS, f.SEND_STATUS2, f.SEND_TYPE,
    f.MAIL_RECEIVE_FLAG, f.MEMBER_STOP_FLAG,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.IS_HOLIDAY,
    -- [2026-08-03 O26] 회원 속성 노출 재구성 — 코드=BRONZE 원천명 · 라벨=분석 용어.
    --   종전은 코드만(`MEMBER_GENDER`=M/F/U 등) 노출해 현업이 WIDE 에서 코드만 보던 상태였다.
    m.SEX                 as SEX,                     -- CM013 코드 raw
    m.SEX_NM              as SEX_NM,                  -- CM013 원천 라벨(국내/외국인 축)
    m.GENDER_NAME         as MEMBER_GENDER_NAME,      -- CM017 분석 라벨 = 정본 공#130
    m.REGION              as MEMBER_REGION,
    m.AGE_BAND            as MEMBER_AGE_BAND,
    m.MBER_STAT_CD        as MBER_STAT_CD,            -- MM010 코드 raw
    m.MEMBER_STATUS_NAME  as MEMBER_STATUS_NAME,      -- MM010 분석 라벨(#132)
    m.MBER_DIV_CD         as MBER_DIV_CD,             -- MM018 코드 raw
    m.MEMBER_TYPE_NAME    as MEMBER_TYPE_NAME,        -- MM018 분석 라벨
    sv.SEND_TYPE_L        as SERVICE_SEND_TYPE_L,
    sv.SEND_TYPE_M        as SERVICE_SEND_TYPE_M,
    sv.SEND_TYPE_S        as SERVICE_SEND_TYPE_S,
    sv.SUBTYPE            as SERVICE_SUBTYPE,
    sv.CHANNEL            as SERVICE_CHANNEL,
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     as CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    c.PROMO_METHOD        as CAMPAIGN_PROMO_METHOD
from GN_DW.GOLD.FACT_SERVICE_EVENT f
left join GN_DW.GOLD.DIM_DATE d on f.DATE_SK = d.DATE_SK
left join (
    select MEMBER_DK, SEX, SEX_NM, GENDER_NAME, REGION, AGE_BAND, MBER_STAT_CD, MEMBER_STATUS_NAME, MBER_DIV_CD, MEMBER_TYPE_NAME
    from GN_DW.GOLD.DIM_MEMBER
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join GN_DW.GOLD.DIM_SERVICE  sv on f.SERVICE_SK  = sv.SERVICE_SK
left join GN_DW.GOLD.DIM_CAMPAIGN c  on f.CAMPAIGN_SK = c.CAMPAIGN_SK