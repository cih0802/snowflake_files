-- assert_dept_aggr_grain_unique: 부서 집계 GOLD 뷰 3종의 grain 유일성 (O200-A 신설)
-- Co-authored with CoCo
-- 반환 행 = grain 중복 키(0행이어야 PASS). dbt_utils 미설치라 singular 테스트로 둔다.
select 'WIDE_DVLP_GOAL_ACMSLT' as model_name, COUNT(*) as dup_cnt
from {{ ref('WIDE_DVLP_GOAL_ACMSLT') }}
group by MONTH_KEY, DEPT_DIV_NM, NEW_EXST_DIV_NM, SPNSR_BSNS_GRP_NM
having COUNT(*) > 1

union all

select 'WIDE_MBRFEE_PRDT_ACTL', COUNT(*)
from {{ ref('WIDE_MBRFEE_PRDT_ACTL') }}
group by MONTH_KEY, DATA_TYPE_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM
having COUNT(*) > 1

union all

select 'WIDE_SPNSR_CLS_AGGR', COUNT(*)
from {{ ref('WIDE_SPNSR_CLS_AGGR') }}
group by MONTH_KEY, AGGR_TY_NM, CPR_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM
having COUNT(*) > 1
