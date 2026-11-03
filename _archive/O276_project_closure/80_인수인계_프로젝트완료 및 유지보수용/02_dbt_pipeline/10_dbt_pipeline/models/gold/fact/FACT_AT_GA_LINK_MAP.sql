-- =============================================================================
-- Purpose    : 알림톡 템플릿 → GA 랜딩 패턴 매핑 (A 「그 알림톡 열람」 판정 근거 · 우선순위 ②③)
-- Target     : GOLD.FACT_AT_GA_LINK_MAP (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref MAP_AT_GA_LINK, ref CRM_MSG_TEMPLATE, ref CRM_MSG_TEMPLATE_BUTTON, ref CRM_SEND_REQUEST, ref CRM_SEND_MEMBER, ref BIGQUERY_EVENT
-- Issue      : O265-C
-- =============================================================================
-- FACT_AT_GA_LINK_MAP: 알림톡 템플릿 → GA 랜딩 패턴 매핑
--  [2026-10-28 O265-C · 사용자 결정 = 우선순위 ① 질문 시 템플릿 정보 > ② 고정 매핑표 > ③ 추정표]
--   ① 은 질문 시점의 일이라 이 테이블에 없다(FACT_AT_GA_CLICK 에서 Agent 가 직접 거른다).
--   이 테이블 = ②③ · 템플릿마다 **가장 높은 우선순위 출처의 행만** 남긴다(출처를 섞지 않는다).
--   · MAP_PRIORITY 1 = MANUAL·WEB_TEAM — seed `MAP_AT_GA_LINK`(수기 확정 · 웹팀 리다이렉트 대상표)
--   · MAP_PRIORITY 2 = DIRECT — 원천 템플릿 버튼·본문 URL 이 단축·리다이렉트가 아닌 경우(결정적)
--   · MAP_PRIORITY 3 = INFER — 수신자 클릭 랜딩의 전용성으로 추정
--  매칭 패턴 = 'UTM:<utm_campaign 소문자>' 또는 'PATH:<호스트 뒤 경로 소문자>' · GA 클릭도 같은 두 형태를 만든다.
--  WARN: GA 는 리다이렉트 **뒤의 최종 랜딩**만 본다(gni.kr/url 은 page_location 2 · referrer 0 실측)
--     ⇒ bit.ly·gni.kr/url·youtu 링크는 DIRECT 로 쓰지 않는다(웹팀 대상표 또는 INFER 로 채운다).
--  INFER 규칙(이전 계정 2026-10-28 실측으로 정함)
--   ㉠ 묶음 = 발송구분 (대 > 소) — 같은 캠페인의 템플릿이 여럿이다(행운의 카드 4종 = MS046 > 1301).
--   ㉡ 후보 = 묶음 수신자의 수신~D+5 클릭 랜딩 · 루트 경로 제외.
--   ㉢ 전용성 = 그 랜딩을 묶음 첫 수신 이후 클릭한 회원 중 **클릭 전에 그 묶음을 받은** 회원 비율 — **창 없이** 본다.
--      창(D+5)을 분자에 걸면 5일 뒤 클릭이 빠져 전용 링크도 15% 로 떨어졌다(행운의 카드 실측) ⇒ 창은 A 판정에만 쓴다.
--   ㉣ 채택 = 전용성 ≥ min_share · 수신 클릭 회원 ≥ min_members · 그 템플릿 수신자가 실제로 클릭한 랜딩만 그 템플릿에 붙인다.
--   WARN: 같은 시기에 같은 랜딩을 쓴 서로 다른 묶음은 전용성이 갈려 채택되지 않는다(= 판정 불가 · 추정하지 않는다).
{%- set min_share   = var('at_ga_infer_min_share', 0.95) -%}
{%- set min_members = var('at_ga_infer_min_members', 5) -%}
{{ config(
    tags=['gold_ready']
) }}

with tmpl_url as (
    select TMPLAT_ID as TEMPLATE_ID, coalesce(MOBILE_URL, PC_URL) as URL
    from {{ ref('CRM_MSG_TEMPLATE_BUTTON') }}
    where coalesce(MOBILE_URL, PC_URL) ilike 'http%'
    union all
    select TEMPLATE_KEY, regexp_substr(TEMPLATE_CTNT, 'https?://[^ \\n\\r"<>]+')
    from {{ ref('CRM_MSG_TEMPLATE') }}
    where SEND_CHANNEL = 'MSG_AT' and TEMPLATE_CTNT ilike '%http%'
),
direct as (
    select distinct TEMPLATE_ID,
        case
            when URL ilike '%utm_campaign=%'
                then 'UTM:' || lower(regexp_substr(URL, '[?&]utm_campaign=([^&#]+)', 1, 1, 'e', 1))
            else 'PATH:' || lower(regexp_substr(URL, '^https?://[^/?#]+(/[^?#]*)?', 1, 1, 'e', 1))
        end as MATCH_PATTERN
    from tmpl_url
    where TEMPLATE_ID is not null
      and not (URL ilike '%bit.ly/%' or URL ilike '%gni.kr/url/%' or URL ilike '%youtu%')
),
direct_ok as (
    select TEMPLATE_ID, MATCH_PATTERN from direct
    where MATCH_PATTERN not in ('PATH:', 'PATH:/', 'UTM:') and MATCH_PATTERN is not null
),
req as (
    select SNDNG_KEY, SEND_CHANNEL, nullif(trim(TMPLAT_ID), '') as TEMPLATE_ID,
           SEND_GBN_TOP || '>' || coalesce(SEND_GBN_BOT, '∅') as SEND_GROUP
    from {{ ref('CRM_SEND_REQUEST') }}
    where ((SEND_CHANNEL = 'MSG_AT' and MSG_DIV_CD = '4') or (SEND_CHANNEL = 'SND' and MSG_TYPE = '1'))
      and SEND_GBN_TOP is not null
),
recv as (
    select distinct q.SEND_GROUP, q.TEMPLATE_ID, m.MBER_NO, m.SNDNG_DE
    from {{ ref('CRM_SEND_MEMBER') }} m
    join req q on q.SNDNG_KEY = m.SNDNG_KEY and q.SEND_CHANNEL = m.SEND_CHANNEL
    where m.MBER_NO is not null and m.SNDNG_DE is not null
),
grp_first as (
    select SEND_GROUP, MBER_NO, min(SNDNG_DE) as FIRST_RECV from recv group by 1, 2
),
grp_start as (
    select SEND_GROUP, min(FIRST_RECV) as GROUP_FROM from grp_first group by 1
),
-- 클릭 정의 = FACT_MESSAGE_DISPATCH.ga_click 과 같다(memnum + 카카오 경로)
clk as (
    select
        REGEXP_SUBSTR(PAGE_LOCATION, '[?&]memnum=([0-9A-Za-z]+)', 1, 1, 'e', 1) as MBER_NO,
        EVENT_TS,
        coalesce('UTM:' || lower(regexp_substr(PAGE_LOCATION, '[?&]utm_campaign=([^&#]+)', 1, 1, 'e', 1)),
                 'PATH:' || lower(regexp_substr(PAGE_LOCATION, '^https?://[^/?#]+(/[^?#]*)?', 1, 1, 'e', 1))) as CLICK_PATTERN
    from {{ ref('BIGQUERY_EVENT') }}
    where PAGE_LOCATION ilike '%memnum=%'
      and (COALESCE(UTM_SOURCE, '') ilike 'kakao%' or COALESCE(UTM_MEDIUM, '') ilike 'kakao%'
           or PAGE_LOCATION ilike '%utm_source=kakao%' or PAGE_LOCATION ilike '%utm_medium=kakao%')
),
clk_first as (
    select MBER_NO, CLICK_PATTERN, min(EVENT_TS) as FIRST_CLICK from clk
    where MBER_NO is not null and CLICK_PATTERN not in ('PATH:', 'PATH:/') group by 1, 2
),
-- ㉡ 후보(창 안) — 묶음 단위 · 템플릿 단위 둘 다 기억
cand as (
    select distinct r.SEND_GROUP, r.TEMPLATE_ID, c.CLICK_PATTERN
    from recv r
    join clk c on c.MBER_NO = r.MBER_NO
              and c.EVENT_TS >= r.SNDNG_DE and c.EVENT_TS <= dateadd(day, 5, r.SNDNG_DE)
    where c.CLICK_PATTERN not in ('PATH:', 'PATH:/')
),
-- ㉢ 전용성(창 없음)
excl as (
    select g.SEND_GROUP, cf.CLICK_PATTERN,
        count(distinct cf.MBER_NO)                                                       as ALL_CLICK_MEMBERS,
        count(distinct iff(gf.FIRST_RECV <= cf.FIRST_CLICK, cf.MBER_NO, null))            as RECV_CLICK_MEMBERS
    from (select distinct SEND_GROUP, CLICK_PATTERN from cand) g
    join grp_start gs on gs.SEND_GROUP = g.SEND_GROUP
    join clk_first cf on cf.CLICK_PATTERN = g.CLICK_PATTERN and cf.FIRST_CLICK >= gs.GROUP_FROM
    left join grp_first gf on gf.SEND_GROUP = g.SEND_GROUP and gf.MBER_NO = cf.MBER_NO
    group by 1, 2
),
infer_ok as (
    select distinct c.TEMPLATE_ID, c.CLICK_PATTERN as MATCH_PATTERN,
        e.RECV_CLICK_MEMBERS, e.ALL_CLICK_MEMBERS
    from cand c
    join excl e on e.SEND_GROUP = c.SEND_GROUP and e.CLICK_PATTERN = c.CLICK_PATTERN
    where c.TEMPLATE_ID is not null
      and e.RECV_CLICK_MEMBERS >= {{ min_members }}
      and e.RECV_CLICK_MEMBERS / nullif(e.ALL_CLICK_MEMBERS, 0) >= {{ min_share }}
),
seed as (
    select upper(trim(TEMPLATE_ID)) as TEMPLATE_ID,
           upper(trim(MATCH_TYPE)) || ':' || lower(trim(MATCH_VALUE)) as MATCH_PATTERN,
           upper(trim(MAP_SRC)) as MAP_SRC
    from {{ ref('MAP_AT_GA_LINK') }}
    where nullif(trim(TEMPLATE_ID), '') is not null and nullif(trim(MATCH_VALUE), '') is not null
),
all_src as (
    select TEMPLATE_ID, MATCH_PATTERN, MAP_SRC, 1 as MAP_PRIORITY,
           cast(null as number(18,0)) as RECV_CLICK_MEMBERS, cast(null as number(18,0)) as ALL_CLICK_MEMBERS
    from seed
    union all
    select TEMPLATE_ID, MATCH_PATTERN, 'DIRECT', 2, null, null from direct_ok
    union all
    select TEMPLATE_ID, MATCH_PATTERN, 'INFER', 3, RECV_CLICK_MEMBERS, ALL_CLICK_MEMBERS from infer_ok
),
best as (
    select * from all_src
    qualify MAP_PRIORITY = min(MAP_PRIORITY) over (partition by TEMPLATE_ID)
)

select
    TEMPLATE_ID,
    MATCH_PATTERN,
    MAP_SRC,
    MAP_PRIORITY,
    RECV_CLICK_MEMBERS,
    ALL_CLICK_MEMBERS,
    {{ gold_meta('CRM') }}
from best
qualify row_number() over (partition by TEMPLATE_ID, MATCH_PATTERN order by MAP_SRC) = 1
