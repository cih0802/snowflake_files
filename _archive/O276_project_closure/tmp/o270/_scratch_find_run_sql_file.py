# O270 · run_sql_file.py 호출 문서 전수 탐색(일회성 · 읽기 전용)
import io, os, re, sys
ROOTS = [d for d in sorted(os.listdir('/workspace'))
         if os.path.isdir(os.path.join('/workspace', d)) and d not in ('_archive', '30_output_share', 'tmp')
         and not d.startswith('.')]
EXT = ('.md', '.py', '.sh', '.sql', '.txt', '.yml')
pat = re.compile(r'run_sql_file\.py')
hits = 0
for r in ROOTS:
    base = os.path.join('/workspace', r)
    for d, _, fs in os.walk(base):
        if '_archive' in d or '__pycache__' in d:
            continue
        for f in fs:
            if not f.endswith(EXT):
                continue
            p = os.path.join(d, f)
            try:
                for i, line in enumerate(io.open(p, encoding='utf-8', errors='replace'), 1):
                    if pat.search(line):
                        hits += 1
                        tag = 'APPLY' if '--apply' in line else 'NOFLAG'
                        print('%s\t%s:%d\t%s' % (tag, os.path.relpath(p, '/workspace'), i, line.strip()[:160]))
            except OSError as e:
                print('ERR', p, e, file=sys.stderr)
print('hits=%d' % hits)
