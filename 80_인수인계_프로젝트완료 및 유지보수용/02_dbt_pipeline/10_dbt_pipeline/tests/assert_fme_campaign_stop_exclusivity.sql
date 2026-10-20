-- O37 회귀 방어: FACT_MEMBER_EVENT 의 캠페인 귀속 중단건이 개발원천 코드5 에만 붙는지 검증.
-- Co-authored with CoCo
--
-- 왜 필요한가: `CAMPAIGN_STOP_CNT` 와 기존 `STOP_CNT` 는 **같은 중단 사건을 서로 다른 원천에서**
-- 세는 두 축이다(O24 — 개발원천 코드5 와 중단원천이 동일 회원·일자로 중복 존재). 이 불변식이
-- 깨지면 두 축이 겹쳐 중단건이 이중계상되고, 그 상태는 행수·참조무결성 검증을 전부 통과한다.
--
-- ① 코드5 행은 반드시 CAMPAIGN_STOP_CNT=1 이다.
-- ② 코드5 가 아닌 행은 반드시 0 이다(중단원천 행 포함).
-- ③ 상호배타: CAMPAIGN_STOP_CNT=1 인 행의 STOP_CNT 는 0 이어야 한다(같은 행에서 두 번 세지 않는다).
-- ④ 캠페인 축 실재: 코드5 행에 CAMPAIGN_SK 가 배선돼 있어야 한다. 전건 센티넬(0)로 돌아가면
--    「캠페인별 중단률 산출 불가」 상태로 회귀한 것이므로 반드시 실패해야 한다.
--    ⚠️ 고아 캠페인키는 SK=0 으로 흡수되므로 소수의 0 은 정상이다 → 과반 이상이 0 일 때만 위반.
{{ config(severity='error') }}

select 'code5_missing_flag' as violation, COUNT(*) as cnt
from {{ ref('FACT_MEMBER_EVENT') }}
where DVLP_DIV_CD = '5' and COALESCE(CAMPAIGN_STOP_CNT, -1) <> 1
group by 1 having COUNT(*) > 0

union all

select 'non_code5_has_flag', COUNT(*)
from {{ ref('FACT_MEMBER_EVENT') }}
where COALESCE(DVLP_DIV_CD, '') <> '5' and COALESCE(CAMPAIGN_STOP_CNT, -1) <> 0
group by 1 having COUNT(*) > 0

union all

select 'double_counted_stop', COUNT(*)
from {{ ref('FACT_MEMBER_EVENT') }}
where CAMPAIGN_STOP_CNT = 1 and COALESCE(STOP_CNT, 0) <> 0
group by 1 having COUNT(*) > 0

union all

select 'campaign_axis_regressed', COUNT(*)
from (
    select 1 as x
    from {{ ref('FACT_MEMBER_EVENT') }}
    where DVLP_DIV_CD = '5'
    group by 1
    having COUNT_IF(COALESCE(CAMPAIGN_SK, 0) = 0) * 2 > COUNT(*)
)
group by 1 having COUNT(*) > 0
