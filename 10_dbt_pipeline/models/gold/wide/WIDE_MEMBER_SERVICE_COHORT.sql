-- WIDE_MEMBER_SERVICE_COHORT: 서비스 수신 코호트 — 회원(획득 코호트) × 서비스그룹 × 수신연도
-- Co-authored with CoCo
-- [2026-10-07 O205] 신설 · 2차 Agent 개선(`12_agent개선과제/00_작업계획.md` §8 B).
--
-- 🔴 왜 필요한가
--   회원실 질문(수신/미수신 회원의 이벤트 참여율 · 발송 후 5일 내 중단자의 특성 · 수신회원 유지기간)은
--   발송(FACT_MESSAGE_DISPATCH) · 획득 코호트(DIM_MEMBER_ACQUISITION) · 중단(FACT_MEMBER_EVENT) ·
--   행사 참여(FACT_EVENT_ATTENDANCE)를 **회원 단위로** 이어야 한다. SV 끼리는 교차결합이 금지라
--   Agent 가 답하지 못했다 ⇒ 결합을 이 뷰 안에서 끝내고 SV 1개로 노출한다(신규 원천 없음).
--
-- 🔴 grain
--   · 수신 행   = 회원 × 서비스그룹 × 수신연도(그 해에 그 그룹 발송을 1회 이상 받음)
--   · 미수신 행 = 회원 × 서비스그룹 1행(RECEIVE_YEAR = NULL · RECEIVED_FLAG = FALSE)
--     ⇒ 미수신 모집단 = DIM_MEMBER_ACQUISITION 회원(획득 코호트) 중 그 그룹을 한 번도 받지 않은 회원.
--   🔴 한 회원이 여러 해에 받으면 연도마다 행이 생긴다 ⇒ 연도를 고정하지 않은 회원수는 반드시 COUNT DISTINCT.
--
-- 🔴🔴 서비스그룹 규칙(rules CTE)은 **현업 확인 대기 초안**이다
--   발송 제목은 자유 텍스트(제목 34,549종 · O205 실측)라 「개별화서비스신규(사단)」 같은 업무 서비스명과
--   1:1 이 아니다. 아래 패턴은 회원실 질문에 나온 서비스를 제목 부분일치로 묶은 **임시 규칙**이며
--   현업이 서비스명 ↔ 제목 목록을 확정하면 이 CTE 만 교체한다(문서20 등재 대상).
--   · 한 제목이 여러 패턴에 맞으면 여러 그룹에 모두 들어간다(그룹 간 합산 금지).
--
-- 🔴 「효과」는 이 뷰가 정의하지 않는다 — 수신·미수신 비교는 단순 차이이며 인과가 아니다(대조군 규칙 현업 대기).
-- ⚠️ 캠페인행사(CRMN) 참여는 FEA.DATE_SK 가 1970 계열로 깨져 있어(O205 실측) 날짜 조건 없이 총계만 싣는다.
-- 🔴 컬럼 COMMENT 정본 = `_wide_schema.yml` columns[] — SELECT 컬럼 추가·순서 변경 시 함께 고친다(gn_view_commented).
{{ config(
    materialized='gn_view_commented',
    tags=['gold_ready']
) }}

with rules as (
    select * from values
        ('SNG_INSTANT',        '선넘는좋은일 신규 즉시', '%선넘는좋은일%'),
        ('PERSONAL_NEW_SADAN', '개별화 신규(사단)',     '%개별화%신규%사단%'),
        ('LUCKY_CARD',         '행운의 카드',          '%행운의 카드%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       '%장기회원%'),
        -- [O205-B] 2026 년 제목에서 「장기회원」이 빠졌다(「사복_2026 굿네이버스 N년 회원 감사서비스」 · BRONZE 서비스코드 MS0505/0201 실측)
        --   ⇒ 패턴 3개 보강 · 2026 수신 회원 2,278 → 161,967 (2024·2025 는 변동 없음)
        ('LONGTERM_THANKS',    '장기회원 서비스',       '%년%회원%감사%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       '%년 회원서비스%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       '%년 감사서비스%')
    as t(SERVICE_GROUP_CD, SERVICE_GROUP_NAME, TITLE_PATTERN)
),
grp as (
    select distinct SERVICE_GROUP_CD, SERVICE_GROUP_NAME from rules
),
disp as (
    select
        f.MEMBER_DK,
        r.SERVICE_GROUP_CD,
        d.FULL_DATE                                 as SEND_DATE,
        f.D5_STOP_MEMBERS,
        f.D5_INCREASE_PART_MEMBERS
    from {{ ref('FACT_MESSAGE_DISPATCH') }} f
    join rules r                       on f.SEND_TITLE ilike r.TITLE_PATTERN
    join {{ ref('DIM_DATE') }} d       on d.DATE_SK = f.DATE_SK
),
rcv as (
    select
        MEMBER_DK,
        SERVICE_GROUP_CD,
        YEAR(SEND_DATE)                             as RECEIVE_YEAR,
        MIN(SEND_DATE)                              as FIRST_RECEIVE_DATE,
        MAX(SEND_DATE)                              as LAST_RECEIVE_DATE,
        COUNT(DISTINCT SEND_DATE)                   as RECEIVE_ROWS,  -- [O205-B] 수신일 수 · 한 제목이 같은 그룹 패턴 여럿에 맞아도 중복되지 않는다
        MAX(IFF(D5_STOP_MEMBERS > 0, 1, 0)) = 1     as D5_STOP_FLAG,
        MAX(IFF(D5_INCREASE_PART_MEMBERS > 0, 1, 0)) = 1 as D5_INCREASE_FLAG
    from disp
    group by 1, 2, 3
),
-- 발송 다음날~+5일(D+1~D+5) 안의 첫 중단 사건 — D5 매칭과 같은 시간창(당일 제외 · O183)
d5_stop as (
    select
        x.MEMBER_DK,
        x.SERVICE_GROUP_CD,
        x.RECEIVE_YEAR,
        ed.FULL_DATE                                as D5_STOP_DATE,
        e.STOP_REASON_NM                            as D5_STOP_REASON,
        e.STOP_CHANNEL_NM                           as D5_STOP_CHANNEL,
        sp.SPONSORSHIP_NAME                         as D5_STOP_SPONSORSHIP
    from (select distinct MEMBER_DK, SERVICE_GROUP_CD, YEAR(SEND_DATE) as RECEIVE_YEAR, SEND_DATE from disp) x
    join {{ ref('FACT_MEMBER_EVENT') }} e
      on e.MEMBER_DK = x.MEMBER_DK
     and e.EVENT_TYPE = 'STOP'
    join {{ ref('DIM_DATE') }} ed      on ed.DATE_SK = e.DATE_SK
    left join {{ ref('DIM_SPONSORSHIP') }} sp on sp.SPONSORSHIP_SK = e.SPONSORSHIP_SK
    where ed.FULL_DATE between DATEADD('day', 1, x.SEND_DATE) and DATEADD('day', 5, x.SEND_DATE)
    qualify ROW_NUMBER() over (partition by x.MEMBER_DK, x.SERVICE_GROUP_CD, x.RECEIVE_YEAR
                               order by ed.FULL_DATE, e.STOP_REASON_NM) = 1
),
spine as (
    select a.MEMBER_DK, g.SERVICE_GROUP_CD
    from {{ ref('DIM_MEMBER_ACQUISITION') }} a
    cross join grp g
),
base as (
    select
        COALESCE(r.MEMBER_DK, s.MEMBER_DK)          as MEMBER_DK,
        COALESCE(r.SERVICE_GROUP_CD, s.SERVICE_GROUP_CD) as SERVICE_GROUP_CD,
        r.RECEIVE_YEAR,
        r.MEMBER_DK is not null                     as RECEIVED_FLAG,
        r.FIRST_RECEIVE_DATE,
        r.LAST_RECEIVE_DATE,
        COALESCE(r.RECEIVE_ROWS, 0)                 as RECEIVE_ROWS,
        COALESCE(r.D5_STOP_FLAG, false)             as D5_STOP_FLAG,
        COALESCE(r.D5_INCREASE_FLAG, false)         as D5_INCREASE_FLAG
    from spine s
    full outer join rcv r
      on r.MEMBER_DK = s.MEMBER_DK
     and r.SERVICE_GROUP_CD = s.SERVICE_GROUP_CD
),
ev as (
    select
        a.MEMBER_DK,
        a.EVENT_KIND,
        d.FULL_DATE                                 as PART_DATE
    from {{ ref('FACT_EVENT_ATTENDANCE') }} a
    left join {{ ref('DIM_DATE') }} d  on d.DATE_SK = a.DATE_SK
),
ev_agg as (
    select
        b.MEMBER_DK,
        b.SERVICE_GROUP_CD,
        b.RECEIVE_YEAR,
        COUNT_IF(v.EVENT_KIND = 'EVENT')            as GENERAL_EVENT_PART_ROWS,
        COUNT_IF(v.EVENT_KIND = 'EVENT' and v.PART_DATE >= b.FIRST_RECEIVE_DATE) as GENERAL_EVENT_PART_ROWS_AFTER,
        COUNT_IF(v.EVENT_KIND = 'CRMN')             as CAMPAIGN_EVENT_PART_ROWS
    from base b
    join ev v on v.MEMBER_DK = b.MEMBER_DK
    group by 1, 2, 3
)
select
    b.MEMBER_DK,
    b.SERVICE_GROUP_CD,
    g.SERVICE_GROUP_NAME,
    b.RECEIVE_YEAR,
    b.RECEIVED_FLAG,
    b.FIRST_RECEIVE_DATE,
    b.LAST_RECEIVE_DATE,
    b.RECEIVE_ROWS,
    b.D5_STOP_FLAG,
    b.D5_INCREASE_FLAG,
    ds.D5_STOP_DATE,
    ds.D5_STOP_REASON,
    ds.D5_STOP_CHANNEL,
    ds.D5_STOP_SPONSORSHIP,
    -- [O205-B] 중단(STOP) 사건 행은 원천 구조상 SPNSR_AMT·JOIN_DATE 가 전건 NULL 이다(2025~ 237,965행 실측)
    --   ⇒ 후원금액 컬럼은 두지 않고(획득 시점 ACQ_SPNSR_AMT 를 쓴다) 후원기간은 획득일 → D5 중단일로 계산한다.
    DATEDIFF('day', acq_d.FULL_DATE, ds.D5_STOP_DATE) as D5_STOP_SPONSOR_DAYS,
    -- ── 획득 코호트 축 (DIM_MEMBER_ACQUISITION · 획득 시점 동결값) ───────────────
    acq_d.FULL_DATE                                 as ACQ_DATE,
    YEAR(acq_d.FULL_DATE)                           as ACQ_YEAR,
    FLOOR(acq.ACQ_DATE_SK / 100)                    as ACQ_MONTH_KEY,
    acq.ACQ_CAMPAIGN_NAME,
    -- 🔴 「선넘는좋은일 캠페인 가입」은 캠페인명이 아니라 상위캠페인명(2026_통합_전체사업_선넘는좋은일)에 있다(O205 실측)
    acq.ACQ_PARENT_CAMPAIGN_NAME,
    acq.ACQ_CAMPAIGN_TYPE,
    acq.ACQ_INFLOW_PATH,
    acq.ACQ_MARKETING_CAMPAIGN,
    acq.ACQ_BRAND,
    acq.ACQ_CPR_DIV_NM,
    acq.ACQ_SPONSORSHIP_NAME,
    acq.ACQ_AGE_BAND,
    acq.ACQ_REGION,
    acq.ACQ_GENDER,
    acq.ACQ_SPNSR_AMT,
    acq.TENURE_DAYS,
    acq.FIRST_STOP_DATE_SK is not null and acq.FIRST_STOP_DATE_SK > 0 as EVER_STOPPED_FLAG,
    acq.FIRST_STOP_REASON_NM,
    -- ── 행사 참여 (FACT_EVENT_ATTENDANCE · 참여 기록 행 수) ──────────────────────
    COALESCE(v.GENERAL_EVENT_PART_ROWS, 0)          as GENERAL_EVENT_PART_ROWS,
    v.GENERAL_EVENT_PART_ROWS_AFTER                 as GENERAL_EVENT_PART_ROWS_AFTER,
    COALESCE(v.CAMPAIGN_EVENT_PART_ROWS, 0)         as CAMPAIGN_EVENT_PART_ROWS
from base b
join grp g                                    on g.SERVICE_GROUP_CD = b.SERVICE_GROUP_CD
left join d5_stop ds
  on ds.MEMBER_DK = b.MEMBER_DK
 and ds.SERVICE_GROUP_CD = b.SERVICE_GROUP_CD
 and ds.RECEIVE_YEAR = b.RECEIVE_YEAR
left join {{ ref('DIM_MEMBER_ACQUISITION') }} acq on acq.MEMBER_DK = b.MEMBER_DK
left join {{ ref('DIM_DATE') }} acq_d         on acq_d.DATE_SK = acq.ACQ_DATE_SK
left join ev_agg v
  on v.MEMBER_DK = b.MEMBER_DK
 and v.SERVICE_GROUP_CD = b.SERVICE_GROUP_CD
 and v.RECEIVE_YEAR is not distinct from b.RECEIVE_YEAR
