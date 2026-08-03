-- FACT_AD_DIGITAL: 광고성과 위성 — 디지털(DGT) 고유속성. 순서9-I 신설(DEC-8).
-- Co-authored with CoCo
-- grain: AD_PERF_DK — 코어 FACT_AD_PERFORMANCE 와 **1:1**(디지털 행만 존재, 실측 197,686행).
-- ⚠️ 조인: `FACT_AD_PERFORMANCE f JOIN FACT_AD_DIGITAL d USING (AD_PERF_DK)` — 1:1이라 fan-out 없음.
-- ⚠️ `_SRC` = 대행사가 계산해 넘긴 파생값(DEC-9 · 설계 §3-A-3). 목적은 **대조**다.
--    DW 는 재계산하지 않고 원천값 그대로 보존하며, SV 가 base measure 로 별도 재계산한다.
--    전량 **N(비가산)** — 비율·단가이므로 SUM/AVG 재합산 금지. 집계는 base 재계산값 사용.
-- ⚠️ AD_TYPE_NM(원천 광고유형명)은 코어 degen `AD_SOURCE_TYPE`(DIGITAL/VIDEO/REBROADCAST)과 **다른 개념**이다.
--    코어 AD_SOURCE_TYPE = 원천 테이블 출처축 / 여기 AD_TYPE_NM = 대행사 표기 광고유형 라벨.
--    DIM_AD_CREATIVE.AD_TYPE(소재 광고유형)과도 별개 — 3자 혼동 주의.


select
    AD_PERF_DK                  as AD_PERF_DK,
    PAGE_TYPE                   as PAGE_TYPE,                   -- 페이지유형
    AD_GROUP_NM                 as AD_GROUP_NM,                 -- 광고그룹명
    GROUP_DIV                   as GROUP_DIV,                   -- 그룹구분
    CREATIVE_TYPE               as CREATIVE_TYPE,               -- 소재유형
    AD_TYPE_NM                  as AD_TYPE_NM,                  -- 광고유형명(원천 표기) ≠ 코어 AD_SOURCE_TYPE
    READ_CNT                    as READ_CNT,                    -- 읽음수
    MEDIA_POTENTIAL_CUST_CNT    as MEDIA_POTENTIAL_CUST_CNT,    -- 매체 잠재고객수
    CRM_DEV_CNT                 as CRM_DEV_CNT,                 -- CRM 개발건수
    CTR_SRC                     as CTR_SRC,                     -- N 대행사, DW=CLICKS/IMPRESSIONS
    CVR_SRC                     as CVR_SRC,                     -- N 대행사, DW=GA_CONV_MEMBERS/CLICKS (O5)
    CPC_SRC                     as CPC_SRC,                     -- N 대행사, DW=AD_COST/CLICKS
    CPM_SRC                     as CPM_SRC,                     -- N 대행사, DW=AD_COST/IMPRESSIONS×1000
    CPA_SRC                     as CPA_SRC,                     -- N 대행사, DW=AD_COST/GA_CONV_CNT
    DEV_UNIT_PRICE_SRC          as DEV_UNIT_PRICE_SRC,          -- N 대행사, DW=AD_COST/개발건수
    VTR_SRC                     as VTR_SRC,                     -- N 대행사, 재계산 불가(원천 전용)
    'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'caf0ed7e-1e99-4c1d-b479-e0fc6272f462'                    AS DW_BATCH_ID
from GN_DW.SILVER.AGENCY_AD_DIGITAL