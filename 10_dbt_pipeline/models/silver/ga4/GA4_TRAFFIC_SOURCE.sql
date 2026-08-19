-- GA4_TRAFFIC_SOURCE: 세션 last-click 트래픽소스 DISTINCT (first-touch/collected 제외 = grain 팽창 방지), 정본 09 STEP6.
-- Co-authored with CoCo
--
-- 🔄 [2026-08-19 O87] 소스 전환 — ga4_union_shards 매크로 → ref('BIGQUERY_REFINED_DATA').
--    session_traffic_source_last_click(VARIANT) 경로 추출과 센티넬 NULLIF 처리는
--    기반 테이블에서 끝났다 ⇒ 이 모델은 스칼라 10컬럼 DISTINCT 만 한다.
--    ⚠️ first-touch(traffic_source)·collected 제외 원칙은 기반 테이블이 승계한다 —
--       그 두 축은 BIGQUERY_REFINED_DATA 에도 올리지 않았다(어트리뷰션 모델·grain 상이).
-- 🔴 범위 제한을 걸지 않는다(의도) — DISTINCT 차원은 전기간 값 집합이 정본이다.
--    특정 월에만 집행된 캠페인의 UTM 이 사라지면 DIM_GA_SOURCE 에 구멍이 난다.
{{ config(materialized='incremental') }}
SELECT DISTINCT
  UTM_SOURCE                     AS UTM_SOURCE,
  UTM_MEDIUM                     AS UTM_MEDIUM,
  UTM_CAMPAIGN                   AS UTM_CAMPAIGN,
  UTM_CONTENT                    AS UTM_CONTENT,
  UTM_TERM                       AS UTM_TERM,
  SOURCE_MEDIUM                  AS SOURCE_MEDIUM,
  XCHAN_SOURCE                   AS XCHAN_SOURCE,
  XCHAN_MEDIUM                   AS XCHAN_MEDIUM,
  XCHAN_CAMPAIGN                 AS XCHAN_CAMPAIGN,
  DEFAULT_CHANNEL_GROUP          AS DEFAULT_CHANNEL_GROUP,
  'GA4'                          AS DW_SOURCE_SYSTEM,
  'SILVER.BIGQUERY_REFINED_DATA' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()            AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()            AS DW_UPDATE_TS,
  NULL                           AS DW_BATCH_ID
FROM {{ ref('BIGQUERY_REFINED_DATA') }}
