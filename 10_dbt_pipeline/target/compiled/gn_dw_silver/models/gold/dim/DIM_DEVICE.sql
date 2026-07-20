-- DIM_DEVICE: 디바이스 차원 (GA4_DEVICE → DEVICE_TYPE DISTINCT, GOLD 축약)
-- Co-authored with CoCo


with src as (
    select distinct DEVICE_TYPE
    from GN_DW.SILVER.GA4_DEVICE
    where DEVICE_TYPE is not null
)

select
    ABS(HASH(COALESCE(CAST(DEVICE_TYPE AS VARCHAR), '∅')))  as DEVICE_SK,
    DEVICE_TYPE                     as DEVICE_TYPE,
    'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '50eaa2d8-6f32-46e5-ad87-91e23c3b74a4'                    AS DW_BATCH_ID
from src
union all
-- 순서9 Unknown 멤버(DEVICE_SK=0): fact 의 미매핑 DEVICE_SK 센티넬 라우팅 대상.
select 0, '(unknown)', 'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '50eaa2d8-6f32-46e5-ad87-91e23c3b74a4'                    AS DW_BATCH_ID