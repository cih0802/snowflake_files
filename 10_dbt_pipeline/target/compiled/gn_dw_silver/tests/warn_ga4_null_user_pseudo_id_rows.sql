-- warn_ga4_null_user_pseudo_id_rows: GA4 `USER_PSEUDO_ID` NULL 탈락 행을 **행 단위로 고정**한다.
-- Co-authored with CoCo
--
-- 🆕 🔴🔴 [2026-09-22 O176 · 사용자 결정 B안] `O91-F A1` 의 정면 처방이다.
--   `A1` 판정 = *"`DEC-40` 은 행을 버리면서 격리 테이블을 만들지 않았다 — 감사 불가 설계다.
--   주석은 사람만 읽고 쿼리할 수 없다. 「어느 행이 왜 빠졌나」를 **데이터로** 재현해야 하는데
--   그 경로가 없다."*
--   ⇒ 짝 테스트 `warn_ga4_null_user_pseudo_id.sql` 은 **날짜별 집계**만 남긴다(「얼마나」).
--      이 테스트가 **개별 행**을 남긴다(「어느 행이」). 두 축은 대체물이 아니다.
--
-- 🟢 전용 테이블(`OPS.GA4_REJECT_LOG`)을 신설하지 않은 이유
--   이 프로젝트에 `store_failures: true, schema: OPS` 패턴이 **이미 확립**돼 있다(5곳 ⇒ `OPS` 5테이블).
--   전용 테이블을 더하면 **같은 것을 다르게 재는 지점**이 생기고 적재·정리 주체가 이원화된다(`R3-9 ㉡`).
--   ⇒ 산출 테이블 = `OPS.WARN_GA4_NULL_USER_PSEUDO_ID_ROWS` (dbt 가 테스트명으로 만든다).
--
-- 🔴🔴 **WHERE 절은 짝 테스트와 한 글자도 다르지 않아야 한다.**
--   두 테스트의 분모가 갈리면 「집계는 0인데 행은 있다」처럼 **서로를 반박하는 판정**이 나온다.
--   ⇒ 짝 테스트를 고치면 **이 파일도 같은 턴에 고쳐라**(분모 단일 관리 · `O167 ㉢` 축).
--   기지 창 제외(`20240605~20240610`)도 같은 이유로 승계한다(`P103-⑤` 항상 빨간 게이트 금지).
--
-- ⚠️ 보존 컬럼을 118 전량으로 하지 않은 이유
--   조사에 필요한 것은 **식별·시점·유입 경로**다. 전량 복제는 감사 테이블을 원천만큼 키우고
--   재적재 때마다 부풀린다. 🔴 다시 넓혀야 할 필요가 생기면 **그 사유를 여기 적고** 넓혀라.
--   · `USER_ID` 는 원값을 남긴다 — GA4 가명 식별자이고 「NULL 인 pseudo_id 행에 user_id 가 있었나」가
--     `A1` 조사의 핵심 축이다(기지 창 111행은 **전건 USER_ID 도 NULL** 이었다).
--     ⚠️ PII 제외 패턴(`MBER_NM`·`ADDR`·`TEL`·`EMAIL_ADDR` 계열)에 해당하지 않는다.
--
-- 📏 실측(2026-09-22 · 계정 LK96056) = `USER_PSEUDO_ID IS NULL` **0행**(총 10,332,737).
--   🔴 **0행을 「해소」로 읽지 마라**(`P106` 분모 0 은 통과가 아니다) — 기지 창 111행도 현 계정에
--   재현되지 않으므로 계정 이관·재적재의 결과일 수 있다. 이 테스트의 값은 **재발 시 규명 경로**다.
--   🔄 [2026-09-22] 종전 이 자리에는 *"이 테스트는 **날짜 범위 탈락을 보지 않는다** — 실측 탈락
--   9,033,325행(33일→3일)은 `ga4_dt_ranges` 의 의도된 범위 제한이다"* 가 적혀 있었다.
--   🔴 그 「의도된 범위 제한」이 **의도가 아니었다** — 원천이 월 1일 샘플로 바뀐 뒤 6월 창과의
--   교집합이 3일뿐이 된 **이중 샘플링 결함**이었고(하류 전체가 3일치로 잘림), 2026-09-22 에
--   롤링 윈도우로 전환하며 해소했다. 범위 필터는 이 테스트에서도 제거했다(원천 전량 관측).
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 기지 창 밖에서 탈락한 원천 행 1건.
--   🟢 정상 상태 = 0행.


SELECT
    BATCH_EVENT_INDEX                            AS BATCH_EVENT_INDEX,
    EVENT_DATE                                   AS EVENT_DATE,
    EVENT_TIMESTAMP                              AS EVENT_TIMESTAMP,
    EVENT_NAME                                   AS EVENT_NAME,
    USER_ID                                      AS USER_ID,
    EP_GA_SESSION_ID                             AS EP_GA_SESSION_ID,
    STREAM_ID                                    AS STREAM_ID,
    PLATFORM                                     AS PLATFORM,
    EP_PAGE_LOCATION                             AS EP_PAGE_LOCATION,
    'USER_PSEUDO_ID_IS_NULL'                     AS REJECT_REASON
FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
WHERE USER_PSEUDO_ID IS NULL
  -- 기지 창 제외 — 🔴 짝 테스트와 동일해야 한다(위 「WHERE 절은 한 글자도 다르지 않아야 한다」)
  AND NOT (EVENT_DATE BETWEEN '20240605' AND '20240610')
ORDER BY EVENT_DATE, EVENT_TIMESTAMP