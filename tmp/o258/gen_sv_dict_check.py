# O258 · SV 리터럴 → BRONZE 코드사전 대조 SQL 생성
import io, csv
lits = [r['literal'] for r in csv.DictReader(io.open('/workspace/tmp/o258/sv_literals_distinct.csv', encoding='utf-8'))]
dbt_out = set()
for r in csv.DictReader(io.open('/workspace/tmp/o258/literals_dbt.csv', encoding='utf-8')):
    for v in r['literals'].split('|'):
        dbt_out.add(v)
esc = lambda s: s.replace("'", "''")
vals = ',\n'.join("('%s', %d)" % (esc(v), 1 if v in dbt_out else 0) for v in lits)
sql = """with l(v, in_dbt) as (select * from values
%s)
, dict as (
  select distinct trim(DTL_CD_NM) nm from GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD
  union select distinct trim(DTL_CD_NM) from GN_DW.BRONZE_CRM.TC_MKTNG_DTL_CD
)
select l.v, l.in_dbt, iff(d.nm is not null, 1, 0) in_dict
from l left join dict d on d.nm = l.v
order by in_dict, in_dbt, l.v""" % vals
io.open('/workspace/tmp/o258/sv_dict_check.sql', 'w', encoding='utf-8').write(sql)
print(len(lits))
