-- AGENCY_AD_ROW_REBRDC: BRONZE REBRDC 전 34컬럼 무손실 staging + AD_PERF_DK 발급 (DEC-11 · 설계 §3-A-7)
-- Co-authored with CoCo
-- ⚠️ AD_PERF_DK **발급 단일지점** — 코어(FAD)·위성(FAD_B·FAD_BC)이 동일 DK 를 쓰도록 여기서만 계산한다.
-- ⚠️ 원천 무손실: BRONZE 34컬럼을 이름 그대로 보존. CASE1_*~CASE3_* 반복군 15컬럼도 원형 보존
--    (언피벗은 하류 AGENCY_AD_BROADCAST_CASE 에서 수행).
-- ⚠️ DUP_SEQ: REBRDC 는 전컬럼 중복 실측 0그룹이나, 원천 스키마 변경 대비 및 3종 staging 로직
--    동일성 유지를 위해 동일하게 부여한다(현재 전건 DUP_SEQ=1).
-- ⚠️ CASE*_CHILD_NM(아동명)은 staging 에는 보존하되 GOLD 미적재 — PII 판정 대기(O14).
WITH src AS (
    SELECT
        RE_BRDC_TY_NM           AS RE_BRDC_TY_NM,
        DIV_NM                  AS DIV_NM,
        YEAR                    AS YEAR,
        BRDC_MT                 AS BRDC_MT,
        CHNNL_CMPNY             AS CHNNL_CMPNY,
        BRDC_NM                 AS BRDC_NM,
        BRDC_DIV_NM             AS BRDC_DIV_NM,
        DATE                    AS DATE,
        DOW                     AS DOW,
        BRDC_TIME               AS BRDC_TIME,
        INBOUND_CALL_CNT        AS INBOUND_CALL_CNT,
        DVLP_MBER_CNT           AS DVLP_MBER_CNT,
        DVLP_CNT                AS DVLP_CNT,
        BRDC_SCHDL_COST         AS BRDC_SCHDL_COST,
        WEEK                    AS WEEK,
        AD_CNT                  AS AD_CNT,
        TIME_RNG_DIV_NM         AS TIME_RNG_DIV_NM,
        CELEB_NM                AS CELEB_NM,
        DMST_OVSEA_DIV_NM       AS DMST_OVSEA_DIV_NM,
        CASE1_BSNS_DIV_NM       AS CASE1_BSNS_DIV_NM,
        CASE1_FAM_TY_NM         AS CASE1_FAM_TY_NM,
        CASE1_APPEAL_POINT_NM   AS CASE1_APPEAL_POINT_NM,
        CASE1_CHILD_NM          AS CASE1_CHILD_NM,
        CASE1_CASE_DIV_NM       AS CASE1_CASE_DIV_NM,
        CASE2_BSNS_DIV_NM       AS CASE2_BSNS_DIV_NM,
        CASE2_FAM_TY_NM         AS CASE2_FAM_TY_NM,
        CASE2_APPEAL_POINT_NM   AS CASE2_APPEAL_POINT_NM,
        CASE2_CHILD_NM          AS CASE2_CHILD_NM,
        CASE2_CASE_DIV_NM       AS CASE2_CASE_DIV_NM,
        CASE3_BSNS_DIV_NM       AS CASE3_BSNS_DIV_NM,
        CASE3_FAM_TY_NM         AS CASE3_FAM_TY_NM,
        CASE3_APPEAL_POINT_NM   AS CASE3_APPEAL_POINT_NM,
        CASE3_CHILD_NM          AS CASE3_CHILD_NM,
        CASE3_CASE_DIV_NM       AS CASE3_CASE_DIV_NM,
        MD5(TO_JSON(OBJECT_CONSTRUCT(*)))   AS ROW_HASH
    FROM GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS
),
seq AS (
    SELECT
        src.*,
        ROW_NUMBER() OVER (PARTITION BY ROW_HASH ORDER BY NULL) AS DUP_SEQ
    FROM src
)

SELECT
    MD5('REBROADCAST' || '|' || ROW_HASH || '|' || DUP_SEQ)  AS AD_PERF_DK,
    'REBROADCAST'           AS AD_SOURCE_TYPE,
    ROW_HASH                AS ROW_HASH,
    DUP_SEQ                 AS DUP_SEQ,
    RE_BRDC_TY_NM, DIV_NM, YEAR, BRDC_MT, CHNNL_CMPNY, BRDC_NM, BRDC_DIV_NM,
    DATE, DOW, BRDC_TIME, INBOUND_CALL_CNT, DVLP_MBER_CNT, DVLP_CNT,
    BRDC_SCHDL_COST, WEEK, AD_CNT, TIME_RNG_DIV_NM, CELEB_NM, DMST_OVSEA_DIV_NM,
    CASE1_BSNS_DIV_NM, CASE1_FAM_TY_NM, CASE1_APPEAL_POINT_NM, CASE1_CHILD_NM, CASE1_CASE_DIV_NM,
    CASE2_BSNS_DIV_NM, CASE2_FAM_TY_NM, CASE2_APPEAL_POINT_NM, CASE2_CHILD_NM, CASE2_CASE_DIV_NM,
    CASE3_BSNS_DIV_NM, CASE3_FAM_TY_NM, CASE3_APPEAL_POINT_NM, CASE3_CHILD_NM, CASE3_CASE_DIV_NM,
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS'    AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    '8162e9f4-6643-49ba-b6e8-240f496af9fe'                   AS DW_BATCH_ID
FROM seq