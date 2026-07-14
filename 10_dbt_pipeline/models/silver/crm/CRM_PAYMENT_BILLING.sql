-- CRM_PAYMENT_BILLING: 결제(청구·납입) = 회비 ∪ 기부금 (PAY_KEY 접두 통합키), 정본 09 STEP3.
-- Co-authored with CoCo
SELECT
  'MBRFEE_'||MBRFEE_KEY            AS PAY_KEY,
  '회비'                           AS PAYMENT_TYPE,
  NULLIF(TRIM(MBER_NO),'')         AS MBER_NO,
  NULLIF(TRIM(SPNSR_BSNS_ID),'')   AS SPNSR_BSNS_ID,
  RELATNSP_KEY                     AS RELATNSP_KEY,
  NULLIF(TRIM(MBRFEE_MT),'')       AS MBRFEE_MT,
  MBRFEE_SQNC                      AS MBRFEE_SQNC,
  RQEST_AMT                        AS RQEST_AMT,
  RQEST_DE                         AS RQEST_DE,
  PAY_AMT                          AS PAY_AMT,
  PAY_DE                           AS PAY_DE,
  NULLIF(TRIM(PAY_STAT_CD),'')     AS PAY_STAT_CD,
  NULLIF(TRIM(SETLE_CD),'')        AS SETLE_CD,
  NULLIF(TRIM(GFT_DIV_CD),'')      AS GFT_DIV_CD,
  'CRM'                            AS DW_SOURCE_SYSTEM,
  'BRONZE_CRM.TM_PM_MBRFEE_ACMSLT' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID
FROM {{ source('bronze_crm','TM_PM_MBRFEE_ACMSLT') }} WHERE MBRFEE_KEY IS NOT NULL
UNION ALL
SELECT
  'DNTN_'||DNTN_KEY, '기부금', NULLIF(TRIM(ONCE_MBER_NO),''), NULLIF(TRIM(SPNSR_BSNS_ID),''), NULL,
  NULL, NULL, NULL, NULL, PAY_AMT, PAY_DE,
  NULLIF(TRIM(PAY_STAT_CD),''), NULLIF(TRIM(SETLE_CD),''), NULL,
  'CRM','BRONZE_CRM.TM_PM_DNTN_DTLS', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), NULL
FROM {{ source('bronze_crm','TM_PM_DNTN_DTLS') }} WHERE DNTN_KEY IS NOT NULL
