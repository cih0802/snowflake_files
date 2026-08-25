-- CRM_ORG: 부서(조직) 마스터 정제 (BRONZE TM_CM_DEPT_INFO → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
SELECT
  NULLIF(TRIM(DEPT_ID),'')              AS DEPT_ID,
  NULLIF(TRIM(DEPT_NM),'')              AS DEPT_NM,
  NULLIF(TRIM(UPPER_DEPT_ID),'')        AS UPPER_DEPT_ID,
  NULLIF(TRIM(ACMSLT_UPPER_DEPT_ID),'') AS ACMSLT_UPPER_DEPT_ID,
  NULLIF(TRIM(ACMSLT_DEPT_YN),'')       AS ACMSLT_DEPT_YN,
  STATS_DEPT_LVL                        AS STATS_DEPT_LVL,
  NULLIF(TRIM(USE_YN),'')               AS USE_YN,
  SORT_ORDR                             AS SORT_ORDR,
  'CRM'                                 AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()                   AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                   AS DW_UPDATE_TS,
  NULL                                  AS DW_BATCH_ID
FROM {{ source('bronze_crm','TM_CM_DEPT_INFO') }}
WHERE DEPT_ID IS NOT NULL
