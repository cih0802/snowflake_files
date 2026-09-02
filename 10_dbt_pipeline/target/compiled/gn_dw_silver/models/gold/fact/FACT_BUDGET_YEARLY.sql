-- FACT_BUDGET_YEARLY: 연 예산 팩트 (SILVER.ERP_BUDGET_YEARLY → YEAR × BUDGET_ITEM), O93 신설.
-- Co-authored with CoCo
--
-- 🔴 존재 이유 = grain 분리. `FACT_BUDGET` 은 월 grain 이라 연 총액을 담으면 12개월에 복제되어
--    `SUM()` 이 12배로 부푼다. 그 오류는 에러 없이 조용히 나오므로 축을 물리적으로 갈랐다
--    (사용자 결정 2026-08-20). 상세 근거는 `03_top-down_gold/06_DDL.sql` FACT 16 주석.
-- ~~🟢 이 팩트는 SUM 이 항상 안전하다 — 1행 = 1(연 × 예산과목).~~
-- 🔴🔴 [2026-08-29 O115] **위 불변식은 현재 데이터에서 깨져 있다 — 취소선으로 남긴다**(지우지 않는다:
--    아래 문장들이 이 선언을 선행사로 인용한다 · `R1-3-7-c` 처방). 정본 = `DEC-44` · `99_NEXT §0-UUU ▣UUU6`.
--    실측 = 원장 247행이 `BUDGET_ITEM_DK` 로 **179키** ⇒ 이 팩트는 **247행 / 고유 179** 다(초과 68행).
--    원인 = 원천이 신설한 `BDGT_PRCD_NM`(편성 차수 = 연사업 / 추가경정)이 MD5 10컬럼 산식에 **없다**.
-- 🔴🔴 [O115 신규 실측] **차수는 「증분」이 아니라 「재작성」이다** ⇒ 차수를 걸쳐 SUM 하면 **중복 계상**된다.
--    근거 = 같은 연도의 **비영 집행액 다중집합이 차수 간 완전 동일**(2024 29/29 · 2025 15/15 · 편차 0).
--    ⇒ `SUM(EXEC_BUDGET_YEAR)` = **99,006,005,048** 이지만 실제 집행은 **55,094,546,653**(연사업만)
--      = **+79.7% 과대**. `PLAN_BUDGET_YEAR` 도 106,085,664,326 ↔ 62,100,245,921 = **+70.8% 과대**.
--    🔴 **월 팩트로 교차검증해도 잡히지 않는다** — `FACT_BUDGET` 월 집행 합도 **같은 99,006,005,048** 이다
--      (두 팩트가 같은 원인으로 같이 틀린다).
--    🔴 **소비 시 `BUDGET_YEAR` 만으로 GROUP BY 하지 마라** — 차수 축이 이 팩트에 노출돼 있지 않아
--      현재는 차수 한정이 **불가능**하다. 그 배선이 `DEC-44` 의 대상이다(🔴 회신 전 키 변경 금지).
-- ⚠️ `FACT_BUDGET.PLAN_BUDGET_YEAR` 는 계속 NULL 이다(값을 두 곳에 두지 않는다).
-- 보수 매핑(재무 오귀속 방지):
--   ORG_SK=0        — ERP 원장에 조직 귀속 축이 없다(월 팩트와 동일 사유).
--   CAMPAIGN_SK=0   — 원천 연결 없음.
--   SPONSORSHIP_SK=NULL — 원천 연결 없음.
-- 순서9 패턴 준수: incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact) — 구조·FK 보존, 데이터만 갱신.


with y as (
    select
        *,
        case BUDGET_PROCEDURE
            when '추가경정' then 2
            when '연사업' then 1
            else 0
        end as PRCD_SEQ
    from GN_DW.SILVER.ERP_BUDGET_YEARLY
),
ranked as (
    select
        *,
        dense_rank() over (partition by BUDGET_YEAR order by PRCD_SEQ desc) as rnk
    from y
)

select
    BUDGET_YEAR                           as BUDGET_YEAR,
    0                                     as ORG_SK,            -- 원천 조직귀속 없음 → Unknown
    ABS(HASH(COALESCE(CAST(BUDGET_ITEM_DK AS VARCHAR), '∅')))     as BUDGET_ITEM_SK,    -- 월 팩트와 동일 산식
    BUDGET_PROCEDURE                      as BUDGET_PROCEDURE,  -- 예산 편성 차수(DEC-44)
    0                                     as CAMPAIGN_SK,       -- 원천 연결 없음
    CAST(NULL AS NUMBER(38,0))            as SPONSORSHIP_SK,
    SUM(YEAR_BUDGET_TOT_AMT)              as PLAN_BUDGET_YEAR,  -- 연 편성
    SUM(CHN_BUDGET_TOT_AMT)               as CHN_BUDGET_YEAR,   -- 연 추경
    SUM(ADJ_BUDGET_TOT_AMT)               as ADJ_BUDGET_YEAR,   -- 연 조정
    SUM(EXEC_TOT_AMT)                     as EXEC_BUDGET_YEAR,  -- 연 집행
    'ERP'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'd38ba6a1-836d-4cd8-ac8f-ef838313ba18'                    AS DW_BATCH_ID
from ranked
where BUDGET_YEAR is not null   -- 연도 파싱 실패행 제외(NOT NULL grain 보호)
  and rnk = 1
group by
    BUDGET_YEAR,
    ABS(HASH(COALESCE(CAST(BUDGET_ITEM_DK AS VARCHAR), '∅'))),
    BUDGET_PROCEDURE