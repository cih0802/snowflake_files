-- gn_biz_codes: 업무 코드 목록·판정 술어의 단일 정의 지점 (MM015 개발구분 · 납부상태 · 미납중단 사유명)
-- Co-authored with CoCo
{#
  🆕 [2026-10-15 O-HC] 하드코딩 전수검토 후속 — 여러 모델에 흩어져 있던 리터럴을 여기로 모았다.
    🔴 값은 종전 리터럴과 **동일**하다(행동 변경 0). 값을 바꾸면 전 하류가 함께 바뀐다 ⇒ 의도한 변경만 여기서 한다.
    🔴 코드 목록을 바꾸는 변경은 「전량 재적재 의무」가 붙는다(GOLD fact = TRUNCATE 재적재라 build 1회로 충족).

  사용:
    DVLP_DIV_CD in ({{ gn_code('DEV_RECOGNIZED') }})
    DVLP_DIV_CD = {{ gn_code('DEV_INCREASE') }}
    {{ gn_is_unpaid('b.PAY_STAT_CD') }}
    {{ gn_is_unpaid_stop_reason('s.DSCNTC_RSN_NM') }}
#}

{% macro gn_code(key) -%}
  {%- set codes = {
      'DEV_NEW':         ['1'],
      'DEV_INCREASE':    ['2'],
      'DEV_DECREASE':    ['3'],
      'DEV_REDONATE':    ['4'],
      'DEV_STOP':        ['5'],
      'DEV_RECOGNIZED':  ['1', '2', '4'],
      'MSTR_B1':         ['1', '4'],
      'MSTR_B2_NET':     ['2', '3'],
      'MSTR_B2_BASE':    ['2', '3', '5'],
      'PAY_FAIL':        ['F'],
  } -%}
  {%- if key not in codes -%}
    {{ exceptions.raise_compiler_error("gn_code: 미정의 키 '" ~ key ~ "' — macros/gn_biz_codes.sql 에 등록하라") }}
  {%- endif -%}
  {%- set quoted = [] -%}
  {%- for c in codes[key] -%}{%- do quoted.append("'" ~ c ~ "'") -%}{%- endfor -%}
  {{ quoted | join(', ') }}
{%- endmacro %}

{# 미납 청구행 = 납부상태 F(실패) 또는 미기록(NULL) — DEC-3 · DEC-4 #}
{% macro gn_is_unpaid(col) -%}
  ({{ col }} = {{ gn_code('PAY_FAIL') }} OR {{ col }} IS NULL)
{%- endmacro %}

{# 미납중단 = 중단사유명에 「미납」 포함 — DEC-54 (코드 목록이 아니라 사유명 술어로 판정) #}
{% macro gn_is_unpaid_stop_reason(col) -%}
  {{ col }} like '%미납%'
{%- endmacro %}
