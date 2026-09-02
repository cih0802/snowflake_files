-- ga4_range_predicate: GA4 적재 범위 술어의 단일 정의 지점 (2026-08-19 O88 신설)
-- Co-authored with CoCo
{#
  왜 이 매크로가 필요한가 — 두 가지 결함을 동시에 닫는다.

  ① 🔴 **같은 것을 다르게 재는 지점이 3곳이었다**(지침 `R1-6-17` 축).
     O87 이 범위 술어를 아래 **세 곳에 각각 하드코딩**했다:
       · `macros/ga4_range_purge.sql`                (pre-hook DELETE 범위)
       · `models/silver/ga4/BIGQUERY_REFINED_DATA.sql` (src CTE WHERE)
       · `models/silver/ga4/BIGQUERY_EVENT.sql`             (최종 SELECT WHERE)
     세 술어는 **반드시 동일해야 멱등**이다 — DELETE 범위와 append 범위가 어긋나면
     행이 남거나(중복) 사라진다(누락). 그런데 어긋남을 잡는 게이트가 **없었다**.
     두 모델 파일이 스스로 *"pre-hook DELETE 범위와 동일해야 멱등이다"* 라고 적어 두었지만,
     그 동일성은 **사람이 세 파일을 맞춰 고치는 것에만** 의존했다.
     ⇒ 정의 지점을 이 매크로 하나로 만들면 그 불일치가 **구조적으로 불가능**해진다.
     같은 처방의 선례 = `macros/silver_purge.sql`(pre-hook 정의 지점 단일화 · O87).

  ② 🔴 **불연속 월 샘플링을 표현할 수 없었다**.
     종전 var 는 `ga4_dt_start`/`ga4_dt_end` **연속 구간 1개**뿐이라
     「2024-06 · 2025-06 · 2026-06 3개월만」을 표현할 방법이 없었다.
     그 상태로 `2024-06-01`~`2026-06-30` 을 주면 **2년치 전량**을 읽는다 = 샘플링 실패이고
     비용 방어선(dbt_project.yml `vars` 주석)이 무력화된다.
     ⇒ var 를 **구간 목록**(`ga4_dt_ranges`)으로 바꾸고 이 매크로가 OR 로 전개한다.

  출력 형태
    ( (<col> >= TO_DATE('2024-06-01') AND <col> <= TO_DATE('2024-06-30'))
   OR (<col> >= TO_DATE('2025-06-01') AND <col> <= TO_DATE('2025-06-30')) )

  🟢 프루닝은 유지된다 — `EVENT_DT` 에 대한 리터럴 범위 비교의 OR 이므로
     Snowflake 가 구간별로 마이크로파티션을 프루닝한다. `TO_CHAR(EVENT_DT,'YYYYMM') IN (...)`
     같은 함수 적용 형태를 쓰지 않는 이유가 이것이다(그것은 프루닝을 깬다).

  인자
    col — 술어를 걸 컬럼 표현식. 별칭이 있으면 함께 준다(예: `'b.EVENT_DT'`).
          기본값 `'EVENT_DT'` = 별칭 없는 참조(pre-hook DELETE · source CTE).

  🔴 빈 목록은 **컴파일 실패**로 만든다.
     빈 목록을 「전 범위」로 해석하면 var 오타 하나가 2.86억행 전량 스캔이 된다
     (조용한 비용 사고). 범위 없이 돌릴 이유는 없으므로 fail-fast 가 맞다.
#}
{% macro ga4_range_predicate(col='EVENT_DT') %}
  {%- set ranges = var('ga4_dt_ranges', []) -%}
  {%- if ranges | length == 0 -%}
    {{ exceptions.raise_compiler_error(
         "ga4_dt_ranges 가 비어 있다. dbt_project.yml vars 또는 --vars 로 "
         ~ "[['YYYY-MM-DD','YYYY-MM-DD'], ...] 형식의 구간 목록을 반드시 지정하라. "
         ~ "빈 목록을 전 범위로 해석하지 않는 것은 의도다(2.86억행 전량 스캔 차단)."
       ) }}
  {%- endif -%}
  (
  {%- for r in ranges %}
    {% if not loop.first %}OR {% endif %}({{ col }} >= TO_DATE('{{ r[0] }}') AND {{ col }} <= TO_DATE('{{ r[1] }}'))
  {%- endfor %}
  )
{%- endmacro %}
