-- =============================================================================
-- Purpose    : 업무 코드 목록·판정 술어의 단일 정의 지점 (MM015 개발구분 · 납부상태 · 미납중단 사유명)
-- Target     : macro gn_code, gn_is_unpaid, gn_is_unpaid_stop_reason, gn_evt_stat 외 3
-- Run order  : dbt 가 호출 (직접 실행 없음)
-- Depends on : -
-- Issue      : DEC-3, DEC-4, DEC-54, O232 외 1
-- =============================================================================
-- gn_biz_codes: 업무 코드 목록·판정 술어의 단일 정의 지점 (MM015 개발구분 · 납부상태 · 미납중단 사유명)
{#
   [2026-10-15 O-HC] 하드코딩 전수검토 후속 — 여러 모델에 흩어져 있던 리터럴을 여기로 모았다.
    WARN: 값은 종전 리터럴과 **동일**하다(행동 변경 0). 값을 바꾸면 전 하류가 함께 바뀐다 ⇒ 의도한 변경만 여기서 한다.
    WARN: 코드 목록을 바꾸는 변경은 「전량 재적재 의무」가 붙는다(GOLD fact = TRUNCATE 재적재라 build 1회로 충족).

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
      'EVT_MS006_APPLY':   ['1'],
      'EVT_MS006_ATTEND':  ['2'],
      'EVT_MS006_ABSENT':  ['3'],
      'EVT_MS006_WAIT':    ['4', '6'],
      'EVT_MS006_CANCEL':  ['5'],
      'EVT_MS006_CONFIRM': ['1', '2', '3'],
      'EVT_MS304_SUCCESS': ['110'],
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

{# [O232] 행사 참여상태 = **코드 기준**(종전 = 라벨 문자열 · 라벨이 바뀌면 조용히 0).
   실측(2026-10-15 jw08094 · SILVER.CRM_EVENT_PARTICIPATION) 코드 ↔ 라벨 1:1:
     MS006 1 신청 · 2 참여 · 3 불참 · 4 대기 · 5 취소 · 6 대기(결제) · MS304 110 Success
   ⇒ 전환 전후 결과 동일(라벨 기준 `LIKE '대기%'` = 코드 4·6). 그룹을 반드시 함께 건다(MS304 에도 코드 1~6 은 없지만 접두가 다른 체계다). #}
{% macro gn_evt_stat(grp_col, cd_col, key) -%}
  ({{ grp_col }} = 'MS006' AND {{ cd_col }} IN ({{ gn_code(key) }}))
{%- endmacro %}

{% macro gn_evt_attended(grp_col, cd_col) -%}
  ({{ gn_evt_stat(grp_col, cd_col, 'EVT_MS006_ATTEND') }} OR ({{ grp_col }} = 'MS304' AND {{ cd_col }} IN ({{ gn_code('EVT_MS304_SUCCESS') }})))
{%- endmacro %}

{# [O232] 처리통보성 발송 = 제목 키워드(O190 L-1① · 사용자 결정 §4 #6). 코드 대체 불가 — 발송유형 미매핑 3,040만 건(실측).
    [O232 사용자 결정] 「감사」 키워드 **제외** — 회원서비스 「장기회원감사서비스(사단)」 발송까지 처리통보로 빠졌다(121,936건).
     ⇒ 키워드 = 「미납·중단」 2종 · 제외 대상 1,466,182 → 483,867건(실측) · 982,315건이 D5 귀속으로 복귀.
     WARN: 「증액 후원감사 알림톡」(증액 결과 통보 · DEC-33 역인과 사례 30-016:260)도 함께 귀속된다 — D5 는 인과가 아니라 시간창 매칭이다. #}
{% macro gn_is_notice_title(col) -%}
  COALESCE(REGEXP_LIKE({{ col }}, '.*(미납|중단).*'), FALSE)
{%- endmacro %}

{# [O232] ERP 예산 원장의 합계 행 표지 — 원천 BRONZE 에 현재 0건(실측 = 「지출」 405행뿐) · 방어 필터로 유지 #}
{% macro gn_erp_not_total(col) -%}
  {{ col }} <> 'TOTAL'
{%- endmacro %}
