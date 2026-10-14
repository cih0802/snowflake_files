import io, re, glob
need = ['O203', 'O204', 'O211']
hit = {k: [] for k in need}
for p in sorted(glob.glob('20_issue/01_세션이력_조각/*.md')):
    for i, s in enumerate(io.open(p, encoding='utf-8').read().split('\n'), 1):
        if s.startswith('#'):
            for k in need:
                if re.search(k + r'(?!\d)', s):
                    hit[k].append((p.split('/')[-1], i, s[:90]))
for k in need:
    print(k, len(hit[k]), hit[k][:2])
