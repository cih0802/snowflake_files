-- DIM_SPONSORSHIP: 후원사업 차원 스캐폴드 (CRM_SPONSORSHIP, Bronze 입고 후 실행)
-- Co-authored with CoCo


with s as (
    select * from GN_DW.SILVER.CRM_SPONSORSHIP
)

select
    ABS(HASH(COALESCE(CAST(SPNSR_BSNS_ID AS VARCHAR), '∅')))              as SPONSORSHIP_SK,
    SPNSR_BSNS_ID                                 as SPONSORSHIP_BK,
    SPNSR_BSNS_NM                                 as SPONSORSHIP_NAME,
    SPNSR_BSNS_ABRV_CD                            as SPONSORSHIP_ABBR,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b50d9005-0be3-463b-8b58-76f0c3a68e8a'                    AS DW_BATCH_ID
from s

union all
-- unknown 멤버(SK=0): 팩트 SPONSORSHIP_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', '(미매핑)', NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b50d9005-0be3-463b-8b58-76f0c3a68e8a'                    AS DW_BATCH_ID