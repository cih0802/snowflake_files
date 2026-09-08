-- DIM_BIGQUERY_SOURCE: 트래픽소스 차원 (BIGQUERY_TRAFFIC_SOURCE → source/medium grain)
-- Co-authored with CoCo
-- ⚠️ grain=(UTM_SOURCE,UTM_MEDIUM): BIGQUERY_EVENT 팩트가 조인 가능한 유일 grain(content/term은 이벤트에 부재).
--    content/term/source_medium 은 대표값(MAX) 보조표시 — 팩트 팬아웃 방지 위해 grain에서 제외.


with src as (
    select
        UTM_SOURCE,
        UTM_MEDIUM,
        MAX(UTM_CONTENT)    as UTM_CONTENT,
        MAX(UTM_TERM)       as UTM_TERM,
        MAX(SOURCE_MEDIUM)  as SOURCE_MEDIUM,
        MAX(DEFAULT_CHANNEL_GROUP) as DEFAULT_CHANNEL_GROUP
    from GN_DW.SILVER.BIGQUERY_TRAFFIC_SOURCE
    group by UTM_SOURCE, UTM_MEDIUM
)

select
    ABS(HASH(COALESCE(CAST(UTM_SOURCE AS VARCHAR), '∅') || '‖' || COALESCE(CAST(UTM_MEDIUM AS VARCHAR), '∅'))) as BIGQUERY_SOURCE_SK,
    UTM_SOURCE                      as UTM_SOURCE,
    UTM_MEDIUM                      as UTM_MEDIUM,
    UTM_CONTENT                     as UTM_CONTENT,
    UTM_TERM                        as UTM_TERM,
    SOURCE_MEDIUM                   as SOURCE_MEDIUM,
    DEFAULT_CHANNEL_GROUP           as DEFAULT_CHANNEL_GROUP,
    'BIGQUERY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '1cc57a1d-4ecd-4300-b7be-1d37f0dc09e2'                    AS DW_BATCH_ID
from src
union all
-- 순서9 Unknown 멤버(BIGQUERY_SOURCE_SK=0): fact 의 미매핑 BIGQUERY_SOURCE_SK 센티넬 라우팅 대상.
select 0, '(unknown)', '(unknown)', NULL, NULL, NULL, NULL, 'BIGQUERY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '1cc57a1d-4ecd-4300-b7be-1d37f0dc09e2'                    AS DW_BATCH_ID