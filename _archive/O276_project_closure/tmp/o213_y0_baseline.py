"""Y0 — 7차 기준선 보존 스크립트.
Agent 3종 스펙(YAML) + SV 28종 DDL + GOLD/MSTR 뷰 DDL 을 tmp/o213_y0/ 에 보존."""
import subprocess, hashlib, os, json

OUT = "/workspace/tmp/o213_y0"
os.makedirs(OUT, exist_ok=True)

def sql(stmt, desc=""):
    """snowflake_sql_execute 대신 직접 REST 호출."""
    import requests
    token = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH',
                                '/snowflake/session/token')).read().strip()
    host = os.environ.get('SNOWFLAKE_HOST', '')
    url = f'https://{host}/api/v2/statements'
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json',
        'X-Snowflake-Authorization-Token-Type': 'KEYPAIR_JWT'
    }
    body = {
        'statement': stmt,
        'timeout': 120,
        'database': 'GN_DW',
        'warehouse': 'COMPUTE_WH',
        'resultSetMetaData': {'format': 'jsonv2'}
    }
    resp = requests.post(url, headers=headers, json=body, timeout=180)
    rj = resp.json()
    if resp.status_code not in (200,):
        print(f"  SQL error ({resp.status_code}): {str(rj)[:300]}")
        return None
    # parse rows
    cols = [c['name'] for c in rj.get('resultSetMetaData',{}).get('rowType',[])]
    data = rj.get('data', [])
    return [dict(zip(cols, row)) for row in data]

def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()

def save(name, content):
    path = os.path.join(OUT, name)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    h = sha256(path)
    print(f"  {name}: {len(content):,} chars · sha256={h[:16]}…")
    return h

manifest = {}

# 1. Agent 3종 스펙
print("=== Agent specs ===")
agents = ['AGENT_EXECUTIVE', 'AGENT_MEMBER', 'AGENT_MARKETING']
for a in agents:
    rows = sql(f"describe agent GN_DW.SERVING.{a}")
    if rows:
        r = rows[0]
        spec_text = r.get('agent_spec', '')
        ver = r.get('default_version_name', '')
        fname = f"{a}_spec_v{ver}.json"
        h = save(fname, spec_text)
        manifest[a] = {'file': fname, 'version': ver, 'sha256': h}
    else:
        print(f"  {a}: FAILED")

# 2. SV 28종 DDL
print("\n=== SV DDL ===")
sv_rows = sql("show semantic views in database GN_DW")
sv_count = 0
if sv_rows:
    for sv in sv_rows:
        name = sv['name']
        ddl_rows = sql(f"select get_ddl('semantic_view', 'GN_DW.SERVING.{name}') as ddl")
        if ddl_rows:
            ddl = ddl_rows[0].get('DDL', ddl_rows[0].get('ddl', ''))
            if not ddl:
                ddl = str(ddl_rows[0])
            fname = f"SV_{name}.sql"
            h = save(fname, ddl)
            manifest[f'SV_{name}'] = {'file': fname, 'sha256': h}
            sv_count += 1
        else:
            print(f"  SV_{name}: DDL FAILED")
print(f"  SV total: {sv_count}")

# 3. GOLD views + MSTR views
print("\n=== GOLD/MSTR views DDL ===")
view_count = 0
for schema in ['GOLD', 'MSTR', 'SERVING']:
    vrows = sql(f"""
        select table_name from GN_DW.INFORMATION_SCHEMA.TABLES
        where table_schema='{schema}' and table_type='VIEW'
        order by table_name
    """)
    if not vrows:
        continue
    for v in vrows:
        vn = v['TABLE_NAME']
        ddl_rows = sql(f"select get_ddl('view', 'GN_DW.{schema}.{vn}') as ddl")
        if ddl_rows:
            ddl = ddl_rows[0].get('DDL', ddl_rows[0].get('ddl', ''))
            if not ddl:
                ddl = str(ddl_rows[0])
            fname = f"VIEW_{schema}_{vn}.sql"
            h = save(fname, ddl)
            manifest[f'{schema}.{vn}'] = {'file': fname, 'sha256': h}
            view_count += 1

print(f"  View total: {view_count}")

# Save manifest
mpath = os.path.join(OUT, "_manifest.json")
with open(mpath, 'w') as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)
print(f"\nManifest: {mpath} ({len(manifest)} entries)")
print("Y0 DONE")
