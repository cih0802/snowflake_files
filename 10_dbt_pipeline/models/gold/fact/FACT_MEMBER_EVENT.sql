-- FACT_MEMBER_EVENT: 회원 사건 팩트 스캐폴드 (개발 ∪ 후원중단, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ 스캐폴드: 행당 카운트 1 부여(회원 dedup·차원 SK 해소는 입고 후). SPONSORSHIP/ORG/REASON_SK=0 센티넬.
-- [2026-07-30] CAMPAIGN_SK = 개발측 배선 완료(B3 부분해소) / 중단측 0 센티넬 유지(D1 미확정).
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.
{{ config(
    tags=['gold_pending']
) }}

-- [2026-07-30 B3 개발측 해소] 유효 캠페인키 집합. 고아 CMPGN_CD(실측 18행)를 SK=0(unknown 멤버 R5)로
-- 흡수해 FK 고아를 만들지 않는다. CRM_CAMPAIGN 은 CMPGN_CD 유일(실측 36,143행=36,143 distinct·중복 0)
-- 이므로 이 조인은 fan-out 을 만들지 않는다(행수 불변 검증 대상).
with campaign_valid as (
    select CMPGN_CD from {{ ref('CRM_CAMPAIGN') }}
),

dev as (
    select
        COALESCE({{ date_sk("TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD')") }}, 0)  as DATE_SK,   -- 범위밖/NULL → 0 (순서9)
        MBER_NO                                             as MEMBER_DK,
        'DEV'                                               as EVENT_TYPE,
        -- B3 해소(개발측 한정): CRM_MEMBER_DEV.CMPGN_CD 채움률 100%(3,594,843/3,594,843)·
        -- DIM_CAMPAIGN 매칭 99.9995%. 산식은 DIM_CAMPAIGN.CAMPAIGN_SK 와 동일(gold_sk(['CMPGN_CD'])).
        -- ⚠️ 중단측은 원천에 캠페인 컬럼 부재 → D1(귀속방식) 확정까지 0 센티넬 유지.
        case when c.CMPGN_CD is not null
             then {{ gold_sk(['d.CMPGN_CD']) }}
             else 0
        end                                                 as CAMPAIGN_SK,
        0 as SPONSORSHIP_SK, 0 as ORG_SK, 0 as REASON_SK,
        1 as DEV_CNT, 1 as DEV_MEMBERS,
        0 as STOP_CNT, 0 as STOP_MEMBERS, 0 as UNPAID_STOP_CNT, 0 as UNPAID_STOP_MEMBERS,
        TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD')                  as JOIN_DATE,
        CAST(NULL AS DATE)                                  as STOP_DATE,
        CAST(NULL AS VARCHAR)                               as STOP_REASON,
        CAST(NULL AS VARCHAR)                               as STOP_CHANNEL,
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG
    from {{ ref('CRM_MEMBER_DEV') }} d
    left join campaign_valid c on d.CMPGN_CD = c.CMPGN_CD
),

stop as (
    select
        COALESCE({{ date_sk("TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD')") }}, 0) as DATE_SK,   -- 범위밖/NULL → 0 (순서9)
        MBER_NO                                             as MEMBER_DK,
        'STOP'                                              as EVENT_TYPE,
        0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK, 0 as ORG_SK, 0 as REASON_SK,
        0 as DEV_CNT, 0 as DEV_MEMBERS,
        1 as STOP_CNT, 1 as STOP_MEMBERS, 0 as UNPAID_STOP_CNT, 0 as UNPAID_STOP_MEMBERS,
        CAST(NULL AS DATE)                                  as JOIN_DATE,
        TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD')             as STOP_DATE,
        DSCNTC_RSN_CD                                       as STOP_REASON,
        DSCNTC_PATH                                         as STOP_CHANNEL,
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG
    from {{ ref('CRM_MEMBER_DISCONTINUE') }}
),

unioned as (
    select * from dev
    union all
    select * from stop
)

select
    DATE_SK, MEMBER_DK, EVENT_TYPE, CAMPAIGN_SK, SPONSORSHIP_SK, ORG_SK, REASON_SK,
    DEV_CNT, DEV_MEMBERS, STOP_CNT, STOP_MEMBERS, UNPAID_STOP_CNT, UNPAID_STOP_MEMBERS,
    JOIN_DATE, STOP_DATE, STOP_REASON, STOP_CHANNEL, NEW_EXISTING_FLAG,
    {{ gold_meta('CRM') }}
from unioned
