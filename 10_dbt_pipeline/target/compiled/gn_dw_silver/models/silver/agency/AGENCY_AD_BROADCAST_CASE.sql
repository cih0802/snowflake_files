-- AGENCY_AD_BROADCAST_CASE: REBRDC 사례 반복군 CASE1_*~CASE3_* 언피벗 → GOLD FACT_AD_BROADCAST_CASE
-- Co-authored with CoCo
-- 설계: DEC-8 · 설계 §3-A(FAD_BC) — 원천 5속성 × 3반복 = 15컬럼을 CASE_SEQ 축으로 정규화.
-- ⚠️ 정규화 이득: 사례가 4개로 늘어도 DDL 변경이 불필요하다(행 추가로 흡수).
-- ⚠️ grain = AD_PERF_DK × CASE_SEQ (코어 FAD 에 1:N). 코어 조인 시 fan-out 주의 —
--    코어 measure 와 함께 집계하면 사례 수만큼 중복 합산된다. 사례 분석 전용으로 사용할 것.
-- ⚠️ 전 속성이 NULL 인 사례는 적재하지 않는다(희소행 방지 — 설계 §3-A FAD_BC 각주).
-- ⚠️ CASEn_CHILD_NM(아동명)은 **미적재** — PII 판정 대기(O14). staging(AGENCY_AD_ROW_REBRDC)에는 보존돼 있어
--    현업 판정 후 여기에 컬럼을 추가하면 즉시 노출 가능하다.
WITH unpivoted AS (
    SELECT AD_PERF_DK, 1 AS CASE_SEQ,
           NULLIF(NULLIF(NULLIF(TRIM(CASE1_BSNS_DIV_NM), ''), 'NULL'), '-')      AS BIZ_DIV,
           NULLIF(NULLIF(NULLIF(TRIM(CASE1_FAM_TY_NM), ''), 'NULL'), '-')        AS FAMILY_TYPE,
           NULLIF(NULLIF(NULLIF(TRIM(CASE1_APPEAL_POINT_NM), ''), 'NULL'), '-')  AS APPEAL_POINT,
           NULLIF(NULLIF(NULLIF(TRIM(CASE1_CASE_DIV_NM), ''), 'NULL'), '-')      AS CASE_DIV
    FROM GN_DW.SILVER.AGENCY_AD_ROW_REBRDC
    UNION ALL
    SELECT AD_PERF_DK, 2,
           NULLIF(NULLIF(NULLIF(TRIM(CASE2_BSNS_DIV_NM), ''), 'NULL'), '-'),
           NULLIF(NULLIF(NULLIF(TRIM(CASE2_FAM_TY_NM), ''), 'NULL'), '-'),
           NULLIF(NULLIF(NULLIF(TRIM(CASE2_APPEAL_POINT_NM), ''), 'NULL'), '-'),
           NULLIF(NULLIF(NULLIF(TRIM(CASE2_CASE_DIV_NM), ''), 'NULL'), '-')
    FROM GN_DW.SILVER.AGENCY_AD_ROW_REBRDC
    UNION ALL
    SELECT AD_PERF_DK, 3,
           NULLIF(NULLIF(NULLIF(TRIM(CASE3_BSNS_DIV_NM), ''), 'NULL'), '-'),
           NULLIF(NULLIF(NULLIF(TRIM(CASE3_FAM_TY_NM), ''), 'NULL'), '-'),
           NULLIF(NULLIF(NULLIF(TRIM(CASE3_APPEAL_POINT_NM), ''), 'NULL'), '-'),
           NULLIF(NULLIF(NULLIF(TRIM(CASE3_CASE_DIV_NM), ''), 'NULL'), '-')
    FROM GN_DW.SILVER.AGENCY_AD_ROW_REBRDC
)

SELECT
    AD_PERF_DK                              AS AD_PERF_DK,
    CASE_SEQ                                AS CASE_SEQ,
    BIZ_DIV                                 AS BIZ_DIV,          -- 사업구분   ← REBRDC.CASEn_BSNS_DIV_NM
    FAMILY_TYPE                             AS FAMILY_TYPE,      -- 가족유형   ← REBRDC.CASEn_FAM_TY_NM
    APPEAL_POINT                            AS APPEAL_POINT,     -- 어필포인트 ← REBRDC.CASEn_APPEAL_POINT_NM
    CASE_DIV                                AS CASE_DIV,         -- 사례구분   ← REBRDC.CASEn_CASE_DIV_NM
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS'    AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    'dc4646cc-51ff-4f7e-bfc7-e9f018c89a5e'                   AS DW_BATCH_ID
FROM unpivoted
WHERE COALESCE(BIZ_DIV, FAMILY_TYPE, APPEAL_POINT, CASE_DIV) IS NOT NULL