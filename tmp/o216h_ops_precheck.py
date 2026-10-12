import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
c = conn().cursor()
def q(s):
    try:
        c.execute(s); return c.fetchall()
    except Exception as e:
        return 'ERR ' + str(e)[:200]
c.execute('USE ROLE ACCOUNTADMIN')
print('wh', [(r[0], r[3], r[22] if len(r) > 22 else '') for r in q('SHOW WAREHOUSES')])
print('rm', q('SHOW RESOURCE MONITORS'))
print('int', q('SHOW NOTIFICATION INTEGRATIONS'))
print('schemas', [r[1] for r in q('SHOW SCHEMAS IN DATABASE GN_DW')])
print('users', [(r[0], r[14] if len(r) > 14 else '') for r in q('SHOW USERS')])
c.execute("DESC USER TRIALADMIN")
print([r[:2] for r in c.fetchall() if r[0] in ('EMAIL', 'HAS_MFA', 'DEFAULT_ROLE', 'OWNER')])
print('tags', q('SHOW TAGS IN SCHEMA GN_DW.SECURITY'))
print('quota', q("SHOW SNOWFLAKE.CORE.QUOTA IN ACCOUNT"))
print('ops', [(r[1], r[4] if len(r) > 4 else '') for r in q('SHOW OBJECTS IN SCHEMA GN_DW.OPS')])
print('owner_ops', q('SHOW SCHEMAS LIKE \'OPS\' IN DATABASE GN_DW'))
