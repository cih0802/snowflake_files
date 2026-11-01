"""O275 잔존 옛 경로 스캔(읽기 전용) — scripts/ · 00_guides/ 에서 4-C 치환 경계가 놓친 표기.
축 ㉠ 절대경로/조인 인자: '/workspace/OLD' · 'OLD' · "OLD" (따옴표 시작)
축 ㉡ 이름 변경·archive 된 파일의 basename 단독 표기(따옴표 안)
"""
import csv, os, re, sys
ROOT = '/workspace'
summ = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig')))
files = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')))
tops = sorted({r['old_path'].rstrip('/') for r in summ if r['old_path'].endswith('/') and '/' not in r['old_path'].rstrip('/')}, key=len, reverse=True)
renamed = {}
for r in files:
    ob, nb = os.path.basename(r['old_path']), os.path.basename(r['new_path'])
    if r['action'] in ('rename', 'archive') and '/' in r['old_path']:
        renamed[ob] = (nb, r['action'], r['old_path'], r['new_path'])
A = re.compile(r'(/workspace/|[\'"`])(' + '|'.join(re.escape(t) for t in tops) + r')(?=[/\'"`]|$)')
B = re.compile(r'[\'"`](' + '|'.join(re.escape(b) for b in sorted(renamed, key=len, reverse=True)) + r')[\'"`]') if renamed else None
hits = []
for top in ('scripts', '00_guides'):
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
                    hits.append(('A', os.path.relpath(p, ROOT), i, m.group(2), ln.strip()[:140]))
                if B:
                    for m in B.finditer(ln):
                        hits.append(('B', os.path.relpath(p, ROOT), i, m.group(1), ln.strip()[:140]))
with open(sys.argv[1], 'w', newline='', encoding='utf-8-sig') as fh:
    w = csv.writer(fh)
    w.writerow(['axis', 'file', 'line', 'token', 'text'])
    w.writerows(hits)
from collections import Counter
print('hits', len(hits), Counter(h[0] for h in hits), 'files', len({h[1] for h in hits}))
for h in hits[:25]:
    print(h)
