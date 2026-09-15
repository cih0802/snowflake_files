-- CRM_MKTNG_CODE: 마케팅 통합 코드 사전 정제 (BRONZE TC_MKTNG_DTL_CD → SILVER)
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-09-16 O162 신설]
-- ----------------------------------------------------------------------------
-- 마케팅캠페인(C001), 채널(C002), UTM(U001) 통합 코드 사전 모델.
-- 기존 공통코드(TC_CMMN_CD/TC_CMMN_DTL_CD)와 분리된 독자 네임스페이스.
-- ============================================================================
SELECT
  NULLIF(TRIM(CD_ID),'')              AS CD_ID,            -- PK. 코드그룹 ID (C001, C002, U001)
  NULLIF(TRIM(DTL_CD_ID),'')          AS DTL_CD_ID,        -- PK. 상세코드 ID
  NULLIF(TRIM(CD_NM),'')              AS CD_NM,            -- 코드그룹명
  NULLIF(TRIM(DTL_CD_NM),'')          AS DTL_CD_NM,        -- 상세코드명 (라벨)
  SORT_ORDR                           AS SORT_ORDR,        -- 정렬순서
  NULLIF(TRIM(USE_YN),'')             AS USE_YN,           -- 사용여부 Y/N
  NULLIF(TRIM(RM),'')                 AS RM,               -- 비고
  NULLIF(TRIM(CD_ATRB1),'')           AS CD_ATRB1,         -- 코드속성1
  NULLIF(TRIM(CD_ATRB2),'')           AS CD_ATRB2,         -- 코드속성2
  NULLIF(TRIM(CD_ATRB3),'')           AS CD_ATRB3,         -- 코드속성3
  'CRM'                               AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()                 AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                 AS DW_UPDATE_TS,
  NULL                                AS DW_BATCH_ID
FROM {{ source('bronze_crm','TC_MKTNG_DTL_CD') }}
WHERE CD_ID IS NOT NULL
  AND DTL_CD_ID IS NOT NULL
