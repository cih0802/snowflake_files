{#
  gold_fact_purge — GOLD fact 계층 pre-hook 단일 진입점 (2026-09-22 신설)

  🔴🔴 왜 매크로가 필요한가 — `macros/silver_purge.sql` 과 **완전히 동일한 이유**다.
     dbt 는 hook 을 **누적(append)** 한다. `dbt_project.yml` 의 `gold.fact:` 에
     `+pre-hook: "TRUNCATE TABLE IF EXISTS {{ this }}"` 를 두고 모델 파일에
     범위 DELETE 를 추가하면 **둘 다 실행되어** 전체가 비워진 뒤 범위만 append 된다.
     ⇒ 팩트가 창 크기만큼으로 쪼그라든다. **에러가 나지 않는다**(행수만 줄어든다).
     silver_purge.sql:4-11 이 경계한 그 사고이며, GOLD fact 에는 그 방어가 없었다.
     ⇒ pre-hook 정의 지점을 `dbt_project.yml` 의 `fact:` 한 줄로 고정하고,
       분기는 이 매크로 안에서만 한다. **모델 파일에 `pre_hook` 을 쓰지 말 것.**

  분기 규칙
    · RANGED_FACTS (일자 SK 보유 · 범위 재적재) → `bigquery_range_predicate_sk` 범위 DELETE
    · 그 밖의 GOLD 전 팩트                      → 종전과 동일 `TRUNCATE TABLE IF EXISTS`

  ⚠️ 아래 RANGED_FACTS 는 **모델명을 문자열로 아는 유일한 지점**이다(`R1-6-17` 축).
     팩트를 추가·개명하면 여기도 고쳐야 하고, 빠뜨리면 그 팩트는 **조용히 TRUNCATE
     경로로 돌아간다**(= 매 run 전량 재적재로 회귀 · 결과는 맞지만 비용만 늘고 아무도 모른다).
     교차 검증 = `grep -n RANGED_FACTS macros/gold_fact_purge.sql` ↔ 각 모델 헤더 주석.

  🔴 범위 DELETE 를 팩트에 걸어도 되는 **전제 3가지**. 하나라도 깨지면 중복·누락이 된다.
     ① grain 에 일자 SK 가 포함될 것 — `FACT_BIGQUERY_BEHAVIOR` 는
        `DATE_SK × IDENTITY_SK × BIGQUERY_EVENT_SK × BIGQUERY_SOURCE_SK × DEVICE_SK
         × CAMPAIGN_SK × PAGE_PATH` 로 DATE_SK 가 첫 키다 ⇒ 일자별 재계산이 정확하다.
     ② 집계가 **일자를 넘나들지 않을 것** — `COUNT(DISTINCT …)` 류가 group by 에
        DATE_SK 를 포함하므로 한 일자 안에서 닫힌다(월간 유니크 같은 지표를 나중에
        추가하면 이 전제가 깨진다 ⇒ 그때는 이 목록에서 빼야 한다).
     ③ 🔴 **센티넬 `DATE_SK = 0` 버킷이 비어 있을 것.**
        `date_sk()` 는 DIM_DATE 범위 밖/NULL 을 NULL 로 클램프하고 팩트가
        `COALESCE(...,0)` 로 0 에 모은다. 0 은 어떤 창에도 속하지 않으므로
        **DELETE 되지 않는데 INSERT 는 된다** ⇒ 0 버킷이 run 마다 중복 누적된다
        (팩트는 append·unique_key 없음 = 막아 주는 것이 없다).
        실측(2026-09-22): `EVENT_DT IS NULL` 0건 · `DATE_SK = 0` 0건 이고
        DIM_DATE 범위(1945~2145)가 데이터(2024~2026)를 완전히 덮으므로 현재 구조적으로
        발생 불가다. 그 전제를 `tests/warn_gold_fact_bigquery_date_sk_zero.sql` 이 감시한다.
        🔄 [2026-09-22 O178] 종전 기재 `1991~2035`. 근거 부재 + 2036 클램프 절벽으로 확장했다
           (정본 = `dbt_project.yml` vars `cal_start`·`cal_end` · 여기는 인용이다).
#}
{% macro gold_fact_purge(relation) %}
  {%- set RANGED_FACTS = ['FACT_BIGQUERY_BEHAVIOR'] -%}
  {%- if relation.identifier | upper in RANGED_FACTS -%}
    {%- if is_incremental() -%}
      DELETE FROM {{ relation }}
       WHERE {{ bigquery_range_predicate_sk('DATE_SK') }}
    {%- else -%}
      SELECT 1 /* gold_fact_purge no-op: 대상 테이블 미존재(최초 run) — DELETE 는 IF EXISTS 를 못 쓴다 */
    {%- endif -%}
  {%- else -%}
    TRUNCATE TABLE IF EXISTS {{ relation }}
  {%- endif -%}
{% endmacro %}
