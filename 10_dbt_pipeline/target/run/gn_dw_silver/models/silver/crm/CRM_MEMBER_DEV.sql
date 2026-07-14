
  
    

        create or replace transient table GN_DW.SILVER.CRM_MEMBER_DEV
         as
        (-- CRM_MEMBER_DEV: 개발약정 실적 정제 + AREA_CD(CM018) 라벨 (BRONZE → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
SELECT
  NULLIF(TRIM(s.SPNSR_NO),'')      AS SPNSR_NO,
  s.SPNSR_BSNS_NO                  AS SPNSR_BSNS_NO,
  NULLIF(TRIM(s.OCCRRNC_DE),'')    AS OCCRRNC_DE,
  s.SER_NO                         AS SER_NO,
  NULLIF(TRIM(s.MBER_NO),'')       AS MBER_NO,
  NULLIF(TRIM(s.SPNSR_BSNS_ID),'') AS SPNSR_BSNS_ID,
  s.SPNSR_AMT                      AS SPNSR_AMT,
  NULLIF(TRIM(s.DVLP_DIV_CD),'')   AS DVLP_DIV_CD,
  NULLIF(TRIM(s.ACT_DEPT_CD),'')   AS ACT_DEPT_CD,
  NULLIF(TRIM(s.ACMSLT_DEPT_CD),'')AS ACMSLT_DEPT_CD,
  NULLIF(TRIM(s.CMPGN_CD),'')      AS CMPGN_CD,
  NULLIF(TRIM(s.SETLE_CD),'')      AS SETLE_CD,
  NULLIF(TRIM(s.AREA_CD),'')       AS AREA_CD,
  a.DTL_CD_NM                      AS AREA_NM,
  s.AGE                            AS AGE,
  'CRM'                            AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT s
LEFT JOIN GN_DW.SILVER.CRM_CODE a ON a.CD_ID='CM018' AND a.DTL_CD_ID=NULLIF(TRIM(s.AREA_CD),'')
WHERE s.SPNSR_NO IS NOT NULL AND s.SPNSR_BSNS_NO IS NOT NULL AND s.OCCRRNC_DE IS NOT NULL AND s.SER_NO IS NOT NULL
        );
      
  