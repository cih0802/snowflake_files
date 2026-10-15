-- FACT_CAMPAIGN_CUM_STOP: 기준연월 × 캠페인 누계 중단·개발·연도초활동 팩트 (캠페인별 누계중단율 신규 #17 분자·분모)
-- Co-authored with CoCo
-- 🆕 [2026-10-15 O236 · 사용자 결정 A = 후원건(후원사업)의 캠페인 귀속]
--   왜 새 팩트인가 = FACT_MEMBER_MONTHLY(회원×월)는 ① YEAR_START_ACTIVE_CNT 를 매달 행에 반복해
--   1~M월 SUM 이 연도초를 M배로 부풀리고(jw08094 2026-01~09 실측 8.66배) ② CAMPAIGN_SK 가
--   「그 달 후원 캠페인 1개」일 때만 연결돼 중단의 58.3%가 미매핑이다 ⇒ 누계 산식을 그 SV 로 낼 수 없다.
--   🟢 산식·원천·대상 집합은 FMM 과 같다 — 캠페인 축만 후원건 기준으로 바꾼다:
--     · 대상 집합 = FMM 의 (MONTH_KEY, MEMBER_DK) 스파인(청구 ∪ 개발 이력) — FMM 과 합계가 일치해야 한다
--     · 중단 = 그 달 중단된 후원사업 SPNSR_AMT ÷ 10,000(FMM stop_amt 와 같은 식) · 캠페인 = 후원사업 대표캠페인
--     · 연도초 = 그 해 1월 as-of 활동 후원사업 SPNSR_AMT ÷ 10,000(FMM active_asof 와 같은 판정) · 캠페인 = 후원사업 대표캠페인
--     · 개발 = FACT_MEMBER_EVENT DEV_CNT(MSTR 인정금액 ÷ 10,000) · 캠페인 = 개발 사건의 캠페인
--   🔴 중단·연도초의 캠페인(FMSS 대표캠페인)과 개발의 캠페인(FME 사건 캠페인)은 다른 규칙이다 — 값이 갈릴 수 있다.
--   🔴 비율은 저장하지 않는다 — SV 가 「합의 비」로 계산한다(캠페인 합산·상위 축 롤업이 맞게 된다).
--   🔴 누계 grain 이다 — 기준월 하나를 골라 조회한다. 여러 기준월을 SUM 하면 누계가 겹쳐 커진다.
{{ config(
    tags=['gold_ready']
) }}

with spine as (
    select distinct MONTH_KEY, MEMBER_DK
    from {{ ref('FACT_MEMBER_MONTHLY') }}
    where MONTH_KEY > 0
),

span as (
    select MEMBER_DK, CAMPAIGN_SK, START_MONTH_KEY, DSCNTC_MONTH_KEY, SPNSR_AMT
    from {{ ref('FACT_MEMBER_SPONSORSHIP_SPAN') }}
),

-- 월 × 캠페인 중단(FMM stop_amt 와 같은 식 · 스파인에 있는 회원×월만)
m_stop as (
    select sp.MONTH_KEY, sn.CAMPAIGN_SK, SUM(sn.SPNSR_AMT) / 10000 as STOP_CNT
    from spine sp
    join span sn
      on sn.MEMBER_DK = sp.MEMBER_DK
     and sn.DSCNTC_MONTH_KEY = sp.MONTH_KEY
    group by 1, 2
),

-- 월 × 캠페인 개발(FMM fme_rollup 과 같은 원천 · 개발 사건의 캠페인)
m_dev as (
    select FLOOR(DATE_SK / 100) as MONTH_KEY, CAMPAIGN_SK, SUM(DEV_CNT) as DEV_CNT
    from {{ ref('FACT_MEMBER_EVENT') }}
    where DATE_SK > 0
    group by 1, 2
),

-- 연도 × 캠페인 연도초(YYYY01) as-of 활동(FMM active_asof YEAR_START_BIZ_AMT 와 같은 판정 · 1월 스파인만)
y_start as (
    select FLOOR(sp.MONTH_KEY / 100) as BASE_YEAR, sn.CAMPAIGN_SK, SUM(sn.SPNSR_AMT) / 10000 as YEAR_START_ACTIVE_CNT
    from spine sp
    join span sn
      on sn.MEMBER_DK = sp.MEMBER_DK
     and sn.START_MONTH_KEY <= sp.MONTH_KEY
     and (sn.DSCNTC_MONTH_KEY is null or sn.DSCNTC_MONTH_KEY > sp.MONTH_KEY)
    where MOD(sp.MONTH_KEY, 100) = 1
    group by 1, 2
),

monthly as (
    select MONTH_KEY, CAMPAIGN_SK, STOP_CNT, 0 as DEV_CNT from m_stop
    union all
    select MONTH_KEY, CAMPAIGN_SK, 0 as STOP_CNT, DEV_CNT from m_dev
),

base_month as (
    select distinct MONTH_KEY as BASE_MONTH_KEY from spine
),

-- 기준월 M 의 누계 = 같은 해 1월 ~ M월 합
cum as (
    select b.BASE_MONTH_KEY, mo.CAMPAIGN_SK,
           SUM(mo.STOP_CNT) as CUM_STOP_CNT,
           SUM(mo.DEV_CNT)  as CUM_DEV_CNT
    from base_month b
    join monthly mo
      on FLOOR(mo.MONTH_KEY / 100) = FLOOR(b.BASE_MONTH_KEY / 100)
     and mo.MONTH_KEY <= b.BASE_MONTH_KEY
    group by 1, 2
),

ys_by_month as (
    select b.BASE_MONTH_KEY, ys.CAMPAIGN_SK, ys.YEAR_START_ACTIVE_CNT
    from base_month b
    join y_start ys on ys.BASE_YEAR = FLOOR(b.BASE_MONTH_KEY / 100)
)

select
    COALESCE(c.BASE_MONTH_KEY, y.BASE_MONTH_KEY)                as BASE_MONTH_KEY,
    FLOOR(COALESCE(c.BASE_MONTH_KEY, y.BASE_MONTH_KEY) / 100)   as BASE_YEAR,
    COALESCE(c.CAMPAIGN_SK, y.CAMPAIGN_SK, 0)                   as CAMPAIGN_SK,
    COALESCE(c.CUM_STOP_CNT, 0)                                 as CUM_STOP_CNT,
    COALESCE(c.CUM_DEV_CNT, 0)                                  as CUM_DEV_CNT,
    COALESCE(y.YEAR_START_ACTIVE_CNT, 0)                        as YEAR_START_ACTIVE_CNT,
    {{ gold_meta('CRM') }}
from cum c
full outer join ys_by_month y
  on y.BASE_MONTH_KEY = c.BASE_MONTH_KEY
 and y.CAMPAIGN_SK = c.CAMPAIGN_SK
