-- WIDE_MEMBER_EVENT: 회원 이벤트 팩트(FME) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.2)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.
{{ config(
    materialized='gn_view_commented'
) }}

select
    f.DATE_SK, f.MEMBER_DK, f.EVENT_TYPE,
    -- [2026-08-03 O24] 개발구분 축 노출. 컬럼명은 BRONZE 원천명 그대로(현업 혼동 방지).
    --   ⚠️ DVLP_DIV_NM='후원중단' 과 EVENT_TYPE='STOP' 은 동일 사건 중복 → 합산 금지.
    f.DVLP_DIV_CD, f.DVLP_DIV_NM, f.SPNSR_AMT,
    f.DEV_CNT, f.DEV_MEMBERS,
    f.STOP_CNT, f.STOP_MEMBERS,
    f.UNPAID_STOP_CNT, f.UNPAID_STOP_MEMBERS,
    f.JOIN_DATE, f.STOP_DATE, f.STOP_REASON, f.STOP_CHANNEL,
    -- [2026-08-03 O25] 중단사유·중단경로 라벨 노출. 종전엔 raw 코드(1/14/16 · 1/2/3)만 있어
    --   현업이 WIDE 를 조회하면 숫자만 보였다. 계보 계약(04_컬럼계보매핑 §4)이 STOP_REASON 을
    --   "사유코드→라벨"로 명시한 것과 실적재가 어긋난 상태를 해소한다(정본 공#162).
    f.STOP_REASON_NM, f.STOP_CHANNEL_NM,
    f.NEW_EXISTING_FLAG,
    -- [2026-08-04 O35] 사건시점 연령대·지역. 아래 MEMBER_AGE_* / MEMBER_REGION(=DIM_MEMBER 현재버전
    --   경유 '최근 약정' 스냅샷)과 **다른 축**이며 값이 다를 수 있다. 이 축이 사건 당시 정확값이다.
    --   같은 뷰 안에 캠페인 축이 있어 연령대 × 캠페인 교차가 성립한다. 중단(STOP)행은 원천 부재로 NULL.
    f.AGE_AT_EVENT, f.AGE_BAND_AT_EVENT, f.AREA_CD_AT_EVENT, f.REGION_AT_EVENT,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.QUARTER, d.IS_HOLIDAY,
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
    m.JOIN_PATH_CD        as JOIN_PATH_CD,            -- MM014 코드 raw
    m.ENROLL_PATH_NAME    as MEMBER_ENROLL_PATH_NAME, -- MM014 분석 라벨
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     as CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    c.PROMO_METHOD        as CAMPAIGN_PROMO_METHOD,
    -- [2026-07-30 D2] 캠페인 분석 2축 노출. DIM_CAMPAIGN 컬럼명↔업무용어 매핑에 주의:
    --   CAMPAIGN_TYPE(MM294 CMPGN_CTGR_NM) = 캠페인'카테고리'  → CAMPAIGN_CATEGORY 로 노출
    --   INFLOW_PATH(MM293 MBER_INFLOW_PATH_NM) = 현업 '주요캠페인' → CAMPAIGN_INFLOW_PATH 로 노출
    c.CAMPAIGN_TYPE       as CAMPAIGN_CATEGORY,
    c.INFLOW_PATH         as CAMPAIGN_INFLOW_PATH,
    s.SPONSORSHIP_BK      as SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    as SPONSORSHIP_NAME,
    o.CORP                as ORG_CORP,
    o.DIVISION            as ORG_DIVISION,
    o.DEPARTMENT          as ORG_DEPARTMENT,
    o.TEAM                as ORG_TEAM,
    r.REASON_CODE         as REASON_CODE,
    r.REASON_NAME         as REASON_NAME,
    r.REASON_TYPE         as REASON_TYPE
from {{ ref('FACT_MEMBER_EVENT') }} f
left join {{ ref('DIM_DATE') }} d on f.DATE_SK = d.DATE_SK
left join (
    select MEMBER_DK, SEX, SEX_NM, GENDER_NAME, AREA_CD, REGION, AGE, AGE_BAND, MBER_STAT_CD, MEMBER_STATUS_NAME, PREV_MBER_STAT_CD, PREV_MEMBER_STATUS_NAME, MBER_DIV_CD, MEMBER_TYPE_NAME, JOIN_PATH_CD, ENROLL_PATH_NAME
    from {{ ref('DIM_MEMBER') }}
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join {{ ref('DIM_CAMPAIGN') }}    c on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join {{ ref('DIM_SPONSORSHIP') }} s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
left join {{ ref('DIM_ORG') }}         o on f.ORG_SK         = o.ORG_SK
left join {{ ref('DIM_REASON') }}      r on f.REASON_SK      = r.REASON_SK
