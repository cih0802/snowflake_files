#!/usr/bin/env python3
"""O205 세션 트랜스크립트(JSONL) → 실행 SQL·수정 파일·변경 SQL 요약 (자기검토 근거)"""
import json, re, collections, sys
p = sys.argv[1] if len(sys.argv) > 1 else '/workspace/tmp/o205_transcript.json'
recs = []
for line in open(p, encoding='utf-8'):
    line = line.strip()
    if line:
        try:
            recs.append(json.loads(line))
        except Exception:
            pass
sql, edits, bash = [], [], []
def walk(o):
    if isinstance(o, dict):
        n = o.get('name'); i = o.get('input')
        if isinstance(i, dict):
            if n == 'snowflake_sql_execute': sql.append(i.get('sql', ''))
            if n in ('edit', 'write'): edits.append(i.get('file_path'))
            if n == 'bash': bash.append(i.get('command', ''))
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
for r in recs: walk(r)
print('records', len(recs), 'sql', len(sql), 'edits', len(edits), 'bash', len(bash))
for k, v in collections.Counter(edits).most_common(): print(f'{v:3d} {k}')
print('-- 변경 SQL --')
for s in sql:
    if re.match(r'\s*(ALTER|CREATE|COPY|DROP|GRANT|INSERT|UPDATE|DELETE|MERGE)', s, re.I):
        print(' ', re.sub(r'\s+', ' ', s)[:150])
print('-- 변경 bash --')
for b in bash:
    if re.search(r'deploy_sv|--apply|handoff_write|--republish|--rollover|rm |dbt ', b):
        print(' ', re.sub(r'\s+', ' ', b)[:150])
