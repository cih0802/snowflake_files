# O276 2단계-6 — 조립 프로젝트(KIT_ROOT)에서 키트 도구 음성 테스트 일괄 실행 · 결과 = TSV
import os, sys, glob, subprocess, time
ROOT = sys.argv[1]
OUT = sys.argv[2]
env = dict(os.environ, KIT_ROOT=ROOT)
rows = []
cmds = [('session_brief --write(게이트 없이)', ['scripts/session_brief.py', '--write', '--no-gates']),
        ('kit_paths --check', ['scripts/kit_paths.py', '--check']),
        ('verify_init_ihcho_skill', ['scripts/verify_init_ihcho_skill.py'])]
cmds += [(os.path.basename(t), [os.path.relpath(t, ROOT)]) for t in sorted(glob.glob(os.path.join(ROOT, 'scripts', 'test_*.py')))]
for name, argv in cmds:
    t0 = time.time()
    try:
        r = subprocess.run([sys.executable] + argv, cwd=ROOT, env=env, capture_output=True, text=True,
                           timeout=120, stdin=subprocess.DEVNULL)
        rc, out = r.returncode, (r.stdout + r.stderr).strip().splitlines()
    except subprocess.TimeoutExpired:
        rc, out = 124, ['TIMEOUT 120s']
    last = ' / '.join(l.strip() for l in out[-3:])[:300].replace('\t', ' ')
    rows.append('%s\t%d\t%.1f\t%s' % (name, rc, time.time() - t0, last))
    open(OUT, 'w', encoding='utf-8').write('name\trc\tsec\ttail\n' + '\n'.join(rows) + '\n')
print('done', len(rows))
