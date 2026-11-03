CREATE OR REPLACE TEMPORARY TABLE GN_DW.SILVER.T_O259_CLEAN AS
with recursive o as (
    select * from GN_DW.SILVER.CRM_ORG
),
b as (
    select x.DEPT_ID, x.DEPT_NM, x.UPPER_DEPT_ID,
           COALESCE(x.USE_YN = 'Y', FALSE)                                      as SELF_USE,
           (x.LAST_UPDT_DT is not null
            and TO_DATE(x.LAST_UPDT_DT) <> '9999-12-31')                        as SELF_UPDT,
           (p.DEPT_ID is null)                                                  as IS_ROOT
    from o x
    left join o p on p.DEPT_ID = x.UPPER_DEPT_ID
),
tree as (
    select DEPT_ID, (SELF_USE and SELF_UPDT) as IS_LIVE, 0 as LVL,
           CAST(NULL AS VARCHAR) as PATH, CAST(NULL AS VARCHAR) as LIVE_UPPER
    from b
    where IS_ROOT
    union all
    select c.DEPT_ID, t.IS_LIVE and c.SELF_USE and c.SELF_UPDT, t.LVL + 1,
           IFF(t.LVL = 0, c.DEPT_NM, t.PATH || ' > ' || c.DEPT_NM),
           t.DEPT_ID
    from b c
    join tree t on c.UPPER_DEPT_ID = t.DEPT_ID and c.DEPT_ID <> c.UPPER_DEPT_ID
    where t.LVL < 12
),
pa (DEPT_ID, CUR_ID, HOP) as (
    select DEPT_ID, DEPT_ID, 0 from o
    union all
    select pa.DEPT_ID, u.ACMSLT_UPPER_DEPT_ID, pa.HOP + 1
    from pa
    join o u on u.DEPT_ID = pa.CUR_ID
    where pa.HOP < 12 and u.ACMSLT_UPPER_DEPT_ID is not null and u.ACMSLT_UPPER_DEPT_ID <> u.DEPT_ID
),
div as (
    select pa.DEPT_ID,
           MIN(IFF(pa.CUR_ID like 'ZB%', pa.CUR_ID, NULL)) as ACMSLT_DIV_GROUP_ID,
           MIN(IFF(pa.CUR_ID like 'ZC%', pa.CUR_ID, NULL)) as ACMSLT_DIV_ID
    from pa
    group by pa.DEPT_ID
),
j as (
    select o.*, bb.SELF_USE, bb.SELF_UPDT,
           COALESCE(t.IS_LIVE, FALSE) as IS_ACTIVE_ORG,
           t.PATH as ORG_PATH, t.LVL as ORG_LEVEL, t.LIVE_UPPER,
           dv.ACMSLT_DIV_GROUP_ID, gz.DEPT_NM as ACMSLT_DIV_GROUP_NM,
           dv.ACMSLT_DIV_ID, cz.DEPT_NM as ACMSLT_DIV_NM
    from o
    join b bb on bb.DEPT_ID = o.DEPT_ID
    left join tree t on t.DEPT_ID = o.DEPT_ID
    left join div dv on dv.DEPT_ID = o.DEPT_ID
    left join o gz on gz.DEPT_ID = dv.ACMSLT_DIV_GROUP_ID
    left join o cz on cz.DEPT_ID = dv.ACMSLT_DIV_ID
)

select
    DEPT_ID,
    DEPT_NM,
    UPPER_DEPT_ID,                                                       -- 원천 그대로
    ACMSLT_UPPER_DEPT_ID,                                                -- 원천 그대로
    ACMSLT_DEPT_YN,                                                      -- 원천 그대로
    USE_YN,                                                              -- 원천 그대로(D1 · 판정에 단독 사용 금지)
    LAST_UPDT_DT,                                                        -- 원천 그대로
    IFF(IS_ACTIVE_ORG, 'ACTIVE', 'RETIRED')                              as ORG_STATUS,
    case
        when IS_ACTIVE_ORG   then NULL
        when not SELF_USE    then 'SELF_USE_YN'
        when not SELF_UPDT   then 'SELF_LAST_UPDT'
        when ORG_PATH is null and ORG_LEVEL is null then 'NOT_IN_TREE'
        else 'UPPER_RETIRED'
    end                                                                  as RETIRE_REASON,
    IS_ACTIVE_ORG,
    ORG_PATH,                                                            -- 전 노드 경로(폐기 포함 · 루트 제외 · 순환 NULL)
    ORG_LEVEL,                                                           -- 루트=0
    IFF(IS_ACTIVE_ORG, ORG_PATH, NULL)                                   as ACTIVE_PATH,
    IFF(IS_ACTIVE_ORG, ORG_LEVEL, NULL)                                  as ACTIVE_LEVEL,
    IFF(IS_ACTIVE_ORG, LIVE_UPPER, NULL)                                 as ACTIVE_UPPER_DEPT_ID,
    ACMSLT_DIV_GROUP_ID,
    ACMSLT_DIV_GROUP_NM,
    ACMSLT_DIV_ID,
    ACMSLT_DIV_NM,
    'CRM'                                                                as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()                                                  as DW_LOAD_TS,
    CURRENT_TIMESTAMP()                                                  as DW_UPDATE_TS,
    NULL                                                                 as DW_BATCH_ID
from j;
CREATE OR REPLACE TEMPORARY TABLE GN_DW.SILVER.T_O259_SUCC AS
with recursive o as (
    select c.DEPT_ID, c.DEPT_NM, c.UPPER_DEPT_ID, c.ACMSLT_UPPER_DEPT_ID,
           c.IS_ACTIVE_ORG as ACT, c.ORG_LEVEL, c.ORG_PATH, c.ACTIVE_UPPER_DEPT_ID
    from GN_DW.SILVER.T_O259_CLEAN c
),
act_nm as (
    select DEPT_NM, MIN(DEPT_ID) as DEPT_ID, COUNT(*) as K
    from o where ACT group by DEPT_NM
),
r_name as (
    select x.DEPT_ID, n.DEPT_ID as CUR_ID
    from o x join act_nm n on n.DEPT_NM = x.DEPT_NM and n.K = 1
    where not x.ACT
),
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
    select f.DEPT_ID, f.CUR_ID, f.N,
           f.N / SUM(f.N) over (partition by f.DEPT_ID)              as SHARE
    from flow f
),
r_flow as (
    select s.DEPT_ID, s.CUR_ID, s.N, s.SHARE, s.SHARE / b.B as LIFT
    from flow_s s join base b on b.CUR_ID = s.CUR_ID
    where s.N >= 10
    qualify ROW_NUMBER() over (
        partition by s.DEPT_ID
        order by s.SHARE / b.B * LEAST(s.N, 200) desc, s.CUR_ID
    ) = 1
),
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
    from GN_DW.GOLD.ORG_SUCCESSION_MANUAL
),
pick as (
    select x.DEPT_ID, x.DEPT_NM, x.UPPER_DEPT_ID, x.ACT,
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
    p.DEPT_ID                                      as OLD_DEPT_ID,
    p.DEPT_NM                                      as OLD_DEPARTMENT,
    p.ACT                                          as OLD_IS_ACTIVE_ORG,
    p.UPPER_DEPT_ID                                as OLD_UPPER_DEPT_ID,
    pu.CUR_DEPT_ID                                 as OLD_UPPER_CUR_DEPT_ID,
    c.DEPT_ID                                      as CUR_DEPT_ID,
    c.DEPT_NM                                      as CUR_DEPARTMENT,
    c.ORG_PATH                                     as CUR_ORG_PATH,
    c.ORG_LEVEL                                    as CUR_ORG_LEVEL,
    c.ACTIVE_UPPER_DEPT_ID                         as CUR_UPPER_DEPT_ID,
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
    'CRM'                                          as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()                            as DW_LOAD_TS,
    CURRENT_TIMESTAMP()                            as DW_UPDATE_TS,
    NULL                                           as DW_BATCH_ID
from pick p
left join o c on c.DEPT_ID = p.CUR_DEPT_ID and c.ACT
left join pick pu on pu.DEPT_ID = p.UPPER_DEPT_ID;
CREATE OR REPLACE TEMPORARY TABLE GN_DW.SILVER.T_O259_DORG AS
with o as (
    select * from GN_DW.SILVER.T_O259_CLEAN
)

select
    ABS(HASH(COALESCE(CAST(o.DEPT_ID AS VARCHAR), '∅')))                  as ORG_SK,
    ABS(HASH(o.DEPT_ID))                          as ORG_DK,
    CAST(NULL AS VARCHAR)                          as CORP,        -- ③ 부서 차원 산출 불가(CONF-4)
    CAST(NULL AS VARCHAR)                          as DIVISION,    -- ① 실적지부 재정의 · 산출규칙 확정 대기
    o.DEPT_NM                                     as DEPARTMENT,   -- 정본 정합
    CAST(NULL AS VARCHAR)                          as TEAM,        -- ② 보류(E-6 입고 시 재개)
    o.ACMSLT_UPPER_DEPT_ID                        as ACMSLT_UPPER_DEPT_ID,  -- 원천 그대로
    o.ACMSLT_DEPT_YN                              as ACMSLT_DEPT_YN,        -- 원천 그대로
    o.USE_YN                                      as USE_YN,                -- 원천 그대로(제외 금지)
    'CRM' AS DW_SOURCE_SYSTEM, NULL::TIMESTAMP_NTZ AS DW_LOAD_TS, NULL::TIMESTAMP_NTZ AS DW_UPDATE_TS, NULL AS DW_BATCH_ID,
    o.IS_ACTIVE_ORG                               as IS_ACTIVE_ORG,  -- O188-E 활성 조직 트리 소속(정본 = CRM_ORG_CLEAN)
    o.ORG_PATH                                    as ORG_PATH,       -- O188-E 조직표 「부서 경로」(루트 제외 · 순환 노드는 NULL)
    o.ORG_LEVEL                                   as ORG_LEVEL,      -- O188-E 루트=0
    o.ACMSLT_DIV_GROUP_ID                         as ACMSLT_DIV_GROUP_ID,  -- O191 실적트리 ZB 상위(본부/지부 구분)
    o.ACMSLT_DIV_GROUP_NM                         as ACMSLT_DIV_GROUP_NM,
    o.ACMSLT_DIV_ID                               as ACMSLT_DIV_ID,        -- O191 실적트리 ZC 상위(본부/지부 단위)
    o.ACMSLT_DIV_NM                               as ACMSLT_DIV_NM
from o

union all
select 0, 0, NULL, NULL, '(미매핑)', NULL, NULL, NULL, NULL,
    'CRM' AS DW_SOURCE_SYSTEM, NULL::TIMESTAMP_NTZ AS DW_LOAD_TS, NULL::TIMESTAMP_NTZ AS DW_UPDATE_TS, NULL AS DW_BATCH_ID,
    FALSE, NULL, NULL,
    NULL, NULL, NULL, NULL;
CREATE OR REPLACE TEMPORARY TABLE GN_DW.SILVER.T_O259_DSUCC AS
select
    ABS(HASH(COALESCE(CAST(s.OLD_DEPT_ID AS VARCHAR), '∅')))               as OLD_ORG_SK,
    s.OLD_DEPT_ID                                  as OLD_DEPT_ID,
    s.OLD_DEPARTMENT                               as OLD_DEPARTMENT,
    s.OLD_IS_ACTIVE_ORG                            as OLD_IS_ACTIVE_ORG,
    IFF(s.CUR_DEPT_ID is null, NULL, ABS(HASH(COALESCE(CAST(s.CUR_DEPT_ID AS VARCHAR), '∅'))))  as CUR_ORG_SK,
    s.CUR_DEPT_ID                                  as CUR_DEPT_ID,
    s.CUR_DEPARTMENT                               as CUR_DEPARTMENT,
    s.CUR_ORG_PATH                                 as CUR_ORG_PATH,
    s.CUR_ORG_LEVEL                                as CUR_ORG_LEVEL,
    s.MAP_METHOD                                   as MAP_METHOD,
    s.IS_REMAPPED                                  as IS_REMAPPED,
    s.IS_CONFIRMED                                 as IS_CONFIRMED,
    s.FLOW_CAND_DEPT_ID                            as FLOW_CAND_DEPT_ID,
    s.FLOW_EVIDENCE_CNT                            as FLOW_EVIDENCE_CNT,
    s.FLOW_SHARE                                   as FLOW_SHARE,
    s.FLOW_LIFT                                    as FLOW_LIFT,
    s.CONFIRMED_BY                                 as CONFIRMED_BY,
    s.CONFIRMED_DT                                 as CONFIRMED_DT,
    s.NOTE                                         as NOTE,
    'CRM' AS DW_SOURCE_SYSTEM, NULL::TIMESTAMP_NTZ AS DW_LOAD_TS, NULL::TIMESTAMP_NTZ AS DW_UPDATE_TS, NULL AS DW_BATCH_ID
from GN_DW.SILVER.T_O259_SUCC s;
SELECT 'DIM_ORG new-old' K, COUNT(*) N FROM (SELECT ORG_SK, ORG_DK, CORP, DIVISION, DEPARTMENT, TEAM, ACMSLT_UPPER_DEPT_ID, ACMSLT_DEPT_YN, USE_YN, IS_ACTIVE_ORG, ORG_PATH, ORG_LEVEL, ACMSLT_DIV_GROUP_ID, ACMSLT_DIV_GROUP_NM, ACMSLT_DIV_ID, ACMSLT_DIV_NM FROM GN_DW.SILVER.T_O259_DORG MINUS SELECT ORG_SK, ORG_DK, CORP, DIVISION, DEPARTMENT, TEAM, ACMSLT_UPPER_DEPT_ID, ACMSLT_DEPT_YN, USE_YN, IS_ACTIVE_ORG, ORG_PATH, ORG_LEVEL, ACMSLT_DIV_GROUP_ID, ACMSLT_DIV_GROUP_NM, ACMSLT_DIV_ID, ACMSLT_DIV_NM FROM GN_DW.GOLD.DIM_ORG)
UNION ALL SELECT 'DIM_ORG old-new', COUNT(*) FROM (SELECT ORG_SK, ORG_DK, CORP, DIVISION, DEPARTMENT, TEAM, ACMSLT_UPPER_DEPT_ID, ACMSLT_DEPT_YN, USE_YN, IS_ACTIVE_ORG, ORG_PATH, ORG_LEVEL, ACMSLT_DIV_GROUP_ID, ACMSLT_DIV_GROUP_NM, ACMSLT_DIV_ID, ACMSLT_DIV_NM FROM GN_DW.GOLD.DIM_ORG MINUS SELECT ORG_SK, ORG_DK, CORP, DIVISION, DEPARTMENT, TEAM, ACMSLT_UPPER_DEPT_ID, ACMSLT_DEPT_YN, USE_YN, IS_ACTIVE_ORG, ORG_PATH, ORG_LEVEL, ACMSLT_DIV_GROUP_ID, ACMSLT_DIV_GROUP_NM, ACMSLT_DIV_ID, ACMSLT_DIV_NM FROM GN_DW.SILVER.T_O259_DORG)
UNION ALL SELECT 'DIM_ORG rows new', COUNT(*) FROM GN_DW.SILVER.T_O259_DORG
UNION ALL SELECT 'DIM_ORG rows old', COUNT(*) FROM GN_DW.GOLD.DIM_ORG
UNION ALL SELECT 'SUCC new-old', COUNT(*) FROM (SELECT OLD_ORG_SK, OLD_DEPT_ID, OLD_DEPARTMENT, OLD_IS_ACTIVE_ORG, CUR_ORG_SK, CUR_DEPT_ID, CUR_DEPARTMENT, CUR_ORG_PATH, CUR_ORG_LEVEL, MAP_METHOD, IS_REMAPPED, IS_CONFIRMED, FLOW_CAND_DEPT_ID, FLOW_EVIDENCE_CNT, FLOW_SHARE, FLOW_LIFT, CONFIRMED_BY, CONFIRMED_DT, NOTE FROM GN_DW.SILVER.T_O259_DSUCC MINUS SELECT OLD_ORG_SK, OLD_DEPT_ID, OLD_DEPARTMENT, OLD_IS_ACTIVE_ORG, CUR_ORG_SK, CUR_DEPT_ID, CUR_DEPARTMENT, CUR_ORG_PATH, CUR_ORG_LEVEL, MAP_METHOD, IS_REMAPPED, IS_CONFIRMED, FLOW_CAND_DEPT_ID, FLOW_EVIDENCE_CNT, FLOW_SHARE, FLOW_LIFT, CONFIRMED_BY, CONFIRMED_DT, NOTE FROM GN_DW.GOLD.DIM_ORG_SUCCESSION)
UNION ALL SELECT 'SUCC old-new', COUNT(*) FROM (SELECT OLD_ORG_SK, OLD_DEPT_ID, OLD_DEPARTMENT, OLD_IS_ACTIVE_ORG, CUR_ORG_SK, CUR_DEPT_ID, CUR_DEPARTMENT, CUR_ORG_PATH, CUR_ORG_LEVEL, MAP_METHOD, IS_REMAPPED, IS_CONFIRMED, FLOW_CAND_DEPT_ID, FLOW_EVIDENCE_CNT, FLOW_SHARE, FLOW_LIFT, CONFIRMED_BY, CONFIRMED_DT, NOTE FROM GN_DW.GOLD.DIM_ORG_SUCCESSION MINUS SELECT OLD_ORG_SK, OLD_DEPT_ID, OLD_DEPARTMENT, OLD_IS_ACTIVE_ORG, CUR_ORG_SK, CUR_DEPT_ID, CUR_DEPARTMENT, CUR_ORG_PATH, CUR_ORG_LEVEL, MAP_METHOD, IS_REMAPPED, IS_CONFIRMED, FLOW_CAND_DEPT_ID, FLOW_EVIDENCE_CNT, FLOW_SHARE, FLOW_LIFT, CONFIRMED_BY, CONFIRMED_DT, NOTE FROM GN_DW.SILVER.T_O259_DSUCC)
UNION ALL SELECT 'SUCC rows new', COUNT(*) FROM GN_DW.SILVER.T_O259_DSUCC
UNION ALL SELECT 'CLEAN rows', COUNT(*) FROM GN_DW.SILVER.T_O259_CLEAN
UNION ALL SELECT 'CLEAN ACTIVE', COUNT_IF(ORG_STATUS='ACTIVE') FROM GN_DW.SILVER.T_O259_CLEAN
UNION ALL SELECT 'RR '||COALESCE(RETIRE_REASON,'(ACTIVE)'), COUNT(*) FROM GN_DW.SILVER.T_O259_CLEAN GROUP BY RETIRE_REASON
UNION ALL SELECT 'PICKER retired', COUNT(*) FROM GN_DW.SILVER.T_O259_CLEAN WHERE ORG_STATUS='ACTIVE' AND NOT IS_ACTIVE_ORG
UNION ALL SELECT 'UPPER_CUR filled', COUNT(OLD_UPPER_CUR_DEPT_ID) FROM GN_DW.SILVER.T_O259_SUCC
ORDER BY 1