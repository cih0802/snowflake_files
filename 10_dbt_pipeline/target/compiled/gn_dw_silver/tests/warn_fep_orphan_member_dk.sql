-- [2026-08-11 O59-G] `FACT_EVENT_PARTICIPATION` 의 회원 축 **고아 참조**를 관측한다.
-- Co-authored with CoCo
--
-- 🔴 왜 필요한가 (실측 경위)
--   O28 오염 조사에서 `MEMBER_DK = ')'` **2행**이 GOLD 에 라이브인데 `DIM_MEMBER` 에 매칭이
--   **0** 인 것을 발견했다(원장 §O59-G ④). 종전 어느 문서에도 이 2행이 적혀 있지 않았다.
--   이유가 중요하다 — 기존 테스트는 `accepted_values PART_STATUS` 뿐이고 그것은 **상태 축만** 본다.
--   회원 축에는 관측 장치가 아예 없었다. 그래서 이 오염은 **어느 게이트에도 걸리지 않았다.**
--
-- 무엇이 문제인가: 회원 차원으로 조인하면 이 행들은 **조용히 탈락**하고(INNER) 전체 집계에는
--   **남는다**. 즉 「전체 참여 건수」와 「회원별 참여 건수의 합」이 어긋나는 **분모 불일치의 씨앗**이다.
--   기지 이슈 「고아 EVENT_KEY 263,611」과는 **다른 축**이므로 그것으로 대체 관측되지 않는다.
--
-- 왜 WARN 인가: 처분은 DEC-17-B(**원천 보존 + 드러내기**)다. 원천을 고치지 않고 지우거나
--   센티넬로 치환하는 것은 원천 충실 위반이므로, **실패시키지 않고 관측**한다.
--   ⚠️ 규모 수치는 여기 하드코딩하지 않는다(작업규칙 7) — 정본은 원장 §O59-G 다.
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 고아 `MEMBER_DK` 1종.
--   🔴 이 테스트가 **0행이 되면** 원천 정정이 반영됐다는 뜻이므로 원장 §O59-G ⑦ 을 닫는다.



with fep as (

    select distinct MEMBER_DK
    from GN_DW.GOLD.FACT_EVENT_PARTICIPATION
    where MEMBER_DK is not null

),

dim as (

    select MEMBER_DK
    from GN_DW.GOLD.DIM_MEMBER

)

select
      fep.MEMBER_DK                                as ORPHAN_MEMBER_DK
    , length(fep.MEMBER_DK)                        as DK_LENGTH
    , not regexp_like(fep.MEMBER_DK, '^[0-9]+$')   as IS_NON_NUMERIC
from fep
left join dim
       on dim.MEMBER_DK = fep.MEMBER_DK
where dim.MEMBER_DK is null