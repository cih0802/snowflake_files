"""O275 4-C 사전 점검 — 이동 대상 폴더를 `versions/live/<폴더>` 형태로 참조하는 텍스트(라이브 배포 경로 후보) 탐색."""
import csv, os, re
ROOT = '/workspace'
rows = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig')))
olds = sorted({r['old_path'].rstrip('/') for r in rows if r['old_path'].endswith('/') and '/' not in r['old_path'].rstrip('/')})
pat = re.compile(r'versions/live/(' + '|'.join(re.escape(o) for o in olds) + r')')
hits = []
for top in ('scripts', '00_guides', '10_dbt_pipeline') + tuple(olds):
    for dp, dns, fns in os.walk(os.path.join(ROOT, top)):
        dns[:] = [d for d in dns if d not in ('_archive', '__pycache__', 'target', 'logs') and not d.startswith('_backup_')]
        for fn in fns:
            if fn.endswith(('.py', '.sql', '.yml', '.yaml', '.md', '.json', '.toml')):
                p = os.path.join(dp, fn)
                try:
                    for i, ln in enumerate(open(p, encoding='utf-8', errors='ignore'), 1):
                        m = pat.search(ln)
                        if m:
                            hits.append(f'{os.path.relpath(p, ROOT)}:{i}: {m.group(1)} :: {ln.strip()[:120]}')
                except OSError:
                    pass
print(len(hits))
print('\n'.join(hits[:80]))
