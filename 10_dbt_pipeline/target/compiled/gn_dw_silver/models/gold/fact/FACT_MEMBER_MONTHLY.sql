-- FACT_MEMBER_MONTHLY: 회원 월간 스냅샷 팩트 스캐폴드 (CRM_PAYMENT_BILLING, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ 스캐폴드: 월×회원 grain 에 납입/청구액만 집계. 활동/증감/누적/밴드/플래그 등 대다수 지표는
--    회원상태·개발·증감 통합 로직 필요 → 입고 후 확장. 차원 SK(CAMPAIGN/SPONSORSHIP/PAYMENT/REASON)=0 센티넬.
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.


with b as (
    select * from GN_DW.SILVER.CRM_PAYMENT_BILLING
)

select
    COALESCE(CASE WHEN TRY_TO_NUMBER(MBRFEE_MT) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(MBRFEE_MT), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(MBRFEE_MT) END, CASE WHEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) END, 0) as MONTH_KEY,  -- 회비월(YYYYMM 검증) 우선, 무효/NULL 이면 납입월(검증) 폴백, 둘 다 무효면 0=Unknown월 (순서9-B: 쓰레기 월키 차단)
    MBER_NO                                       as MEMBER_DK,
    0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK, 0 as PAYMENT_SK, 0 as REASON_SK,
    0 as DEV_CNT, 0 as DEV_MEMBERS, 0 as STOP_CNT, 0 as UNPAID_CNT,
    0 as ACTIVE_CNT, 0 as ACTIVE_MEMBERS, 0 as ACTIVE_CUM_CNT, 0 as ACTIVE_CUM_MEMBERS,
    0 as INCREASE_CNT, 0 as INCREASE_MEMBERS, 0 as DECREASE_CNT, 0 as CHURN_CNT,
    0 as YEAR_START_ACTIVE_CNT, 0 as YEAR_END_ACTIVE_CNT,
    0 as MONTH_END_ACTIVE_CNT, 0 as PREV_MONTH_END_ACTIVE_CNT,
    0 as CAMPAIGN_UNPAID_CNT, 0 as STATUS_UNPAID_CNT,
    0 as REGULAR_FEE, 0 as REGULAR_ONETIME_FEE, 0 as ONETIME_ONETIME_FEE,
    SUM(PAY_AMT)                                  as PAID_FEE,
    SUM(RQEST_AMT)                                as BILLED_AMT,
    0 as INBOUND_CALL_CNT, 0 as TS_CALL_CNT,      -- ⚠️ 비-CRM 수기 미수령
    CAST(NULL AS VARCHAR)                          as DEV_TYPE,
    CAST(NULL AS BOOLEAN) as NEW_FLAG, CAST(NULL AS BOOLEAN) as INCREASE_FLAG, CAST(NULL AS BOOLEAN) as REDONATE_FLAG,
    CAST(NULL AS DATE) as JOIN_DATE, CAST(NULL AS DATE) as STOP_DATE,
    CAST(NULL AS VARCHAR) as AMOUNT_BAND1, CAST(NULL AS VARCHAR) as AMOUNT_BAND2,
    CAST(NULL AS VARCHAR) as PERIOD_BAND1, CAST(NULL AS VARCHAR) as PERIOD_BAND2,
    0 as SPONSOR_MONTHS, 0 as SPONSOR_YEARS, 0 as PAID_MONTHS,
    CAST(NULL AS VARCHAR)                          as NEW_EXISTING_FLAG,
    CAST(NULL AS BOOLEAN) as UNPAID_FLAG_BOM, CAST(NULL AS BOOLEAN) as UNPAID_FLAG_EOM,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'ecb2a2a1-80f3-4f9b-b682-52f3bd552714'                    AS DW_BATCH_ID
from b
where MBER_NO is not null                         -- 순수 불량 5행 제외(NOT NULL MEMBER_DK)
group by MONTH_KEY, MEMBER_DK                      -- 순서9-B: 출력 별칭으로 group by(MONTH_KEY 검증식 중복 제거·정합 보장)