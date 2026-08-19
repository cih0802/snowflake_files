{#
  ga4_range_purge — EVENT_DT 범위 한정 멱등 purge (SILVER GA4 range 모델 전용 pre-hook)

  왜 필요한가 (2026-08-19 O87 신설)
    SILVER 기본 전략은 `pre-hook: TRUNCATE TABLE IF EXISTS {{ this }}` 다(dbt_project.yml).
    그것은 「매 run 전량 재적재」를 전제하므로 **월 단위 분할 적재와 상충**한다 —
    설계문서 `04_silver_design/07_GA4_SILVER_샤드통합 설계결정.md` §7-A 가 이미 경고했다:
      *"멱등 INSERT OVERWRITE 는 월 단위 분할 적재와 상충한다 — 월별로 돌리면 앞 달이 지워진다.
        전기간 적재 시 ① 한 번에 전량 OVERWRITE 또는 ② DELETE WHERE EVENT_DT + INSERT 로
        멱등성을 재설계할 것."*
    GA4 는 2.86억행이라 ① 이 현실적이지 않다(전기간 환산 ≈ 36분 + 하류). ⇒ **②를 채택한다.**

  동작
    `DELETE FROM <this> WHERE EVENT_DT BETWEEN var(ga4_dt_start) AND var(ga4_dt_end)`
    ⇒ 그 범위만 지우고 모델 SELECT 가 같은 범위를 append 하므로 **범위 단위 멱등**이다.
    범위 밖 데이터는 보존된다 ⇒ 월별 분할 적재가 안전해진다.

  🔴 적용 대상 = EVENT_DT 를 보유한 range 모델만이다.
     · BIGQUERY_REFINED_DATA · GA4_EVENT     → 이 매크로 사용
     · GA4_EVENT_DIM · GA4_DEVICE · GA4_TRAFFIC_SOURCE · GA4_IDENTITY
       → EVENT_DT 가 없는 **DISTINCT/집약 차원**이다. 범위 삭제가 불가능하고,
         범위 제한해서 만들면 **전기간 값 집합이 소실**된다(예: 특정 월에만 등장한 UTM).
         ⇒ 그 4종은 기본 TRUNCATE + 전량 재적재를 유지하고 기반 테이블 **전량**을 읽는다.

  ⚠️ 첫 run 에서는 대상 테이블이 없을 수 있다 — `DELETE` 는 IF EXISTS 를 못 쓰므로
     `is_incremental()` 이 아닐 때는 no-op SQL 을 낸다(TRUNCATE 와 달리 방어가 필요하다).
     테이블 구조는 `04_silver_design/08_SILVER_테이블DDL_20260714.sql` 이 선생성한다(순서 8-B).
#}
{% macro ga4_range_purge(relation) %}
  {%- if is_incremental() -%}
    DELETE FROM {{ relation }}
     WHERE EVENT_DT >= TO_DATE('{{ var("ga4_dt_start") }}')
       AND EVENT_DT <= TO_DATE('{{ var("ga4_dt_end") }}')
  {%- else -%}
    SELECT 1 /* ga4_range_purge no-op: 대상 테이블 미존재(최초 run) */
  {%- endif -%}
{% endmacro %}
