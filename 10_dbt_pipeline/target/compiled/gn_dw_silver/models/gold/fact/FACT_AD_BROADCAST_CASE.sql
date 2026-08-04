-- FACT_AD_BROADCAST_CASE: 광고성과 위성 — 재방송 사례(정규화). 순서9-I 신설(DEC-8).
-- Co-authored with CoCo
-- grain: AD_PERF_DK × CASE_SEQ (1행 = 1사례) — 코어 FACT_AD_PERFORMANCE 에 **1:N**.
-- ⚠️ fan-out 주의: 코어 measure(광고비·노출 등)와 함께 집계하면 **사례 수만큼 중복 합산**된다.
--    사례 속성 분석 전용으로 사용하고, 코어 measure 집계는 코어 단독으로 수행할 것.
-- ⚠️ 정규화 근거: 원천 REBRDC 의 CASE1_*~CASE3_* = 5속성 × 3반복 = 15컬럼 반복군을 CASE_SEQ 축으로
--    언피벗했다. 사례가 4개로 늘어도 DDL 변경이 불필요하다(행으로 흡수).
-- ⚠️ 전 속성 NULL 인 사례는 미적재(희소행 방지) → 실제 행수는 REBRDC 2,064행 × 3 보다 적다.
-- ⚠️ CASEn_CHILD_NM(아동명)은 **미적재** — PII 판정 대기(O14). SILVER staging 에 원형 보존돼 있어
--    현업 판정 후 컬럼 추가만으로 노출 가능하다.


select
    AD_PERF_DK      as AD_PERF_DK,
    CASE_SEQ        as CASE_SEQ,        -- 사례 순번 1~3
    BIZ_DIV         as BIZ_DIV,         -- 사업구분
    FAMILY_TYPE     as FAMILY_TYPE,     -- 가족유형
    APPEAL_POINT    as APPEAL_POINT,    -- 어필포인트
    CASE_DIV        as CASE_DIV,        -- 사례구분
    'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '5ef82815-e89f-4a45-805d-207f49bbc068'                    AS DW_BATCH_ID
from GN_DW.SILVER.AGENCY_AD_BROADCAST_CASE