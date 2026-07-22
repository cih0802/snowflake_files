-- FACT_MEMBER_MONTHLY: 회원 월 팩트 (billing ∪ FME 스파인) — A1: 개발/중단 FME 롤업 + HAS_BILLING 출처플래그
-- Co-authored with CoCo
-- ✅ A1(2026-07-21): 스파인 = 회비(CRM_PAYMENT_BILLING) ∪ 개발/중단(FACT_MEMBER_EVENT 월 롤업).
--    · 개발/중단이 난 달(납입無 ~2.26M 월×회원)도 포함 → DEV/STOP 온전 집계(과소집계 해소).
--    · HAS_BILLING=TRUE  → 구 billing 스파인(≈37.79M)과 동일. 회비/청구/미납 지표 불변. (보수적 소비: WHERE HAS_BILLING)
--    · HAS_BILLING=FALSE → 개발/중단만 있는 월(회비 measure NULL). (정확 소비: 필터 없이 전체)
-- ⚠️ 스캐폴드 잔여(전건 0/NULL): ACTIVE/증감/누계/미납건·CAMPAIGN/SPONSORSHIP/PAYMENT/REASON_SK·DEV_TYPE·밴드·플래그
--    → 상태이력(CRM_MEMBER_STATUS_HIST)·금액변경(CRM_MEMBER_AMT_CHANGE) 원천 + O8 grain 규칙(B2) 후속.
-- ⚠️ DEV_CNT = FME 사건수(금액/10000 아님 — 06_DDL 주석/별도트랙).
-- 순서9(G-1/G-2 해소): incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.
-- 순서9-C(#80/DEC-4): UNPAID_FLAG_EOM/BOM — 미납 = PAY_STAT_CD IN ('F', NULL).
{{ config(
    tags=['gold_pending']
) }}

with b as (
    select * from {{ ref('CRM_PAYMENT_BILLING') }}
),

-- 회비/청구 집계 (월×회원) — 구 로직 유지(멱등)
billing as (
    select
        COALESCE({{ month_key_clamp('TRY_TO_NUMBER(MBRFEE_MT)') }}, {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM'))") }}, 0) as MONTH_KEY,  -- 회비월 우선, 무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월
        MBER_NO                                       as MEMBER_DK,
        SUM(PAY_AMT)                                  as PAID_FEE,
        SUM(RQEST_AMT)                                as BILLED_AMT,
        -- #80(DEC-4): 월×회원에 미납 청구행(PAY_STAT_CD='F' OR NULL)이 하나라도 있으면 월말 미납.
        BOOLOR_AGG(PAY_STAT_CD = 'F' OR PAY_STAT_CD IS NULL)  as UNPAID_FLAG_EOM
    from b
    where MBER_NO is not null                         -- 순수 불량 5행 제외(NOT NULL MEMBER_DK)
    group by MONTH_KEY, MEMBER_DK
),

-- 개발/중단 월 롤업 (월×회원) — FME(일 grain) → 월 집계. A1 핵심.
fme_rollup as (
    select
        FLOOR(DATE_SK / 100)                          as MONTH_KEY,   -- YYYYMMDD→YYYYMM (FME DATE_SK 는 이미 범위클램프; 0 → 0=Unknown월)
        MEMBER_DK,
        SUM(DEV_CNT)                                  as DEV_CNT,      -- 개발 사건수 합
        IFF(SUM(DEV_CNT) > 0, 1, 0)                    as DEV_MEMBERS,  -- 월×회원 grain: 개발발생 1/0 (다월 SUM 시 distinct 회원수)
        SUM(STOP_CNT)                                 as STOP_CNT,      -- 중단 사건수 합
        IFF(SUM(STOP_CNT) > 0, 1, 0)                   as STOP_MEMBERS
    from {{ ref('FACT_MEMBER_EVENT') }}
    group by MONTH_KEY, MEMBER_DK
),

-- 통합 스파인 = billing ∪ fme (월×회원 유일)
spine as (
    select MONTH_KEY, MEMBER_DK from billing
    union
    select MONTH_KEY, MEMBER_DK from fme_rollup
),

joined as (
    select
        sp.MONTH_KEY,
        sp.MEMBER_DK,
        0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK, 0 as PAYMENT_SK, 0 as REASON_SK,   -- B2(O8 규칙) 후속
        COALESCE(fr.DEV_CNT, 0)      as DEV_CNT,
        COALESCE(fr.DEV_MEMBERS, 0)  as DEV_MEMBERS,
        COALESCE(fr.STOP_CNT, 0)     as STOP_CNT,
        0 as UNPAID_CNT,
        0 as ACTIVE_CNT, 0 as ACTIVE_MEMBERS, 0 as ACTIVE_CUM_CNT, 0 as ACTIVE_CUM_MEMBERS,
        0 as INCREASE_CNT, 0 as INCREASE_MEMBERS, 0 as DECREASE_CNT, 0 as CHURN_CNT,
        0 as YEAR_START_ACTIVE_CNT, 0 as YEAR_END_ACTIVE_CNT,
        0 as MONTH_END_ACTIVE_CNT, 0 as PREV_MONTH_END_ACTIVE_CNT,
        0 as CAMPAIGN_UNPAID_CNT, 0 as STATUS_UNPAID_CNT,
        0 as REGULAR_FEE, 0 as REGULAR_ONETIME_FEE, 0 as ONETIME_ONETIME_FEE,
        bl.PAID_FEE,
        bl.BILLED_AMT,
        0 as INBOUND_CALL_CNT, 0 as TS_CALL_CNT,       -- ⚠️ 비-CRM 수기 미수령(C-8)
        CAST(NULL AS VARCHAR)  as DEV_TYPE,
        CAST(NULL AS BOOLEAN)  as NEW_FLAG, CAST(NULL AS BOOLEAN) as INCREASE_FLAG, CAST(NULL AS BOOLEAN) as REDONATE_FLAG,
        CAST(NULL AS DATE)     as JOIN_DATE, CAST(NULL AS DATE) as STOP_DATE,
        CAST(NULL AS VARCHAR)  as AMOUNT_BAND1, CAST(NULL AS VARCHAR) as AMOUNT_BAND2,
        CAST(NULL AS VARCHAR)  as PERIOD_BAND1, CAST(NULL AS VARCHAR) as PERIOD_BAND2,
        0 as SPONSOR_MONTHS, 0 as SPONSOR_YEARS, 0 as PAID_MONTHS,
        CAST(NULL AS VARCHAR)  as NEW_EXISTING_FLAG,
        bl.UNPAID_FLAG_EOM,
        -- A1: 출처 플래그. billing 매칭 행 존재 여부(billing MEMBER_DK 는 group 키라 매칭 시 non-null).
        IFF(bl.MEMBER_DK IS NOT NULL, TRUE, FALSE)     as HAS_BILLING,
        {{ gold_meta('CRM') }}
    from spine sp
    left join billing    bl on sp.MONTH_KEY = bl.MONTH_KEY and sp.MEMBER_DK = bl.MEMBER_DK
    left join fme_rollup fr on sp.MONTH_KEY = fr.MONTH_KEY and sp.MEMBER_DK = fr.MEMBER_DK
)

select
    j.*,
    -- #80 월초(BOM) = 전월말(EOM) 상태. 회원별 월순 LAG(union 스파인 전체 월 기준; 결측월은 직전 존재월 근사).
    LAG(j.UNPAID_FLAG_EOM) OVER (PARTITION BY j.MEMBER_DK ORDER BY j.MONTH_KEY)  as UNPAID_FLAG_BOM
from joined j
