-- DIM_CAMPAIGN: 캠페인 차원 (CRM_CAMPAIGN 기반, 분류 4축 라벨)
-- Co-authored with CoCo
-- ⚠️ ORG_SK(주관조직 O10 미확정)=0 센티넬.
-- [2026-07-16 BRONZE 재입고 반영] 캠페인 분류가 원천에서 채워짐 → 3건 교정 + 2컬럼 신설:
--   1) CAMPAIGN_TYPE : CAST(CMPGN_CTGR_CD AS VARCHAR)(숫자코드 "17") → CMPGN_CTGR_NM(라벨) 로 교체.
--   2) BIZ_CASE_TYPE : CMPGN_TYPE1_BSN(국내/통합/해외) → CMPGN_TYPE2_NM(굿즈/기타/사례/사업) 로 **의미혼입 교정**.
--      종전 모델은 유형1을 사업/사례 자리에 넣었다(O16 과 동일한 위치매핑 오류). 전건 NULL 이라 무증상이었을 뿐이다.
--   3) DOMESTIC_OVERSEAS : CAST(NULL AS VARCHAR)(파생규칙 대기) → CMPGN_TYPE1_NM 으로 해소.
--   4) INFLOW_PATH(신설) : MM293 개발인입경로 라벨 — 현업 "주요캠페인" 분류축.
--   5) MARKETING_CAMPAIGN(신설) : MK_CMPGN_NM (Q16 해소, 323종·고아 0).
-- ⚠️ 라벨 NULL 은 코드사전 미등재(고아)를 뜻한다 — 결측이 아니다. 기지: 카테고리 23행 · 유형1 740행.


with c as (
    select * from GN_DW.SILVER.CRM_CAMPAIGN
)

select
    ABS(HASH(COALESCE(CAST(CMPGN_CD AS VARCHAR), '∅')))                   as CAMPAIGN_SK,
    CMPGN_CD                                      as CAMPAIGN_BK,
    BRND_NM                                       as BRAND,
    UPPER_CMPGN_CD                                as PARENT_CAMPAIGN,
    CMPGN_NM                                      as CAMPAIGN_NAME,
    PR_MTH_CD                                     as PROMO_METHOD,
    CMPGN_CTGR_NM                                 as CAMPAIGN_TYPE,        -- MM294 카테고리 라벨
    CMPGN_TYPE1_NM                                as DOMESTIC_OVERSEAS,    -- MM295 국내/통합/해외
    CMPGN_TYPE2_NM                                as BIZ_CASE_TYPE,        -- MM296 굿즈/기타/사례/사업
    MBER_INFLOW_PATH_NM                           as INFLOW_PATH,          -- MM293 개발인입경로
    MK_CMPGN_NM                                   as MARKETING_CAMPAIGN,   -- Q16 마케팅캠페인
    TRY_TO_DATE(CMPGN_STRT_DE, 'YYYYMMDD')        as CAMPAIGN_OPEN_DATE,
    0                                             as ORG_SK,               -- ⚠️ 센티넬(O10 주관조직 미확정)
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '5ef82815-e89f-4a45-805d-207f49bbc068'                    AS DW_BATCH_ID
from c

union all
-- unknown 멤버(SK=0): 팩트 CAMPAIGN_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', NULL, NULL, '(미매핑)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '5ef82815-e89f-4a45-805d-207f49bbc068'                    AS DW_BATCH_ID