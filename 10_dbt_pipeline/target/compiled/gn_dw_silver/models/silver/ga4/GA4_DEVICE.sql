-- GA4_DEVICE: 기기 차원 DISTINCT (platform+device.category 조합 파생: APP/M/PC), 정본 09 STEP6.
-- Co-authored with CoCo
--
-- 🔄 [2026-08-19 O87] 소스 전환 — ga4_union_shards 매크로 → ref('BIGQUERY_REFINED_DATA').
-- 🔄 [2026-08-21] BIGQUERY_REFINED_DATA 가 외부 Python 적재로 전환되며 파생을 잃었다 —
--    신설 `GA4_BASIC`(dbt) 이 그 파생을 되살리므로 ref() 로 되돌린다(source() → ref('GA4_BASIC')).
--    · DEVICE_TYPE 파생 CASE 는 기반 테이블에서 **1회만** 계산된다(종전엔 이 파일과
--      GA4_EVENT.sql 두 곳에 중복 존재했고, 2026-07-27 교정 때 두 곳을 따로 고쳐야 했다).
--    · VARIANT(device) 파싱도 기반 테이블에서 끝난다 ⇒ 이 모델은 스칼라 DISTINCT 만 한다.
-- 🔴 범위 제한을 걸지 않는다(의도) — DISTINCT 차원은 **전기간 값 집합**이 정본이다.
--    범위 제한하면 특정 월에만 등장한 기기 조합이 사라진다. 그래서 이 모델의 pre-hook 은
--    기본 TRUNCATE(전량 재적재)를 유지한다(macros/ga4_range_purge.sql 주석 참조).
-- grain = DEVICE_TYPE × PLATFORM × DEVICE_CATEGORY × OS × BROWSER × LANGUAGE DISTINCT (PK 없음).

SELECT DISTINCT
  DEVICE_TYPE                  AS DEVICE_TYPE,
  PLATFORM                     AS PLATFORM,
  DEVICE_CATEGORY              AS DEVICE_CATEGORY,
  OS                           AS OS,
  BROWSER                      AS BROWSER,
  LANGUAGE                     AS LANGUAGE,
  'GA4'                        AS DW_SOURCE_SYSTEM,
  'SILVER.GA4_BASIC' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()          AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()          AS DW_UPDATE_TS,
  NULL                         AS DW_BATCH_ID
FROM GN_DW.SILVER.GA4_BASIC