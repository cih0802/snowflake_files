-- CRM_MARKETING_CAMPAIGN: 마케팅캠페인 마스터 정제 (BRONZE TC_MKTNG_DTL_CD C001 → SILVER)
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-08-06 O44 · 2026-09-16 O162 개정]
-- ----------------------------------------------------------------------------
-- 🔴 2026-09-15 원천 TM_CM_MKTNG_CMPGN_MNG 가 삭제되고 TC_MKTNG_DTL_CD 로 통합됨.
--    dbt 모델에서는 TC_MKTNG_DTL_CD (CD_ID='C001' 마케팅캠페인명) 필터링으로 재정의되어 상위 호환성 유지.
-- ============================================================================
SELECT
  NULLIF(TRIM(DTL_CD_ID),'')          AS MK_CMPGN_CD,      -- PK. `TM_CM_CMPGN_MNG.MKTG_CMPGN_NM`(NUMBER)의 문자 표현
  NULLIF(TRIM(DTL_CD_NM),'')          AS MK_CMPGN_NM,      -- 마케팅캠페인명. AGENCY `CAMPAIGN_NM` 과 이름 매칭되는 축
  NULLIF(TRIM(USE_YN),'')             AS USE_YN,           -- 원천 그대로(제외 금지 — 폐지분도 과거 실적에 붙는다)
  NULLIF(TRIM(RM),'')                 AS RM,               -- 비고
  'CRM'                               AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()                 AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                 AS DW_UPDATE_TS,
  NULL                                AS DW_BATCH_ID
FROM GN_DW.BRONZE_CRM.TC_MKTNG_DTL_CD
WHERE CD_ID = 'C001'
  AND DTL_CD_ID IS NOT NULL