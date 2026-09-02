{#
  silver_purge — SILVER 계층 pre-hook 단일 진입점 (2026-08-19 O87 신설)

  🔴🔴 왜 매크로 1개로 합치는가 — dbt 는 hook 을 **누적(append)** 한다.
     프로젝트 레벨 `silver: +pre-hook: TRUNCATE ...` 와 모델 레벨 `config(pre_hook=...)` 를
     함께 두면 **둘 다 실행된다**(더 구체적인 설정이 덮어쓰는 것이 아니다).
     ⇒ GA4 range 모델에 범위 DELETE 를 달아도 그 앞에서 TRUNCATE 가 먼저 돌아
     **전체 테이블이 비워진 뒤 범위만 append** 된다 = 월 단위 분할 적재가 조용히 망가진다.
     이 사고는 에러를 내지 않는다(행수가 줄어들 뿐) ⇒ 구조로 막는다.
     ⇒ **pre-hook 정의 지점을 dbt_project.yml 의 `silver:` 한 곳으로 고정**하고,
       분기는 이 매크로 안에서만 한다. 모델 파일에는 pre_hook 을 쓰지 않는다.

  분기 규칙
    · range 모델(EVENT_DT 보유) → `ga4_range_purge`: var 범위만 DELETE ⇒ 범위 단위 멱등.
    · 그 밖의 SILVER 전 모델      → 종전과 동일한 `TRUNCATE TABLE IF EXISTS`(전량 재적재).

  ⚠️ 아래 RANGED_MODELS 는 **모델명을 문자열로 아는 유일한 지점**이다(`R1-6-17` 「같은 것을
     다르게 재는 지점」 축). 모델을 추가·개명하면 여기도 고쳐야 하고, 빠뜨리면
     그 모델은 조용히 TRUNCATE 경로로 돌아간다.
     ⇒ 그래서 대상 모델 파일 주석에도 「pre-hook 은 silver_purge 가 분기한다」를 적어 둔다.
     교차 검증 = `grep -n RANGED_MODELS macros/silver_purge.sql` ↔ 각 모델 헤더 주석.

  🔄 [2026-08-21] BIGQUERY_REFINED_DATA 를 목록에서 제거했다 — 더 이상 dbt 모델이 아니라
     외부 Python 파이프라인이 GN_DW.SILVER.BIGQUERY_REFINED_DATA 를 직접 적재·삭제 관리한다
     (이 매크로는 `this` = dbt 가 소유한 모델의 relation 에만 호출되므로 애초에 이 목록에
     남겨 둬도 호출되지 않지만, 죽은 항목을 지워 목록을 정본으로 유지한다).
  🔄 [2026-08-21] `BIGQUERY_BASIC` 을 추가했다 — 그 외부 적재 테이블을 재파생하는 새 range 모델
     (EVENT_DT 보유). BIGQUERY_EVENT 와 동일하게 범위만 DELETE(멱등).
#}
{% macro silver_purge(relation) %}
  {%- set RANGED_MODELS = ['BIGQUERY_EVENT', 'BIGQUERY_BASIC'] -%}
  {%- if relation.identifier | upper in RANGED_MODELS -%}
    {{ ga4_range_purge(relation) }}
  {%- else -%}
    TRUNCATE TABLE IF EXISTS {{ relation }}
  {%- endif -%}
{% endmacro %}
