import os, sys, json, re, io, time, warnings
warnings.filterwarnings('ignore')
import snowflake.connector
from snowflake.connector.util_text import split_statements

BASE = os.environ.get('WS_BASE', '/workspace/')
ENV = os.environ.get('TARGET_ENV', 'DEV')
FILES = [f.strip() for f in os.environ['RUN_FILES'].split('|') if f.strip()]
STATE = os.environ.get('STATE', '/workspace/tmp/runner/state.json')
SKIPS_FILE = os.environ.get('SKIPS_FILE', '/workspace/tmp/runner/skips.json')
SKIPS = json.load(open(SKIPS_FILE)) if os.path.exists(SKIPS_FILE) else {}

SRC_WRITE = re.compile(r'^\s*(INSERT|UPDATE|DELETE|MERGE|TRUNCATE|COPY\s+INTO|DROP|CREATE\s+OR\s+REPLACE\s+(TRANSIENT\s+)?TABLE|ALTER\s+TABLE)\b[^;]*\bBRONZE_', re.I | re.S)

state = json.load(open(STATE)) if os.path.exists(STATE) else {'file': 0, 'stmt': 0}

print(f"Connecting to Snowflake as {os.environ.get('SNOWFLAKE_USERNAME', 'TRIALADMIN')}...", flush=True)

conn = snowflake.connector.connect(
    account=os.environ['SNOWFLAKE_ACCOUNT'],
    user=os.environ['SNOWFLAKE_USERNAME'],
    token=os.environ['SNOWFLAKE_TOKEN'],
    authenticator='oauth',
    role=os.environ.get('SNOWFLAKE_ROLE', 'ACCOUNTADMIN'),
    warehouse=os.environ.get('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH')
)
cur = conn.cursor()

total_files = len(FILES)
print(f"Total files to process: {total_files}, starting from file index {state['file']}", flush=True)

for fi in range(state['file'], total_files):
    rel = FILES[fi]
    full_path = os.path.join(BASE, rel.lstrip('/'))
    if not os.path.exists(full_path):
        print(f"FAIL: File not found: {full_path}", flush=True)
        sys.exit(1)
        
    with open(full_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    stmts = [s for s, _ in split_statements(io.StringIO(content), remove_comments=True) if s.strip()]
    
    if ENV == 'PROD':
        bad = [i for i, s in enumerate(stmts) if SRC_WRITE.search(s)]
        if bad:
            print(f'BLOCKED {rel}: 원천 쓰기 문장 {bad} — 실행 중단, 사용자 확인 필요', flush=True)
            sys.exit(2)
            
    start = state['stmt'] if fi == state['file'] else 0
    print(f"=== [{fi+1}/{total_files}] [{rel}] {len(stmts)} stmts (from stmt {start}) ===", flush=True)
    
    for si, s in enumerate(stmts):
        if si < start:
            # Replaying session context (USE ROLE / USE WAREHOUSE / USE DATABASE / USE SCHEMA)
            if re.match(r'^\s*USE\s', s, re.I):
                try:
                    cur.execute(s)
                except Exception as ctx_err:
                    print(f"Warning restoring context: {s.strip()} -> {ctx_err}", flush=True)
            continue
            
        key = f'{rel}:{si}'
        if key in SKIPS:
            print(f'SKIP {key}: {SKIPS[key]}', flush=True)
            continue
            
        json.dump({'file': fi, 'stmt': si}, open(STATE, 'w'))
        
        try:
            cur.execute(s)
            # If CALL or EXECUTE, print query ID or return value
            if re.match(r'^\s*(CALL|EXECUTE\s+IMMEDIATE)\b', s, re.I):
                row = cur.fetchone()
                val = str(row[0]) if row else ""
                print(f"  [EXEC {si}] {val[:200]}", flush=True)
        except Exception as e:
            err_msg = str(e)
            print(f"FAIL {key}: {err_msg}\n--- SQL (first 500 chars) ---\n{s[:500]}", flush=True)
            sys.exit(1)
            
    print(f"OK [{fi+1}/{total_files}] [{rel}]", flush=True)
    json.dump({'file': fi + 1, 'stmt': 0}, open(STATE, 'w'))

print("ALL DONE", flush=True)
