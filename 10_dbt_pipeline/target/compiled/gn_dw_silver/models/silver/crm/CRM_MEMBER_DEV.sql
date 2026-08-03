-- CRM_MEMBER_DEV: 개발약정 실적 정제 + AREA_CD(CM018)·DVLP_DIV_CD(MM015) 라벨 (BRONZE → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
-- [2026-08-03 O24] DVLP_DIV_NM 신설. 원천 DVLP_DIV_CD 는 정본 컬럼정의서(167행)가 코드그룹 MM015 를 지정하며
--   1=신규 · 2=증액 · 3=감액 · 4=재후원 · 5=후원중단 5종이다(USE_YN 전부 Y). 종전에는 코드만 전파하고
--   라벨을 만들지 않아 하류 GOLD 가 5종을 EVENT_TYPE='DEV' 한 값으로 뭉갰다(O24).
--   컬럼명은 정본 컬럼정의서 504행이 명시한 현업 용어쌍 `DVLP_DIV_CD`/`DVLP_DIV_NM` 을 그대로 쓴다.
SELECT
  NULLIF(TRIM(s.SPNSR_NO),'')      AS SPNSR_NO,
  s.SPNSR_BSNS_NO                  AS SPNSR_BSNS_NO,
  NULLIF(TRIM(s.OCCRRNC_DE),'')    AS OCCRRNC_DE,
  s.SER_NO                         AS SER_NO,
  NULLIF(TRIM(s.MBER_NO),'')       AS MBER_NO,
  NULLIF(TRIM(s.SPNSR_BSNS_ID),'') AS SPNSR_BSNS_ID,
  s.SPNSR_AMT                      AS SPNSR_AMT,
  NULLIF(TRIM(s.DVLP_DIV_CD),'')   AS DVLP_DIV_CD,
  v.DTL_CD_NM                      AS DVLP_DIV_NM,
  NULLIF(TRIM(s.ACT_DEPT_CD),'')   AS ACT_DEPT_CD,
  NULLIF(TRIM(s.ACMSLT_DEPT_CD),'')AS ACMSLT_DEPT_CD,
  NULLIF(TRIM(s.CMPGN_CD),'')      AS CMPGN_CD,
  NULLIF(TRIM(s.SETLE_CD),'')      AS SETLE_CD,
  NULLIF(TRIM(s.AREA_CD),'')       AS AREA_CD,
  a.DTL_CD_NM                      AS AREA_NM,
  s.AGE                            AS AGE,
  -- [2026-08-03 G3] 정본 코드컬럼 raw 전파(라벨 미배선 — 수요 확인 후 별도).
  NULLIF(TRIM(s.CANCL_RDCAMT_RSN_CD),'') AS CANCL_RDCAMT_RSN_CD,  -- MM002 (31종 중 18종 폐지코드)
  NULLIF(TRIM(s.MBER_DIV_CD),'')   AS MBER_DIV_CD,   -- MM018
  NULLIF(TRIM(s.SEX),'')           AS SEX,           -- CM013 raw. ⚠️CRM_MEMBER.SEX 는 M/F/U 정규화값 — 동명이의
  NULLIF(TRIM(s.SPNSR_AMT_CD),'')  AS SPNSR_AMT_CD,  -- CM012
  'CRM'                            AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT s
LEFT JOIN GN_DW.SILVER.CRM_CODE a ON a.CD_ID='CM018' AND a.DTL_CD_ID=NULLIF(TRIM(s.AREA_CD),'')
-- MM015 = 정본 컬럼정의서 167행이 DVLP_DIV_CD 에 지정한 코드그룹. CRM_CODE PK=(CD_ID,DTL_CD_ID) 이므로
-- 이 조인은 fan-out 을 만들지 않는다(행수 불변 검증 대상).
LEFT JOIN GN_DW.SILVER.CRM_CODE v ON v.CD_ID='MM015' AND v.DTL_CD_ID=NULLIF(TRIM(s.DVLP_DIV_CD),'')
WHERE s.SPNSR_NO IS NOT NULL AND s.SPNSR_BSNS_NO IS NOT NULL AND s.OCCRRNC_DE IS NOT NULL AND s.SER_NO IS NOT NULL