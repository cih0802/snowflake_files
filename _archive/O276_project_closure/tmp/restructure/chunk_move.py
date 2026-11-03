"""O275 4-C 분할 이동 — 그룹 접두 아래 3단계 폴더 단위로 --move-only 를 순차 실행(실행 1회 = 짧게 끝남).
사용: python3 chunk_move.py <group_prefix> [max_chunks]"""
import csv, subprocess, sys
from collections import OrderedDict
ROOT = '/workspace'
g = sys.argv[1]
maxn = int(sys.argv[2]) if len(sys.argv) > 2 else 999
rows = [r for r in csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')) if r['new_path'].startswith(g)]
chunks = OrderedDict()
for r in rows:
    parts = r['new_path'].split('/')
    key = '/'.join(parts[:min(len(parts) - 1, 4)]) + '/'
    chunks.setdefault(key, 0)
    chunks[key] += 1
import os
alive = {r['old_path'] for r in rows if os.path.exists(f'{ROOT}/{r["old_path"]}')}  # 파일당 stat 1회
todo = [k for k in chunks if any(r['new_path'].startswith(k) and r['old_path'] in alive for r in rows)]
todo = [k for k in todo if not any(k != j and k.startswith(j) for j in todo)]  # 상위 청크가 하위를 포함하면 상위만
print('chunks', len(chunks), 'alive', len(alive), 'todo', len(todo), flush=True)
for k in todo[:maxn]:
    p = subprocess.run(['python3', f'{ROOT}/tmp/restructure/exec_group.py', k, '--apply', '--move-only'],
                       cwd=ROOT, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=5400)
    print(k, chunks[k], '|', (p.stdout + p.stderr).strip().splitlines()[-1], flush=True)
