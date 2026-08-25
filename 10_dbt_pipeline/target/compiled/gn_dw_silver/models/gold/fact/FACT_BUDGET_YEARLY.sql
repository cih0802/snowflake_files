-- FACT_BUDGET_YEARLY: 연 예산 팩트 (SILVER.ERP_BUDGET_YEARLY → YEAR × BUDGET_ITEM), O93 신설.
-- Co-authored with CoCo
--
-- 🔴 존재 이유 = grain 분리. `FACT_BUDGET` 은 월 grain 이라 연 총액을 담으면 12개월에 복제되어
--    `SUM()` 이 12배로 부푼다. 그 오류는 에러 없이 조용히 나오므로 축을 물리적으로 갈랐다
--    (사용자 결정 2026-08-20). 상세 근거는 `03_top-down_gold/06_DDL.sql` FACT 16 주석.
-- 🟢 이 팩트는 SUM 이 항상 안전하다 — 1행 = 1(연 × 예산과목).
-- ⚠️ `FACT_BUDGET.PLAN_BUDGET_YEAR` 는 계속 NULL 이다(값을 두 곳에 두지 않는다).
-- 보수 매핑(재무 오귀속 방지):
--   ORG_SK=0        — ERP 원장에 조직 귀속 축이 없다(월 팩트와 동일 사유).
--   CAMPAIGN_SK=0   — 원천 연결 없음.
--   SPONSORSHIP_SK=NULL — 원천 연결 없음.
-- 순서9 패턴 준수: incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact) — 구조·FK 보존, 데이터만 갱신.


with y as (
    select * from GN_DW.SILVER.ERP_BUDGET_YEARLY
)

select
    BUDGET_YEAR                           as BUDGET_YEAR,
    0                                     as ORG_SK,            -- 원천 조직귀속 없음 → Unknown
    ABS(HASH(COALESCE(CAST(BUDGET_ITEM_DK AS VARCHAR), '∅')))     as BUDGET_ITEM_SK,    -- 월 팩트와 동일 산식
    0                                     as CAMPAIGN_SK,       -- 원천 연결 없음
    CAST(NULL AS NUMBER(38,0))            as SPONSORSHIP_SK,
    YEAR_BUDGET_TOT_AMT                   as PLAN_BUDGET_YEAR,  -- 연 편성
    CHN_BUDGET_TOT_AMT                    as CHN_BUDGET_YEAR,   -- 연 추경
    ADJ_BUDGET_TOT_AMT                    as ADJ_BUDGET_YEAR,   -- 연 조정
    EXEC_TOT_AMT                          as EXEC_BUDGET_YEAR,  -- 연 집행
    'ERP'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '0a0f03d1-d7c1-4e10-a7c3-7a79d0fcb1ad'                    AS DW_BATCH_ID
from y
where BUDGET_YEAR is not null   -- 연도 파싱 실패행 제외(NOT NULL grain 보호)