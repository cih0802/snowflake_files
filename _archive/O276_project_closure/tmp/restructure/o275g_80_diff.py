"""O275-G 80 빌더 dry-run 대조 — 기존 00_INDEX.csv(재편 전 빌드) ↔ 새 빌더 PLAN 목록."""
import csv, re, subprocess, sys
B = '/workspace/80_인수인계_프로젝트완료 및 유지보수용/build_handoff.py'
p = subprocess.run([sys.executable, B], capture_output=True, text=True, cwd='/workspace', timeout=600)
plan = {l[7:].strip() for l in p.stdout.splitlines() if l.startswith('[PLAN] ')}
old = {f"{r['서브폴더']}/{r['파일경로']}" for r in csv.DictReader(open('/workspace/tmp/restructure/o275g_80_index_before.csv', encoding='utf-8-sig'))}
print('rc', p.returncode, 'plan', len(plan), 'before', len(old))
print('only_before', len(old - plan)); [print('  -', x) for x in sorted(old - plan)[:30]]
print('only_plan', len(plan - old)); [print('  +', x) for x in sorted(plan - old)[:30]]
for l in p.stdout.splitlines():
    if l.startswith(('[MISSING]', '[WARN]', '파일 ')):
        print(l[:200])
print(p.stderr[-1500:])
