"""O275 4-C 순차 실행 v2 — 사용자 결정(2026-10-31): 원본 백업은 사용자 보유 → 스테이지 사전 대조 생략 · 소실·오류는 기록하고 계속.
그룹마다 apply → 빈 폴더 정리 → line_len · 마지막에 스테이지 1회 대조 + 게이트 + 소실 목록(tmp/restructure/LOST_FILES.csv)."""
import csv, json, os, subprocess, sys

ROOT = '/workspace'
T = f'{ROOT}/tmp/restructure'
GROUPS = sys.argv[1:]


def run(cmd, timeout):
    p = subprocess.run(cmd, cwd=ROOT, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=timeout)
    return p.returncode, (p.stdout + p.stderr).strip()


lost, errors = [], []
for g in GROUPS:
    print(f'=== {g}', flush=True)
    rc, out = run(['python3', f'{T}/exec_group.py', g, '--apply'], 3600)
    print(out, flush=True)
    if rc == 2:
        sys.exit(f'대상 충돌로 중단 {g}')
    log = json.load(open(f'{T}/exec_{g.strip("/").replace("/", "_")}.json'))
    lost += log.get('lost', [])
    errors += [[g, e] for e in log['errors']]
    rows = [r for r in csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')) if r['new_path'].startswith(g)]
    for t in {r['old_path'].split('/')[0] for r in rows if '/' in r['old_path']}:
        if os.path.isdir(f'{ROOT}/{t}'):
            for dp, _, _ in sorted(os.walk(f'{ROOT}/{t}'), key=lambda x: -len(x[0])):
                if os.path.isdir(dp) and not os.listdir(dp):
                    try:
                        os.rmdir(dp)
                    except OSError:
                        pass
    docs = [p for p, _ in log['subst'] if os.path.isfile(f'{ROOT}/{p}')]
    if docs:
        rc, out = run(['python3', 'scripts/line_len.py'] + docs, 300)
        print(out.splitlines()[-1], flush=True)

import glob
lost = []
for lf in sorted(glob.glob(f'{T}/exec_*.json')):  # 이번 실행분만이 아니라 전 그룹 로그에서 모은다
    lost += json.load(open(lf)).get('lost', [])
with open(f'{T}/LOST_FILES.csv', 'w', newline='', encoding='utf-8-sig') as fh:
    w = csv.writer(fh)
    w.writerow(['old_path', 'planned_new_path', 'note'])
    w.writerows(lost)
print(f'소실 {len(lost)} · 오류(원본 잔존) {len(errors)}', flush=True)
for e in errors[:20]:
    print('  ERR', e, flush=True)
rc, out = run(['sh', '-c', 'cortex ws ls \'USER$.PUBLIC."snowflake_files"\' > /tmp/ws.out 2>&1'], 600)
for g in GROUPS:
    rc, out = run(['python3', f'{T}/stage_verify.py', g], 120)
    print(out.splitlines()[0], flush=True)
for gate, to in (('scripts/doc_heading_gate.py', 300), ('scripts/index_row_gate.py', 200), ('scripts/doc_coord_gate.py', 300)):
    rc, out = run(['python3', gate], to)
    print(gate, f'rc={rc}', out.splitlines()[-1] if out else '', flush=True)
print('ALL_DONE', flush=True)
