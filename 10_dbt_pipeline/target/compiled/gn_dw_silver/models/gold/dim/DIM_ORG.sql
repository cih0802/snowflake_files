-- DIM_ORG: 조직 차원 SCD1 (DEPT_ID grain, 안정 SK) — CRM_ORG, Bronze 입고 후 실행
-- Co-authored with CoCo
-- ⚠️ SK=hash(DEPT_ID) 안정키(재실행 멱등). DEC-2 SCD1 확정 — 조직 변경이력 소스 없음·as-was org 지표 요구 없음(4개 정의서 검토) → SCD2 예약컬럼(EFFECTIVE_*/IS_CURRENT) 삭제(2026-07-07).
--    향후 조직 이력추적 필요 시 별도 변경이력 소스 확보 후 재설계.
-- ⚠️ 계층전개(CORP/DIVISION/DEPARTMENT/TEAM)=UPPER_DEPT_ID 재귀 필요 → 입고 후 확장. 현재 DEPARTMENT=DEPT_NM만.


with o as (
    select * from GN_DW.SILVER.CRM_ORG
)

select
    ABS(HASH(COALESCE(CAST(DEPT_ID AS VARCHAR), '∅')))                    as ORG_SK,
    ABS(HASH(DEPT_ID))                            as ORG_DK,
    CAST(NULL AS VARCHAR)                          as CORP,        -- ⚠️ 계층전개 대기
    CAST(NULL AS VARCHAR)                          as DIVISION,    -- ⚠️ 계층전개 대기
    DEPT_NM                                       as DEPARTMENT,
    CAST(NULL AS VARCHAR)                          as TEAM,        -- ⚠️ 계층전개 대기
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b50d9005-0be3-463b-8b58-76f0c3a68e8a'                    AS DW_BATCH_ID
from o

union all
-- unknown 멤버(SK=0): 팩트 ORG_SK=0(미매핑) 조인 유실 방지
select 0, 0, NULL, NULL, '(미매핑)', NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b50d9005-0be3-463b-8b58-76f0c3a68e8a'                    AS DW_BATCH_ID