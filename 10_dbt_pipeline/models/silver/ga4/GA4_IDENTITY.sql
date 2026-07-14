-- GA4_IDENTITY: GA 신원 스파인 (user_id 접두사 분기 S%→ONCE / else→FDRM)
-- Co-authored with CoCo
-- ⚠️ 설계결정서 §5 + 주의사항 §6: Q1 행매칭(CRM MEMBER_DK↔GA user_id) 실증 완료 전까지 비활성
--    표(spine)는 안전하나 GA-7 브리지(CRM LEFT JOIN)는 후속. 활성화: enabled=true 로 변경
{{ config(
    materialized='table',
    enabled=false
) }}

with src as (
    {{ ga4_union_shards('20000101', '99991231') }}
)

select
    user_pseudo_id                                             as USER_PSEUDO_ID,
    user_id                                                    as GA_MEMBER_ID,   -- ⚠️VARCHAR 유지
    CASE WHEN user_id ILIKE 'S%' THEN 'ONCE' ELSE 'FDRM' END   as MEMBER_TYPE,
    IFF(user_id ILIKE 'S%', NULL, user_id)                     as MBER_NO,        -- → TM_MM_FDRM_MBER_INFO.MBER_NO
    IFF(user_id ILIKE 'S%', user_id, NULL)                     as ONCE_MBER_NO,   -- → TM_MM_ONCE_MBER_INFO.ONCE_MBER_NO
    'GA4'                              as DW_SOURCE_SYSTEM,
    'BRONZE_GA4.EVENTS_*'              as DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from src
where user_id is not null
group by user_pseudo_id, user_id
