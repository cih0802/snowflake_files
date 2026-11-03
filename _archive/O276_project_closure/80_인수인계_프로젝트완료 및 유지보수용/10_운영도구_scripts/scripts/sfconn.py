import os, snowflake.connector

# [O262] 접속 2경로 — 기본값(워크스페이스 동작)은 불변이다.
#   ㉠ 토큰 파일이 있으면 = 종전 OAuth(Snowsight 워크스페이스 · 컨테이너)
#   ㉡ 없으면 = SNOWFLAKE_CONNECTION_NAME 의 connections.toml 항목(로컬 · 운영 PC · 80 패키지)
#   역할·웨어하우스 = GN_DW_ROLE · GN_DW_WAREHOUSE 환경변수로 덮어쓴다(미설정 = ㉠ 종전 값 · ㉡ toml 값).
def conn():
    role = os.environ.get('GN_DW_ROLE')
    wh = os.environ.get('GN_DW_WAREHOUSE')
    tokpath = os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')
    if not os.path.exists(tokpath):
        name = os.environ.get('SNOWFLAKE_CONNECTION_NAME')
        if not name:
            raise RuntimeError('토큰 파일이 없고 SNOWFLAKE_CONNECTION_NAME 도 없다 — connections.toml 항목 이름을 지정하라')
        kw = {'connection_name': name, 'database': 'GN_DW', 'client_session_keep_alive': True}
        if role:
            kw['role'] = role
        if wh:
            kw['warehouse'] = wh
        return snowflake.connector.connect(**kw)
    tok = open(tokpath).read().strip()
    return snowflake.connector.connect(
        account=os.environ['SNOWFLAKE_ACCOUNT'],
        host=os.environ.get('SNOWFLAKE_HOST'),
        token=tok,
        authenticator='oauth',
        role=role or 'ACCOUNTADMIN',
        warehouse=wh or 'COMPUTE_WH',
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
