CREATE OR REPLACE TEMPORARY TABLE GN_DW.PUBLIC.TMP_O252_MODEL AS
with recursive o as (
    select c.DEPT_ID, c.DEPT_NM, c.UPPER_DEPT_ID, c.ACMSLT_UPPER_DEPT_ID,
           d.ORG_SK, COALESCE(d.IS_ACTIVE_ORG, FALSE) as ACT, d.ORG_LEVEL, d.ORG_PATH
    from GN_DW.SILVER.CRM_ORG c
    join GN_DW.GOLD.DIM_ORG d on d.ORG_SK = ABS(HASH(COALESCE(CAST(c.DEPT_ID AS VARCHAR),'∅')))
),
act_nm as (
    select DEPT_NM, MIN(DEPT_ID) as DEPT_ID, COUNT(*) as K
    from o where ACT group by DEPT_NM
),
-- 2 동명 유일
r_name as (
    select x.DEPT_ID, n.DEPT_ID as CUR_ID
    from o x join act_nm n on n.DEPT_NM = x.DEPT_NM and n.K = 1
    where not x.ACT
),
-- 3 회원 흐름(lift)
base as (
    select d.ACMSLT_DEPT_CD as CUR_ID,
           COUNT(*) / SUM(COUNT(*)) over () as B
    from GN_DW.SILVER.CRM_MEMBER_DEV d
    join o a on a.DEPT_ID = d.ACMSLT_DEPT_CD and a.ACT
    where d.OCCRRNC_DE >= '20220101' and d.OCCRRNC_DE < '9999'
    group by d.ACMSLT_DEPT_CD
),
mem as (
    select distinct sp.MBER_NO, sp.ACMSLT_DEPT_CD as DEPT_ID
    from GN_DW.SILVER.CRM_MEMBER_SPONSOR_SPAN sp
    join o x on x.DEPT_ID = sp.ACMSLT_DEPT_CD and not x.ACT
),
flow as (
    select m.DEPT_ID, d.ACMSLT_DEPT_CD as CUR_ID, COUNT(*) as N
    from mem m
    join GN_DW.SILVER.CRM_MEMBER_DEV d on d.MBER_NO = m.MBER_NO
    join o a on a.DEPT_ID = d.ACMSLT_DEPT_CD and a.ACT
    where d.OCCRRNC_DE >= '20220101' and d.OCCRRNC_DE < '9999'
    group by m.DEPT_ID, d.ACMSLT_DEPT_CD
),
flow_s as (
    -- 점유율 분모 = 그 부서 회원의 활성 부서 개발 전체(10건 미만 후보도 분모에는 포함)
    select f.DEPT_ID, f.CUR_ID, f.N,
           f.N / SUM(f.N) over (partition by f.DEPT_ID)              as SHARE
    from flow f
),
r_flow as (
    -- 🔴 Snowflake 는 윈도 함수 안에 윈도 함수를 중첩할 수 없다 ⇒ 점유율을 flow_s 에서 먼저 계산한다
    select s.DEPT_ID, s.CUR_ID, s.N, s.SHARE, s.SHARE / b.B as LIFT
    from flow_s s join base b on b.CUR_ID = s.CUR_ID
    where s.N >= 10
    qualify ROW_NUMBER() over (
        partition by s.DEPT_ID
        order by s.SHARE / b.B * LEAST(s.N, 200) desc, s.CUR_ID
    ) = 1
),
-- 4 실적트리 상위
wa (START_ID, CUR_ID, HOP) as (
    select DEPT_ID, ACMSLT_UPPER_DEPT_ID, 1 from o where not ACT and ACMSLT_UPPER_DEPT_ID is not null
    union all
    select wa.START_ID, u.ACMSLT_UPPER_DEPT_ID, wa.HOP + 1
    from wa join o u on u.DEPT_ID = wa.CUR_ID
    where wa.HOP < 10 and u.ACMSLT_UPPER_DEPT_ID is not null and u.ACMSLT_UPPER_DEPT_ID <> u.DEPT_ID
),
r_acm as (
    select wa.START_ID as DEPT_ID,
           MIN_BY(IFF(u.ACT, u.DEPT_ID, n.DEPT_ID), wa.HOP) as CUR_ID
    from wa
    join o u on u.DEPT_ID = wa.CUR_ID
    left join act_nm n on n.DEPT_NM = u.DEPT_NM and n.K = 1
    where u.ACT or n.DEPT_ID is not null
    group by wa.START_ID
),
-- 5 조직트리 상위(L≥1)
wo (START_ID, CUR_ID, HOP) as (
    select DEPT_ID, UPPER_DEPT_ID, 1 from o where not ACT and UPPER_DEPT_ID is not null
    union all
    select wo.START_ID, u.UPPER_DEPT_ID, wo.HOP + 1
    from wo join o u on u.DEPT_ID = wo.CUR_ID
    where wo.HOP < 10 and not u.ACT and u.UPPER_DEPT_ID is not null and u.UPPER_DEPT_ID <> u.DEPT_ID
),
r_org as (
    select wo.START_ID as DEPT_ID, MIN_BY(u.DEPT_ID, wo.HOP) as CUR_ID
    from wo join o u on u.DEPT_ID = wo.CUR_ID and u.ACT and u.ORG_LEVEL >= 1
    group by wo.START_ID
),
man as (
    select OLD_DEPT_ID, NULLIF(TRIM(CUR_DEPT_ID), '') as CUR_DEPT_ID, CONFIRMED_BY, CONFIRMED_DT, NOTE
    from (select NULL::varchar OLD_DEPT_ID, NULL::varchar CUR_DEPT_ID, NULL::varchar CONFIRMED_BY, NULL::varchar CONFIRMED_DT, NULL::varchar NOTE where 1=0)
),
pick as (
    select x.DEPT_ID, x.DEPT_NM, x.ORG_SK, x.ACT,
        case
            when x.ACT                                                      then 'SELF'
            when man.OLD_DEPT_ID is not null and man.CUR_DEPT_ID is null    then 'MANUAL_UNMAPPED'
            when man.OLD_DEPT_ID is not null                                then 'MANUAL'
            when rn.CUR_ID is not null                                      then 'AUTO_NAME'
            when rf.LIFT >= 3 and rf.N >= 30        then 'AUTO_MEMBER_FLOW'
            when ra.CUR_ID is not null                                      then 'AUTO_ACMSLT_PARENT'
            when ro.CUR_ID is not null                                      then 'AUTO_ORG_PARENT'
            else 'UNMAPPED'
        end as MAP_METHOD,
        case
            when x.ACT                                                      then x.DEPT_ID
            when man.OLD_DEPT_ID is not null                                then man.CUR_DEPT_ID
            when rn.CUR_ID is not null                                      then rn.CUR_ID
            when rf.LIFT >= 3 and rf.N >= 30        then rf.CUR_ID
            when ra.CUR_ID is not null                                      then ra.CUR_ID
            else ro.CUR_ID
        end as CUR_DEPT_ID,
        rf.CUR_ID as FLOW_CAND_DEPT_ID, rf.N as FLOW_EVIDENCE_CNT, rf.SHARE as FLOW_SHARE, rf.LIFT as FLOW_LIFT,
        man.CONFIRMED_BY, man.CONFIRMED_DT, man.NOTE
    from o x
    left join man       on man.OLD_DEPT_ID = x.DEPT_ID
    left join r_name rn on rn.DEPT_ID = x.DEPT_ID
    left join r_flow rf on rf.DEPT_ID = x.DEPT_ID
    left join r_acm  ra on ra.DEPT_ID = x.DEPT_ID
    left join r_org  ro on ro.DEPT_ID = x.DEPT_ID
)

select
    p.ORG_SK                                       as OLD_ORG_SK,
    p.DEPT_ID                                      as OLD_DEPT_ID,
    p.DEPT_NM                                      as OLD_DEPARTMENT,
    p.ACT                                          as OLD_IS_ACTIVE_ORG,
    c.ORG_SK                                       as CUR_ORG_SK,
    c.DEPT_ID                                      as CUR_DEPT_ID,
    c.DEPT_NM                                      as CUR_DEPARTMENT,
    c.ORG_PATH                                     as CUR_ORG_PATH,
    c.ORG_LEVEL                                    as CUR_ORG_LEVEL,
    p.MAP_METHOD                                   as MAP_METHOD,
    (p.MAP_METHOD not in ('SELF', 'UNMAPPED', 'MANUAL_UNMAPPED'))  as IS_REMAPPED,
    (p.MAP_METHOD in ('SELF', 'MANUAL', 'MANUAL_UNMAPPED'))        as IS_CONFIRMED,
    p.FLOW_CAND_DEPT_ID                            as FLOW_CAND_DEPT_ID,
    p.FLOW_EVIDENCE_CNT                            as FLOW_EVIDENCE_CNT,
    ROUND(p.FLOW_SHARE, 4)                         as FLOW_SHARE,
    ROUND(p.FLOW_LIFT, 2)                          as FLOW_LIFT,
    p.CONFIRMED_BY                                 as CONFIRMED_BY,
    p.CONFIRMED_DT                                 as CONFIRMED_DT,
    p.NOTE                                         as NOTE,
    'CRM' AS DW_SOURCE_SYSTEM, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_LOAD_TS, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_UPDATE_TS, 'o252' AS DW_BATCH_ID
from pick p
left join o c on c.DEPT_ID = p.CUR_DEPT_ID and c.ACT
