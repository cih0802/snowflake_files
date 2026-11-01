-- 🔴🔴 [2026-08-19 O87] 이 매크로는 **폐기(DEPRECATED)** 됐다. 어느 모델도 참조하지 않는다.
--    삭제 대상이나 파일 삭제는 사용자 승인이 필요해(R4-4-3) 폐기 표기만 남긴다.
--
--    왜 폐기했나: BRONZE 가 **일별 샤드가 아니라 통합 1테이블**로 적재됐다(G-5 해소 · O86).
--      `GN_DW.BRONZE_BIGQUERY.EVENTS` = 285,676,588행 / 911일 · 통제총계 911건 전수 일치.
--      ⇒ INFORMATION_SCHEMA 로 샤드를 열거할 대상이 사라졌다.
--
--    🔴 **이 매크로는 살아 있는 동안 라이브 지뢰였다.** 패턴이 `UPPER(table_name) LIKE 'EVENTS\_%'`
--      이므로 통합 테이블 `EVENTS`(뒤에 언더스코어 없음)를 **매칭하지 못하고**, 빈 레거시 샤드
--      `events_20260501`·`events_20260719`(둘 다 0행)만 잡았다. 그 상태로 `dbt run` 을 돌리면
--      pre-hook TRUNCATE 후 **0행 append** 로 끝나고 **에러가 나지 않는다** ⇒ SILVER·GOLD 가
--      조용히 비워진다. 실제로 `SILVER.GA4_EVENT` 8,161,106행이 이 경로로 소실될 상태였다.
--      ⇒ 🔴 **되살리지 마라.** 되살리려면 먼저 위 패턴 불일치를 이해했음을 확인할 것.
--
--    대체 경로 = `{{ source('bronze_bigquery','EVENTS') }}` + `WHERE EVENT_DT BETWEEN var(...)`.
--      정본 = `models/silver/ga4/BIGQUERY_REFINED_DATA.sql` · 설계 = `04_silver_design/07` 머리말.
--    ⚠️ 종전 var `ga4_start`/`ga4_end`(YYYYMMDD)도 함께 폐기됐다 → `ga4_dt_start`/`ga4_dt_end`(DATE).
--
-- ────────────────────────────────────────────────────────────────────────────
-- 이하 본문은 **역사 기록**이다(실행 경로 없음).
--
-- GA4 date-shard 동적 UNION 매크로 (dbt_utils.get_relations_by_pattern 대체, trial EAI 불가 대응)
-- Co-authored with CoCo
-- ⚠️ 설계결정서 §2: SELECT * 금지 → 컬럼명 명시(위치기반 오염 차단, SILVER 출력 스키마 고정)
-- ⚠️ 컬럼 추가 시 본 매크로 + SILVER DDL 동시 갱신(자동 전파 차단 = 의도된 설계)
--
-- 🔄 [2026-08-14 스키마 개명] 물리 스키마 `GN_DW.BRONZE_GA4` → `GN_DW.BRONZE_BIGQUERY`
--    (`ALTER SCHEMA BRONZE_GA4 RENAME TO BRONZE_BIGQUERY;` 실행 완료).
--    왜: 이 BRONZE 스키마의 원천은 GA4 제품이 아니라 **BigQuery export**이며, GA4 외 BigQuery 유입도
--        수용할 수 있도록 원천 시스템(BigQuery) 기준 명명으로 통일했다.
--    ⚠️ 개명된 것은 **스키마명뿐**이다 — 매크로명 `ga4_union_shards`·모델명 `GA4_*`·샤드
--        테이블명 `events_YYYYMMDD`·SILVER 산출 객체명은 모두 불변(GA4 = 데이터 도메인 명칭).
--    ⚠️ INFORMATION_SCHEMA 동적 조회이므로 아래 `table_schema` 리터럴이 유일한 결합점이다.
--        스키마가 다시 개명되면 이 한 줄과 §FROM 절(둘 다) 을 반드시 함께 고칠 것.
--    이력 정본: `10_dbt_pipeline/README.md` §5 스키마 개명 이력.
{% macro ga4_union_shards(start_date, end_date) %}
  {% set q %}
    -- ⚠️ 샤드 테이블명이 소문자 인용식별자("events_YYYYMMDD")로 저장될 수 있어 대소문자 무관 매칭 필수.
    SELECT table_name
    FROM {{ target.database }}.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'BRONZE_BIGQUERY'
      AND UPPER(table_name) LIKE 'EVENTS\\_%' ESCAPE '\\'
      AND REPLACE(UPPER(table_name),'EVENTS_','') BETWEEN '{{ start_date }}' AND '{{ end_date }}'
    ORDER BY table_name
  {% endset %}
  {% if execute %}
    {% set tabs = run_query(q).columns[0].values() %}
    {% if tabs | length == 0 %}
      -- 범위 내 shard 없음: 스키마 유지용 빈 결과 (컬럼명 명시)
      SELECT
        NULL::VARCHAR      AS event_date,
        NULL::NUMBER       AS event_timestamp,
        NULL::VARCHAR      AS event_name,
        NULL::VARIANT      AS event_params,
        NULL::VARCHAR      AS user_id,
        NULL::VARCHAR      AS user_pseudo_id,
        NULL::VARIANT      AS device,
        NULL::VARIANT      AS geo,
        NULL::VARIANT      AS traffic_source,
        NULL::VARIANT      AS collected_traffic_source,
        NULL::VARIANT      AS session_traffic_source_last_click,
        NULL::VARCHAR      AS platform,
        NULL::BOOLEAN      AS is_active_user,
        NULL::NUMBER       AS batch_ordering_id
      WHERE 1=0
    {% else %}
      {% for t in tabs %}
        -- ⚠️ BRONZE_BIGQUERY 컬럼도 소문자 인용식별자로 저장됨 → "col" AS COL 로 참조/승격(하류는 unquoted 대문자 참조).
        SELECT
          "event_date"                        AS event_date,
          "event_timestamp"                   AS event_timestamp,
          "event_name"                        AS event_name,
          "event_params"                      AS event_params,       -- VARIANT: LATERAL FLATTEN은 모델에서
          "user_id"                           AS user_id,            -- ⚠️VARCHAR 필수(선행0·S접두 보존)
          "user_pseudo_id"                    AS user_pseudo_id,
          "device"                            AS device,
          "geo"                               AS geo,
          "traffic_source"                    AS traffic_source,
          "collected_traffic_source"          AS collected_traffic_source,
          "session_traffic_source_last_click" AS session_traffic_source_last_click,
          "platform"                          AS platform,
          "is_active_user"                    AS is_active_user,
          "batch_ordering_id"                 AS batch_ordering_id
        FROM {{ target.database }}.BRONZE_BIGQUERY."{{ t }}"
        {% if not loop.last %}UNION ALL{% endif %}
      {% endfor %}
    {% endif %}
  {% endif %}
{% endmacro %}
