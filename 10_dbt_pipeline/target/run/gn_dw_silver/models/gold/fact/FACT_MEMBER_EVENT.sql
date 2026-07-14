
  
    

        create or replace transient table GN_DW.GOLD.FACT_MEMBER_EVENT
         as
        (-- FACT_MEMBER_EVENT: 회원 사건 팩트 스캐폴드 (개발 ∪ 후원중단, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ 스캐폴드: 행당 카운트 1 부여(회원 dedup·차원 SK 해소는 입고 후). CAMPAIGN/SPONSORSHIP/ORG/REASON_SK=0 센티넬.
-- 🔴 D1 임시조치[삭제금지]: materialized=table 로 스캐폴드 행소실 방지. 프로젝트 마감 전 'incremental'(차원 SK 실적재 시) 재전환 검토 필수. 이력/코드 정리 시에도 이 주석 보존.


with dev as (
    select
        TRY_TO_NUMBER(TO_CHAR(TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD'), 'YYYYMMDD'))  as DATE_SK,
        MBER_NO                                             as MEMBER_DK,
        'DEV'                                               as EVENT_TYPE,
        0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK, 0 as ORG_SK, 0 as REASON_SK,
        1 as DEV_CNT, 1 as DEV_MEMBERS,
        0 as STOP_CNT, 0 as STOP_MEMBERS, 0 as UNPAID_STOP_CNT, 0 as UNPAID_STOP_MEMBERS,
        TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD')                  as JOIN_DATE,
        CAST(NULL AS DATE)                                  as STOP_DATE,
        CAST(NULL AS VARCHAR)                               as STOP_REASON,
        CAST(NULL AS VARCHAR)                               as STOP_CHANNEL,
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG
    from GN_DW.SILVER.CRM_MEMBER_DEV
),

stop as (
    select
        TRY_TO_NUMBER(TO_CHAR(TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD'), 'YYYYMMDD')) as DATE_SK,
        MBER_NO                                             as MEMBER_DK,
        'STOP'                                              as EVENT_TYPE,
        0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK, 0 as ORG_SK, 0 as REASON_SK,
        0 as DEV_CNT, 0 as DEV_MEMBERS,
        1 as STOP_CNT, 1 as STOP_MEMBERS, 0 as UNPAID_STOP_CNT, 0 as UNPAID_STOP_MEMBERS,
        CAST(NULL AS DATE)                                  as JOIN_DATE,
        TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD')             as STOP_DATE,
        DSCNTC_RSN_CD                                       as STOP_REASON,
        DSCNTC_PATH                                         as STOP_CHANNEL,
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG
    from GN_DW.SILVER.CRM_MEMBER_DISCONTINUE
),

unioned as (
    select * from dev
    union all
    select * from stop
)

select
    DATE_SK, MEMBER_DK, EVENT_TYPE, CAMPAIGN_SK, SPONSORSHIP_SK, ORG_SK, REASON_SK,
    DEV_CNT, DEV_MEMBERS, STOP_CNT, STOP_MEMBERS, UNPAID_STOP_CNT, UNPAID_STOP_MEMBERS,
    JOIN_DATE, STOP_DATE, STOP_REASON, STOP_CHANNEL, NEW_EXISTING_FLAG,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'df029261-a9a2-4be5-9882-1697416aa73a'                    AS DW_BATCH_ID
from unioned
        );
      
  