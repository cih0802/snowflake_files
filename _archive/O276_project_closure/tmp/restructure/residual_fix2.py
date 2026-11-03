"""O275-A 잔존 정정 2 — `{ROOT}/OLD` · `{BASE}/OLD` · `W + '/OLD` · 셸 목록 끝 토큰 형태(경계 밖 표기)."""
import csv, os, re, sys
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot  # noqa: E402

ROOT = '/workspace'
ARCH = f'{ROOT}/_archive/RESTRUCTURE_20261031-pre/4C/residual'
files = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')))
fmap = {r['old_path']: r['new_path'] for r in files}
summ = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig')))
tops = {r['old_path'].rstrip('/'): r['new_path'].rstrip('/') for r in summ
        if r['old_path'].endswith('/') and '/' not in r['old_path'].rstrip('/')}
TARGETS = ['scripts/add_column_comments.py', 'scripts/mirror_from_stage.sh', 'scripts/o192_ddl_compact.py',
           'scripts/o192_ml_serving_compact.py', 'scripts/rbac_source_gate.py']
OLD = '|'.join(re.escape(t) for t in sorted(tops, key=len, reverse=True))
RX = re.compile(r"(\{ROOT\}/|\{BASE\}/|W \+ '/|(?<=\s))(" + OLD + r")((?:/[^'\"`\n%}]*)?)(?=['\"`%}\s]|$)")


def fix(m):
    pre, top, rest = m.group(1), m.group(2), m.group(3)
    full = top + rest
    if full in fmap:
        return pre + fmap[full]
    cand = tops[top] + rest.replace(' ', '_')
    new = cand if ' ' in rest and os.path.exists(f'{ROOT}/{cand}') else tops[top] + rest
    # glob 패턴·디렉터리 접두: 하위 폴더 공백 치환형이 실재하면 그것으로
    d = os.path.dirname(cand)
    if ' ' in rest and os.path.isdir(f'{ROOT}/{d}'):
        new = cand
    return pre + new


for rel in TARGETS:
    p = f'{ROOT}/{rel}'
    a, b = open(p, 'rb').read(), open(p, 'rb').read()
    assert a == b
    t = a.decode('utf-8')
    nt, k = RX.subn(fix, t)
    if k:
        nm = rel.replace('/', '__') + '.O275-A-residual2-pre'
        snapshot(p, 'pre', label='O275', archive=ARCH, name=nm, quiet=True)
        with open(p, 'wb') as fh:
            fh.write(nt.encode('utf-8'))
        assert open(p, 'rb').read() == nt.encode('utf-8')
    print(rel, k)
    for x, y in zip(t.split('\n'), nt.split('\n')):
        if x != y:
            print('   -', x.strip()[:130])
            print('   +', y.strip()[:130])
