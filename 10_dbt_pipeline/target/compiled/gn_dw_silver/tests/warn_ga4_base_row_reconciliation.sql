-- [2026-08-19 O88] BRONZE ↔ 기반 테이블 행수 정합 관측 — `GA4-SEQ-1` ① 선결의 기계 구현.
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (`90_해소완료_로그.md` §1-B `GA4-SEQ-1` 이 지목한 선결 항목이다)
--   그 항목의 조치 후보 ①이 이것이다:
--     *"기반 모델 `GROUP BY` 실제 출력 행수를 1개월 적재로 확인해 **접힌 양을 확정**한다
--       (`GROUP BY` 는 VARIANT 통째 + param pivot 을 포함하므로 위 233,272 는 **상한**이다)"*
--   O87 은 「손실 0」이라 확정으로 적었고 O87-B 가 그것을 철회했다. 남은 것은 **실측**인데
--   그 실측을 사람이 그때그때 쿼리로 하면 **다음 적재에서 또 사라진다** ⇒ 게이트로 고정한다.
--
-- 무엇을 재는가 — 접힌 양을 **두 원인으로 분해**한다. 이것이 이 게이트의 핵심이다.
--   ㉠ `PARAMS_NULL_ROWS` = BRONZE 에서 `event_params` 가 NULL 인 행수.
--      🔴 O88 이전에는 `LATERAL FLATTEN` 이 INNER 라 이 행들이 **전량 소실**됐다.
--         O88 에서 `OUTER => TRUE` 로 보존했으므로 **이 값은 이제 접힌 양에 포함되지 않는다.**
--         ⇒ 이 컬럼은 「O88 시정이 실제로 몇 행을 구했는가」를 사후에 답한다.
--   ㉡ `FOLDED_ROWS` = BRONZE 행수 − 기반 테이블 행수 = **`GROUP BY` 가 접은 양**.
--      원인은 「11 스칼라/VARIANT + 계보 3 이 전부 동일한 행」이고, 그것이 원천 중복인지
--      의미 있는 서로 다른 이벤트인지는 **데이터가 답할 수 없다** ⇒ 규모만 상시 노출한다.
--
-- 🔴 판정 기준을 임계값으로 두지 않는 이유
--   「접히는 것」은 이 아키텍처의 **의도된 동작**이다(설계문서 07 · 종전 `GA4_EVENT` 도 접었다).
--   따라서 「N% 넘으면 실패」는 근거 없는 숫자가 된다(`R2-3` — 실측 없이 단정 금지).
--   ⇒ 이 게이트의 역할은 **판정이 아니라 노출**이다. 그래서 WARN 이고, 매 run 결과를
--      `store_failures` 로 남겨 **추이**를 본다(`P207` — warn 게이트는 「몇 건」이 아니라
--      「무엇」을 남겨야 한다 · 선례 = `warn_gold_view_comment_coverage`).
--   🟢 접힌 양이 0 이면 이 게이트는 조용하다(아래 having 조건).
--
-- 🔴 비용 — BRONZE 를 **범위 안에서만** 읽는다. 술어는 `ga4_range_predicate` 를 재사용하므로
--    모델·pre-hook 과 자동으로 같은 범위다(범위를 여기 다시 쓰지 말 것 · `R1-6-17`).
--    ⚠️ 그래도 이 테스트는 BRONZE 를 1회 더 스캔한다 — 전 기간으로 범위를 넓히면
--       비용이 그만큼 커진다. 샘플링 구간에서 운용하는 것을 전제한다.
--
-- ⚠️ 수치는 여기 하드코딩하지 않는다(`R2-6`) — 규모 정본은 `90` §1-B-실측이다.



with bronze as (
    select
          count(*)                                          as BRONZE_ROWS
        , count_if("event_params" is null)                   as PARAMS_NULL_ROWS
        , min(EVENT_DT)                                      as FIRST_DT
        , max(EVENT_DT)                                      as LAST_DT
    from GN_DW.BRONZE_BIGQUERY.EVENTS
    where (
    (EVENT_DT >= TO_DATE('2024-06-01') AND EVENT_DT <= TO_DATE('2024-06-30'))
    OR (EVENT_DT >= TO_DATE('2025-06-01') AND EVENT_DT <= TO_DATE('2025-06-30'))
    OR (EVENT_DT >= TO_DATE('2026-06-01') AND EVENT_DT <= TO_DATE('2026-06-30'))
  )
),
base as (
    select count(*) as BASE_ROWS
    from GN_DW.SILVER.BIGQUERY_REFINED_DATA
    where (
    (EVENT_DT >= TO_DATE('2024-06-01') AND EVENT_DT <= TO_DATE('2024-06-30'))
    OR (EVENT_DT >= TO_DATE('2025-06-01') AND EVENT_DT <= TO_DATE('2025-06-30'))
    OR (EVENT_DT >= TO_DATE('2026-06-01') AND EVENT_DT <= TO_DATE('2026-06-30'))
  )
)
select
      b.BRONZE_ROWS                                          as BRONZE_ROWS
    , s.BASE_ROWS                                            as BASE_ROWS
    , b.BRONZE_ROWS - s.BASE_ROWS                            as FOLDED_ROWS
    , round(100.0 * (b.BRONZE_ROWS - s.BASE_ROWS)
            / nullif(b.BRONZE_ROWS, 0), 4)                   as FOLDED_PCT
    , b.PARAMS_NULL_ROWS                                     as PARAMS_NULL_ROWS
    , b.FIRST_DT                                             as FIRST_DT
    , b.LAST_DT                                              as LAST_DT
from bronze b cross join base s
-- 🔴 두 방향을 다 낸다. 음수(BASE > BRONZE)는 **범위 이중 적재**를 뜻하므로 더 위험하다
--    (pre-hook DELETE 범위와 append 범위가 어긋난 경우) ⇒ 0 이 아니면 전부 드러낸다.
where b.BRONZE_ROWS <> s.BASE_ROWS