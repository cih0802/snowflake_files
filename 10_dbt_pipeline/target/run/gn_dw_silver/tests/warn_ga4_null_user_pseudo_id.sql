select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- warn_ga4_null_user_pseudo_id: GA4 원천의 `user_pseudo_id` NULL 을 **기지 창 밖에서만** 관측한다.
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (2026-08-20 O91-D · 사용자 결정 「필터 제외」의 짝)
--   `BIGQUERY_REFINED_DATA` 는 `USER_PSEUDO_ID NOT NULL`(grain 1번 컬럼)이라 원천에 NULL 이
--   1행만 있어도 `100072` 로 **모델 전체가 실패**한다. 실측(2026-08-20)에서 **111행**이
--   `build` 를 죽여 **모델 18개 + 테스트 61개가 SKIP** 됐고, `DIM_DEVICE` 가 GA4 파생이라
--   **광고 도메인(FACT_AD_PERFORMANCE·WIDE_AD_*)까지 함께 죽었다.**
--   ⇒ 모델에 `AND "user_pseudo_id" IS NOT NULL` 필터를 넣어 실패를 막았다. 이 테스트는
--      **그 필터가 조용히 삼키는 양이 커지는지**를 감시한다. 필터만 있으면 소실이 보이지 않는다.
--
-- 🔴 왜 「기지 창 밖에서만」인가 (사용자 결정 · P103-⑤)
--   P103-⑤ = **「항상 빨간 게이트는 무시된다」**. 기지 사고 111행을 그대로 세면 이 테스트는
--   **영구히 WARN** 이고 곧 아무도 안 본다. 그래서 이미 규명된 창을 분모에서 뺀다:
--     · 기지 창 = `EVENT_DT` **2024-06-05 ~ 2024-06-10**(6일 · 6샤드 · 111행 · 전건 `user_id` 도 NULL)
--     · ⇒ 이 테스트가 WARN 이면 **「새로운 사고」**라는 뜻이다. 신호 대 잡음비를 위해 이렇게 좁혔다.
--   ⚠️ 절대 건수(111)를 기지값으로 박지 않은 이유 = GA4 는 계속 유입되는 파이프라인이라
--      고정 숫자는 곧 stale 이 된다(작업규칙 7 · 규모 정본은 `50_dbt_…-013` §O91-C·§O91-D).
--
-- ⚠️ 이 테스트가 보지 못하는 것 (해석 전에 읽을 것)
--   ⓐ **기지 창 안의 변화는 보지 않는다.** 그 창의 111행이 200행으로 늘어도 침묵한다.
--      그 창을 재적재했다면 이 테스트가 아니라 `-013` §O91-C 의 수치를 직접 재라.
--   ⓑ **범위 술어(`ga4_range_predicate`) 밖은 보지 않는다** — 모델이 읽지 않는 구간의 NULL 은
--      실패를 유발하지 않으므로 감시 대상이 아니다. 범위를 넓히면 이 테스트가 먼저 울린다(의도된 동작).
--   ⓒ 이것은 **원천 관측**이고 SILVER 결과 검증이 아니다. SILVER 쪽 행수 대조는 별건이다.
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 기지 창 밖에서 발견된 NULL 샤드 1개 + 규모.
--   🟢 정상 상태 = 0행.


SELECT
    SRC_TABLE                                   AS SRC_TABLE,
    EVENT_DT                                    AS EVENT_DT,
    COUNT(*)                                    AS NULL_UPI_ROWS,
    COUNT(DISTINCT SRC_FILE_NAME)               AS SRC_FILES,
    COUNT_IF("user_id" IS NOT NULL)             AS HAS_USER_ID_ROWS
FROM GN_DW.BRONZE_BIGQUERY.EVENTS
WHERE (
    (EVENT_DT >= TO_DATE('2024-06-01') AND EVENT_DT <= TO_DATE('2024-06-30'))
    OR (EVENT_DT >= TO_DATE('2025-06-01') AND EVENT_DT <= TO_DATE('2025-06-30'))
    OR (EVENT_DT >= TO_DATE('2026-06-01') AND EVENT_DT <= TO_DATE('2026-06-30'))
  )
  AND "user_pseudo_id" IS NULL
  -- 기지 창 제외 (위 「왜 기지 창 밖에서만인가」 참조 · 정본 = 50_dbt_…-013 §O91-C)
  AND NOT (EVENT_DT BETWEEN DATE '2024-06-05' AND DATE '2024-06-10')
GROUP BY 1, 2
ORDER BY 2, 1
      
    ) dbt_internal_test