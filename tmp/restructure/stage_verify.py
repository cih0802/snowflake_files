"""O275 스테이지 실체 대조 — cortex ws ls 출력(/tmp/ws.out) ↔ MOVE_MAP_files.csv 그룹 행."""
import csv, re, sys
grp = sys.argv[1]
ws = {}
LINE = re.compile(r'^/versions/live/(.+?)\t(\d+)\t([0-9a-f]{32})\t')
for ln in open('/tmp/ws.out', encoding='utf-8', errors='ignore'):
    m = LINE.match(ln)
    if m and not m.group(1).endswith('/.folder') and m.group(1) != '.folder':
        ws[m.group(1)] = m.group(2)
rows = [r for r in csv.DictReader(open('/workspace/MOVE_MAP_files.csv', encoding='utf-8-sig')) if r['new_path'].startswith(grp)]
miss_new = [r['new_path'] for r in rows if r['new_path'] not in ws]
left_old = [r['old_path'] for r in rows if r['old_path'] in ws]
extra = [k for k in ws if k.startswith(grp) and k not in {r['new_path'] for r in rows}]
print(f'{grp} rows {len(rows)} · stage 신규 부재 {len(miss_new)} · stage 원본 잔존 {len(left_old)} · 매핑 밖 항목 {len(extra)}')
for x in (miss_new + left_old)[:10]:
    print('  !', x)
for x in extra[:10]:
    print('  +', x)
