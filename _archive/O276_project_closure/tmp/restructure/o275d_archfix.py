import io, sys
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot
a = '10_design/12_silver_design/_archive/08_SILVER_테이블DDL_20260714.sql'
b = '10_design/12_silver_design/08_SILVER_테이블DDL_20260714.sql'
for f in ('doc_line_length_gate.py', 'o125_layer_census.py', 'table_ddl_column_gate.py'):
    p = f'/workspace/scripts/{f}'
    t = io.open(p, encoding='utf-8').read()
    assert t.count(a) == 1, f
    print(snapshot(p, 'pre-archfix', label='O275-D')[1])
    io.open(p, 'w', encoding='utf-8').write(t.replace(a, b))
    assert a not in io.open(p, encoding='utf-8').read()
import os; assert os.path.isfile('/workspace/' + b); print('ok')
