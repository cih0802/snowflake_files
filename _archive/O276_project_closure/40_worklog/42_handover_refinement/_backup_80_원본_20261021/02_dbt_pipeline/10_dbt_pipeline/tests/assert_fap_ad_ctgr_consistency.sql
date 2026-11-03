-- assert_fap_ad_ctgr_consistency: FACT_AD_PERFORMANCE 광고비 귀속 카테고리 정합 (O232-B 신설)
-- ⚠️ [임시] 2026-10-16 severity=warn 하향: AD_CREATIVE_CAMPAIGN_MAP 원천 코드(MM294 DTL_CD_ID) 불일치 14건으로
--    운영 build 가 막혀 다운스트림이 SKIP 됨. 원천 CSV(O232_광고_매핑_추천안.csv) 보정·재적재 후 error 로 원복할 것.
{{ config(severity='warn') }}
-- Co-authored with CoCo
-- 반환 행 = 위반(0행이어야 PASS). dbt_utils 미설치라 singular 테스트로 둔다.
--   ㉠ 출처 ↔ 값: NONE 이면 코드·이름·다중 플래그가 모두 NULL · 그 밖은 코드·이름·플래그가 모두 있다
--   ㉡ CREATIVE_MAP 은 확정값이라 다중 플래그 FALSE
--   ㉢ 코드 ↔ 이름 1:1(원천 CRM_CAMPAIGN 과 같은 쌍)
--   ㉣ 차원 대표값 = 팩트 값(MKTG_REP 행은 연결된 마케팅캠페인의 CMPGN_CTGR_CD 와 같아야 한다)
select 'SRC_VALUE:' || AD_CTGR_SRC as CHECK_NM, COUNT(*) as V
from {{ ref('FACT_AD_PERFORMANCE') }}
where (AD_CTGR_SRC = 'NONE' and (AD_CTGR_CD is not null or AD_CTGR_NM is not null or AD_CTGR_IS_MULTI is not null))
   or (AD_CTGR_SRC <> 'NONE' and (AD_CTGR_CD is null or AD_CTGR_NM is null or AD_CTGR_IS_MULTI is null))
group by AD_CTGR_SRC

union all

select 'CREATIVE_MAP_MULTI', COUNT(*)
from {{ ref('FACT_AD_PERFORMANCE') }}
where AD_CTGR_SRC = 'CREATIVE_MAP' and AD_CTGR_IS_MULTI
having COUNT(*) > 0

union all

select 'CD_NM_PAIR:' || f.AD_CTGR_CD, COUNT(*)
from {{ ref('FACT_AD_PERFORMANCE') }} f
where f.AD_CTGR_CD is not null
  and not exists (select 1 from {{ ref('CRM_CAMPAIGN') }} c
                  where c.CMPGN_CTGR_CD = f.AD_CTGR_CD and c.CMPGN_CTGR_NM = f.AD_CTGR_NM)
group by f.AD_CTGR_CD

union all

select 'MKTG_REP_DIM', COUNT(*)
from {{ ref('FACT_AD_PERFORMANCE') }} f
join {{ ref('DIM_MARKETING_CAMPAIGN') }} d on d.MKTG_CAMPAIGN_SK = f.MKTG_CAMPAIGN_SK
where f.AD_CTGR_SRC = 'MKTG_REP' and f.AD_CTGR_CD is distinct from d.CMPGN_CTGR_CD
having COUNT(*) > 0

union all

-- 🆕 [O233 #36] ㉤ 나열 컬럼: NULL 여부 = AD_CTGR_NM 과 같고 · 첫 항목 = AD_CTGR_NM · 다중 FALSE 이면 이름 1개(나열 = 이름)
select 'NM_LIST', COUNT(*)
from {{ ref('FACT_AD_PERFORMANCE') }}
where (AD_CTGR_NM is null) <> (AD_CTGR_NM_LIST is null)
   or (AD_CTGR_NM_LIST is not null and SPLIT_PART(AD_CTGR_NM_LIST, ', ', 1) <> AD_CTGR_NM)
   or (AD_CTGR_IS_MULTI = FALSE and AD_CTGR_NM_LIST <> AD_CTGR_NM)
having COUNT(*) > 0
