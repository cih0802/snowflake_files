-- FACT_PAYMENT_METHOD_CHANGE: 결제수단 변경 이력 팩트 (SETLE_KEY × UPDT_DT grain) — CRM_PAYMENT_METHOD_HIST
-- Co-authored with CoCo
-- 🆕 [2026-09-29 O188-F 2차-A] 신설 — 종전 파이프라인 미연결 BRONZE_CRM 원천의 GOLD 반영
-- 🔴 민감 컬럼(카드번호·빌키·인증데이터·결제자·연락처)은 SILVER 에서 이미 제외됐다.
{{ config(
    tags=['gold_pending']
) }}

select
    COALESCE({{ date_sk('UPDT_DT::DATE') }}, 0)  as DATE_SK,
    MBER_NO                                    as MEMBER_DK,
    SETLE_KEY,
    UPDT_DT,
    CPR_DIV_CD,
    SETLE_CD,
    WTDRW_STRT_DE,
    WTDRW_ASMT_SQNC,
    FNLT_DIV_CD,
    FNLT_CD,
    SETLE_ENTRPS_CD,
    ACNUT_SER_NO,
    CARD_DIV_CD,
    ETC_CTTPC_REL_CD,
    PAYER_MBER_REL_CD,
    CRTFC_MTH_CD,
    CRTFC_DE,
    FILE_SIZE,
    SETLE_STAT_CD,
    BF_SETLE_STAT_CD,
    RQST_DIV_CD,
    RCEPT_DIV_CD,
    APRV_YN,
    APRV_REQUST_KEY,
    APRV_RST_KEY,
    FRST_BEGIN_DE,
    RQEST_EXCL_YN,
    RQEST_EXCL_STRT_DE,
    RQEST_EXCL_END_DE,
    APPLCNT_ETC_CTTPC_REL_CD,
    APPLCNT_MBER_REL_CD,
    BF_SETLE_KEY,
    OPERT_DIV_CD,
    CRTFC_TY_CD,
    USE_YN,
    REGIST_DT,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_PAYMENT_METHOD_HIST') }}
