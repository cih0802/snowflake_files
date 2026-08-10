-- FACT_MEMBER_FEE: 회비 분해 팩트 — 후원사업 × 회비구분 × 결제수단별 청구·납입·미납
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-08-06 O45] 신설 — 왜 컬럼 추가가 아니라 팩트 신설인가
-- ----------------------------------------------------------------------------
-- 🔴 `FACT_MEMBER_MONTHLY` 의 grain 은 **회원 × 월 정확히 1행**이다(실측 40,054,883 =
--    distinct member-month). 여기에 후원사업을 컬럼으로 붙이면 **grain 이 깨진다**:
--      회원-월 조합            37,148,615
--      회원-월-후원사업 조합    39,563,730  → **6.5% 증가**
--    즉 한 회원-월이 복수 후원사업에 회비를 낸다. FMM 에 붙이려면 **귀속 규칙(임의 선택)**이
--    필요하고 그 순간 후원사업별 회비 합계가 원천과 어긋난다.
--    ⇒ **grain 이 다르면 팩트를 나눈다.** 이것이 교과서적 해법이고 O8(다중귀속) 을 회피하는 길이다.
--
-- grain: MEMBER_DK × MONTH_KEY × SPONSORSHIP_SK × FEE_DIV_CD × PAYMENT_TYPE × PAYMENT_SK
--    실측 조합수 ≈ **39,810,101** (원천 47,521,872행의 집계)
--
-- 🔴 measure 정의는 `FACT_MEMBER_MONTHLY` 와 **완전히 동일한 식**을 쓴다(O40 정본).
--    다른 식을 쓰면 두 팩트의 합계가 어긋나 어느 쪽이 맞는지 아무도 모르게 된다.
--      BILLED_AMT        = SUM(RQEST_AMT)
--      PAID_FEE          = SUM(PAY_AMT)                                  -- 회비 ∪ 기부금
--      PAID_FEE_BILLABLE = SUM(CASE WHEN PAYMENT_TYPE='회비' THEN PAY_AMT END)
--      UNPAID_BILLED_AMT = SUM(CASE WHEN PAY_STAT_CD='F' OR NULL THEN RQEST_AMT END)  -- DEC-3
--    ⚠️ 검증 필수: `SUM(BILLED_AMT)` 이 FMM 과 일치해야 한다(실측 기준값 891,959,790,888).
--       납입은 FMM 이 0.004% 낮다(월키 클램프 추정) → 신설 후 차이 원인을 규명할 것.
--
-- ── 축 커버리지 실측(2026-08-06) ──────────────────────────────────────────────
--   `SPNSR_BSNS_ID`    47,439,264 / 47,521,872 = **99.83%** · 36종 (차원 고아 코드 1종 → 센티넬)
--   `MBRFEE_DIV_CD`    46,391,620 채움 · 4종 = PM010(E=정기 · G=선물금 · I=일시 · U=긴급구호)
--                      🔴 NULL 1,130,252행 = **전부 기부금**(PAYMENT_TYPE='기부금') → 정상 NULL
--   `SETLE_CD`         47,415,584 채움 · **11종**
--                      🔴 그런데 `DIM_PAYMENT` 는 6종만 갖는다(`CRM_PAYMENT_METHOD` distinct).
--                      라벨 있는 6종이 47,189,729행 = **99.3%** 를 덮고, 라벨 없는 5종
--                      (`3`·`10`·`6`·`13`·`7`) 225,855행 = 0.48% 는 센티넬로 간다.
--                      ⚠️ `SETLE_CD` 의 표준 코드그룹은 **특정되지 않았다** — CRM_CODE 에서
--                      11종을 모두 덮는 그룹이 6개나 나왔고 전부 의미가 무관했다(간사/질병/취미…).
--                      **숫자 코드 우연 일치다(P36)** → 추측 금지. 원본 코드를 degen 으로 보존하고
--                      현업 확인 대상으로 남긴다(신규 이슈 O45-B).
--
-- 순서9 규약: fact = incremental + append + pre-hook TRUNCATE. 구조 소유주 = `03_top-down_gold/06_DDL.sql`.
-- ============================================================================


with b as (
    select * from GN_DW.SILVER.CRM_PAYMENT_BILLING
),

spb as (
    select SPONSORSHIP_BK, SPONSORSHIP_SK from GN_DW.GOLD.DIM_SPONSORSHIP
),

pay as (
    select PAYMENT_METHOD, PAYMENT_SK from GN_DW.GOLD.DIM_PAYMENT
),

-- 회비구분 라벨(PM010). 🔴 코드그룹을 실측으로 확정한 축이다 — 4종 전부 원천 값과 일치.
fee_div as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'PM010'
),

keyed as (
    select
        -- 회비월 우선, 무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월 (FMM 과 동일 규칙)
        COALESCE(CASE WHEN TRY_TO_NUMBER(b.MBRFEE_MT) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(b.MBRFEE_MT), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(b.MBRFEE_MT) END,
                 CASE WHEN TRY_TO_NUMBER(TO_CHAR(b.PAY_DE,'YYYYMM')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(TO_CHAR(b.PAY_DE,'YYYYMM')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(TO_CHAR(b.PAY_DE,'YYYYMM')) END, 0) as MONTH_KEY,
        b.MBER_NO                                       as MEMBER_DK,
        COALESCE(s.SPONSORSHIP_SK, 0)                   as SPONSORSHIP_SK,
        COALESCE(p.PAYMENT_SK, 0)                       as PAYMENT_SK,
        b.MBRFEE_DIV_CD                                 as FEE_DIV_CD,
        b.PAYMENT_TYPE                                  as PAYMENT_TYPE,
        b.SETLE_CD                                      as SETLE_CD,       -- degen: 라벨 없는 5종 보존
        b.RQEST_AMT, b.PAY_AMT, b.PAY_STAT_CD, b.PAY_DE, b.RQEST_DE
    from b
    left join spb s on s.SPONSORSHIP_BK = b.SPNSR_BSNS_ID
    left join pay p on p.PAYMENT_METHOD = b.SETLE_CD
    -- ── [2026-08-06 O45-C] 회원 미귀속 불량 행 제외 — `FACT_MEMBER_MONTHLY` 규약과 일치시킨다 ──
    --   🔴 왜 필요한가: FMM 은 이 필터를 쓰는데(FACT_MEMBER_MONTHLY.sql:100) FMF 는 쓰지 않아
    --      `PAID_FEE` 만 두 팩트가 어긋났다(O45-C). 청구·회비납입·미납 3종은 원래 일치했으므로
    --      납부율에는 영향이 없었지만, **FMF 테이블 COMMENT 가 「measure 식은 FMM 과 완전히 동일」이라고
    --      단정**하고 있어 그 서술이 거짓인 상태였다.
    --   🔴 제외 대상: `MBER_NO IS NULL` 행. 실측(2026-08-06) 5행 · `SUM(PAY_AMT)` 34,672,700 ·
    --      2011-03/04 납입 · `RQEST_AMT` NULL · `MBRFEE_DIV_CD` NULL · `SPNSR_BSNS_ID`=33.
    --      회원 grain 팩트에서 `MEMBER_DK` NULL 행은 `DIM_MEMBER` 로 조인되지 않아 **어차피 소비 불가**이고,
    --      총계만 SILVER 원표와 맞아 보이게 만든다(P67 계열).
    --   ⚠️ 이 필터로 `PAID_FEE` 총계가 895,212,981,808 → 895,178,309,108 로 내려간다(= FMM 과 동일).
    --      SILVER 원표 전체 합과 다르다는 점은 정상이며, 그 차이가 곧 이 불량 5행이다.
    where b.MBER_NO is not null
),

agg as (
    select
        MONTH_KEY, MEMBER_DK, SPONSORSHIP_SK, PAYMENT_SK,
        FEE_DIV_CD, PAYMENT_TYPE, SETLE_CD,
        SUM(RQEST_AMT)                                              as BILLED_AMT,
        SUM(PAY_AMT)                                                as PAID_FEE,
        SUM(CASE WHEN PAYMENT_TYPE = '회비' THEN PAY_AMT END)        as PAID_FEE_BILLABLE,
        -- DEC-3 정본 미납 = 결제상태 실패(F) 또는 NULL 인 **청구액**. 차감식 금지(O40).
        SUM(CASE WHEN PAY_STAT_CD = 'F' OR PAY_STAT_CD IS NULL
                 THEN RQEST_AMT END)                                as UNPAID_BILLED_AMT,
        COUNT(*)                                                    as BILLING_ROWS,
        BOOLOR_AGG(PAY_STAT_CD = 'F' OR PAY_STAT_CD IS NULL)        as UNPAID_FLAG,
        -- 🔴 일 grain 축: 「기준일(납입일)」 요구를 여기서만 답할 수 있다(FMM 은 월 팩트).
        --   같은 조합에 납입일이 여러 개면 **최종 납입일**을 쓴다 — 합계가 아니라 시점 축이다.
        COALESCE(CASE WHEN MAX(PAY_DE) BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(MAX(PAY_DE), 'YYYYMMDD')) END, 0)                   as LAST_PAY_DATE_SK,
        COALESCE(CASE WHEN MAX(RQEST_DE) BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(MAX(RQEST_DE), 'YYYYMMDD')) END, 0)                 as LAST_BILL_DATE_SK
    from keyed
    group by 1,2,3,4,5,6,7
)

select
    a.MONTH_KEY, a.MEMBER_DK, a.SPONSORSHIP_SK, a.PAYMENT_SK,
    a.FEE_DIV_CD,
    -- 회비구분 라벨. 기부금은 원천이 NULL 이므로 '(해당없음)' 이 아니라 NULL 로 둔다(P21).
    fd.DTL_CD_NM                                                    as FEE_DIV_NAME,
    a.PAYMENT_TYPE, a.SETLE_CD,
    a.LAST_PAY_DATE_SK, a.LAST_BILL_DATE_SK,
    a.BILLED_AMT, a.PAID_FEE, a.PAID_FEE_BILLABLE, a.UNPAID_BILLED_AMT,
    a.BILLING_ROWS, a.UNPAID_FLAG,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'a88f9d92-e51a-4588-9cc2-c02608b2e0da'                    AS DW_BATCH_ID
from agg a
left join fee_div fd on fd.DTL_CD_ID = a.FEE_DIV_CD