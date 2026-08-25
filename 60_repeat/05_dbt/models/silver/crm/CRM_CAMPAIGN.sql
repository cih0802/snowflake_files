-- CRM_CAMPAIGN: 캠페인 + 브랜드/마케팅캠페인/분류코드 라벨 LEFT JOIN 정제 (BRONZE → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
-- Q16: MKTG_CMPGN_NM(NUMBER) ↔ MK_CMPGN_CD(TEXT) 조인키 불일치 → TO_VARCHAR 캐스팅 조인. [2026-07-16 재입고로 해소]
-- Q2·Q3: 캠페인 분류 4축 코드→라벨 병행보존(master §3). 코드사전 = ref('CRM_CODE') (CRM_MEMBER 등 기존 모델과 동일 패턴).
--   MM294 캠페인 카테고리(56) · MM293 개발인입경로(16) · MM295 유형1 국내/통합/해외(3) · MM296 유형2 굿즈/기타/사례/사업(4)
--   ⚠️ 유형1 ≠ 사업/사례. 유형1=국내/해외 축, 유형2=사업/사례 축 (GOLD DIM_CAMPAIGN 매핑 시 혼동 금지).
-- 코드 조인키: 캠페인측 코드컬럼=NUMBER vs CRM_CODE.DTL_CD_ID=VARCHAR → TRY_TO_NUMBER(DTL_CD_ID) 로 정규화 비교.
--   (CRM_MEMBER 는 코드컬럼이 VARCHAR 라 TEXT 직접 비교 — 여기만 숫자 정규화가 필요한 이유.)
--   ⚠️ fan-out 안전: (CD_ID, TRY_TO_NUMBER(DTL_CD_ID)) 실측 유일·비숫자 0 (2026-07-16 검증).
--   고아 코드는 라벨 NULL로 남긴다(기지: CMPGN_CTGR_CD=58 23행 · CMPGN_TYPE1_BSN=4 740행).
-- [DEC-신설 예정] 원천 재입고(2026-08-24)로 신규 7컬럼 값 반영 + MM297(공통브랜드) 코드그룹 신설.
--   CMMN_BRND → MM297(14종, 라벨이 MM293 개발인입경로와 상당 중복 — 현업 확인: 별도 축으로 유지, 배선 유지).
--   MKTG_UTM → CRM_CODE 사전이 아니라 신설 원천 TM_CM_MKTNG_UTM(MK_UTM/MK_UTM_NM) 과 연동.
--   조인키: c.MKTG_UTM(NUMBER) = TRY_TO_NUMBER(u.MK_UTM) — u.MK_UTM 191종 유일(fan-out 없음, 2026-08-25 실측).
--   SPNSR_DIV_CD(CM035 정기/일시후원)·CPR_DIV_CD(CM019 통합/사단/사복) 라벨 신설(현업 요건 — GOLD 까지 적재).
SELECT
  NULLIF(TRIM(c.CMPGN_CD),'')       AS CMPGN_CD,
  NULLIF(TRIM(c.CMPGN_NM),'')       AS CMPGN_NM,
  NULLIF(TRIM(c.UPPER_CMPGN_CD),'') AS UPPER_CMPGN_CD,
  NULLIF(TRIM(c.UPPER_CMPGN_YN),'') AS UPPER_CMPGN_YN,
  NULLIF(TRIM(c.BRND_ID),'')        AS BRND_ID,
  NULLIF(TRIM(b.BRND_NM),'')        AS BRND_NM,
  NULLIF(TRIM(c.PR_MTH_CD),'')      AS PR_MTH_CD,
  NULLIF(TRIM(c.SPNSR_BSNS_ID),'')  AS SPNSR_BSNS_ID,
  -- [2026-08-03 G3] 정본 코드컬럼 raw 전파. [2026-08-25] SPNSR_DIV_CD·CPR_DIV_CD 라벨 신설(현업 요건).
  NULLIF(TRIM(c.CMPGN_TRGET_CD),'') AS CMPGN_TRGET_CD,   -- CM002 (라벨 미배선 — 수요 확인 후 별도)
  NULLIF(TRIM(c.CPR_DIV_CD),'')     AS CPR_DIV_CD,       -- CM019
  NULLIF(TRIM(cpr.DTL_CD_NM),'')    AS CPR_DIV_NM,       -- CM019 라벨(통합/사단/사복)
  NULLIF(TRIM(c.SPNSR_DIV_CD),'')   AS SPNSR_DIV_CD,     -- CM035
  NULLIF(TRIM(spnsr.DTL_CD_NM),'')  AS SPNSR_DIV_NM,     -- CM035 라벨(정기후원/일시후원)
  c.CMPGN_CTGR_CD                   AS CMPGN_CTGR_CD,
  NULLIF(TRIM(ctgr.DTL_CD_NM),'')   AS CMPGN_CTGR_NM,
  c.MBER_INFLOW_PATH_CD             AS MBER_INFLOW_PATH_CD,
  NULLIF(TRIM(infl.DTL_CD_NM),'')   AS MBER_INFLOW_PATH_NM,
  c.CMPGN_TYPE1_BSN                 AS CMPGN_TYPE1_BSN,
  NULLIF(TRIM(ty1.DTL_CD_NM),'')    AS CMPGN_TYPE1_NM,
  c.CMPGN_TYPE2_BSN                 AS CMPGN_TYPE2_BSN,
  NULLIF(TRIM(ty2.DTL_CD_NM),'')    AS CMPGN_TYPE2_NM,
  c.MKTG_CMPGN_NM                   AS MKTG_CMPGN_NM,
  NULLIF(TRIM(m.MK_CMPGN_NM),'')    AS MK_CMPGN_NM,
  -- [2026-08-25] 신규 2컬럼(공통브랜드·UTM) — 안내1 회원 개발이력 비정규화 요건의 원천.
  c.CMMN_BRND                       AS CMMN_BRND,        -- MM297 공통브랜드 코드
  NULLIF(TRIM(brnd.DTL_CD_NM),'')   AS CMMN_BRND_NM,      -- MM297 라벨
  c.MKTG_UTM                        AS MKTG_UTM,          -- TM_CM_MKTNG_UTM.MK_UTM 코드
  NULLIF(TRIM(u.MK_UTM_NM),'')      AS MKTG_UTM_NM,       -- TM_CM_MKTNG_UTM 라벨
  NULLIF(TRIM(c.CMPGN_STRT_DE),'')  AS CMPGN_STRT_DE,
  'CRM'                             AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()               AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()               AS DW_UPDATE_TS,
  NULL                              AS DW_BATCH_ID
FROM {{ source('bronze_crm','TM_CM_CMPGN_MNG') }} c
LEFT JOIN {{ source('bronze_crm','TM_CM_BRND_MNG') }} b ON c.BRND_ID = b.BRND_ID
LEFT JOIN {{ source('bronze_crm','TM_CM_MKTNG_CMPGN_MNG') }} m ON TO_VARCHAR(c.MKTG_CMPGN_NM) = m.MK_CMPGN_CD
LEFT JOIN {{ ref('CRM_CODE') }} ctgr  ON ctgr.CD_ID='MM294' AND TRY_TO_NUMBER(ctgr.DTL_CD_ID)  = c.CMPGN_CTGR_CD
LEFT JOIN {{ ref('CRM_CODE') }} infl  ON infl.CD_ID='MM293' AND TRY_TO_NUMBER(infl.DTL_CD_ID)  = c.MBER_INFLOW_PATH_CD
LEFT JOIN {{ ref('CRM_CODE') }} ty1   ON ty1.CD_ID ='MM295' AND TRY_TO_NUMBER(ty1.DTL_CD_ID)   = c.CMPGN_TYPE1_BSN
LEFT JOIN {{ ref('CRM_CODE') }} ty2   ON ty2.CD_ID ='MM296' AND TRY_TO_NUMBER(ty2.DTL_CD_ID)   = c.CMPGN_TYPE2_BSN
-- [2026-08-25] MM297 공통브랜드. CRM_CODE PK=(CD_ID,DTL_CD_ID) 이므로 fan-out 없음(기존 4축과 동일 패턴).
LEFT JOIN {{ ref('CRM_CODE') }} brnd  ON brnd.CD_ID='MM297' AND TRY_TO_NUMBER(brnd.DTL_CD_ID) = c.CMMN_BRND
-- [2026-08-25] UTM. 코드사전이 아니라 신설 원천 TM_CM_MKTNG_UTM 과 연동. MK_UTM 191종 유일(실측) → fan-out 없음.
LEFT JOIN {{ source('bronze_crm','TM_CM_MKTNG_UTM') }} u ON c.MKTG_UTM = TRY_TO_NUMBER(u.MK_UTM)
-- [2026-08-25] CM019/CM035 라벨. CRM_CODE 코드컬럼이 VARCHAR 라 TEXT 직접 비교(TRY_TO_NUMBER 불필요).
LEFT JOIN {{ ref('CRM_CODE') }} cpr   ON cpr.CD_ID='CM019' AND cpr.DTL_CD_ID = NULLIF(TRIM(c.CPR_DIV_CD),'')
LEFT JOIN {{ ref('CRM_CODE') }} spnsr ON spnsr.CD_ID='CM035' AND spnsr.DTL_CD_ID = NULLIF(TRIM(c.SPNSR_DIV_CD),'')
WHERE c.CMPGN_CD IS NOT NULL
