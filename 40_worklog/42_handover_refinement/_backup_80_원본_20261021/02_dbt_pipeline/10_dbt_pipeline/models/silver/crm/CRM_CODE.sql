-- CRM_CODE: 공통 코드상세 정제 (BRONZE TC_CMMN_DTL_CD → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
SELECT
  NULLIF(TRIM(CD_ID),'')       AS CD_ID,
  NULLIF(TRIM(DTL_CD_ID),'')   AS DTL_CD_ID,
  NULLIF(TRIM(DTL_CD_NM),'')   AS DTL_CD_NM,
  NULLIF(TRIM(UPPER_CD_ID),'') AS UPPER_CD_ID,
  SORT_ORDR                    AS SORT_ORDR,
  NULLIF(TRIM(USE_YN),'')      AS USE_YN,
  'CRM'                        AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()          AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()          AS DW_UPDATE_TS,
  NULL                         AS DW_BATCH_ID,
  -- 🆕 [2026-09-30 O191-E · 2차-B 2단] 누락 컬럼 4종(문서32 §3) — 감사컬럼 뒤 ordinal 말미
  NULLIF(TRIM(DTL_CD_DC),'')   AS DTL_CD_DC,
  NULLIF(TRIM(CD_ATRB1),'')    AS CD_ATRB1,
  NULLIF(TRIM(CD_ATRB2),'')    AS CD_ATRB2,
  NULLIF(TRIM(CD_ATRB3),'')    AS CD_ATRB3
FROM {{ source('bronze_crm','TC_CMMN_DTL_CD') }}
WHERE CD_ID IS NOT NULL AND DTL_CD_ID IS NOT NULL
