-- WIDE_MEMBER_FEE: 회비 분해 소비뷰 — 후원사업 × 회비구분 × 결제수단 × 획득귀속
-- Co-authored with CoCo
-- [2026-08-06 O45] 신설. base = FACT_MEMBER_FEE(회원×회비월×후원사업×회비구분×납입유형×결제수단).
--
-- 🔴 이 뷰가 답하는 것 / 답하지 않는 것
--   답한다: 후원사업별·회비구분별(정기/선물금/일시/긴급구호)·결제수단별 청구·납입·미납,
--           납입일 기준 조회, 획득 캠페인·부서·후원사업별 회비 분해
--   답하지 않는다: 회원 **상태**(활동/미납 플래그)·개발/중단 건수 → `WIDE_MEMBER_MONTHLY` 를 쓴다
--   🔴 두 뷰의 회비를 **같은 표에서 합하지 말 것** — 같은 원천이라 이중계상이다.
{{ config(
    materialized='view',
    tags=['gold_ready'],
    post_hook=[
      "COMMENT ON VIEW {{ this }} IS '회비 분해 소비뷰(O45). grain = 회원 × 회비월 × 후원사업 × 회비구분 × 납입유형 × 결제수단. 🔴WIDE_MEMBER_MONTHLY 의 회비 measure 와 같은 표에서 합산 금지 — 동일 원천이라 이중계상이다. 획득귀속 축(ACQ_*)은 「이 회원을 데려온」 캠페인·부서·후원사업이며 납입 대상 후원사업(SPONSORSHIP_NAME)과 의미가 다르다.'",
      "ALTER VIEW {{ this }} ALTER COLUMN MONTH_KEY COMMENT '회비월 YYYYMM (무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월 — FMM 과 동일 규칙)', COLUMN CAL_YEAR COMMENT 'FLOOR(MONTH_KEY/100) — 연도', COLUMN CAL_MONTH COMMENT 'MOD(MONTH_KEY,100) — 월', COLUMN SPONSORSHIP_NAME COMMENT '🔴**납입 대상** 후원사업 — 회비 행에 붙은 값이다(원천 SPNSR_BSNS_ID 채움 99.83%·36종). 획득 후원사업(ACQ_SPONSORSHIP_NAME)과 다르다: 한 회원이 여러 후원사업에 낸다(회원-월 조합 37,148,615 → 회원-월-후원사업 39,563,730 = 6.5% 증가). 이것이 이 팩트를 FMM 과 분리한 이유다', COLUMN FEE_DIV_NAME COMMENT '회비구분(PM010 실측 확정): 정기·선물금·일시·긴급구호. 🔴기부금 행은 원천이 NULL 이다 — 결측이 아니라 해당없음(P21)', COLUMN PAYMENT_TYPE COMMENT '납입유형 = 회비/기부금. 🔴납부율·미납 분석은 회비만으로 스코프할 것 — 기부금은 원천에 청구(RQEST_AMT)가 전건 NULL 이라 분모에 들어갈 수 없다(O40)', COLUMN PAYMENT_METHOD_NAME COMMENT '결제수단 라벨. ⚠️커버리지 99.3%(6종=자동이체·신용카드·네이버페이·회비통장·OCR·휴대폰) — 원천 11종 중 5종(3·10·6·13·7, 225,855행=0.48%)은 **코드그룹 미특정**으로 (미매핑)이다. CRM_CODE 에서 11종을 덮는 그룹이 6개 나왔으나 전부 의미 무관(간사/질병/취미…)이라 추측하지 않았다 — 숫자 코드 우연 일치(P36). 원본 코드는 SETLE_CD 로 보존', COLUMN SETLE_CD COMMENT '결제수단 원본 코드(degen). 라벨 없는 5종을 잃지 않기 위해 보존한다 — 현업 코드그룹 확인 대상(O45-B)', COLUMN LAST_PAY_DATE_SK COMMENT '해당 조합의 **최종 납입일** (FK→DIM_DATE). 🔴합계가 아니라 시점 축이다. FMM 은 월 팩트라 일자 분해가 불가하므로 「기준일(납입일)」 요구는 이 뷰에서만 답한다', COLUMN ACQ_DEPARTMENT COMMENT '🔴**획득(최초개발) 시점 부서**다. 개발실적보고의 「부서」(=사건 부서)와 다르다 — 사건 부서는 WIDE_MEMBER_EVENT.ORG_DEPARTMENT 를 쓴다(O34 _AT_PLEDGE/_AT_EVENT 규약의 재적용)', COLUMN ACQ_MARKETING_CAMPAIGN COMMENT '획득 캠페인의 마케팅캠페인(O45 conformed 축). 광고비와 결합할 때 이 축을 쓴다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃)', COLUMN BILLED_AMT COMMENT '청구액(원) = SUM(RQEST_AMT). FMM 과 동일 식이므로 전체 합계가 일치해야 한다(기준값 891,959,790,888)', COLUMN PAID_FEE COMMENT '납입 총액(원) = 회비 + 기부금. 🔴납부율 분자로 쓰지 말 것(O40) — PAID_FEE_BILLABLE 을 쓴다', COLUMN PAID_FEE_BILLABLE COMMENT '회비 납입액(원) — 납부율 분자 정본(O40)', COLUMN UNPAID_BILLED_AMT COMMENT '미납 청구액(원) — DEC-3 정본 = PAY_STAT_CD IN (F, NULL) 인 청구액. 🔴차감식(청구−납입) 아님. ⚠️조회 시점 스냅샷 — 과거 미납이 이후 납입되면 값이 바뀐다', COLUMN BILLING_ROWS COMMENT '집계된 원천 회비행 수. 🔴금액이 아니다 — 「건수」로 쓰지 말 것(정본 (건) 정의는 CONF-2 미결)', COLUMN UNPAID_FLAG COMMENT '해당 조합에 미납 청구행이 하나라도 있는가(BOOLOR_AGG). 회원 단위 미납 여부는 WIDE_MEMBER_MONTHLY 의 UNPAID_FLAG_EOM 을 쓴다'"
    ]
) }}

select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100)                    as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)                       as CAL_MONTH,
    f.MEMBER_DK,
    -- ── 납입 대상 축 ──────────────────────────────────────────────────────────
    f.SPONSORSHIP_SK,
    s.SPONSORSHIP_NAME                          as SPONSORSHIP_NAME,
    f.FEE_DIV_CD,
    f.FEE_DIV_NAME                              as FEE_DIV_NAME,
    f.PAYMENT_TYPE                              as PAYMENT_TYPE,
    f.PAYMENT_SK,
    p.SETTLE_METHOD                             as PAYMENT_METHOD_NAME,
    f.SETLE_CD                                  as SETLE_CD,
    f.LAST_PAY_DATE_SK,
    dp.FULL_DATE                                as LAST_PAY_DATE,
    f.LAST_BILL_DATE_SK,
    -- ── 회원 현재 속성 (SCD2 현재행 1건) ──────────────────────────────────────
    mem.MBER_STAT_CD                            as MBER_STAT_CD,
    mem.MEMBER_STATUS_NAME                      as MEMBER_STATUS_NAME,
    mem.MBER_DIV_CD                             as MBER_DIV_CD,
    mem.MEMBER_TYPE_NAME                        as MEMBER_TYPE_NAME,
    mem.SEX                                     as SEX,
    mem.GENDER_NAME                             as GENDER_NAME,
    -- ── 획득 귀속 축 (O45 · LEFT JOIN 필수 — 개발사건 없는 회원 1.61% 존재) ───
    acq.ACQ_CAMPAIGN_SK,
    acq.ACQ_BRAND                               as ACQ_BRAND,
    acq.ACQ_CAMPAIGN_NAME                       as ACQ_CAMPAIGN_NAME,
    acq.ACQ_PARENT_CAMPAIGN_NAME                as ACQ_PARENT_CAMPAIGN_NAME,
    acq.ACQ_PROMO_METHOD_NAME                   as ACQ_PROMO_METHOD_NAME,
    acq.ACQ_MARKETING_CAMPAIGN                  as ACQ_MARKETING_CAMPAIGN,
    acq.ACQ_ORG_SK,
    acq.ACQ_DEPARTMENT                          as ACQ_DEPARTMENT,
    acq.ACQ_SPONSORSHIP_SK,
    acq.ACQ_SPONSORSHIP_NAME                    as ACQ_SPONSORSHIP_NAME,
    acq.ACQ_AGE_BAND                            as ACQ_AGE_BAND,
    acq.ACQ_REGION                              as ACQ_REGION,
    -- ── measure ──────────────────────────────────────────────────────────────
    f.BILLED_AMT,
    f.PAID_FEE,
    f.PAID_FEE_BILLABLE,
    f.UNPAID_BILLED_AMT,
    f.BILLING_ROWS,
    f.UNPAID_FLAG
from {{ ref('FACT_MEMBER_FEE') }} f
left join {{ ref('DIM_SPONSORSHIP') }} s        on s.SPONSORSHIP_SK  = f.SPONSORSHIP_SK
left join {{ ref('DIM_PAYMENT') }} p            on p.PAYMENT_SK      = f.PAYMENT_SK
left join {{ ref('DIM_DATE') }} dp              on dp.DATE_SK        = f.LAST_PAY_DATE_SK
-- 회원 차원은 SCD2 → 현재행 1건만 (WIDE 공통 패턴)
left join (
    select MEMBER_DK, SEX, GENDER_NAME, MBER_STAT_CD, MEMBER_STATUS_NAME,
           MBER_DIV_CD, MEMBER_TYPE_NAME
    from {{ ref('DIM_MEMBER') }}
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) mem on mem.MEMBER_DK = f.MEMBER_DK
-- [O45] 회원 귀속 차원. 1행/회원이므로 fan-out 0(실측 확인).
left join {{ ref('DIM_MEMBER_ACQUISITION') }} acq on acq.MEMBER_DK = f.MEMBER_DK
