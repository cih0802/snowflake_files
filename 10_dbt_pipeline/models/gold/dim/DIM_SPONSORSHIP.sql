-- DIM_SPONSORSHIP: 후원사업 차원 스캐폴드 (CRM_SPONSORSHIP, Bronze 입고 후 실행)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='SPONSORSHIP_SK',
    tags=['gold_pending']
) }}

with s as (
    select * from {{ ref('CRM_SPONSORSHIP') }}
)

select
    {{ gold_sk(['SPNSR_BSNS_ID']) }}              as SPONSORSHIP_SK,
    SPNSR_BSNS_ID                                 as SPONSORSHIP_BK,
    SPNSR_BSNS_NM                                 as SPONSORSHIP_NAME,
    SPNSR_BSNS_ABRV_CD                            as SPONSORSHIP_ABBR,
    {{ gold_meta('CRM') }}
from s

union all
-- unknown 멤버(SK=0): 팩트 SPONSORSHIP_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', '(미매핑)', NULL,
    {{ gold_meta('CRM') }}
