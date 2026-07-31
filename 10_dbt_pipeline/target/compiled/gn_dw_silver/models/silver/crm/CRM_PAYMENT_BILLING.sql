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
  -- W1(DEC-17, 2026-07-31): 결제결과코드 2종 = 사유축 전용. 미납 판정은 DEC-3(PAY_STAT_CD) 불변.
  --   RQEST_RST_CD: 조인은 (코드그룹, 코드) 복합키 필수 — 코드그룹 = SETLE_CD+자릿수 매핑(GOLD W3 소관).
  --   PRCS_RST_CD : PAY_STAT_CD 거울(불일치 0.386%) — 판정·사유 분해에 사용 금지. 원천 보존 목적.
  NULLIF(TRIM(RQEST_RST_CD),'')    AS RQEST_RST_CD,
  NULLIF(TRIM(PRCS_RST_CD),'')     AS PRCS_RST_CD,
  'CRM'                            AS DW_SOURCE_SYSTEM,
  'BRONZE_CRM.TM_PM_MBRFEE_ACMSLT' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID
FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT WHERE MBRFEE_KEY IS NOT NULL
UNION ALL
SELECT
  'DNTN_'||DNTN_KEY, '기부금', NULLIF(TRIM(ONCE_MBER_NO),''), NULLIF(TRIM(SPNSR_BSNS_ID),''), NULL,
  NULL, NULL, NULL, NULL, PAY_AMT, PAY_DE,
  NULLIF(TRIM(PAY_STAT_CD),''), NULLIF(TRIM(SETLE_CD),''), NULL,
  -- W1: 기부금 원천(TM_PM_DNTN_DTLS)에 RQEST_RST_CD·PRCS_RST_CD 컬럼 부재(실측 확인) → NULL 토파드.
  --   SETLE_CD 는 기부금에도 존재하나 결과코드가 없어 사유축 산출 대상 아님.
  NULL, NULL,
  'CRM','BRONZE_CRM.TM_PM_DNTN_DTLS', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), NULL
FROM GN_DW.BRONZE_CRM.TM_PM_DNTN_DTLS WHERE DNTN_KEY IS NOT NULL