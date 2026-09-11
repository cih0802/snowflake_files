-- FACT_EVENT_ATTENDANCE: 행사 참여/출석 팩트 (행사별 회원 참여, 출석, 신청, 대기, 취소 현황)
-- Co-authored with CoCo


with p as (
    select * from GN_DW.SILVER.CRM_EVENT_PARTICIPATION
)

select
    COALESCE(CASE WHEN p.PARTCPT_DT::DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(p.PARTCPT_DT::DATE, 'YYYYMMDD')) END, CASE WHEN e.EVENT_START_DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(e.EVENT_START_DATE, 'YYYYMMDD')) END, 0) as DATE_SK,
    p.MBER_NO                                     as MEMBER_DK,
    COALESCE(e.EVENT_SK, 0)                        as EVENT_SK,
    0                                             as CAMPAIGN_SK,
    0                                             as SPONSORSHIP_SK,
    1 as TOTAL_CNT,
    IFF(p.PARTCPT_STAT_GROUP IS NOT NULL AND p.PARTCPT_STAT_NM LIKE '대기%', 1, 0)  as WAIT_CNT,
    IFF(p.PARTCPT_STAT_GROUP IS NOT NULL AND p.PARTCPT_STAT_NM = '취소', 1, 0)      as CANCEL_CNT,
    0 as CONFIRM_CNT,
    1 as PARTICIPATE_CNT, 1 as PARTICIPANT_CNT,
    IFF(p.PARTCPT_STAT_GROUP IS NOT NULL AND p.PARTCPT_STAT_NM = '불참', 1, 0)      as ABSENT_CNT,
    0 as PARTICIPATION_TIMES, 0 as WAIT_TIMES, 0 as ABSENT_TIMES, 0 as CUM_APPLY_TIMES,
    p.RCPMNY_AMT                                  as REGULAR_DONATION,
    (p.PRZWIN_CD IS NOT NULL)                     as WIN_FLAG,
    CAST(NULL AS BOOLEAN)                          as SELF_PART_FLAG,
    p.PARTCPT_STAT_CD                             as PART_STATUS,
    p.PARTCPT_PATH_CD                             as PART_PATH,
    p.PARTCPT_CHNNL_CD                            as PART_CHANNEL,
    p.EVENT_KEY                                   as EVENT_BK,
    p.PARTCPT_SEQ                                 as PARTCPT_SEQ,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '025f9ac5-d9be-4588-8381-cd1bfa260b2e'                    AS DW_BATCH_ID,
    p.PARTCPT_STAT_GROUP                          as PART_STATUS_GROUP,
    p.PARTCPT_STAT_NM                             as PART_STATUS_NAME,
    p.PARTCPT_PATH_GROUP                          as PART_PATH_GROUP,
    p.PARTCPT_PATH_NM                             as PART_PATH_NAME,
    p.PARTCPT_CHNNL_GROUP                         as PART_CHANNEL_GROUP,
    p.PARTCPT_CHNNL_NM                            as PART_CHANNEL_NAME,
    case p.DW_SOURCE_TABLE
         when 'BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL' then 'EVENT'
         when 'BRONZE_CRM.TD_MS_CRMN_PRTCPNT'      then 'CRMN' end as EVENT_KIND,
    case p.DW_SOURCE_TABLE
         when 'BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL' then '일반행사'
         when 'BRONZE_CRM.TD_MS_CRMN_PRTCPNT'      then '캠페인행사' end as EVENT_KIND_NAME
from p
left join GN_DW.GOLD.DIM_EVENT e
    on e.EVENT_BK = p.EVENT_KEY