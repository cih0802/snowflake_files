-- FACT_EVENT_ATTENDANCE: 행사 참여/출석 팩트 (행사별 회원 참여, 출석, 신청, 대기, 취소 현황)
-- Co-authored with CoCo
-- 🔴 [2026-09-22 O179 · I1] 리터럴 pre_hook='TRUNCATE TABLE IF EXISTS <this>' **제거**.
--    이유 = dbt 는 hook 을 누적하므로 `dbt_project.yml` `gold.fact:+pre-hook: gold_fact_purge(this)`
--    와 **이중 실행**됐다(dbt_project.yml:239-246 이 경고한 구조).
--    🟢 피해는 0 이었다 — 이 팩트는 `RANGED_FACTS` 에 없어 매크로도 `TRUNCATE` 를 내고
--       **TRUNCATE 는 멱등**이라 2회 실행이 1회와 같다 ⇒ 제거 후 기대값은 **행수 불변**이다.
--    🔴 그래도 제거하는 이유 = 이 팩트를 나중에 `RANGED_FACTS` 에 넣는 순간
--       TRUNCATE + 범위 DELETE 가 함께 돌아 **에러 없이 창 크기로 쪼그라든다.**
--       즉 지금은 무해하지만 **한 줄만 바뀌면 사고가 되는 배선**이었다.
--    🔴 pre-hook 정의 지점은 `macros/gold_fact_purge.sql` 하나다 — 여기에 다시 쓰지 마라.
-- 🆕 🔴🔴 [2026-09-22 O180] **위 주석은 원래 config 블록 안에 있었고 그것이 컴파일을 깨뜨렸다.**
--    config 호출은 **Jinja 표현식**이므로 `--` 는 SQL 주석이 아니라 연산자로 파싱된다.
--    게다가 주석 안에 인용해 둔 Jinja 태그(중괄호 2개로 감싼 this)가 닫는 중괄호로
--    **config 를 조기 종료**시켰다
--    ⇒ `Compilation Error ... invalid syntax for function call expression line 3`.
--    🟢 그래서 이 주석을 **config 바깥으로 옮기고** 그 인용을 `<this>` 로 바꿨다.
--    🔴🔴 판정식 3개 — 전부 이 한 사고에서 나왔다:
--       ㉠ **config 안에 `--` 주석을 쓰지 마라.** 설명은 config 위·아래 SQL 주석에 둔다.
--       ㉡ **주석 안에서도 Jinja 태그를 인용하지 마라** — dbt 는 파일 전체를 Jinja 로 렌더하므로
--          `--` 는 Jinja 를 막지 못한다. 백틱도 막지 못한다. 태그 이름만 말로 적어라.
--       ㉢ **Jinja 를 인용해야 하면 `{#- … -#}` 블록에 넣어라** — 그 안은 렌더되지 않는다.
--    🔴 O180 이 ㉡ 를 모른 채 1차 수정에서 같은 결함을 재생산했다(자체 적발·즉시 정정).
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    tags=['gold_ready']
) }}

with p as (
    select * from {{ ref('CRM_EVENT_PARTICIPATION') }}
)

select
    COALESCE({{ date_sk('p.PARTCPT_DT::DATE') }}, {{ date_sk('e.EVENT_START_DATE') }}, 0) as DATE_SK,
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
    {{ gold_meta('CRM') }},
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
left join {{ ref('DIM_EVENT') }} e
    on e.EVENT_BK = p.EVENT_KEY
