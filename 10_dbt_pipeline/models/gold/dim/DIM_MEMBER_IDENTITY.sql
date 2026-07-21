-- DIM_MEMBER_IDENTITY: 회원 신원 브리지 (CRM_MEMBER × GA4_IDENTITY 매칭, IDENTITY_MEMBER_XREF 경유)
-- Co-authored with CoCo
-- ⚠️ 활성화(2026-07-15): SILVER GA4_IDENTITY 적재 확인 → enabled 해제. GA_MEMBER_ID=exact member_id 매칭분만.
--    grain 보호: XREF는 user_pseudo_id 단위(1회원 최대 3 pseudo) → MEMBER_DK로 집계 후 조인(IDENTITY_SK 유일성 보장).
--    데이터 범위: 현재 GA4 1일 샤드 기반(채움률 ~4.2%)·Q1 현업검증 대기. 행수는 GA4 입고 범위에 비례(전기간 입고 시 truncate+append로 자동 갱신).
{{ config(
    materialized='incremental',
    unique_key='IDENTITY_SK',
    tags=['gold_pending']
) }}

with m as (
    select * from {{ ref('CRM_MEMBER') }}
),
-- XREF는 user_pseudo_id 단위 → MEMBER_DK로 집계(1회원 1행)해 fan-out(IDENTITY_SK 중복) 방지
xref as (
    select MEMBER_DK as X_MEMBER_DK, MAX(GA_MEMBER_ID) as GA_MEMBER_ID
    from {{ ref('IDENTITY_MEMBER_XREF') }}
    where MEMBER_DK is not null
    group by MEMBER_DK
)

select
    {{ gold_sk(['MEMBER_DK']) }}                  as IDENTITY_SK,
    MEMBER_DK                                     as MEMBER_DK,
    MEMBER_DK                                     as MEMBER_NO,
    CAST(NULL AS VARCHAR)                          as MEMNUM,
    x.GA_MEMBER_ID                                as GA_MEMBER_ID,   -- exact member_id 매칭분(미매칭=NULL)
    HMPG_ID                                       as HOMEPAGE_ID,
    CAST(NULL AS VARCHAR)                          as CHILD_CODE,     -- ⚠️ 결연(SPONSOR_RELATION) 대기
    {{ gold_meta('CRM') }}
from m
left join xref x on x.X_MEMBER_DK = m.MEMBER_DK

union all
-- unknown 멤버(SK=0): 팩트 IDENTITY_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', '(미매핑)', NULL, NULL, NULL, NULL,
    {{ gold_meta('CRM') }}
