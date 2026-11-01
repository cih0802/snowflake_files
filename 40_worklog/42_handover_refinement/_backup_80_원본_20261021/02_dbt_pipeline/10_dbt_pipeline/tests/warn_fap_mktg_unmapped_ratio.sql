-- [2026-10-14 O225] DIGITAL 광고비 중 마케팅캠페인 미매핑(SK=0) 비율 경고 + 귀속 경로 정합.
-- Co-authored with CoCo
--
-- 왜: 이름매칭 단일 경로(O45)에서 DIGITAL 미매핑이 33.69%(11,379,933,112원 · xh20001 · O225 실측)까지 컸는데
--   어떤 테스트도 울리지 않았다. UTM 보조 경로 적용 후 시뮬레이션 = 2,693,839,977원(약 8.0%).
--   ⇒ 임계 15% — 넘으면 새 대행사 캠페인명·UTM 태그가 마스터에 없다는 신호다(별칭 등록·현업 확인).
--   VIDEO·REBROADCAST 는 캠페인명 원천 결손(95.85%·100%)이라 이 경고의 분모에서 뺀다(별도 과제).
--
-- 반환 행 = ㉠ 비율 초과 ㉡ 경로 표기와 SK 모순(UTM 인데 후보 0 · NONE 인데 SK≠0 등).
-- 판정: 반환 행이 있으면 WARN.
{{ config(severity = 'warn') }}

with d as (
    select
        SUM(AD_COST)                                as COST,
        SUM(iff(MKTG_CAMPAIGN_SK = 0, AD_COST, 0))  as UNMAPPED_COST
    from {{ ref('FACT_AD_PERFORMANCE') }}
    where AD_SOURCE_TYPE = 'DIGITAL'
)
select 'UNMAPPED_RATIO' as CHECK_NM, ROUND(UNMAPPED_COST / NULLIF(COST, 0) * 100, 2) as VAL
from d
where UNMAPPED_COST / NULLIF(COST, 0) > 0.15
union all
select 'METHOD_SK_MISMATCH:' || MKTG_MAP_METHOD, count(*)
from {{ ref('FACT_AD_PERFORMANCE') }}
where (MKTG_MAP_METHOD = 'NONE' and MKTG_CAMPAIGN_SK <> 0)
   or (MKTG_MAP_METHOD <> 'NONE' and MKTG_CAMPAIGN_SK = 0)
   or (MKTG_MAP_METHOD = 'UTM' and COALESCE(MKTG_MAP_CAND_CNT, 0) < 1)
   or MKTG_MAP_METHOD is null
group by MKTG_MAP_METHOD
