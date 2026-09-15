-- BIGQUERY_EVENT_DIM: 이벤트 정의 브리지 (event_params 승격: category/label/action), 정본 09 STEP6.
-- ⚠️ grain = (EVENT_NAME × EVENT_CATEGORY × EVENT_LABEL × EVENT_ACTION). EVENT_NAME 은 다중행 정상(유일 아님).
--    GOLD DIM_BIGQUERY_EVENT 가 여기서 distinct (category,label,action) 를 추출해 분류차원 SK 생성 → 조합 커버리지 필수.
--    source() 대신 ref('BIGQUERY_BASIC') 을 읽는다.
--
-- ⚠️ [순서9-C grain 비판검토] EVENT_NAME 단독 unique 금지:
--    동일 이벤트명이 파라미터 조합에 따라 복수 행으로 존재한다. 이를 unique 로 묶으면
--    (app_exception, ..., ...) 등 다중 행이 잘려 하류 분류 차원이 결손된다.
--    grain 은 (EVENT_NAME, EVENT_CATEGORY, EVENT_LABEL, EVENT_ACTION) 복합 4키다.
--    ⚠️ 이 모델은 분류 차원이 아니라 브리지(bridge)다 — EVENT_NAME 과 3파라미터의 M:N 사전을
--       BIGQUERY_EVENT 팩트 조인용으로 제공한다.
--       실측: 이벤트 49종 중 다중 조합은 1종('app_exception' 5개 조합)뿐이고 나머지는 1:1 이다.
--       이 구조를 '이벤트 차원'이라 부르면 안 된다 — 이벤트명에 파라미터를 붙여 유일키를 만들면
--       이 차원이 사실상 팩트화된다(1일 실측 event_name 49 대비 3,633행). GOLD DIM_BIGQUERY_EVENT 는
--       event_name(+안정 category/action)으로 conform 하고 label 은 팩트측에 유지할 것.

SELECT DISTINCT
  EVENT_NAME                     AS EVENT_NAME,
  EVENT_CATEGORY                 AS EVENT_CATEGORY,
  EVENT_LABEL                    AS EVENT_LABEL,
  EVENT_ACTION                   AS EVENT_ACTION,
  'GA4'                          AS DW_SOURCE_SYSTEM,
  'SILVER.BIGQUERY_BASIC' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()            AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()            AS DW_UPDATE_TS,
  NULL                           AS DW_BATCH_ID
FROM GN_DW.SILVER.BIGQUERY_BASIC