select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- O37 회귀 방어: 캠페인별 중단률의 구조 불변량 검증 (행이 반환되면 위반).
-- Co-authored with CoCo
--
-- 이 테스트가 지키는 것 = O37 설계의 목적 자체다. 캠페인별 중단률은 값·매핑이 전부 정상이어도
-- **분자·분모 모집단이 어긋나면 조용히 틀린다**. 그것이 애초에 Agent 를 오답으로 이끈 구조이며
-- 어떤 참조무결성·도메인 테스트로도 잡히지 않는다(P60·P63 계열 의미 결함).
--
-- ① 분자 ⊆ 분모: STOPPED_12M_MEMBERS 는 OBSERVABLE_12M_MEMBERS 를 초과할 수 없다.
--    모델이 분자를 관측 가능 집합으로 제한하도록 작성돼 있으므로, 위반은 그 제한이
--    깨졌다는 뜻이다 → 12개월 이탈률이 100% 를 넘을 수 있게 된다.
-- ② 비율 상한: 어떤 캠페인에서도 12개월 이탈률이 100% 를 넘지 않는다.
--    ①의 결과이지만 **소비 끝단이 보는 형태 그대로** 검증한다(집계 후 검증).
--    종전 「사건 기준」 산식이 185% 를 냈던 것이 바로 이 지점이다.
-- ③ 관측 플래그 정합: OBSERVABLE_12M_MEMBERS = IS_12M_OBSERVABLE.
--    둘이 갈라지면 분모가 두 갈래가 되어 같은 질문에 두 답이 나온다.
-- ④ 유지기간 부호: TENURE_DAYS 는 음수가 될 수 없다(획득 이후 중단만 세므로).
--    음수는 「획득 전 중단」이 섞였다는 뜻 = 코호트 귀속이 깨진 것이다.
-- ⑤ 미중단 정합: FIRST_STOP_DATE_SK 가 NULL 이면 이탈 measure 는 전부 0 이어야 한다.
--
-- ⚠️ [2026-08-05 자기지적] 초판이 `IIF` 를 썼다가 첫 build 의 유일한 ERROR 가 됐다(T-SQL 함수 —
--    Snowflake 는 `IFF`). 모델은 `EXPLAIN` 으로 사전 검증했는데 **singular test 는 하지 않았다**.
--    `dbt compile` 은 Jinja 렌더만 하고 SQL 유효성을 DB 에 묻지 않으므로 이런 결함을 잡지 못한다
--    → singular test 도 모델과 동일하게 `EXPLAIN`/실행으로 사전 검증할 것(P64).


select 'numerator_exceeds_denominator' as violation, COUNT(*) as cnt
from GN_DW.GOLD.FACT_MEMBER_COHORT
where STOPPED_12M_MEMBERS > OBSERVABLE_12M_MEMBERS
group by 1 having COUNT(*) > 0

union all

-- 집계 후 비율 상한. 캠페인 단위로 확인한다(소비가 실제로 그루핑하는 축).
select 'churn_rate_over_100pct', COUNT(*)
from (
    select ACQ_CAMPAIGN_SK
    from GN_DW.GOLD.FACT_MEMBER_COHORT
    group by ACQ_CAMPAIGN_SK
    having SUM(OBSERVABLE_12M_MEMBERS) > 0
       and SUM(STOPPED_12M_MEMBERS) > SUM(OBSERVABLE_12M_MEMBERS)
)
group by 1 having COUNT(*) > 0

union all

select 'observable_flag_mismatch', COUNT(*)
from GN_DW.GOLD.FACT_MEMBER_COHORT
where OBSERVABLE_12M_MEMBERS <> IFF(IS_12M_OBSERVABLE, 1, 0)
group by 1 having COUNT(*) > 0

union all

select 'negative_tenure', COUNT(*)
from GN_DW.GOLD.FACT_MEMBER_COHORT
where TENURE_DAYS < 0
group by 1 having COUNT(*) > 0

union all

select 'stopped_measure_without_stop_date', COUNT(*)
from GN_DW.GOLD.FACT_MEMBER_COHORT
where FIRST_STOP_DATE_SK is null
  and (STOPPED_MEMBERS <> 0 or STOPPED_12M_MEMBERS <> 0 or TENURE_DAYS is not null)
group by 1 having COUNT(*) > 0
      
    ) dbt_internal_test