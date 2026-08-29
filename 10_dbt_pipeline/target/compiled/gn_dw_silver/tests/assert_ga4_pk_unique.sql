-- [2026-08-19 O88] GA4 계열 PK 4키 유일성 게이트 — `GA4-SEQ-1` 의 유일한 기계 검사.
-- Co-authored with CoCo
--
-- 🔄 [2026-08-21] BIGQUERY_REFINED_DATA 가 외부 Python 적재로 전환되며 파생을 잃었다 —
--    신설 `GA4_BASIC`(dbt) 이 그 파생을 되살리므로 ref() 로 되돌린다(source() → ref('GA4_BASIC')).
-- 🔴🔴 왜 필요한가 — 이 축을 검사하는 게이트가 **하나도 없었다.**
--   `08_SILVER_테이블DDL` 이 두 테이블에 `PRIMARY KEY (USER_PSEUDO_ID, EVENT_TIMESTAMP,
--   EVENT_NAME, EVENT_SEQ)` 를 선언하지만 **Snowflake 는 PK 를 강제하지 않는다**(informational).
--   그리고 `_ga4_schema.yml` 은 4키 각각의 `not_null` 만 검사했다 — `not_null` 4개는
--   **조합 유일성을 전혀 증명하지 않는다.** ⇒ PK 가 깨져도 build 가 초록으로 끝난다.
--
-- 🔴 그 공백이 실제로 미결 이슈를 만들었다 (`90_해소완료_로그.md` §1-B `GA4-SEQ-1`)
--   `EVENT_SEQ` 는 `ROW_NUMBER()` surrogate 이므로 3키 내부에서 유일해야 **정의상** 맞다.
--   그런데 O87-B 실측이 `ORDER BY` 튜플 동일 행 **397,224건**(2024-06 표본)을 찾아
--   O87 의 「손실 0 · 중복 흡수」 판정을 무효화했다. 즉 이 계열의 위험은
--     ⓐ 기반 모델 `GROUP BY` 가 접는 양이 미확정 ⓑ 순번이 run 마다 재배치될 수 있음
--   두 가지이고, **둘 다 「PK 가 실제로 유일한가」를 먼저 기계로 고정해야** 논의가 된다.
--
-- 이 테스트가 잡는 것 / 못 잡는 것 (경계를 분명히 한다)
--   🟢 잡는다 = 같은 4키 조합이 2행 이상 존재하는 상태.
--      발생 경로 = ㉠ pre-hook DELETE 범위와 모델 append 범위가 어긋나 **범위가 겹쳐 이중 적재**
--      (`ga4_range_predicate` 단일화로 구조적으로는 막았지만, 그 단일화가 실제로 듣는지를
--       확인하는 것이 이 테스트다 — 게이트 없는 구조 처방은 자기증명이다)
--      ㉡ `ROW_NUMBER()` 파티션 키가 잘못 바뀐 경우 ㉢ `08` DDL 재실행 없이 수동 INSERT.
--   🔴 **못 잡는다 = 재실행 간 순번 안정성**(`GA4-SEQ-1` 본체). 한 시점의 스냅샷만 보므로
--      run A 와 run B 가 같은 행에 다른 `EVENT_SEQ` 를 줘도 각 run 안에서는 유일하다.
--      ⇒ 그것은 두 run 의 결과를 대조해야 판정되며 **이 테스트의 범위가 아니다.**
--      혼동을 막기 위해 여기 명시한다 — 이 테스트 통과를 `GA4-SEQ-1` 해소로 읽지 말 것.
--
-- 왜 ERROR 인가 (severity 미지정 = 기본 error)
--   PK 중복은 **하류 GOLD 의 팬아웃**으로 직결된다(`FACT_GA_BEHAVIOR` 가 `GA4_EVENT` 를 읽는다)
--   ⇒ 값이 조용히 배수로 부풀는 유형이라 warn 으로 두면 그대로 발행된다.
--   선례 = 순서9-D `DIM_MEMBER` 중복 현재행 1,264,753 사고(`90` §1 `D2`)에서 같은 처방을 썼다:
--   *"MEMBER_DK IS_CURRENT 한정 unique 가드레일"*.
--
-- 판정: 반환 행이 있으면 ERROR. 각 행 = 중복된 4키 조합 1건 + 중복 배수.
--   ⚠️ 규모 수치는 여기 하드코딩하지 않는다(`R2-6`) — 정본은 `90` §1-B 다.

select
      'GA4_BASIC'               as MODEL_NAME
    , USER_PSEUDO_ID            as USER_PSEUDO_ID
    , EVENT_TIMESTAMP           as EVENT_TIMESTAMP
    , EVENT_NAME                as EVENT_NAME
    , EVENT_SEQ                 as EVENT_SEQ
    , count(*)                  as DUP_ROWS
    , min(EVENT_DT)             as FIRST_DT
    , max(EVENT_DT)             as LAST_DT
from GN_DW.SILVER.GA4_BASIC
group by all
having count(*) > 1

union all

select
      'GA4_EVENT'               as MODEL_NAME
    , USER_PSEUDO_ID            as USER_PSEUDO_ID
    , EVENT_TIMESTAMP           as EVENT_TIMESTAMP
    , EVENT_NAME                as EVENT_NAME
    , EVENT_SEQ                 as EVENT_SEQ
    , count(*)                  as DUP_ROWS
    , min(EVENT_DT)             as FIRST_DT
    , max(EVENT_DT)             as LAST_DT
from GN_DW.SILVER.GA4_EVENT
group by all
having count(*) > 1