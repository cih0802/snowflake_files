-- FACT_CAMPAIGN_MONTHLY: 기준연월 × 캠페인 × 납입방식 월 팩트 (캠페인별 활동율·중단율·이탈율·납입율·미납율 분자·분모)
-- Co-authored with CoCo
-- 🆕 [2026-10-16 O237-B · 사용자 결정 A = 후원건(후원사업) 캠페인 귀속 · FACT_CAMPAIGN_CUM_STOP 과 같은 규칙]
--   왜 새 팩트인가 = FACT_MEMBER_MONTHLY 의 CAMPAIGN_SK 는 「그 달 후원 캠페인 1개」일 때만 연결돼
--   중단의 58.3%가 미매핑이다(O236 실측) ⇒ 신규지표 #12~#16 · #19~#25 · #27~#28 을 캠페인별로 낼 수 없다.
--   🟢 대상 집합·판정식은 FMM 과 같다 — 캠페인·납입방식 축만 붙인다(월별 합 = FMM 합 · 대사 = 05_25b):
--     · 대상 = FMM (MONTH_KEY, MEMBER_DK) 스파인
--     · 활동(건)·전월말활동(건)·연도초활동(건) = FMSS span as-of SPNSR_AMT ÷ 10,000(FMM active_asof 와 같은 판정)
--     · 중단(건) = 그 달 중단 span SPNSR_AMT ÷ 10,000(FMM STOP_AMT_CNT 와 같은 식)
--       ⇒ 캠페인 = span 대표캠페인(FMSS CAMPAIGN_SK)
--     · 개발(건) = FME DEV_CNT ⇒ 캠페인 = 개발 사건 캠페인(FCCS 와 같다)
--     · 감액(건) = 금액변경 감액금액 ÷ 10,000(FMM DECREASE_CNT 와 같은 식) ⇒ 캠페인 = 금액변경 원천 CMPGN_CD
--     · 이탈(건) = 중단(건) + 감액(건)(FMM CHURN_CNT 와 같은 식)
--     · 납입회비·미납회비 = FACT_MEMBER_FEE(회원×월×후원사업) ⇒ 같은 회원×후원사업 span 중 그 달 유효 span 의 대표캠페인
--   🔴 납입방식(PAYMENT_SK) = 잠정(사용자 승인 2026-10-16 · 현업 확인 대상) — span 에는 납입방식이 없다:
--     · span 기반 measure = 그 달 같은 회원×후원사업 청구 행의 결제수단(청구액 최대 1개) → 없으면 회원×월 대표 결제수단 → 없으면 0
--     · 개발·감액(후원사업 키 없음) = 회원×월 대표 결제수단(그 달 청구액 최대) → 없으면 0
--   🔴 누계·연도초 = 기준월마다 as-of 값을 싣는다 ⇒ **기준월 하나를 고정**해 조회한다(여러 달 SUM 금지 · FMM 8.66배 함정).
--   🔴 비율은 저장하지 않는다 — SV 가 「합의 비」로 계산한다.


with spine as (
    select distinct MONTH_KEY, MEMBER_DK
    from GN_DW.GOLD.FACT_MEMBER_MONTHLY
    where MONTH_KEY > 0
),

span as (
    select MEMBER_DK, SPONSORSHIP_SK, CAMPAIGN_SK, START_MONTH_KEY, DSCNTC_MONTH_KEY, SPNSR_AMT
    from GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN
),

-- 회원×월×후원사업 결제수단(청구액 최대 1개) · 회원×월 대표 결제수단
fee as (
    select MONTH_KEY, MEMBER_DK, SPONSORSHIP_SK, PAYMENT_SK,
           SUM(BILLED_AMT) as BILLED_AMT, SUM(PAID_FEE_BILLABLE) as PAID_FEE_BILLABLE,
           SUM(UNPAID_BILLED_AMT) as UNPAID_BILLED_AMT
    from GN_DW.GOLD.FACT_MEMBER_FEE
    where MONTH_KEY > 0
    group by 1, 2, 3, 4
),
pay_biz as (
    select MONTH_KEY, MEMBER_DK, SPONSORSHIP_SK, PAYMENT_SK
    from fee
    qualify row_number() over (partition by MONTH_KEY, MEMBER_DK, SPONSORSHIP_SK
                               order by BILLED_AMT desc nulls last, PAYMENT_SK) = 1
),
pay_mem as (
    select MONTH_KEY, MEMBER_DK, PAYMENT_SK
    from (select MONTH_KEY, MEMBER_DK, PAYMENT_SK, SUM(BILLED_AMT) as B from fee group by 1, 2, 3)
    qualify row_number() over (partition by MONTH_KEY, MEMBER_DK order by B desc nulls last, PAYMENT_SK) = 1
),

-- span × 스파인 월 as-of(당월말 · 전월말 · 당월 중단)
span_month as (
    select
        sp.MONTH_KEY, sp.MEMBER_DK, sn.SPONSORSHIP_SK, sn.CAMPAIGN_SK,
        case when sn.DSCNTC_MONTH_KEY is null or sn.DSCNTC_MONTH_KEY > sp.MONTH_KEY
             then sn.SPNSR_AMT else 0 end                                   as ACTIVE_AMT,
        case when sn.START_MONTH_KEY <= CASE WHEN MOD(sp.MONTH_KEY, 100) BETWEEN 1 AND 12 AND sp.MONTH_KEY >= 100001 THEN TRY_TO_NUMBER(TO_CHAR(ADD_MONTHS(TRY_TO_DATE(TO_VARCHAR(sp.MONTH_KEY) || '01', 'YYYYMMDD'), -1),'YYYYMM')) END
              and (sn.DSCNTC_MONTH_KEY is null
                   or sn.DSCNTC_MONTH_KEY > CASE WHEN MOD(sp.MONTH_KEY, 100) BETWEEN 1 AND 12 AND sp.MONTH_KEY >= 100001 THEN TRY_TO_NUMBER(TO_CHAR(ADD_MONTHS(TRY_TO_DATE(TO_VARCHAR(sp.MONTH_KEY) || '01', 'YYYYMMDD'), -1),'YYYYMM')) END)
             then sn.SPNSR_AMT else 0 end                                   as PREV_ACTIVE_AMT,
        case when sn.DSCNTC_MONTH_KEY = sp.MONTH_KEY then sn.SPNSR_AMT else 0 end as STOP_AMT
    from spine sp
    join span sn
      on sn.MEMBER_DK = sp.MEMBER_DK
     and (sn.START_MONTH_KEY <= sp.MONTH_KEY or sn.DSCNTC_MONTH_KEY = sp.MONTH_KEY)
),
m_span as (
    select s.MONTH_KEY, s.CAMPAIGN_SK,
           COALESCE(pb.PAYMENT_SK, pm.PAYMENT_SK, 0)                        as PAYMENT_SK,
           SUM(s.ACTIVE_AMT) / 10000                                        as ACTIVE_CNT,
           SUM(s.PREV_ACTIVE_AMT) / 10000                                   as PREV_MONTH_END_ACTIVE_CNT,
           SUM(s.STOP_AMT) / 10000                                          as STOP_CNT
    from span_month s
    left join pay_biz pb on pb.MONTH_KEY = s.MONTH_KEY and pb.MEMBER_DK = s.MEMBER_DK
                        and pb.SPONSORSHIP_SK = s.SPONSORSHIP_SK
    left join pay_mem pm on pm.MONTH_KEY = s.MONTH_KEY and pm.MEMBER_DK = s.MEMBER_DK
    group by 1, 2, 3
),

-- 개발(FME 사건 캠페인 · FMM fme_rollup 과 같은 원천)
m_dev as (
    select FLOOR(e.DATE_SK / 100) as MONTH_KEY, e.CAMPAIGN_SK,
           COALESCE(pm.PAYMENT_SK, 0) as PAYMENT_SK, SUM(e.DEV_CNT) as DEV_CNT
    from GN_DW.GOLD.FACT_MEMBER_EVENT e
    left join pay_mem pm on pm.MONTH_KEY = FLOOR(e.DATE_SK / 100) and pm.MEMBER_DK = e.MEMBER_DK
    where e.DATE_SK > 0
    group by 1, 2, 3
),

-- 감액(FMM amt_month DEC_AMT 와 같은 식 · 캠페인 = 금액변경 원천 CMPGN_CD)
m_dec as (
    select a.MONTH_KEY, COALESCE(c.CAMPAIGN_SK, 0) as CAMPAIGN_SK,
           COALESCE(pm.PAYMENT_SK, 0) as PAYMENT_SK, SUM(a.DEC_AMT) / 10000 as DECREASE_CNT
    from (
        select COALESCE(CASE WHEN TRY_TO_NUMBER(SUBSTR(OCCRRNC_DE,1,6)) BETWEEN 194501 AND 214512 THEN TRY_TO_NUMBER(SUBSTR(OCCRRNC_DE,1,6)) END, 0) as MONTH_KEY,
               MBER_NO as MEMBER_DK, CMPGN_CD,
               -SUM(case when RDCAMT_YN = 'Y' and SPNSR_AMT < 0 then SPNSR_AMT else 0 end) as DEC_AMT
        from GN_DW.SILVER.CRM_MEMBER_AMT_CHANGE
        where MBER_NO is not null
        group by 1, 2, 3
    ) a
    join spine sp on sp.MONTH_KEY = a.MONTH_KEY and sp.MEMBER_DK = a.MEMBER_DK
    left join GN_DW.GOLD.DIM_CAMPAIGN c on c.CAMPAIGN_BK = a.CMPGN_CD
    left join pay_mem pm on pm.MONTH_KEY = a.MONTH_KEY and pm.MEMBER_DK = a.MEMBER_DK
    where a.DEC_AMT <> 0
    group by 1, 2, 3
),

-- 납입·미납회비(회원×월×후원사업 → 그 달 유효 span 의 대표캠페인 · 없으면 최근 시작 span · 없으면 0)
fee_campaign as (
    select f.MONTH_KEY, f.MEMBER_DK, f.SPONSORSHIP_SK, f.PAYMENT_SK, f.PAID_FEE_BILLABLE, f.UNPAID_BILLED_AMT,
           sn.CAMPAIGN_SK
    from fee f
    join spine sp on sp.MONTH_KEY = f.MONTH_KEY and sp.MEMBER_DK = f.MEMBER_DK
    left join span sn
      on sn.MEMBER_DK = f.MEMBER_DK
     and sn.SPONSORSHIP_SK = f.SPONSORSHIP_SK
     and sn.START_MONTH_KEY <= f.MONTH_KEY
    qualify row_number() over (
        partition by f.MONTH_KEY, f.MEMBER_DK, f.SPONSORSHIP_SK, f.PAYMENT_SK
        order by IFF(sn.DSCNTC_MONTH_KEY is null or sn.DSCNTC_MONTH_KEY > f.MONTH_KEY, 0, 1),
                 sn.START_MONTH_KEY desc nulls last, sn.CAMPAIGN_SK
    ) = 1
),
m_fee as (
    select MONTH_KEY, COALESCE(CAMPAIGN_SK, 0) as CAMPAIGN_SK, PAYMENT_SK,
           SUM(PAID_FEE_BILLABLE) as PAID_FEE_BILLABLE, SUM(UNPAID_BILLED_AMT) as UNPAID_BILLED_AMT
    from fee_campaign
    group by 1, 2, 3
),

monthly as (
    select MONTH_KEY, CAMPAIGN_SK, PAYMENT_SK,
           SUM(ACTIVE_CNT) as ACTIVE_CNT, SUM(PREV_MONTH_END_ACTIVE_CNT) as PREV_MONTH_END_ACTIVE_CNT,
           SUM(STOP_CNT) as STOP_CNT, SUM(DEV_CNT) as DEV_CNT, SUM(DECREASE_CNT) as DECREASE_CNT,
           SUM(PAID_FEE_BILLABLE) as PAID_FEE_BILLABLE, SUM(UNPAID_BILLED_AMT) as UNPAID_BILLED_AMT
    from (
        select MONTH_KEY, CAMPAIGN_SK, PAYMENT_SK, ACTIVE_CNT, PREV_MONTH_END_ACTIVE_CNT, STOP_CNT,
               0 as DEV_CNT, 0 as DECREASE_CNT, 0 as PAID_FEE_BILLABLE, 0 as UNPAID_BILLED_AMT from m_span
        union all
        select MONTH_KEY, CAMPAIGN_SK, PAYMENT_SK, 0, 0, 0, DEV_CNT, 0, 0, 0 from m_dev
        union all
        select MONTH_KEY, CAMPAIGN_SK, PAYMENT_SK, 0, 0, 0, 0, DECREASE_CNT, 0, 0 from m_dec
        union all
        select MONTH_KEY, CAMPAIGN_SK, PAYMENT_SK, 0, 0, 0, 0, 0, PAID_FEE_BILLABLE, UNPAID_BILLED_AMT from m_fee
    )
    group by 1, 2, 3
),

base_month as (
    select distinct MONTH_KEY as BASE_MONTH_KEY from spine
),

-- 기준월 M 의 누계 = 같은 해 1월 ~ M월 합(FCCS 와 같은 식)
cum as (
    select b.BASE_MONTH_KEY, mo.CAMPAIGN_SK, mo.PAYMENT_SK,
           SUM(mo.STOP_CNT)          as CUM_STOP_CNT,
           SUM(mo.DEV_CNT)           as CUM_DEV_CNT,
           SUM(mo.ACTIVE_CNT)        as CUM_ACTIVE_CNT,
           SUM(mo.PAID_FEE_BILLABLE) as CUM_PAID_FEE_BILLABLE
    from base_month b
    join monthly mo
      on FLOOR(mo.MONTH_KEY / 100) = FLOOR(b.BASE_MONTH_KEY / 100)
     and mo.MONTH_KEY <= b.BASE_MONTH_KEY
    group by 1, 2, 3
),

-- 연도초(YYYY01) as-of 활동 = 1월 스파인의 당월말 활동(FCCS y_start 와 같은 판정) → 같은 해 기준월마다 싣는다
y_start as (
    select FLOOR(MONTH_KEY / 100) as BASE_YEAR, CAMPAIGN_SK, PAYMENT_SK, ACTIVE_CNT as YEAR_START_ACTIVE_CNT
    from m_span
    where MOD(MONTH_KEY, 100) = 1
),
ys_by_month as (
    select b.BASE_MONTH_KEY, ys.CAMPAIGN_SK, ys.PAYMENT_SK, ys.YEAR_START_ACTIVE_CNT
    from base_month b
    join y_start ys on ys.BASE_YEAR = FLOOR(b.BASE_MONTH_KEY / 100)
),

keys as (
    select MONTH_KEY as BASE_MONTH_KEY, CAMPAIGN_SK, PAYMENT_SK from monthly
    union
    select BASE_MONTH_KEY, CAMPAIGN_SK, PAYMENT_SK from cum
    union
    select BASE_MONTH_KEY, CAMPAIGN_SK, PAYMENT_SK from ys_by_month
)

select
    k.BASE_MONTH_KEY,
    FLOOR(k.BASE_MONTH_KEY / 100)                   as BASE_YEAR,
    COALESCE(k.CAMPAIGN_SK, 0)                      as CAMPAIGN_SK,
    COALESCE(k.PAYMENT_SK, 0)                       as PAYMENT_SK,
    COALESCE(m.ACTIVE_CNT, 0)                       as ACTIVE_CNT,
    COALESCE(m.PREV_MONTH_END_ACTIVE_CNT, 0)        as PREV_MONTH_END_ACTIVE_CNT,
    COALESCE(y.YEAR_START_ACTIVE_CNT, 0)            as YEAR_START_ACTIVE_CNT,
    COALESCE(m.STOP_CNT, 0)                         as STOP_CNT,
    COALESCE(m.DEV_CNT, 0)                          as DEV_CNT,
    COALESCE(m.DECREASE_CNT, 0)                     as DECREASE_CNT,
    COALESCE(m.STOP_CNT, 0) + COALESCE(m.DECREASE_CNT, 0) as CHURN_CNT,
    COALESCE(m.PAID_FEE_BILLABLE, 0)                as PAID_FEE_BILLABLE,
    COALESCE(m.UNPAID_BILLED_AMT, 0)                as UNPAID_BILLED_AMT,
    COALESCE(c.CUM_STOP_CNT, 0)                     as CUM_STOP_CNT,
    COALESCE(c.CUM_DEV_CNT, 0)                      as CUM_DEV_CNT,
    COALESCE(c.CUM_ACTIVE_CNT, 0)                   as CUM_ACTIVE_CNT,
    COALESCE(c.CUM_PAID_FEE_BILLABLE, 0)            as CUM_PAID_FEE_BILLABLE,
    'CRM' AS DW_SOURCE_SYSTEM
from keys k
left join monthly m
  on m.MONTH_KEY = k.BASE_MONTH_KEY and m.CAMPAIGN_SK = k.CAMPAIGN_SK and m.PAYMENT_SK = k.PAYMENT_SK
left join cum c
  on c.BASE_MONTH_KEY = k.BASE_MONTH_KEY and c.CAMPAIGN_SK = k.CAMPAIGN_SK and c.PAYMENT_SK = k.PAYMENT_SK
left join ys_by_month y
  on y.BASE_MONTH_KEY = k.BASE_MONTH_KEY and y.CAMPAIGN_SK = k.CAMPAIGN_SK and y.PAYMENT_SK = k.PAYMENT_SK