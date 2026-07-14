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
    '24b70347-040a-40c6-b075-ccde404e290d'                    AS DW_BATCH_ID
from src