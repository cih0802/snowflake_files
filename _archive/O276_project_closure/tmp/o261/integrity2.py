import sys, glob, os, io
sys.path.insert(0, '/workspace/scripts')
from run_sql_file import parse_statements
bad = 0
for new in sorted(glob.glob('/workspace/05_SV-Agent_ai/*.sql')) + ['/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql']:
    old = '/workspace/tmp/o261/pre_fill/' + os.path.basename(new)
    a = io.open(old, encoding='utf-8').read()
    b = io.open(new, encoding='utf-8').read()
    if a == b:
        continue
    sa, sb = parse_statements(a), parse_statements(b)
    oq = sum(s.count("'") % 2 for s in sb)
    ok = len(sa) == len(sb) and oq == 0
    bad += not ok
    if not ok:
        print('BAD', os.path.basename(new), len(sa), '->', len(sb), 'odd', oq)
print('BAD', bad)
