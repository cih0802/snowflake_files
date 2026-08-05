-- [2026-08-05 O38] WIDE_DEV_ACHIEVEMENT 는 목표 행을 하나도 잃지 않아야 한다.
-- Co-authored with CoCo
--
-- 무엇을 지키는가: `FACT_TARGET_DEV` 의 모든 행이 소비뷰에 `HAS_GOAL_ROW=TRUE` 로 살아 있어야 한다.
--   이 뷰는 목표 × 실적을 **FULL OUTER** 로 묶는데, 조인 키의 타입·널 처리·grain 이 어긋나면
--   목표 행이 조용히 유실된다. 유실되면 **달성율의 분모가 작아져 달성율이 과대**해지는데,
--   행수는 오히려 줄어들어 "정상"처럼 보인다 — 총계 대조만으로는 잡히지 않는다.
--
-- 왜 이 테스트가 필요한가(실측 경위): 같은 뷰에서 이미 한 번 **분자·분모 스코프 불일치**로
--   달성율이 폭증한 사고가 있었다(증액 537% · 재후원 1700%). 원인은 목표 행의 과반이
--   `GOAL_CNT=0` 인데 「목표 행 존재」를 「목표 편성」으로 읽은 것이었다.
--   그 교정으로 플래그를 `HAS_GOAL_ROW`(행 존재) / `HAS_POSITIVE_GOAL`(값 편성)로 분리했으므로,
--   이제 **행 보존**은 기계적으로 검사할 수 있다.
--
-- 위반 조건: 뷰의 `HAS_GOAL_ROW=TRUE` 행수 != 팩트 행수, 또는 목표 합계 불일치.
--   ⚠️ 합계 비교 시 `GOAL_CNT` 는 뷰에서 `COALESCE(...,0)` 되고 팩트는 NULL 을 보존하므로
--      `SUM` 은 NULL 을 무시해 양쪽이 같다(0 과 NULL 의 합 기여가 동일).
--
-- 판정: 0행이면 PASS.

with fact_side as (
    select count(*) as N, SUM(GOAL_CNT) as G
    from {{ ref('FACT_TARGET_DEV') }}
),
view_side as (
    select count(*) as N, SUM(GOAL_CNT) as G
    from {{ ref('WIDE_DEV_ACHIEVEMENT') }}
    where HAS_GOAL_ROW
)
select
    f.N as FACT_ROWS, v.N as VIEW_GOAL_ROWS,
    f.G as FACT_GOAL_SUM, v.G as VIEW_GOAL_SUM
from fact_side f cross join view_side v
where f.N <> v.N
   or COALESCE(f.G, 0) <> COALESCE(v.G, 0)
