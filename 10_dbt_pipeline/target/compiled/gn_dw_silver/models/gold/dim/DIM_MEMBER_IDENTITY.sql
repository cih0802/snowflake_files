-- DIM_MEMBER_IDENTITY: 회원 신원 브리지 (CRM_MEMBER × GA4_IDENTITY 매칭, IDENTITY_MEMBER_XREF 경유)
-- Co-authored with CoCo
-- ⚠️ 활성화(2026-07-15): SILVER GA4_IDENTITY 적재 확인 → enabled 해제. GA_MEMBER_ID=exact member_id 매칭분만.
--    grain 보호: XREF는 user_pseudo_id 단위(1회원 최대 3 pseudo) → MEMBER_DK로 집계 후 조인(IDENTITY_SK 유일성 보장).
--    데이터 범위: 현재 GA4 1일 샤드 기반(채움률 ~4.2%)·Q1 현업검증 대기. 행수는 GA4 입고 범위에 비례(전기간 입고 시 truncate+append로 자동 갱신).


with m as (
    select * from GN_DW.SILVER.CRM_MEMBER
),
-- XREF는 user_pseudo_id 단위 → MEMBER_DK로 집계(1회원 1행)해 fan-out(IDENTITY_SK 중복) 방지
xref as (
    select MEMBER_DK as X_MEMBER_DK, MAX(GA_MEMBER_ID) as GA_MEMBER_ID
    from GN_DW.SILVER.IDENTITY_MEMBER_XREF
    where MEMBER_DK is not null
    group by MEMBER_DK
)

select
    ABS(HASH(COALESCE(CAST(MEMBER_DK AS VARCHAR), '∅')))                  as IDENTITY_SK,
    MEMBER_DK                                     as MEMBER_DK,
    MEMBER_DK                                     as MEMBER_NO,
    CAST(NULL AS VARCHAR)                          as MEMNUM,         -- 🔴 전건 NULL. 정본 #111. 원천 실재 = SILVER.GA4_EVENT.PAGE_LOCATION 의 memnum= (17,795행·1,589종) — 미배선(phase-2). ⚠️ 단 GOLD.FACT_GA_BEHAVIOR.PAGE_LOCATION 은 MAX() 대표값이라 680종만 남으므로 배선 원천은 SILVER 여야 한다
    x.GA_MEMBER_ID                                as GA_MEMBER_ID,   -- exact member_id 매칭분(미매칭=NULL)
    HMPG_ID                                       as HOMEPAGE_ID,
    CAST(NULL AS VARCHAR)                          as CHILD_CODE,     -- 🔴 전건 NULL. 종전 주석 '결연(SPONSOR_RELATION) 대기' 는 회수한다 — 정본 #122 는 결연아동코드를 "페이지 경로+쿼리 문자열에서 childnum= 뒤 13자리" 로 규정하며 정본 DDL(06_DDL.sql:164)도 'URL 파싱' 이라 적었다. 원천 실재 = SILVER.GA4_EVENT.PAGE_LOCATION 의 childnum= (6,827행·594종) — 미배선(phase-2)
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b21b7934-7c9a-4bb8-bfb2-a3d18e0205f5'                    AS DW_BATCH_ID
from m
left join xref x on x.X_MEMBER_DK = m.MEMBER_DK

union all
-- unknown 멤버(SK=0): 팩트 IDENTITY_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', '(미매핑)', NULL, NULL, NULL, NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b21b7934-7c9a-4bb8-bfb2-a3d18e0205f5'                    AS DW_BATCH_ID