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
-- grain: MONTH_KEY × SPONSORSHIP_SK × FEE_DIV_CD × PAYMENT_TYPE × RQEST_DIV_CD × PRCS_STAT_CD × RETUN_RSN_CD × CAMPAIGN_SK
--    🆕 [2026-10-14 O225-C] CAMPAIGN_SK 를 grain 에 편입 — 「그 달 후원 캠페인」(사용자 결정 O225-B).
--       규칙 = 일시후원 `ONCE_CMPGN_CD` 우선 → 정기는 같은 회원×후원사업 span 중 청구월에 **유효한 span**
--       (시작 ≤ 청구월 · 미중단/중단월 > 청구월 우선 → 시작월 최근 → 캠페인코드) · 후보 없으면 0(미매핑).
--       📏 dry-run(xh20001) = grain 12,116 → 1,104,308행 · 원천 50,835,411행 보존 · 캠페인 보유 금액 98.86%.
--       🔴 BILLED_MEMBERS(COUNT DISTINCT)는 캠페인 간에 더하면 중복된다(종전과 같은 비가산 성질).
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


with b as (
    select * from GN_DW.SILVER.CRM_PAYMENT_BILLING
),

-- 🆕 [O225-C] 청구 행 + 그 달 후원 캠페인(정의 지점 = macros/billing_campaign_asof.sql · 행수 불변)
bc as (
    select
        bb.*,
        COALESCE(CASE WHEN TRY_TO_NUMBER(bb.MBRFEE_MT) BETWEEN 194501 AND 214512
          AND MOD(TRY_TO_NUMBER(bb.MBRFEE_MT), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(bb.MBRFEE_MT) END,
                 CASE WHEN TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM')) BETWEEN 194501 AND 214512
          AND MOD(TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM')) END, 0) as BILLING_MK,
        COALESCE(NULLIF(TRIM(bb.ONCE_CMPGN_CD), ''), sp.CMPGN_CD)               as BILLING_CMPGN_CD
    from b bb
    left join GN_DW.SILVER.CRM_MEMBER_SPONSOR_SPAN sp
           on NULLIF(TRIM(bb.ONCE_CMPGN_CD), '') is null
          and sp.MBER_NO = bb.MBER_NO
          and sp.SPNSR_BSNS_ID = bb.SPNSR_BSNS_ID
          and sp.START_MONTH_KEY <= COALESCE(CASE WHEN TRY_TO_NUMBER(bb.MBRFEE_MT) BETWEEN 194501 AND 214512
          AND MOD(TRY_TO_NUMBER(bb.MBRFEE_MT), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(bb.MBRFEE_MT) END,
                                            CASE WHEN TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM')) BETWEEN 194501 AND 214512
          AND MOD(TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM')) END, 0)
    qualify row_number() over (
        partition by bb.PAY_KEY, bb.MBRFEE_SQNC, bb.PAYMENT_TYPE
        order by IFF(sp.DSCNTC_MONTH_KEY is null
                     or sp.DSCNTC_MONTH_KEY > COALESCE(CASE WHEN TRY_TO_NUMBER(bb.MBRFEE_MT) BETWEEN 194501 AND 214512
          AND MOD(TRY_TO_NUMBER(bb.MBRFEE_MT), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(bb.MBRFEE_MT) END,
                                                       CASE WHEN TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM')) BETWEEN 194501 AND 214512
          AND MOD(TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM')) END, 0), 0, 1),
                 sp.START_MONTH_KEY desc nulls last,
                 sp.CMPGN_CD
    ) = 1
),

cmp as (
    select CAMPAIGN_BK, CAMPAIGN_SK from GN_DW.GOLD.DIM_CAMPAIGN
),

spb as (
    select SPONSORSHIP_BK, SPONSORSHIP_SK from GN_DW.GOLD.DIM_SPONSORSHIP
),

code as (
    select CD_ID, DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE
    where CD_ID in ('PM010', 'PM024', 'PM013', 'PM042')
),

keyed as (
    select
        -- 회비월 우선, 무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월 (FACT_MEMBER_FEE 와 동일 규칙 · 매크로가 계산)
        b.BILLING_MK                                    as MONTH_KEY,
        COALESCE(s.SPONSORSHIP_SK, 0)                   as SPONSORSHIP_SK,
        b.MBRFEE_DIV_CD                                 as FEE_DIV_CD,
        b.PAYMENT_TYPE                                  as PAYMENT_TYPE,
        b.RQEST_DIV_CD                                  as RQEST_DIV_CD,
        b.MBRFEE_PRCS_STAT_CD                           as PRCS_STAT_CD,
        b.RETUN_RSN_CD                                  as RETUN_RSN_CD,
        COALESCE(c.CAMPAIGN_SK, 0)                      as CAMPAIGN_SK,
        b.MBER_NO, b.RQEST_AMT, b.PAY_AMT, b.PAY_STAT_CD
    from bc b
    left join spb s on s.SPONSORSHIP_BK = b.SPNSR_BSNS_ID
    left join cmp c on c.CAMPAIGN_BK = b.BILLING_CMPGN_CD
    -- FACT_MEMBER_FEE 와 같은 필터(O45-C · 회원 미귀속 불량 행 제외)
    where b.MBER_NO is not null
),

agg as (
    select
        MONTH_KEY, SPONSORSHIP_SK, FEE_DIV_CD, PAYMENT_TYPE, RQEST_DIV_CD, PRCS_STAT_CD, RETUN_RSN_CD, CAMPAIGN_SK,
        COUNT(*)                                                    as BILLING_ROWS,
        COUNT(DISTINCT MBER_NO)                                     as BILLED_MEMBERS,
        SUM(RQEST_AMT)                                              as BILLED_AMT,
        SUM(PAY_AMT)                                                as PAID_FEE,
        SUM(CASE WHEN (PAY_STAT_CD = 'F' OR PAY_STAT_CD IS NULL)
                 THEN RQEST_AMT END)                                as UNPAID_BILLED_AMT
    from keyed
    group by 1,2,3,4,5,6,7,8
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
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '070658e8-347d-4ba9-9fd9-bb0d40c467de'                    AS DW_BATCH_ID,
    a.CAMPAIGN_SK                                                   as CAMPAIGN_SK   -- 🆕 [O225-C] 06_DDL 동기 · 맨 끝 append
from agg a
left join code fd on fd.CD_ID = 'PM010' and fd.DTL_CD_ID = a.FEE_DIV_CD
left join code rd on rd.CD_ID = 'PM024' and rd.DTL_CD_ID = a.RQEST_DIV_CD
left join code ps on ps.CD_ID = 'PM013' and ps.DTL_CD_ID = a.PRCS_STAT_CD
left join code rr on rr.CD_ID = 'PM042' and rr.DTL_CD_ID = a.RETUN_RSN_CD