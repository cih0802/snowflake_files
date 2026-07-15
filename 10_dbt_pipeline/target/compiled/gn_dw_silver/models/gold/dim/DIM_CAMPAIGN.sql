-- DIM_CAMPAIGN: 캠페인 차원 스캐폴드 (CRM_CAMPAIGN, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ ORG_SK(주관조직 O10 미확정)=0 센티넬. DOMESTIC_OVERSEAS/BIZ_CASE_TYPE 파생규칙 대기.


with c as (
    select * from GN_DW.SILVER.CRM_CAMPAIGN
)

select
    ABS(HASH(COALESCE(CAST(CMPGN_CD AS VARCHAR), '∅')))                   as CAMPAIGN_SK,
    CMPGN_CD                                      as CAMPAIGN_BK,
    BRND_NM                                       as BRAND,
    UPPER_CMPGN_CD                                as PARENT_CAMPAIGN,
    CMPGN_NM                                      as CAMPAIGN_NAME,
    PR_MTH_CD                                     as PROMO_METHOD,
    CAST(CMPGN_CTGR_CD AS VARCHAR)                as CAMPAIGN_TYPE,
    CAST(NULL AS VARCHAR)                          as DOMESTIC_OVERSEAS,  -- ⚠️ 파생규칙 대기
    CAST(CMPGN_TYPE1_BSN AS VARCHAR)              as BIZ_CASE_TYPE,
    TRY_TO_DATE(CMPGN_STRT_DE, 'YYYYMMDD')        as CAMPAIGN_OPEN_DATE,
    0                                             as ORG_SK,             -- ⚠️ 센티넬(O10 주관조직 미확정)
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '79c7f449-64e1-46aa-9c0c-b206859bd7a3'                    AS DW_BATCH_ID
from c

union all
-- unknown 멤버(SK=0): 팩트 CAMPAIGN_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', NULL, NULL, '(미매핑)', NULL, NULL, NULL, NULL, NULL, 0,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '79c7f449-64e1-46aa-9c0c-b206859bd7a3'                    AS DW_BATCH_ID