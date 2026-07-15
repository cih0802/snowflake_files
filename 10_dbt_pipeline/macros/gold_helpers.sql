-- GOLD 공통 매크로: 해시 대리키·감사메타·날짜키 (dbt_utils 대체, trial EAI 불가 대응)
-- Co-authored with CoCo

-- 해시 대리키(_SK): 비즈니스키 컬럼들로 결정적 SK 생성.
--   유지보수·인수인계 유리 — 무상태(시퀀스 객체 불필요)·재현성·병렬안전·재빌드 시 값 불변.
--   SCD2 차원은 cols 에 EFFECTIVE_FROM 을 포함해 버전별 유일 SK 보장.
--   NULL 키 안정화: 각 컬럼을 COALESCE 후 구분자로 결합해 해시(널·경계 충돌 방지).
{% macro gold_sk(cols) -%}
    ABS(HASH(
        {%- for c in cols -%}
            COALESCE(CAST({{ c }} AS VARCHAR), '∅')
            {%- if not loop.last %} || '‖' || {% endif -%}
        {%- endfor -%}
    ))
{%- endmacro %}

-- GOLD 공통 감사 4컬럼 — LOAD_TS=최초적재(merge 보존)·UPDATE_TS=최종적재(merge 갱신)·BATCH_ID=dbt run UUID
{% macro gold_meta(src_system='CRM') -%}
    '{{ src_system }}'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '{{ invocation_id }}'                    AS DW_BATCH_ID
{%- endmacro %}

-- DATE_SK: YYYYMMDD NUMBER(8,0) (DIM_DATE 조인키). NULL 안전 + 캘린더 범위(cal_start~cal_end) 클램프.
--   범위 밖·NULL 은 NULL 반환 → fact 에서 COALESCE(date_sk(...),0) 로 DIM_DATE Unknown 멤버(0) 라우팅.
{% macro date_sk(date_col) -%}
    CASE WHEN {{ date_col }} BETWEEN '{{ var("cal_start") }}' AND '{{ var("cal_end") }}'
         THEN TRY_TO_NUMBER(TO_CHAR({{ date_col }}, 'YYYYMMDD')) END
{%- endmacro %}

-- MONTH_KEY: YYYYMM NUMBER(6,0) (월팩트 conform). NULL 안전.
{% macro month_key(date_col) -%}
    TRY_TO_NUMBER(TO_CHAR({{ date_col }}, 'YYYYMM'))
{%- endmacro %}

-- MONTH_KEY 검증 클램프: YYYYMM 후보(숫자)가 캘린더 범위(cal_start~cal_end 월)·월(01~12) 모두 유효할 때만 반환, 아니면 NULL.
--   → fact 에서 COALESCE(month_key_clamp(...), month_key_clamp(폴백), 0) 로 무효 월키를 Unknown(0) 라우팅.
--   순서9-B: MBRFEE_MT 등 소스 원값이 YYYYMM 아닌 쓰레기 숫자(실측 20251·210103 등 ~2,043행)를 TRY_TO_NUMBER 가 통과시켜
--            유령 월키 생성 + 정상 폴백 단락하던 문제 차단. date_sk 의 범위 클램프와 동일 철학(무효→0).
{% macro month_key_clamp(mk_num) -%}
    {%- set lo = var("cal_start")[:7] | replace("-", "") -%}
    {%- set hi = var("cal_end")[:7] | replace("-", "") -%}
    CASE WHEN {{ mk_num }} BETWEEN {{ lo }} AND {{ hi }}
          AND MOD({{ mk_num }}, 100) BETWEEN 1 AND 12
         THEN {{ mk_num }} END
{%- endmacro %}
