import io, re, glob, datetime
rows = {}
for p in sorted(glob.glob('20_issue/00_INDEX_이슈원장_조각/*.md')):
    for i, s in enumerate(io.open(p, encoding='utf-8').read().split('\n'), 1):
        m = re.match(r'\|\s*\S*\s*\*\*`(O2\d\d)`\*\*', s)
        if m:
            d = re.search(r'\((20\d\d-\d\d-\d\d)', s)
            rows.setdefault(m.group(1), []).append((p.split('/')[-1], i, d.group(1) if d else None))
hist = set()
for p in glob.glob('20_issue/01_세션이력_조각/*.md'):
    hist |= set(re.findall(r'^## (O2\d\d)', io.open(p, encoding='utf-8').read(), re.M))
labels = set(re.findall(r'O0(2\d\d)-', ' '.join(glob.glob('99_NEXT_SESSION_조각/99_NEXT_SESSION-O02*.md'))))
today = '2026-10-14'
for n in range(202, 230):
    k = 'O%d' % n
    r = rows.get(k, [])
    fut = [x for x in r if x[2] and x[2] > today]
    print(k, 'ledger', len(r), 'hist', k in hist, 'handoff', str(n) in labels, 'future', len(fut), r[:1])
