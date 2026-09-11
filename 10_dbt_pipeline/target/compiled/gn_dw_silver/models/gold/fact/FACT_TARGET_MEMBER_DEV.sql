-- FACT_TARGET_MEMBER_DEV: 회원개발 목표 팩트 (CRM_DEV_TARGET, 월×조직×개발구분)
-- Co-authored with CoCo


with t as (
    select * from GN_DW.SILVER.CRM_DEV_TARGET
    where COALESCE(GOAL_CNT, 0) > 0
)

select
    COALESCE(CASE WHEN TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')) END, 0) as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,
    t.MBER_DVLP_DIV_CD                            as DEV_TYPE,
    SUM(t.GOAL_CNT)                               as GOAL_CNT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '025f9ac5-d9be-4588-8381-cd1bfa260b2e'                    AS DW_BATCH_ID
from t
left join GN_DW.GOLD.DIM_ORG o
    on o.ORG_DK = ABS(HASH(t.DEPT_ID))
group by
    COALESCE(CASE WHEN TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')) END, 0),
    COALESCE(o.ORG_SK, 0),
    t.MBER_DVLP_DIV_CD