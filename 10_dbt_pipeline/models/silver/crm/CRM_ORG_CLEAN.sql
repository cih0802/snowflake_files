-- =============================================================================
-- Purpose    : 조직 마스터 활성 트리 정제 — 노드별 상태·폐기 사유·활성 경로 (O259 · DIM_ORG 규칙 Silver 이관)
-- Target     : SILVER.CRM_ORG_CLEAN (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계) · 선행 = 08 DDL(또는 39_DEPLOY_SILVER_ORG_CLEAN.sql)
-- Depends on : ref CRM_ORG
-- Issue      : O259, O188-E, O191, O16
-- =============================================================================
-- CRM_ORG_CLEAN: grain = DEPT_ID 1행(CRM_ORG 1,314행 그대로 · 행 삭제 금지 O16).
--   Silver 를 읽는 소비자(Streamlit 등)가 정제 전 트리를 보지 않도록 활성 판정을 여기서 낸다.
--   GOLD.DIM_ORG 는 이 모델을 ref 한다(규칙 정본 = 이 파일 · 이관 원본 = O258 시점 DIM_ORG.sql 42~110행).
--
-- 활성 규칙(O188-E · 하드코딩 0) = 자기와 모든 상위(UPPER_DEPT_ID)가 USE_YN='Y' 이고
--   LAST_UPDT_DT 가 NULL·9999-12-31 이 아님. 조직표 222/222 일치 + B000006 해외파견(사용자 결정 포함).
-- D1(O259) = 폐기 정의는 이 활성 트리 기준으로 단일화한다. USE_YN 은 원천 속성으로만 보존한다.
--   WARN: USE_YN='Y' 인데 RETIRED 인 노드가 있다(상위 폐기 전파) — 사유 = RETIRE_REASON 'UPPER_RETIRED'.
--
-- RETIRE_REASON(ACTIVE 면 NULL · 앞선 사유가 우선):
--   SELF_USE_YN      자기 USE_YN <> 'Y'(또는 NULL)
--   SELF_LAST_UPDT   자기 LAST_UPDT_DT 가 NULL 또는 9999-12-31(비활성 버전)
--   NOT_IN_TREE      루트에서 닿지 않음(순환 등 · ORG_PATH NULL)
--   UPPER_RETIRED    자기는 살아 있으나 상위 중 하나가 폐기
with recursive o as (
    select * from {{ ref('CRM_ORG') }}
),
b as (
    select x.DEPT_ID, x.DEPT_NM, x.UPPER_DEPT_ID,
           COALESCE(x.USE_YN = 'Y', FALSE)                                      as SELF_USE,
           (x.LAST_UPDT_DT is not null
            and TO_DATE(x.LAST_UPDT_DT) <> '9999-12-31')                        as SELF_UPDT,
           -- WARN: 재귀 CTE 안의 NOT IN 서브쿼리는 Snowflake 가 거부한다(O188-F) ⇒ anti-join 플래그
           (p.DEPT_ID is null)                                                  as IS_ROOT
    from o x
    left join o p on p.DEPT_ID = x.UPPER_DEPT_ID
),
tree as (
    -- 경로는 루트를 뺀 형태(조직표 규격)
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
-- O191 실적트리(ACMSLT_UPPER_DEPT_ID) 상위 중 부서코드 접두 ZB(본부/지부 구분)·ZC(본부/지부 단위)
--   WARN: 접두 판정은 코드 체계이고 명칭 판정이 아니다(O16) · 자기 자신이 ZB/ZC 면 자기를 쓴다.
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
