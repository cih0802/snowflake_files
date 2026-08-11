-- AGENCY_AD_ROW_DGT: BRONZE DGT 전 36컬럼 무손실 staging + AD_PERF_DK 발급 (DEC-11 · 설계 §3-A-7)
-- Co-authored with CoCo
-- ⚠️ 본 모델은 AD_PERF_DK **발급 단일지점**이다. 코어(FAD)·위성(FAD_D)이 같은 DK 를 쓰도록
--    DK 계산을 여기 한 곳에만 둔다. 하류 모델은 절대 DK 를 재계산하지 말고 이 모델을 ref 할 것.
-- ⚠️ 원천 무손실: BRONZE 36컬럼을 이름 그대로 보존한다(개명·가공 금지). 정제·개명은 하류(AGENCY_AD_*)에서.
-- ⚠️ ROW_HASH = MD5(TO_JSON(OBJECT_CONSTRUCT(*))) — 원천 '전컬럼' 해시(설계 §3-A-6).
--    OBJECT 키는 정렬되어 직렬화되므로 컬럼 순서 변경에 불변. 단 **컬럼 추가 시 DK 값이 변한다**
--    (전컬럼 해시의 정의상 의도된 동작 — 원천 스키마 변경은 새 행정체성으로 간주).
-- ⚠️ DUP_SEQ: 전컬럼 중복 그룹(실측 35그룹·최대 2중복) 내 순번. 그룹 내 행은 전컬럼이 동일하므로
--    순번 부여 순서가 무관 → DK **집합**은 재실행 멱등.
WITH src AS (
    SELECT
        TIME                    AS TIME,
        YEAR                    AS YEAR,
        CPR_NM                  AS CPR_NM,
        DMST_OVSEA_DIV_NM       AS DMST_OVSEA_DIV_NM,
        BSNS_CASE_DIV_NM        AS BSNS_CASE_DIV_NM,
        CMPGN_TY_NM             AS CMPGN_TY_NM,
        AD_TY_NM                AS AD_TY_NM,
        MONTH                   AS MONTH,
        DEVICE                  AS DEVICE,
        MEDIA_NM                AS MEDIA_NM,
        WEEK                    AS WEEK,
        DAY                     AS DAY,
        DOW                     AS DOW,
        CMPGN_NM                AS CMPGN_NM,
        MATR                    AS MATR,
        MATR_TY_NM              AS MATR_TY_NM,
        EXPS_CNT                AS EXPS_CNT,
        CLICK_CNT               AS CLICK_CNT,
        GA_AD_COST              AS GA_AD_COST,
        GA_CONV_MBER_CNT        AS GA_CONV_MBER_CNT,
        CONV_VU_CNT             AS CONV_VU_CNT,
        CPA                     AS CPA,
        DEV_UNIT_PRICE          AS DEV_UNIT_PRICE,
        CTR                     AS CTR,
        CVR                     AS CVR,
        CPC                     AS CPC,
        CPM                     AS CPM,
        UPPER_CMPGN_NM          AS UPPER_CMPGN_NM,
        READ_CNT                AS READ_CNT,
        MEDIA_PTNT_CUST_CNT     AS MEDIA_PTNT_CUST_CNT,
        DATE                    AS DATE,
        VTR                     AS VTR,
        PAGE_TYPE_NM            AS PAGE_TYPE_NM,
        CRM_DVLP_CNT            AS CRM_DVLP_CNT,
        AD_GRP_NM               AS AD_GRP_NM,
        GRP_DIV_NM              AS GRP_DIV_NM,
        MD5(TO_JSON(OBJECT_CONSTRUCT(*)))   AS ROW_HASH
    FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
),
seq AS (
    SELECT
        src.*,
        ROW_NUMBER() OVER (PARTITION BY ROW_HASH ORDER BY NULL) AS DUP_SEQ
    FROM src
)

SELECT
    MD5('DIGITAL' || '|' || ROW_HASH || '|' || DUP_SEQ)  AS AD_PERF_DK,
    'DIGITAL'               AS AD_SOURCE_TYPE,
    ROW_HASH                AS ROW_HASH,
    DUP_SEQ                 AS DUP_SEQ,
    TIME, YEAR, CPR_NM, DMST_OVSEA_DIV_NM, BSNS_CASE_DIV_NM, CMPGN_TY_NM, AD_TY_NM,
    MONTH, DEVICE, MEDIA_NM, WEEK, DAY, DOW, CMPGN_NM, MATR, MATR_TY_NM,
    EXPS_CNT, CLICK_CNT, GA_AD_COST, GA_CONV_MBER_CNT, CONV_VU_CNT,
    CPA, DEV_UNIT_PRICE, CTR, CVR, CPC, CPM,
    UPPER_CMPGN_NM, READ_CNT, MEDIA_PTNT_CUST_CNT, DATE, VTR,
    PAGE_TYPE_NM, CRM_DVLP_CNT, AD_GRP_NM, GRP_DIV_NM,
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS'       AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    'bc494410-1de4-4551-8a46-6f1b99eb6fbd'                   AS DW_BATCH_ID
FROM seq