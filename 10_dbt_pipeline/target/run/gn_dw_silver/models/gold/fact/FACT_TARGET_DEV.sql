
  
    

        create or replace transient table GN_DW.GOLD.FACT_TARGET_DEV
         as
        (-- FACT_TARGET_DEV: 회원개발 목표 팩트 (CRM_DEV_TARGET, 월×조직×개발구분)
-- Co-authored with CoCo
-- ORG_SK 는 DIM_ORG.ORG_DK(=ABS(HASH(DEPT_ID)))로 해소. Bronze 입고 후 실행.
-- 🔴 D1 임시조치[삭제금지]: materialized=table 로 스캐폴드 행소실 방지. 프로젝트 마감 전 'incremental'(실적재 시) 재전환 검토 필수. 이력/코드 정리 시에도 이 주석 보존.


with t as (
    select * from GN_DW.SILVER.CRM_DEV_TARGET
)

select
    TRY_TO_NUMBER(t.STDR_MT)                      as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,
    t.MBER_DVLP_DIV_CD                            as DEV_TYPE,
    SUM(t.GOAL_CNT)                               as GOAL_CNT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'df029261-a9a2-4be5-9882-1697416aa73a'                    AS DW_BATCH_ID
from t
left join GN_DW.GOLD.DIM_ORG o
    on o.ORG_DK = ABS(HASH(t.DEPT_ID))
group by TRY_TO_NUMBER(t.STDR_MT), COALESCE(o.ORG_SK, 0), t.MBER_DVLP_DIV_CD
        );
      
  