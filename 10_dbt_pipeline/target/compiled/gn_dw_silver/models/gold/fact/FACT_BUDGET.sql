-- FACT_BUDGET: 예산 팩트 (SILVER.ERP_BUDGET 월별 언피벗 → MONTH×BUDGET_ITEM), 순서9-C 신설.
-- Co-authored with CoCo
-- 보수 매핑(재무 오귀속 방지): EXEC_BUDGET_ERP=EXEC_AMT · PLAN_BUDGET_MONTH=YEAR_BUDGET_AMT(월 편성) 만 확정.
--   ORG_SK=0: ERP_BUDGET 원장에 조직 귀속 없음(원천 grain=예산과목×월) → Unknown 라우팅.
--   CAMPAIGN_SK=0·SPONSORSHIP_SK=NULL: 원천 연결 없음.
--   NULL(원천 부재/미해소): EXEC_BUDGET_EST(추정집행)·FUNDRAISING_COST(E-1 원천부재).
-- 🔴 [2026-09-21 O175] `AD_COST` 는 **폐기 슬롯이다**(의도적 영구 NULL) — 종전 주석의
--    *"E-4 원천부재"* 는 **거짓이었다**. 대행사 원천 3종에 광고비가 전량 실재하고
--    이미 `GOLD.FACT_AD_PERFORMANCE.AD_COST` 로 일 grain 배선돼 있다(원천 합 일치).
--    ⚠️ 여기에 광고비를 넣지 말 것 — 예산 원장에는 광고비 예산항목이 없어
--    `BUDGET_ITEM_SK` 귀속 근거가 없고, 광고 팩트와 이중계상이 된다.
--    소비 안내: 광고비 정본 = `SERVING.SV_AD.TOTAL_AD_COST`(base `GOLD.WIDE_AD_COMBINED`).
-- 🔴 [2026-08-20 O93] `PLAN_BUDGET_YEAR` 는 **의도적으로 NULL 이다** — 종전 주석의
--    *"추경 CHN·조정 ADJ 는 GOLD 슬롯 부재 → 매핑확인 TODO"* 는 해소됐다.
--    원장의 연 총액 4종(편성·추경·조정·집행)은 **`FACT_BUDGET_YEARLY`(연 grain)** 로 분리했다.
--    ⚠️ 여기에 연값을 넣지 말 것 — 이 팩트는 월 grain 이라 12개월에 복제되고 `SUM()` 이 12배가 된다.
--    소비 안내: 연 편성 = `FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR` · 월 편성 = 아래 `PLAN_BUDGET_MONTH`.


with b as (
    select
        *,
        case BUDGET_PROCEDURE
            when '추가경정' then 2
            when '연사업' then 1
            else 0
        end as PRCD_SEQ
    from GN_DW.SILVER.ERP_BUDGET
),
ranked as (
    select
        *,
        dense_rank() over (partition by BUDGET_YEAR order by PRCD_SEQ desc) as rnk
    from b
)

select
    COALESCE(CASE WHEN TRY_TO_NUMBER(MONTH_KEY) BETWEEN 194501 AND 214512
          AND MOD(TRY_TO_NUMBER(MONTH_KEY), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(MONTH_KEY) END, 0)  as MONTH_KEY,
    0                                     as ORG_SK,            -- 원천 조직귀속 없음 → Unknown
    ABS(HASH(COALESCE(CAST(BUDGET_ITEM_DK AS VARCHAR), '∅')))     as BUDGET_ITEM_SK,
    BUDGET_PROCEDURE                      as BUDGET_PROCEDURE,  -- 예산 편성 차수(DEC-44)
    0                                     as CAMPAIGN_SK,       -- 원천 연결 없음
    CAST(NULL AS NUMBER(38,0))            as SPONSORSHIP_SK,
    SUM(YEAR_BUDGET_AMT)                  as PLAN_BUDGET_MONTH, -- 월 편성예산
    -- 🔴 [2026-09-01 O130] `PLAN_BUDGET_YEAR` 드랍 — O96 판정(§7-B A군) 집행.
    --    연값은 `FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR` 로 이미 분리돼 있어 이 컬럼은 항상 NULL이었다.
    SUM(EXEC_AMT)                         as EXEC_BUDGET_ERP,   -- ERP 집행
    CAST(NULL AS NUMBER(18,2))            as EXEC_BUDGET_EST,   -- 추정집행 미산출
    CAST(NULL AS NUMBER(18,2))            as FUNDRAISING_COST,  -- E-1 원천부재
    CAST(NULL AS NUMBER(18,2))            as AD_COST,           -- 폐기 슬롯(O175) · 정본=FACT_AD_PERFORMANCE
    'ERP'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b6399ce8-b69a-4e04-8dfb-ec2beaa941f8'                    AS DW_BATCH_ID
from ranked
where rnk = 1
group by
    COALESCE(CASE WHEN TRY_TO_NUMBER(MONTH_KEY) BETWEEN 194501 AND 214512
          AND MOD(TRY_TO_NUMBER(MONTH_KEY), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(MONTH_KEY) END, 0),
    ABS(HASH(COALESCE(CAST(BUDGET_ITEM_DK AS VARCHAR), '∅'))),
    BUDGET_PROCEDURE