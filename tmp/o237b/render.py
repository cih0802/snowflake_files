# dbt 모델을 jinja2 로 렌더(ref → GN_DW.<SCHEMA>.<NAME>) — 읽기 전용 검증용(dbt 미실행)
import sys, re, jinja2
from snowflake.snowpark import Session
import os
SCH = {}
def ref(n):
    return SCH[n]
macros = {
 'month_key_offset': lambda mk, n: f"CASE WHEN MOD({mk}, 100) BETWEEN 1 AND 12 AND {mk} >= 100001 THEN TRY_TO_NUMBER(TO_CHAR(ADD_MONTHS(TRY_TO_DATE(TO_VARCHAR({mk}) || '01', 'YYYYMMDD'), {n}),'YYYYMM')) END",
 'month_key_clamp': lambda mk: f"CASE WHEN {mk} BETWEEN 194501 AND 214512 THEN {mk} END",
 'gold_meta': lambda s='CRM': f"'{s}' AS DW_SOURCE_SYSTEM",
 'config': lambda **k: '',
}
def render(path, sch):
    SCH.update(sch)
    t = jinja2.Environment().from_string(open(path, encoding='utf-8').read())
    return t.render(ref=ref, **macros)
if __name__ == '__main__':
    print(render(sys.argv[1], {})[:100])
