"""O275 상태 판정(스테이지 기준) — cortex ws ls 1회 → 매핑표 전 행을 done/todo/both/LOST 로 분류. 출력 = tmp/restructure/stage_status.json"""
import csv, json, re, subprocess
from collections import Counter, defaultdict
ROOT = '/workspace'
out = subprocess.run(['cortex', 'ws', 'ls', 'USER$.PUBLIC."snowflake_files"'], capture_output=True, text=True,
                     stdin=subprocess.DEVNULL, timeout=900).stdout
LINE = re.compile(r'^/versions/live/(.+?)\t(\d+)\t([0-9a-f]{32})\t')
ws = {}
for ln in out.splitlines():
    m = LINE.match(ln)
    if m and not m.group(1).endswith('.folder'):
        ws[m.group(1)] = (int(m.group(2)), m.group(3))
rows = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')))
st, det = Counter(), defaultdict(list)
for r in rows:
    g = '/'.join(r['new_path'].split('/')[:1])
    o, n = r['old_path'] in ws, r['new_path'] in ws
    s = 'done' if n and not o else 'both' if n else 'todo' if o else 'LOST'
    st[(g, s)] += 1
    if s != 'done':
        det[s].append([r['old_path'], r['new_path']])
json.dump({'stage_entries': len(ws), 'status': {f'{a}|{b}': c for (a, b), c in st.items()}, 'detail': det},
          open(f'{ROOT}/tmp/restructure/stage_status.json', 'w'), ensure_ascii=False, indent=1)
print('stage entries', len(ws))
for k in sorted(st):
    print(k, st[k])
for p in det['LOST']:
    print('LOST', p[0], '->', p[1])
