-- FACT_EVENT_PARTICIPATION: 행사 참여 팩트 스캐폴드 (CRM_EVENT_PARTICIPATION, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ 스캐폴드: 행당 PARTICIPANT_CNT=1. 모집/대기/취소 등 상태별 집계는 입고 후. CAMPAIGN/SPONSORSHIP_SK=0 센티넬.
-- 🔴 D1 임시조치[삭제금지]: materialized=table 로 스캐폴드 행소실 방지. 프로젝트 마감 전 'incremental'(차원 SK 실적재 시) 재전환 검토 필수. 이력/코드 정리 시에도 이 주석 보존.
{{ config(
    materialized='table',
    unique_key=['DATE_SK','MEMBER_DK','EVENT_SK'],
    tags=['gold_pending']
) }}

with p as (
    select * from {{ ref('CRM_EVENT_PARTICIPATION') }}
)

select
    {{ date_sk('p.PARTCPT_DT::DATE') }}           as DATE_SK,
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
    {{ gold_meta('CRM') }}
from p
left join {{ ref('DIM_EVENT') }} e
    on e.EVENT_BK = p.EVENT_KEY
