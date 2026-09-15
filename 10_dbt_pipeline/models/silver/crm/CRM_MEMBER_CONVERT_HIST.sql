-- CRM_MEMBER_CONVERT_HIST: 일시→정기 회원 전환 매핑 이력 정제 (BRONZE TM_MM_FDRM_MBER_DT_DTLS → SILVER)
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-09-16 O162 신설]
-- ----------------------------------------------------------------------------
-- 회비이관 시에만 기록되는 일시→정기 회원 매핑 이력.
-- ============================================================================
SELECT
  NULLIF(TRIM(MBER_NO),'')            AS MBER_NO,          -- PK. 정기회원번호 (전환 후)
  NULLIF(TRIM(ONCE_MBER_NO),'')       AS ONCE_MBER_NO,     -- PK. 일시후원회원번호 (전환 전)
  FRST_REGIST_DT                      AS FRST_REGIST_DT,   -- 전환/최초등록일시
  'CRM'                               AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()                 AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                 AS DW_UPDATE_TS,
  NULL                                AS DW_BATCH_ID
FROM {{ source('bronze_crm','TM_MM_FDRM_MBER_DT_DTLS') }}
WHERE MBER_NO IS NOT NULL
  AND ONCE_MBER_NO IS NOT NULL
