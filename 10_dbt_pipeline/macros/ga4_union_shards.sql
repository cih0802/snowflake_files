-- GA4 date-shard 동적 UNION 매크로 (dbt_utils.get_relations_by_pattern 대체, trial EAI 불가 대응)
-- Co-authored with CoCo
-- ⚠️ 설계결정서 §2: SELECT * 금지 → 컬럼명 명시(위치기반 오염 차단, SILVER 출력 스키마 고정)
-- ⚠️ 컬럼 추가 시 본 매크로 + SILVER DDL 동시 갱신(자동 전파 차단 = 의도된 설계)
{% macro ga4_union_shards(start_date, end_date) %}
  {% set q %}
    -- ⚠️ 샤드 테이블명이 소문자 인용식별자("events_YYYYMMDD")로 저장될 수 있어 대소문자 무관 매칭 필수.
    SELECT table_name
    FROM {{ target.database }}.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'BRONZE_GA4'
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
        -- ⚠️ BRONZE_GA4 컬럼도 소문자 인용식별자로 저장됨 → "col" AS COL 로 참조/승격(하류는 unquoted 대문자 참조).
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
        FROM {{ target.database }}.BRONZE_GA4."{{ t }}"
        {% if not loop.last %}UNION ALL{% endif %}
      {% endfor %}
    {% endif %}
  {% endif %}
{% endmacro %}
