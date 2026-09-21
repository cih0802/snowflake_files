-- CRM_MEMBER_DISCONTINUE: 후원중단 정제 + 사유(MM005)·경로(MM287) 라벨 (BRONZE → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
-- [2026-08-03 O25/G3] DSCNTC_PATH_NM 신설. 원천 DSCNTC_PATH 는 raw 코드 1/2/3 이며 MM287 라벨이
--   SYSTEM/CRM/홈페이지 다 — 코드만 GOLD 로 올려서 현업이 숫자만 보던 상태를 해소한다.
--   ⚠️ 두 라벨 조인 모두 USE_YN 필터를 걸지 않는다. MM005 실측 20종 중 6종(366행)이 폐지코드이며
--      USE_YN='Y' 를 걸면 그 라벨이 조용히 NULL 이 된다(G2 §2-4 경고의 실측 확인).
SELECT
  NULLIF(TRIM(s.MBER_NO),'')         AS MBER_NO,
  NULLIF(TRIM(s.SPNSR_DSCNTC_DE),'') AS SPNSR_DSCNTC_DE,
  s.SER_NO                           AS SER_NO,
  NULLIF(TRIM(s.DSCNTC_RSN_CD),'')   AS DSCNTC_RSN_CD,
  cd.DTL_CD_NM                       AS DSCNTC_RSN_NM,
  NULLIF(TRIM(s.DSCNTC_PATH),'')     AS DSCNTC_PATH,
  pt.DTL_CD_NM                       AS DSCNTC_PATH_NM,
  NULLIF(TRIM(s.REGIST_DEPT_CD),'')  AS REGIST_DEPT_CD,
  'CRM'                              AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()                AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                AS DW_UPDATE_TS,
  NULL                               AS DW_BATCH_ID
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC s
LEFT JOIN GN_DW.SILVER.CRM_CODE cd ON cd.CD_ID='MM005' AND cd.DTL_CD_ID = NULLIF(TRIM(s.DSCNTC_RSN_CD),'')
-- MM287 = 정본 컬럼정의서가 DSCNTC_PATH 에 지정한 코드그룹. CRM_CODE PK=(CD_ID,DTL_CD_ID) 이므로 fan-out 없음.
LEFT JOIN GN_DW.SILVER.CRM_CODE pt ON pt.CD_ID='MM287' AND pt.DTL_CD_ID = NULLIF(TRIM(s.DSCNTC_PATH),'')
WHERE s.MBER_NO IS NOT NULL AND s.SPNSR_DSCNTC_DE IS NOT NULL AND s.SER_NO IS NOT NULL