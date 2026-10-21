-- assert_org_succession_invariants: DIM_ORG_SUCCESSION 귀속 정합 (O252 · DEC-63 신설)
-- Co-authored with CoCo
-- 반환 행 = 위반(0행이어야 PASS).
--   ㉠ CUR_ORG_SK 가 NULL 인데 MAP_METHOD 가 UNMAPPED·MANUAL_UNMAPPED 가 아님
--      = 현업 확정(seed)이 **비활성 부서**를 가리켰거나 자동 규칙이 활성 아닌 노드를 골랐다
--   ㉡ 활성 부서인데 SELF 가 아님(또는 SELF 인데 자기 자신이 아님)
--   ㉢ seed 의 OLD_DEPT_ID 가 CRM_ORG 에 없음(오타 · 확정분이 조용히 무시된다)
select 'CUR_NULL_NOT_UNMAPPED:' || MAP_METHOD as CHECK_NM, COUNT(*) as CNT
from {{ ref('DIM_ORG_SUCCESSION') }}
where CUR_ORG_SK is null and MAP_METHOD not in ('UNMAPPED', 'MANUAL_UNMAPPED')
group by MAP_METHOD

union all

select 'ACTIVE_NOT_SELF', COUNT(*)
from {{ ref('DIM_ORG_SUCCESSION') }}
where (OLD_IS_ACTIVE_ORG and (MAP_METHOD <> 'SELF' or CUR_ORG_SK <> OLD_ORG_SK))
   or (MAP_METHOD = 'SELF' and not OLD_IS_ACTIVE_ORG)
having COUNT(*) > 0

union all

select 'SEED_UNKNOWN_DEPT:' || m.OLD_DEPT_ID, 1
from {{ ref('ORG_SUCCESSION_MANUAL') }} m
left join {{ ref('CRM_ORG') }} c on c.DEPT_ID = m.OLD_DEPT_ID
where c.DEPT_ID is null
