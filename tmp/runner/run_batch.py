import os, sys, json, re, io, time, warnings
warnings.filterwarnings('ignore')
import snowflake.connector
from snowflake.connector.util_text import split_statements

sys.path.insert(0, '/workspace')
from scripts.sfconn import conn

BASE = '/workspace/'
STATE_FILE = os.environ.get('STATE_FILE', '/tmp/runner/state_group1.json')
LOG_FILE = os.environ.get('LOG_FILE', '/tmp/runner/group1.log')
FILES = [f.strip() for f in os.environ['RUN_FILES'].split('|') if f.strip()]

TARGET_BRONZE = re.compile(
    r'^\s*(INSERT\s+INTO|UPDATE|DELETE\s+FROM|MERGE\s+INTO|TRUNCATE\s+TABLE|COPY\s+INTO|DROP\s+TABLE|CREATE\s+(OR\s+REPLACE\s+)?(TRANSIENT\s+)?TABLE|ALTER\s+TABLE)\s+([^\s;(]+\.)?BRONZE_',
    re.I
)

BACKFILL_PATTERN = re.compile(
    r'(bigquery_dt_ranges|USP_RUN_MSTR_1ST.*BETWEEN\s+\'202401\')',
    re.I
)

state = {'file_idx': 0, 'stmt_idx': 0}
if os.path.exists(STATE_FILE):
    try:
        state = json.load(open(STATE_FILE, 'r', encoding='utf-8'))
    except Exception:
        pass

def log(msg):
    ts = time.strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{ts}] {msg}'
    print(line, flush=True)
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(line + '\n')

log(f'=== RUNNER STARTED for {len(FILES)} files ===')
log(f'Resuming from file_idx={state["file_idx"]}, stmt_idx={state["stmt_idx"]}')

cn = conn()
cur = cn.cursor()

for fi in range(state['file_idx'], len(FILES)):
    rel = FILES[fi]
    full_path = os.path.join(BASE, rel)
    log(f'>>> Starting file [{fi+1}/{len(FILES)}]: {rel}')

    try:
        content = open(full_path, 'r', encoding='utf-8').read()
    except Exception as e:
        log(f'FATAL: Could not read {full_path}: {e}')
        sys.exit(1)

    stmts = [s.strip() for s, _ in split_statements(io.StringIO(content), remove_comments=True) if s.strip()]
    start_stmt = state['stmt_idx'] if fi == state['file_idx'] else 0
    log(f'File {rel} has {len(stmts)} statements. Starting from stmt {start_stmt}')

    for si in range(start_stmt, len(stmts)):
        stmt = stmts[si]
        key = f'{rel}:{si}'

        # Check raw data write safety (R1)
        if TARGET_BRONZE.search(stmt):
            log(f'BLOCKED {key}: Prohibited write to BRONZE schema detected! Statement: {stmt[:200]}')
            sys.exit(2)

        # Check backfill / period-specified skip rule (R2-9)
        if BACKFILL_PATTERN.search(stmt):
            log(f'SKIP (R2-9 Backfill/Period-specified) {key}: {stmt[:100]}...')
            state['file_idx'] = fi
            state['stmt_idx'] = si + 1
            json.dump(state, open(STATE_FILE, 'w', encoding='utf-8'))
            continue

        state['file_idx'] = fi
        state['stmt_idx'] = si
        json.dump(state, open(STATE_FILE, 'w', encoding='utf-8'))

        log_snippet = stmt.replace('\n', ' ')[:120]
        t0 = time.time()
        try:
            cur.execute(stmt)
            elapsed = time.time() - t0
            # fetch rowcount or first result if applicable
            msg = f'OK ({elapsed:.2f}s) {key}: {log_snippet}'
            log(msg)
        except Exception as e:
            elapsed = time.time() - t0
            err_msg = str(e)
            log(f'FAIL ({elapsed:.2f}s) {key}: {err_msg}\nSQL:\n{stmt[:1000]}')
            sys.exit(1)

    log(f'<<< Finished file [{fi+1}/{len(FILES)}]: {rel}')
    state['file_idx'] = fi + 1
    state['stmt_idx'] = 0
    json.dump(state, open(STATE_FILE, 'w', encoding='utf-8'))

log('=== ALL FILES COMPLETED SUCCESSFULLY ===')
cn.close()
