import os, sys, io
import snowflake.connector

files = sys.argv[1:]
tok = io.open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
con = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ['SNOWFLAKE_HOST'],
                                  authenticator='oauth', token=tok, warehouse=os.environ.get('SNOWFLAKE_WAREHOUSE'))
rc = 0
for f in files:
    sql = io.open(f, encoding='utf-8').read()
    try:
        for cur in con.execute_string(sql):
            head = (cur.query or '').strip().split('\n')[0][:70]
            if head.upper().startswith('SELECT'):
                print('  SMOKE', cur.fetchall())
        print('OK  ', os.path.basename(f))
    except Exception as e:
        print('FAIL', os.path.basename(f), str(e)[:600])
        rc = 1
        break
sys.exit(rc)
