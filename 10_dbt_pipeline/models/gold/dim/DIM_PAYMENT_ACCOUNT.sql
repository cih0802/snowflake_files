-- DIM_PAYMENT_ACCOUNT: 입금·결제 계정 차원 = 기관 계좌 ∪ 결제사 계정 — CRM_INSTT_ACCOUNT · CRM_SETLE_CMPNY_ACCOUNT
-- Co-authored with CoCo
-- 🆕 [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
-- 🔴 계좌번호(ACCTNO)는 SILVER 에서 제외됐다. 결제사 계정은 ACNUT_SER_NO 로 기관 계좌를 참조한다.
{{ config(
    materialized='incremental',
    unique_key='PAYMENT_ACCOUNT_SK',
    tags=['gold_pending']
) }}

select
    {{ gold_sk(["'INSTT'", 'ACNUT_SER_NO']) }}       as PAYMENT_ACCOUNT_SK,
    'INSTT'                                          as ACCOUNT_KIND,
    TO_VARCHAR(ACNUT_SER_NO)                         as ACCOUNT_KEY,
    CPR_DIV_CD, ACNUT_DIV_CD as ACCOUNT_DIV_CD, BANK_CD, ACNUT_PRP as ACCOUNT_PURPOSE, ACNUT_ABRV as ACCOUNT_ABBR,
    CHRG_DEPT_CD, REGIST_USE_YN, USE_YN,
    CAST(NULL AS VARCHAR)                            as SETLE_CMPNY_ACNT_ID,
    ACNUT_SER_NO                                     as INSTT_ACNUT_SER_NO,
    CAST(NULL AS VARCHAR)                            as RM,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_INSTT_ACCOUNT') }}
union all
select
    {{ gold_sk(["'SETLE_CMPNY'", 'SETLE_CMPNY_ACNT_NO']) }},
    'SETLE_CMPNY',
    TO_VARCHAR(SETLE_CMPNY_ACNT_NO),
    CPR_DIV_CD, SETLE_CMPNY_ACNT_DIV_CD, NULL, ACNT_PRP, NULL,
    NULL, NULL, USE_YN,
    SETLE_CMPNY_ACNT_ID,
    ACNUT_SER_NO,
    RM,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_SETLE_CMPNY_ACCOUNT') }}
