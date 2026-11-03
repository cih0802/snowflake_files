import io, re, sys
sys.path.insert(0, '/workspace/tmp/o261')
exec(open('/workspace/tmp/o261/cmp_34_22.py', encoding='utf-8').read().split("a = svs(")[0])
ITEM = re.compile(r"(\w+)\.(\w+)\s+AS\s+.*?COMMENT\s*=\s*'((?:[^']|'')*)'", re.I | re.S)


def items(t):
    return {m.group(2).upper(): m.group(3) for m in ITEM.finditer(t)}


a = svs('/workspace/05_SV-Agent_ai/34_DEPLOY_SV_ML_FALLBACK_NOTE.sql')
b = svs('/workspace/05_SV-Agent_ai/22_ML_SV_DDL.sql')
b.update(svs('/workspace/05_SV-Agent_ai/25_ML_CHURN_CMPGN_CTGR_DDL.sql'))
for k in a:
    ia, ib = items(a[k]), items(b[k])
    only34, only22 = set(ia) - set(ib), set(ib) - set(ia)
    diff = [n for n in set(ia) & set(ib) if ia[n] != ib[n]]
    print(k, 'items34', len(ia), 'items22', len(ib), 'only34', sorted(only34)[:8], 'only22', sorted(only22)[:8], 'commentDiff', len(diff))
    for n in diff[:3]:
        print('  ', n, '\n    34:', ia[n][:220], '\n    22:', ib[n][:220])
    for tok in ('ROLLUP', 'GROUPING SETS', '폴백', 'O259', 'O250', 'O245'):
        print('   tok', tok, '34=', a[k].upper().count(tok.upper()), '22=', b[k].upper().count(tok.upper()))
