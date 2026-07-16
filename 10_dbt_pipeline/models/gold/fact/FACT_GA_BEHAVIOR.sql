-- FACT_GA_BEHAVIOR: GA 행동 팩트 (GA4_EVENT + GA DIM 조인, 일 grain)
-- Co-authored with CoCo
-- grain: DATE_SK×IDENTITY_SK×GA_EVENT_SK×GA_SOURCE_SK×DEVICE_SK×CAMPAIGN_SK×PAGE_PATH
-- IDENTITY_SK = IDENTITY_MEMBER_XREF(pseudo→회원) → DIM_MEMBER_IDENTITY 매칭분, 미매칭=0(센티넬). CAMPAIGN_SK=NULL(DIM_CAMPAIGN GA UTM↔CRM cross-source).
-- ⚠️ [G-5 재확인] IDENTITY 결선은 GA4 1일 샤드 기반(회원 커버리지 ~4.2%). 전기간 입고 시 재실행·재검증 필요(문서50 G-5 게이트).
-- ⚠️ 비/준가산 지표(AVG_SESSION_DURATION·BOUNCE_RATE)는 grain 값 — 상위 재합산 금지(06_DDL §6)
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.
{{ config(
    tags=['gold_ready']
) }}

with e as (
    select * from {{ ref('GA4_EVENT') }}
),
-- pseudo→회원 매칭(1 pseudo 1행 = XREF grain). IDENTITY_SK 해소용, fan-out 없음.
xref as (
    select USER_PSEUDO_ID, MEMBER_DK
    from {{ ref('IDENTITY_MEMBER_XREF') }}
    where MEMBER_DK is not null
    qualify row_number() over (partition by USER_PSEUDO_ID order by MEMBER_DK) = 1
),

joined as (
    select
        COALESCE({{ date_sk('e.EVENT_DT') }}, 0)                            as DATE_SK,        -- 범위밖/NULL → 0 (순서9)
        COALESCE(dmi.IDENTITY_SK, 0)                                        as IDENTITY_SK,   -- 매칭 회원 SK / 미매칭=0(센티넬)
        COALESCE(gev.GA_EVENT_SK, 0)                                        as GA_EVENT_SK,
        COALESCE(gs.GA_SOURCE_SK, 0)                                        as GA_SOURCE_SK,
        COALESCE(dv.DEVICE_SK, 0)                                           as DEVICE_SK,
        0                                                                   as CAMPAIGN_SK,   -- 센티넬(미매핑) — DIM_CAMPAIGN 적재 후 해소
        COALESCE(SPLIT_PART(e.PAGE_LOCATION, '?', 1), '(none)')              as PAGE_PATH,
        e.PAGE_LOCATION                                                      as PAGE_LOCATION,
        e.USER_PSEUDO_ID,
        e.GA_SESSION_ID,
        e.EVENT_NAME,
        e.IS_ACTIVE_USER,
        e.SESSION_ENGAGED,
        e.ENGAGEMENT_TIME_MSEC,
        e.PERCENT_SCROLLED
    from e
    left join {{ ref('DIM_GA_EVENT') }}  gev
        on  EQUAL_NULL(gev.EVENT_CATEGORY, e.EVENT_CATEGORY)
        and EQUAL_NULL(gev.EVENT_LABEL,    e.EVENT_LABEL)
        and EQUAL_NULL(gev.EVENT_ACTION,   e.EVENT_ACTION)
    left join {{ ref('DIM_GA_SOURCE') }} gs
        on  EQUAL_NULL(gs.UTM_SOURCE, e.UTM_SOURCE)
        and EQUAL_NULL(gs.UTM_MEDIUM, e.UTM_MEDIUM)
    left join {{ ref('DIM_DEVICE') }}    dv
        on  EQUAL_NULL(dv.DEVICE_TYPE, e.DEVICE_TYPE)
    left join xref x
        on  x.USER_PSEUDO_ID = e.USER_PSEUDO_ID
    left join {{ ref('DIM_MEMBER_IDENTITY') }} dmi
        on  dmi.MEMBER_DK = x.MEMBER_DK
)

select
    DATE_SK,
    IDENTITY_SK,
    GA_EVENT_SK,
    GA_SOURCE_SK,
    DEVICE_SK,
    CAMPAIGN_SK,
    PAGE_PATH,
    MAX(PAGE_LOCATION)                                                       as PAGE_LOCATION,
    COUNT_IF(EVENT_NAME = 'session_start')                                  as VISITS,
    COUNT(*)                                                                 as EVENT_CNT,
    COUNT_IF(EVENT_NAME = 'page_view')                                      as VIEW_CNT,
    COUNT(DISTINCT USER_PSEUDO_ID || '|' || GA_SESSION_ID)                  as SESSION_CNT,
    COUNT(DISTINCT IFF(SESSION_ENGAGED = '1',
        USER_PSEUDO_ID || '|' || GA_SESSION_ID, NULL))                      as ENGAGED_SESSIONS,
    MAX(PERCENT_SCROLLED)                                                    as SCROLL_DEPTH,
    COUNT(DISTINCT IFF(IS_ACTIVE_USER, USER_PSEUDO_ID, NULL))               as ACTIVE_USERS,
    COUNT(DISTINCT USER_PSEUDO_ID)                                          as TOTAL_USERS,
    CAST(NULL AS NUMBER)                                                     as AVG_SESSION_DURATION,  -- ⚠️ 세션지속 산식 미정
    CAST(NULL AS NUMBER)                                                     as BOUNCE_RATE,           -- ⚠️ 비가산·정의 대기
    DIV0(
        COUNT(DISTINCT IFF(SESSION_ENGAGED='1', USER_PSEUDO_ID||'|'||GA_SESSION_ID, NULL)),
        COUNT(DISTINCT USER_PSEUDO_ID || '|' || GA_SESSION_ID)
    )                                                                        as ENGAGEMENT_RATE,
    DIV0(SUM(ENGAGEMENT_TIME_MSEC) / 1000.0,
        COUNT(DISTINCT USER_PSEUDO_ID || '|' || GA_SESSION_ID))              as AVG_ENGAGEMENT_TIME_PER_SESSION,  -- 초 단위(NUMBER(9,4))
    {{ gold_meta('GA4') }}
from joined
group by DATE_SK, IDENTITY_SK, GA_EVENT_SK, GA_SOURCE_SK, DEVICE_SK, CAMPAIGN_SK, PAGE_PATH
