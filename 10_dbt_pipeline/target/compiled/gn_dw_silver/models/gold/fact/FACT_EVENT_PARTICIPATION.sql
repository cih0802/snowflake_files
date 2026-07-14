-- FACT_EVENT_PARTICIPATION: 행사 참여 팩트 스캐폴드 (CRM_EVENT_PARTICIPATION, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ 스캐폴드: 행당 PARTICIPANT_CNT=1. 모집/대기/취소 등 상태별 집계는 입고 후. CAMPAIGN/SPONSORSHIP_SK=0 센티넬.
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.


with p as (
    select * from GN_DW.SILVER.CRM_EVENT_PARTICIPATION
)

select
    COALESCE(TRY_TO_NUMBER(TO_CHAR(p.PARTCPT_DT::DATE, 'YYYYMMDD')), TRY_TO_NUMBER(TO_CHAR(e.EVENT_START_DATE, 'YYYYMMDD')), 0) as DATE_SK,  -- 참여일 없으면 행사시작일, 둘 다 없으면 센티넬0 (순서9)
    p.MBER_NO                                     as MEMBER_DK,
    COALESCE(e.EVENT_SK, 0)                        as EVENT_SK,
    0                                             as CAMPAIGN_SK,
    0                                             as SPONSORSHIP_SK,
    0 as RECRUIT_CNT, 0 as TOTAL_CNT, 0 as WAIT_CNT, 0 as CANCEL_CNT, 0 as CONFIRM_CNT,
    1 as PARTICIPATE_CNT, 0 as ABSENT_CNT, 1 as PARTICIPANT_CNT,
    0 as PARTICIPATION_TIMES, 0 as WAIT_TIMES, 0 as ABSENT_TIMES, 0 as CUM_APPLY_TIMES,
    p.RCPMNY_AMT                                  as REGULAR_DONATION,
    (p.PRZWIN_CD IS NOT NULL)                     as WIN_FLAG,
    CAST(NULL AS BOOLEAN)                          as SELF_PART_FLAG,
    p.PARTCPT_STAT_CD                             as PART_STATUS,
    p.PARTCPT_PATH_CD                             as PART_PATH,
    p.PARTCPT_CHNNL_CD                            as PART_CHANNEL,
    CAST(NULL AS BOOLEAN)                          as INCREASE_FLAG,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '939bb5db-645a-41c5-a55e-0e6a4feb44c8'                    AS DW_BATCH_ID
from p
left join GN_DW.GOLD.DIM_EVENT e
    on e.EVENT_BK = p.EVENT_KEY