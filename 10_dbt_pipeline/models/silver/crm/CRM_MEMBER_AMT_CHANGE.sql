-- CRM_MEMBER_AMT_CHANGE: 증액/감액 정제 + AREA_CD(CM018) 라벨 (BRONZE → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
SELECT
  NULLIF(TRIM(s.OCCRRNC_DE),'')     AS OCCRRNC_DE,
  s.SER_NO                          AS SER_NO,
  NULLIF(TRIM(s.MBER_NO),'')        AS MBER_NO,
  s.SPNSR_AMT                       AS SPNSR_AMT,
  NULLIF(TRIM(s.RDCAMT_YN),'')      AS RDCAMT_YN,
  NULLIF(TRIM(s.ACMSLT_DEPT_CD),'') AS ACMSLT_DEPT_CD,
  NULLIF(TRIM(s.CMPGN_CD),'')       AS CMPGN_CD,
  NULLIF(TRIM(s.AREA_CD),'')        AS AREA_CD,
  a.DTL_CD_NM                       AS AREA_NM,
  s.AGE                             AS AGE,
  'CRM'                             AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()               AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()               AS DW_UPDATE_TS,
  NULL                              AS DW_BATCH_ID
FROM {{ source('bronze_crm','TM_MM_FDRM_MBER_IRSD') }} s
LEFT JOIN {{ ref('CRM_CODE') }} a ON a.CD_ID='CM018' AND a.DTL_CD_ID=NULLIF(TRIM(s.AREA_CD),'')
WHERE s.OCCRRNC_DE IS NOT NULL AND s.SER_NO IS NOT NULL
