-- CRM_EVENT: 행사 마스터 = 일반행사(EVENT) ∪ 캠페인행사(CRMN), 정본 09 STEP3.
-- Co-authored with CoCo
-- [2026-08-11 O59-N · DEC-35 1단계] 행사구분 코드→라벨. 정본 = 문서30 §23-J · 매핑 = 문서31 §4.
--   🔴 두 원천의 코드체계가 완전 분리된다(겹침 0) ⇒ 판별자 EVENT_SOURCE 로 갈라 각자의 코드군에 조인한다.
--     · EVENT → `MS286`(등급 B · 5/5 정확 일치 — MS303 7종·MS302 8종은 초과값으로 배제)
--     · CRMN  → `MS002`(등급 B · 도메인 14/16 포함 + 의미 완전 정합)
--   ⚠️ 사전 초과값은 라벨 NULL(DEC-17-B) · fan-out 안전: 두 그룹 (CD_ID, DTL_CD_ID) 유일(실측 2026-08-11).
WITH base AS (
  SELECT 'EVENT_'||EVENT_CD          AS EVENT_KEY,
    'EVENT'                          AS EVENT_SOURCE,
    NULLIF(TRIM(EVENT_DIV_CD),'')    AS EVENT_DIV_CD,
    NULLIF(TRIM(EVENT_NM),'')        AS EVENT_NM,
    NULLIF(TRIM(STRT_DATE),'')       AS STRT_DE,
    NULLIF(TRIM(END_DATE),'')        AS END_DE,
    NULL                             AS RCRIT_PSNNL_CO,
    NULL                             AS BRNCH_DEPT_ID,
    'CRM'                            AS DW_SOURCE_SYSTEM,
    'BRONZE_CRM.TM_MS_EVENT'         AS DW_SOURCE_TABLE
  FROM GN_DW.BRONZE_CRM.TM_MS_EVENT WHERE EVENT_CD IS NOT NULL
  UNION ALL
  SELECT 'CRMN_'||CRMN_CD, 'CRMN', NULLIF(TRIM(CRMN_DIV_CD),''), NULLIF(TRIM(CRMN_TIT),''),
    NULLIF(TRIM(CRMN_STRT_DE),''), NULLIF(TRIM(CRMN_END_DE),''), RCRIT_PSNNL_CO, NULLIF(TRIM(BRNCH_DEPT_ID),''),
    'CRM','BRONZE_CRM.TM_MS_CRMN'
  FROM GN_DW.BRONZE_CRM.TM_MS_CRMN WHERE CRMN_CD IS NOT NULL
)
SELECT
  b.EVENT_KEY                      AS EVENT_KEY,
  b.EVENT_SOURCE                   AS EVENT_SOURCE,
  b.EVENT_DIV_CD                   AS EVENT_DIV_CD,
  b.EVENT_NM                       AS EVENT_NM,
  b.STRT_DE                        AS STRT_DE,
  b.END_DE                         AS END_DE,
  b.RCRIT_PSNNL_CO                 AS RCRIT_PSNNL_CO,
  b.BRNCH_DEPT_ID                  AS BRNCH_DEPT_ID,
  b.DW_SOURCE_SYSTEM               AS DW_SOURCE_SYSTEM,
  b.DW_SOURCE_TABLE                AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID,
  -- 🔴 신설 컬럼 = 감사컬럼 뒤(정본 DDL 규약 · 물리 ordinal 이 ALTER 로 맨 끝이 된다).
  CASE WHEN b.EVENT_DIV_CD IS NULL THEN NULL
       WHEN b.EVENT_SOURCE='EVENT' THEN 'MS286' ELSE 'MS002' END AS EVENT_DIV_GROUP,
  dv.DTL_CD_NM                     AS EVENT_DIV_NM
FROM base b
LEFT JOIN GN_DW.SILVER.CRM_CODE dv
  ON dv.CD_ID = CASE WHEN b.EVENT_SOURCE='EVENT' THEN 'MS286' ELSE 'MS002' END
 AND dv.DTL_CD_ID = b.EVENT_DIV_CD