-- FACT_MEMBER_EVENT_COHORT: 개발사건(회원 × 사건월 × 개발구분) × 경과월(0~12) 코호트 팩트
-- Co-authored with CoCo
-- 🆕 [2026-10-20 O248 · 사용자 결정 = 「개발 사건을 기준으로 한 코호트 팩트 하나」 · 회원 Agent 전용]
--   왜 새 팩트인가 = 회원 Agent 도구는 SV 마다 따로 집계돼 회원 단위로 서로 결합할 수 없다
--   (예: 증액회원 × 이후 회비·중단 · 신규 → 이후 증액 · 개발 당일 알림톡). 특성마다 뷰를 늘리지 않도록
--   grain 을 「개발 사건」으로 잡고 개발구분(신규·증액·재후원·감액·후원중단)은 필터로 고른다.
--   · 코호트 키 = 회원 × 사건월 × 개발구분(FME 는 사건 키가 유일하지 않다 — 2022~ 156만 행 · 키 149만)
--   · 사건 시점 속성 = 그 달 그 개발구분 **첫 사건**(동률 = 후원금액 큰 것)의 FME 동결값
--   · 관측월 지표 = FACT_MEMBER_MONTHLY(회원 × 월 유일)의 같은 값 · FMM 행이 없는 관측 가능 월 = 0/FALSE
--   · 후속 개발 = 같은 회원의 이후 1~12개월 사건(FME) 첫 발생 경과월
--   · 발송 = 첫 사건일 기준 D-30~D+5 · 알림톡 자동/수동 = 템플릿 ATMC_YN(Y = 자동 트리거 · N = 수동·캠페인)
--     🔴 채널 적재 시작 전 사건은 발송 플래그를 NULL 로 둔다(「안 보냈다」가 아니라 「모른다」 · R2-7)
--     🔴 오픈은 문자(SND) 링크 클릭만 원천에 있다 — 알림톡·메일·우편 오픈 컬럼을 만들지 않는다
--   🔴 대상 = billing_coverage_start_month 이후 사건(회비원장 적재 구간과 맞춘다).
--   🔴 소비 규칙 = 개발구분 하나 · 경과월 하나를 고정해 센다(경과월 SUM 은 회원 중복 계상).
{{ config(
    tags=['gold_ready']
) }}

{% set start_dk = var('billing_coverage_start_month') ~ '01' %}

with ev_rows as (
    select
        MEMBER_DK,
        FLOOR(DATE_SK / 100)                          as EVENT_MONTH_KEY,
        DVLP_DIV_CD,
        DVLP_DIV_NM,
        DATE_SK,
        DEV_CNT,
        SPNSR_AMT,
        CAMPAIGN_SK,
        SPONSORSHIP_SK,
        MKTG_CMPGN_NM_AT_EVENT,
        MBER_INFLOW_PATH_NM_AT_EVENT,
        CMPGN_CTGR_NM_AT_EVENT,
        AGE_BAND_AT_EVENT,
        GENDER_AT_EVENT,
        CPR_DIV_NM_AT_EVENT,
        NEW_EXISTING_FLAG,
        JOIN_DATE,
        row_number() over (
            partition by MEMBER_DK, FLOOR(DATE_SK / 100), DVLP_DIV_CD
            order by DATE_SK, SPNSR_AMT desc nulls last
        )                                             as RN,
        count(*) over (partition by MEMBER_DK, FLOOR(DATE_SK / 100), DVLP_DIV_CD)          as EVENT_ROWS,
        SUM(DEV_CNT) over (partition by MEMBER_DK, FLOOR(DATE_SK / 100), DVLP_DIV_CD)      as EVENT_DEV_CNT,
        SUM(SPNSR_AMT) over (partition by MEMBER_DK, FLOOR(DATE_SK / 100), DVLP_DIV_CD)    as EVENT_SPNSR_AMT
    from {{ ref('FACT_MEMBER_EVENT') }}
    where EVENT_TYPE = 'DEV'
      and DATE_SK >= {{ start_dk }}
      and DVLP_DIV_CD is not null
),

ev as (
    select
        *,
        DATE_SK                                        as FIRST_EVENT_DATE_SK,
        TO_DATE(TO_VARCHAR(DATE_SK), 'YYYYMMDD')       as EVENT_DATE,
        TO_DATE(TO_VARCHAR(EVENT_MONTH_KEY) || '01', 'YYYYMMDD') as EVENT_MONTH_START
    from ev_rows
    where RN = 1
),

-- 후속 개발: 같은 회원의 이후 1~12개월 첫 발생(코호트 키 단위로 이미 축약된 ev 끼리 비교)
follow as (
    select
        a.MEMBER_DK, a.EVENT_MONTH_KEY, a.DVLP_DIV_CD,
        MIN(IFF(b.DVLP_DIV_CD = {{ gn_code('DEV_INCREASE') }}, DATEDIFF(month, a.EVENT_MONTH_START, b.EVENT_MONTH_START), NULL)) as FIRST_INC_MONTHS_AFTER,
        MIN(IFF(b.DVLP_DIV_CD = {{ gn_code('DEV_REDONATE') }}, DATEDIFF(month, a.EVENT_MONTH_START, b.EVENT_MONTH_START), NULL)) as FIRST_REDON_MONTHS_AFTER,
        MIN(IFF(b.DVLP_DIV_CD = {{ gn_code('DEV_DECREASE') }}, DATEDIFF(month, a.EVENT_MONTH_START, b.EVENT_MONTH_START), NULL)) as FIRST_DEC_MONTHS_AFTER,
        MIN(IFF(b.DVLP_DIV_CD = {{ gn_code('DEV_STOP') }},     DATEDIFF(month, a.EVENT_MONTH_START, b.EVENT_MONTH_START), NULL)) as FIRST_STOP_MONTHS_AFTER
    from ev a
    join ev b
      on b.MEMBER_DK = a.MEMBER_DK
     and b.EVENT_MONTH_START >  a.EVENT_MONTH_START
     and b.EVENT_MONTH_START <= DATEADD(month, 12, a.EVENT_MONTH_START)
    group by 1, 2, 3
),

-- 채널별 발송 적재 시작일(그 이전 사건은 발송 플래그 NULL)
disp_src as (
    select
        f.MEMBER_DK,
        TO_DATE(TO_VARCHAR(f.DATE_SK), 'YYYYMMDD')     as SEND_DATE,
        r.SEND_CHANNEL,
        t.ATMC_YN,
        COALESCE(f.OPEN_MEMBERS, 0)                    as OPENED
    from {{ ref('FACT_MESSAGE_DISPATCH') }} f
    join {{ ref('DIM_SEND_REQUEST') }} r
      on r.SEND_REQUEST_SK = f.SEND_REQUEST_SK
    left join {{ ref('DIM_MSG_TEMPLATE') }} t
      on t.TEMPLATE_KEY = r.TMPLAT_ID
     and t.SEND_CHANNEL = r.SEND_CHANNEL
    where f.DATE_SK > 0
      and r.SEND_CHANNEL in ('MSG_AT', 'SND', 'EMAIL')
),

disp_cov as (
    select SEND_CHANNEL, MIN(SEND_DATE) as COV_START
    from disp_src
    group by 1
),

disp_flags as (
    select
        e.MEMBER_DK, e.EVENT_MONTH_KEY, e.DVLP_DIV_CD,
        BOOLOR_AGG(d.SEND_CHANNEL = 'MSG_AT' and d.ATMC_YN = 'Y' and d.SEND_DATE = e.EVENT_DATE)                                    as AT_D0_AUTO,
        BOOLOR_AGG(d.SEND_CHANNEL = 'MSG_AT' and d.ATMC_YN = 'N' and d.SEND_DATE = e.EVENT_DATE)                                    as AT_D0_MANUAL,
        BOOLOR_AGG(d.SEND_CHANNEL = 'MSG_AT' and d.ATMC_YN = 'Y' and d.SEND_DATE between e.EVENT_DATE + 1 and e.EVENT_DATE + 5)     as AT_D1_5_AUTO,
        BOOLOR_AGG(d.SEND_CHANNEL = 'MSG_AT' and d.ATMC_YN = 'N' and d.SEND_DATE between e.EVENT_DATE + 1 and e.EVENT_DATE + 5)     as AT_D1_5_MANUAL,
        BOOLOR_AGG(d.SEND_CHANNEL = 'MSG_AT' and d.ATMC_YN = 'N' and d.SEND_DATE between e.EVENT_DATE - 30 and e.EVENT_DATE - 1)    as AT_PRE30_MANUAL,
        BOOLOR_AGG(d.SEND_CHANNEL = 'MSG_AT' and d.SEND_DATE between e.EVENT_DATE and e.EVENT_DATE + 5)                             as AT_ANY_D0_5,
        BOOLOR_AGG(d.SEND_CHANNEL = 'SND'    and d.SEND_DATE between e.EVENT_DATE and e.EVENT_DATE + 5)                             as SND_D0_5,
        BOOLOR_AGG(d.SEND_CHANNEL = 'SND'    and d.SEND_DATE between e.EVENT_DATE and e.EVENT_DATE + 5 and d.OPENED > 0)            as SND_D0_5_OPEN,
        BOOLOR_AGG(d.SEND_CHANNEL = 'EMAIL'  and d.SEND_DATE between e.EVENT_DATE and e.EVENT_DATE + 5)                             as EMAIL_D0_5
    from ev e
    join disp_src d
      on d.MEMBER_DK = e.MEMBER_DK
     and d.SEND_DATE between e.EVENT_DATE - 30 and e.EVENT_DATE + 5
    group by 1, 2, 3
),

months as (
    select ROW_NUMBER() over (order by SEQ4()) - 1 as MONTHS_AFTER
    from table(generator(rowcount => 13))
),

spine as (
    select
        e.*,
        m.MONTHS_AFTER,
        TO_NUMBER(TO_CHAR(DATEADD(month, m.MONTHS_AFTER, e.EVENT_MONTH_START), 'YYYYMM')) as OBS_MONTH_KEY
    from ev e
    cross join months m
),

cur as (
    select TO_NUMBER(TO_CHAR(CURRENT_DATE(), 'YYYYMM')) as CUR_MK
)

select
    s.EVENT_MONTH_KEY,
    s.MEMBER_DK,
    s.DVLP_DIV_CD,
    s.DVLP_DIV_NM,
    s.MONTHS_AFTER,
    s.OBS_MONTH_KEY,
    (s.OBS_MONTH_KEY <= c.CUR_MK)                                     as IS_OBSERVABLE,
    s.FIRST_EVENT_DATE_SK,
    s.EVENT_ROWS,
    s.EVENT_DEV_CNT,
    s.EVENT_SPNSR_AMT,
    s.CAMPAIGN_SK,
    s.SPONSORSHIP_SK,
    s.MKTG_CMPGN_NM_AT_EVENT,
    s.MBER_INFLOW_PATH_NM_AT_EVENT                                    as INFLOW_PATH_AT_EVENT,
    s.CMPGN_CTGR_NM_AT_EVENT,
    s.AGE_BAND_AT_EVENT,
    s.GENDER_AT_EVENT,
    s.CPR_DIV_NM_AT_EVENT,
    s.NEW_EXISTING_FLAG,
    IFF(s.JOIN_DATE is null, NULL, GREATEST(DATEDIFF(month, s.JOIN_DATE, s.EVENT_DATE), 0)) as TENURE_MONTHS_AT_EVENT,
    fe.PAYMENT_SK                                                     as PAYMENT_SK_AT_EVENT,
    fe.AMOUNT_BAND2                                                   as AMOUNT_BAND2_AT_EVENT,
    fl.FIRST_INC_MONTHS_AFTER,
    fl.FIRST_REDON_MONTHS_AFTER,
    fl.FIRST_DEC_MONTHS_AFTER,
    fl.FIRST_STOP_MONTHS_AFTER,
    -- 관측월까지 후속 발생 — 미래 관측월은 NULL
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fl.FIRST_INC_MONTHS_AFTER   <= s.MONTHS_AFTER, FALSE), NULL) as INC_BY_FLAG,
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fl.FIRST_REDON_MONTHS_AFTER <= s.MONTHS_AFTER, FALSE), NULL) as REDON_BY_FLAG,
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fl.FIRST_DEC_MONTHS_AFTER   <= s.MONTHS_AFTER, FALSE), NULL) as DEC_BY_FLAG,
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fl.FIRST_STOP_MONTHS_AFTER  <= s.MONTHS_AFTER, FALSE), NULL) as STOP_BY_FLAG,
    -- 관측월 지표(FMM) — 관측 가능 월에 FMM 행이 없으면 활동·청구 없음(0 / FALSE)
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fo.MONTH_END_ACTIVE_CNT, 0) > 0, NULL)  as ACTIVE_FLAG,
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fo.MONTH_END_ACTIVE_CNT, 0), NULL)      as MONTH_END_ACTIVE_CNT,
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fo.BILLED_AMT, 0), NULL)                as BILLED_AMT,
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fo.PAID_FEE_BILLABLE, 0), NULL)         as PAID_FEE_BILLABLE,
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fo.UNPAID_FLAG_EOM, FALSE), NULL)       as UNPAID_FLAG_EOM,
    IFF(s.OBS_MONTH_KEY <= c.CUR_MK, COALESCE(fo.STOP_AMT_CNT, 0), NULL)              as STOP_AMT_CNT,
    -- 발송(코호트 속성 · 채널 적재 시작 전 사건 = NULL)
    IFF(s.EVENT_DATE      < ca.COV_START, NULL, COALESCE(df.AT_D0_AUTO, FALSE))       as AT_D0_AUTO_FLAG,
    IFF(s.EVENT_DATE      < ca.COV_START, NULL, COALESCE(df.AT_D0_MANUAL, FALSE))     as AT_D0_MANUAL_FLAG,
    IFF(s.EVENT_DATE      < ca.COV_START, NULL, COALESCE(df.AT_D1_5_AUTO, FALSE))     as AT_D1_5_AUTO_FLAG,
    IFF(s.EVENT_DATE      < ca.COV_START, NULL, COALESCE(df.AT_D1_5_MANUAL, FALSE))   as AT_D1_5_MANUAL_FLAG,
    IFF(s.EVENT_DATE - 30 < ca.COV_START, NULL, COALESCE(df.AT_PRE30_MANUAL, FALSE))  as AT_PRE30_MANUAL_FLAG,
    IFF(s.EVENT_DATE      < ca.COV_START, NULL, COALESCE(df.AT_ANY_D0_5, FALSE))      as AT_ANY_D0_5_FLAG,
    IFF(s.EVENT_DATE      < cs.COV_START, NULL, COALESCE(df.SND_D0_5, FALSE))         as SND_D0_5_FLAG,
    IFF(s.EVENT_DATE      < cs.COV_START, NULL, COALESCE(df.SND_D0_5_OPEN, FALSE))    as SND_D0_5_OPEN_FLAG,
    IFF(s.EVENT_DATE      < cm.COV_START, NULL, COALESCE(df.EMAIL_D0_5, FALSE))       as EMAIL_D0_5_FLAG,
    {{ gold_meta('CRM') }}
from spine s
cross join cur c
left join follow fl
       on fl.MEMBER_DK = s.MEMBER_DK
      and fl.EVENT_MONTH_KEY = s.EVENT_MONTH_KEY
      and fl.DVLP_DIV_CD = s.DVLP_DIV_CD
left join disp_flags df
       on df.MEMBER_DK = s.MEMBER_DK
      and df.EVENT_MONTH_KEY = s.EVENT_MONTH_KEY
      and df.DVLP_DIV_CD = s.DVLP_DIV_CD
left join {{ ref('FACT_MEMBER_MONTHLY') }} fe
       on fe.MEMBER_DK = s.MEMBER_DK
      and fe.MONTH_KEY = s.EVENT_MONTH_KEY
left join {{ ref('FACT_MEMBER_MONTHLY') }} fo
       on fo.MEMBER_DK = s.MEMBER_DK
      and fo.MONTH_KEY = s.OBS_MONTH_KEY
left join disp_cov ca on ca.SEND_CHANNEL = 'MSG_AT'
left join disp_cov cs on cs.SEND_CHANNEL = 'SND'
left join disp_cov cm on cm.SEND_CHANNEL = 'EMAIL'
