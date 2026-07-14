
  
    

        create or replace transient table GN_DW.SILVER.CRM_MEMBER_RESPONSOR
         as
        (-- CRM_MEMBER_RESPONSOR: 재후원 정제 (BRONZE TM_MM_FDRM_MBER_RE_SPNSR → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
SELECT
  NULLIF(TRIM(MBER_NO),'')        AS MBER_NO,
  SER_NO                          AS SER_NO,
  NULLIF(TRIM(RE_SPNSR_DE),'')    AS RE_SPNSR_DE,
  NULLIF(TRIM(REGIST_DEPT_CD),'') AS REGIST_DEPT_CD,
  'CRM'                           AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()             AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()             AS DW_UPDATE_TS,
  NULL                            AS DW_BATCH_ID
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR
WHERE MBER_NO IS NOT NULL AND SER_NO IS NOT NULL AND RE_SPNSR_DE IS NOT NULL
        );
      
  