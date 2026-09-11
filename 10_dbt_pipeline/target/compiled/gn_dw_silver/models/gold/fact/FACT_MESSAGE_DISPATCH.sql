-- FACT_MESSAGE_DISPATCH: 메시지/서비스 발송 팩트 (이메일·문자·알림톡·우편 발송 및 성공/실패/오픈 현황)
-- Co-authored with CoCo


with s as (
    select * from GN_DW.SILVER.CRM_SEND_MEMBER
),
req as (
    select SNDNG_KEY, SEND_CHANNEL, SNDNG_TY_CD, TIT,
           SEND_GBN_TOP, SEND_GBN_MID, SEND_GBN_BOT
    from GN_DW.SILVER.CRM_SEND_REQUEST
),
open_window as (
    select MIN(OPEN_DT) as OPEN_TRACK_FROM
    from s
    where OPEN_DT is not null
)

select
    COALESCE(CASE WHEN s.SNDNG_DE::DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(s.SNDNG_DE::DATE, 'YYYYMMDD')) END, 0)  as DATE_SK,
    s.MBER_NO                                     as MEMBER_DK,
    CASE WHEN r.SNDNG_KEY IS NULL THEN 0
         ELSE ABS(HASH(COALESCE(CAST(r.SEND_CHANNEL AS VARCHAR), '∅') || '‖' || COALESCE(CAST(r.SNDNG_TY_CD AS VARCHAR), '∅'))) END  as SERVICE_SK,
    0                                             as CAMPAIGN_SK,
    1                                             as SEND_MEMBERS,
    CASE
        WHEN s.SEND_CHANNEL = 'EMAIL'  AND s.SNDNG_RST_CD = '1' THEN 1
        WHEN s.SEND_CHANNEL = 'MSG_AT' AND s.SEND_STATUS_GROUP IS NOT NULL
                                       AND s.SNDNG_RST_CD = '2' THEN 1
        ELSE 0
    END                                           as SUCCESS_MEMBERS,
    CASE
        WHEN s.SEND_CHANNEL = 'EMAIL'  AND s.SNDNG_RST_CD = '0' THEN 1
        WHEN s.SEND_CHANNEL = 'MSG_AT' AND s.SEND_STATUS_GROUP IS NOT NULL
                                       AND s.SNDNG_RST_CD = '3' THEN 1
        ELSE 0
    END                                           as FAIL_MEMBERS,
    CASE
        WHEN s.SEND_CHANNEL <> 'SND'                     THEN CAST(NULL AS NUMBER(38,0))
        WHEN s.OPEN_DT IS NOT NULL                       THEN 1
        WHEN ow.OPEN_TRACK_FROM IS NULL                  THEN CAST(NULL AS NUMBER(38,0))
        WHEN s.SNDNG_DE >= ow.OPEN_TRACK_FROM            THEN 0
        ELSE CAST(NULL AS NUMBER(38,0))
    END                                           as OPEN_MEMBERS,
    0 as LETTER_PART_MEMBERS, 0 as LETTER_PART_CNT, 0 as GIFT_PART_MEMBERS, 0 as GIFT_PART_AMT,
    0 as D5_LETTER_PART_MEMBERS, 0 as D5_LETTER_PART_CNT, 0 as D5_GIFT_PART_MEMBERS, 0 as D5_GIFT_PART_CNT,
    0 as D5_INCREASE_PART_MEMBERS, 0 as D5_INCREASE_PART_CNT, 0 as D5_STOP_MEMBERS, 0 as D5_STOP_CNT,
    0 as SERVICE_MEMBERS, 0 as SERVICE_CNT,
    r.TIT                                          as SEND_TITLE,
    s.SNDNG_RST_CD                                as SEND_STATUS,
    CAST(NULL AS VARCHAR)                          as SEND_STATUS2,
    s.SEND_CHANNEL                                as SEND_TYPE,
    CAST(NULL AS BOOLEAN)                          as MAIL_RECEIVE_FLAG,
    CAST(NULL AS BOOLEAN)                          as MEMBER_STOP_FLAG,
    CASE WHEN r.SEND_GBN_TOP IS NULL THEN 0
         ELSE ABS(HASH(COALESCE(CAST(r.SEND_GBN_TOP AS VARCHAR), '∅') || '‖' || COALESCE(CAST(r.SEND_GBN_MID AS VARCHAR), '∅') || '‖' || COALESCE(CAST(r.SEND_GBN_BOT AS VARCHAR), '∅'))) END as SEND_TYPE_SK,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '025f9ac5-d9be-4588-8381-cd1bfa260b2e'                    AS DW_BATCH_ID,
    s.SEND_STATUS_GROUP                           as SEND_STATUS_GROUP,
    s.SEND_STATUS_NAME                            as SEND_STATUS_NAME,
    s.SEND_RESULT_CD                              as SEND_RESULT_CD,
    s.SEND_RESULT_GROUP                           as SEND_RESULT_GROUP,
    s.SEND_RESULT_NAME                            as SEND_RESULT_NAME
from s
left join req r on s.SNDNG_KEY = r.SNDNG_KEY
cross join open_window ow
where s.MBER_NO is not null