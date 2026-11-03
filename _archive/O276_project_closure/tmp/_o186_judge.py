import io, json, re, glob, os, collections
inv = collections.Counter(); rows=[]
for p in sorted(glob.glob('tmp/nlsmoke/AGENT_*.txt')):
    t = io.open(p, encoding='utf-8').read()
    try: d = json.loads(t)
    except Exception: d = None
    s = json.dumps(d, ensure_ascii=False) if d is not None else t
    ok = len(re.findall(r'"status"\s*:\s*"success"', s)); er = len(re.findall(r'"status"\s*:\s*"error"', s))
    tab = '"type": "table"' in s or '"type":"table"' in s
    ids = set(re.findall(r"invalid identifier '([^']+)'", s.replace('\\\\', '')))
    for i in ids: inv[(os.path.basename(p)[6:9], i)] += 1
    rows.append((os.path.basename(p)[:-4], ok, er, tab))
bad = [r for r in rows if not r[3]]
print('answers', len(rows), '· final table', sum(r[3] for r in rows), '· no table', [r[0] for r in bad])
print('with any error', sum(1 for r in rows if r[2]), '· recovered(error+table)', sum(1 for r in rows if r[2] and r[3]))
for (a,i),n in sorted(inv.items()): print('INV', a, i, n)
