-- FACT_AD_INFLOW_ALLOC: 월 × 마케팅캠페인 × 개발인입경로 광고비 배분 팩트 (인입경로별 개발단가)
-- Co-authored with CoCo
-- 🆕 [2026-10-20 O248 · 사용자 결정 = 원천 구분자 1차 매핑 + 개발(건) 비중 배분]
--   왜 새 팩트인가 = 광고비(AGENCY)는 마케팅캠페인 grain 이고 인입경로가 없다. 한 마케팅캠페인 아래
--   개발인입경로가 97.2% 다중이라(DIM_MARKETING_CAMPAIGN O225-C 실측) 대표값을 붙이면 왜곡된다.
--   대신 광고원천(AD_SOURCE_TYPE)이 인입경로와 강하게 대응한다(O248 실측 2025-01~2026-09 CRM 개발(건)):
--     · DIGITAL 단독 캠페인 → 디지털 97.1% · 뉴미디어 2.2%
--     · REBROADCAST 단독 → 재송출 55.6% · 방송 43.3%
--     · VIDEO 단독 → 콜개발 45.1% · 디지털 41.0% · 영상광고 9.7% (방송 시청 → 전화·웹 후원)
--   ⇒ 원천별 허용 경로(src_map) 안에서만, 같은 월 · 마케팅캠페인의 개발(건) 비중으로 광고비를 나눈다.
--   🔴 VIDEO 허용 경로(영상광고·방송·콜개발·디지털)는 **현업 확인 전 가정**이다(사용자 결정 2026-10-20).
--   🔴 버리지 않는다: 배분할 개발이 없는 광고비는 ROW_KIND = 'UNALLOC' 으로 남긴다(합계 보존 = assert_faia_ad_cost_preserved).
--   🔴 DEV_CNT 는 인입경로 행에 한 번만 싣는다 — 원천별 광고비는 컬럼으로 펼쳐 원천 간 개발 중복 계상을 막는다.
--   매핑을 바꿀 때는 이 파일의 src_map 만 고친다(정의 지점 1곳).
{{ config(
    tags=['gold_ready']
) }}

with src_map as (
    select * from values
        ('DIGITAL',     '디지털'),
        ('DIGITAL',     '뉴미디어'),
        ('REBROADCAST', '재송출'),
        ('REBROADCAST', '방송'),
        ('VIDEO',       '영상광고'),
        ('VIDEO',       '방송'),
        ('VIDEO',       '콜개발'),
        ('VIDEO',       '디지털')
        as t(AD_SOURCE_TYPE, INFLOW_PATH)
),

ad as (
    select
        FLOOR(PERF_DATE_SK / 100)          as MONTH_KEY,
        COALESCE(MKTG_CAMPAIGN_SK, 0)      as MKTG_CAMPAIGN_SK,
        AD_SOURCE_TYPE,
        SUM(AD_COST)                       as AD_COST
    from {{ ref('FACT_AD_PERFORMANCE') }}
    where PERF_DATE_SK > 0
    group by 1, 2, 3
),

-- 개발(건) = FME DEV_CNT(MSTR 정의) · 마케팅캠페인 = 사건 시점 코드 → conformed SK(코드 조인 실측 100%)
dev as (
    select
        FLOOR(f.DATE_SK / 100)             as MONTH_KEY,
        m.MKTG_CAMPAIGN_SK,
        f.MBER_INFLOW_PATH_NM_AT_EVENT     as INFLOW_PATH,
        SUM(f.DEV_CNT)                     as DEV_CNT
    from {{ ref('FACT_MEMBER_EVENT') }} f
    join {{ ref('DIM_MARKETING_CAMPAIGN') }} m
      on TO_VARCHAR(m.MKTG_CAMPAIGN_BK) = TO_VARCHAR(f.MKTG_CMPGN_CD_AT_EVENT)
    where f.EVENT_TYPE = 'DEV'
      and f.DATE_SK > 0
    group by 1, 2, 3
    having SUM(f.DEV_CNT) > 0
),

-- 허용 경로에 개발이 있는 (월 · 캠페인 · 원천 · 경로)
base as (
    select a.MONTH_KEY, a.MKTG_CAMPAIGN_SK, a.AD_SOURCE_TYPE, a.AD_COST, d.INFLOW_PATH, d.DEV_CNT
    from ad a
    join src_map s
      on s.AD_SOURCE_TYPE = a.AD_SOURCE_TYPE
    join dev d
      on d.MONTH_KEY = a.MONTH_KEY
     and d.MKTG_CAMPAIGN_SK = a.MKTG_CAMPAIGN_SK
     and d.INFLOW_PATH = s.INFLOW_PATH
    where a.MKTG_CAMPAIGN_SK <> 0
),

alloc as (
    select
        MONTH_KEY, MKTG_CAMPAIGN_SK, INFLOW_PATH, AD_SOURCE_TYPE,
        AD_COST * DEV_CNT / SUM(DEV_CNT) over (partition by MONTH_KEY, MKTG_CAMPAIGN_SK, AD_SOURCE_TYPE) as ALLOC_COST
    from base
),

alloc_by_path as (
    select
        MONTH_KEY, MKTG_CAMPAIGN_SK, INFLOW_PATH,
        SUM(IFF(AD_SOURCE_TYPE = 'DIGITAL',     ALLOC_COST, 0)) as AD_COST_DIGITAL,
        SUM(IFF(AD_SOURCE_TYPE = 'VIDEO',       ALLOC_COST, 0)) as AD_COST_VIDEO,
        SUM(IFF(AD_SOURCE_TYPE = 'REBROADCAST', ALLOC_COST, 0)) as AD_COST_REBROADCAST
    from alloc
    group by 1, 2, 3
),

-- 광고를 집행한 (월 · 캠페인)의 개발 전 경로 — 허용 경로면 ALLOC, 아니면 NOT_ALLOWED(광고비 0)
ad_mk as (
    select distinct MONTH_KEY, MKTG_CAMPAIGN_SK from ad where MKTG_CAMPAIGN_SK <> 0
),

dev_in_ad as (
    select d.*
    from dev d
    join ad_mk k
      on k.MONTH_KEY = d.MONTH_KEY
     and k.MKTG_CAMPAIGN_SK = d.MKTG_CAMPAIGN_SK
),

path_rows as (
    select
        d.MONTH_KEY, d.MKTG_CAMPAIGN_SK, d.INFLOW_PATH,
        IFF(p.INFLOW_PATH is not null, 'ALLOC', 'NOT_ALLOWED')       as ROW_KIND,
        CAST(NULL AS VARCHAR)                                        as UNALLOC_REASON,
        COALESCE(p.AD_COST_DIGITAL, 0)                               as AD_COST_DIGITAL,
        COALESCE(p.AD_COST_VIDEO, 0)                                 as AD_COST_VIDEO,
        COALESCE(p.AD_COST_REBROADCAST, 0)                           as AD_COST_REBROADCAST,
        d.DEV_CNT
    from dev_in_ad d
    left join alloc_by_path p
      on p.MONTH_KEY = d.MONTH_KEY
     and p.MKTG_CAMPAIGN_SK = d.MKTG_CAMPAIGN_SK
     and p.INFLOW_PATH = d.INFLOW_PATH
),

-- 배분할 개발이 없는 광고비(버리지 않는다)
unalloc as (
    select
        a.MONTH_KEY, a.MKTG_CAMPAIGN_SK,
        CAST(NULL AS VARCHAR)                                        as INFLOW_PATH,
        'UNALLOC'                                                    as ROW_KIND,
        IFF(a.MKTG_CAMPAIGN_SK = 0, 'UNMAPPED_CAMPAIGN', 'NO_ALLOWED_DEV') as UNALLOC_REASON,
        SUM(IFF(a.AD_SOURCE_TYPE = 'DIGITAL',     a.AD_COST, 0))     as AD_COST_DIGITAL,
        SUM(IFF(a.AD_SOURCE_TYPE = 'VIDEO',       a.AD_COST, 0))     as AD_COST_VIDEO,
        SUM(IFF(a.AD_SOURCE_TYPE = 'REBROADCAST', a.AD_COST, 0))     as AD_COST_REBROADCAST,
        CAST(NULL AS NUMBER(18,4))                                   as DEV_CNT
    from ad a
    where not exists (
        select 1 from base b
        where b.MONTH_KEY = a.MONTH_KEY
          and b.MKTG_CAMPAIGN_SK = a.MKTG_CAMPAIGN_SK
          and b.AD_SOURCE_TYPE = a.AD_SOURCE_TYPE
    )
    group by 1, 2, 3, 4, 5
),

unioned as (
    select * from path_rows
    union all
    select * from unalloc
)

select
    MONTH_KEY,
    MKTG_CAMPAIGN_SK,
    INFLOW_PATH,
    ROW_KIND,
    UNALLOC_REASON,
    AD_COST_DIGITAL,
    AD_COST_VIDEO,
    AD_COST_REBROADCAST,
    AD_COST_DIGITAL + AD_COST_VIDEO + AD_COST_REBROADCAST        as AD_COST_ALLOC,
    DEV_CNT,
    {{ gold_meta('AGENCY') }}
from unioned
