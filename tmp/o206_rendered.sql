

with rules as (
    select * from values
        ('SNG_INSTANT',        '선넘는좋은일 신규 즉시', 'TITLE', null, '%선넘는좋은일%'),
        ('PERSONAL_NEW_SADAN', '개별화 신규(사단)',     'CODE',  '43', null),
        ('PERSONAL_NEW_SADAN', '개별화 신규(사단)',     'TITLE', null, '%개별화%신규%사단%'),
        ('LUCKY_CARD',         '행운의 카드',          'TITLE', null, '%행운의 카드%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'CODE',  '06', null),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'CODE',  '23', null),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'CODE',  '24', null),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'TITLE', null, '%장기회원%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'TITLE', null, '%년%회원%감사%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'TITLE', null, '%년 회원서비스%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'TITLE', null, '%년 감사서비스%')
    as t(SERVICE_GROUP_CD, SERVICE_GROUP_NAME, MATCH_BASIS, SVC_UPPER_CD, TITLE_PATTERN)
),
grp as (
    select distinct SERVICE_GROUP_CD, SERVICE_GROUP_NAME from rules
),
req as (
    select
        r.SEND_REQUEST_SK,
        r.SNDNG_CD_ID,
        u.DTL_CD_ID                                 as SVC_UPPER_CD,
        u.DTL_CD_NM                                 as SVC_CATEGORY_NAME,
        COALESCE(
            case when u.DTL_CD_NM like '%사복%' then '사복'
                 when u.DTL_CD_NM like '%통합%' then '통합'
                 when u.DTL_CD_NM like '%사단%' then '사단' end,
            cpr.DTL_CD_NM)                          as SEND_CPR_NM,
        o.DEPT_NM                                   as CHRG_DEPT_NM
    from GN_DW.GOLD.DIM_SEND_REQUEST r
    left join GN_DW.SILVER.CRM_CODE d    on d.CD_ID = r.SNDNG_CD_ID and d.DTL_CD_ID = r.SNDNG_DTL_CD_ID
    left join GN_DW.SILVER.CRM_CODE u    on u.CD_ID = d.CD_ID and u.DTL_CD_ID = d.UPPER_CD_ID
    left join GN_DW.SILVER.CRM_MSG_TEMPLATE t on t.TEMPLATE_KEY = r.TMPLAT_ID and t.SEND_CHANNEL = r.SEND_CHANNEL
    left join GN_DW.SILVER.CRM_CODE cpr  on cpr.CD_ID = 'CM019' and cpr.DTL_CD_ID = t.CPR_DIV_CD
    left join GN_DW.SILVER.CRM_ORG o     on o.DEPT_ID = t.CHRG_DEPT_ID
),
disp_raw as (
    select f.MEMBER_DK, r.SERVICE_GROUP_CD, 'CODE' as MATCH_BASIS, f.DATE_SK,
           f.D5_STOP_MEMBERS, f.D5_INCREASE_PART_MEMBERS, q.SEND_CPR_NM, q.CHRG_DEPT_NM, q.SVC_CATEGORY_NAME
    from GN_DW.GOLD.FACT_MESSAGE_DISPATCH f
    join req q                         on q.SEND_REQUEST_SK = f.SEND_REQUEST_SK
    join rules r                       on r.MATCH_BASIS = 'CODE' and q.SNDNG_CD_ID = 'MS049' and q.SVC_UPPER_CD = r.SVC_UPPER_CD
    union all
    select f.MEMBER_DK, r.SERVICE_GROUP_CD, 'TITLE', f.DATE_SK,
           f.D5_STOP_MEMBERS, f.D5_INCREASE_PART_MEMBERS, q.SEND_CPR_NM, q.CHRG_DEPT_NM, q.SVC_CATEGORY_NAME
    from GN_DW.GOLD.FACT_MESSAGE_DISPATCH f
    join rules r                       on r.MATCH_BASIS = 'TITLE' and f.SEND_TITLE ilike r.TITLE_PATTERN
    left join req q                    on q.SEND_REQUEST_SK = f.SEND_REQUEST_SK
),
disp as (
    select
        x.MEMBER_DK,
        x.SERVICE_GROUP_CD,
        x.MATCH_BASIS,
        d.FULL_DATE                                 as SEND_DATE,
        x.D5_STOP_MEMBERS,
        x.D5_INCREASE_PART_MEMBERS,
        x.SEND_CPR_NM,
        x.CHRG_DEPT_NM,
        x.SVC_CATEGORY_NAME
    from disp_raw x
    join GN_DW.GOLD.DIM_DATE d       on d.DATE_SK = x.DATE_SK
),
rcv as (
    select
        MEMBER_DK,
        SERVICE_GROUP_CD,
        YEAR(SEND_DATE)                             as RECEIVE_YEAR,
        MIN(SEND_DATE)                              as FIRST_RECEIVE_DATE,
        MAX(SEND_DATE)                              as LAST_RECEIVE_DATE,
        COUNT(DISTINCT SEND_DATE)                   as RECEIVE_ROWS,  -- [O205-B] 수신일 수 · 한 발송이 코드·제목 둘 다에 맞아도 중복되지 않는다
        MAX(IFF(D5_STOP_MEMBERS > 0, 1, 0)) = 1     as D5_STOP_FLAG,
        MAX(IFF(D5_INCREASE_PART_MEMBERS > 0, 1, 0)) = 1 as D5_INCREASE_FLAG,
        MAX(IFF(MATCH_BASIS = 'CODE', 1, 0)) = 1    as MATCHED_BY_CODE_FLAG,
        MAX(IFF(MATCH_BASIS = 'TITLE', 1, 0)) = 1   as MATCHED_BY_TITLE_FLAG,
        MAX(IFF(SEND_CPR_NM = '사단', 1, 0)) = 1    as RECEIVED_SADAN_FLAG,
        MAX(IFF(SEND_CPR_NM = '사복', 1, 0)) = 1    as RECEIVED_SABOK_FLAG,
        MAX(IFF(SEND_CPR_NM = '통합', 1, 0)) = 1    as RECEIVED_TONGHAP_FLAG,
        LISTAGG(DISTINCT CHRG_DEPT_NM, ' · ') WITHIN GROUP (ORDER BY CHRG_DEPT_NM) as CHRG_DEPT_NAMES,
        LISTAGG(DISTINCT SVC_CATEGORY_NAME, ' · ') WITHIN GROUP (ORDER BY SVC_CATEGORY_NAME) as SVC_CATEGORY_NAMES
    from disp
    group by 1, 2, 3
),
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
    join GN_DW.GOLD.FACT_MEMBER_EVENT e
      on e.MEMBER_DK = x.MEMBER_DK
     and e.EVENT_TYPE = 'STOP'
    join GN_DW.GOLD.DIM_DATE ed      on ed.DATE_SK = e.DATE_SK
    left join GN_DW.GOLD.DIM_SPONSORSHIP sp on sp.SPONSORSHIP_SK = e.SPONSORSHIP_SK
    where ed.FULL_DATE between DATEADD('day', 1, x.SEND_DATE) and DATEADD('day', 5, x.SEND_DATE)
    qualify ROW_NUMBER() over (partition by x.MEMBER_DK, x.SERVICE_GROUP_CD, x.RECEIVE_YEAR
                               order by ed.FULL_DATE, e.STOP_REASON_NM) = 1
),
spine as (
    select a.MEMBER_DK, g.SERVICE_GROUP_CD
    from GN_DW.GOLD.DIM_MEMBER_ACQUISITION a
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
        COALESCE(r.D5_INCREASE_FLAG, false)         as D5_INCREASE_FLAG,
        r.MATCHED_BY_CODE_FLAG,
        r.MATCHED_BY_TITLE_FLAG,
        r.RECEIVED_SADAN_FLAG,
        r.RECEIVED_SABOK_FLAG,
        r.RECEIVED_TONGHAP_FLAG,
        r.CHRG_DEPT_NAMES,
        r.SVC_CATEGORY_NAMES
    from spine s
    full outer join rcv r
      on r.MEMBER_DK = s.MEMBER_DK
     and r.SERVICE_GROUP_CD = s.SERVICE_GROUP_CD
),
ev as (
    select
        a.MEMBER_DK,
        a.EVENT_KIND,
        d.FULL_DATE                                 as PART_DATE,
        (a.EVENT_KIND = 'CRMN' and e.EVENT_CATEGORY in ('6', '14', '15', '16')) as IS_CULTURE,
        (a.EVENT_KIND = 'EVENT' and e.EVENT_CATEGORY = '100')                   as IS_ONLINE
    from GN_DW.GOLD.FACT_EVENT_ATTENDANCE a
    left join GN_DW.GOLD.DIM_DATE d  on d.DATE_SK = a.DATE_SK
    left join GN_DW.GOLD.DIM_EVENT e on e.EVENT_SK = a.EVENT_SK
),
ev_agg as (
    select
        b.MEMBER_DK,
        b.SERVICE_GROUP_CD,
        b.RECEIVE_YEAR,
        COUNT_IF(v.EVENT_KIND = 'EVENT')            as GENERAL_EVENT_PART_ROWS,
        COUNT_IF(v.EVENT_KIND = 'EVENT' and v.PART_DATE >= b.FIRST_RECEIVE_DATE) as GENERAL_EVENT_PART_ROWS_AFTER,
        COUNT_IF(v.EVENT_KIND = 'CRMN')             as CAMPAIGN_EVENT_PART_ROWS,
        COUNT_IF(v.IS_CULTURE)                      as CULTURE_EVENT_PART_ROWS,
        COUNT_IF(v.IS_ONLINE)                       as ONLINE_EVENT_PART_ROWS,
        COUNT_IF(v.IS_ONLINE and v.PART_DATE >= b.FIRST_RECEIVE_DATE) as ONLINE_EVENT_PART_ROWS_AFTER
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
    DATEDIFF('day', acq_d.FULL_DATE, ds.D5_STOP_DATE) as D5_STOP_SPONSOR_DAYS,
    acq_d.FULL_DATE                                 as ACQ_DATE,
    YEAR(acq_d.FULL_DATE)                           as ACQ_YEAR,
    FLOOR(acq.ACQ_DATE_SK / 100)                    as ACQ_MONTH_KEY,
    acq.ACQ_CAMPAIGN_NAME,
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
    COALESCE(v.GENERAL_EVENT_PART_ROWS, 0)          as GENERAL_EVENT_PART_ROWS,
    v.GENERAL_EVENT_PART_ROWS_AFTER                 as GENERAL_EVENT_PART_ROWS_AFTER,
    COALESCE(v.CAMPAIGN_EVENT_PART_ROWS, 0)         as CAMPAIGN_EVENT_PART_ROWS,
    case when b.MATCHED_BY_CODE_FLAG and b.MATCHED_BY_TITLE_FLAG then '서비스코드+발송제목'
         when b.MATCHED_BY_CODE_FLAG then '서비스코드'
         when b.MATCHED_BY_TITLE_FLAG then '발송제목' end as MATCH_BASIS,
    b.RECEIVED_SADAN_FLAG,
    b.RECEIVED_SABOK_FLAG,
    b.RECEIVED_TONGHAP_FLAG,
    b.CHRG_DEPT_NAMES,
    b.SVC_CATEGORY_NAMES,
    COALESCE(v.CULTURE_EVENT_PART_ROWS, 0)          as CULTURE_EVENT_PART_ROWS,
    COALESCE(v.ONLINE_EVENT_PART_ROWS, 0)           as ONLINE_EVENT_PART_ROWS,
    v.ONLINE_EVENT_PART_ROWS_AFTER                  as ONLINE_EVENT_PART_ROWS_AFTER
from base b
join grp g                                    on g.SERVICE_GROUP_CD = b.SERVICE_GROUP_CD
left join d5_stop ds
  on ds.MEMBER_DK = b.MEMBER_DK
 and ds.SERVICE_GROUP_CD = b.SERVICE_GROUP_CD
 and ds.RECEIVE_YEAR = b.RECEIVE_YEAR
left join GN_DW.GOLD.DIM_MEMBER_ACQUISITION acq on acq.MEMBER_DK = b.MEMBER_DK
left join GN_DW.GOLD.DIM_DATE acq_d         on acq_d.DATE_SK = acq.ACQ_DATE_SK
left join ev_agg v
  on v.MEMBER_DK = b.MEMBER_DK
 and v.SERVICE_GROUP_CD = b.SERVICE_GROUP_CD
 and v.RECEIVE_YEAR is not distinct from b.RECEIVE_YEAR
