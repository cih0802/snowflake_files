-- warn_ga4_load_gap: 원천에 있고 하류에 없는 일자를 감시한다(일일 증분의 **유일한 안전망**).
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (2026-09-22 · 롤링 윈도우 전환의 짝)
--   BASIC·EVENT·FACT 는 이제 매 run **[오늘 - ga4_lookback_days, ∞)** 구간만 다시 만든다
--   (`macros/ga4_range_predicate.sql`). 창 밖 과거는 손대지 않는다 — 그것이 일일 증분이
--   성립하는 근거이면서 동시에 **이 설계의 유일한 실패 모드**다:
--     🔴 run 을 lookback 일수보다 오래 건너뛰면 그 사이 일자는 **어떤 run 의 창에도 들어가지
--        못하고 영구히 누락된다.** 다음 run 에서는 이미 창 아래로 밀려나 있기 때문이다.
--   그 누락은 **에러를 내지 않는다.** 모델은 SUCCESS 로 끝나고 행수만 조용히 적다.
--   ⇒ 이 프로젝트가 반복해서 당한 「무증상 결함」의 전형이며(3일치 절단 사고와 같은 종류),
--     구조로 막을 수 없으므로 **관측으로 시끄럽게 만든다**. 그것이 이 테스트의 전부다.
--
-- 🔴 lookback 을 키우는 것은 해법이 아니다 — 비용만 늘고 「얼마나 키워야 충분한가」에
--    답할 수 없다(중단이 얼마나 길지 모른다). 이 테스트가 울리면 백필로 되메운다:
--      dbt build --vars '{ga4_dt_ranges: [["<누락시작>","<누락종료>"]]}' --select BIGQUERY_BASIC+
--
-- ⚠️ 원천은 **지연 도착 이벤트 종료 후 동결된 데이터**가 들어온다(사용자 확인 2026-09-22)
--    ⇒ 이 테스트가 「아직 안 들어온 최신 일자」로 오탐할 여지는 없다. 원천에 있으면 확정이다.
--
-- ⚠️ 이 테스트가 보지 못하는 것
--   ⓐ **일자 내 행수 차이는 보지 않는다** — 일자가 양쪽에 존재하면 침묵한다.
--      부분 적재(같은 날 일부만)는 여기서 안 잡힌다. 그것이 `ga4_lookback_days` 의 실제 역할이다
--      (최근 창을 매번 다시 만들므로 부분 적재는 자동 복구된다).
--   ⓑ BASIC 에서 **의도적으로 탈락**시킨 행(`USER_PSEUDO_ID IS NULL`)만으로 하루가 전멸한
--      경우와 구분하지 못한다 ⇒ 울리면 `warn_ga4_null_user_pseudo_id` 를 함께 볼 것.
--   ⓒ FACT 는 보지 않는다 — SILVER 가 맞으면 FACT 는 같은 창을 공유하므로 따라온다.
--      (FACT 고유 위험인 `DATE_SK = 0` 누적은 `warn_gold_fact_bigquery_date_sk_zero` 소관이다.)
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 원천에 있으나 BASIC/EVENT 에 없는 일자 1건.
--   🟢 정상 상태 = 0행.


WITH src AS (
    SELECT DISTINCT TO_DATE(EVENT_DATE, 'YYYYMMDD') AS EVENT_DT
    FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
    WHERE EVENT_DATE IS NOT NULL
),
basic AS (
    SELECT DISTINCT EVENT_DT FROM GN_DW.SILVER.BIGQUERY_BASIC
),
evt AS (
    SELECT DISTINCT EVENT_DT FROM GN_DW.SILVER.BIGQUERY_EVENT
)
SELECT
    s.EVENT_DT                                              AS MISSING_EVENT_DT,
    IFF(b.EVENT_DT IS NULL, 'MISSING', 'OK')                AS IN_BIGQUERY_BASIC,
    IFF(e.EVENT_DT IS NULL, 'MISSING', 'OK')                AS IN_BIGQUERY_EVENT,
    DATEDIFF(day, s.EVENT_DT, CURRENT_DATE())               AS AGE_DAYS
FROM src s
LEFT JOIN basic b ON b.EVENT_DT = s.EVENT_DT
LEFT JOIN evt   e ON e.EVENT_DT = s.EVENT_DT
WHERE b.EVENT_DT IS NULL OR e.EVENT_DT IS NULL
ORDER BY 1