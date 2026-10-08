-- FACT_PAYMENT_BILLING_STATUS: 회비 청구 처리 상태 팩트 — 청구구분 × 처리상태 × 환급사유별 청구·납입 건수·금액
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-10-08 O213 Y3-D] 신설 — 왜 FACT_MEMBER_FEE 에 컬럼을 붙이지 않고 팩트를 나누는가
-- ----------------------------------------------------------------------------
-- 🔴 청구구분·처리상태·환급사유는 회원×월×후원사업×회비구분×납입유형×결제수단 조합 안에서
--    **청구 행마다 갈리는 운영 상태값**이다. FACT_MEMBER_FEE 의 GROUP BY 에 넣으면 grain 이 바뀐다
--    (실측 2026-08 SILVER 기준 · NULL-safe = 기본 42,672,118 → 처리 6축 포함 44,401,745 · +4.05%).
--    ⇒ O45 선례(「grain 이 다르면 팩트를 나눈다」)를 따른다. FACT_MEMBER_FEE 는 **무변경**이다.
--
-- grain: MONTH_KEY × SPONSORSHIP_SK × FEE_DIV_CD × PAYMENT_TYPE × RQEST_DIV_CD × PRCS_STAT_CD × RETUN_RSN_CD
--    🔴 회원 축을 두지 않는다 — 이 팩트는 「청구 처리 현황」(몇 건이 어떤 상태로 처리됐나) 질문용이고
--       회원 단위 질문은 FACT_MEMBER_FEE / FACT_MEMBER_MONTHLY 소관이다(행 수 · 비용 · 중복 정의 회피).
--
-- 라벨 코드그룹(2026-10-08 실측 · SILVER.CRM_CODE):
--   RQEST_DIV_CD  = PM024 (1=정기청구 · 2=OCR신규 · 9=개별청구 · 라벨 커버 97.4% · 🔴 `Y` 는 사전에 없다 ⇒ 라벨 NULL)
--   PRCS_STAT_CD  = PM013 (R=청구 · S=완료 · 커버 97.8% · 🔴 `F` 는 사전에 없다 ⇒ 라벨 NULL)
--   RETUN_RSN_CD  = PM042 (11종 전부 라벨 · 값이 있는 행은 0.03% · 나머지는 환급이 아니라 NULL)
-- 🔴 제외(문서20 현업 확인 등재): 청구결과 RQEST_RST_CD(PM002 사전과 89/101 불일치) ·
--    처리결과 PRCS_RST_CD(은행·카드 응답코드 혼재 · 코드그룹 미특정 · P36 우연 일치 금지) · 함께출금여부(운영 플래그).
--
-- measure 식은 FACT_MEMBER_FEE 와 **같은 식**을 쓴다(O40 정본) — 축만 다르다.
--   ⚠️ 검증 = SUM(BILLED_AMT) 가 FACT_MEMBER_FEE 의 SUM(BILLED_AMT) 와 일치해야 한다(같은 원천 · 같은 필터).
-- ============================================================================
{{ config(
    tags=['gold_ready']
) }}

with b as (
    select * from {{ ref('CRM_PAYMENT_BILLING') }}
),

spb as (
    select SPONSORSHIP_BK, SPONSORSHIP_SK from {{ ref('DIM_SPONSORSHIP') }}
),

code as (
    select CD_ID, DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }}
    where CD_ID in ('PM010', 'PM024', 'PM013', 'PM042')
),

keyed as (
    select
        -- 회비월 우선, 무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월 (FACT_MEMBER_FEE 와 동일 규칙)
        COALESCE({{ month_key_clamp('TRY_TO_NUMBER(b.MBRFEE_MT)') }},
                 {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(b.PAY_DE,'YYYYMM'))") }}, 0) as MONTH_KEY,
        COALESCE(s.SPONSORSHIP_SK, 0)                   as SPONSORSHIP_SK,
        b.MBRFEE_DIV_CD                                 as FEE_DIV_CD,
        b.PAYMENT_TYPE                                  as PAYMENT_TYPE,
        b.RQEST_DIV_CD                                  as RQEST_DIV_CD,
        b.MBRFEE_PRCS_STAT_CD                           as PRCS_STAT_CD,
        b.RETUN_RSN_CD                                  as RETUN_RSN_CD,
        b.MBER_NO, b.RQEST_AMT, b.PAY_AMT, b.PAY_STAT_CD
    from b
    left join spb s on s.SPONSORSHIP_BK = b.SPNSR_BSNS_ID
    -- FACT_MEMBER_FEE 와 같은 필터(O45-C · 회원 미귀속 불량 행 제외)
    where b.MBER_NO is not null
),

agg as (
    select
        MONTH_KEY, SPONSORSHIP_SK, FEE_DIV_CD, PAYMENT_TYPE, RQEST_DIV_CD, PRCS_STAT_CD, RETUN_RSN_CD,
        COUNT(*)                                                    as BILLING_ROWS,
        COUNT(DISTINCT MBER_NO)                                     as BILLED_MEMBERS,
        SUM(RQEST_AMT)                                              as BILLED_AMT,
        SUM(PAY_AMT)                                                as PAID_FEE,
        SUM(CASE WHEN PAY_STAT_CD = 'F' OR PAY_STAT_CD IS NULL
                 THEN RQEST_AMT END)                                as UNPAID_BILLED_AMT
    from keyed
    group by 1,2,3,4,5,6,7
)

select
    a.MONTH_KEY, a.SPONSORSHIP_SK,
    a.FEE_DIV_CD,
    fd.DTL_CD_NM                                                    as FEE_DIV_NAME,
    a.PAYMENT_TYPE,
    a.RQEST_DIV_CD,
    rd.DTL_CD_NM                                                    as RQEST_DIV_NAME,
    a.PRCS_STAT_CD,
    ps.DTL_CD_NM                                                    as PRCS_STAT_NAME,
    a.RETUN_RSN_CD,
    rr.DTL_CD_NM                                                    as RETUN_RSN_NAME,
    a.BILLING_ROWS, a.BILLED_MEMBERS,
    a.BILLED_AMT, a.PAID_FEE, a.UNPAID_BILLED_AMT,
    {{ gold_meta('CRM') }}
from agg a
left join code fd on fd.CD_ID = 'PM010' and fd.DTL_CD_ID = a.FEE_DIV_CD
left join code rd on rd.CD_ID = 'PM024' and rd.DTL_CD_ID = a.RQEST_DIV_CD
left join code ps on ps.CD_ID = 'PM013' and ps.DTL_CD_ID = a.PRCS_STAT_CD
left join code rr on rr.CD_ID = 'PM042' and rr.DTL_CD_ID = a.RETUN_RSN_CD
