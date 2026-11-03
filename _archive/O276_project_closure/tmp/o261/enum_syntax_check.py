"""O261 · SV DDL 파일의 CREATE SEMANTIC VIEW 문만 골라 컴파일 검증(EXPLAIN 불가 ⇒ 따옴표 짝 · 파서 분할 검사).
판정 = run_sql_file.parse_statements 로 분할한 문장 수가 스냅샷과 같고, 각 CREATE 문의 홑따옴표 수가 짝수.
"""
import sys, glob
sys.path.insert(0, '/workspace/scripts')
from run_sql_file import parse_statements

bad = 0
for path in [l.strip() for l in open('/workspace/tmp/o261/targets.txt', encoding='utf-8') if l.strip()]:
    name = path.split('/')[-1]
    new = open('/workspace/' + path, encoding='utf-8').read()
    old = open(glob.glob(f'/workspace/_archive/{name}.O261-preenum*')[0], encoding='utf-8').read()
    a, b = parse_statements(old), parse_statements(new)
    odd = sum(1 for s in b if s.count("'") % 2)
    ok = len(a) == len(b) and odd == 0
    bad += not ok
    print(('OK ' if ok else 'BAD'), name, 'stmts', len(a), '->', len(b), 'odd_quote', odd)
print('BAD_TOTAL', bad)
