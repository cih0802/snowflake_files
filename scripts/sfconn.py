import os, snowflake.connector

def conn():
    tokpath = os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')
    tok = open(tokpath).read().strip()
    return snowflake.connector.connect(
        account=os.environ['SNOWFLAKE_ACCOUNT'],
        host=os.environ.get('SNOWFLAKE_HOST'),
        token=tok,
        authenticator='oauth',
        role='ACCOUNTADMIN',
        warehouse='COMPUTE_WH',
        database='GN_DW',
        client_session_keep_alive=True,
    )

def q(sql, cn=None):
    own = cn is None
    cn = cn or conn()
    try:
        cur = cn.cursor()
        cur.execute(sql)
        cols = [c[0] for c in cur.description]
        return cols, cur.fetchall()
    finally:
        if own:
            cn.close()

if __name__ == '__main__':
    print(q("select current_account(), current_role(), current_warehouse()"))
