-- FACT_MESSAGE_DISPATCH: 메시지/서비스 발송 팩트 (이메일·문자·알림톡·우편 발송 및 성공/실패/오픈 현황)
-- Co-authored with CoCo
-- 🔴 [2026-09-22 O179 · I1] 리터럴 pre_hook **제거** — `dbt_project.yml` `gold.fact:+pre-hook`
--    (`gold_fact_purge(this)`)와 **이중 실행**됐다. 🟢 둘 다 `TRUNCATE` 를 내고 TRUNCATE 는 멱등이라
--    피해 0 이었고 제거 후 기대값도 **행수 불변**이다. 🔴 제거 이유 = `RANGED_FACTS` 등재 시
--    TRUNCATE + 범위 DELETE 동시 실행으로 **에러 없이 창 크기로 쪼그라드는** 잠재 사고였다.
--    🔴 정의 지점 = `macros/gold_fact_purge.sql` 하나 · 여기에 다시 쓰지 마라.
-- 🆕 🔴 [2026-09-22 O180] **위 주석을 config 블록 밖으로 옮겼다** — config 호출은 Jinja 표현식이라
--    `--` 가 주석이 아니라 연산자로 파싱돼 컴파일이 깨졌다(`FACT_EVENT_ATTENDANCE` 가 먼저 터졌고
--    같은 결함이 O179 가 만진 GOLD 팩트 **4건 전건**에 있었다).
--    🔴 판정식 = **config 안에 `--` 주석 금지 · 주석 안에서도 Jinja 태그 인용 금지**
--       (dbt 는 파일 전체를 Jinja 로 렌더하므로 `--` 도 백틱도 Jinja 를 막지 못한다).
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    tags=['gold_ready']
) }}

with s as (
    select * from {{ ref('CRM_SEND_MEMBER') }}
),
req as (
    select SNDNG_KEY, SEND_CHANNEL, SNDNG_TY_CD, TIT,
           SEND_GBN_TOP, SEND_GBN_MID, SEND_GBN_BOT
    from {{ ref('CRM_SEND_REQUEST') }}
),
open_window as (
    select MIN(OPEN_DT) as OPEN_TRACK_FROM
    from s
    where OPEN_DT is not null
)

select
    COALESCE({{ date_sk('s.SNDNG_DE::DATE') }}, 0)  as DATE_SK,
    s.MBER_NO                                     as MEMBER_DK,
    CASE WHEN r.SNDNG_KEY IS NULL THEN 0
         ELSE {{ gold_sk(['r.SEND_CHANNEL', 'r.SNDNG_TY_CD']) }} END  as SERVICE_SK,
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
         ELSE {{ gold_sk(['r.SEND_GBN_TOP', 'r.SEND_GBN_MID', 'r.SEND_GBN_BOT']) }} END as SEND_TYPE_SK,
    {{ gold_meta('CRM') }},
    s.SEND_STATUS_GROUP                           as SEND_STATUS_GROUP,
    s.SEND_STATUS_NAME                            as SEND_STATUS_NAME,
    s.SEND_RESULT_CD                              as SEND_RESULT_CD,
    s.SEND_RESULT_GROUP                           as SEND_RESULT_GROUP,
    s.SEND_RESULT_NAME                            as SEND_RESULT_NAME
from s
left join req r on s.SNDNG_KEY = r.SNDNG_KEY
cross join open_window ow
where s.MBER_NO is not null
