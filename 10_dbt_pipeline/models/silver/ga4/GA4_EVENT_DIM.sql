-- GA4_EVENT_DIM: 이벤트분류 차원 (event_params FLATTEN → cat/label/action DISTINCT)
-- Co-authored with CoCo
{{ config(materialized='table') }}

with src as (
    {{ ga4_union_shards('20000101', '99991231') }}
),

per_event as (
    select
        e.event_name                                                                                          as EVENT_NAME,
        MAX(IFF(p.value:key::STRING='event_category', p.value:value:string_value::STRING, NULL))              as EVENT_CATEGORY,
        MAX(IFF(p.value:key::STRING='event_label',
            COALESCE(p.value:value:string_value::STRING, p.value:value:int_value::STRING), NULL))             as EVENT_LABEL,
        MAX(IFF(p.value:key::STRING='event_action', p.value:value:string_value::STRING, NULL))                as EVENT_ACTION
    from src e, LATERAL FLATTEN(input => e.event_params) p
    group by e.event_name, e.event_timestamp, e.user_pseudo_id, e.batch_ordering_id
)

select distinct
    EVENT_NAME,
    EVENT_CATEGORY,
    EVENT_LABEL,
    EVENT_ACTION,
    'GA4'                              as DW_SOURCE_SYSTEM,
    'BRONZE_GA4.EVENTS_*'              as DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from per_event
where EVENT_NAME is not null
