-- warn_bigquery_load_gap: 원천과 하류의 **일자 집합 불일치를 양방향으로** 감시한다(일일 증분의 안전망).
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (2026-09-22 · 롤링 윈도우 전환의 짝)
--   BASIC·EVENT·FACT 는 이제 매 run **[오늘 - bigquery_lookback_days, ∞)** 구간만 다시 만든다
--   (`macros/bigquery_range_predicate.sql`). 창 밖 과거는 손대지 않는다 — 그것이 일일 증분이
--   성립하는 근거이면서 동시에 **이 설계가 새로 만든 실패 모드**다:
--     🔴 run 을 lookback 일수보다 오래 건너뛰면 그 사이 일자는 **어떤 run 의 창에도 들어가지
--        못하고 영구히 누락된다.** 다음 run 에서는 이미 창 아래로 밀려나 있기 때문이다.
--   그 누락은 **에러를 내지 않는다.** 모델은 SUCCESS 로 끝나고 행수만 조용히 적다.
--   ⇒ 이 프로젝트가 반복해서 당한 「무증상 결함」의 전형이며(3일치 절단 사고와 같은 종류),
--     구조로 막을 수 없으므로 **관측으로 시끄럽게 만든다**. 그것이 이 테스트의 전부다.
--
-- 🔴 lookback 을 키우는 것은 해법이 아니다 — 비용만 늘고 「얼마나 키워야 충분한가」에
--    답할 수 없다(중단이 얼마나 길지 모른다). 이 테스트가 울리면 **백필로 되메운다**:
--      `dbt_project.yml` `vars` 의 `bigquery_dt_ranges` 주석을 **일시적으로 풀고** 누락 구간을 적어
--      `dbt build --select BIGQUERY_BASIC+` → 끝나면 **다시 주석 처리**.
--    🔴🔴 **`--vars` 로 주지 마라 — 이 환경에서 동작하지 않는다**(실측 2026-09-22 · 3형태 전부 실패).
--       특히 `--vars {bigquery_dt_ranges:[...]}` 는 **에러 없이 조용히 무시된다**(콜론 뒤 공백이 없어
--       YAML 이 키 하나로 파싱한다) ⇒ 백필한 줄 알고 넘어가게 된다. 근거 = `dbt_project.yml` vars 주석.
--
-- ⚠️ 원천은 **지연 도착 이벤트 종료 후 동결된 데이터**가 들어온다(사용자 확인 2026-09-22)
--    ⇒ 이 테스트가 「아직 안 들어온 최신 일자」로 오탐할 여지는 없다. 원천에 있으면 확정이다.
--
-- 🔴🔴 **양방향이다 — 단방향으로 만들면 반대쪽 실패 모드를 영구히 못 본다.**
--   [2026-09-22 자기검토로 발견 · 신설 당일 시정] 최초 구현은 「원천에 있고 하류에 없는」
--   한쪽만 봤다. 그런데 롤링 윈도우는 **창 밖을 건드리지 않으므로 반대쪽이 더 위험하다**:
--     🔴 원천이 어떤 일자를 **잃으면**(외부 Python 이 다른 표본으로 재적재) 하류의 그 일자는
--        **어떤 run 의 창에도 들어가지 않아 영구히 고아로 남는다.** 전량 TRUNCATE 시절에는
--        구조적으로 불가능했던 실패 모드이고, **내가 일일 증분으로 바꿔서 새로 만든 것이다.**
--     ⇒ 그래서 `DIRECTION` 축을 둔다: `SRC_ONLY`(누락) · `DW_ONLY`(고아).
--   🟢 판정식 = **내가 없앤 방어가 무엇인지 세라.** 증분화는 「창 밖 불변」을 얻는 대신
--      「창 밖 검증」을 잃는다 — 그 손실을 메우는 것이 이 테스트의 존재 이유다.
--
-- 🔴 `TRY_TO_DATE` 를 쓴다(`TO_DATE` 아님) — 원천 `EVENT_DATE` 는 `VARCHAR(16777216)` 이고
--    형식이 깨진 값이 있으면 `TO_DATE` 는 **예외를 던져 이 테스트를 ERROR** 로 만든다.
--    감시기가 입력 불량으로 죽으면 감시가 사라진다 ⇒ NULL 로 받아 `BAD_DATE_FORMAT` 행으로
--    **보이게** 만든다. 🟢 즉 이 테스트는 「누락·고아·형식불량」 3축을 한 번에 낸다.
--    ⚠️ 이것은 이 프로젝트의 「조용히 자르지 말고 에러내라」(BIGQUERY_BASIC CAST 규약)와
--       상충하지 않는다 — 그쪽은 **적재 경로**(죽어야 알린다), 이쪽은 **감시 경로**(죽으면 못 알린다).
--
-- ⚠️ 이 테스트가 보지 못하는 것
--   ⓐ **일자 내 행수 차이는 보지 않는다** — 일자가 양쪽에 존재하면 침묵한다.
--      부분 적재(같은 날 일부만)는 여기서 안 잡힌다. 그것이 `bigquery_lookback_days` 의 실제 역할이다
--      (최근 창을 매번 다시 만드므로 부분 적재는 자동 복구된다).
--   ⓑ BASIC 에서 **의도적으로 탈락**시킨 행(`USER_PSEUDO_ID IS NULL`)만으로 하루가 전멸한
--      경우와 구분하지 못한다 ⇒ 울리면 `warn_bigquery_null_user_pseudo_id` 를 함께 볼 것.
--   ⓒ FACT 는 보지 않는다 — SILVER 가 맞으면 FACT 는 같은 창을 공유하므로 따라온다.
--      (FACT 고유 위험인 `DATE_SK = 0` 누적은 `warn_gold_fact_bigquery_date_sk_zero` 소관이다.)
--
-- 📏 탐지 실증(`R3-4`·`P106` — 「대상이 존재하는 상태에서 돌렸는가」)
--   🔴 **0행 통과만으로 「감시된다」고 쓰지 마라** — 그것은 분모 0 이다(`P106`).
--   실측(2026-09-22 · 계정 `LK96056` · 오염 주입 + 역방향 양성대조 4축):
--     · `A` 하류에서 `20260914` 제거        ⇒ `SRC_ONLY` **1건**(`20260914`)        🟢
--     · `B` 원천에서 `20240129` 상실        ⇒ `DW_ONLY` **1건**(`20240129`)         🟢
--     · `C` 원천에 `'2026-XX-99'` 주입      ⇒ `BAD_DATE_FORMAT` **1건**             🟢
--     · `D` 무주입 양성대조(역방향 오탐 축) ⇒ **0건**                                🟢
--   🔴 실증은 **dbt 를 쓰지 않고 순수 SQL 로** 했다(`R4-1` 정지점 · 에이전트는 dbt 를 돌리지 않는다).
--   재현 SQL 정본 = 이력 `§O177`.
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 한쪽에만 있는 일자 1건(방향은 `DIRECTION`).
--   🟢 정상 상태 = 0행.
{{ config(severity = 'warn', store_failures = true, schema = 'OPS') }}

WITH src AS (
    SELECT DISTINCT
        TRY_TO_DATE(EVENT_DATE, 'YYYYMMDD') AS EVENT_DT,
        EVENT_DATE                          AS RAW_EVENT_DATE
    FROM {{ source('silver_external', 'BIGQUERY_REFINED_DATA') }}
    WHERE EVENT_DATE IS NOT NULL
),
basic AS (
    SELECT DISTINCT EVENT_DT FROM {{ ref('BIGQUERY_BASIC') }}
),
evt AS (
    SELECT DISTINCT EVENT_DT FROM {{ ref('BIGQUERY_EVENT') }}
),
-- 축1 = 원천에 있고 하류에 없다(누락 · 롤링 윈도우를 오래 건너뛴 결과)
src_only AS (
    SELECT
        'SRC_ONLY'                                   AS DIRECTION,
        s.EVENT_DT                                   AS EVENT_DT,
        IFF(b.EVENT_DT IS NULL, 'MISSING', 'OK')     AS IN_BIGQUERY_BASIC,
        IFF(e.EVENT_DT IS NULL, 'MISSING', 'OK')     AS IN_BIGQUERY_EVENT
    FROM src s
    LEFT JOIN basic b ON b.EVENT_DT = s.EVENT_DT
    LEFT JOIN evt   e ON e.EVENT_DT = s.EVENT_DT
    WHERE s.EVENT_DT IS NOT NULL
      AND (b.EVENT_DT IS NULL OR e.EVENT_DT IS NULL)
),
-- 축2 = 하류에 있고 원천에 없다(고아 · 창 밖이라 영구 잔존)
dw_only AS (
    SELECT
        'DW_ONLY'                                    AS DIRECTION,
        b.EVENT_DT                                   AS EVENT_DT,
        'ORPHAN'                                     AS IN_BIGQUERY_BASIC,
        IFF(e.EVENT_DT IS NULL, 'ABSENT', 'ORPHAN')  AS IN_BIGQUERY_EVENT
    FROM basic b
    LEFT JOIN evt e ON e.EVENT_DT = b.EVENT_DT
    WHERE NOT EXISTS (
        SELECT 1 FROM src s WHERE s.EVENT_DT = b.EVENT_DT
    )
),
-- 축3 = 원천 EVENT_DATE 가 YYYYMMDD 로 파싱되지 않는다(형식 불량)
bad_fmt AS (
    SELECT DISTINCT
        'BAD_DATE_FORMAT'                            AS DIRECTION,
        CAST(NULL AS DATE)                           AS EVENT_DT,
        LEFT(s.RAW_EVENT_DATE, 20)                   AS IN_BIGQUERY_BASIC,
        '(unparseable)'                              AS IN_BIGQUERY_EVENT
    FROM src s
    WHERE s.EVENT_DT IS NULL
)
SELECT
    DIRECTION                                        AS DIRECTION,
    EVENT_DT                                         AS EVENT_DT,
    IN_BIGQUERY_BASIC                                AS IN_BIGQUERY_BASIC,
    IN_BIGQUERY_EVENT                                AS IN_BIGQUERY_EVENT,
    DATEDIFF(day, EVENT_DT, CURRENT_DATE())          AS AGE_DAYS
FROM (
    SELECT * FROM src_only
    UNION ALL SELECT * FROM dw_only
    UNION ALL SELECT * FROM bad_fmt
)
ORDER BY DIRECTION, EVENT_DT
