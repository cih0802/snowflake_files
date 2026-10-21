-- =============================================================================
-- Purpose    : 외부 수기 업로드 SILVER.MM_SPNSR_CLS_AGGR_DATA 의 grain 중복 감시(1행 = 중복된 키 1개).
-- Target     : dbt singular test warn_spnsr_cls_aggr_src_dup (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : source silver_external.MM_SPNSR_CLS_AGGR_DATA
-- Issue      : -
-- =============================================================================
-- 외부 수기 업로드 SILVER.MM_SPNSR_CLS_AGGR_DATA 의 grain 중복 감시(1행 = 중복된 키 1개).
-- [2026-10-16 사용자 결정] WIDE_SPNSR_CLS_AGGR 는 큰 값 1건을 남겨 grain 을 지킨다 — 이 테스트는 원천 정리 신호다.
--   실패 행은 OPS 에 고정되고(store_failures) 담당자 메일 알림이 이 테이블을 읽는다.


select
    STDR_MT, AGGR_TY_NM, CPR_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM,
    COUNT(*)                                as ROW_CNT,
    COUNT(DISTINCT HASH(VALUE1, VALUE2))    as VALUE_VERSIONS,
    MIN(VALUE1)                             as VALUE1_MIN,
    MAX(VALUE1)                             as VALUE1_MAX
from GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
group by STDR_MT, AGGR_TY_NM, CPR_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM
having COUNT(*) > 1