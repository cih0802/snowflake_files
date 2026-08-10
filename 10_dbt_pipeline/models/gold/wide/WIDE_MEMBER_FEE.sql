-- WIDE_MEMBER_FEE: 회비 분해 소비뷰 — 후원사업 × 회비구분 × 결제수단 × 획득귀속
-- Co-authored with CoCo
-- [2026-08-06 O45] 신설. base = FACT_MEMBER_FEE(회원×회비월×후원사업×회비구분×납입유형×결제수단).
--
-- 🔴 이 뷰가 답하는 것 / 답하지 않는 것
--   답한다: 후원사업별·회비구분별(정기/선물금/일시/긴급구호)·결제수단별 청구·납입·미납,
--           납입일 기준 조회, 획득 캠페인·부서·후원사업별 회비 분해
--   답하지 않는다: 회원 **상태**(활동/미납 플래그)·개발/중단 건수 → `WIDE_MEMBER_MONTHLY` 를 쓴다
--   🔴 두 뷰의 회비를 **같은 표에서 합하지 말 것** — 같은 원천이라 이중계상이다.
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.
{{ config(
    materialized='gn_view_commented',
    tags=['gold_ready']
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
