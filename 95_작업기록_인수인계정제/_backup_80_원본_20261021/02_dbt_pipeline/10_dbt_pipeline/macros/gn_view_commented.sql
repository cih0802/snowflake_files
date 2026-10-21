-- [2026-08-07 O51-C] GOLD 뷰 컬럼 COMMENT 를 물리로 적용하는 커스텀 머티리얼라이제이션.
-- Co-authored with CoCo
--
-- 🔴 왜 필요한가 (실측 근거 2026-08-07)
--   Snowflake 에는 **뷰 컬럼 COMMENT 를 사후에 붙이는 경로가 없다.** 4변형 전부 실패:
--     · ALTER VIEW x ALTER  COLUMN c COMMENT '...'      → syntax error position 61 unexpected 'COMMENT'
--     · ALTER VIEW x ALTER  COLUMN c SET COMMENT '...'  → position 65
--     · ALTER VIEW x MODIFY COLUMN c COMMENT '...'      → position 62
--     · COMMENT ON COLUMN x.c IS '...'                  → "Object found is of type 'VIEW', not 'TABLE'"
--   문서 스펙상 ALTER VIEW 는 `SET COMMENT = '...'`(뷰 레벨)만 있고 컬럼에는 마스킹정책·태그만 걸린다.
--   ⇒ **유일 경로 = CREATE VIEW 의 컬럼 목록에 인라인 COMMENT.** probe 로 확인(2/2 반영).
--   ⚠️ dbt 내장 `persist_docs: {columns: true}` 도 `snowflake__alter_column_comment` 가 위 1번 형태를
--      쓰므로 **대안이 못 된다**(같은 이유로 실패). 그래서 생성문 자체를 바꾸는 이 방식이 필요하다.
--
-- 🔴 왜 전역 매크로 오버라이드가 아니라 커스텀 머티리얼라이제이션인가
--   O42 에서 `snowflake__process_schema_changes` 전역 오버라이드가 **Snowflake 서버측 dbt 런타임에서
--   발화하지 않았다**(워크스페이스·배포객체 양쪽). 발화하지 않는 가드는 거짓 안전 신호라 파일을 삭제했다.
--   본 파일은 dbt 내장 매크로를 **덮지 않는다** — 모델이 `materialized='gn_view_commented'` 로
--   **새 이름을 명시 호출**하므로 dispatch 경로가 다르다. 그래도 미검증이므로 뷰 1개로 probe 후 확대한다.
--
-- ⚠️⚠️ 사용 전제 (Snowflake 제약)
--   CREATE VIEW 에 컬럼 목록을 주면 **SELECT 의 전체 컬럼과 개수·순서가 정확히 일치해야 한다.**
--   부분 목록은 실패한다. ⇒ schema.yml 의 `columns:` 는 **전 컬럼을 SELECT 순서대로** 등재할 것.
--   `columns:` 가 아예 없으면 컬럼 목록을 생략하고 평범한 CREATE VIEW 로 동작한다(안전한 폴백).
--
-- 사용법:
--   {{ config(materialized='gn_view_commented') }}
--   + schema.yml 에 description 을 가진 columns: 전량 등재


{#- 컬럼 목록 + 인라인 COMMENT 절 생성. columns 미정의 시 빈 문자열 -#}
{% macro gn_view_column_list() %}
  {%- set cols = model.get('columns', {}) -%}
  {%- if cols | length > 0 -%}
    (
    {%- for _, c in cols.items() %}
      {{ c.name }}
      {%- if c.description %} COMMENT $${{ c.description | replace('$', '[$]') }}$${% endif %}
      {{- "," if not loop.last -}}
    {% endfor %}
    )
  {%- endif -%}
{% endmacro %}


{% materialization gn_view_commented, adapter='snowflake' %}

  {%- set target_relation = this.incorporate(type='view') -%}

  {{ run_hooks(pre_hooks) }}

  {%- set col_list = gn_view_column_list() -%}
  {%- set view_comment = model.get('description', none) -%}

  {% call statement('main') -%}
    create or replace view {{ target_relation }}
    {{ col_list }}
    {%- if view_comment %}
    comment = $${{ view_comment | replace('$', '[$]') }}$$
    {%- endif %}
    as (
      {{ sql }}
    );
  {%- endcall %}

  {{ run_hooks(post_hooks) }}

  {{ adapter.commit() }}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
