-- WIDE_EVENT_PARTICIPATION: 행사 참여 팩트(FEP) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.8)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.


select
    f.DATE_SK, f.MEMBER_DK,
    -- [DEC-30] f.RECRUIT_CNT 제거 → e.RECRUIT_HEADCOUNT(행사 차원)으로 대체
    f.TOTAL_CNT, f.WAIT_CNT, f.CANCEL_CNT,
    f.CONFIRM_CNT, f.PARTICIPATE_CNT, f.ABSENT_CNT,
    f.PARTICIPANT_CNT, f.PARTICIPATION_TIMES,
    f.WAIT_TIMES, f.ABSENT_TIMES, f.CUM_APPLY_TIMES,
    f.REGULAR_DONATION,
    f.WIN_FLAG, f.SELF_PART_FLAG, f.PART_STATUS,
    f.PART_PATH, f.PART_CHANNEL, f.INCREASE_FLAG,
    -- [DEC-30] degen key 2종. 🔷유일 식별 = (PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ).
    --   ⚠️PART_EVENT_BK(팩트·고아 포함 전건) 와 EVENT_BK(차원 매칭·고아는 '(미매핑)') 는 다르다.
    f.EVENT_BK            as PART_EVENT_BK,
    f.PARTCPT_SEQ         as PARTCPT_SEQ,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.IS_HOLIDAY,
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
    m.MBER_DIV_CD         as MBER_DIV_CD,             -- MM018 코드 raw
    m.MEMBER_TYPE_NAME    as MEMBER_TYPE_NAME,        -- MM018 분석 라벨
    e.EVENT_BK            as EVENT_BK,
    e.EVENT_KIND          as EVENT_KIND,
    e.EVENT_CATEGORY      as EVENT_CATEGORY,
    e.EVENT_NAME          as EVENT_NAME,
    e.EVENT_START_DATE    as EVENT_START_DATE,
    e.EVENT_END_DATE      as EVENT_END_DATE,
    e.APPLY_CHANNEL       as EVENT_APPLY_CHANNEL,
    e.RECRUIT_HEADCOUNT   as EVENT_RECRUIT_HEADCOUNT,  -- [DEC-30] 행사 정원(행사 grain) — 참여행 반복 합산 금지
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    s.SPONSORSHIP_BK      as SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    as SPONSORSHIP_NAME
from GN_DW.GOLD.FACT_EVENT_PARTICIPATION f
left join GN_DW.GOLD.DIM_DATE d on f.DATE_SK = d.DATE_SK
left join (
    select MEMBER_DK, SEX, SEX_NM, GENDER_NAME, AREA_CD, REGION, AGE, AGE_BAND, MBER_STAT_CD, MEMBER_STATUS_NAME, MBER_DIV_CD, MEMBER_TYPE_NAME
    from GN_DW.GOLD.DIM_MEMBER
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join GN_DW.GOLD.DIM_EVENT       e on f.EVENT_SK       = e.EVENT_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK