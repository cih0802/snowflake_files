"""O275 4-C 최종 검증 — 스테이지 전수 대조 · 소실 목록 · 게이트."""
import csv, glob, json, re, subprocess
ROOT = '/workspace'
T = f'{ROOT}/tmp/restructure'
subprocess.run(['sh', '-c', 'cortex ws ls \'USER$.PUBLIC."snowflake_files"\' > /tmp/ws.out 2>&1'], timeout=900)
LINE = re.compile(r'^/versions/live/(.+?)\t(\d+)\t([0-9a-f]{32})\t')
ws = set()
for ln in open('/tmp/ws.out', encoding='utf-8', errors='ignore'):
    m = LINE.match(ln)
    if m and not m.group(1).endswith('.folder'):
        ws.add(m.group(1))
rows = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')))
lost = []
for lf in sorted(glob.glob(f'{T}/exec_*.json')):
    lost += json.load(open(lf)).get('lost', [])
lost_old = {x[0] for x in lost}
miss_new = [r for r in rows if r['new_path'] not in ws and r['old_path'] not in lost_old]
left_old = [r['old_path'] for r in rows if r['old_path'] in ws]
# 맵 대조로 못 잡는 소실: 신규 부재 + 원본 부재
for r in miss_new:
    if r['old_path'] not in ws:
        lost.append([r['old_path'], r['new_path'], '스테이지 대조: 신·구 모두 부재'])
uniq = {x[0]: x for x in lost}
with open(f'{T}/LOST_FILES.csv', 'w', newline='', encoding='utf-8-sig') as fh:
    w = csv.writer(fh)
    w.writerow(['old_path', 'planned_new_path', 'note'])
    w.writerows(uniq.values())
print(f'ws {len(ws)} · map {len(rows)} · 신규 부재 {len(miss_new)} · 원본 잔존 {len(left_old)} · 소실 {len(uniq)}')
for x in left_old[:10]:
    print('  LEFT', x)
for x in uniq.values():
    print('  LOST', x)
for gate, to in (('scripts/doc_heading_gate.py', 600), ('scripts/index_row_gate.py', 300), ('scripts/doc_coord_gate.py', 600)):
    p = subprocess.run(['python3', gate], cwd=ROOT, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=to)
    out = (p.stdout + p.stderr).strip().splitlines()
    print(gate, f'rc={p.returncode}', out[-1] if out else '')
    if p.returncode:
        print('\n'.join(out[-25:]))
