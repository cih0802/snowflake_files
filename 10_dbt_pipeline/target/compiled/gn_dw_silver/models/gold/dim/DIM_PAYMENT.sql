-- DIM_PAYMENT: 결제수단 차원 스캐폴드 (CRM_PAYMENT_METHOD DISTINCT, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ FEE_TYPE(회비유형 정기/일시) 이중표현 설계결정 대기(§8). SETTLE_METHOD 라벨은 CRM_CODE 조인 후.


with src as (
    select distinct SETLE_CD, SETLE_NM
    from GN_DW.SILVER.CRM_PAYMENT_METHOD
)

select
    ABS(HASH(COALESCE(CAST(SETLE_CD AS VARCHAR), '∅')))                   as PAYMENT_SK,
    SETLE_CD                                      as PAYMENT_METHOD,
    SETLE_NM                                      as SETTLE_METHOD,
    CAST(NULL AS VARCHAR)                          as FEE_TYPE,   -- ⚠️ 정기/일시 이중표현 결정 대기
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '79c7f449-64e1-46aa-9c0c-b206859bd7a3'                    AS DW_BATCH_ID
from src

union all
-- unknown 멤버(SK=0): 팩트 PAYMENT_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', NULL, NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '79c7f449-64e1-46aa-9c0c-b206859bd7a3'                    AS DW_BATCH_ID