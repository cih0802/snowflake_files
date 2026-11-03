import io, re, sys
sys.path.insert(0, '/workspace/scripts')
from run_sql_file import parse_statements
NAME = re.compile(r'SEMANTIC\s+VIEW\s+GN_DW\.\w+\.(\w+)', re.I)


def svs(path):
    out = {}
    for s in parse_statements(io.open(path, encoding='utf-8').read()):
        body = '\n'.join(l for l in s.split('\n') if not l.strip().startswith('--'))
        if re.search(r'CREATE\s+OR\s+(ALTER|REPLACE)\s+SEMANTIC\s+VIEW', body, re.I):
            out[NAME.search(body).group(1)] = re.sub(r'\s+', ' ', body).strip()
    return out


a = svs('/workspace/05_SV-Agent_ai/34_DEPLOY_SV_ML_FALLBACK_NOTE.sql')
for f in ('22_ML_SV_DDL.sql', '25_ML_CHURN_CMPGN_CTGR_DDL.sql'):
    b = svs('/workspace/05_SV-Agent_ai/' + f)
    for k in a:
        if k in b:
            same = a[k] == b[k]
            print(f, k, 'SAME' if same else 'DIFF', len(a[k]), len(b[k]))
            if not same:
                i = next(i for i, (x, y) in enumerate(zip(a[k], b[k])) if x != y)
                print('   34 :', a[k][max(0, i - 80):i + 160])
                print('   ' + f[:2] + ' :', b[k][max(0, i - 80):i + 160])
