# O276 A 치환 사후 검증 — 스냅샷에 fix() 를 적용한 결과 == 현재 파일 인가 (중단·절단 탐지)
import io, os
ROOT = '/workspace'
HERE = os.path.join(ROOT, '_archive/O276_project_closure')
SNAP = os.path.join(HERE, '_snap_refA')
src = io.open(os.path.join(HERE, 'o276_replace_A.py'), encoding='utf-8').read().split('\nrows = ')[0]
ns = {}
exec(src, ns)
fix = ns['fix']
ok, bad, pending = 0, [], []
for d, _, fs in os.walk(SNAP):
    reldir = os.path.relpath(d, SNAP)
    for fn in fs:
        snap = os.path.join(d, fn)
        old = io.open(snap, encoding='utf-8').read()
        odir = os.path.join(ROOT, reldir)
        orig = sorted((c for c in os.listdir(odir)
                       if os.path.isfile(os.path.join(odir, c)) and fn.startswith(os.path.splitext(c)[0])),
                      key=len, reverse=True)
        hit = None
        for c in orig:
            cur = io.open(os.path.join(odir, c), encoding='utf-8', errors='replace').read()
            rel = os.path.normpath(os.path.join(reldir, c))
            if cur == ''.join(fix(l, rel) for l in old.splitlines(keepends=True)):
                hit = 'ok'
                break
            if cur == old:
                hit = 'pending'
        if hit == 'ok':
            ok += 1
        elif hit == 'pending':
            pending.append(snap)
        else:
            bad.append(snap)
print('ok', ok, 'pending', len(pending), 'bad', len(bad))
for b in bad + pending:
    print(b)
