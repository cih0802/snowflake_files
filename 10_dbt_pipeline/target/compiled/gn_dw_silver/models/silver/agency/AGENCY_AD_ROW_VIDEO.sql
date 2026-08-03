-- AGENCY_AD_ROW_VIDEO: BRONZE VIDEO 전 32컬럼 무손실 staging + AD_PERF_DK 발급 (DEC-11 · 설계 §3-A-7)
-- Co-authored with CoCo
-- ⚠️ AD_PERF_DK **발급 단일지점** — 코어(FAD)·위성(FAD_B)이 동일 DK 를 쓰도록 여기서만 계산한다.
-- ⚠️ 원천 무손실: BRONZE 32컬럼을 이름 그대로 보존(개명·형변환 금지). 정제는 하류에서.
-- ⚠️ DUP_SEQ: 전컬럼 중복 실측 30그룹·최대 3중복 → 해시 단독으로는 충돌하므로 순번 결합 필수.
WITH src AS (
    SELECT
        CHNNL_NM                AS CHNNL_NM,
        DOW                     AS DOW,
        BRDC_DATE               AS BRDC_DATE,
        TIME_RNG                AS TIME_RNG,
        DAY_DIV_NM              AS DAY_DIV_NM,
        PRG_STRT_TIME           AS PRG_STRT_TIME,
        SCHDL_NM                AS SCHDL_NM,
        CM                      AS CM,
        CM_AREA                 AS CM_AREA,
        AD_STRT_TIME            AS AD_STRT_TIME,
        AD_END_TIME             AS AD_END_TIME,
        SPOT_TY                 AS SPOT_TY,
        AD_VIEW_RT              AS AD_VIEW_RT,
        AD_CNT                  AS AD_CNT,
        AD_SEC                  AS AD_SEC,
        ACTL_PUR_AD_COST_KRW    AS ACTL_PUR_AD_COST_KRW,
        INBOUND_CALL_CNT        AS INBOUND_CALL_CNT,
        CPC                     AS CPC,
        UPPER_CMPGN_NM          AS UPPER_CMPGN_NM,
        MATR_NM                 AS MATR_NM,
        CMPGN_TY_NM             AS CMPGN_TY_NM,
        DUR_PD_MATR_CHN         AS DUR_PD_MATR_CHN,
        CHNNL_CMPNY_TY_NM       AS CHNNL_CMPNY_TY_NM,
        WEEK                    AS WEEK,
        CONV_CALL_CNT           AS CONV_CALL_CNT,
        BRDC_MT                 AS BRDC_MT,
        YEAR                    AS YEAR,
        CTV_DIV_NM              AS CTV_DIV_NM,
        MKT_CMPGN_NM            AS MKT_CMPGN_NM,
        SPNSR_BSNS_NM           AS SPNSR_BSNS_NM,
        DMST_OVSEA_DIV_NM       AS DMST_OVSEA_DIV_NM,
        BSNS_CASE_DIV_NM        AS BSNS_CASE_DIV_NM,
        MD5(TO_JSON(OBJECT_CONSTRUCT(*)))   AS ROW_HASH
    FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
),
seq AS (
    SELECT
        src.*,
        ROW_NUMBER() OVER (PARTITION BY ROW_HASH ORDER BY NULL) AS DUP_SEQ
    FROM src
)

SELECT
    MD5('VIDEO' || '|' || ROW_HASH || '|' || DUP_SEQ)   AS AD_PERF_DK,
    'VIDEO'                 AS AD_SOURCE_TYPE,
    ROW_HASH                AS ROW_HASH,
    DUP_SEQ                 AS DUP_SEQ,
    CHNNL_NM, DOW, BRDC_DATE, TIME_RNG, DAY_DIV_NM, PRG_STRT_TIME, SCHDL_NM,
    CM, CM_AREA, AD_STRT_TIME, AD_END_TIME, SPOT_TY, AD_VIEW_RT, AD_CNT, AD_SEC,
    ACTL_PUR_AD_COST_KRW, INBOUND_CALL_CNT, CPC, UPPER_CMPGN_NM, MATR_NM, CMPGN_TY_NM,
    DUR_PD_MATR_CHN, CHNNL_CMPNY_TY_NM, WEEK, CONV_CALL_CNT, BRDC_MT, YEAR,
    CTV_DIV_NM, MKT_CMPGN_NM, SPNSR_BSNS_NM, DMST_OVSEA_DIV_NM, BSNS_CASE_DIV_NM,
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS'     AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    'caf0ed7e-1e99-4c1d-b479-e0fc6272f462'                   AS DW_BATCH_ID
FROM seq