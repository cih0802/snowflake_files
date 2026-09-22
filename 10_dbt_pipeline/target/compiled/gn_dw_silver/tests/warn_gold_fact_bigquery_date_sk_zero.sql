-- warn_gold_fact_bigquery_date_sk_zero: 범위 재적재의 **전제 ③** 을 감시한다.
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (2026-09-22 · FACT 범위 재적재 전환의 짝)
--   `FACT_BIGQUERY_BEHAVIOR` 는 이제 pre-hook 이 `DELETE … WHERE DATE_SK <창>` 을 내고
--   모델이 같은 창을 append 한다(`macros/gold_fact_purge.sql`). 그 멱등성은
--   **「모든 행의 DATE_SK 가 어떤 창에 속한다」** 는 전제 위에 서 있다.
--
--   🔴 그런데 센티넬 `DATE_SK = 0` 은 **어떤 창에도 속하지 않는다.**
--      `date_sk()` 가 DIM_DATE 범위 밖/NULL 을 NULL 로 클램프하고 팩트가 `COALESCE(...,0)` 로
--      0 에 모으므로, 0 행이 생기면:
--        · pre-hook DELETE 는 그 행을 **지우지 않는다**(0 은 창 밖)
--        · 모델 SELECT 는 그 행을 **다시 만든다**(창 안 원천에서 나온 불량 행이므로)
--      ⇒ run 마다 0 버킷이 **중복 누적**된다. 팩트는 `append` 이고 `unique_key` 가 없어
--        중복을 막아 주는 것이 아무것도 없다. 그리고 **에러가 나지 않는다.**
--
--   📏 실측(2026-09-22 · 계정 LK96056) = `DATE_SK = 0` **0행** / 총 1,620,857행.
--      · `SILVER.BIGQUERY_EVENT.EVENT_DT IS NULL` = 0행 (DDL 상 NOT NULL)
--      · DIM_DATE 범위(`cal_start` 1991-01-01 ~ `cal_end` 2035-12-31)가 데이터(2024~2026)를 완전히 덮음
--      ⇒ 현재는 **구조적으로 발생 불가**다. 이 테스트는 그 전제가 깨지는 순간을 잡는다.
--
--   🔴 전제가 깨지는 경로 2가지 — 둘 다 「멀리 있어 보이지만 실제로 일어난다」:
--     ① `cal_start`/`cal_end` 를 좁힌다 ⇒ 범위 밖 일자가 즉시 0 으로 떨어진다.
--     ② 원천에 `EVENT_DT` 를 만들 수 없는 행이 들어온다(`EVENT_DATE` 형식 파괴 등).
--
-- ⚠️ 이 테스트가 울렸을 때 할 일 — 0 버킷을 **지우고 다시 만드는 것으로 끝내지 마라.**
--    근본은 `date_sk()` 가 클램프한 이유(①인지 ②인지)이고, 그것을 고치기 전에는 재발한다.
--    임시 조치로 팩트를 정상화하려면 전량 재적재가 필요하다:
--      dbt build --vars '{ga4_dt_ranges: [["2024-01-01","2026-12-31"]]}' --select FACT_BIGQUERY_BEHAVIOR
--    ⚠️ 그것도 0 버킷을 지우지는 못한다(창 밖이므로) — `DELETE FROM … WHERE DATE_SK = 0` 을
--       먼저 수동 실행해야 한다. 🔴 이 비대칭이 바로 위 「중복 누적」의 정체다.
--
-- 판정: 반환 행이 있으면 WARN(1행 = 센티넬 버킷의 현재 규모).
--   🟢 정상 상태 = 0행.


SELECT
    COUNT(*)                                     AS DATE_SK_ZERO_ROWS,
    COUNT(DISTINCT IDENTITY_SK)                  AS DISTINCT_IDENTITY_SK,
    SUM(EVENT_CNT)                               AS EVENT_CNT_IN_SENTINEL,
    MIN(DW_LOAD_TS)                              AS FIRST_SEEN_LOAD_TS,
    MAX(DW_LOAD_TS)                              AS LAST_SEEN_LOAD_TS
FROM GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR
WHERE DATE_SK = 0
HAVING COUNT(*) > 0