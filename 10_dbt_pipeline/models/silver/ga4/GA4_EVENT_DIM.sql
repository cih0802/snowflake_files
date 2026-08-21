-- GA4_EVENT_DIM: 이벤트 정의 브리지 (event_params 승격: category/label/action), 정본 09 STEP6.
-- ⚠️ grain = (EVENT_NAME × EVENT_CATEGORY × EVENT_LABEL × EVENT_ACTION). EVENT_NAME 은 다중행 정상(유일 아님).
--    GOLD DIM_GA_EVENT 가 여기서 distinct (category,label,action) 를 추출해 분류차원 SK 생성 → 조합 커버리지 필수.
--    ▶▶ unique(EVENT_NAME) 테스트 금지(순서9-C: 조합 grain 파괴 사고). GA4_EVENT relationships 는 존재성만 요구.
-- Co-authored with CoCo
--
-- 🔄 [2026-08-19 O87] 소스 전환 — ga4_union_shards + LATERAL FLATTEN → ref('BIGQUERY_REFINED_DATA').
-- 🔄 [2026-08-21] BIGQUERY_REFINED_DATA 가 외부 Python 적재로 전환되며 파생을 잃었다 —
--    신설 `GA4_BASIC`(dbt) 이 그 파생을 되살리므로 ref() 로 되돌린다(source() → ref('GA4_BASIC')).
--    종전에는 이 모델이 **자체 FLATTEN + GROUP BY** 로 category/label/action 을 승격했고,
--    그 GROUP BY 절(event_name, event_timestamp, user_pseudo_id, batch_ordering_id)이
--    GA4_EVENT 의 것과 **미묘하게 달랐다**(GA4_EVENT 는 11컬럼). 기반 테이블에서 1회 승격하므로
--    두 모델이 같은 승격 결과를 보게 되어 그 불일치 위험이 사라진다.
-- 🔴 범위 제한을 걸지 않는다(의도) — DISTINCT 차원은 전기간 값 집합이 정본이다.
--    ⚠️ GA-2 카디널리티 리스크는 그대로다 — EVENT_LABEL 이 혼합타입 고카디널리티라 전기간에서
--       이 차원이 사실상 팩트화된다(1일 실측 event_name 49 대비 3,633행). GOLD DIM_GA_EVENT 는
--       event_name(+안정 category/action)으로 conform 하고 label 은 팩트측에 유지할 것.
{{ config(materialized='incremental') }}
SELECT DISTINCT
  EVENT_NAME                     AS EVENT_NAME,
  EVENT_CATEGORY                 AS EVENT_CATEGORY,
  EVENT_LABEL                    AS EVENT_LABEL,
  EVENT_ACTION                   AS EVENT_ACTION,
  'GA4'                          AS DW_SOURCE_SYSTEM,
  'SILVER.GA4_BASIC' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()            AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()            AS DW_UPDATE_TS,
  NULL                           AS DW_BATCH_ID
FROM {{ ref('GA4_BASIC') }}
