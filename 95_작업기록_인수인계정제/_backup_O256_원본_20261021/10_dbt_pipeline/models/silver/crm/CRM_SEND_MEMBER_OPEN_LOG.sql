-- CRM_SEND_MEMBER_OPEN_LOG: 메시지 발송 메일 오픈 로그 정제 (BRONZE SND_MEMBER_OPEN_LOG → SILVER)
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-09-16 O162 신설]
-- ----------------------------------------------------------------------------
-- 구 SND_MEMBER_LIST.OPEN_DT 가 확장된 오픈 세부 로그.
-- ============================================================================
SELECT
  LOG_SEQ                             AS LOG_SEQ,          -- PK. 로그순번
  REQ_SEQ_NO                          AS REQ_SEQ_NO,       -- 발송요청순번 (→CRM_SEND_REQUEST)
  R_NUM                               AS R_NUM,            -- 순번 (→CRM_SEND_MEMBER)
  NULLIF(TRIM(MBER_NO),'')            AS MBER_NO,          -- 회원번호
  OPEN_DT                             AS OPEN_DT,          -- 오픈일시
  FRST_REGIST_DT                      AS FRST_REGIST_DT,   -- 최초등록일시
  'CRM'                               AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()                 AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                 AS DW_UPDATE_TS,
  NULL                                AS DW_BATCH_ID
FROM {{ source('bronze_crm','SND_MEMBER_OPEN_LOG') }}
WHERE LOG_SEQ IS NOT NULL
