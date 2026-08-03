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
  -- [2026-08-03 G3] 정본 코드컬럼 raw 전파. 라벨은 수요 확인 후 별도 배선(스캐폴드 금지).
  NULLIF(TRIM(CPR_DIV_CD),'')      AS CPR_DIV_CD,     -- CM019 (회비·기부금 양쪽 존재)
  NULLIF(TRIM(MBER_DIV_CD),'')     AS MBER_DIV_CD,    -- MM018 (회비 전용)
  NULLIF(TRIM(MBRFEE_DIV_CD),'')   AS MBRFEE_DIV_CD,  -- PM010 (회비 전용)
  NULLIF(TRIM(OPERT_DIV_CD),'')    AS OPERT_DIV_CD,   -- MM014 (회비 전용)
  NULLIF(TRIM(PRCS_STAT_CD),'')    AS MBRFEE_PRCS_STAT_CD,  -- PM013 회비 전용. [O26] 원천 테이블 변별토큰 MBRFEE 접두 — CRM_SEND_REQUEST.PSTMTR_PRCS_STAT_CD(MS061)와 도메인이 완전히 다르다(R,F,S vs 0,1)
  NULLIF(TRIM(RETUN_RSN_CD),'')    AS RETUN_RSN_CD,   -- PM042 (회비·기부금 양쪽 존재)
  NULLIF(TRIM(RQEST_DIV_CD),'')    AS RQEST_DIV_CD,   -- PM024 (회비 전용)
  'CRM'                            AS DW_SOURCE_SYSTEM,
  'BRONZE_CRM.TM_PM_MBRFEE_ACMSLT' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID
FROM {{ source('bronze_crm','TM_PM_MBRFEE_ACMSLT') }} WHERE MBRFEE_KEY IS NOT NULL
UNION ALL
SELECT
  'DNTN_'||DNTN_KEY, '기부금', NULLIF(TRIM(ONCE_MBER_NO),''), NULLIF(TRIM(SPNSR_BSNS_ID),''), NULL,
  NULL, NULL, NULL, NULL, PAY_AMT, PAY_DE,
  NULLIF(TRIM(PAY_STAT_CD),''), NULLIF(TRIM(SETLE_CD),''), NULL,
  -- W1: 기부금 원천(TM_PM_DNTN_DTLS)에 RQEST_RST_CD·PRCS_RST_CD 컬럼 부재(실측 확인) → NULL 토파드.
  --   SETLE_CD 는 기부금에도 존재하나 결과코드가 없어 사유축 산출 대상 아님.
  NULL, NULL,
  -- [2026-08-03 G3] 위 회비 브랜치와 동일 순서. 기부금 원천에 없는 컬럼은 NULL(개념 부재).
  --   ⚠️ MBRFEE_PRCS_STAT_CD 의 기부금측 동명 컬럼(TM_PM_DNTN_DTLS.PRCS_STAT_CD)은 정본이 코드그룹을 지정하지 않았다.
  --      코드체계가 다를 수 있어 채우면 O16형 의미혼입이 된다 → 코드그룹 확정 후 배선.
  NULLIF(TRIM(CPR_DIV_CD),''),                    -- CPR_DIV_CD (CM019)
  NULL, NULL, NULL, NULL,                         -- MBER_DIV_CD·MBRFEE_DIV_CD·OPERT_DIV_CD·MBRFEE_PRCS_STAT_CD
  NULLIF(TRIM(RETUN_RSN_CD),''),                  -- RETUN_RSN_CD (PM042)
  NULL,                                           -- RQEST_DIV_CD
  'CRM','BRONZE_CRM.TM_PM_DNTN_DTLS', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), NULL
FROM {{ source('bronze_crm','TM_PM_DNTN_DTLS') }} WHERE DNTN_KEY IS NOT NULL
