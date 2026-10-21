-- =============================================================================
-- Purpose    : 청구 행 1건 → 「그 달 후원 캠페인」 코드 1개 (O225-C · 사용자 결정 O225-B)
-- Target     : macro billing_campaign_asof
-- Run order  : dbt 가 호출 (직접 실행 없음)
-- Depends on : ref CRM_MEMBER_SPONSOR_SPAN
-- Issue      : O225-C, O225-B
-- =============================================================================
-- billing_campaign_asof: 청구 행 1건 → 「그 달 후원 캠페인」 코드 1개 (O225-C · 사용자 결정 O225-B)
--
-- 정의 지점은 이 매크로 하나다 — FACT_PAYMENT_BILLING_STATUS · FACT_MEMBER_MONTHLY 가 같은 규칙을 쓴다.
--   규칙: ① 일시후원 ONCE_CMPGN_CD 가 있으면 그것
--         ② 없으면 같은 회원 × 후원사업 span 중 시작월 <= 청구월 인 것에서
--            미중단 또는 중단월 > 청구월(= 그 달 유효) 우선 → 시작월 최근 → 캠페인코드(결정성)
--         ③ 후보가 없으면 NULL (호출측이 SK 0 = 미매핑으로 보낸다)
--   왜 as-of 인가: 같은 회원 × 후원사업에 캠페인이 바뀐 이력이 있다(xh20001 실측 168,437 / 1,914,230 키).
--   반환: 청구 relation 의 모든 컬럼 + MK(청구월 키) + BILLING_CMPGN_CD. 행수는 입력과 같다(row_number = 1).
-- 인자: billing_rel = CRM_PAYMENT_BILLING 의 ref 또는 CTE 이름 (MBER_NO is not null 필터는 호출측 책임)
{% macro billing_campaign_asof(billing_rel) -%}
    select
        bb.*,
        COALESCE({{ month_key_clamp('TRY_TO_NUMBER(bb.MBRFEE_MT)') }},
                 {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM'))") }}, 0) as BILLING_MK,
        COALESCE(NULLIF(TRIM(bb.ONCE_CMPGN_CD), ''), sp.CMPGN_CD)               as BILLING_CMPGN_CD
    from {{ billing_rel }} bb
    left join {{ ref('CRM_MEMBER_SPONSOR_SPAN') }} sp
           on NULLIF(TRIM(bb.ONCE_CMPGN_CD), '') is null
          and sp.MBER_NO = bb.MBER_NO
          and sp.SPNSR_BSNS_ID = bb.SPNSR_BSNS_ID
          and sp.START_MONTH_KEY <= COALESCE({{ month_key_clamp('TRY_TO_NUMBER(bb.MBRFEE_MT)') }},
                                            {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM'))") }}, 0)
    qualify row_number() over (
        partition by bb.PAY_KEY, bb.MBRFEE_SQNC, bb.PAYMENT_TYPE
        order by IFF(sp.DSCNTC_MONTH_KEY is null
                     or sp.DSCNTC_MONTH_KEY > COALESCE({{ month_key_clamp('TRY_TO_NUMBER(bb.MBRFEE_MT)') }},
                                                       {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(bb.PAY_DE,'YYYYMM'))") }}, 0), 0, 1),
                 sp.START_MONTH_KEY desc nulls last,
                 sp.CMPGN_CD
    ) = 1
{%- endmacro %}
