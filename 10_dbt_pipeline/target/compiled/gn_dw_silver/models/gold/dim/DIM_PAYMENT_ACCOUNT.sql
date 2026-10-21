-- =============================================================================
-- Purpose    : 입금·결제 계정 차원 = 기관 계좌 ∪ 결제사 계정 — CRM_INSTT_ACCOUNT · CRM_SETLE_CMPNY_ACCOUNT
-- Target     : GOLD.DIM_PAYMENT_ACCOUNT (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_INSTT_ACCOUNT, ref CRM_SETLE_CMPNY_ACCOUNT
-- Issue      : O188-F
-- =============================================================================
-- DIM_PAYMENT_ACCOUNT: 입금·결제 계정 차원 = 기관 계좌 ∪ 결제사 계정 — CRM_INSTT_ACCOUNT · CRM_SETLE_CMPNY_ACCOUNT
--  [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
-- WARN: 계좌번호(ACCTNO)는 SILVER 에서 제외됐다. 결제사 계정은 ACNUT_SER_NO 로 기관 계좌를 참조한다.


select
    ABS(HASH(COALESCE(CAST('INSTT' AS VARCHAR), '∅') || '‖' || COALESCE(CAST(ACNUT_SER_NO AS VARCHAR), '∅')))       as PAYMENT_ACCOUNT_SK,
    'INSTT'                                          as ACCOUNT_KIND,
    TO_VARCHAR(ACNUT_SER_NO)                         as ACCOUNT_KEY,
    CPR_DIV_CD, ACNUT_DIV_CD as ACCOUNT_DIV_CD, BANK_CD, ACNUT_PRP as ACCOUNT_PURPOSE, ACNUT_ABRV as ACCOUNT_ABBR,
    CHRG_DEPT_CD, REGIST_USE_YN, USE_YN,
    CAST(NULL AS VARCHAR)                            as SETLE_CMPNY_ACNT_ID,
    ACNUT_SER_NO                                     as INSTT_ACNUT_SER_NO,
    CAST(NULL AS VARCHAR)                            as RM,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID
from GN_DW.SILVER.CRM_INSTT_ACCOUNT
union all
select
    ABS(HASH(COALESCE(CAST('SETLE_CMPNY' AS VARCHAR), '∅') || '‖' || COALESCE(CAST(SETLE_CMPNY_ACNT_NO AS VARCHAR), '∅'))),
    'SETLE_CMPNY',
    TO_VARCHAR(SETLE_CMPNY_ACNT_NO),
    CPR_DIV_CD, SETLE_CMPNY_ACNT_DIV_CD, NULL, ACNT_PRP, NULL,
    NULL, NULL, USE_YN,
    SETLE_CMPNY_ACNT_ID,
    ACNUT_SER_NO,
    RM,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID
from GN_DW.SILVER.CRM_SETLE_CMPNY_ACCOUNT