-- DIM_EVENT: 행사 차원 스캐폴드 (CRM_EVENT, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ APPLY_CHANNEL 원천/파생규칙 미정(ADMIN A-10 대기).


with e as (
    select * from GN_DW.SILVER.CRM_EVENT
)

select
    ABS(HASH(COALESCE(CAST(EVENT_KEY AS VARCHAR), '∅')))                  as EVENT_SK,
    EVENT_KEY                                     as EVENT_BK,
    EVENT_SOURCE                                  as EVENT_KIND,
    EVENT_DIV_CD                                  as EVENT_CATEGORY,
    EVENT_NM                                      as EVENT_NAME,
    TRY_TO_DATE(STRT_DE, 'YYYYMMDD')              as EVENT_START_DATE,
    TRY_TO_DATE(END_DE, 'YYYYMMDD')               as EVENT_END_DATE,
    CAST(NULL AS VARCHAR)                          as APPLY_CHANNEL,   -- ⚠️ A-10 대기
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b50d9005-0be3-463b-8b58-76f0c3a68e8a'                    AS DW_BATCH_ID
from e

union all
-- unknown 멤버(SK=0): 팩트 EVENT_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', NULL, NULL, '(미매핑)', NULL, NULL, NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b50d9005-0be3-463b-8b58-76f0c3a68e8a'                    AS DW_BATCH_ID