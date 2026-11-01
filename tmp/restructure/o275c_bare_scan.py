"""O275-C 보조 스캔(읽기 전용) — 따옴표 밖 맨 토큰 옛 상위폴더명(scripts · 00_guides · .snowflake · 루트 md)."""
import csv, os, re, sys
from collections import Counter
ROOT = '/workspace'
summ = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig')))
tops = sorted({r['old_path'].rstrip('/') for r in summ if r['old_path'].endswith('/') and '/' not in r['old_path'].rstrip('/')}, key=len, reverse=True)
A = re.compile(r'(?<![\w/])(' + '|'.join(re.escape(t) for t in tops) + r')/')
EXC = re.compile(r'01_실행순서_배포SQL/|80_인수인계|_backup_|MOVE_MAP|O275')
hits = []
targets = [('scripts', True), ('00_guides', True), ('.snowflake', True)]
for top, rec in targets:
    for dp, dns, fns in os.walk(f'{ROOT}/{top}'):
        dns[:] = [d for d in dns if d not in ('__pycache__', '_archive', 'golden')]
        for fn in fns:
            if not fn.endswith(('.py', '.sh', '.md', '.sql', '.yml', '.yaml')):
                continue
            p = os.path.join(dp, fn)
            try:
                lines = open(p, encoding='utf-8').read().split('\n')
            except (UnicodeDecodeError, OSError):
                continue
            for i, ln in enumerate(lines, 1):
                for m in A.finditer(ln):
                    hits.append((os.path.relpath(p, ROOT), i, m.group(1), bool(EXC.search(ln)), ln.strip()[:160]))
with open(sys.argv[1], 'w', newline='', encoding='utf-8-sig') as fh:
    w = csv.writer(fh); w.writerow(['file', 'line', 'token', 'exception_ctx', 'text']); w.writerows(hits)
print('hits', len(hits), 'exc', sum(h[3] for h in hits), 'files', len({h[0] for h in hits}))
print(Counter(h[0] for h in hits if not h[3]).most_common(30))
