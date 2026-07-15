-- DIM_GA_SOURCE: 트래픽소스 차원 (GA4_TRAFFIC_SOURCE → source/medium grain)
-- Co-authored with CoCo
-- ⚠️ grain=(UTM_SOURCE,UTM_MEDIUM): GA4_EVENT 팩트가 조인 가능한 유일 grain(content/term은 이벤트에 부재).
--    content/term/source_medium 은 대표값(MAX) 보조표시 — 팩트 팬아웃 방지 위해 grain에서 제외.


with src as (
    select
        UTM_SOURCE,
        UTM_MEDIUM,
        MAX(UTM_CONTENT)    as UTM_CONTENT,
        MAX(UTM_TERM)       as UTM_TERM,
        MAX(SOURCE_MEDIUM)  as SOURCE_MEDIUM
    from GN_DW.SILVER.GA4_TRAFFIC_SOURCE
    group by UTM_SOURCE, UTM_MEDIUM
)

select
    ABS(HASH(COALESCE(CAST(UTM_SOURCE AS VARCHAR), '∅') || '‖' || COALESCE(CAST(UTM_MEDIUM AS VARCHAR), '∅'))) as GA_SOURCE_SK,
    UTM_SOURCE                      as UTM_SOURCE,
    UTM_MEDIUM                      as UTM_MEDIUM,
    UTM_CONTENT                     as UTM_CONTENT,
    UTM_TERM                        as UTM_TERM,
    SOURCE_MEDIUM                   as SOURCE_MEDIUM,
    'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'ecb2a2a1-80f3-4f9b-b682-52f3bd552714'                    AS DW_BATCH_ID
from src
union all
-- 순서9 Unknown 멤버(GA_SOURCE_SK=0): fact 의 미매핑 GA_SOURCE_SK 센티넬 라우팅 대상.
select 0, '(unknown)', '(unknown)', NULL, NULL, NULL, 'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'ecb2a2a1-80f3-4f9b-b682-52f3bd552714'                    AS DW_BATCH_ID