with o as (
    select * from T_CLEAN
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
    NULL, NULL, NULL, NULL