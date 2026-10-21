import os, io, sys
pat = sys.argv[1]
roots = sys.argv[2:]
skip = {'target', '_archive', 'logs', 'dbt_packages', '__pycache__', 'tmp', '.git'}
for r in roots:
    for d, ds, fs in os.walk(r):
        ds[:] = [x for x in ds if x not in skip]
        for f in fs:
            if not f.endswith(('.sql', '.yml', '.yaml', '.md', '.py', '.json')):
                continue
            p = os.path.join(d, f)
            try:
                n = io.open(p, encoding='utf-8', errors='ignore').read().count(pat)
            except Exception:
                continue
            if n:
                print(n, p)
