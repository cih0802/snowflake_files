-- AGENCY_AD_DIGITAL: 디지털 광고(DGT) 고유속성 + 대행사 산정 파생값 _SRC 7종 → GOLD FACT_AD_DIGITAL
-- Co-authored with CoCo
-- 설계: DEC-8(위성 분리) · DEC-9(_SRC 전량 보존, 비가산) · 설계 §3-A-3
-- ⚠️ AD_PERF_DK 는 staging(AGENCY_AD_ROW_DGT)이 발급한 값을 **그대로 승계**한다(재계산 금지).
-- ⚠️ _SRC 컬럼 = 대행사가 계산해 넘긴 원천 파생값. DW 가 재계산하지 않고 원본 그대로 적재한다.
--    목적은 '대조'다 — SV 는 base measure(AD_COST/CLICKS 등)로 별도 재계산하고, 현업이 양쪽을 비교한다.
--    전량 **N(비가산)**: 비율·단가이므로 SUM/재합산 금지. 집계는 반드시 base 재계산값 사용.
-- ⚠️ VTR_SRC 는 base 가 원천에 없어 재계산 불가 → 대조 대상이 아닌 유일값(설계 §3-A-3 각주).
SELECT
    AD_PERF_DK                          AS AD_PERF_DK,
    -- ── 디지털 고유 degenerate ──
    NULLIF(NULLIF(NULLIF(TRIM(PAGE_TYPE_NM), ''), 'NULL'), '-')     AS PAGE_TYPE,                   -- 페이지유형 ← DGT.PAGE_TYPE_NM
    NULLIF(NULLIF(NULLIF(TRIM(AD_GRP_NM), ''), 'NULL'), '-')        AS AD_GROUP_NM,                 -- 광고그룹명 ← DGT.AD_GRP_NM
    NULLIF(NULLIF(NULLIF(TRIM(GRP_DIV_NM), ''), 'NULL'), '-')       AS GROUP_DIV,                   -- 그룹구분 ← DGT.GRP_DIV_NM
    NULLIF(NULLIF(NULLIF(TRIM(MATR_TY_NM), ''), 'NULL'), '-')       AS CREATIVE_TYPE,               -- 소재유형 ← DGT.MATR_TY_NM
    NULLIF(NULLIF(NULLIF(TRIM(AD_TY_NM), ''), 'NULL'), '-')         AS AD_TYPE_NM,                  -- 광고유형명(원천 표기) ← DGT.AD_TY_NM
                                                                        --   ⚠️ 코어 FAD.AD_SOURCE_TYPE(DIGITAL/VIDEO/REBROADCAST)과 다른 개념
    -- ── 디지털 고유 measure (가산) ──
    READ_CNT                            AS READ_CNT,                    -- 읽음수
    MEDIA_PTNT_CUST_CNT                 AS MEDIA_POTENTIAL_CUST_CNT,    -- 매체 잠재고객수
    CRM_DVLP_CNT                        AS CRM_DEV_CNT,                 -- CRM 개발건수
    -- ── 대행사 산정 파생값 (_SRC, 전량 비가산 N) ──
    CTR                                 AS CTR_SRC,                     -- DW 재계산 = CLICKS/IMPRESSIONS
    CVR                                 AS CVR_SRC,                     -- DW 재계산 = GA_CONV_MEMBERS/CLICKS (O5 확정)
    CPC                                 AS CPC_SRC,                     -- DW 재계산 = AD_COST/CLICKS
    CPM                                 AS CPM_SRC,                     -- DW 재계산 = AD_COST/IMPRESSIONS×1000
    CPA                                 AS CPA_SRC,                     -- DW 재계산 = AD_COST/GA_CONV_CNT
    DEV_UNIT_PRICE                      AS DEV_UNIT_PRICE_SRC,          -- DW 재계산 = AD_COST/개발건수
    VTR                                 AS VTR_SRC,                     -- 재계산 불가(원천 전용)
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS'       AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    'ef7eb47e-3629-4d48-b7bd-658cf3868918'                   AS DW_BATCH_ID
FROM GN_DW.SILVER.AGENCY_AD_ROW_DGT