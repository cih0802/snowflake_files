# O216-F — 세션 트랜스크립트 다이제스트(실행 SQL · 라이브 변경 · 파일 쓰기 · 사용자 지시) 추출
# 사용: python3 tmp/o216f_digest.py <transcript.jsonl> <out.md>
# Co-authored with CoCo
import io, json, re, sys

src, out = sys.argv[1], sys.argv[2]
rows = [json.loads(l) for l in io.open(src, encoding='utf-8') if l.strip()]
MUT = re.compile(r'\b(ALTER|CREATE|GRANT|DROP|INSERT|UPDATE|DELETE|COPY FILES|CALL EXECUTE_AI|MERGE|TRUNCATE)\b', re.I)
user, sqls, files, bashes = [], [], [], []


def blocks(c):
    if isinstance(c, str):
        return [{'type': 'text', 'text': c}]
    return c or []


for i, r in enumerate(rows):
    for b in blocks(r.get('content')):
        t = b.get('type')
        if r['role'] == 'user' and t == 'text':
            txt = re.sub(r'<system-reminder>.*?</system-reminder>', '', b.get('text', ''), flags=re.S).strip()
            if txt:
                user.append((i, txt[:600]))
        if t == 'tool_use':
            tu = b.get('tool_use', b)  # 🔴 실물 = {'type':'tool_use','tool_use':{name,input,…}} (중첩 · 2026-10-12 실측)
            name, inp = tu.get('name'), tu.get('input', {})
            if name == 'snowflake_sql_execute':
                sqls.append((i, inp.get('sql', '')))
            elif name in ('write', 'edit'):
                files.append((i, name, inp.get('file_path', '')))
            elif name == 'bash':
                cmd = inp.get('command', '')
                if MUT.search(cmd) or '--apply' in cmd or 'handoff_write' in cmd or 'rollover' in cmd \
                        or 'update-golden' in cmd or 'ADD VERSION' in cmd:
                    bashes.append((i, cmd))
w = io.open(out, 'w', encoding='utf-8')
w.write('# O216 세션 트랜스크립트 다이제스트 (자동 추출 · 원문 = ' + src + ')\n\n')
w.write(f'records {len(rows)} · 사용자 지시 {len(user)} · SQL 도구 {len(sqls)} · 파일 쓰기 {len(files)} · 변경성 bash {len(bashes)}\n\n')
w.write('## 1. 사용자 지시\n\n')
for i, t in user:
    w.write(f'- [{i}] ' + t.replace('\n', ' / ')[:900] + '\n')
w.write('\n## 2. SQL 도구 — 변경성만\n\n')
for i, s in sqls:
    if MUT.search(s):
        w.write(f'- [{i}] ' + ' '.join(s.split())[:900] + '\n')
w.write('\n## 3. 파일 쓰기(write/edit)\n\n')
for i, n, p in files:
    w.write(f'- [{i}] {n} {p}\n')
w.write('\n## 4. 변경성 bash(라이브 DDL · --apply · 인수인계 · 골든)\n\n')
for i, c in bashes:
    w.write(f'- [{i}] ' + ' '.join(c.split())[:900] + '\n')
w.close()
print('ok', len(user), len(sqls), len(files), len(bashes))
