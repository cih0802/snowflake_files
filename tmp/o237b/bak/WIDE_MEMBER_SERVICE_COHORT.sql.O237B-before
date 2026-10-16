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
-- 🔴🔴 서비스그룹 판정 = [O206 A안 · 사용자 결정 2026-10-07] **코드 우선 → 제목 보조**
--   ① 서비스코드(발송코드 MS049 의 상위 서비스코드 = 원천 서비스 카테고리)로 먼저 판정한다
--      · 개별화 신규(사단) = MS049 상위 43(개별화 서비스 신규(사단))
--      · 장기회원 서비스  = MS049 상위 06·23·24(장기회원감사서비스 사단·사복·통합)
--   ② 카테고리가 없는 발송(MS0505 「기타」·MS046 결연 등)과 코드 계층에 없는 서비스는 발송 제목으로 판정한다
--      · 선넘는좋은일 신규 즉시 = 제목(서비스코드 4312 「신규_사단_기타」는 다른 개별화 신규와 섞여 코드만으로 분리 불가)
--      · 행운의 카드 = 제목(MS046 결연 / ACPI 발송 — 원천에 서비스 카테고리 없음)
--      · 장기회원 서비스 = 제목 보조(2025~ 대량 발송이 MS0505 「기타」 코드에 실렸다 · O205-B 실측)
--   ⇒ MATCH_BASIS 로 그 행이 어느 근거로 들었는지 남긴다(SV 가 답변에 「코드 기준」·「제목 매핑」을 밝힌다).
--   · 한 발송이 여러 그룹에 들 수 있다(그룹 간 합산 금지) · 같은 그룹은 코드 판정이 제목 판정보다 우선한다.
--   🔴 법인 = 서비스코드명의 (사단)/(사복)/(통합) → 없으면 알림톡 템플릿 법인구분(CPR_DIV_CD · CM019).
--      grain 에 넣지 않는다(평균 지표가 법인 수만큼 중복 가중된다) ⇒ 법인별 수신 플래그 3개로 낸다.
--   🔴 담당부서 = 알림톡 템플릿 담당부서(CHRG_DEPT_ID → CRM_ORG). 처리자ID→부서 마스터는 원천에 없다.
--   🔴 제목·코드·템플릿이 모두 없는 발송(예: 2026-08 제목 「[굿네이버스]」 대량 발송)은 어느 그룹에도 들지 않는다.
--
-- 🔴 「효과」는 이 뷰가 정의하지 않는다 — 수신·미수신 비교는 단순 차이이며 인과가 아니다.
--   [O206] 대조군은 원천·DW 어디에도 정의가 없다(실측) ⇒ SV 가 「대조군 없음」을 밝히고 후보군(같은 가입월·캠페인·사업·법인 미수신)을 제시한다.
-- ⚠️ 캠페인행사(CRMN) 참여는 원천에 참여일이 없어(PARTCPT_DATE 전건 NULL) FEA 날짜가 행사 시작일이다
--   (종전 1970 계열은 DIM_EVENT 변환 결함이었고 O205-B 에서 교정됐다) ⇒ 수신 전후 구분 없이 총계만 싣는다.
-- 🔴 컬럼 COMMENT 정본 = `_wide_schema.yml` columns[] — SELECT 컬럼 추가·순서 변경 시 함께 고친다(gn_view_commented).
{{ config(
    materialized='gn_view_commented',
    tags=['gold_ready']
) }}

with rules as (
    -- MATCH_BASIS = CODE(서비스코드 MS049 상위코드 등가) · TITLE(발송 제목 부분일치)
    select * from values
        ('SNG_INSTANT',        '선넘는좋은일 신규 즉시', 'TITLE', null, '%선넘는좋은일%'),
        ('PERSONAL_NEW_SADAN', '개별화 신규(사단)',     'CODE',  '43', null),
        ('PERSONAL_NEW_SADAN', '개별화 신규(사단)',     'TITLE', null, '%개별화%신규%사단%'),
        ('LUCKY_CARD',         '행운의 카드',          'TITLE', null, '%행운의 카드%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'CODE',  '06', null),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'CODE',  '23', null),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'CODE',  '24', null),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'TITLE', null, '%장기회원%'),
        -- [O205-B] 2026 년 제목에서 「장기회원」이 빠졌다(「사복_2026 굿네이버스 N년 회원 감사서비스」 · BRONZE 서비스코드 MS0505/0201 실측)
        ('LONGTERM_THANKS',    '장기회원 서비스',       'TITLE', null, '%년%회원%감사%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'TITLE', null, '%년 회원서비스%'),
        ('LONGTERM_THANKS',    '장기회원 서비스',       'TITLE', null, '%년 감사서비스%')
    as t(SERVICE_GROUP_CD, SERVICE_GROUP_NAME, MATCH_BASIS, SVC_UPPER_CD, TITLE_PATTERN)
),
grp as (
    select distinct SERVICE_GROUP_CD, SERVICE_GROUP_NAME from rules
),
-- 발송요청 × 서비스코드 계층(MS049 상세 → 상위) × 알림톡/메일 템플릿(법인구분 · 담당부서)
req as (
    select
        r.SEND_REQUEST_SK,
        r.SNDNG_CD_ID,
        u.DTL_CD_ID                                 as SVC_UPPER_CD,
        u.DTL_CD_NM                                 as SVC_CATEGORY_NAME,
        -- 법인: 서비스코드명의 법인 표기 → 없으면 템플릿 법인구분(CM019)
        COALESCE(
            case when u.DTL_CD_NM like '%사복%' then '사복'
                 when u.DTL_CD_NM like '%통합%' then '통합'
                 when u.DTL_CD_NM like '%사단%' then '사단' end,
            cpr.DTL_CD_NM)                          as SEND_CPR_NM,
        o.DEPT_NM                                   as CHRG_DEPT_NM
    from {{ ref('DIM_SEND_REQUEST') }} r
    left join {{ ref('CRM_CODE') }} d    on d.CD_ID = r.SNDNG_CD_ID and d.DTL_CD_ID = r.SNDNG_DTL_CD_ID
    left join {{ ref('CRM_CODE') }} u    on u.CD_ID = d.CD_ID and u.DTL_CD_ID = d.UPPER_CD_ID
    left join {{ ref('CRM_MSG_TEMPLATE') }} t on t.TEMPLATE_KEY = r.TMPLAT_ID and t.SEND_CHANNEL = r.SEND_CHANNEL
    left join {{ ref('CRM_CODE') }} cpr  on cpr.CD_ID = 'CM019' and cpr.DTL_CD_ID = t.CPR_DIV_CD
    left join {{ ref('CRM_ORG') }} o     on o.DEPT_ID = t.CHRG_DEPT_ID
),
disp_raw as (
    -- ① 서비스코드 판정(등가조인)
    select f.MEMBER_DK, r.SERVICE_GROUP_CD, 'CODE' as MATCH_BASIS, f.DATE_SK,
           f.D5_STOP_MEMBERS, f.D5_INCREASE_PART_MEMBERS, q.SEND_CPR_NM, q.CHRG_DEPT_NM, q.SVC_CATEGORY_NAME
    from {{ ref('FACT_MESSAGE_DISPATCH') }} f
    join req q                         on q.SEND_REQUEST_SK = f.SEND_REQUEST_SK
    join rules r                       on r.MATCH_BASIS = 'CODE' and q.SNDNG_CD_ID = 'MS049' and q.SVC_UPPER_CD = r.SVC_UPPER_CD
    union all
    -- ② 발송 제목 판정(카테고리가 없는 발송 · 코드 계층에 없는 서비스)
    select f.MEMBER_DK, r.SERVICE_GROUP_CD, 'TITLE', f.DATE_SK,
           f.D5_STOP_MEMBERS, f.D5_INCREASE_PART_MEMBERS, q.SEND_CPR_NM, q.CHRG_DEPT_NM, q.SVC_CATEGORY_NAME
    from {{ ref('FACT_MESSAGE_DISPATCH') }} f
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
    join {{ ref('DIM_DATE') }} d       on d.DATE_SK = x.DATE_SK
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
        -- [O206] 판정 근거 · 법인 · 담당부서 · 원천 서비스분류
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
        -- [O206] 원천 행사구분: 캠페인행사 MS002 6 문화서비스 · 14 전시 · 15 서적 · 16 공연 / 일반행사 MS286 100 온라인
        (a.EVENT_KIND = 'CRMN' and e.EVENT_CATEGORY in ('6', '14', '15', '16')) as IS_CULTURE,
        (a.EVENT_KIND = 'EVENT' and e.EVENT_CATEGORY = '100')                   as IS_ONLINE
    from {{ ref('FACT_EVENT_ATTENDANCE') }} a
    left join {{ ref('DIM_DATE') }} d  on d.DATE_SK = a.DATE_SK
    left join {{ ref('DIM_EVENT') }} e on e.EVENT_SK = a.EVENT_SK
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
    COALESCE(v.CAMPAIGN_EVENT_PART_ROWS, 0)         as CAMPAIGN_EVENT_PART_ROWS,
    -- ── [O206 A안] 판정 근거 · 발송 법인 · 담당부서 · 원천 서비스분류 (수신 행만 · 미수신 NULL) ──
    case when b.MATCHED_BY_CODE_FLAG and b.MATCHED_BY_TITLE_FLAG then '서비스코드+발송제목'
         when b.MATCHED_BY_CODE_FLAG then '서비스코드'
         when b.MATCHED_BY_TITLE_FLAG then '발송제목' end as MATCH_BASIS,
    b.RECEIVED_SADAN_FLAG,
    b.RECEIVED_SABOK_FLAG,
    b.RECEIVED_TONGHAP_FLAG,
    b.CHRG_DEPT_NAMES,
    b.SVC_CATEGORY_NAMES,
    -- ── [O206] 원천 행사구분 기준 참여(문화서비스 · 온라인) ──────────────────────
    COALESCE(v.CULTURE_EVENT_PART_ROWS, 0)          as CULTURE_EVENT_PART_ROWS,
    COALESCE(v.ONLINE_EVENT_PART_ROWS, 0)           as ONLINE_EVENT_PART_ROWS,
    v.ONLINE_EVENT_PART_ROWS_AFTER                  as ONLINE_EVENT_PART_ROWS_AFTER
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
