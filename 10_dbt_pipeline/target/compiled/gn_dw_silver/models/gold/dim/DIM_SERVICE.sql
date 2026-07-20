-- DIM_SERVICE: 발송 서비스 차원 스캐폴드 (CRM_SEND_REQUEST DISTINCT, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ SEND_TYPE_L/M/S(대/중/소) 코드체계 검수 대기(설계 §8). 현재 CHANNEL/SUBTYPE만.


with src as (
    select distinct SEND_CHANNEL, SNDNG_TY_CD
    from GN_DW.SILVER.CRM_SEND_REQUEST
)

select
    ABS(HASH(COALESCE(CAST(SEND_CHANNEL AS VARCHAR), '∅') || '‖' || COALESCE(CAST(SNDNG_TY_CD AS VARCHAR), '∅'))) as SERVICE_SK,
    CAST(NULL AS VARCHAR)                          as SEND_TYPE_L,   -- ⚠️ 대분류 미해소
    CAST(NULL AS VARCHAR)                          as SEND_TYPE_M,   -- ⚠️ 중분류 미해소
    CAST(NULL AS VARCHAR)                          as SEND_TYPE_S,   -- ⚠️ 소분류 미해소
    SNDNG_TY_CD                                   as SUBTYPE,
    SEND_CHANNEL                                  as CHANNEL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '50eaa2d8-6f32-46e5-ad87-91e23c3b74a4'                    AS DW_BATCH_ID
from src

union all
-- unknown 멤버(SK=0): 팩트 SERVICE_SK=0(미매핑) 조인 유실 방지
select 0, NULL, NULL, NULL, '(미매핑)', '(미매핑)',
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '50eaa2d8-6f32-46e5-ad87-91e23c3b74a4'                    AS DW_BATCH_ID