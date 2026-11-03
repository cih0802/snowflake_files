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
from j