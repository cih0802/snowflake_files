-- CRM_SEND_MEMBER_LINK_LOG: 메시지 발송 메일 링크 클릭 로그 정제 (BRONZE SND_MEMBER_MAIL_LINK_LOG → SILVER)
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-09-16 O162 신설]
-- ----------------------------------------------------------------------------
-- 메일 링크 클릭 세부 로그.
-- ============================================================================
SELECT
  LOG_SEQ                             AS LOG_SEQ,          -- PK. 로그순번
  REQ_SEQ_NO                          AS REQ_SEQ_NO,       -- 발송요청순번 (→CRM_SEND_REQUEST)
  R_NUM                               AS R_NUM,            -- 순번 (→CRM_SEND_MEMBER)
  NULLIF(TRIM(MBER_NO),'')            AS MBER_NO,          -- 회원번호
  NULLIF(TRIM(LINK_ID),'')            AS LINK_ID,          -- 링크ID
  NULLIF(TRIM(LINK_NM),'')            AS LINK_NM,          -- 링크명
  NULLIF(TRIM(LINK_PAGE),'')          AS LINK_PAGE,        -- 링크페이지
  NULLIF(TRIM(LINK_IMG_URL),'')       AS LINK_IMG_URL,     -- 링크이미지URL
  NULLIF(TRIM(AGENT),'')              AS AGENT,            -- 접속에이전트
  CLICK_DT                            AS CLICK_DT,         -- 클릭일시
  FRST_REGIST_DT                      AS FRST_REGIST_DT,   -- 최초등록일시
  'CRM'                               AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()                 AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                 AS DW_UPDATE_TS,
  NULL                                AS DW_BATCH_ID
FROM GN_DW.BRONZE_CRM.SND_MEMBER_MAIL_LINK_LOG
WHERE LOG_SEQ IS NOT NULL