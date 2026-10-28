-- =============================================================================
-- Purpose    : 개발사건 코호트 × 사건 전후 발송 브리지 (코호트 키 × 발송요청 × 발송일)
-- Target     : GOLD.FACT_COHORT_DISPATCH (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref FACT_MEMBER_EVENT_COHORT, ref FACT_MESSAGE_DISPATCH, ref DIM_SEND_REQUEST, ref DIM_MSG_TEMPLATE
-- Issue      : O265
-- =============================================================================
-- FACT_COHORT_DISPATCH: 개발사건 코호트 × 사건 전후 발송 브리지
--  [2026-10-28 O265 · 사용자 결정 = 브리지 팩트 신설 · 현업 문의 = 회원참여팀]
--   왜 새 팩트인가 = 코호트(FACT_MEMBER_EVENT_COHORT)는 발송을 **예/아니오 플래그**로만 담아 「어떤 발송구분(대/중/소)을
--   받았나」를 답할 수 없다. 코호트와 발송 팩트는 둘 다 회원 기준 비유일이라 SV 관계도 걸 수 없다 ⇒ 다(多) 쪽 브리지를 둔다.
--   · grain = 코호트 키(회원 × 사건월 × 개발구분) × 발송요청 × 발송일 · MONTHS_AFTER = 0 고정(코호트 PK 참조용)
--   · 창 = 첫 사건일 기준 D-30 ~ D+5 (코호트 플래그와 같다) · 구간 라벨 = D-30~D-1 / D0 / D+1~D+5
--   · 발송구분 = SEND_TYPE_SK(→ DIM_SEND_TYPE) · 메시지 형식 = DIM_SEND_REQUEST.SEND_FORMAT_NAME
--   WARN: 같은 (회원, 요청, 발송일)의 발송 행이 여럿이면 1행으로 접고 SEND_ROWS 에 행 수를 둔다.
--   WARN: 인과가 아니라 시간 창 매칭이다 · 사건 당일(D0) 발송은 대부분 처리 통보(DEC-33) ⇒ 답변에 구간을 밝힌다.
{{ config(
    tags=['gold_ready']
) }}

with ev as (
    select
        EVENT_MONTH_KEY, MEMBER_DK, DVLP_DIV_CD, MONTHS_AFTER,
        TO_DATE(TO_VARCHAR(FIRST_EVENT_DATE_SK), 'YYYYMMDD') as EVENT_DATE
    from {{ ref('FACT_MEMBER_EVENT_COHORT') }}
    where MONTHS_AFTER = 0
),
disp as (
    select
        f.MEMBER_DK,
        TO_DATE(TO_VARCHAR(f.DATE_SK), 'YYYYMMDD')     as SEND_DATE,
        f.SEND_REQUEST_SK,
        f.SEND_TYPE_SK,
        r.SEND_CHANNEL,
        r.SEND_FORMAT_NAME,
        t.ATMC_YN,
        f.SEND_TITLE,
        f.OPEN_MEMBERS,
        f.GA_CLICK_MEMBERS
    from {{ ref('FACT_MESSAGE_DISPATCH') }} f
    join {{ ref('DIM_SEND_REQUEST') }} r
      on r.SEND_REQUEST_SK = f.SEND_REQUEST_SK
    left join {{ ref('DIM_MSG_TEMPLATE') }} t
      on t.TEMPLATE_KEY = r.TMPLAT_ID
     and t.SEND_CHANNEL = r.SEND_CHANNEL
    where f.DATE_SK > 0
      and r.SEND_CHANNEL in ('MSG_AT', 'SND', 'EMAIL')
)

select
    e.EVENT_MONTH_KEY,
    e.MEMBER_DK,
    e.DVLP_DIV_CD,
    e.MONTHS_AFTER,
    d.SEND_DATE,
    DATEDIFF(day, e.EVENT_DATE, d.SEND_DATE)                       as DAYS_FROM_EVENT,
    CASE
        WHEN d.SEND_DATE < e.EVENT_DATE  THEN 'D-30~D-1'
        WHEN d.SEND_DATE = e.EVENT_DATE  THEN 'D0'
        ELSE 'D+1~D+5'
    END                                                             as SEND_WINDOW,
    d.SEND_REQUEST_SK,
    MAX(d.SEND_TYPE_SK)                                             as SEND_TYPE_SK,
    MAX(d.SEND_CHANNEL)                                             as SEND_CHANNEL,
    MAX(d.SEND_FORMAT_NAME)                                         as SEND_FORMAT_NAME,
    MAX(d.ATMC_YN)                                                  as ATMC_YN,
    MAX(d.SEND_TITLE)                                               as SEND_TITLE,
    COUNT(*)                                                        as SEND_ROWS,
    -- 오픈 2축(합치지 않는다) · 원천 판정 불가 = NULL(R2-7)
    MAX(d.OPEN_MEMBERS)                                             as SND_OPENED,
    MAX(d.GA_CLICK_MEMBERS)                                         as GA_CLICKED,
    {{ gold_meta('CRM') }}
from ev e
join disp d
  on d.MEMBER_DK = e.MEMBER_DK
 and d.SEND_DATE between e.EVENT_DATE - 30 and e.EVENT_DATE + 5
group by e.EVENT_MONTH_KEY, e.MEMBER_DK, e.DVLP_DIV_CD, e.MONTHS_AFTER, e.EVENT_DATE, d.SEND_DATE, d.SEND_REQUEST_SK
