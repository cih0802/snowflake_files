# 문서실행순서_llm실행.md §3.2 실행기 (O241 · 연결만 sfconn OAuth 로 교체 · 상태는 /workspace 에 둔다)
import os, sys, json, re, io, warnings
warnings.filterwarnings('ignore')
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn as sf_conn
from snowflake.connector.util_text import split_statements

BASE   = os.environ.get('WS_BASE', '/workspace/')
ENV    = os.environ['TARGET_ENV']
FILES  = os.environ['RUN_FILES'].split('|')
STATE  = os.environ['STATE']
SKIPF  = '/workspace/tmp/runner/skips.json'
SKIPS  = json.load(open(SKIPF)) if os.path.exists(SKIPF) else {}
SRC_WRITE = re.compile(r'^\s*(INSERT|UPDATE|DELETE|MERGE|TRUNCATE|COPY\s+INTO|DROP|CREATE\s+OR\s+REPLACE\s+(TRANSIENT\s+)?TABLE|ALTER\s+TABLE)\b[^;]*\bBRONZE_', re.I | re.S)

state = json.load(open(STATE)) if os.path.exists(STATE) else {'file': 0, 'stmt': 0}
conn = sf_conn()
cur = conn.cursor()

for fi in range(state['file'], len(FILES)):
    rel = FILES[fi]
    stmts = [s for s, _ in split_statements(io.StringIO(open(BASE + rel, encoding='utf-8').read()),
                                            remove_comments=True) if s.strip()]
    if ENV == 'PROD':
        bad = [i for i, s in enumerate(stmts) if SRC_WRITE.search(s)]
        if bad:
            print(f'BLOCKED {rel}: 원천 쓰기 문장 {bad} — 실행 중단, 사용자 확인 필요', flush=True); sys.exit(2)
    start = state['stmt'] if fi == state['file'] else 0
    print(f'=== [{rel}] {len(stmts)} stmts from {start}', flush=True)
    for si, s in enumerate(stmts):
        if si < start:
            if re.match(r'^\s*USE\s', s, re.I): cur.execute(s)
            continue
        key = f'{rel}:{si}'
        if key in SKIPS:
            print(f'SKIP {key}: {SKIPS[key]}', flush=True); continue
        json.dump({'file': fi, 'stmt': si}, open(STATE, 'w'))
        try:
            cur.execute(s)
            if re.match(r'^\s*(EXECUTE|CALL)\b', s, re.I):
                try:
                    print(f'  RESULT {key}: {str(cur.fetchall())[:400]}', flush=True)
                except Exception:
                    pass
        except Exception as e:
            print(f'FAIL {key}: {e}\n--- SQL ---\n{s[:1500]}', flush=True); sys.exit(1)
    print(f'OK [{rel}]', flush=True)
    json.dump({'file': fi + 1, 'stmt': 0}, open(STATE, 'w'))
print('ALL DONE', flush=True)
