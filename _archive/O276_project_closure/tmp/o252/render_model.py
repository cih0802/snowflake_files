import sys
src = '/workspace/10_dbt_pipeline/models/gold/dim/DIM_ORG_SUCCESSION.sql'
out = '/workspace/tmp/o252/render_DIM_ORG_SUCCESSION.sql'
s = open(src, encoding='utf-8').read()
s = s[s.index('with recursive'):]
rep = {
    "{{ ref('CRM_ORG') }}": "GN_DW.SILVER.CRM_ORG",
    "{{ ref('DIM_ORG') }}": "GN_DW.GOLD.DIM_ORG",
    "{{ ref('CRM_MEMBER_DEV') }}": "GN_DW.SILVER.CRM_MEMBER_DEV",
    "{{ ref('CRM_MEMBER_SPONSOR_SPAN') }}": "GN_DW.SILVER.CRM_MEMBER_SPONSOR_SPAN",
    "{{ ref('ORG_SUCCESSION_MANUAL') }}": sys.argv[1] if len(sys.argv) > 1 else
        "(select NULL::varchar OLD_DEPT_ID, NULL::varchar CUR_DEPT_ID, NULL::varchar CONFIRMED_BY,"
        " NULL::varchar CONFIRMED_DT, NULL::varchar NOTE where 1=0)",
    "{{ gold_sk(['c.DEPT_ID']) }}": "ABS(HASH(COALESCE(CAST(c.DEPT_ID AS VARCHAR),'∅')))",
    "{{ min_lift }}": "3",
    "{{ min_evd }}": "30",
    "{{ gold_meta('CRM') }}": "'CRM' AS DW_SOURCE_SYSTEM, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_LOAD_TS,"
        " CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_UPDATE_TS, 'o252' AS DW_BATCH_ID",
}
for k, v in rep.items():
    s = s.replace(k, v)
assert '{{' not in s and '{%' not in s, 'unrendered jinja'
open(out, 'w', encoding='utf-8').write('CREATE OR REPLACE TEMPORARY TABLE GN_DW.PUBLIC.TMP_O252_MODEL AS\n' + s)
print('OK', len(s))
