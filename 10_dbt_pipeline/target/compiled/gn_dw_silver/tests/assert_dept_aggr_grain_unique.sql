-- =============================================================================
-- Purpose    : 부서 집계 GOLD 뷰 3종의 grain 유일성 (O200-A 신설)
-- Target     : dbt singular test assert_dept_aggr_grain_unique (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref WIDE_DVLP_GOAL_ACMSLT, ref WIDE_MBRFEE_PRDT_ACTL, ref WIDE_SPNSR_CLS_AGGR
-- Issue      : O200-A
-- =============================================================================
-- assert_dept_aggr_grain_unique: 부서 집계 GOLD 뷰 3종의 grain 유일성 (O200-A 신설)
-- 반환 행 = grain 중복 키(0행이어야 PASS). dbt_utils 미설치라 singular 테스트로 둔다.
select 'WIDE_DVLP_GOAL_ACMSLT' as model_name, COUNT(*) as dup_cnt
from GN_DW.GOLD.WIDE_DVLP_GOAL_ACMSLT
group by MONTH_KEY, DEPT_DIV_NM, NEW_EXST_DIV_NM, SPNSR_BSNS_GRP_NM
having COUNT(*) > 1

union all

select 'WIDE_MBRFEE_PRDT_ACTL', COUNT(*)
from GN_DW.GOLD.WIDE_MBRFEE_PRDT_ACTL
group by MONTH_KEY, DATA_TYPE_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM
having COUNT(*) > 1

union all

select 'WIDE_SPNSR_CLS_AGGR', COUNT(*)
from GN_DW.GOLD.WIDE_SPNSR_CLS_AGGR
group by MONTH_KEY, AGGR_TY_NM, CPR_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM
having COUNT(*) > 1