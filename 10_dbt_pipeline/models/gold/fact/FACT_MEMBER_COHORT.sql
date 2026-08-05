-- FACT_MEMBER_COHORT: 회원 획득 코호트 팩트 (1행=1회원) — 캠페인별 중단률·유지기간의 정본
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-08-05 O37] 신설 — 왜 이 팩트가 필요한가
-- ----------------------------------------------------------------------------
-- 트리거: Agent 가 *"캠페인 축은 개발 사건에만 배선돼 있고 중단 사건에는 캠페인 정보가 원천에
--   없다 — 따라서 캠페인별 중단률은 구조적으로 산출 불가"* 라고 답했다.
--
-- 🔴 그 판정은 틀렸다. 중단원천에는 캠페인이 없지만, 개발원천의 `DVLP_DIV_CD='5'`(MM015
--   후원중단) 행이 `CMPGN_CD` 를 전건 보유하며 `FACT_MEMBER_EVENT.CAMPAIGN_SK` 로 이미
--   배선돼 있었다. 다만 **그것만으로는 「중단률」이 되지 않는다** — 실측으로 두 함정을 확인했다:
--
--   ① 코드5 의 캠페인은 **중단 시점** 캠페인이다. 이를 신규 건수로 나누면 분자·분모의
--      모집단이 달라 비율이 100% 를 넘는다(기존회원 대상 캠페인에서 실증). 비율이 아니다.
--      → 분모를 **획득 코호트**(그 캠페인이 데려온 회원)로 잡아야 비율이 성립한다.
--   ② 누적 이탈률은 **관측 기간**에 지배된다. 획득 시점이 이를수록 누적 이탈률이 높아지는
--      단조 관계가 실측됐다. 캠페인은 실행 연도가 다르므로 누적률로 비교하면 **오래된
--      캠페인이 자동으로 「중단률 높음」**이 된다 — 값·매핑이 전부 정상이라 어떤 품질
--      테스트로도 잡히지 않는 P60 유형 의미 결함이다.
--      → **12개월 고정 이탈률**을 정본으로 삼고, 분자를 관측 가능 코호트로 제한한다.
--
-- 왜 별도 팩트인가: 중단률의 분모는 **회원 수**다. 사건 팩트(FME)에서 소비 끝단이 회원 수를
--   distinct 로 세게 하면 분모를 틀리기 쉽다. 회원 grain 으로 미리 확정하면 SUM/SUM 이 되어
--   오답 경로가 구조적으로 사라진다(O35 에서 배운 「축이 갈리면 Agent 가 못 푼다」의 역적용).
--
-- 🔴 분자·분모 일치를 **데이터로** 강제한다: `STOPPED_12M_MEMBERS` 는 `IS_12M_OBSERVABLE`
--   인 회원에 대해서만 1 이 된다. 소비 끝단이 분모를 `ACQ_MEMBERS` 로 잘못 골라도 분자가
--   이미 관측 가능 집합으로 제한돼 있어 과소추정 방향으로만 틀린다(과대추정 불가).
--
-- 상류 = `FACT_MEMBER_EVENT`(GOLD). SILVER 를 다시 읽지 않는다 — FME 가 이미 개발∪중단을
--   union 하고 conformed SK·사건시점 속성·중단사유 라벨을 확정했으므로 재구현은 드리프트를 만든다.
--
-- 순서9 규약: fact = incremental + append + pre-hook TRUNCATE(dbt_project.yml gold.fact).
--   구조 소유주는 `03_top-down_gold/06_DDL.sql` 이다(P57 — 이 모델만 고치면 다음 재구축에서 소실).
-- ============================================================================
{{ config(
    tags=['gold_pending']
) }}

with fme as (
    select * from {{ ref('FACT_MEMBER_EVENT') }}
),

-- 관측 기준일 = 데이터가 실제로 담고 있는 최종 사건일. 🔴 CURRENT_DATE 를 쓰지 않는다 —
--   적재 지연이 있으면 관측창이 실제보다 길게 잡혀 12개월 이탈률이 과소추정된다.
obs_window as (
    select max(DATE_SK) as MAX_DATE_SK from fme where DATE_SK <> 0
),

dev as (
    select * from fme where EVENT_TYPE = 'DEV'
),

-- 획득 사건 후보. 우선순위 = ① 신규(MM015 코드1) ② 신규가 없으면 최초 개발 사건(FALLBACK).
--   🔴 정렬 결정성: 무효 일자(DATE_SK=0)를 뒤로 밀고, 동일 일자는 캠페인·금액·지역·연령으로
--      결정적으로 깬다. 완전 동일 행이면 어느 것을 골라도 값이 같다(비결정성 무해).
acq_ranked as (
    select
        MEMBER_DK, CAMPAIGN_SK, DATE_SK, DVLP_DIV_CD,
        AGE_AT_EVENT, AGE_BAND_AT_EVENT, AREA_CD_AT_EVENT, REGION_AT_EVENT,
        SEX_AT_EVENT, GENDER_AT_EVENT, SPNSR_AMT,
        case when DVLP_DIV_CD = '1' then 'NEW' else 'FALLBACK' end as ACQ_BASIS,
        row_number() over (
            partition by MEMBER_DK
            order by
                case when DVLP_DIV_CD = '1' then 0 else 1 end,   -- 신규 우선
                case when DATE_SK = 0 then 1 else 0 end,         -- 무효 일자는 뒤로
                DATE_SK,
                CAMPAIGN_SK,
                coalesce(SPNSR_AMT, 0),
                coalesce(AREA_CD_AT_EVENT, ''),
                coalesce(AGE_AT_EVENT, -1)
        ) as rn
    from dev
),

acq as (
    select * from acq_ranked where rn = 1
),

-- 중단 사건. 🔴 **획득일 이후**의 중단만 이 코호트의 이탈로 본다 — 획득 전 중단은 직전
--   후원관계의 종료이며 이 획득 코호트의 이탈이 아니다(FALLBACK 회원에서 실제로 발생 가능).
stop_all as (
    select MEMBER_DK, DATE_SK, STOP_REASON_NM from fme where EVENT_TYPE = 'STOP'
),

stop_first as (
    select
        a.MEMBER_DK,
        min(case when s.DATE_SK <> 0 and s.DATE_SK >= a.DATE_SK then s.DATE_SK end) as FIRST_STOP_VALID,
        max(case when s.DATE_SK = 0 then 1 else 0 end)                              as HAS_INVALID_STOP
    from acq a
    join stop_all s on s.MEMBER_DK = a.MEMBER_DK
    group by 1
),

-- 최초 중단의 사유 라벨. 같은 일자에 복수 중단행이 있을 수 있어 결정적으로 1건만 고른다.
stop_reason as (
    select MEMBER_DK, DATE_SK, STOP_REASON_NM,
           row_number() over (partition by MEMBER_DK, DATE_SK
                              order by coalesce(STOP_REASON_NM, '')) as rn
    from stop_all
),

joined as (
    select
        a.MEMBER_DK,
        coalesce(a.CAMPAIGN_SK, 0)                                  as ACQ_CAMPAIGN_SK,
        coalesce(a.DATE_SK, 0)                                      as ACQ_DATE_SK,
        a.ACQ_BASIS,
        a.DVLP_DIV_CD                                               as ACQ_DVLP_DIV_CD,
        a.AGE_AT_EVENT                                              as ACQ_AGE_CD,
        a.AGE_BAND_AT_EVENT                                         as ACQ_AGE_BAND,
        a.AREA_CD_AT_EVENT                                          as ACQ_AREA_CD,
        a.REGION_AT_EVENT                                           as ACQ_REGION,
        a.SEX_AT_EVENT                                              as ACQ_SEX_CD,
        a.GENDER_AT_EVENT                                           as ACQ_GENDER,
        a.SPNSR_AMT                                                 as ACQ_SPNSR_AMT,
        -- 유효 중단일이 없고 무효 일자 중단행만 있으면 0(날짜 미상)으로 라우팅. 중단 이력이
        -- 전혀 없거나 획득 전 중단만 있으면 NULL(미중단) — 0 과 NULL 은 다른 뜻이다(P21).
        coalesce(sf.FIRST_STOP_VALID,
                 case when sf.HAS_INVALID_STOP = 1 then 0 end)      as FIRST_STOP_DATE_SK,
        sr.STOP_REASON_NM                                           as FIRST_STOP_REASON_NM,
        to_date(to_char(nullif(a.DATE_SK, 0)), 'YYYYMMDD')          as ACQ_DATE,
        to_date(to_char(sf.FIRST_STOP_VALID), 'YYYYMMDD')           as FIRST_STOP_DATE,
        -- 관측 기준일은 단일 행이므로 cross join 이 fan-out 을 만들지 않는다.
        --   (스칼라 서브쿼리는 Snowflake 가 이 위치에서 허용하지 않는다 — 검증 중 확인)
        --   ⚠️ CTE 명을 `asof` 로 쓰면 안 된다 — ASOF JOIN 예약어와 충돌한다(검증 중 확인).
        ao.MAX_DATE_SK
    from acq a
    cross join obs_window ao
    left join stop_first sf on sf.MEMBER_DK = a.MEMBER_DK
    left join stop_reason sr on sr.MEMBER_DK = a.MEMBER_DK
                            and sr.DATE_SK  = sf.FIRST_STOP_VALID
                            and sr.rn = 1
),

final as (
    select
        MEMBER_DK, ACQ_CAMPAIGN_SK, ACQ_DATE_SK, ACQ_BASIS, ACQ_DVLP_DIV_CD,
        ACQ_AGE_CD, ACQ_AGE_BAND, ACQ_AREA_CD, ACQ_REGION, ACQ_SEX_CD, ACQ_GENDER,
        ACQ_SPNSR_AMT, FIRST_STOP_DATE_SK, FIRST_STOP_REASON_NM,
        -- 유지기간 = 중단일 − 획득일. 🔴 미중단은 NULL(우절단 관측이다 — 0 이나 현재까지
        --   경과일로 채우면 평균 유지기간이 조용히 틀린다).
        case when ACQ_DATE is not null and FIRST_STOP_DATE is not null
             then datediff(day, ACQ_DATE, FIRST_STOP_DATE) end      as TENURE_DAYS,
        -- 12개월 관측 가능 = 획득 후 12개월이 데이터 최종일 안에 들어오는가.
        case when ACQ_DATE is not null
                  and add_months(ACQ_DATE, 12)
                      <= to_date(to_char(MAX_DATE_SK), 'YYYYMMDD')
             then TRUE else FALSE end                               as IS_12M_OBSERVABLE,
        1                                                           as ACQ_MEMBERS,
        case when FIRST_STOP_DATE_SK is not null then 1 else 0 end   as STOPPED_MEMBERS,
        -- 🔴 분자를 관측 가능 집합으로 **구조적으로 제한**한다(분모 오선택 방어).
        case when ACQ_DATE is not null
                  and add_months(ACQ_DATE, 12)
                      <= to_date(to_char(MAX_DATE_SK), 'YYYYMMDD')
                  and FIRST_STOP_DATE is not null
                  and FIRST_STOP_DATE < add_months(ACQ_DATE, 12)
             then 1 else 0 end                                      as STOPPED_12M_MEMBERS,
        case when ACQ_DATE is not null
                  and add_months(ACQ_DATE, 12)
                      <= to_date(to_char(MAX_DATE_SK), 'YYYYMMDD')
             then 1 else 0 end                                      as OBSERVABLE_12M_MEMBERS
    from joined
)

select
    MEMBER_DK, ACQ_CAMPAIGN_SK, ACQ_DATE_SK, ACQ_BASIS, ACQ_DVLP_DIV_CD,
    ACQ_AGE_CD, ACQ_AGE_BAND, ACQ_AREA_CD, ACQ_REGION, ACQ_SEX_CD, ACQ_GENDER,
    ACQ_SPNSR_AMT, FIRST_STOP_DATE_SK, FIRST_STOP_REASON_NM, TENURE_DAYS,
    IS_12M_OBSERVABLE, ACQ_MEMBERS, STOPPED_MEMBERS, STOPPED_12M_MEMBERS,
    OBSERVABLE_12M_MEMBERS,
    {{ gold_meta('CRM') }}
from final
