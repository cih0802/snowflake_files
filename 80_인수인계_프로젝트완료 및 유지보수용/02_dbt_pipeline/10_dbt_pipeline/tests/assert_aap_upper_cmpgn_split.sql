-- =============================================================================
-- Purpose    : AGENCY_AD_PERFORMANCE 상위캠페인 코드·이름 분리 불변식 (O262 신설 · O261-B ㉮ [3])
-- Target     : dbt singular test assert_aap_upper_cmpgn_split (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref AGENCY_AD_PERFORMANCE
-- Issue      : O262, O261-B
-- =============================================================================
-- assert_aap_upper_cmpgn_split: 상위캠페인 2열 분리 불변식 (O262 신설)
-- severity = error — 착수 실측(이전 계정 2026-10-25) 오분류 0 · 이름형 34종 중 코드형 0(`tmp/o261b/evidence.md` E0).
-- 반환 행 = 위반(0행이어야 PASS). dbt_utils 미설치라 singular 테스트로 둔다.
--   ㉠ UPPER_CAMPAIGN_CD 가 있으면 형태 ^U[0-9]+$
--   ㉡ UPPER_CAMPAIGN_NM 에 코드형 값 없음(분리 누락)
--   ㉢ 두 열 동시 채움 0
--   ㉣ VIDEO 외 소스는 두 열 다 NULL
select 'CD_BAD_SHAPE' as CHECK_NM, COUNT(*) as V
from {{ ref('AGENCY_AD_PERFORMANCE') }}
where UPPER_CAMPAIGN_CD is not null and not REGEXP_LIKE(UPPER_CAMPAIGN_CD, '^U[0-9]+$')
having COUNT(*) > 0

union all

select 'NM_CODE_SHAPED', COUNT(*)
from {{ ref('AGENCY_AD_PERFORMANCE') }}
where REGEXP_LIKE(UPPER_CAMPAIGN_NM, '^U[0-9]+$')
having COUNT(*) > 0

union all

select 'BOTH_FILLED', COUNT(*)
from {{ ref('AGENCY_AD_PERFORMANCE') }}
where UPPER_CAMPAIGN_CD is not null and UPPER_CAMPAIGN_NM is not null
having COUNT(*) > 0

union all

select 'NON_VIDEO_FILLED:' || AD_SOURCE_TYPE, COUNT(*)
from {{ ref('AGENCY_AD_PERFORMANCE') }}
where AD_SOURCE_TYPE <> 'VIDEO' and (UPPER_CAMPAIGN_CD is not null or UPPER_CAMPAIGN_NM is not null)
group by AD_SOURCE_TYPE
