-- =============================================================================
-- Purpose    : [2026-10-22 O258] 후원사업 그룹(CM003 코드명) ↔ seed MAP_SPONSORSHIP_GROUP4 커버리지 · 판정 코드 드리프트 경고
-- Target     : dbt singular test warn_map_coverage_sponsorship_group4 (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_CODE, ref MAP_SPONSORSHIP_GROUP4, ref CRM_SEND_REQUEST
-- Issue      : O258
-- =============================================================================
-- 왜: 4그룹 접기·서비스 판정을 라벨 하드코딩에서 seed·코드로 옮겼다(O258). 남는 위험 2종을 관측한다.
--   ㉠ CM003 에 새 그룹명이 생기면 SPONSORSHIP_GROUP4_NAME 이 NULL(조용한 누락)
--   ㉡ 서비스 판정 코드 MS054(gn_code SEND_TOP_MEMBER_SERVICE)의 대분류 명칭이 「회원서비스」가 아니게 됨(코드 뜻 변경)
-- 판정: WARN → ㉠ seeds/MAP_SPONSORSHIP_GROUP4.csv 에 행 추가 · ㉡ macros/gn_biz_codes.sql 키 재검토.
{{ config(severity = 'warn') }}

select 'UNMAPPED_GROUP:' || c.DTL_CD_ID as CHECK_NM, c.DTL_CD_NM as ACTUAL_NM, CAST(NULL AS VARCHAR) as EXPECTED_NM
from {{ ref('CRM_CODE') }} c
left join {{ ref('MAP_SPONSORSHIP_GROUP4') }} m on m.SRC_LABEL = c.DTL_CD_NM
where c.CD_ID = 'CM003'
  and m.SRC_LABEL is null
union all
select distinct 'SEND_TOP_LABEL_CHANGED:' || r.SEND_GBN_TOP, r.SEND_GBN_TOP_NM, '회원서비스'
from {{ ref('CRM_SEND_REQUEST') }} r
where r.SEND_GBN_TOP in ({{ gn_code('SEND_TOP_MEMBER_SERVICE') }})
  and COALESCE(r.SEND_GBN_TOP_NM, '') <> '회원서비스'
