-- =============================================================================
-- Purpose    : 알림톡 수신 후 D+5 카카오 경로 GA 클릭 (클릭 1건 = 1행 · A 판정 ①②③의 공통 근거)
-- Target     : GOLD.FACT_AT_GA_CLICK (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_SEND_MEMBER, ref CRM_SEND_REQUEST, ref BIGQUERY_EVENT, ref FACT_AT_GA_LINK_MAP
-- Issue      : O265-C
-- =============================================================================
-- FACT_AT_GA_CLICK: 알림톡 수신 후 D+5 카카오 경로 GA 클릭
--  [2026-10-28 O265-C · 사용자 결정 = A 우선순위 ① 질문 시 템플릿 정보 > ② 고정 매핑표 > ③ 추정표]
--   왜 클릭 grain 인가 = ① 은 질문마다 패턴이 다르다 ⇒ Agent 가 랜딩 경로·utm 으로 **직접 거를 수 있어야** 한다.
--   · grain = 알림톡 발송요청 × 채널 × 회원 × 클릭 시각 × 랜딩(경로·utm) · 창 = 수신 시각 ~ +5일
--   · 클릭 정의 = FACT_MESSAGE_DISPATCH 의 B(ANY_AT_GA_OPEN_MEMBERS)와 같다 ⇒ 이 표의 (발송, 회원) 집합 = B 가 1 인 집합
--   · MAP_MATCHED = 그 템플릿의 ②③ 매핑 패턴에 맞으면 1 · 아니면 0 · 템플릿에 매핑이 없으면 NULL(판정 불가 · R2-7)
--   WARN: 회원번호(memnum)는 MEMBER_DK 로만 남기고 URL 원문은 싣지 않는다(경로·utm 3종만).
{{ config(
    tags=['gold_ready']
) }}

with req as (
    select SNDNG_KEY, SEND_CHANNEL, nullif(trim(TMPLAT_ID), '') as TEMPLATE_ID
    from {{ ref('CRM_SEND_REQUEST') }}
    where (SEND_CHANNEL = 'MSG_AT' and MSG_DIV_CD = '4') or (SEND_CHANNEL = 'SND' and MSG_TYPE = '1')
),
at_send as (
    select distinct m.SNDNG_KEY, m.SEND_CHANNEL, q.TEMPLATE_ID, m.MBER_NO, m.SNDNG_DE
    from {{ ref('CRM_SEND_MEMBER') }} m
    join req q on q.SNDNG_KEY = m.SNDNG_KEY and q.SEND_CHANNEL = m.SEND_CHANNEL
    where m.MBER_NO is not null and m.SNDNG_DE is not null
),
-- 클릭 정의 = FACT_MESSAGE_DISPATCH.ga_click 과 같다(memnum + 카카오 경로)
clk as (
    select distinct
        REGEXP_SUBSTR(PAGE_LOCATION, '[?&]memnum=([0-9A-Za-z]+)', 1, 1, 'e', 1)             as MBER_NO,
        EVENT_TS,
        lower(regexp_substr(PAGE_LOCATION, '^https?://[^/?#]+(/[^?#]*)?', 1, 1, 'e', 1))   as LANDING_PATH,
        lower(regexp_substr(PAGE_LOCATION, '[?&]utm_campaign=([^&#]+)', 1, 1, 'e', 1))     as UTM_CAMPAIGN,
        lower(regexp_substr(PAGE_LOCATION, '[?&]utm_content=([^&#]+)', 1, 1, 'e', 1))      as UTM_CONTENT
    from {{ ref('BIGQUERY_EVENT') }}
    where PAGE_LOCATION ilike '%memnum=%'
      and (COALESCE(UTM_SOURCE, '') ilike 'kakao%' or COALESCE(UTM_MEDIUM, '') ilike 'kakao%'
           or PAGE_LOCATION ilike '%utm_source=kakao%' or PAGE_LOCATION ilike '%utm_medium=kakao%')
),
map_tmpl as (
    select TEMPLATE_ID, min(MAP_SRC) as MAP_SRC from {{ ref('FACT_AT_GA_LINK_MAP') }} group by 1
),
map_pat as (
    select TEMPLATE_ID, MATCH_PATTERN from {{ ref('FACT_AT_GA_LINK_MAP') }}
),
win as (
    select a.SNDNG_KEY, a.SEND_CHANNEL, a.TEMPLATE_ID, a.MBER_NO, a.SNDNG_DE,
           c.EVENT_TS, c.LANDING_PATH, c.UTM_CAMPAIGN, c.UTM_CONTENT
    from at_send a
    join clk c
      on c.MBER_NO = a.MBER_NO
     and c.EVENT_TS >= a.SNDNG_DE
     and c.EVENT_TS <= DATEADD(day, 5, a.SNDNG_DE)
)

select
    COALESCE({{ date_sk('w.SNDNG_DE::DATE') }}, 0)                   as DATE_SK,
    w.MBER_NO                                                         as MEMBER_DK,
    {{ gold_sk(['w.SNDNG_KEY']) }}                                    as SEND_REQUEST_SK,
    w.SEND_CHANNEL                                                    as SEND_CHANNEL,
    w.TEMPLATE_ID                                                     as TEMPLATE_ID,
    w.SNDNG_DE                                                        as SEND_TS,
    w.EVENT_TS                                                        as CLICK_TS,
    DATEDIFF(day, w.SNDNG_DE::DATE, w.EVENT_TS::DATE)                 as DAYS_FROM_SEND,
    w.LANDING_PATH                                                    as LANDING_PATH,
    w.UTM_CAMPAIGN                                                    as UTM_CAMPAIGN,
    w.UTM_CONTENT                                                     as UTM_CONTENT,
    mt.MAP_SRC                                                        as MAP_SRC,
    CASE
        WHEN mt.TEMPLATE_ID IS NULL THEN CAST(NULL AS NUMBER(1,0))
        WHEN MAX(IFF(mp.MATCH_PATTERN IS NOT NULL, 1, 0)) = 1 THEN 1
        ELSE 0
    END                                                               as MAP_MATCHED,
    {{ gold_meta('CRM') }}
from win w
left join map_tmpl mt on mt.TEMPLATE_ID = w.TEMPLATE_ID
left join map_pat mp
  on mp.TEMPLATE_ID = w.TEMPLATE_ID
 and mp.MATCH_PATTERN in ('UTM:' || w.UTM_CAMPAIGN, 'PATH:' || w.LANDING_PATH)
group by w.SNDNG_KEY, w.SEND_CHANNEL, w.TEMPLATE_ID, w.MBER_NO, w.SNDNG_DE,
         w.EVENT_TS, w.LANDING_PATH, w.UTM_CAMPAIGN, w.UTM_CONTENT, mt.TEMPLATE_ID, mt.MAP_SRC
