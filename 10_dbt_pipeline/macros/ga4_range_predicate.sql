-- ga4_range_predicate: GA4 적재 범위 술어의 단일 정의 지점 (2026-08-19 O88 신설)
-- Co-authored with CoCo
{#
  왜 이 매크로가 필요한가 — 두 가지 결함을 동시에 닫는다.

  ① 🔴 **같은 것을 다르게 재는 지점이 3곳이었다**(지침 `R1-6-17` 축).
     O87 이 범위 술어를 pre-hook DELETE·BASIC·EVENT 에 **각각 하드코딩**했다.
     세 술어는 **반드시 동일해야 멱등**이다 — DELETE 범위와 append 범위가 어긋나면
     행이 남거나(중복) 사라진다(누락). 그런데 어긋남을 잡는 게이트가 **없었다**.
     ⇒ 정의 지점을 이 파일 하나로 만들면 그 불일치가 **구조적으로 불가능**해진다.

  ② 🔴 **불연속 구간을 표현할 수 없었다**(종전 var 는 연속 구간 1개뿐).

  ─────────────────────────────────────────────────────────────────────────────
  🔄🔄 [2026-09-22] **고정 리터럴 창 → 롤링 윈도우(일일 증분)로 전환.**

  왜 바꿨나
    종전에는 `ga4_dt_ranges` 에 리터럴 구간을 박아 두고 **매 run 그 범위 전량을 재적재**했다.
    그 방식은 두 가지를 동시에 틀리게 만들었다.
      · 🔴 **이중 샘플링** — 원천(`SILVER.BIGQUERY_REFINED_DATA`)의 스코프와 이 창이
        **둘 다** 범위를 좁혔다. 실측: 6월 창 3개 ∩ 원천 33개 샘플 날짜 = **3일**
        ⇒ BASIC→EVENT→GOLD 전 하류가 3일치로 잘려 있었다(에러 0 · 무증상).
      · 🔴 **매 run 전량 재적재** — 전일자 환산 GA4 체인 ≈ 28분(실측 33일 61초 × 27.6).
        일일 배치에서 이미 적재된 과거를 매일 다시 만드는 순수 낭비다.

  🔴 **스코프 결정 지점은 원천 적재(외부 Python) 한 곳이다.**
     dbt 는 「원천에 있는 것을 전량 하류로 흘린다」가 원칙이고, 이 매크로가 정하는 것은
     **범위가 아니라 "이번 run 이 다시 만들 구간"** 뿐이다. 둘을 혼동하면 ①이 재발한다.

  3가지 모드 (우선순위 순)
    ⓐ `ga4_dt_ranges` var 가 **주어지면** 그 구간 목록을 쓴다 — **백필 전용 수동 오버라이드**.
       🔴 `dbt_project.yml` 에 이 값을 **상주시키지 말 것**(그것이 ①의 원인이었다).
          🟢 주는 법 = `dbt_project.yml` `vars` 의 **주석 슬롯을 일시적으로 풀고** 구간을 적어
             `dbt build --select <모델>+` → 끝나면 **다시 주석 처리**한다.
          🔴🔴 **`--vars` 로 주지 마라 — 이 환경에서 동작하지 않는다**(실측 2026-09-22 · 3형태 전부 실패).
             특히 `--vars {ga4_dt_ranges:[...]}` 는 **에러 없이 조용히 무시된다**(콜론 뒤 공백이 없어
             YAML 이 키 하나로 파싱한다) ⇒ **백필한 줄 알고 넘어간다.** 실측 근거 = `dbt_project.yml` vars 주석.
             🟢 판정식 = 오버라이드는 「전달됐다」가 아니라 **「렌더된 창이 바뀌었다」**로 확인한다.
    ⓑ `is_incremental()` 이 **아니면**(최초 run · 대상 테이블 미존재) **전량**을 적재한다.
       ⇒ 첫 빌드가 창 크기만큼만 적재되는 사고를 구조적으로 막는다.
       ⚠️ SILVER·GOLD 는 `full_refresh: false` 다 ⇒ `--full-refresh` 로 전량 재적재할 수 없다.
          전량 재적재 경로는 ⓐ 하나다(그래서 ⓐ를 지운 게 아니라 **상주만 끊었다**).
    ⓒ 그 밖(평시 일일 run) = **롤링 윈도우** `[오늘 - ga4_lookback_days, 열린 상한]`.

  🔴🔴 왜 워터마크(`MAX(EVENT_DT) FROM this`)를 쓰지 않는가 — **트랩이 있다.**
     pre-hook DELETE 가 먼저 돌아 최근 일자를 지우므로, 그 뒤 모델 SELECT 가 같은
     서브쿼리를 평가하면 **MAX 가 달라진다** ⇒ DELETE 범위 ≠ append 범위 = ①의 재발.
     `run_started_at` 기반 리터럴은 run 전체에서 **불변**이라 그 불일치가 불가능하다.
     (그래서 창의 기준을 "데이터 상태" 가 아니라 "run 시각" 으로 잡았다.)

  🟢 상한을 열어 두는(9999-12-31) 이유 — 미래 일자가 조용히 누락되지 않게 한다.
     GA4 는 UTC/로컬 경계에서 오늘+1 이 섞일 수 있고, 상한을 오늘로 닫으면 그 행이
     **영구히** 안 들어온다(다음 run 에서는 창 아래로 밀려나므로).

  ⚠️ lookback 은 「지연 도착 방어」가 아니다 — 원천은 **지연 도착 종료 후 동결된 데이터**가
     들어온다(사용자 확인 2026-09-22). 이 값의 실제 역할은 **부분 적재·중단된 run 재처리**다.
     🔴 run 을 lookback 일수보다 오래 건너뛰면 **창 아래에 구멍이 남는다.** 그 구멍을
        막는 것은 lookback 을 키우는 것이 아니라 `tests/warn_ga4_load_gap.sql` 이다
        (원천에 있고 하류에 없는 일자를 감시 ⇒ 무증상 누락을 시끄럽게 만든다).

  🟢 프루닝은 유지된다 — 리터럴 범위 비교의 OR 이므로 Snowflake 가 마이크로파티션을
     프루닝한다. `TO_CHAR(EVENT_DT,'YYYYMM') IN (...)` 같은 함수 적용 형태를 쓰지 않는
     이유가 이것이다(그것은 프루닝을 깬다).

  3가지 렌더러 — **컬럼의 물리 타입이 3종이라서** 필요하다. 창 계산은 `ga4_load_window()`
  하나이고 렌더러는 그것을 각 타입의 리터럴로만 옮긴다(여기에 창 로직을 다시 쓰지 마라).
    · `ga4_range_predicate(col)`      DATE            예: `EVENT_DT`  · `b.EVENT_DT`
    · `ga4_range_predicate_text(col)` VARCHAR(8)      예: `EVENT_DATE` (원천 TEXT YYYYMMDD)
    · `ga4_range_predicate_sk(col)`   NUMBER(8)       예: `DATE_SK`    (GOLD 팩트 YYYYMMDD)
    🔴 TEXT 는 `TO_DATE()` 로 감싸지 않는다 — 사전순=시간순이라 문자열 비교라야 프루닝이
       유지된다(함수를 적용하면 깨진다 · `20_issue/02_...-007.md:102`).
#}

{#- 창 계산의 단일 지점. 반환 = [[시작,종료], ...] (ISO 'YYYY-MM-DD') 또는 none(=전량) -#}
{% macro ga4_load_window() %}
  {%- set override = var('ga4_dt_ranges', []) -%}

  {#- ⓐ 수동 백필 오버라이드 -#}
  {%- if override | length > 0 -%}
    {%- for r in override -%}
      {%- if r | length != 2 -%}
        {{ exceptions.raise_compiler_error(
             "ga4_dt_ranges 의 각 원소는 [시작일, 종료일] 2개여야 한다. 받은 값: " ~ r) }}
      {%- endif -%}
    {%- endfor -%}
    {{ return(override) }}

  {#- ⓑ 최초 run(대상 테이블 미존재) = 전량 -#}
  {%- elif not is_incremental() -%}
    {{ return(none) }}

  {#- ⓒ 평시 = 롤링 윈도우 -#}
  {%- else -%}
    {%- set lookback = var('ga4_lookback_days', 3) | int -%}
    {%- if lookback < 0 -%}
      {{ exceptions.raise_compiler_error(
           "ga4_lookback_days 는 0 이상이어야 한다. 받은 값: " ~ lookback) }}
    {%- endif -%}
    {%- set floor_dt = run_started_at.date() - modules.datetime.timedelta(days=lookback) -%}
    {{ return([[floor_dt.strftime('%Y-%m-%d'), '9999-12-31']]) }}
  {%- endif -%}
{% endmacro %}


{#- DATE 컬럼용 -#}
{% macro ga4_range_predicate(col='EVENT_DT') %}
  {%- set w = ga4_load_window() -%}
  {%- if w is none -%}
    TRUE /* ga4_range_predicate: 최초 run ⇒ 전량 적재 */
  {%- else -%}
  (
    {%- for r in w %}
    {% if not loop.first %}OR {% endif %}({{ col }} >= TO_DATE('{{ r[0] }}') AND {{ col }} <= TO_DATE('{{ r[1] }}'))
    {%- endfor %}
  )
  {%- endif -%}
{%- endmacro %}


{#- VARCHAR(8) 'YYYYMMDD' 컬럼용 (원천 TEXT · 프루닝 보존) -#}
{% macro ga4_range_predicate_text(col='EVENT_DATE') %}
  {%- set w = ga4_load_window() -%}
  {%- if w is none -%}
    TRUE /* ga4_range_predicate_text: 최초 run ⇒ 전량 적재 */
  {%- else -%}
  (
    {%- for r in w %}
    {% if not loop.first %}OR {% endif %}({{ col }} between '{{ r[0] | replace('-','') }}' and '{{ r[1] | replace('-','') }}')
    {%- endfor %}
  )
  {%- endif -%}
{%- endmacro %}


{#- NUMBER(8) YYYYMMDD 컬럼용 (GOLD 팩트 DATE_SK) -#}
{% macro ga4_range_predicate_sk(col='DATE_SK') %}
  {%- set w = ga4_load_window() -%}
  {%- if w is none -%}
    TRUE /* ga4_range_predicate_sk: 최초 run ⇒ 전량 적재 */
  {%- else -%}
  (
    {%- for r in w %}
    {% if not loop.first %}OR {% endif %}({{ col }} between {{ r[0] | replace('-','') }} and {{ r[1] | replace('-','') }})
    {%- endfor %}
  )
  {%- endif -%}
{%- endmacro %}
