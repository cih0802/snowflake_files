-- DIM_REASON: 사유 차원 스캐폴드 (CRM_CODE, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ 사유 코드그룹 필터(CD_ID) 확정 대기 — 현재 전체 코드를 REASON_TYPE=CD_ID 로 스캐폴드.
--    후원중단 사유(MEMBER_DISCONTINUE.DSCNTC_RSN_CD) 등 실제 사용 그룹으로 좁힐 것.
{{ config(
    materialized='incremental',
    unique_key='REASON_SK',
    tags=['gold_pending']
) }}

with c as (
    select * from {{ ref('CRM_CODE') }}
)

select
    {{ gold_sk(['CD_ID','DTL_CD_ID']) }}          as REASON_SK,
    DTL_CD_ID                                     as REASON_CODE,
    DTL_CD_NM                                     as REASON_NAME,
    CD_ID                                         as REASON_TYPE,   -- 코드그룹(사유유형)
    {{ gold_meta('CRM') }}
from c

union all
-- unknown 멤버(SK=0): 팩트 REASON_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', '(미매핑)', NULL,
    {{ gold_meta('CRM') }}
