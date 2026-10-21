-- warn_bigquery_null_user_pseudo_id: GA4 원천의 USER_PSEUDO_ID NULL 을 **기지 창 밖에서만** 관측한다.
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (2026-08-20 O91-D · 사용자 결정 「필터 제외」의 짝)
--   `BIGQUERY_BASIC` 은 `USER_PSEUDO_ID NOT NULL`(grain 1번 컬럼)이라 원천에 NULL 이
--   1행만 있어도 `100072` 로 **모델 전체가 실패**한다. 실측(2026-08-20)에서 **111행**이
--   `build` 를 죽여 모델·테스트가 대량 SKIP 됐다.
--   ⇒ `BIGQUERY_BASIC` 에 `WHERE USER_PSEUDO_ID IS NOT NULL` 필터를 넣어 실패를 막았다. 이 테스트는
--      **그 필터가 조용히 삼키는 양이 커지는지**를 감시한다. 필터만 있으면 소실이 보이지 않는다.
--
-- 🔄 [2026-08-21] 원천을 `source('bronze_bigquery','EVENTS')` → `source('silver_external',
--    'BIGQUERY_REFINED_DATA')` 로 교체했다 — 계정 이관 후 `BRONZE_BIGQUERY.EVENTS` **통합
--    테이블이 라이브에 없다**(실측: 일별 샤드 `events_YYYYMMDD` 911개 + 월별 `BQ_YYYYMM` 30개만
--    존재 · 통합 `EVENTS` 는 구 계정 `UA93987` 기록이고 현 계정에 재현되지 않음).
--    `BIGQUERY_REFINED_DATA`(외부 Python 적재)가 `BIGQUERY_BASIC` 의 필터 **이전** 원본이므로
--    개념적으로 동일한 관측을 계속할 수 있는 유일한 SILVER 객체다.
--    ⚠️ `SRC_TABLE`·`SRC_FILE_NAME` 계보 컬럼은 외부 적재에 없다 — 그룹핑을 `EVENT_DATE` 로
--    대체했다. `EVENT_DATE` 는 TEXT(YYYYMMDD) 라 리터럴 문자열 비교로 필터한다(BIGQUERY_BASIC 과 동일
--    이유 — 함수를 적용하면 프루닝이 깨진다).
--
-- 🔴 왜 「기지 창 밖에서만」인가 (사용자 결정 · P103-⑤)
--   P103-⑤ = **「항상 빨간 게이트는 무시된다」**. 기지 사고 111행을 그대로 세면 이 테스트는
--   **영구히 WARN** 이고 곧 아무도 안 본다. 그래서 이미 규명된 창을 분모에서 뺀다:
--     · 기지 창 = `EVENT_DATE` **20240605 ~ 20240610**(6일 · 111행 · 전건 `USER_ID` 도 NULL)
--     · ⇒ 이 테스트가 WARN 이면 **「새로운 사고」**라는 뜻이다. 신호 대 잡음비를 위해 이렇게 좁혔다.
--   ⚠️ 절대 건수(111)를 기지값으로 박지 않은 이유 = GA4 는 계속 유입되는 파이프라인이라
--      고정 숫자는 곧 stale 이 된다(작업규칙 7 · 규모 정본은 `50_dbt_…-013` §O91-C·§O91-D).
--
-- ⚠️ 이 테스트가 보지 못하는 것 (해석 전에 읽을 것)
--   ⓐ **기지 창 안의 변화는 보지 않는다.** 그 창의 111행이 200행으로 늘어도 침묵한다.
--      그 창을 재적재했다면 이 테스트가 아니라 `-013` §O91-C 의 수치를 직접 재라.
--   ⓑ 🔄 [2026-09-22] 종전 이 항목은 *"`bigquery_dt_ranges` 밖은 보지 않는다"* 였다 —
--      그 범위 필터를 **제거했다**. 이제 원천 **전량**을 관측한다.
--      왜: dbt 가 원천에 있는 것을 전량 하류로 흘리도록 바뀌었으므로(롤링 윈도우는 「이번 run 이
--      다시 만들 구간」일 뿐 적재 범위가 아니다) 「모델이 읽지 않는 구간」이라는 개념이 사라졌다.
--      그리고 창을 여기서 다시 전개하던 것이 **술어 중복 지점**이었다(`R1-6-17`) ⇒ 같이 없앴다.
--   ⓒ 이것은 **원천 관측**이고 SILVER 결과 검증이 아니다. SILVER 쪽 행수 대조는 별건이다.
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 기지 창 밖에서 발견된 NULL 날짜 1건 + 규모.
--   🟢 정상 상태 = 0행.
--
-- 🆕 🟢 [2026-09-22 O176 · 사용자 결정 B안 · `O91-F A1` 처방] `store_failures` 를 켰다.
--   🔴 **왜** = `A1` 이 *"`DEC-40` 은 행을 버리면서 격리 테이블을 만들지 않았다 — 감사 불가 설계다"* 로
--   지적한 그 결함이다. 종전에는 WARN 이 `Got N results` 만 남겨 **다음 세션이 규모를 재현할 수 없었다**.
--   🟢 전용 테이블(`OPS.GA4_REJECT_LOG`)을 새로 만들지 않은 이유 = 이 프로젝트에 **이미 확립된 패턴**이
--   있고(`store_failures: true, schema: OPS` × 5곳 ⇒ `OPS` 5테이블 실재) 전용 테이블을 더하면
--   **같은 것을 다르게 재는 지점**이 생긴다(`R3-9 ㉡`).
--   ⚠️ 이 테스트가 보존하는 것은 **날짜별 집계**다 — 개별 탈락 행은 짝 테스트
--   `warn_bigquery_null_user_pseudo_id_rows.sql` 이 보존한다(그쪽이 `A1` 의 「어느 행이」에 답한다).
--   📏 실측(2026-09-22 · 계정 LK96056) = `BIGQUERY_REFINED_DATA` 의 `USER_PSEUDO_ID IS NULL` **0행**
--     (기지 창 111행도 현 계정에 재현되지 않는다) ⇒ 🔴 **0행을 「해소」로 읽지 마라** — 계정 이관·재적재의
--     결과일 수 있고, 이 두 테스트는 **재발 시 규명 경로**로서 값을 갖는다(`P106` 분모 0 은 통과가 아니다).
{{ config(severity = 'warn', store_failures = true, schema = 'OPS') }}

SELECT
    EVENT_DATE                                   AS EVENT_DATE,
    COUNT(*)                                     AS NULL_UPI_ROWS,
    COUNT_IF(USER_ID IS NOT NULL)                AS HAS_USER_ID_ROWS
FROM {{ source('silver_external', 'BIGQUERY_REFINED_DATA') }}
WHERE USER_PSEUDO_ID IS NULL
  -- 기지 창 제외 (위 「왜 기지 창 밖에서만인가」 참조 · 정본 = 50_dbt_…-013 §O91-C)
  AND NOT (EVENT_DATE BETWEEN '20240605' AND '20240610')
GROUP BY 1
ORDER BY 1
