-- DIM_GA_EVENT: 이벤트분류 차원 (GA4_EVENT_DIM → category/label/action DISTINCT)
-- Co-authored with CoCo


with src as (
    select distinct EVENT_CATEGORY, EVENT_LABEL, EVENT_ACTION
    from GN_DW.SILVER.GA4_EVENT_DIM
)

select
    ABS(HASH(COALESCE(CAST(EVENT_CATEGORY AS VARCHAR), '∅') || '‖' || COALESCE(CAST(EVENT_LABEL AS VARCHAR), '∅') || '‖' || COALESCE(CAST(EVENT_ACTION AS VARCHAR), '∅'))) as GA_EVENT_SK,
    EVENT_CATEGORY                  as EVENT_CATEGORY,
    EVENT_LABEL                     as EVENT_LABEL,
    EVENT_ACTION                    as EVENT_ACTION,
    'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b50d9005-0be3-463b-8b58-76f0c3a68e8a'                    AS DW_BATCH_ID
from src
union all
-- 순서9 Unknown 멤버(GA_EVENT_SK=0): fact 의 미매핑 GA_EVENT_SK 센티넬 라우팅 대상.
select 0, '(unknown)', '(unknown)', '(unknown)', 'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b50d9005-0be3-463b-8b58-76f0c3a68e8a'                    AS DW_BATCH_ID