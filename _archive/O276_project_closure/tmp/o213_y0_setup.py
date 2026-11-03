"""Y0 — 7차 기준선 보존: Agent 3종 스펙 + SV 28종 DDL + GOLD/MSTR 뷰 DDL."""
import hashlib, os, subprocess, json, sys

OUT = "/workspace/tmp/o213_y0_baseline"
os.makedirs(OUT, exist_ok=True)

def run_sql(sql):
    """Return rows as list of dicts via snowsql-like interface."""
    # Use snowflake_sql_execute indirectly by writing to file
    r = subprocess.run(
        ["python3", "-c", f"""
import subprocess, json, sys
# We'll use the Snowflake REST via the sandbox token
import requests, os
token = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH','/snowflake/session/token')).read().strip()
host = os.environ.get('SNOWFLAKE_HOST','')
url = f'https://{{host}}/api/v2/statements'
headers = {{'Authorization': f'Bearer {{token}}', 'Content-Type': 'application/json',
            'X-Snowflake-Authorization-Token-Type': 'KEYPAIR_JWT'}}
body = {{'statement': '''{sql}''', 'timeout': 120, 'database': 'GN_DW', 'warehouse': 'COMPUTE_WH'}}
resp = requests.post(url, headers=headers, json=body)
print(resp.status_code)
print(resp.text[:2000])
"""],
        capture_output=True, text=True, timeout=30
    )
    return r.stdout

def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()

# Will collect via snowflake_sql_execute tool calls instead
# This script just creates the directory structure
print(f"Baseline dir: {OUT}")
print("Ready for spec/DDL dumps.")
