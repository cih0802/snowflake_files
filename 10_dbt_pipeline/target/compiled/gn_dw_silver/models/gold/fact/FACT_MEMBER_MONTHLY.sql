-- FACT_MEMBER_MONTHLY: 회원 월간 스냅샷 팩트 스캐폴드 (CRM_PAYMENT_BILLING, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ 스캐폴드: 월×회원 grain 에 납입/청구액만 집계. 활동/증감/누적/밴드/플래그 등 대다수 지표는
--    회원상태·개발·증감 통합 로직 필요 → 입고 후 확장. 차원 SK(CAMPAIGN/SPONSORSHIP/PAYMENT/REASON)=0 센티넬.
-- 🔴 D1 임시조치[삭제금지]: materialized=table 로 스캐폴드 행소실 방지. 프로젝트 마감 전 'incremental'(다치 FK 실적재 시) 재전환 검토 필수. 이력/코드 정리 시에도 이 주석 보존.


with b as (
    select * from GN_DW.SILVER.CRM_PAYMENT_BILLING
)

select
    TRY_TO_NUMBER(TO_CHAR(PAY_DE::DATE, 'YYYYMM'))               as MONTH_KEY,
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
    '24b70347-040a-40c6-b075-ccde404e290d'                    AS DW_BATCH_ID
from b
group by TRY_TO_NUMBER(TO_CHAR(PAY_DE::DATE, 'YYYYMM')), MBER_NO