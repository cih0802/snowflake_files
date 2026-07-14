-- DIM_MEMBER_IDENTITY: 회원 신원 브리지 스캐폴드 (CRM_MEMBER 기반, GA 결합 대기)
-- Co-authored with CoCo
-- ⚠️ enabled=false: GA4_IDENTITY 비활성(Q1 행매칭 실증 대기) → GA_MEMBER_ID 결합 전까지 미실행.
--    활성화 시: GA4_IDENTITY 를 MEMBER_DK 로 LEFT JOIN 해 GA_MEMBER_ID 채움.
{{ config(
    materialized='incremental',
    unique_key='IDENTITY_SK',
    enabled=false,
    tags=['gold_pending']
) }}

with m as (
    select * from {{ ref('CRM_MEMBER') }}
)

select
    {{ gold_sk(['MEMBER_DK']) }}                  as IDENTITY_SK,
    MEMBER_DK                                     as MEMBER_DK,
    MEMBER_DK                                     as MEMBER_NO,
    CAST(NULL AS VARCHAR)                          as MEMNUM,
    CAST(NULL AS VARCHAR)                          as GA_MEMBER_ID,   -- ⚠️ GA4_IDENTITY 활성 후 결합
    HMPG_ID                                       as HOMEPAGE_ID,
    CAST(NULL AS VARCHAR)                          as CHILD_CODE,     -- ⚠️ 결연(SPONSOR_RELATION) 대기
    {{ gold_meta('CRM') }}
from m

union all
-- unknown 멤버(SK=0): 팩트 IDENTITY_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', '(미매핑)', NULL, NULL, NULL, NULL,
    {{ gold_meta('CRM') }}
